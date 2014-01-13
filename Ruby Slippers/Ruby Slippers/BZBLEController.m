//
//  BZBLEController.m
//  Ruby Slippers
//
//  Created by Jeff Squyres on 1/12/2014.
//  Copyright (c) 2014 Wailing Banshees. All rights reserved.
//

#import "BZBLEController.h"
#import "BZFirstViewController.h"

@interface BZBLEController ()

@property (strong, nonatomic) CLBeaconRegion *beaconRegion1;
@property (strong, nonatomic) CLBeaconRegion *beaconRegion2;
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, readonly) BZFirstViewController *viewController;

- (void) printResults:(NSString*) results;

@end

@implementation BZBLEController

/////////////////////////////////////////////////////////////////////////////////////

- (BZBLEController*) init: (BZFirstViewController*)withController
{
    NSLog(@"Initializing the BZBLEController");

    _viewController = withController;

    // Create our location manager
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;

    // Create a region that we're looking for
    NSUUID *uuid;
    // Generated UUID from OS X "uuidgen" command
    uuid = [[NSUUID alloc] initWithUUIDString:@"FADEBAAB-4D48-4868-B2C3-D98938F9DD74"];
    self.beaconRegion1 = [[CLBeaconRegion alloc] initWithProximityUUID:uuid identifier:@"uuidgen"];
    // From LightBlue
    uuid = [[NSUUID alloc] initWithUUIDString:@"00B9AA32-3606-C646-4D69-1F579B17AC50"];
    uuid = [[NSUUID alloc] initWithUUIDString:@"00B9AA32-3606-C646-4D69-1F579B17AC50"];
    self.beaconRegion2 = [[CLBeaconRegion alloc] initWithProximityUUID:uuid identifier:@"lightblue"];

    [self.locationManager startMonitoringForRegion:self.beaconRegion1];

    return self;
}

/////////////////////////////////////////////////////////////////////////////////////

- (void) startScanning
{
    if (_isScanning) {
        NSLog(@"I'm already scanning -- not starting again!");
        return;
    }

    NSLog(@"I'm starting to scan...");
    [self.locationManager startMonitoringForRegion:self.beaconRegion1];
    [self.locationManager startMonitoringForRegion:self.beaconRegion2];

    // For kicks, start determining the status of this region
    [self.locationManager requestStateForRegion:self.beaconRegion1];
    [self.locationManager requestStateForRegion:self.beaconRegion2];

    _isScanning = TRUE;
}

- (void) stopScanning
{
    if (! _isScanning) {
        NSLog(@"I'm already not scanning -- not stopping again!");
        return;
    }

    NSLog(@"I'm stopping scanning...");
    [self.locationManager stopRangingBeaconsInRegion:self.beaconRegion1];
    [self.locationManager stopMonitoringForRegion:self.beaconRegion1];
    [self.locationManager stopRangingBeaconsInRegion:self.beaconRegion2];
    [self.locationManager stopMonitoringForRegion:self.beaconRegion2];
    _isScanning = FALSE;
}

/////////////////////////////////////////////////////////////////////////////////////

- (void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region
{
    NSString *str;
    switch (state) {
        case CLRegionStateInside: str = @"Inside"; break;
        case CLRegionStateOutside: str = @"Outside"; break;
        default: str = @"Unknown"; break;
    }
    NSString *msg = [NSString stringWithFormat:@"Determined state for region %@: %@",
                    region.identifier, str];
    NSLog(@"%@", msg);
    [_viewController printResults:msg];
}

- (void)locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region
{
    NSLog(@"Region monitoring started for %@", region.identifier);
    //[self.locationManager startRangingBeaconsInRegion:region];
}

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region
{
    NSString *msg = [NSString stringWithFormat:@"Entered region %@!  Starting ranging...",
                     region.identifier];
    [self printResults:msg];
//    [self.locationManager startRangingBeaconsInRegion:region];
}

-(void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region
{
    NSString *msg = [NSString stringWithFormat:@"Left region %@ (stopped ranging)",
                     region.identifier];
    [self printResults:msg];
//    [self.locationManager stopRangingBeaconsInRegion:region];
}

-(void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region
{
    CLBeacon *beacon = [[CLBeacon alloc] init];

    NSLog(@"Printing all the beacons in %@: %lu", region.identifier,
        (unsigned long)[beacons count]);
    for (beacon in beacons) {
        NSString *distance;
        switch (beacon.proximity) {
            case CLProximityImmediate: distance = @"Immediate"; break;
            case CLProximityNear: distance = @"Near"; break;
            case CLProximityFar: distance = @"Far"; break;
            default: distance = @"Unknown distance"; break;
        }

        NSString *msg = [NSString stringWithFormat:@"Found range in %@: UUID:%@, Major/Minor:%@/%@, Accuracy:%f, Distance:%@, RSSI:%ld",
                         region.identifier,
                         beacon.proximityUUID.UUIDString,
                         beacon.major, beacon.minor, beacon.accuracy,
                         distance, (long)beacon.rssi];
        [self printResults:msg];
    }
}

/////////////////////////////////////////////////////////////////////////////////////

-(void) printResults:(NSString *)results
{
    NSLog(@"%@", results);
    [_viewController printResults:results];

}

@end