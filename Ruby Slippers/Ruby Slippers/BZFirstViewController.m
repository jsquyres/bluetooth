//
//  BZFirstViewController.m
//  Ruby Slippers
//
//  Created by Jeff Squyres on 1/12/2014.
//  Copyright (c) 2014 Wailing Banshees. All rights reserved.
//

#import "BZFirstViewController.h"

@interface BZFirstViewController ()

@end

static BOOL scanning = false;

static int numTimesOn = 0;
static int numTimesOff = 0;

@implementation BZFirstViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.

    if (scanning) {
        // Set the switch to on
        UISwitch *foo;
        [foo setOn:YES animated:NO];
    } else {
        // Set the switch to off
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)EnableBLEScanning:(UISwitch *)sender {
    if ([sender isOn]) {
        // They switched it on!  Party time!
        ++numTimesOn;
        scanning = true;
    } else {
        // They switched it off.  Sadness.
        ++numTimesOff;
        scanning = false;
    }
    
    return ....;
}

@end
