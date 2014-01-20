//
//  BZController.m
//  Ruby Slippers
//
//  Created by Jeff Squyres on 1/19/2014.
//  Copyright (c) 2014 Wailing Banshees. All rights reserved.
//

#import "BZController.h"
#import "BZScanStatus.h"

@interface BZController ()

@property (atomic, weak) BZAppData *appData;

@property (atomic) BOOL hardwareCanScan;
@property (atomic) BOOL haveAuthToScan;
@property (strong, atomic) CLLocationManager *locationManager;
@property (strong, atomic) NSMutableArray *viewControllers;

-(void) createRegion:(NSString*)name
        withUUID:(NSString*)uuidString;
-(void) setStatus:(NSString*) status;
-(void) reloadScanStatus;

@end

@implementation BZController

/////////////////////////////////////////////////////////////////////////////////////

- (BZController*) initWithSharedAppData:(BZAppData *)data
{
    NSLog(@"Initializing the BZController");

    _appData = data;
    _viewControllers = [[NSMutableArray alloc] init];
    _hardwareCanScan = false;

    // Is this device capable of scanning?
    if (! [CLLocationManager isMonitoringAvailableForClass:[CLBeaconRegion class]]) {
        [self setStatus:@"Scanning is not possible on this hardware"];
        _hardwareCanScan = FALSE;
        _canScan = FALSE;
    } else {
        _hardwareCanScan = TRUE;
        [self setStatus:@"Hardware supports scanning -- w00t"];

        // If the hardware supports it, create a location manager (even if we determine we don't have permission to do it, below, we might get permission in the future, so make the relevant objects now)
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;

        // Generated UUID from OS X "uuidgen" command
        [self createRegion:@"uuidgen-new"
                  withUUID:@"FADEBAAB-4D48-4868-B2C3-D98938F9DD74"];
        // From LightBlue, originally
        [self createRegion:@"lightBlue-1"
                  withUUID:@"00B9AA32-3606-C646-4D69-1F579B17AC50"];
        // From LightBlue, Jan 18 2014
        [self createRegion:@"lightblue-2"
                  withUUID:@"7d83899c-e72b-e451-95a9-0ad04c9e624f"];
        // RadiusNetworks / Apple's iBeacon uuid
        [self createRegion:@"apple-ibeacon"
                  withUUID:@"e2c56db5-dffb-48d2-b060-d0f5a71096e0"];

        [self setStatus:@"Created all identifiers"];
    }

    return self;
}

- (void) createRegion:(NSString*)name
         withUUID:(NSString*)uuidString
{
    // Create a region that we're looking for
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:uuidString];
    CLBeaconRegion *region = [[CLBeaconRegion alloc] initWithProximityUUID:uuid identifier:name];

    // Save a new BZScanStatus
    [_appData addScanStatus:name withRegion:region];

    // List it in the table view
    [self reloadScanStatus];
}

// Register a view controller to be notified when there's something to display
- (void) registerController:(NSObject <ControllerNotify> *) object
{
    [_viewControllers addObject:object];
    NSLog(@"BZController registered a ControllerNotify object (now have %lu)", (unsigned long)[_viewControllers count]);
}

// We were just loaded.
// Check to see if we have authorization to use location services
-(void) didLoad
{
    // If the hardware can't scan, don't bother doing anything
    if (!_hardwareCanScan) {
        return;
    }

    // Has this app been given permission to use location data?  This is a little tricky, because the app won't even show up in Settings -> Privacy -> Location Settings until you actually try to *use* Location Services.  So if we don't currently have authorization, make sure we go try to *use* them.
    // JMS Need to add that logic ^^
    // JMS Somehow have to respond to "now you [do|do not] have location services authorization" events

    if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorized) {
        [self setStatus:@"Location services are not enabled for this app"];
        _canScan = FALSE;
        return;
    }

    [self setStatus:@"App is authorized to use location data -- w00t"];
    _canScan = TRUE;

    // Do we have beacon ranging?
    if ([CLLocationManager isRangingAvailable]) {
        [self setStatus:@"Ranging is available -- w00t"];
    } else {
        [self setStatus:@"Ranging is not available"];
    }
}

/////////////////////////////////////////////////////////////////////////////////////

