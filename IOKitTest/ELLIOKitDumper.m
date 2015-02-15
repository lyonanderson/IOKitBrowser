//
//  ELLIOKitDumper.m
//  IOKitTest
//
//  Created by Christopher Anderson on 10/02/2014.
//  Copyright (c) 2014 Electric Labs. All rights reserved.
//
// This code is based on Apple's IOKitTools http://opensource.apple.com/source/IOKitTools/IOKitTools-89.1.1/ioreg.tproj/ioreg.c

#import "ELLIOKitDumper.h"
#import <mach/mach_host.h>
#import "ELLIOKitNodeInfo.h"


static void assertion(int condition, char *message) {
    if (condition == 0) {
        fprintf(stderr, "ioreg: error: %s.\n", message);
        exit(1);
    }
}

const UInt32 kIORegFlagShowProperties = (1 << 1);

struct options {
    char *class;
    UInt32 flags;
    char *name;
    char *plane;
};


@interface ELLIOKitDumper  ()
@property (nonatomic, assign) IORegistryGetRootEntryShim IORegistryGetRootEntryShim;
@property (nonatomic, assign) IOMasterPortShim IOMasterPortShim;
@property (nonatomic, assign) IORegistryEntryGetNameInPlaneShim IORegistryEntryGetNameInPlaneShim;
@property (nonatomic, assign) IOObjectReleaseShim IOObjectReleaseShim;
@property (nonatomic, assign) IOObjectRetainShim IOObjectRetainShim;
@property (nonatomic, assign) IOIteratorNextShim IOIteratorNextShim;
@property (nonatomic, assign) IORegistryEntryCreateCFPropertiesShim IORegistryEntryCreateCFPropertiesShim;
@property (nonatomic, assign) IOObjectConformsToShim IOObjectConformsToShim;
@property (nonatomic, assign) IORegistryEntryGetChildIteratorShim IORegistryEntryGetChildIteratorShim;
@end



@implementation ELLIOKitDumper

- (instancetype)init {
    self = [super init];
    if (self) {
        [self _prepFuncs];
    }
    return self;
}

+ (instancetype)sharedInstance {
    static dispatch_once_t pred;
    static ELLIOKitDumper *service = nil;
    dispatch_once(&pred, ^{ service = [[self alloc] init]; });
    return service;
}


- (void)_prepFuncs {
    NSString *bundlePath = [[NSBundle bundleWithPath:@"/System/Library/Frameworks/IOKit.framework"] bundlePath];
    NSURL *bundleURL = [NSURL fileURLWithPath:bundlePath];
    CFBundleRef cfBundle = CFBundleCreate(kCFAllocatorDefault, (CFURLRef)bundleURL);
    
    self.IORegistryGetRootEntryShim = CFBundleGetFunctionPointerForName(cfBundle, CFSTR("IORegistryGetRootEntry"));
    self.IOMasterPortShim = CFBundleGetFunctionPointerForName(cfBundle, CFSTR("IOMasterPort"));
    self.IORegistryEntryGetNameInPlaneShim = CFBundleGetFunctionPointerForName(cfBundle, CFSTR("IORegistryEntryGetNameInPlane"));
    self.IOObjectReleaseShim = CFBundleGetFunctionPointerForName(cfBundle, CFSTR("IOObjectRelease"));
    self.IOObjectRetainShim = CFBundleGetFunctionPointerForName(cfBundle, CFSTR("IOObjectRetain"));
    self.IOIteratorNextShim = CFBundleGetFunctionPointerForName(cfBundle, CFSTR("IOIteratorNext"));
    self.IORegistryEntryCreateCFPropertiesShim = CFBundleGetFunctionPointerForName(cfBundle, CFSTR("IORegistryEntryCreateCFProperties"));
    self.IOObjectConformsToShim = CFBundleGetFunctionPointerForName(cfBundle, CFSTR("IOObjectConformsTo"));
    self.IORegistryEntryGetChildIteratorShim = CFBundleGetFunctionPointerForName(cfBundle, CFSTR("IORegistryEntryGetChildIterator"));
    
    CFRelease(cfBundle);
}

- (void)dumpIOKitTreeFromNode:(ELLIOKitNodeInfo *)fromNode completion:(void(^)(ELLIOKitNodeInfo *nodeInfo))completion {
    
     dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
     
         mach_port_t iokitPort = 0;
         struct options options;
         io_registry_entry_t service = 0;
         kern_return_t status = KERN_SUCCESS;
         
         options.class = 0;
         options.flags = kIORegFlagShowProperties;
         options.name = 0;
         options.plane = kIOServicePlane;
         
         status = self.IOMasterPortShim(bootstrap_port, &iokitPort);
         assertion(status == KERN_SUCCESS, "can't obtain I/O Kit's master port");
         
         
         if (fromNode == nil) {
             service = self.IORegistryGetRootEntryShim(iokitPort);
         } else {
             service = fromNode.service;
         }
         
         assertion(service, "can't obtain I/O Kit's root service");
         
         ELLIOKitNodeInfo *root = [self _scan:fromNode.parent service:service options:options];
         
         dispatch_async(dispatch_get_main_queue(), ^{
             completion(root);
         });
         
     });

}


