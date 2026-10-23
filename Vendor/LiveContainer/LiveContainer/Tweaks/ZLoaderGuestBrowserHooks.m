@import UIKit;
@import WebKit;
@import SafariServices;
@import AuthenticationServices;
#import <objc/runtime.h>
#import "ZLoaderGuestURLPolicy.h"
#import "../utils.h"
#import "Tweaks.h"

@interface ZLoaderGuestURLOptions : UISceneOpenURLOptions
@end
@implementation ZLoaderGuestURLOptions
- (NSString *)sourceApplication { return NSUserDefaults.lcMainBundle.bundleIdentifier; }
- (id)annotation { return nil; }
- (BOOL)openInPlace { return NO; }
@end
@interface ZLoaderGuestURLContext : UIOpenURLContext
@property(nonatomic, strong) NSURL *guestURL;
@end
@implementation ZLoaderGuestURLContext
- (NSURL *)URL { return self.guestURL; }
- (UISceneOpenURLOptions *)options { return class_createInstance(ZLoaderGuestURLOptions.class, 0); }
@end

@interface ZLoaderGuestAuthentication : NSObject
@property(nonatomic, copy) NSString *scheme;
@property(nonatomic, copy) ASWebAuthenticationSessionCompletionHandler completion;
@property(nonatomic, weak) ASWebAuthenticationSession *session;
@property(nonatomic) BOOL finished;
@end
@implementation ZLoaderGuestAuthentication
@end
static NSMutableDictionary<NSString *, ZLoaderGuestAuthentication *> *authentications;
static NSArray<NSString *> *guestSchemes;
static BOOL browserHooksActive;
static NSString *guestBundlePath;
static NSSet<NSString *> *guestSceneDelegateNames;
static BOOL guestDeclaresScenes;

static BOOL isGuestSceneDelegate(id delegate) {
    if (!delegate) return NO;
    // Host scenes remain connected when a legacy UIApplicationDelegate guest
    // runs. Never dispatch its callback to the host URL router.
    const char *image = delegate ? class_getImageName([delegate class]) : NULL;
    NSString *path = image ? [@(image) stringByResolvingSymlinksInPath] : nil;
    if ([path hasPrefix:[guestBundlePath stringByAppendingString:@"/"]]) return YES;
    // SwiftUI supplies platform-owned scene delegates for a guest's declared
    // scene lifecycle. Preserve those without accepting the host's UIKit scene.
    NSString *name = NSStringFromClass([delegate class]);
    return guestDeclaresScenes && [path containsString:@"/System/Library/"] &&
        ([guestSceneDelegateNames containsObject:name] || [name hasPrefix:@"SwiftUI."]);

}

static BOOL ownsURL(NSURL *url) {
    NSMutableArray *activeSchemes = [NSMutableArray new];
    for (ZLoaderGuestAuthentication *record in authentications.allValues) {
        if (record.session && !record.finished && record.scheme.length) [activeSchemes addObject:record.scheme];
    }
    return browserHooksActive && ZLoaderURLBelongsToGuest(url, guestSchemes, activeSchemes);
}
static void finishAuthentication(ZLoaderGuestAuthentication *record, NSURL *url, NSError *error) {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ finishAuthentication(record, url, error); });
        return;
    }
    if (record.finished) return;
    record.finished = YES;
    if (record.scheme.length && authentications[record.scheme] == record) [authentications removeObjectForKey:record.scheme];
    record.completion(url, error);
}
static void deliverURL(NSURL *url) {
    ZLoaderGuestAuthentication *authentication = authentications[url.scheme.lowercaseString];
    if (authentication) {
        finishAuthentication(authentication, url, nil);
        [authentication.session cancel];
        return;
    }
    UIApplication *application = UIApplication.sharedApplication;
    ZLoaderGuestURLContext *context = class_createInstance(ZLoaderGuestURLContext.class, 0);
    context.guestURL = url;
    for (UIScene *scene in application.connectedScenes) {
        if (isGuestSceneDelegate(scene.delegate) && scene.activationState != UISceneActivationStateUnattached &&
            [scene.delegate respondsToSelector:@selector(scene:openURLContexts:)]) {
            [scene.delegate scene:scene openURLContexts:[NSSet setWithObject:context]];
            return;
        }
    }
    id<UIApplicationDelegate> delegate = application.delegate;
    if ([delegate respondsToSelector:@selector(application:openURL:options:)]) {
        [delegate application:application openURL:url options:@{}];
    } else if ([delegate respondsToSelector:@selector(application:handleOpenURL:)]) {
        [delegate application:application handleOpenURL:url];
    }
}
BOOL ZLoaderRouteOwnedGuestURL(NSURL *url) {
    if (!ownsURL(url)) return NO;
    // No LaunchServices or UIApplication.open URL dispatch: another installed
    // app with this scheme must never receive this container's auth callback.
    if (NSThread.isMainThread) deliverURL(url);
    else dispatch_async(dispatch_get_main_queue(), ^{ deliverURL(url); });
    return YES;
}

