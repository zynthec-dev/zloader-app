#import "ZLoaderGuestURLPolicy.h"

BOOL ZLoaderURLBelongsToGuest(NSURL *url, NSArray<NSString *> *registeredSchemes, NSArray<NSString *> *authenticationSchemes) {
    NSString *scheme = url.scheme.lowercaseString;
    if (!scheme.length || [@[@"http", @"https", @"file", @"data", @"javascript", @"about", @"blob"] containsObject:scheme]) return NO;
    for (NSString *candidate in [registeredSchemes arrayByAddingObjectsFromArray:authenticationSchemes]) {
        if ([candidate isKindOfClass:NSString.class] && [candidate.lowercaseString isEqualToString:scheme]) return YES;
    }
    return NO;
}
