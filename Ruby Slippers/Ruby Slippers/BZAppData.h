//
//  BZAppData.h
//  Ruby Slippers
//
//  Created by Jeff Squyres on 1/19/2014.
//  Copyright (c) 2014 Wailing Banshees. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@class BZController;
@class BZScanStatus;

@interface BZAppData : NSObject

@property (atomic, strong) BZController *controller;
@property (atomic, strong) NSMutableArray *scanStatus;

+ (id)sharedAppData;

- (void) addScanStatus:(NSString*)name
      withBeaconRegion:(CLBeaconRegion*)beaconRegion;
- (BZScanStatus*)getStatusByName:(NSString*)name;
- (BZScanStatus*)getStatusByUUID:(NSString*)name;

@end
