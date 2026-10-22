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
        puts("PASS guest callbacks remain local, case insensitive exact schemes, active auth ownership, web/external/near-match isolation");
    }
    return 0;
}
