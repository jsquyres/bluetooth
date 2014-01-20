//
//  BZFirstViewController.h
//  Ruby Slippers
//
//  Created by Jeff Squyres on 1/12/2014.
//  Copyright (c) 2014 Wailing Banshees. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BZController.h"

@interface BZFirstViewController : UIViewController <ControllerNotify>

-(void) setStatus:(NSString*) status;
-(void) reloadScanStatus;

@end
