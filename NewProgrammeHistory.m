//
//  NewProgrammeHistory.m
//  Get_iPlayer GUI
//
//  Created by LFS on 5/1/17.
//
//

#import <Foundation/Foundation.h>
#import "NewProgrammeHistory.h"
#import "ProgrammeHistoryObject.h"


@implementation NewProgrammeHistory

+ (NewProgrammeHistory *)sharedInstance
{
	static NewProgrammeHistory *sharedInstance = nil;
	static dispatch_once_t onceToken;
	
	dispatch_once(&onceToken, ^{
		sharedInstance = [[NewProgrammeHistory alloc] init];
	});
	
	return sharedInstance;
}

-(id)init
{
	if (self = [super init]) {
		
		itemsAdded = false;
		historyFilePath = @"~/Library/Application Support/BriTv/history.gia";
		historyFilePath= [historyFilePath stringByExpandingTildeInPath];
		programmeHistoryArray = [NSKeyedUnarchiver unarchiveObjectWithFile:historyFilePath];
		
		if ( programmeHistoryArray == nil )
			programmeHistoryArray = [[NSMutableArray alloc]init];
		
		/* Cull history if > 3,000 entries */
		
		while ( [programmeHistoryArray count] > 3000 )
			[programmeHistoryArray removeObjectAtIndex:0];
		
		timeIntervalSince1970UTC = [[NSDate date] timeIntervalSince1970];
		timeIntervalSince1970UTC += [[NSTimeZone systemTimeZone] secondsFromGMTForDate:[NSDate date]];
		timeIntervalSince1970UTC /= (24*60*60);
		
		NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
		[dateFormatter setDateFormat:@"EEE MMM dd"];
		dateFound = [dateFormatter stringFromDate:[NSDate date]];
	}
	return self;
}

-(void)addToNewProgrammeHistory:(NSString *)name andTVChannel:(NSString *)tvChannel andNetworkName:(NSString *)networkName
{
	itemsAdded = true;
	ProgrammeHistoryObject *newEntry = [[ProgrammeHistoryObject alloc]initWithName:name andTVChannel:tvChannel andDateFound:dateFound andSortKey:timeIntervalSince1970UTC andNetworkName:networkName];
	[programmeHistoryArray addObject:newEntry];
}

-(NSMutableArray *)getHistoryArray
{
	if (itemsAdded)
		[self flushHistoryToDisk];
	
	return programmeHistoryArray;
}

-(void)flushHistoryToDisk;
{
	itemsAdded = false;
	
	/* Sort history array and flush to disk */
	
	NSSortDescriptor *sort1 = [NSSortDescriptor sortDescriptorWithKey:@"sortKey" ascending:YES];
	NSSortDescriptor *sort2 = [NSSortDescriptor sortDescriptorWithKey:@"programmeName" ascending:YES];
	NSSortDescriptor *sort3 = [NSSortDescriptor sortDescriptorWithKey:@"tvChannel" ascending:YES];
	
	[programmeHistoryArray sortUsingDescriptors:[NSArray arrayWithObjects:sort1, sort2, sort3, nil]];
	
	[NSKeyedArchiver archiveRootObject:programmeHistoryArray toFile:historyFilePath];
}

@end