@protocol ZLoaderOwnedBrowserCallback <NSObject>
- (void)finishWithOwnedCallback:(NSURL *)url;
@end
@interface ZLoaderGuestNavigationDelegate : NSObject <WKNavigationDelegate>
@property(nonatomic, weak) id<WKNavigationDelegate> original;
@end
@implementation ZLoaderGuestNavigationDelegate
- (BOOL)respondsToSelector:(SEL)selector { return [super respondsToSelector:selector] || [self.original respondsToSelector:selector]; }
- (id)forwardingTargetForSelector:(SEL)selector { return self.original; }
- (BOOL)intercept:(WKNavigationAction *)action decision:(void (^)(WKNavigationActionPolicy))decision {
    if (!ownsURL(action.request.URL)) return NO;
    decision(WKNavigationActionPolicyCancel);
    if ([self.original conformsToProtocol:@protocol(ZLoaderOwnedBrowserCallback)]) {
        [(id<ZLoaderOwnedBrowserCallback>)self.original finishWithOwnedCallback:action.request.URL];
    } else {
        ZLoaderRouteOwnedGuestURL(action.request.URL);
    }
    return YES;
}
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)action decisionHandler:(void (^)(WKNavigationActionPolicy))decision {
    if ([self intercept:action decision:decision]) return;
    if ([self.original respondsToSelector:_cmd]) [self.original webView:webView decidePolicyForNavigationAction:action decisionHandler:decision];
    else decision(WKNavigationActionPolicyAllow);
}
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)action preferences:(WKWebpagePreferences *)preferences decisionHandler:(void (^)(WKNavigationActionPolicy, WKWebpagePreferences *))decision {
    if ([self intercept:action decision:^(WKNavigationActionPolicy policy) { decision(policy, preferences); }]) return;
    if ([self.original respondsToSelector:_cmd]) [self.original webView:webView decidePolicyForNavigationAction:action preferences:preferences decisionHandler:decision];
    else if ([self.original respondsToSelector:@selector(webView:decidePolicyForNavigationAction:decisionHandler:)]) {
        [self.original webView:webView decidePolicyForNavigationAction:action decisionHandler:^(WKNavigationActionPolicy policy) { decision(policy, preferences); }];
    } else decision(WKNavigationActionPolicyAllow, preferences);
}
@end

@implementation WKWebView (ZLoaderGuestCallbacks)
- (instancetype)zl_initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration __attribute__((objc_method_family(init))) {
    self = [self zl_initWithFrame:frame configuration:configuration];
    if (browserHooksActive) [self setNavigationDelegate:self.navigationDelegate];
    return self;
}
- (instancetype)zl_initWithCoder:(NSCoder *)coder __attribute__((objc_method_family(init))) {
    self = [self zl_initWithCoder:coder];
    if (browserHooksActive) [self setNavigationDelegate:self.navigationDelegate];
    return self;
}
- (void)zl_setNavigationDelegate:(id<WKNavigationDelegate>)delegate {
    if (!browserHooksActive || [delegate isKindOfClass:ZLoaderGuestNavigationDelegate.class]) { [self zl_setNavigationDelegate:delegate]; return; }
    ZLoaderGuestNavigationDelegate *proxy = [ZLoaderGuestNavigationDelegate new];
    proxy.original = delegate;
    objc_setAssociatedObject(self, @selector(zl_setNavigationDelegate:), proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self zl_setNavigationDelegate:proxy];
}
@end

