#import "ZLoaderContainerRuntime.h"
#import <dlfcn.h>
#import <objc/message.h>

static Class containerUI(void) {
    static Class result;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dlopen("@executable_path/Frameworks/LiveContainerSwiftUI.framework/LiveContainerSwiftUI", RTLD_LAZY | RTLD_GLOBAL);
        result = NSClassFromString(@"ZLoaderContainerUI");
    });
    return result;
}

int ZLoaderRunContainerHost(int argc, char *argv[]) {
    void *runtime = dlopen("@executable_path/Frameworks/LiveContainerShared.framework/LiveContainerShared", RTLD_LAZY | RTLD_GLOBAL);
    int (*entry)(int, char **) = runtime ? dlsym(runtime, "LiveContainerMain") : NULL;
    if (entry) return entry(argc, argv);
    NSLog(@"Container runtime unavailable: %s", dlerror());
    return UIApplicationMain(argc, argv, nil, @"ZLoaderAppDelegate");
}

static UIViewController *controller(SEL selector) {
    Class ui = containerUI();
    if (ui && [ui respondsToSelector:selector]) {
        return ((UIViewController *(*)(id, SEL))objc_msgSend)(ui, selector);
    }
    UIViewController *fallback = [UIViewController new];
    UILabel *label = [UILabel new];
    label.text = @"Die Container-Laufzeit fehlt in diesem Build.";
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentCenter;
    fallback.view = label;
    return fallback;
}
UIViewController *ZLoaderContainerAppsController(void) { return controller(NSSelectorFromString(@"appsController")); }
UIViewController *ZLoaderContainerSettingsController(void) { return controller(NSSelectorFromString(@"settingsController")); }
BOOL ZLoaderHandleContainerURL(NSURL *url) {
    Class ui = containerUI();
    return ui && ((BOOL (*)(id, SEL, NSURL *))objc_msgSend)(ui, NSSelectorFromString(@"openURL:"), url);
}
void ZLoaderImportContainerIPA(NSURL *url) {
    Class ui = containerUI();
    if (ui) ((void (*)(id, SEL, NSURL *))objc_msgSend)(ui, NSSelectorFromString(@"importIPA:"), url);
}
BOOL ZLoaderSetContainerSigningIdentity(NSData *data, NSString *password, NSError **error) {
    Class ui = containerUI();
    NSString *message = ui ? ((NSString *(*)(id, SEL, NSData *, NSString *))objc_msgSend)(ui,
        NSSelectorFromString(@"configureSigning:password:"), data, password) : @"Container-Laufzeit nicht verfügbar.";
    if (!message) return YES;
    if (error) *error = [NSError errorWithDomain:@"zLoader.ContainerSigning" code:1 userInfo:@{NSLocalizedDescriptionKey: message}];
    return NO;
}