- (ELLIOKitNodeInfo *)_scan:(ELLIOKitNodeInfo *)parent service:(io_registry_entry_t)service options:(struct options)options {

    io_registry_entry_t child = 0;
    io_registry_entry_t childUpNext = 0;
    io_iterator_t children = 0;
    kern_return_t status = KERN_SUCCESS;

    // Obtain the service's children.

    status = self.IORegistryEntryGetChildIteratorShim(service, options.plane, &children);
    assertion(status == KERN_SUCCESS, "can't obtain children");

    childUpNext = self.IOIteratorNextShim(children);

    ELLIOKitNodeInfo *node = [self _showService:service parent:parent options:options];

    // Traverse over the children of this service.
    while (childUpNext) {
        child = childUpNext;
        childUpNext = self.IOIteratorNextShim(children);

        ELLIOKitNodeInfo *childNode = [self _scan:node service:child options:options];

        [node addChild:childNode];

    }

    self.IOObjectReleaseShim(children);
    children = 0;

    return node;

}

- (void)releaseIOKitService:(io_registry_entry_t)service {
    self.IOObjectReleaseShim(service);
}

- (void)retainIOKitService:(io_registry_entry_t)service {
    self.IOObjectRetainShim(service);
}

- (ELLIOKitNodeInfo *)_showService:(io_registry_entry_t)service parent:(ELLIOKitNodeInfo *)parent options:(struct options)options {
    io_name_t name;
    CFMutableDictionaryRef properties = 0;
    kern_return_t status = KERN_SUCCESS;

    self.IORegistryEntryGetNameInPlaneShim(service, options.plane, name);

    NSMutableArray *translatedProperties = [NSMutableArray new];

    if (options.class && self.IOObjectConformsToShim(service, options.class)) {
        options.flags |= kIORegFlagShowProperties;
    }

    if (options.name && !strcmp(name, options.name)) {
        options.flags |= kIORegFlagShowProperties;
    }

    if (options.flags & kIORegFlagShowProperties) {

        // Obtain the service's properties.

        status = self.IORegistryEntryCreateCFPropertiesShim(service,
                &properties,
                kCFAllocatorDefault,
                kNilOptions);

        assertion(status == KERN_SUCCESS, "can't obtain properties");

        CFDictionaryApplyFunction(properties, CFDictionaryShow_Applier, (__bridge void *) (translatedProperties));

        CFRelease(properties);
    }

    return [[ELLIOKitNodeInfo alloc] initWithParent:parent service:service nodeInfoWithInfo:[NSString stringWithCString:name encoding:NSUTF8StringEncoding] properties:translatedProperties];


}

static void CFArrayShow_Applier(const void *value, void *parameter) {
    NSMutableArray *translatedElements = (__bridge NSMutableArray *) parameter;
    NSString *translatedElement = CFObjectShow(value);

    if (translatedElement) {
        [translatedElements addObject:translatedElement];
    }
}

static NSString *CFArrayShow(CFArrayRef object) {
    CFRange range = {0, CFArrayGetCount(object)};
    NSMutableArray *translatedElements = [NSMutableArray new];
    CFArrayApplyFunction(object, range, CFArrayShow_Applier, (__bridge void *) (translatedElements));

    return [NSString stringWithFormat:@"(%@)", [translatedElements componentsJoinedByString:@","]];
}

static NSString *CFBooleanShow(CFBooleanRef object) {
    return CFBooleanGetValue(object) ? @"Yes" : @"No";
}

