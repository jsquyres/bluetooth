//
//  BZAppData.m
//  Ruby Slippers
//
//  Created by Jeff Squyres on 1/19/2014.
//  Copyright (c) 2014 Wailing Banshees. All rights reserved.
//

#import "BZAppData.h"
#import "BZController.h"
#import "BZScanStatus.h"

@interface BZAppData ()

@property (atomic, strong) NSMutableDictionary *indexByName;
@property (atomic, strong) NSMutableDictionary *indexByUUID;

@end


@implementation BZAppData

#pragma mark Singleton Methods

+ (id)sharedAppData {
    static BZAppData *sharedData = nil;

    // If this is the first time through, create the singleton object
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSLog(@"Creating shared app data");
        sharedData = [[self alloc] init];
    });

    return sharedData;
}

- (id)init {
    // If this is the first time through, initialize all the members
    if (self = [super init]) {
        NSLog(@"Initializing appdata");
        _scanStatus = [[NSMutableArray alloc] init];
        _indexByName = [[NSMutableDictionary alloc] init];
        _indexByUUID = [[NSMutableDictionary alloc] init];
        _controller = [[BZController alloc] initWithSharedAppData:self];
    }

    return self;
}

- (void)dealloc {
    // Should never be called, but just here for clarity really.
}

//////////////////////////////////////////////////////////////////////

- (void) addScanStatus:(NSString*)name withRegion:(CLBeaconRegion*)region
{
    // Make a BZScanStatus and save it in the ordered array
    BZScanStatus *status = [[BZScanStatus alloc] init];
    status.name = name;
    status.region = region;
    status.scanning = @"not scanning";
    status.status = @"Unknown";
    status.distance = @"Unknown";
    [_scanStatus addObject:status];

    // Now save lookup entries so that we can lookup BZScanStatus array indexes by region name and region UUID
    NSNumber *index = [NSNumber numberWithInteger:[_scanStatus count] - 1];
    _indexByName[name] = index;
    _indexByUUID[region.proximityUUID.UUIDString] = index;

    NSLog(@"We just saved scan status %@,%@ at index %lu", name, region.proximityUUID.UUIDString, (unsigned long) [_scanStatus count]);
}

- (BZScanStatus*)getStatusByName:(NSString*)name
{
    NSNumber *index = [_indexByName objectForKey:name];
    NSLog(@"Looking up status by name %@: found index %@", name, index);
    return [_scanStatus objectAtIndex:index.intValue];
}

- (BZScanStatus*)getStatusByUUID:(NSString*)uuidString
{
    NSNumber *index = [_indexByUUID objectForKey:uuidString];
    NSLog(@"Looking up status by UUID %@: found index %@", uuidString, index);
    return [_scanStatus objectAtIndex:index.intValue];
}

@end
