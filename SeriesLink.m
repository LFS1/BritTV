//
//  SeriesLink.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/19/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "SeriesLink.h"


@implementation SeriesLink
 - (id)init
{
	if (!(self = [super init])) return nil;
	programmeName = [[NSString alloc] init];
	tvNetwork = [[NSString alloc] init];
	return self;
}
- (id)initWithShowname:(NSString *)SHOWNAME
{
	if (!(self = [super init])) return nil;
	programmeName = [[NSString alloc] initWithString:SHOWNAME];
	tvNetwork = [[NSString alloc] init];
	return self;
}
- (void) encodeWithCoder: (NSCoder *)coder
{
	[coder encodeObject: programmeName forKey:@"programmeName"];
	[coder encodeObject: tvNetwork forKey:@"tvNetwork"];
}
- (id) initWithCoder: (NSCoder *)coder
{
	if (!(self = [super init])) return nil;
	programmeName = [[NSString alloc] initWithString:[coder decodeObjectForKey:@"programmeName"]];
	tvNetwork = [[NSString alloc] initWithString:[coder decodeObjectForKey:@"tvNetwork"]];
	return self;
}
- (id)description
{
	return [NSString stringWithFormat:@"%@ (%@)", showName,tvNetwork];
}
@synthesize programmeName;
@synthesize tvNetwork;
@end
