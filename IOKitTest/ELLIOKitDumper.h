//
//  ELLIOKitDumper.h
//  IOKitTest
//
//  Created by Christopher Anderson on 10/02/2014.
//  Copyright (c) 2014 Electric Labs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IOKitDefines.h"

@class ELLIOKitNodeInfo;

@interface ELLIOKitDumper : NSObject

+ (instancetype)sharedInstance;
- (void)dumpIOKitTreeFromNode:(ELLIOKitNodeInfo *)fromNode completion:(void(^)(ELLIOKitNodeInfo *nodeInfo))completion;
- (void)releaseIOKitService:(io_registry_entry_t)service;
- (void)retainIOKitService:(io_registry_entry_t)service;

@end
