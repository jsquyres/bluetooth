//
//  BZTableViewController.m
//  Ruby Slippers
//
//  Created by Jeff Squyres on 1/19/2014.
//  Copyright (c) 2014 Wailing Banshees. All rights reserved.
//

#import "BZTableViewController.h"
#import "BZAppData.h"
#import "BZTableRow.h"

@interface BZTableViewController ()

@property (weak, nonatomic) BZAppData *appData;
@property (strong, atomic) NSMutableArray *rows;
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

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [self.rows count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"row";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];

    BZTableRow *row = [self.rows objectAtIndex:indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"%@: %@", row.identifier, row.status];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"UUID:%@, major:%@, minor:%@)", row.region.proximityUUID.UUIDString, row.region.major, row.region.minor];

    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
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
-(void) setIDStatus:(NSString*)identifier withRegion:(CLBeaconRegion*)region withStatus:(NSString*)status;
{
    // Look through the rows array and see if we have this identifier already
    BOOL found = false;
    for (BZTableRow *row in _rows) {
        if (row.identifier == identifier) {
            found = true;
            row.region = region;
            row.status = status;
            NSLog(@"Updated old row");
        }
    }

    if (!found) {
        BZTableRow *row = [BZTableRow alloc];
        row.identifier = identifier;
        row.region = region;
        row.status = status;
        [_rows addObject:row];
        NSLog(@"Added new row! Now have %lu rows", (unsigned long) [_rows count]);
    }

    // If the table has been initialized, then go ahead and re-draw it
    if (_initialized) {
        // Make the table re-draw with the new data
        // Fun way (animated)
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:([_rows count] - 1) inSection:0];
        [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];

        // Boring way (no animation)
        //[self.tableView reloadData];
    }
}

@end
