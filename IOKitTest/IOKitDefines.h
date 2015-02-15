//
//  IOKitDefines.h
//  IOKitBrowser
//
//  Created by Christopher Anderson on 14/02/2015.
//  Copyright (c) 2015 Electric Labs. All rights reserved.
//

#ifndef IOKitBrowser_IOKitDefines_h
#define IOKitBrowser_IOKitDefines_h

#define kIOServicePlane    "IOService"

typedef mach_port_t io_object_t;
typedef io_object_t io_registry_entry_t;
typedef io_object_t io_iterator_t;
typedef char io_name_t[128];
typedef UInt32 IOOptionBits;

typedef io_object_t (* IOIteratorNextShim)(io_iterator_t iterator);

typedef kern_return_t (* IOObjectReleaseShim)(io_object_t object);

typedef kern_return_t (* IORegistryEntryGetNameInPlaneShim)(io_registry_entry_t entry,
                                                            const io_name_t plane,
                                                            io_name_t name);

typedef kern_return_t (* IOMasterPortShim)(mach_port_t bootstrapPort,  mach_port_t *masterPort);

typedef io_registry_entry_t (*IORegistryGetRootEntryShim)(mach_port_t);

typedef kern_return_t (* IORegistryEntryCreateCFPropertiesShim)(io_registry_entry_t entry,
                                                                CFMutableDictionaryRef *properties,
                                                                CFAllocatorRef allocator,
                                                                IOOptionBits options);


typedef kern_return_t (* IOObjectRetainShim)(io_object_t object);

typedef boolean_t (* IOObjectConformsToShim)(io_object_t object,
                                             const io_name_t className);


typedef kern_return_t (* IORegistryEntryGetChildIteratorShim)(io_registry_entry_t entry,
                                                              const io_name_t plane,
                                                              io_iterator_t *iterator);




#endif