- (void) startScanning
{
    if (_isScanning) {
        NSLog(@"I'm already scanning -- not starting again!");
        return;
    }

    NSLog(@"I'm starting to scan...");
    for (BZScanStatus *status in _appData.scanStatus) {
        [self setStatus:[NSString stringWithFormat:@"Scanning for region named %@...", status.name]];
        status.scanning = @"starting to scan";

        // Start monitoring for the region, and start determining the state of us with respect to that region
        [_locationManager startMonitoringForRegion:status.region];
        [_locationManager requestStateForRegion:status.region];
    }

    _isScanning = TRUE;
    [self reloadScanStatus];
}

- (void) stopScanning
{
    if (! _isScanning) {
        NSLog(@"I'm already not scanning -- not stopping again!");
        return;
    }

    NSLog(@"I'm stopping scanning...");
    for (BZScanStatus *status in _appData.scanStatus) {
        [self.locationManager stopMonitoringForRegion:status.region];
        [self.locationManager stopRangingBeaconsInRegion:status.region];

        [self setStatus:[NSString stringWithFormat:@"Stopped scanning for region name %@", status.name]];
        status.scanning = @"not scanning";
        status.status = @"Unknown";
    }

    _isScanning = FALSE;
    [self reloadScanStatus];
}

/////////////////////////////////////////////////////////////////////////////////////

- (void)locationManager:(CLLocationManager *)manager
         didDetermineState:(CLRegionState)state
         forRegion:(CLRegion *)region
{
    NSString *str;
    switch (state) {
        case CLRegionStateInside: str = @"Inside"; break;
        case CLRegionStateOutside: str = @"Outside"; break;
        default: str = @"Unknown"; break;
    }

    // Lookup the BZScanStatus entry for this region
    BZScanStatus *status = [_appData getStatusByName:region.identifier];

    [self setStatus: [NSString stringWithFormat:@"Determined state for region name %@: %@",
                      status.name, str]];
    status.status = str;

    [self reloadScanStatus];
}

- (void)locationManager:(CLLocationManager *)manager
         didStartMonitoringForRegion:(CLRegion *)region
{
    // Lookup the BZScanStatus entry for this region
    BZScanStatus *status = [_appData getStatusByName:region.identifier];

    status.scanning = @"scanning";

    NSLog(@"Region monitoring started for %@", region.identifier);
    [self reloadScanStatus];
}

- (void)locationManager:(CLLocationManager *)manager
         didEnterRegion:(CLRegion *)region
{
    // Lookup the BZScanStatus entry for this region
    BZScanStatus *status = [_appData getStatusByName:region.identifier];

    [self setStatus: [NSString stringWithFormat:@"Entered region %@!", status.name]];
    status.status = @"Inside";

    [self reloadScanStatus];
}

-(void)locationManager:(CLLocationManager *)manager
         didExitRegion:(CLRegion *)region
{
    // Lookup the BZScanStatus entry for this region
    BZScanStatus *status = [_appData getStatusByName:region.identifier];

    [self setStatus: [NSString stringWithFormat:@"Left region %@", status.name]];
    status.status = @"Outside";

    [self reloadScanStatus];
}

-(void)locationManager:(CLLocationManager *)manager
         didRangeBeacons:(NSArray *)beacons
         inRegion:(CLBeaconRegion *)region
{
    // Lookup the BZScanStatus entry for this region
    BZScanStatus *status = [_appData getStatusByName:region.identifier];

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

        [self setStatus: [NSString stringWithFormat:@"Found range in %@: UUID:%@, Major/Minor:%@/%@, Accuracy:%f, Distance:%@, RSSI:%ld",
                          region.identifier,
                          beacon.proximityUUID.UUIDString,
                          beacon.major, beacon.minor, beacon.accuracy,
                          distance, (long)beacon.rssi]];
        status.distance = distance;
    }

    [self reloadScanStatus];
}

/////////////////////////////////////////////////////////////////////////////////////

-(void) setStatus:(NSString*) status
{
    NSLog(@"%@", status);
    for (NSObject <ControllerNotify> *item in _viewControllers) {
        [item setStatus:status];
    }
}

-(void) reloadScanStatus
{
    for (NSObject <ControllerNotify> *item in _viewControllers) {
        [item reloadScanStatus];
    }
}


@end
