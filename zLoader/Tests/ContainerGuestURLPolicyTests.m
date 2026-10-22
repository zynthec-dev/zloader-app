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
        NSData *icon = [@"synthetic icon" dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *profile = ZLoaderContainerShortcutProfile(shortcut, @"Test", icon, @"zLoader");
        NSDictionary *same = ZLoaderContainerShortcutProfile(shortcut, @"Renamed", icon, @"zLoader");
        NSDictionary *other = ZLoaderContainerShortcutProfile(ZLoaderContainerLaunchURL(@"zloader", @"Test & Ö.app", @"Another container"), @"Test", icon, @"zLoader");
        NSCAssert([profile[@"PayloadIdentifier"] isEqual:same[@"PayloadIdentifier"]] && ![profile[@"PayloadIdentifier"] isEqual:other[@"PayloadIdentifier"]], @"Updating one shortcut must preserve other data-container shortcuts");
        NSDictionary *clip = [profile[@"PayloadContent"] firstObject];
        NSCAssert([clip[@"PayloadType"] isEqual:@"com.apple.webClip.managed"] && [clip[@"Icon"] isEqual:icon] && [clip[@"URL"] isEqual:shortcut.absoluteString], @"Distribute only the selected web clip with its actual icon and exact launch URL");
        NSCAssert([clip[@"IsRemovable"] boolValue] && ![profile[@"PayloadRemovalDisallowed"] boolValue], @"The shortcut profile must remain removable");
        NSCAssert(!ZLoaderContainerShortcutProfile(shortcut, @"Test", [NSData data], @"zLoader"), @"Do not create a broken icon-less profile");
        puts("PASS guest callbacks remain local, case insensitive exact schemes, active auth ownership, web/external/near-match isolation");
    }
    return 0;
}
