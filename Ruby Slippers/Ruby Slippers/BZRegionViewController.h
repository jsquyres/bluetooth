//
//  BZRegionViewController.h
//  Ruby Slippers
//
//  Created by Jeff Squyres on 1/20/2014.
//  Copyright (c) 2014 Wailing Banshees. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BZController.h"
#import "BZScanStatus.h"

@class BZAllRegionsViewController;
@class BZRegionViewController;

@protocol BZRegionViewControllerDelegate <NSObject>
- (void)BZRegionViewControllerDidDone:(BZRegionViewController *)controller;
@end

@interface BZRegionViewController : UITableViewController <UITableViewDataSource, ControllerNotify>

@property (nonatomic, weak) id <BZRegionViewControllerDelegate> delegate;
@property (atomic) int statusIndexToView;

- (void) setStatusMessage:(NSString*)statusMessage;
- (void) reRenderScanStatus;
- (IBAction)done:(id)sender;

@end
