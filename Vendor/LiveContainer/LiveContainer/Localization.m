//
//  Localization.m
//  LiveContainer
//
//  Created by s s on 2024/9/21.
//
#import "Localization.h"
#import "LCSharedUtils.h"
#import "utils.h"

static NSString *containerBranding(NSString *text) {
    if (![NSUserDefaults.lcMainBundle.infoDictionary[@"ZLoaderContainerHost"] boolValue]) return text;
    for (NSString *name in @[@"LiveContainer", @"Live-Container", @"Live Container"]) {
        text = [text stringByReplacingOccurrencesOfString:name withString:@"Container"];
    }
    return text;
}

@implementation NSString (Localization)

// Class method for the English language bundle
+ (NSBundle *)enBundle {
    static NSBundle *enBundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *language = @"en";
        NSString *path = [[NSClassFromString(@"LCSharedUtils") resourceBundle] pathForResource:language ofType:@"lproj"];
        enBundle = [NSBundle bundleWithPath:path];
    });
    return enBundle;
}

// Instance method to return a localized string
- (NSString *)localized {
    NSString *message = [[NSClassFromString(@"LCSharedUtils") resourceBundle] localizedStringForKey:self value:@"" table:nil];
    
    if (![message isEqualToString:self]) {
        return containerBranding(message);
    }

    NSString *forcedString = [[NSString enBundle] localizedStringForKey:self value:nil table:nil];
    
    if (forcedString) {
        return containerBranding(forcedString);
    } else {
        return self;
    }
}

// Instance method for localization with format
- (NSString *)localizeWithFormat:(NSString*)arg1, ... {
    va_list args;
    va_start(args, arg1);
    NSString *formattedString = [NSString localizedStringWithFormat:[self localized], arg1, args];
//    NSString *formattedString = [[NSString alloc] localized:[self localized] arguments:arg1, args];
    va_end(args);
    return formattedString;
}

@end
