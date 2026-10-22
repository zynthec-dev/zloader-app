#import "ZLoaderAppLauncher.h"

// The same runtime workspace interface is already used by zLoaderBackup.
@interface NSObject (ZLoaderNativeLaunch)
+ (id)defaultWorkspace;
- (void)openApplicationWithBundleIdentifier:(NSString *)bundleIdentifier
                       usingConfiguration:(id)configuration
                        completionHandler:(void (^)(BOOL, NSError * _Nullable))completionHandler;
- (BOOL)openApplicationWithBundleID:(NSString *)bundleIdentifier;
@end

@implementation ZLoaderAppLauncher
+ (void)openApplicationWithBundleIdentifier:(NSString *)bundleIdentifier
                        completionHandler:(void (^)(BOOL, NSError * _Nullable))completionHandler {
    NSCharacterSet *invalid = [[NSCharacterSet characterSetWithCharactersInString:
        @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-"] invertedSet];
    if (bundleIdentifier.length == 0 || [bundleIdentifier rangeOfCharacterFromSet:invalid].location != NSNotFound) {
        completionHandler(NO, [NSError errorWithDomain:@"zLoader.AppLaunch" code:1 userInfo:@{
            NSLocalizedDescriptionKey: @"The installed app has an invalid bundle identifier."
        }]);
        return;
    }
#if ZLOADER_APP_LAUNCH_TESTING
    Class workspaceClass = NSClassFromString(@"ZLoaderTestApplicationWorkspace");
    Class configurationClass = NSClassFromString(@"ZLoaderTestOpenConfiguration");
#else
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    Class configurationClass = NSClassFromString(@"_LSOpenConfiguration");
#endif
    if (!workspaceClass || ![workspaceClass respondsToSelector:@selector(defaultWorkspace)]) {
        completionHandler(NO, [NSError errorWithDomain:@"zLoader.AppLaunch" code:2 userInfo:@{
            NSLocalizedDescriptionKey: @"Direct app launch is unavailable on this system."
        }]);
        return;
    }
    id workspace = [workspaceClass defaultWorkspace];
    if (configurationClass && [workspace respondsToSelector:@selector(openApplicationWithBundleIdentifier:usingConfiguration:completionHandler:)]) {
        // Deliberately no __PayloadURL or URL fallback. An unknown deep link can
        // cause the target app to open Safari while handling its launch URL.
        [workspace openApplicationWithBundleIdentifier:bundleIdentifier
                                   usingConfiguration:[[configurationClass alloc] init]
                                    completionHandler:completionHandler];
    } else if ([workspace respondsToSelector:@selector(openApplicationWithBundleID:)]) {
        completionHandler([workspace openApplicationWithBundleID:bundleIdentifier], nil);
    } else {
        completionHandler(NO, [NSError errorWithDomain:@"zLoader.AppLaunch" code:2 userInfo:@{
            NSLocalizedDescriptionKey: @"Direct app launch is unavailable on this system."
        }]);
    }
}
@end
