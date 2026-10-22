#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <sys/sysctl.h>
#import <sys/utsname.h>
#import <dlfcn.h>
#import "../../litehook/src/litehook.h"
#import "Tweaks.h"

static NSDictionary *identity;
static int (*originalSysctlByName)(const char *, void *, size_t *, void *, size_t);
static int (*originalSysctl)(int *, u_int, void *, size_t *, void *, size_t);
static int (*originalUname)(struct utsname *);
static CFTypeRef (*originalMGCopyAnswer)(CFStringRef);
static CFTypeRef (*originalIOProperty)(mach_port_t, CFStringRef, CFAllocatorRef, uint32_t);
static CFTypeRef (*originalIOSearch)(mach_port_t, const char *, CFStringRef, CFAllocatorRef, uint32_t);

static int copyString(NSString *value, void *output, size_t *length) {
    if (!length) { errno = EINVAL; return -1; }
    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
    size_t needed = data.length + 1, capacity = *length;
    *length = needed;
    if (!output) return 0;
    if (capacity < needed) { errno = ENOMEM; return -1; }
    memcpy(output, value.UTF8String, needed);
    return 0;
}
static int virtualSysctlByName(const char *name, void *output, size_t *length, void *newValue, size_t newLength) {
    if (!newValue && name && strcmp(name, "hw.machine") == 0) return copyString(identity[@"hardwareIdentifier"], output, length);
    return originalSysctlByName(name, output, length, newValue, newLength);
}
static int virtualSysctl(int *name, u_int count, void *output, size_t *length, void *newValue, size_t newLength) {
    if (!newValue && name && count == 2 && name[0] == CTL_HW && name[1] == HW_MACHINE) {
        return copyString(identity[@"hardwareIdentifier"], output, length);
    }
    return originalSysctl(name, count, output, length, newValue, newLength);
}
static int virtualUname(struct utsname *value) {
    int result = originalUname(value);
    if (result == 0 && value) {
        strlcpy(value->machine, [identity[@"hardwareIdentifier"] UTF8String], sizeof(value->machine));
        strlcpy(value->nodename, [identity[@"deviceName"] UTF8String], sizeof(value->nodename));
    }
    return result;
}
static NSString *answerForKey(CFStringRef key) {
    if (!key) return nil;
    NSDictionary *values = @{@"ProductType": identity[@"hardwareIdentifier"],
        @"MarketingProductName": identity[@"modelName"], @"UserAssignedDeviceName": identity[@"deviceName"],
        @"SerialNumber": identity[@"serialNumber"], @"UniqueDeviceID": identity[@"syntheticDeviceIdentifier"]};
    return values[(__bridge NSString *)key];
}
static CFTypeRef virtualMGCopyAnswer(CFStringRef key) {
    NSString *value = answerForKey(key);
    return value ? CFRetain((__bridge CFStringRef)value) : originalMGCopyAnswer(key);
}
static BOOL isSerialKey(CFStringRef key) {
    return key && (CFEqual(key, CFSTR("IOPlatformSerialNumber")) || CFEqual(key, CFSTR("serial-number")));
}
static CFTypeRef virtualIOProperty(mach_port_t entry, CFStringRef key, CFAllocatorRef allocator, uint32_t options) {
    if (isSerialKey(key)) return CFRetain((__bridge CFStringRef)identity[@"serialNumber"]);
    return originalIOProperty(entry, key, allocator, options);
}
static CFTypeRef virtualIOSearch(mach_port_t entry, const char *plane, CFStringRef key, CFAllocatorRef allocator, uint32_t options) {
    if (isSerialKey(key)) return CFRetain((__bridge CFStringRef)identity[@"serialNumber"]);
    return originalIOSearch(entry, plane, key, allocator, options);
}

void ZLoaderVirtualDeviceHooksInit(NSDictionary *values) {
    NSArray *required = @[@"hardwareIdentifier", @"deviceName", @"modelName", @"serialNumber", @"vendorIdentifier", @"syntheticDeviceIdentifier"];
    for (NSString *key in required) {
        if (![values[key] isKindOfClass:NSString.class] || [values[key] length] == 0) return;
    }
    NSUUID *vendor = [[NSUUID alloc] initWithUUIDString:values[@"vendorIdentifier"]];
    if (!vendor) return;
    identity = [values copy];
    IDFVHookInit(vendor);
    method_setImplementation(class_getInstanceMethod(UIDevice.class, @selector(name)), imp_implementationWithBlock(^NSString *(id device) { return identity[@"deviceName"]; }));
    method_setImplementation(class_getInstanceMethod(UIDevice.class, @selector(identifierForVendor)), imp_implementationWithBlock(^NSUUID *(id device) { return vendor; }));
    originalSysctlByName = sysctlbyname;
    originalSysctl = sysctl;
    originalUname = uname;
    litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, originalSysctlByName, virtualSysctlByName, nil);
    litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, originalSysctl, virtualSysctl, nil);
    litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, originalUname, virtualUname, nil);
    originalMGCopyAnswer = dlsym(RTLD_DEFAULT, "MGCopyAnswer");
    if (originalMGCopyAnswer) litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, originalMGCopyAnswer, virtualMGCopyAnswer, nil);
    originalIOProperty = dlsym(RTLD_DEFAULT, "IORegistryEntryCreateCFProperty");
    if (originalIOProperty) litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, originalIOProperty, virtualIOProperty, nil);
    originalIOSearch = dlsym(RTLD_DEFAULT, "IORegistryEntrySearchCFProperty");
    if (originalIOSearch) litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, originalIOSearch, virtualIOSearch, nil);
}
