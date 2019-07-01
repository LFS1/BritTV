//
//  NewProgrammeHistory.h
//  Get_iPlayer GUI
//
//  Created by LFS on 5/1/17.
//
//

#ifndef NewProgrammeHistory_h
#define NewProgrammeHistory_h

@interface NewProgrammeHistory : NSObject
{
	NSString        *historyFilePath;
	NSMutableArray  *programmeHistoryArray;
	BOOL            itemsAdded;
	NSUInteger      timeIntervalSince1970UTC;
	NSString        *dateFound;
}

+(NewProgrammeHistory*)sharedInstance;
-(id)init;
-(void)addToNewProgrammeHistory:(NSString *)name andTVChannel:(NSString *)tvChannel andNetworkName:(NSString *)networkName;
-(void)flushHistoryToDisk;
-(NSMutableArray *)getHistoryArray;

@end


#endif /* NewProgrammeHistory_h */
