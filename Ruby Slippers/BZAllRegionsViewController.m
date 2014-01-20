//
//  BZAllRegionsViewController.m
//  Ruby Slippers
//
//  Created by Jeff Squyres on 1/20/2014.
//  Copyright (c) 2014 Wailing Banshees. All rights reserved.
//

#import "BZAllRegionsViewController.h"
#import "BZScanStatus.h"

@interface BZAllRegionsViewController ()

@property (atomic, weak) BZAppData *appData;

@property (atomic, strong) NSMutableArray *rows;
@property (atomic) BOOL initialized;
@property (atomic) int selectedRow;

@end

@implementation BZAllRegionsViewController

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

    // First time through, get the shared data
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSLog(@"TableViewController -- first time through, getting shared data");
        _appData = [BZAppData sharedAppData];

        // Register this view controller with the BZController
        [_appData.controller registerController:self];

        // Get an empty array of rows
        _rows = [[NSMutableArray alloc] init];

        _initialized = true;
    });

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

// Return how many sections we have
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // We only have 1 section
    return 1;
}

// Return how many rows we have
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of regions in the shared data
    return [_appData.scanStatus count];
}

// Render an individual cell
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"region";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];

    BZScanStatus *status = [_appData.scanStatus objectAtIndex:indexPath.row];

    UILabel *textLabel = (UILabel *)[cell viewWithTag:100];
    textLabel.text = status.name;
    NSLog(@"AllRegionsView rendering row: %@", status.name);

    UIImageView *slippersView = (UIImageView *)[cell viewWithTag:101];
    if (status.foundBeacons != nil) {
        slippersView.image = [UIImage imageNamed:@"ruby-slippers29x29.jpg"];
    } else {
        slippersView.image = nil;
    }

    return cell;
}

#pragma mark - BZRegionViewControllerDelegate

// For when the RegionView calls us back to say that the user tapped the Done button.  So it's time to make that controller view go away.
- (void)BZRegionViewControllerDidDone:(BZRegionViewController *)controller
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Navigation

// In a story board-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"RegionView"]) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
        UINavigationController *navigationController = segue.destinationViewController;
        BZRegionViewController *regionViewController = [navigationController viewControllers][0];
        regionViewController.delegate = self;
        NSLog(@"=======Segue for selected row: %d", self.selectedRow);
        regionViewController.statusIndexToView = self.selectedRow;
    }
}

- (NSIndexPath *)tableView:(UITableView *)tableView
  willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSLog(@"=======About to select row %ld", (long)indexPath.row);
    _selectedRow = indexPath.row;

    return indexPath;
}

#pragma mark - ControllerNotify

// Set the status message
-(void) setStatusMessage:(NSString*)statusMessage
{
    // Do nothing
}

// Set the status message for a specific beacon
-(void) reRenderScanStatus
{
    // If the table has been initialized, then go ahead and re-draw it
    if (_initialized) {
        [self.tableView reloadData];
    }
}

@end
