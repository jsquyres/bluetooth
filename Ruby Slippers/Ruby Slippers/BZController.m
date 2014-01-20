//
//  BZController.m
//  Ruby Slippers
//
//  Created by Jeff Squyres on 1/19/2014.
//  Copyright (c) 2014 Wailing Banshees. All rights reserved.
//

#import "BZController.h"

@interface BZController ()

@property (strong, atomic) NSMutableDictionary *regionsByID;
@property (strong, atomic) NSMutableDictionary *IDsByRegion;
@property (strong, atomic) CLLocationManager *locationManager;
@property (strong, atomic) NSMutableArray *viewControllers;
@property (atomic) BOOL hardwareCanScan;
@property (atomic) BOOL haveAuthToScan;

-(void) createRegion:(NSString*)uuid withIdentifier:(NSString*)identifier;
-(void) setStatus:(NSString*) status;
-(void) setIDStatus:(NSString*)identifier withRegion:(CLRegion*)region withStatus:(NSString*)status;

@end

@implementation BZController

/////////////////////////////////////////////////////////////////////////////////////

- (BZController*) init
{
    NSLog(@"Initializing the BZController");

    self.viewControllers = [[NSMutableArray alloc] init];
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
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        self.regionsByID = [[NSMutableDictionary alloc] init];
        self.IDsByRegion = [[NSMutableDictionary alloc] init];

        // Generated UUID from OS X "uuidgen" command
        [self createRegion:@"FADEBAAB-4D48-4868-B2C3-D98938F9DD74" withIdentifier:@"uuidgen-new"];
        // From LightBlue, originally
        [self createRegion:@"00B9AA32-3606-C646-4D69-1F579B17AC50" withIdentifier:@"lightblue-1"];
        // From LightBlue, Jan 18 2014
        [self createRegion:@"7d83899c-e72b-e451-95a9-0ad04c9e624f" withIdentifier:@"lightblue-2"];
        // RadiusNetworks / Apple's iBeacon uuid
        [self createRegion:@"e2c56db5-dffb-48d2-b060-d0f5a71096e0" withIdentifier:@"apple-ibeacon"];
    }

    return self;
}

- (void) createRegion:(NSString*)uuid withIdentifier:(NSString*) identifier
{
    // Create a region that we're looking for
    NSUUID *newUuid = [[NSUUID alloc] initWithUUIDString:uuid];
    CLBeaconRegion *region = [[CLBeaconRegion alloc] initWithProximityUUID:newUuid identifier:identifier];

    // Save in the dictionary
    [self.regionsByID setObject:region forKey:identifier];
    [self.IDsByRegion setObject:identifier forKey:region];

    // List it in the table view
    [self setIDStatus:identifier withRegion:region withStatus:@"Not scanning"];
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
    for (id identifier in self.regionsByID) {
        CLBeaconRegion *region = [self.regionsByID objectForKey:identifier];
        [self setStatus:[NSString stringWithFormat:@"Scanning for %@ region...", identifier]];
        [self setIDStatus:identifier withRegion:region withStatus:@"Scanning..."];

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
    for (id identifier in self.regionsByID) {
        CLBeaconRegion *region = [self.regionsByID objectForKey:identifier];

        [self.locationManager stopMonitoringForRegion:region];
        [self.locationManager stopRangingBeaconsInRegion:region];

        [self setStatus:[NSString stringWithFormat:@"Stopped scanning for %@ region", identifier]];
        [self setIDStatus:identifier withRegion:region withStatus:@"Not scanning"];
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
    [self setStatus: [NSString stringWithFormat:@"Determined state for region %@: %@",
                      region.identifier, str]];
    [self setIDStatus:self.IDsByRegion[region] withRegion:region withStatus:str];
}

- (void)locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region
{
    NSLog(@"Region monitoring started for %@", region.identifier);
    //[self.locationManager startRangingBeaconsInRegion:region];
}

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region
{
    [self setStatus: [NSString stringWithFormat:@"Entered region %@! Starting ranging...",
                      region.identifier]];
    [self setIDStatus:self.IDsByRegion[region] withRegion:region withStatus:@"Entered!"];
}

-(void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region
{
    [self setStatus: [NSString stringWithFormat:@"Left region %@ (stopped ranging)",
                      region.identifier]];
    [self setIDStatus:self.IDsByRegion[region] withRegion:region withStatus:@"Exited!"];
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

        [self setStatus: [NSString stringWithFormat:@"Found range in %@: UUID:%@, Major/Minor:%@/%@, Accuracy:%f, Distance:%@, RSSI:%ld",
                          region.identifier,
                          beacon.proximityUUID.UUIDString,
                          beacon.major, beacon.minor, beacon.accuracy,
                          distance, (long)beacon.rssi]];
        [self setIDStatus:self.IDsByRegion[region] withRegion:region withStatus:distance];
    }
}

/////////////////////////////////////////////////////////////////////////////////////

-(void) setStatus:(NSString*) status
{
    NSLog(@"%@", status);
    for (NSObject <ControllerNotify> *item in _viewControllers) {
        [item setStatus:status];
    }
}

-(void) setIDStatus:(NSString*)identifier withRegion:(CLBeaconRegion*)region withStatus:(NSString*)status
{
    NSLog(@"%@ (UUID:%@,major:%@,minor:%@): %@", identifier, [region.proximityUUID UUIDString], region.major, region.minor, status);
    for (NSObject <ControllerNotify> *item in _viewControllers) {
        [item setIDStatus:identifier withRegion:region withStatus:status];
    }
}


@end
