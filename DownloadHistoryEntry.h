//
//  DownloadHistoryEntry.h
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 10/15/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#ifndef DownloadHistoryEntry_h
#define DownloadHistoryEntry_h

#import <Foundation/Foundation.h>

@interface DownloadHistoryEntry : NSObject {
}

@property NSString *productionId;
@property NSString *programmeName;
@property NSString *episodeName;
@property NSString *dateTimeRecorded;


- (id)initWithPID:(NSString *)pid ProgrammeName:(NSString *)programmeName EpisodeName:(NSString *) episodeName;
- (NSString *)entryString;

@end

#endif

