//
//  ELLViewController.m
//  IOKitTest
//
//  Created by Christopher Anderson on 26/12/2013.
//  Copyright (c) 2013 Electric Labs. All rights reserved.
//

#import "ELLViewController.h"
#import "ELLIOKitNodeInfo.h"
#import "ELLIOKitDumper.h"
#import "ELLIOKitViewModel.h"
#import <KVOController/FBKVOController.h>

@interface ELLCopyMenuItem : UIMenuItem
@property (nonatomic, strong) NSString *IOKitText;
@end

@implementation ELLCopyMenuItem
@end

@interface ELLViewController () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@property(nonatomic, strong) ELLIOKitNodeInfo *root;
@property(nonatomic, strong) ELLIOKitNodeInfo *locationInTree;

@property(nonatomic, strong) IBOutlet UITableView *tableView;
@property(nonatomic, strong) IBOutlet UIActivityIndicatorView *spinner;
@property(nonatomic, strong) IBOutlet UISearchBar *searchBar;
@property(nonatomic, strong) IBOutlet UITextView *trailLabel;
@property(nonatomic, strong) IBOutlet UIView *trailHolder;
@property(nonatomic, strong) IBOutlet NSLayoutConstraint *textHeightConstraint;

@property (nonatomic, strong) UITableViewCell *sizingCell;

@property(nonatomic, strong) NSMutableArray *trailStack;
@property(nonatomic, strong) NSMutableArray *offsetStack;

@property (nonatomic, strong) UIBarButtonItem *refreshButton;

@property(nonatomic, copy) NSString *searchTerm;

@property(nonatomic, strong) NSTimer *searchDelayTimer;
@property(nonatomic, strong) FBKVOController *KVOController;
@property(nonatomic, assign) BOOL menuVisible;

@end

@implementation ELLViewController

static NSString *kSearchTerm = @"kSearchTerm";

- (void)awakeFromNib {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];
    self.KVOController = [[FBKVOController alloc] initWithObserver:self];


}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_searchDelayTimer invalidate];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.viewModel load];
}


- (void)viewDidLoad {
    [super viewDidLoad];
    self.sizingCell = [self.tableView dequeueReusableCellWithIdentifier:@"ELLViewControllerCellPropertiesIdentifier"];
    self.refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refresh:)];
    self.navigationItem.rightBarButtonItem = self.refreshButton;
}


- (void)setViewModel:(ELLIOKitViewModel *)viewModel {
    if (viewModel != _viewModel) {
        _viewModel = viewModel;
        
        [self.KVOController observe:viewModel keyPath:@"state" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew block:^(ELLViewController *observer, ELLIOKitViewModel *model, NSDictionary *change) {
            
            observer.title = model.title;
            
            switch (model.state) {
                case ELLIOKitViewModelStateLoaded: {
                    observer.tableView.hidden = NO;
                    [observer.spinner stopAnimating];
                    [observer.tableView reloadData];
                    
                    observer.refreshButton.enabled = YES;
                    
                    observer.title = observer.viewModel.title;
                    observer.searchBar.text = observer.viewModel.filterTerm;
                    
                    observer.trailLabel.hidden = NO;
                    observer.trailLabel.attributedText = observer.viewModel.trail;
                   
                    CGSize sizeThatShouldFitTheContent = [observer.trailLabel sizeThatFits:CGSizeMake(CGRectGetWidth(observer.view.bounds), CGFLOAT_MAX)];
                    observer.textHeightConstraint.constant = sizeThatShouldFitTheContent.height;

                }
                    break;
                case ELLIOKitViewModelStateSearching:{
                    [observer.spinner startAnimating];
                }
                    break;
                case ELLIOKitViewModelStateLoading: {
                    observer.tableView.hidden = YES;
                    observer.refreshButton.enabled = NO;
                    observer.trailLabel.hidden = YES;
                    [observer.spinner startAnimating];
                }
                    break;
                default:
                    break;
            }
        }];
        
    }
}

- (void)refresh:(id)sender {
    [self.viewModel refresh];
}


