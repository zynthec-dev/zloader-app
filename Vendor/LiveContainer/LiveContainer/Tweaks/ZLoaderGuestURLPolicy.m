#import "ZLoaderGuestURLPolicy.h"

NSURL *ZLoaderContainerLaunchURL(NSString *scheme, NSString *bundleFolder, NSString *containerFolder) {
    if (!scheme.length || !bundleFolder.length || [scheme rangeOfString:@"^[A-Za-z][A-Za-z0-9+.-]*$" options:NSRegularExpressionSearch].location == NSNotFound) return nil;
    NSURLComponents *components = [NSURLComponents new];
    components.scheme = scheme;
    components.host = @"livecontainer-launch";
    NSMutableArray *query = [NSMutableArray arrayWithObject:[NSURLQueryItem queryItemWithName:@"bundle-name" value:bundleFolder]];
    if (containerFolder.length) [query addObject:[NSURLQueryItem queryItemWithName:@"container-folder-name" value:containerFolder]];
    components.queryItems = query;
    return components.URL;
}

BOOL ZLoaderURLBelongsToGuest(NSURL *url, NSArray<NSString *> *registeredSchemes, NSArray<NSString *> *authenticationSchemes) {
    NSString *scheme = url.scheme.lowercaseString;
    if (!scheme.length || [@[@"http", @"https", @"file", @"data", @"javascript", @"about", @"blob"] containsObject:scheme]) return NO;
    for (NSString *candidate in [registeredSchemes arrayByAddingObjectsFromArray:authenticationSchemes]) {
        if ([candidate isKindOfClass:NSString.class] && [candidate.lowercaseString isEqualToString:scheme]) return YES;
    }
    return NO;
}
