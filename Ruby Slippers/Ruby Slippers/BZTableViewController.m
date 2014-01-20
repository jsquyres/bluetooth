//
//  BZTableViewController.m
//  Ruby Slippers
//
//  Created by Jeff Squyres on 1/19/2014.
//  Copyright (c) 2014 Wailing Banshees. All rights reserved.
//

#import "BZTableViewController.h"
#import "BZAppData.h"
#import "BZScanStatus.h"

@interface BZTableViewController ()

@property (atomic, weak) BZAppData *appData;

@property (atomic, strong) NSMutableArray *rows;
@property (atomic) BOOL initialized;

@end

@implementation BZTableViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // JMS not sure when this is invoked...
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

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // We only have 1 section
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section
{
    NSLog(@"Returning %lu rows...", (unsigned long)[_appData.scanStatus count]);

    // Return the number of regions in the shared data
    return [_appData.scanStatus count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"row";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];

    BZScanStatus *status = _appData.scanStatus[indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"%@ (%@,%@)",
                           status.name, status.scanning, status.status];

    NSString *uuidString = [status.region.proximityUUID.UUIDString substringToIndex:8];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"UUID:%@, m/m:%@/%@)",
                                 uuidString,
                                 status.region.major,
                                 status.region.minor];

    NSLog(@"Rendering row %lda: %@", (long)indexPath.row, cell.textLabel.text);
    NSLog(@"Rendering row %ldb: %@", (long)indexPath.row, cell.detailTextLabel.text);

    return cell;
}

- (NSString *)tableView:(UITableView *)tableView
titleForHeaderInSection:(NSInteger)section
{
    return @"Beacons by identifier";
}

/*
#pragma mark - Navigation

// In a story board-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}

 */

// Set the status message
-(void) setStatus:(NSString*) status
{
    // Do nothing
}

// Set the status message for a specific beacon
-(void) reloadScanStatus
{
    // If the table has been initialized, then go ahead and re-draw it
    if (_initialized) {
        [self.tableView reloadData];
    }
}

@end
