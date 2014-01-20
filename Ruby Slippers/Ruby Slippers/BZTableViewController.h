//
//  BZTableViewController.h
//  Ruby Slippers
//
//  Created by Jeff Squyres on 1/19/2014.
//  Copyright (c) 2014 Wailing Banshees. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BZController.h"

@interface BZTableViewController : UITableViewController <UITableViewDataSource, ControllerNotify>

-(void) setStatus:(NSString*) status;
-(void) reloadScanStatus;

@end
