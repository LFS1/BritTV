//
//  ReasonForFailure.m
//  Get_iPlayer GUI
//
//  Created by Thomas E. Willson on 8/3/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ReasonForFailure.h"

@implementation ReasonForFailure

- (id)init
{
	if (!(self = [super init])) return nil;
	shortEpisodeName = [[NSString alloc] init];
    solution = [[NSString alloc] init];
	return self;
}
@synthesize shortEpisodeName;
@synthesize solution;
@end
