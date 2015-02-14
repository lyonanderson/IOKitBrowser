//
//  ELLIOKitViewModel.h
//  IOKitBrowser
//
//  Created by Christopher Anderson on 25/11/2014.
//  Copyright (c) 2014 Electric Labs. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const kDepthAttribute;

typedef NS_ENUM(NSUInteger, ELLIOKitViewModelState) {
    ELLIOKitViewModelStateLoading,
    ELLIOKitViewModelStateSearching,
    ELLIOKitViewModelStateLoaded
};

@interface ELLIOKitViewModel : NSObject

@property (nonatomic, readonly, assign) ELLIOKitViewModelState state;
@property (nonatomic, readonly, copy) NSString *filterTerm;
@property (nonatomic, readonly, copy) NSString *title;
@property (nonatomic, readonly, copy) NSAttributedString *trail;

- (void)load;
- (void)refresh;
- (void)filterModelByTerm:(NSString *)filterTerm;
- (void)clearFilter;

- (ELLIOKitViewModel *) viewModelForIndexPath:(NSIndexPath *)indexPath;
- (BOOL) hasChildren:(NSIndexPath *)indexPath;

- (NSAttributedString *) titleForIndexPath:(NSIndexPath *)indexPath;
- (NSString *) titleForHeaderInSection:(NSInteger)section;
- (NSInteger) numberOfRowsInSection:(NSInteger)section;
- (NSInteger) numberOfSections;


@end
