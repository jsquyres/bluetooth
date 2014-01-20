//
//  BZController.h
//  Ruby Slippers
//
//  Created by Jeff Squyres on 1/19/2014.
//  Copyright (c) 2014 Wailing Banshees. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@protocol ControllerNotify
-(void) setStatus:(NSString*) status;
-(void) setIDStatus:(NSString*)identifier withRegion:(CLBeaconRegion*)region withStatus:(NSString*)status;
@end

@interface BZController : UIViewController <CLLocationManagerDelegate>

@property (readonly) BOOL canScan;
@property (readonly) BOOL isScanning;

- (BZController*) init;
- (void) didLoad;
- (void) registerController:(NSObject <ControllerNotify> *) object;
- (void) startScanning;
- (void) stopScanning;

@end
