//
//  DownloadHistoryCache.h
//  Get_iPlayer GUI
//
//  Created by LFS on 6/5/17.
//
//


#ifndef DownloadHistoryCache_h
#define DownloadHistoryCache_h

#import <Foundation/Foundation.h>


extern bool runDownloads;

@interface DownloadHistoryCache : NSObject
{
	NSString *history;
	NSDate	 *timeLastRead;
	NSString *historyFilePath;
	NSFileHandle *historyFile;
	NSArray *historyArray;

}
-(BOOL)searchHistory:(NSString *)searchPID;

@end


#endif

