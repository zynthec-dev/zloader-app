#import "ZLoaderGuestURLPolicy.h"
#import <CommonCrypto/CommonDigest.h>

NSDictionary *ZLoaderContainerShortcutProfile(NSURL *url, NSString *label, NSData *icon, NSString *organization) {
    if (!url.scheme.length || !label.length || !icon.length) return nil;
    NSData *identity = [url.absoluteString dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(identity.bytes, (CC_LONG)identity.length, digest);
    NSMutableString *identifier = [NSMutableString stringWithString:@"de.zloader.container-shortcut."];
    for (NSUInteger i = 0; i < sizeof(digest); i++) [identifier appendFormat:@"%02x", digest[i]];
    NSString *description = [NSString stringWithFormat:@"%@ in %@ öffnen", label, organization];
    NSDictionary *clip = @{@"FullScreen": @YES, @"Icon": icon, @"IgnoreManifestScope": @YES,
        @"IsRemovable": @YES, @"Label": label, @"PayloadDescription": description,
        @"PayloadDisplayName": label, @"PayloadIdentifier": [identifier stringByAppendingString:@".clip"],
        @"PayloadType": @"com.apple.webClip.managed", @"PayloadUUID": NSUUID.UUID.UUIDString,
        @"PayloadVersion": @1, @"Precomposed": @NO, @"URL": url.absoluteString};
    return @{@"ConsentText": @{@"default": description}, @"PayloadContent": @[clip],
        @"PayloadDescription": description, @"PayloadDisplayName": label,
        @"PayloadIdentifier": identifier, @"PayloadOrganization": organization,
        @"PayloadRemovalDisallowed": @NO, @"PayloadType": @"Configuration",
        @"PayloadUUID": NSUUID.UUID.UUIDString, @"PayloadVersion": @1};
}

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
