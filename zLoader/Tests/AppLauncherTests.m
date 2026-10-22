#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "../App/Core/UI/ZLoaderAppLauncher.h"

static id workspace;
static NSUInteger modernCalls, legacyCalls, payloadCalls;
static BOOL modernSucceeds;
static NSString *receivedBundle;
static id defaultWorkspace(id object, SEL selector) { (void)object; (void)selector; return workspace; }
static void setPayload(id object, SEL selector, id payload) { (void)object; (void)selector; (void)payload; payloadCalls++; }
static BOOL launchLegacy(id object, SEL selector, NSString *bundle) {
    (void)object; (void)selector;
    legacyCalls++; receivedBundle = bundle; return YES;
}
static void launchModern(id object, SEL selector, NSString *bundle, id configuration, void (^completion)(BOOL, NSError *)) {
    (void)object; (void)selector;
    modernCalls++; receivedBundle = bundle;
    NSCAssert(configuration != nil, @"Missing native configuration");
    completion(modernSucceeds, nil);
}

int main(int argc, const char **argv) {
    @autoreleasepool {
        NSString *mode = argc > 1 ? @(argv[1]) : @"unavailable";
        if (![mode isEqualToString:@"unavailable"]) {
            Class cls = objc_allocateClassPair(NSObject.class, "ZLoaderTestApplicationWorkspace", 0);
            class_addMethod(object_getClass(cls), @selector(defaultWorkspace), (IMP)defaultWorkspace, "@@:");
            class_addMethod(cls, NSSelectorFromString(@"openApplicationWithBundleID:"), (IMP)launchLegacy, "B@:@");
            if (![mode isEqualToString:@"legacy"]) {
                Class config = objc_allocateClassPair(NSObject.class, "ZLoaderTestOpenConfiguration", 0);
                class_addMethod(config, NSSelectorFromString(@"setFrontBoardOptions:"), (IMP)setPayload, "v@:@");
                objc_registerClassPair(config);
                class_addMethod(cls, NSSelectorFromString(@"openApplicationWithBundleIdentifier:usingConfiguration:completionHandler:"), (IMP)launchModern, "v@:@@@?");
            }
            objc_registerClassPair(cls); workspace = [[cls alloc] init];
        }
        modernSucceeds = [mode isEqualToString:@"modern-success"];
        BOOL invalid = [mode isEqualToString:@"invalid"];
        NSString *target = invalid ? @"https://example.invalid" : @"example.app.TESTTEAM";
        __block NSUInteger completions = 0;
        __block BOOL result = NO;
        [ZLoaderAppLauncher openApplicationWithBundleIdentifier:target completionHandler:^(BOOL success, NSError *error) {
            (void)error; completions++; result = success;
        }];
        NSCAssert(completions == 1 && payloadCalls == 0, @"Must complete once without a URL payload");
        if (invalid || [mode isEqualToString:@"unavailable"]) {
            NSCAssert(!result && modernCalls == 0 && legacyCalls == 0, @"Invalid/unavailable launch must not open anything");
        } else if ([mode isEqualToString:@"legacy"]) {
            NSCAssert(result && legacyCalls == 1 && modernCalls == 0, @"One legacy bundle launch only");
        } else {
            NSCAssert(result == modernSucceeds && modernCalls == 1 && legacyCalls == 0, @"Never retry after a modern launch result");
        }
        if (modernCalls + legacyCalls) { NSCAssert([receivedBundle isEqualToString:target], @"Must use the actual resigned bundle identifier"); }
        printf("PASS native app launcher: %s\n", mode.UTF8String);
    }
    return 0;
}
