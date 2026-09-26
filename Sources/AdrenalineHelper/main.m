// Privileged helper, blessed into /Library/PrivilegedHelperTools and run by launchd as root.
//
// Written in Objective-C on purpose: macOS before 10.14.4 ships no Swift runtime, and a
// blessed helper is copied out of the app bundle on its own, so a Swift helper would have
// to load the runtime from the app's Frameworks directory. This file only needs system
// frameworks, so the helper runs on every supported macOS wherever the app lives.
//
// The XPC contract must stay in sync with AdrenalineCore/AdrenalineHelperProtocol.swift:
// the Swift `func enableLidClosePrevention(reply:)` is the selector
// `enableLidClosePreventionWithReply:` here, and the constants below are mirrored from
// `AdrenalineHelperConstants` (checked by AdrenalineHelperConstantsTests).

#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <Security/Security.h>

static NSString *const kHelperMachServiceName = @"com.tonioriol.adrenaline.helper";
static NSString *const kAppCodeSigningRequirement = @"anchor apple generic and identifier \"com.tonioriol.adrenaline\" and certificate leaf[subject.OU] = \"B65K228Z97\" and certificate leaf[field.1.2.840.113635.100.6.1.13] exists";
static const NSInteger kHelperVersion = 1;
static NSString *const kSleepDisabledKey = @"SleepDisabled";

// Private IOKit power-management SPI (same calls `pmset disablesleep` uses).
extern IOReturn IOPMSetSystemPowerSetting(CFStringRef key, CFTypeRef value);
extern CFDictionaryRef IOPMCopySystemPowerSettings(void);

@protocol AdrenalineHelperProtocol
- (void)enableLidClosePreventionWithReply:(void (^)(NSNumber *success, NSString *_Nullable errorMessage))reply;
- (void)disableLidClosePreventionWithReply:(void (^)(NSNumber *success, NSString *_Nullable errorMessage))reply;
- (void)readLidClosePreventionStatusWithReply:(void (^)(NSNumber *enabled, NSString *_Nullable errorMessage))reply;
- (void)helperVersionWithReply:(void (^)(NSNumber *version))reply;
@end

@interface HelperDelegate : NSObject <NSXPCListenerDelegate, AdrenalineHelperProtocol>
@end

@implementation HelperDelegate

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)connection {
    if (![HelperDelegate clientSatisfiesCodeSigningRequirement:connection]) {
        return NO;
    }

    connection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(AdrenalineHelperProtocol)];
    connection.exportedObject = self;
    [connection resume];
    return YES;
}

- (void)enableLidClosePreventionWithReply:(void (^)(NSNumber *, NSString *))reply {
    [self setLidClosePrevention:YES reply:reply];
}

- (void)disableLidClosePreventionWithReply:(void (^)(NSNumber *, NSString *))reply {
    [self setLidClosePrevention:NO reply:reply];
}

- (void)readLidClosePreventionStatusWithReply:(void (^)(NSNumber *, NSString *))reply {
    NSNumber *enabled = [HelperDelegate readSleepDisabled];
    if (enabled == nil) {
        reply(@NO, @"Failed to read SleepDisabled");
        return;
    }
    reply(enabled, nil);
}

- (void)helperVersionWithReply:(void (^)(NSNumber *))reply {
    reply(@(kHelperVersion));
}

- (void)setLidClosePrevention:(BOOL)enabled reply:(void (^)(NSNumber *, NSString *))reply {
    IOReturn result = IOPMSetSystemPowerSetting((__bridge CFStringRef)kSleepDisabledKey,
                                                enabled ? kCFBooleanTrue : kCFBooleanFalse);
    if (result != kIOReturnSuccess) {
        reply(@NO, [NSString stringWithFormat:@"Failed to update SleepDisabled: IOReturn %d", result]);
        return;
    }

    NSNumber *actual = [HelperDelegate readSleepDisabled];
    if (actual == nil) {
        reply(@NO, @"Failed to read SleepDisabled");
        return;
    }
    reply(@(actual.boolValue == enabled), nil);
}

+ (nullable NSNumber *)readSleepDisabled {
    CFDictionaryRef settings = IOPMCopySystemPowerSettings();
    if (settings == NULL) {
        return nil;
    }
    NSDictionary *dictionary = CFBridgingRelease(settings);
    id value = dictionary[kSleepDisabledKey];
    return @([value isKindOfClass:[NSNumber class]] && [value boolValue]);
}

// MARK: - Code Signing Validation

+ (BOOL)clientSatisfiesCodeSigningRequirement:(NSXPCConnection *)connection {
    NSDictionary *attributes = @{ (__bridge NSString *)kSecGuestAttributePid: @(connection.processIdentifier) };
    SecCodeRef code = NULL;
    if (SecCodeCopyGuestWithAttributes(NULL, (__bridge CFDictionaryRef)attributes, kSecCSDefaultFlags, &code) != errSecSuccess
        || code == NULL) {
        return NO;
    }

    SecRequirementRef requirement = NULL;
    if (SecRequirementCreateWithString((__bridge CFStringRef)kAppCodeSigningRequirement, kSecCSDefaultFlags, &requirement) != errSecSuccess
        || requirement == NULL) {
        CFRelease(code);
        return NO;
    }

    OSStatus status = SecCodeCheckValidity(code, kSecCSDefaultFlags, requirement);
    CFRelease(requirement);
    CFRelease(code);
    return status == errSecSuccess;
}

@end

int main(void) {
    @autoreleasepool {
        HelperDelegate *delegate = [[HelperDelegate alloc] init];
        NSXPCListener *listener = [[NSXPCListener alloc] initWithMachServiceName:kHelperMachServiceName];
        listener.delegate = delegate;
        [listener resume];
        [[NSRunLoop currentRunLoop] run];
    }
    return 0;
}