#pragma mark UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.viewModel numberOfRowsInSection:section];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.viewModel.numberOfSections;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [self.viewModel titleForHeaderInSection:section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"ELLViewControllerCellPropertiesIdentifier";

    UITableViewCell *cell = [_tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    }
    
    UILabel *textLabel = (UILabel *)[cell viewWithTag:101];
    textLabel.attributedText = [self.viewModel titleForIndexPath:indexPath];
    
    cell.accessoryType = [self.viewModel hasChildren:indexPath] ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;

    return cell;
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    UILabel *textLabel = (UILabel *)[self.sizingCell viewWithTag:101];
    textLabel.attributedText = [self.viewModel titleForIndexPath:indexPath];
    CGSize calcualtedSize = [textLabel sizeThatFits:CGSizeMake(CGRectGetWidth(tableView.bounds) - 16.0f, CGFLOAT_MAX)];
    return MIN(600.0f, calcualtedSize.height + 30.0f);
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (![self.viewModel hasChildren:indexPath]) {
        UIMenuController *menuController = [UIMenuController sharedMenuController];
        
        if (self.menuVisible) {
            [self resignFirstResponder];
            [menuController setMenuVisible:NO animated:YES];
            self.menuVisible = NO;
        } else {
            [self becomeFirstResponder];
            NSString *IOKitTextForRow = [self.viewModel titleForIndexPath:indexPath].string;
            ELLCopyMenuItem *copyMenuItem = [[ELLCopyMenuItem alloc] initWithTitle:@"Copy" action:@selector(copyMenuButtonPressed:)];
            copyMenuItem.IOKitText = IOKitTextForRow;
            menuController.menuItems = @[copyMenuItem];
            [menuController setTargetRect:[self.tableView rectForRowAtIndexPath:indexPath] inView:self.tableView];
            [menuController setMenuVisible:YES animated:YES];
            self.menuVisible = YES;
        }

    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark segways

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"showChild"]) {
        ELLViewController *viewController = segue.destinationViewController;
        
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        ELLIOKitViewModel *viewModel = [self.viewModel viewModelForIndexPath:indexPath];
        viewController.viewModel = viewModel;
    }
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender  {
    if ([identifier isEqualToString:@"showChild"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        return [self.viewModel hasChildren:indexPath];
    }
    return NO;
}


#pragma mark UISearchBar

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchTerm {
    [_searchDelayTimer invalidate];
    self.searchDelayTimer = [NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(_searchWithTimer:)
                                                           userInfo:@{kSearchTerm : searchTerm}
                                                            repeats:NO];
}

- (void)_searchWithTimer:(NSTimer *)timer {
    NSString *searchTerm = timer.userInfo[kSearchTerm];
    if(searchTerm.length > 1) {
        self.searchTerm = searchTerm;
        [self.viewModel filterModelByTerm:searchTerm];
    } else {
        self.searchTerm = nil;
        [self.viewModel clearFilter];
    }
    [_tableView reloadData];
}

#pragma mark

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)copyMenuButtonPressed:(UIMenuController *)menuController {
    [self resignFirstResponder];
    ELLCopyMenuItem *copyMenuItem = [menuController menuItems][0];
    if (copyMenuItem.IOKitText.length) {
        [UIPasteboard generalPasteboard].string = copyMenuItem.IOKitText;
    }
}

#pragma mark Keyboard

- (void)keyboardWasShown:(NSNotification *)aNotification {
    NSDictionary *info = [aNotification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;

    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbSize.height, 0.0);
    _tableView.contentInset = contentInsets;
    _tableView.scrollIndicatorInsets = contentInsets;

}

- (void)keyboardWillBeHidden:(NSNotification *)aNotification {
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    _tableView.contentInset = contentInsets;
    _tableView.scrollIndicatorInsets = contentInsets;
}

#pragma mark
- (IBAction)textTapped:(UITapGestureRecognizer *)recognizer {
    UITextView *textView = (UITextView *)recognizer.view;
    
    
    NSLayoutManager *layoutManager = textView.layoutManager;
    CGPoint location = [recognizer locationInView:textView];
    location.x -= textView.textContainerInset.left;
    location.y -= textView.textContainerInset.top;
    
    // Find the character that's been tapped on
    
    NSUInteger characterIndex;
    characterIndex = [layoutManager characterIndexForPoint:location
                                           inTextContainer:textView.textContainer
                  fractionOfDistanceBetweenInsertionPoints:NULL];
    
    if (characterIndex < textView.textStorage.length) {
        
        NSRange range;
        NSNumber *index = [self.viewModel.trail attribute:kDepthAttribute atIndex:characterIndex effectiveRange:&range];
    
        NSArray *viewControllers = self.navigationController.viewControllers;
        [self.navigationController popToViewController:viewControllers[index.integerValue] animated:YES];
        
    }
}

@end
