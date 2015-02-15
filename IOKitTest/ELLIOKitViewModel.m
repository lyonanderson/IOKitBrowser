//
//  ELLIOKitViewModel.m
//  IOKitBrowser
//
//  Created by Christopher Anderson on 25/11/2014.
//  Copyright (c) 2014 Electric Labs. All rights reserved.
//

#import "ELLIOKitViewModel.h"
#import "ELLIOKitNodeInfo.h"
#import "ELLIOKitDumper.h"

#define RGBCOLOR(r,g,b) [UIColor colorWithRed:(r)/255.0f green:(g)/255.0f blue:(b)/255.0f alpha:1]

@interface ELLIOKitViewModel ()
@property (nonatomic, readwrite, strong) ELLIOKitNodeInfo *nodeInfo;
@property (nonatomic, readwrite, copy) NSString *filterTerm;
@property (nonatomic, readwrite, assign) ELLIOKitViewModelState state;
@property (nonatomic, readwrite, copy) NSString *title;
@property (nonatomic, readwrite, copy) NSAttributedString *trail;
@end

@implementation ELLIOKitViewModel

NSString * const kDepthAttribute = @"kDepthAttribute";

- (instancetype)initWithNodeInfo:(ELLIOKitNodeInfo *)nodeInfo filterTerm:(NSString *)filterTerm {
    self = [super init];
    if (self) {
        self.nodeInfo = nodeInfo;
        self.filterTerm = filterTerm;
    }
    return self;
}


- (void)load {
    if (!_nodeInfo) {
        [self _load];
    } else {
        self.state = ELLIOKitViewModelStateLoaded;
    }
}

- (void)refresh {
    [self _load];
}

- (void)_load {
    self.state = ELLIOKitViewModelStateLoading;
    ELLIOKitDumper *dumper = [ELLIOKitDumper sharedInstance];
    [dumper dumpIOKitTreeFromNode:self.nodeInfo completion:^(ELLIOKitNodeInfo *nodeInfo) {
        self.nodeInfo = nodeInfo;
        if (self.filterTerm.length) {
            [self.nodeInfo searchForTerm:self.filterTerm];
        }
        self.state = ELLIOKitViewModelStateLoaded;
    }];
}

-(void)setNodeInfo:(ELLIOKitNodeInfo *)nodeInfo {
    if (_nodeInfo != nodeInfo) {
        [_nodeInfo.parent replaceChild:_nodeInfo withChild:nodeInfo];
        _nodeInfo = nodeInfo;
        self.title = nodeInfo.name;
    }
}

- (void)filterModelByTerm:(NSString *)filterTerm {
    self.state = ELLIOKitViewModelStateSearching;
    [self.nodeInfo searchForTerm:filterTerm];
    self.filterTerm = filterTerm;
    self.state = ELLIOKitViewModelStateLoaded;
}

- (void)clearFilter {
    self.filterTerm = nil;
}

- (ELLIOKitViewModel *) viewModelForIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1){
        ELLIOKitNodeInfo *childNode = [self _childrenForLocation][indexPath.row];
        ELLIOKitViewModel *childViewModel = [[ELLIOKitViewModel alloc] initWithNodeInfo:childNode filterTerm:self.filterTerm];
        return childViewModel;
    }
    return  nil;
}

- (BOOL) hasChildren:(NSIndexPath *)indexPath {
    return indexPath.section == 1;
}

- (NSAttributedString *) titleForIndexPath:(NSIndexPath *)indexPath {
    NSString *cellText = @"";
    if (indexPath.section == 0) {
        cellText = [self _propertiesForLocation][indexPath.row];
        
    } else {
        ELLIOKitNodeInfo *childNode = [self _childrenForLocation][indexPath.row];
        
        cellText = [NSString stringWithFormat:@"%@ %@", childNode.name,
                    childNode.searchCount && _filterTerm.length ? [NSString stringWithFormat:@"[%li]", (long) childNode.searchCount] : @""];
    }
    
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:cellText];
    [self _highlightSearchTerm:self.filterTerm inText:text];
    
    return text;
}

- (NSString *) titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return [[self _propertiesForLocation] count] ? @"Properties" : @"";
    } else {
        return [[self _childrenForLocation] count] ? @"Children" : @"";
    }
}


- (NSInteger) numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return [[self _propertiesForLocation] count];
    } else {
        return [[self _childrenForLocation] count];
    }
    
}

- (NSInteger)numberOfSections {
    return 2;
}


#pragma mark Helpers

- (NSAttributedString *) trail {

    
    NSMutableArray *stack = [@[self.nodeInfo.name ?: @"<NO NAME>"] mutableCopy];
    ELLIOKitNodeInfo *node = self.nodeInfo.parent;
    while (node != nil) {
        [stack addObject:node.name ?: @"Root"];
        node = node.parent;
    }
    
    NSArray *reversedStack = [[stack reverseObjectEnumerator] allObjects];
    
    NSMutableAttributedString *trail = [[NSMutableAttributedString alloc] init];
    [reversedStack enumerateObjectsUsingBlock:^(NSString *element, NSUInteger idx, BOOL *stop) {
        NSAttributedString *trailElement = [[NSAttributedString alloc] initWithString:element
                                                                           attributes:@{ kDepthAttribute: @(idx),
                                                                                         NSFontAttributeName : [UIFont systemFontOfSize:14.0] }];
        [trail appendAttributedString:trailElement];
        if (idx < reversedStack.count - 1) {
            NSAttributedString *chevron = [[NSAttributedString alloc] initWithString:@" → "];
            [trail appendAttributedString:chevron];

        }
    }];
    
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineHeightMultiple = 1.2f;
    
    [trail addAttributes:@{NSParagraphStyleAttributeName : paragraphStyle} range:NSMakeRange(0, trail.length)];
    
    return trail;
}

- (NSArray *)_propertiesForLocation {
    return self.filterTerm.length ? self.nodeInfo.matchingProperties : self.nodeInfo.properties;
}

- (NSArray *)_childrenForLocation {
    return (self.filterTerm.length ? self.nodeInfo.matchedChildren : self.nodeInfo.children);
}


- (void)_highlightSearchTerm:(NSString *)searchTerm inText:(NSMutableAttributedString *)text {
    if (searchTerm.length) {
        NSDictionary *attrs = @{NSBackgroundColorAttributeName : [UIColor yellowColor]};
        
        NSRange range = [text.string rangeOfString:searchTerm options:NSCaseInsensitiveSearch];
        while (range.location != NSNotFound) {
            [text setAttributes:attrs range:range];
            range = [text.string rangeOfString:searchTerm
                                       options:NSCaseInsensitiveSearch
                                         range:NSMakeRange(range.location + 1, [text length] - range.location - 1)];
        }
        
    }
}




@end
