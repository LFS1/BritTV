//
//  ProgramHistoryObject.m
//  Get_iPlayer GUI
//
//  Created by LFS on 5/1/17.
//
//

#import <Foundation/Foundation.h>
#import "ProgrammeHistoryObject.h"


@implementation ProgrammeHistoryObject

- (id)initWithName:(NSString *)name andTVChannel:(NSString *)aTVChannel andDateFound:(NSString *)dateFound andSortKey:(NSUInteger)aSortKey andNetworkName:(NSString *)networkName
{
	
	self.sortKey        = aSortKey;
	self.programmeName  = name;
	self.dateFound      = dateFound;
	self.tvChannel      = aTVChannel;
	self.networkName    = networkName;
	
	return self;
}


- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:[NSNumber numberWithLong:self.sortKey] forKey:@"sortKey"];
	[encoder encodeObject:self.programmeName forKey:@"programmeName"];
	[encoder encodeObject:self.dateFound forKey:@"dateFound"];
	[encoder encodeObject:self.tvChannel forKey:@"tvChannel"];
	[encoder encodeObject:self.networkName forKey:@"networkName"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
	self = [super init];
	
	if (self != nil) {
		self.sortKey = [[decoder decodeObjectForKey:@"sortKey"] intValue];
		self.programmeName = [decoder decodeObjectForKey:@"programmeName"];
		self.dateFound = [decoder decodeObjectForKey:@"dateFound"];
		self.tvChannel = [decoder decodeObjectForKey:@"tvChannel"];
		self.networkName = [decoder decodeObjectForKey:@"networkName"];
	}
	
	return self;
}

- (BOOL)isEqual:(ProgrammeHistoryObject *)anObject
{
	return [self.programmeName isEqual:anObject.programmeName];
}

- (NSUInteger)hash
{
	return [self.programmeName hash];
}
@end


