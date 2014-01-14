//
//  BZFirstViewController.m
//  Ruby Slippers
//
//  Created by Jeff Squyres on 1/12/2014.
//  Copyright (c) 2014 Wailing Banshees. All rights reserved.
//

#import "BZFirstViewController.h"
#import "BZBeacon.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>


@interface BZFirstViewController ()

@property (weak, nonatomic) IBOutlet UISwitch *EnableBLEScanningSwitch;
@property (weak, nonatomic) IBOutlet UILabel *EnableBLEScanningLabel;
@property (weak, nonatomic) IBOutlet UITextView *ResultsLabel;
@property BZBeacon *controller;

- (void) enableUI;
- (void) disableUI;

@end


@implementation BZFirstViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.

    // Is this device capable of scanning?
    if (! [CLLocationManager isMonitoringAvailableForClass:[CLBeaconRegion class]]) {
        [self disableUI];
        [self printResults:@"Scanning not possible on this hardware, sorry"];
        NSLog(@"Scanning is not possible on this hardware -- switch is disabled");
        return;
    }
    NSLog(@"Hardware supports scanning -- w00t");

    // Has this app been given permission to use location data?  This is a little tricky, because the app won't even show up in Settings -> Privacy -> Location Settings until you actually try to *use* Location Services.  So if we don't currently have authorization, make sure we go try to *use* them.
    // JMS Need to add that logic ^^
    // JMS Somehow have to respond to "now you [do|do not] have location services authorization" events

    if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorized) {
        [self disableUI];
        [self printResults:@"You need to enable location services for this app"];
        NSLog(@"Location services are not enabled for this app -- switch is disabled");
        return;
    }
    NSLog(@"App is authorized to use location data -- w00t");

    // Do we have beacon ranging?
    if ([CLLocationManager isRangingAvailable]) {
        NSLog(@"Ranging is available -- w00t");
    }

    [self enableUI];
    NSLog(@"All scanning checks passed -- switch is enabled");

    // Allocate and initialize our BLE controller object
    if (Nil == _controller) {
        _controller = [[BZBeacon alloc] init:self];
    }

    [self EnableBLEScanning:self.EnableBLEScanningSwitch];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)enableUI
{
    _EnableBLEScanningSwitch.enabled = YES;
    _EnableBLEScanningLabel.enabled = YES;
}

- (void)disableUI
{
    _EnableBLEScanningSwitch.enabled = NO;
    _EnableBLEScanningLabel.enabled = NO;
}

- (void) printResults:(NSString*) label
{
    _ResultsLabel.text = label;
}

//
// Method invoked when the user toggles the "Enable scanning" switch
// on the view
//
- (IBAction)EnableBLEScanning:(UISwitch *)sender {
    if ([sender isOn]) {
        NSLog(@"They switched it on!  Party time!");
        [self printResults:@"Scanning..."];
        [_controller startScanning];
    } else {
        NSLog(@"They switched it off.  Sadness.");
        [self printResults:@"< Not scanning >"];
        [_controller stopScanning];
    }
}

@end
