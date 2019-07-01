//
//  YoutubeDLDownload.h
//  Get_iPlayer GUI
//
//  Created by LFS on 1/28/18.
//

#ifndef YoutubeDLDownload_h
#define YoutubeDLDownload_h

#import <Cocoa/Cocoa.h>
#import "ProgrammeData.h"
#import "LogController.h"
#import "AppController.h"

extern bool runDownloads;

@interface YoutubeDLDownload : NSObject {

	NSTask *youTubeTask;
	NSFileHandle *youTubeStdFh;
	NSFileHandle *youTubeErrFh;
	
	ProgrammeData *show;
	BOOL	verbose;
	int		downloadNumber;
	BOOL	addFailedDownloadToHistory;
}

- (id)initWithProgramme:(ProgrammeData *)tempShow downloadNumber:(int)downloadNumber;
- (void)startDownload;
- (void)cancelDownload:(id)sender;

@end



#endif /* YoutubeDLDownload_h */
