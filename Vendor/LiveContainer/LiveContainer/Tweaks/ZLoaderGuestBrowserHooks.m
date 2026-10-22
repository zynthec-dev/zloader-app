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

static BOOL ownsURL(NSURL *url) {
    return browserHooksActive && ZLoaderURLBelongsToGuest(url, guestSchemes, authentications.allKeys);
}
static void finishAuthentication(ZLoaderGuestAuthentication *record, NSURL *url, NSError *error) {
    if (record.finished) return;
    record.finished = YES;
    if (authentications[record.scheme] == record) [authentications removeObjectForKey:record.scheme];
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
        if (scene.activationState != UISceneActivationStateUnattached &&
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
    dispatch_async(dispatch_get_main_queue(), ^{ deliverURL(url); });
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
    [self dismissViewControllerAnimated:YES completion:^{ ZLoaderRouteOwnedGuestURL(url); }];
}
@end
@implementation SFSafariViewController (ZLoaderGuestCallbacks)
- (instancetype)zl_initWithURL:(NSURL *)url configuration:(SFSafariViewControllerConfiguration *)configuration __attribute__((objc_method_family(init))) {
    if (browserHooksActive && ![self isKindOfClass:ZLoaderGuestSafariBrowser.class]) {
        return [[ZLoaderGuestSafariBrowser alloc] initWithURL:url configuration:configuration];
    }
    return [self zl_initWithURL:url configuration:configuration];
}
@end

@implementation ASWebAuthenticationSession (ZLoaderGuestCallbacks)
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
    if (!started && authentications[record.scheme] == record) [authentications removeObjectForKey:record.scheme];
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
    guestSchemes = schemes;
    swizzle(WKWebView.class, @selector(setNavigationDelegate:), @selector(zl_setNavigationDelegate:));
    swizzle(SFSafariViewController.class, @selector(initWithURL:configuration:), @selector(zl_initWithURL:configuration:));
    swizzle(ASWebAuthenticationSession.class, @selector(initWithURL:callbackURLScheme:completionHandler:), @selector(zl_initWithURL:callbackURLScheme:completionHandler:));
    swizzle(ASWebAuthenticationSession.class, @selector(start), @selector(zl_start));
}
