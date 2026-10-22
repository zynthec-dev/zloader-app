#import <Foundation/Foundation.h>
#import "../../Vendor/LiveContainer/LiveContainer/Tweaks/ZLoaderGuestURLPolicy.h"

int main(void) {
    @autoreleasepool {
        NSArray *schemes = @[@"com.example.login", @"GOOGLE.Example"];
        for (NSString *value in @[@"com.example.login://oauth?code=example&state=unchanged", @"GOOGLE.example:/callback#token=example"]) {
            NSCAssert(ZLoaderURLBelongsToGuest([NSURL URLWithString:value], schemes, @[]), @"Owned callbacks must remain in this guest even with a native app using the same scheme");
        }
        NSCAssert(ZLoaderURLBelongsToGuest([NSURL URLWithString:@"session-only://callback"], schemes, @[@"session-only"]), @"An active native auth session can own an unregistered callback scheme");
        for (NSString *value in @[@"https://example.test", @"http://example.test", @"javascript:alert(1)", @"file:///tmp/data", @"data:text/plain,hello", @"other-app://callback", @"com.example.login.evil://callback", @"com.example.logi://callback"]) {
            NSCAssert(!ZLoaderURLBelongsToGuest([NSURL URLWithString:value], schemes, @[]), @"External and near-match schemes must not be captured");
        }
        NSCAssert(!ZLoaderURLBelongsToGuest([NSURL URLWithString:@"https://example.test"], @[@"https"], @[@"https"]), @"Do not capture all web navigation");
        NSURL *shortcut = ZLoaderContainerLaunchURL(@"zloader", @"Test & Ö.app", @"Container #1 + 2");
        NSURLComponents *components = [NSURLComponents componentsWithURL:shortcut resolvingAgainstBaseURL:NO];
        NSCAssert([components.scheme isEqualToString:@"zloader"] && [components.host isEqualToString:@"livecontainer-launch"], @"Shortcuts must launch the embedded zLoader host");
        NSCAssert([components.queryItems[0].value isEqualToString:@"Test & Ö.app"] && [components.queryItems[1].value isEqualToString:@"Container #1 + 2"], @"Shortcut app/container identities must survive URL encoding");
        NSCAssert(!ZLoaderContainerLaunchURL(@"", @"Test.app", nil) && !ZLoaderContainerLaunchURL(@"invalid://scheme", @"Test.app", nil) && !ZLoaderContainerLaunchURL(@"zloader", @"", nil), @"Reject malformed shortcuts");
        NSCAssert([NSURLComponents componentsWithURL:ZLoaderContainerLaunchURL(@"zloader", @"Test.app", nil) resolvingAgainstBaseURL:NO].queryItems.count == 1, @"Default-container shortcuts need only the app identity");
        puts("PASS guest callbacks remain local, case insensitive exact schemes, active auth ownership, web/external/near-match isolation");
    }
    return 0;
}
