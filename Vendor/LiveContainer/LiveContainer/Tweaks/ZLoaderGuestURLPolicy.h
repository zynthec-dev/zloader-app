#import <Foundation/Foundation.h>
BOOL ZLoaderURLBelongsToGuest(NSURL *url, NSArray<NSString *> *registeredSchemes, NSArray<NSString *> *authenticationSchemes);
NSURL *ZLoaderContainerLaunchURL(NSString *scheme, NSString *bundleFolder, NSString *containerFolder);
BOOL ZLoaderRouteOwnedGuestURL(NSURL *url);
void ZLoaderGuestBrowserHooksInit(void);
