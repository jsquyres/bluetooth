//
//  BZAllRegionsViewController.h
//  Ruby Slippers
//
//  Created by Jeff Squyres on 1/20/2014.
//  Copyright (c) 2014 Wailing Banshees. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BZController.h"
#import "BZRegionViewController.h"

@interface BZAllRegionsViewController : UITableViewController <UITableViewDataSource, ControllerNotify, BZRegionViewControllerDelegate>

- (void)BZRegionViewControllerDidDone:(BZRegionViewController *)controller;
- (void)setStatusMessage:(NSString*)statusMessage;
- (void)reRenderScanStatus;

@end
