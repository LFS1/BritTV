//
//  ProgrammeHistoryObject.h
//  Get_iPlayer GUI
//
//  Created by LFS on 5/1/17.
//
//

#ifndef ProgrammeHistoryObject_h
#define ProgrammeHistoryObject_h

@interface ProgrammeHistoryObject : NSObject <NSCoding>
{
	// long      sortKey;
}
@property long      sortKey;
@property NSString  *programmeName;
@property NSString  *dateFound;
@property NSString  *tvChannel;
@property NSString  *networkName;

- (id)initWithName:(NSString *)name andTVChannel:(NSString *)aTVChannel andDateFound:(NSString *)dateFound andSortKey:(NSUInteger)sortKey andNetworkName:(NSString *)networkName;

@end


#endif /* ProgrammeHistoryObject_h */
