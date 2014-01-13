//
//  BZBLEController.h
//  Ruby Slippers
//
//  Created by Jeff Squyres on 1/12/2014.
//  Copyright (c) 2014 Wailing Banshees. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreBluetooth/CoreBluetooth.h>

#import "BZFirstViewController.h"

@interface BZBLEController : UIViewController <CLLocationManagerDelegate>

@property (readonly) BOOL isScanning;

- (BZBLEController*)init: (BZFirstViewController*)withController;

- (void) startScanning;

- (void) stopScanning;

@end
