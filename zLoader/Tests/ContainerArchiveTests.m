#import <Foundation/Foundation.h>
#import "../../Vendor/LiveContainer/LiveContainerSwiftUI/Utilities/unarchive.h"
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 4) return 2;
        NSString *archive = @(argv[1]), *destination = @(argv[2]);
        BOOL shouldSucceed = atoi(argv[3]) != 0;
        [[NSFileManager defaultManager] createDirectoryAtPath:destination withIntermediateDirectories:YES attributes:nil error:nil];
        int result = extract(archive, destination, [NSProgress progressWithTotalUnitCount:0]);
        NSCAssert((result == 0) == shouldSucceed, @"Archive containment expectation failed");
    }
    return 0;
}
