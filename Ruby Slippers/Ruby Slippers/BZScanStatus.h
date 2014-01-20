//
//  BZScanStatus.h
//  Ruby Slippers
//
//  Created by Jeff Squyres on 1/20/2014.
//  Copyright (c) 2014 Wailing Banshees. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@interface BZScanStatus : NSObject

@property (strong, atomic) NSString *name;
@property (strong, atomic) CLBeaconRegion *region;
@property (strong, atomic) NSString *scanning;
@property (strong, atomic) NSString *status;
@property (strong, atomic) NSString *distance;

@end
