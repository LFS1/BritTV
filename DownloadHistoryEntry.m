//
//  DownloadHistoryEntry.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 10/15/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "DownloadHistoryEntry.h"


@implementation DownloadHistoryEntry
-(id)initWithPID:(NSString *)pid ProgrammeName:(NSString *)programmeName EpisodeName:(NSString *) episodeName;
{
	if (!(self = [super init])) return nil;
	
	_productionId = pid;
	_programmeName = [programmeName capitalizedString];
	_episodeName = episodeName;
	
	NSDate *now = [NSDate date];
	NSDateFormatter *df = [[NSDateFormatter alloc]init];
	[df setDateFormat:@"yyyy-MM-dd' at 'HH:mm:ss"];
	_dateTimeRecorded = [df stringFromDate:now];
	
	return self;
}
- (NSString *)entryString
{
	return [NSString stringWithFormat:@"%@|%@|%@|%@",_productionId, _dateTimeRecorded, _programmeName, _episodeName];
}
	


@end