/// SFSafariViewController's remote browser process cannot be hooked by a guest.
/// Use an in-process browser for container-owned Safari windows; native
/// ASWebAuthenticationSession remains native for identity-provider support.
@interface ZLoaderGuestSafariBrowser : SFSafariViewController <WKNavigationDelegate, ZLoaderOwnedBrowserCallback>
@property(nonatomic, strong) NSURL *initialURL;
@property(nonatomic, strong) WKWebView *guestWebView;
@property(nonatomic, strong) UINavigationBar *guestNavigationBar;
@end
@implementation ZLoaderGuestSafariBrowser
- (instancetype)initWithURL:(NSURL *)url configuration:(SFSafariViewControllerConfiguration *)configuration {
    self = [super initWithURL:url configuration:configuration];
    if (self) self.initialURL = url;
    return self;
}
- (void)loadView {
    UIView *view = [UIView new];
    view.backgroundColor = UIColor.systemBackgroundColor;
    self.view = view;
    UINavigationBar *bar = [UINavigationBar new];
    UINavigationItem *item = [[UINavigationItem alloc] initWithTitle:self.initialURL.host ?: @"Anmeldung"];
    item.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(closeGuestBrowser)];
    item.rightBarButtonItems = @[
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"arrow.clockwise"] style:UIBarButtonItemStylePlain target:self action:@selector(reloadGuestBrowser)],
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"chevron.left"] style:UIBarButtonItemStylePlain target:self action:@selector(backGuestBrowser)]];
    bar.items = @[item];
    self.guestNavigationBar = bar;
    WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:[WKWebViewConfiguration new]];
    webView.navigationDelegate = self;
    self.guestWebView = webView;
    for (UIView *child in @[bar, webView]) { child.translatesAutoresizingMaskIntoConstraints = NO; [view addSubview:child]; }
    [NSLayoutConstraint activateConstraints:@[
        [bar.topAnchor constraintEqualToAnchor:view.safeAreaLayoutGuide.topAnchor],
        [bar.leadingAnchor constraintEqualToAnchor:view.leadingAnchor], [bar.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
        [webView.topAnchor constraintEqualToAnchor:bar.bottomAnchor], [webView.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
        [webView.trailingAnchor constraintEqualToAnchor:view.trailingAnchor], [webView.bottomAnchor constraintEqualToAnchor:view.bottomAnchor]]];
}
- (void)viewDidLoad {
    // Avoid the system class's remote Safari view-service setup.
    void (*base)(id, SEL) = (void *)class_getMethodImplementation(UIViewController.class, _cmd);
    base(self, _cmd);
    [self.guestWebView loadRequest:[NSURLRequest requestWithURL:self.initialURL]];
}
- (void)viewWillAppear:(BOOL)animated {
    void (*base)(id, SEL, BOOL) = (void *)class_getMethodImplementation(UIViewController.class, _cmd);
    base(self, _cmd, animated);
}
- (void)viewDidAppear:(BOOL)animated {
    void (*base)(id, SEL, BOOL) = (void *)class_getMethodImplementation(UIViewController.class, _cmd);
    base(self, _cmd, animated);
}
- (void)viewWillDisappear:(BOOL)animated {
    void (*base)(id, SEL, BOOL) = (void *)class_getMethodImplementation(UIViewController.class, _cmd);
    base(self, _cmd, animated);
}
- (void)viewDidDisappear:(BOOL)animated {
    void (*base)(id, SEL, BOOL) = (void *)class_getMethodImplementation(UIViewController.class, _cmd);
    base(self, _cmd, animated);
}
- (void)closeGuestBrowser {
    if ([self.delegate respondsToSelector:@selector(safariViewControllerDidFinish:)]) [self.delegate safariViewControllerDidFinish:self];
    [self dismissViewControllerAnimated:YES completion:nil];
}
- (void)reloadGuestBrowser { [self.guestWebView reload]; }
- (void)backGuestBrowser { if (self.guestWebView.canGoBack) [self.guestWebView goBack]; }
- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation {
    self.guestNavigationBar.topItem.title = webView.URL.host;
}
- (void)finishWithOwnedCallback:(NSURL *)url {
    // A wrapper can cancel pending OAuth state in viewDidDisappear. Deliver
    // first, while it is still alive, and let the guest close its own wrapper.
    ZLoaderRouteOwnedGuestURL(url);
    if (self.presentingViewController && !self.isBeingDismissed) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}
@end
@implementation SFSafariViewController (ZLoaderGuestCallbacks)
// Apple uses private SFSafari subclasses for ASWebAuthenticationSession. Their
// private presentation API must retain the system implementation and identity.
- (instancetype)zl_initWithURL:(NSURL *)url __attribute__((objc_method_family(init))) {
    if (browserHooksActive && object_getClass(self) == SFSafariViewController.class) {
        return [[ZLoaderGuestSafariBrowser alloc] initWithURL:url configuration:[SFSafariViewControllerConfiguration new]];
    }
    return [self zl_initWithURL:url];
}
- (instancetype)zl_initWithURL:(NSURL *)url entersReaderIfAvailable:(BOOL)reader __attribute__((objc_method_family(init))) {
    if (browserHooksActive && object_getClass(self) == SFSafariViewController.class) {
        SFSafariViewControllerConfiguration *configuration = [SFSafariViewControllerConfiguration new];
        configuration.entersReaderIfAvailable = reader;
        return [[ZLoaderGuestSafariBrowser alloc] initWithURL:url configuration:configuration];
    }
    return [self zl_initWithURL:url entersReaderIfAvailable:reader];
}
- (instancetype)zl_initWithURL:(NSURL *)url configuration:(SFSafariViewControllerConfiguration *)configuration __attribute__((objc_method_family(init))) {
    if (browserHooksActive && object_getClass(self) == SFSafariViewController.class) {
        return [[ZLoaderGuestSafariBrowser alloc] initWithURL:url configuration:configuration];
    }
    return [self zl_initWithURL:url configuration:configuration];
}
@end

@implementation ASWebAuthenticationSessionCallback (ZLoaderGuestCallbacks)
+ (instancetype)zl_callbackWithCustomScheme:(NSString *)scheme {
    id callback = [self zl_callbackWithCustomScheme:scheme];
    objc_setAssociatedObject(callback, @selector(zl_callbackWithCustomScheme:), scheme.lowercaseString, OBJC_ASSOCIATION_COPY_NONATOMIC);
    return callback;
}
@end

@implementation ASWebAuthenticationSession (ZLoaderGuestCallbacks)
- (instancetype)zl_initWithURL:(NSURL *)url callback:(ASWebAuthenticationSessionCallback *)callback completionHandler:(ASWebAuthenticationSessionCompletionHandler)completion __attribute__((objc_method_family(init))) {
    ZLoaderGuestAuthentication *record = [ZLoaderGuestAuthentication new];
    record.scheme = objc_getAssociatedObject(callback, @selector(zl_callbackWithCustomScheme:));
    record.completion = completion;
    self = [self zl_initWithURL:url callback:callback completionHandler:^(NSURL *result, NSError *error) {
        finishAuthentication(record, result, error);
    }];
    record.session = self;
    objc_setAssociatedObject(self, @selector(zl_start), record, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return self;
}
- (instancetype)zl_initWithURL:(NSURL *)url callbackURLScheme:(NSString *)scheme completionHandler:(ASWebAuthenticationSessionCompletionHandler)completion __attribute__((objc_method_family(init))) {
    ZLoaderGuestAuthentication *record = [ZLoaderGuestAuthentication new];
    record.scheme = scheme.lowercaseString;
    record.completion = completion;
    self = [self zl_initWithURL:url callbackURLScheme:scheme completionHandler:^(NSURL *result, NSError *error) {
        finishAuthentication(record, result, error);
    }];
    record.session = self;
    objc_setAssociatedObject(self, @selector(zl_start), record, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return self;
}
- (BOOL)zl_start {
    ZLoaderGuestAuthentication *record = objc_getAssociatedObject(self, @selector(zl_start));
    if (!record) return [self zl_start];
    if (record.scheme.length) authentications[record.scheme] = record;
    BOOL started = [self zl_start];
    if (!started && record.scheme.length && authentications[record.scheme] == record) [authentications removeObjectForKey:record.scheme];
    return started;
}
@end

void ZLoaderGuestBrowserHooksInit(void) {
    if (browserHooksActive || ![NSUserDefaults.lcMainBundle.infoDictionary[@"ZLoaderContainerHost"] boolValue] || !NSUserDefaults.lcGuestAppId) return;
    browserHooksActive = YES;
    authentications = [NSMutableDictionary new];
    NSMutableArray *schemes = [NSMutableArray new];
    for (NSDictionary *type in NSBundle.mainBundle.infoDictionary[@"CFBundleURLTypes"]) {
        for (NSString *scheme in type[@"CFBundleURLSchemes"]) if ([scheme isKindOfClass:NSString.class]) [schemes addObject:scheme.lowercaseString];
    }
    guestBundlePath = NSBundle.mainBundle.bundlePath.stringByResolvingSymlinksInPath;
    id rawManifest = NSBundle.mainBundle.infoDictionary[@"UIApplicationSceneManifest"];
    NSDictionary *manifest = [rawManifest isKindOfClass:NSDictionary.class] ? rawManifest : nil;
    guestDeclaresScenes = manifest != nil;
    id rawRoles = manifest[@"UISceneConfigurations"];
    NSDictionary *roles = [rawRoles isKindOfClass:NSDictionary.class] ? rawRoles : nil;
    NSMutableSet *delegates = [NSMutableSet new];
    for (NSArray *configurations in roles.allValues) {
        if (![configurations isKindOfClass:NSArray.class]) continue;
        for (NSDictionary *configuration in configurations) {
            if (![configuration isKindOfClass:NSDictionary.class]) continue;
            NSString *name = configuration[@"UISceneDelegateClassName"];
            if ([name isKindOfClass:NSString.class]) [delegates addObject:name];
        }
    }
    guestSceneDelegateNames = delegates;
    guestSchemes = schemes;
    swizzle(WKWebView.class, @selector(setNavigationDelegate:), @selector(zl_setNavigationDelegate:));
    swizzle(WKWebView.class, @selector(initWithFrame:configuration:), @selector(zl_initWithFrame:configuration:));
    swizzle(WKWebView.class, @selector(initWithCoder:), @selector(zl_initWithCoder:));
    swizzle(SFSafariViewController.class, @selector(initWithURL:), @selector(zl_initWithURL:));
    swizzle(SFSafariViewController.class, NSSelectorFromString(@"initWithURL:entersReaderIfAvailable:"), @selector(zl_initWithURL:entersReaderIfAvailable:));
    swizzle(SFSafariViewController.class, @selector(initWithURL:configuration:), @selector(zl_initWithURL:configuration:));
    swizzle(ASWebAuthenticationSession.class, @selector(initWithURL:callbackURLScheme:completionHandler:), @selector(zl_initWithURL:callbackURLScheme:completionHandler:));
    swizzle(object_getClass(ASWebAuthenticationSessionCallback.class), @selector(callbackWithCustomScheme:), @selector(zl_callbackWithCustomScheme:));
    swizzle(ASWebAuthenticationSession.class, @selector(initWithURL:callback:completionHandler:), @selector(zl_initWithURL:callback:completionHandler:));
    swizzle(ASWebAuthenticationSession.class, @selector(start), @selector(zl_start));
}
