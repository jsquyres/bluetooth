//
//  BZController.h
//  Ruby Slippers
//
//  Created by Jeff Squyres on 1/19/2014.
//  Copyright (c) 2014 Wailing Banshees. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

#import "BZAppData.h"

@protocol ControllerNotify
- (void) setStatusMessage:(NSString*)statusMessage;
- (void) reRenderScanStatus;
@end

@interface BZController : UIViewController <CLLocationManagerDelegate>

@property (readonly) BOOL canScan;
@property (readonly) BOOL isScanning;

- (BZController*) initWithSharedAppData:(BZAppData*)data;
- (void) didLoad;
- (void) registerController:(NSObject <ControllerNotify> *) object;
- (void) deregisterController:(NSObject <ControllerNotify> *) object;
- (void) startScanning;
- (void) stopScanning;

@end
