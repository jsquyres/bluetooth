//
//  BZAppData.m
//  Ruby Slippers
//
//  Created by Jeff Squyres on 1/19/2014.
//  Copyright (c) 2014 Wailing Banshees. All rights reserved.
//

#import "BZAppData.h"

@implementation BZAppData

#pragma mark Singleton Methods

+ (id)sharedAppData {
    static BZAppData *sharedData = nil;

    // If this is the first time through, create the singleton object
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedData = [[self alloc] init];
    });

    return sharedData;
}

- (id)init {
    // If this is the first time through, initialize all the members
    if (self = [super init]) {
        _controller = [[BZController alloc] init];
    }

    return self;
}

- (void)dealloc {
    // Should never be called, but just here for clarity really.
}

@end
