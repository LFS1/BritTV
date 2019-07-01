//
//  ProgrammeCache.h
//  Get_iPlayer GUI
//
//  Created by LFS on 6/2/17.
//
//

#ifndef ProgrammeCache_h
#define ProgrammeCache_h


#import <Foundation/Foundation.h>
#import "DownloadHistoryCache.h"


@interface ProgrammeCache : NSObject
{
	BOOL cacheExists;
	NSArray	*bbcCache;
	NSArray	*itvCache;
	DownloadHistoryCache *downloadHistoryCache;
	
}

+(ProgrammeCache*)sharedInstance;
-(id)init;
-(void)buildProgrammeCache;
-(NSArray*)searchProgrammeCache:(NSString *)searchName andSEARCHTYPE:(NSString *)searchType andAllowDownloaded:(BOOL)allowDownloaded;
-(BOOL)isPidDownloaded:(NSString *)pid;

@end

#endif