static NSString *CFDataShow(CFDataRef object) {
    UInt32 asciiNormalCount = 0;
    UInt32 asciiSymbolCount = 0;
    const UInt8 *bytes;
    CFIndex index;
    CFIndex length;

    NSMutableString *result = [[NSMutableString alloc] initWithString:@"<"];

    length = CFDataGetLength(object);
    bytes = CFDataGetBytePtr(object);

    //
    // This algorithm detects ascii strings, or a set of ascii strings, inside a
    // stream of bytes.  The string, or last string if in a set, needn't be null
    // terminated.  High-order symbol characters are accepted, unless they occur
    // too often (80% of characters must be normal).  Zero padding at the end of
    // the string(s) is valid.  If the data stream is only one byte, it is never
    // considered to be a string.
    //

    for (index = 0; index < length; index++) {  // (scan for ascii string/strings)

        if (bytes[index] == 0) {      // (detected null in place of a new string,
            //  ensure remainder of the string is null)
            for (; index < length && bytes[index] == 0; index++) {}

            break;          // (either end of data or a non-null byte in stream)
        } else {                       // (scan along this potential ascii string)

            for (; index < length; index++) {
                if (isprint(bytes[index])) {
                    asciiNormalCount++;
                } else if (bytes[index] >= 128 && bytes[index] <= 254) {
                    asciiSymbolCount++;
                } else {
                    break;
                }
            }

            if (index < length && bytes[index] == 0) {        // (end of string)
                continue;
            } else {
                break;
            }
        }
    }

    if ((asciiNormalCount >> 2) < asciiSymbolCount) {  // (is 80% normal ascii?)
        index = 0;
    } else if (length == 1) {                                // (is just one byte?)
        index = 0;
    }

    if (index >= length && asciiNormalCount) { // (is a string or set of strings?)
        Boolean quoted = FALSE;

        for (index = 0; index < length; index++) {
            if (bytes[index]) {
                if (quoted == FALSE) {
                    quoted = TRUE;
                    if (index) {
                        [result appendString:@",\""];
                    } else {
                        [result appendString:@"\""];
                    }
                }
                [result appendFormat:@"%c", bytes[index]];
            } else {
                if (quoted == TRUE) {
                    quoted = FALSE;
                    [result appendString:@"\""];
                } else {
                    break;
                }
            }
        }
        if (quoted == TRUE) {
            [result appendString:@"\""];
        }
    } else {                                 // (is not a string or set of strings)
        for (index = 0; index < length; index++) {
            [result appendFormat:@"%02x", bytes[index]];
        }
    }

    [result appendString:@">"];
    return result;
}

static void CFDictionaryShow_Applier(const void *key, const void *value, void *parameter) {

    NSMutableArray *translatedElements = (__bridge NSMutableArray *) (parameter);

    NSString *name = CFObjectShow(key);
    NSString *val = CFObjectShow(value);

    if (name) {
        [translatedElements addObject:[NSString stringWithFormat:@"%@ = %@", name, val ?: @"<Null>"]];
    }
}

static NSString *CFDictionaryShow(CFDictionaryRef object) {
    NSMutableArray *translatedElements = [NSMutableArray new];

    CFDictionaryApplyFunction(object, CFDictionaryShow_Applier, (__bridge void *) (translatedElements));

    return [NSString stringWithFormat:@"{%@}", [translatedElements componentsJoinedByString:@","]];
}

static NSString *CFNumberShow(CFNumberRef object) {
    long long number;

    if (CFNumberGetValue(object, kCFNumberLongLongType, &number)) {
        return [NSString stringWithFormat:@"%qd", number];
    }
    return @"<Nan>";
}

static NSString *CFObjectShow(CFTypeRef object) {
    CFTypeID type = CFGetTypeID(object);

    if (type == CFArrayGetTypeID()) return CFArrayShow(object);
    else if (type == CFBooleanGetTypeID()) return CFBooleanShow(object);
    else if (type == CFDataGetTypeID()) return CFDataShow(object);
    else if (type == CFDictionaryGetTypeID()) return CFDictionaryShow(object);
    else if (type == CFNumberGetTypeID()) return CFNumberShow(object);
    else if (type == CFSetGetTypeID()) return CFSetShow(object);
    else if (type == CFStringGetTypeID()) return CFStringShow(object);
    else return @"<unknown object>";
}

static void CFSetShow_Applier(const void *value, void *parameter) {
    NSMutableArray *translatedElements = (__bridge NSMutableArray *) (parameter);
    NSString *objectValue = CFObjectShow(value);

    if (objectValue) {
        [translatedElements addObject:objectValue];
    }
}

static NSString *CFSetShow(CFSetRef object) {
    NSMutableArray *translatedElements = [NSMutableArray new];
    CFSetApplyFunction(object, CFSetShow_Applier, (__bridge void *) (translatedElements));
    return [NSString stringWithFormat:@"[%@]", [translatedElements componentsJoinedByString:@","]];
}

static NSString *CFStringShow(CFStringRef object) {

    NSString *stringToShow = @"";

    const char *c = CFStringGetCStringPtr(object, kCFStringEncodingMacRoman);

    if (c) {
        return [NSString stringWithFormat:@"%s", c];
    } else {
        CFIndex bufferSize = CFStringGetLength(object) + 1;
        char *buffer = malloc(bufferSize);

        if (buffer) {
            if (CFStringGetCString(object, buffer, bufferSize, kCFStringEncodingMacRoman)) {
                stringToShow = [NSString stringWithFormat:@"%s", buffer];
            }

            free(buffer);
        }
    }
    return stringToShow;
}

@end
