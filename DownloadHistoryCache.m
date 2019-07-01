//
//  DownloadHistoryCache.m
//  Get_iPlayer GUI
//
//  Created by LFS on 6/5/17.
//
//

#import "DownloadHistoryCache.h"

@implementation DownloadHistoryCache

- (id)init
{
	if (!(self = [super init])) return nil;
	
	historyFilePath = @"~/Library/Application Support/BriTv/download_history.v2";
	historyFilePath = [historyFilePath stringByExpandingTildeInPath];
	historyFile = [NSFileHandle fileHandleForReadingAtPath:[historyFilePath stringByExpandingTildeInPath]];
	timeLastRead = [NSDate date];
	
	[self searchHistory:@"a"];

	return self;
}


-(BOOL)searchHistory:(NSString *)searchPID
{
	NSDictionary* fileAttribs = [[NSFileManager defaultManager] attributesOfItemAtPath:historyFilePath error:nil];
	NSDate *timeChanged = [fileAttribs objectForKey:NSFileModificationDate];
	
	if ( [timeChanged compare:timeLastRead] != NSOrderedSame ) {
		NSError *error;
		history = [NSString stringWithContentsOfFile:historyFilePath encoding:NSUTF8StringEncoding error:&error];
		
		if (error)  {
			NSLog(@"Search for %@ gives error %@", searchPID, error);
			return NO;
		}

		timeLastRead = timeChanged;
		BOOL finished = false;;
		
		NSMutableArray *tempHistoryArray = [NSMutableArray arrayWithCapacity:20000];
		
		NSScanner *s1 = [NSScanner scannerWithString:history];
		NSString  *record;
		[s1 scanUpToString:@"\n" intoString:&record];
		
		while ( !finished )  {
			
			if ([s1 isAtEnd] )
				finished = true;
			
			[s1 scanString:@"\n" intoString:NULL];
			NSString *pid;
			NSScanner *s2 = [NSScanner scannerWithString:record];
			[s2 scanUpToString:@"|" intoString:&pid];
			[tempHistoryArray addObject:pid];
			[s1 scanUpToString:@"\n" intoString:&record];

		}

		historyArray = [tempHistoryArray sortedArrayUsingSelector:@selector(compare:)];
	}

	return [self searchForProductionId:searchPID];

}

-(BOOL)searchForProductionId:(NSString *)searchPID
{
	NSInteger startPoint = 0;
	NSInteger endPoint   = historyArray.count -1;
	NSInteger midPoint = endPoint / 2;
	
	NSString *midPID;
	
	while (startPoint <= endPoint) {
		
		midPID = [historyArray objectAtIndex:midPoint];
		
		NSComparisonResult result = [midPID compare:searchPID];
		
		switch ( result )  {
			case NSOrderedAscending:
				startPoint = midPoint +1;
				break;
			case NSOrderedSame:
				return YES;
				break;
			case NSOrderedDescending:
				endPoint = midPoint -1;
				break;
				
		}
		midPoint = (startPoint + endPoint)/2;
	}
	
	return NO;
}



@end
