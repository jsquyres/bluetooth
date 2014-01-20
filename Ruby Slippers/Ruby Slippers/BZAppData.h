//
//  BZAppData.h
//  Ruby Slippers
//
//  Created by Jeff Squyres on 1/19/2014.
//  Copyright (c) 2014 Wailing Banshees. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "BZController.h"

@interface BZAppData : NSObject

@property (nonatomic, retain) BZController *controller;

+ (id)sharedAppData;

@end
