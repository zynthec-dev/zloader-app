#import <Foundation/Foundation.h>
BOOL ZLoaderURLBelongsToGuest(NSURL *url, NSArray<NSString *> *registeredSchemes, NSArray<NSString *> *authenticationSchemes);
BOOL ZLoaderRouteOwnedGuestURL(NSURL *url);
void ZLoaderGuestBrowserHooksInit(void);
