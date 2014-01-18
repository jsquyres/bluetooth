//
//  BZBLEController.m
//  Ruby Slippers
//
//  Created by Jeff Squyres on 1/12/2014.
//  Copyright (c) 2014 Wailing Banshees. All rights reserved.
//

#import "BZBeacon.h"
#import "BZFirstViewController.h"

@interface BZBeacon ()

@property (strong, atomic) NSMutableDictionary *regions;
@property (strong, atomic) CLLocationManager *locationManager;
@property (strong, atomic) BZFirstViewController *viewController;

- (void) printResults:(NSString*)results;
- (void) createRegion:(NSString*)uuid withName:(NSString*)identifier;

@end

@implementation BZBeacon

/////////////////////////////////////////////////////////////////////////////////////

- (BZBeacon*) init: (BZFirstViewController*)withController
{
    NSLog(@"Initializing the BZBeacon");

    _viewController = withController;

    // Create our location manager
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;

    self.regions = [[NSMutableDictionary alloc] init];

    // Generated UUID from OS X "uuidgen" command
    [self createRegion:@"FADEBAAB-4D48-4868-B2C3-D98938F9DD74" withName:@"uuidgen"];
    // From LightBlue, originally
    [self createRegion:@"00B9AA32-3606-C646-4D69-1F579B17AC50" withName:@"lightblue-1"];
    // From LightBlue, Jan 18 2014
    [self createRegion:@"7d83899c-e72b-e451-95a9-0ad04c9e624f" withName:@"lightblue-2"];
    // Apple's iBeacon uuid
    [self createRegion:@"e2c56db5-dffb-48d2-b060-d0f5a71096e0" withName:@"apple-ibeacon"];
    // Radiusnetworks uuid
    [self createRegion:@"E2C56DB5-DFFB-48D2-B060-D0F5A71096E0" withName:@"RadiusNetworks"];

    return self;
}

- (void) createRegion:(NSString*)uuid withName:(NSString*)identifier
{
    // Create a region that we're looking for
    NSUUID *newUuid = [[NSUUID alloc] initWithUUIDString:uuid];
    CLBeaconRegion *region = [[CLBeaconRegion alloc] initWithProximityUUID:newUuid identifier:identifier];

    // Start looking for it
    [self.locationManager startMonitoringForRegion:region];

    // Save in the dictionary
    [self.regions setObject:region forKey:identifier];
}

/////////////////////////////////////////////////////////////////////////////////////

- (void) startScanning
{
    if (_isScanning) {
        NSLog(@"I'm already scanning -- not starting again!");
        return;
    }

    NSLog(@"I'm starting to scan...");
    for (id identifier in self.regions) {
        CLBeaconRegion *region = [self.regions objectForKey:identifier];
        NSLog(@"Scanning for %@ region...", identifier);

        // Start monitoring the region

        [self.locationManager startMonitoringForRegion:region];

        // For kicks, start determining the state of this region
        [self.locationManager requestStateForRegion:region];
    }

    _isScanning = TRUE;
}

- (void) stopScanning
{
    if (! _isScanning) {
        NSLog(@"I'm already not scanning -- not stopping again!");
        return;
    }

    NSLog(@"I'm stopping scanning...");
    for (id identifier in self.regions) {
        CLBeaconRegion *region = [self.regions objectForKey:identifier];
        NSLog(@"Stopping scanning for %@ region...", identifier);

        [self.locationManager stopMonitoringForRegion:region];
        [self.locationManager stopRangingBeaconsInRegion:region];
    }

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