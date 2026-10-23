#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <SafariServices/SafariServices.h>
#import <AuthenticationServices/AuthenticationServices.h>
#import <sys/sysctl.h>
#import <sys/utsname.h>

// Synthetic acceptance-test app. No account, credentials or remote service.
@interface FixtureController : UIViewController <ASWebAuthenticationPresentationContextProviding>
@property UILabel *callbackLabel;
@property ASWebAuthenticationSession *authentication;
@end

// Match legacy OAuth wrappers: leaving the browser cancels an unfinished flow.
static FixtureController *activeController;
static BOOL wrapperPending;
@interface FixtureSafariWrapper : UIViewController
@property NSURL *url;
@end
@implementation FixtureSafariWrapper
- (void)viewDidLoad {
    [super viewDidLoad];
    SFSafariViewController *browser = [[SFSafariViewController alloc] initWithURL:self.url];
    [self addChildViewController:browser];
    browser.view.frame = self.view.bounds;
    browser.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:browser.view];
    [browser didMoveToParentViewController:self];
}
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (wrapperPending) {
        wrapperPending = NO;
        activeController.callbackLabel.text = @"cancelled-before-callback";
    }
}
@end

@implementation FixtureController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    UIStackView *stack = [UIStackView new];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 16;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:24],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-24],
        [stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:24]
    ]];
    activeController = self;
    NSDictionary *info = NSBundle.mainBundle.infoDictionary;
    UILabel *title = [UILabel new];
    title.text = info[@"CFBundleDisplayName"];
    title.accessibilityIdentifier = @"fixture-title";
    [stack addArrangedSubview:title];
    struct utsname machine;
    uname(&machine);
    char product[128] = {0}; size_t size = sizeof(product);
    sysctlbyname("hw.machine", product, &size, NULL, 0);
    NSDictionary *values = @{
        @"idfv": UIDevice.currentDevice.identifierForVendor.UUIDString ?: @"nil",
        @"device-name": UIDevice.currentDevice.name,
        @"uname": @(machine.machine),
        @"product-type": @(product)
    };
    for (NSString *key in [values.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        UILabel *label = [UILabel new]; label.numberOfLines = 0;
        label.text = values[key]; label.accessibilityIdentifier = [@"fixture-" stringByAppendingString:key];
        [stack addArrangedSubview:label];
    }
    NSInteger launches = [NSUserDefaults.standardUserDefaults integerForKey:@"fixture-launches"] + 1;
    [NSUserDefaults.standardUserDefaults setInteger:launches forKey:@"fixture-launches"];
    UILabel *counter = [UILabel new]; counter.text = [NSString stringWithFormat:@"%ld", (long)launches];
    counter.accessibilityIdentifier = @"fixture-launch-count"; [stack addArrangedSubview:counter];
    for (NSString *kind in @[@"WK", @"Safari", @"ASSession", @"ASCallback", @"Wrapper"]) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        [button setTitle:[kind stringByAppendingString:@" login"] forState:UIControlStateNormal];
        button.accessibilityIdentifier = [@"fixture-login-" stringByAppendingString:kind];
        [button addTarget:self action:@selector(login:) forControlEvents:UIControlEventTouchUpInside];
        [stack addArrangedSubview:button];
    }
    self.callbackLabel = [UILabel new]; self.callbackLabel.numberOfLines = 0;
    self.callbackLabel.text = @"waiting"; self.callbackLabel.accessibilityIdentifier = @"fixture-callback";
    [stack addArrangedSubview:self.callbackLabel];
}
- (void)login:(UIButton *)button {
    self.callbackLabel.text = @"waiting";
    NSString *kind = [button.accessibilityIdentifier componentsSeparatedByString:@"-"].lastObject;
    NSURL *url = [NSURL URLWithString:@"http://127.0.0.1:18769/login"];
    if ([kind isEqualToString:@"WK"]) {
        UIViewController *browser = [UIViewController new];
        WKWebView *web = [[WKWebView alloc] initWithFrame:self.view.bounds];
        web.accessibilityIdentifier = @"fixture-web"; browser.view = web;
        [self presentViewController:browser animated:YES completion:^{ [web loadRequest:[NSURLRequest requestWithURL:url]]; }];
    } else if ([kind isEqualToString:@"Wrapper"]) {
        wrapperPending = YES;
        FixtureSafariWrapper *wrapper = [FixtureSafariWrapper new]; wrapper.url = url;
        [self presentViewController:wrapper animated:YES completion:nil];
    } else if ([kind isEqualToString:@"Safari"]) {
        SFSafariViewController *browser = [[SFSafariViewController alloc] initWithURL:url];
        NSLog(@"Fixture Safari class: %@", NSStringFromClass(browser.class));
        [self presentViewController:browser animated:YES completion:nil];
    } else {
        __weak typeof(self) weakSelf = self;
        ASWebAuthenticationSessionCompletionHandler completion = ^(NSURL *callback, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.callbackLabel.text = callback.absoluteString ?: error.localizedDescription;
            });
        };
        if ([kind isEqualToString:@"ASCallback"]) {
            self.authentication = [[ASWebAuthenticationSession alloc] initWithURL:url
                callback:[ASWebAuthenticationSessionCallback callbackWithCustomScheme:@"fixturecallback"] completionHandler:completion];
        } else {
            self.authentication = [[ASWebAuthenticationSession alloc] initWithURL:url callbackURLScheme:@"fixturecallback" completionHandler:completion];
        }
        self.authentication.presentationContextProvider = self;
        self.authentication.prefersEphemeralWebBrowserSession = YES;
        [self.authentication start];
    }
}
- (ASPresentationAnchor)presentationAnchorForWebAuthenticationSession:(ASWebAuthenticationSession *)session {
    return self.view.window;
}
- (void)receiveURL:(NSURL *)url {
    if ([self.presentedViewController isKindOfClass:FixtureSafariWrapper.class] && !wrapperPending) return;
    wrapperPending = NO;
    self.callbackLabel.text = url.absoluteString;
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end

@interface FixtureDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end
@implementation FixtureDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    if (!NSBundle.mainBundle.infoDictionary[@"UIApplicationSceneManifest"]) {
        self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        self.window.rootViewController = [FixtureController new];
        [self.window makeKeyAndVisible];
    }
    return YES;
}
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url options:(NSDictionary *)options {
    [activeController receiveURL:url]; return YES;
}
@end

@interface FixtureSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property(nonatomic, strong) UIWindow *window;
@property FixtureController *controller;
@end
@implementation FixtureSceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.controller = [FixtureController new]; self.window.rootViewController = self.controller;
    [self.window makeKeyAndVisible];
}
- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)contexts {
    [self.controller receiveURL:contexts.anyObject.URL];
}
@end
int main(int argc, char **argv) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(FixtureDelegate.class)); }
}
