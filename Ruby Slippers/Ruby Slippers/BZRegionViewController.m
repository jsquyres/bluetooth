//
//  BZRegionViewController.m
//  Ruby Slippers
//
//  Created by Jeff Squyres on 1/20/2014.
//  Copyright (c) 2014 Wailing Banshees. All rights reserved.
//

#import "BZRegionViewController.h"
#import "BZAppData.h"
#import "BZScanStatus.h"
#import "BZAllRegionsViewController.h"

@interface BZRegionViewController ()

@property (atomic, weak) BZAppData *appData;

@property (atomic) BOOL initialized;
@property (weak, nonatomic) IBOutlet UINavigationItem *ViewTitle;
@property (weak, nonatomic) IBOutlet UITableViewCell *CellName;
@property (weak, nonatomic) IBOutlet UITableViewCell *CellUUID;
@property (weak, nonatomic) IBOutlet UITableViewCell *CellScanning;
@property (weak, nonatomic) IBOutlet UITableViewCell *CellTimestamp;
@property (weak, nonatomic) IBOutlet UITableViewCell *CellStatus;
@property (weak, nonatomic) IBOutlet UITableViewCell *CellMajor;
@property (weak, nonatomic) IBOutlet UITableViewCell *CellMinor;
@property (weak, nonatomic) IBOutlet UITableViewCell *CellDistance;
@property (weak, nonatomic) IBOutlet UITableViewCell *CellRSSI;

@end

@implementation BZRegionViewController

enum RowNames {
    RowName,
    RowUUID,
    RowScanning,
    RowTimestamp,
    RowStatus,
    RowMajor,
    RowMinor,
    RowDistance,
    RowRSSI,
    RowMax
};

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // JMS Not sure when this is invoked
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // This controller seems to actually be destroyed when you click the "Done" button (but "dealloc" isn't fired... hmmm...).  So we don't want to just get the shared app data *once* -- we want to get it whenever we don't have it (i.e., when it's set to nil).
    if (nil == _appData) {
        _appData = [BZAppData sharedAppData];

        // Register this view controller with the BZController
        [_appData.controller registerController:self];

        _initialized = true;
    }

    [_appData.controller didLoad];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// When this object goes away, deregister it from the controller
- (void) dealloc
{
    [_appData.controller deregisterController:self];
}

#pragma mark - Table view data source

// We only have 1 section
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

// Return the number of rows
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return RowMax;
}

// Render each cell
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"RegionView rendering cell for row %ld, status index %d", (long)indexPath.row, self.statusIndexToView);
    BZScanStatus *status = [_appData.scanStatus objectAtIndex:self.statusIndexToView];

    UITableViewCell *cell;
    NSString *tmp;
    CLBeacon *beacon = [status.foundBeacons firstObject];
    switch (indexPath.row) {
        case RowName:
            cell = self.CellName;
            cell.textLabel.text = @"Name";
            cell.detailTextLabel.text = status.name;
            break;

        case RowUUID:
            cell = self.CellUUID;
            cell.textLabel.text = @"UUID";
            cell.detailTextLabel.text = status.beaconRegion.proximityUUID.UUIDString;
            break;

        case RowScanning:
            cell = self.CellScanning;
            cell.textLabel.text = @"Scanning";
            cell.detailTextLabel.text = status.scanning;
            break;

        case RowTimestamp:
            cell = self.CellTimestamp;
            cell.textLabel.text = @"Last timestamp";
            cell.detailTextLabel.text = status.statusTimestamp.description;
            break;

        case RowStatus:
            cell = self.CellStatus;
            cell.textLabel.text = @"Status";
            cell.detailTextLabel.text = status.status;
            break;

        case RowMajor:
            cell = self.CellMajor;
            cell.textLabel.text = @"Major";
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", beacon.major];
            break;

        case RowMinor:
            cell = self.CellMinor;
            cell.textLabel.text = @"Minor";
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", beacon.minor];
            break;

        case RowDistance:
            cell = self.CellDistance;
            cell.textLabel.text = @"Distance";
            switch (beacon.proximity) {
                case CLProximityImmediate: tmp = @"Immediate"; break;
                case CLProximityNear:      tmp = @"Near"; break;
                case CLProximityFar:       tmp = @"Far"; break;
                default:                   tmp = @"Unknown distance"; break;
            }
            cell.detailTextLabel.text = tmp;
            break;

        case RowRSSI:
            cell = self.CellRSSI;
            cell.textLabel.text = @"RSSI";
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%d", beacon.rssi];
            break;

        default:
            return nil;
    }

    return cell;
}

// User tapped the "done" button
- (IBAction)done:(id)sender
{
    NSLog(@"RegionView \"done\" delegate");
    [self.delegate BZRegionViewControllerDidDone:self];
}

// Set the status message
-(void) setStatusMessage:(NSString*)statusMessage
{
    NSLog(@"RegionView setStatus");
    // Do nothing
}

// Set the status message for a specific beacon
-(void) reRenderScanStatus
{
    NSLog(@"RegionView reloadScanStatus");
    // If the table has been initialized, then go ahead and re-draw it
    if (_initialized) {
        [self.tableView reloadData];
    }
}

@end
