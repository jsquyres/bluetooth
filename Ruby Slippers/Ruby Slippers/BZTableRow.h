//
//  BZTableRow.h
//  Ruby Slippers
//
//  Created by Jeff Squyres on 1/19/2014.
//  Copyright (c) 2014 Wailing Banshees. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@interface BZTableRow : NSObject

@property (strong, atomic) NSString *identifier;
@property (strong, atomic) CLBeaconRegion *region;
@property (strong, atomic) NSString *status;

@end
