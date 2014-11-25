//
//  ELLIOKitNodeInfo.m
//  IOKitTest
//
//  Created by Christopher Anderson on 28/12/2013.
//  Copyright (c) 2013 Electric Labs. All rights reserved.
//

#import "ELLIOKitNodeInfo.h"


@implementation ELLIOKitNodeInfo


- (instancetype)init {
    self = [super init];
    if (self) {
        _children = [NSMutableArray new];
    }
    return self;
}

- (id)initWithParent:(ELLIOKitNodeInfo *)parent nodeInfoWithInfo:(NSString *)info properties:(NSArray *)properties {
    self = [self init];
    if (self) {
        _parent = parent;
        _name = info;
        _properties = properties;

    }
    return self;
}

- (void)addChild:(ELLIOKitNodeInfo *)child {
    [_children addObject:child];
}

- (void)searchForTerm:(NSString *)searchTerm {
    [self _searchForTerm:searchTerm inSubTree:self];
}

- (NSInteger)_searchForTerm:(NSString *)searchTerm inSubTree:(ELLIOKitNodeInfo *)subTree {
    __block NSInteger searchCount = 0;
    
    if ([subTree.name rangeOfString:searchTerm options:NSCaseInsensitiveSearch].location != NSNotFound) {
        searchCount++;
    }
    
    
    NSMutableArray *matchingProperties = [NSMutableArray new];
    
    [subTree.properties enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
        if ([obj rangeOfString:searchTerm options:NSCaseInsensitiveSearch].location != NSNotFound) {
            searchCount++;
            [matchingProperties addObject:obj];
        }
    }];
    
    
    NSMutableArray *matchedChildren = [NSMutableArray new];
    
    for (ELLIOKitNodeInfo *child in subTree.children) {
        NSInteger preThisPropertySearchCount = searchCount;
        searchCount += [self _searchForTerm:searchTerm inSubTree:child];
        if (searchCount > preThisPropertySearchCount) {
            [matchedChildren addObject:child];
        }
    }
    
    subTree.matchingProperties = matchingProperties;
    subTree.matchedChildren = matchedChildren;
    return subTree.searchCount = searchCount;
}

@end
