//
//  ProgrammeData.h
//  Get_iPlayer GUI
//
//  Created by LFS on 5/1/17.
//
//

#ifndef ProgrammeData_h
#define ProgrammeData_h

#import "LogController.h"

@interface ProgrammeData : NSObject <NSCoding>
{
	int afield;
	int isNew;
}
@property enum DownloadStatus { NotStarted = 0, Started = 1, FinishedOK = 2, FinishedWithError = 3, Cancelled = 4, Expired = 5};

@property NSString *programmeName;				// Coronation Street (was seriesName)
@property NSString *episodeName;
@property NSString *productionId;				// (Was pid)
@property NSString *programmeURL;				// (was url)
@property int numberEpisodes;
@property int forceCacheUpdate;
@property NSString *tvNetwork;					// BBC1 -> BBC4 or ITV (was channel)
@property int seriesNumber;						// (Was Season)
@property int episodeNumber;					// (was episode)
@property NSDate *dateAired;
@property NSString *episodeTitle;
@property NSString *status;
@property enum DownloadStatus downloadStatus;
@property NSString *mp4Path;
@property NSString *tempMp4Path;
@property NSString *reasonForFailure;
@property bool addedByPVR;
@property NSString *shortEpisodeName;
@property BOOL dateWithTime;
@property NSString *downloadPath;
@property NSString *mp4FileName;
@property NSInteger programDuration;
@property NSInteger sortKey;
@property NSString *dateAiredString;
@property NSString *timeAiredString;
@property NSString *fullITVProductionID;
@property NSString *displayInfo;
@property NSImage  *episodeImage;
@property NSURL *episodeImageURL;
@property NSProgressIndicator *downloadProgress;
@property double progressDoubleValue;
@property BOOL progressIsHidden;
@property BOOL progressIsIndeterminate;
@property double progressMaxValue;
@property double progressMinValue;
@property BOOL statusIsHidden;
@property BOOL displayInfoIsHidden;




- (id)initWithName:(NSString *)name andChannel:(NSString*)channel andPID:(NSString *)pid andURL:(NSString *)url andNUMBEREPISODES:(int)numberEpisodes;
- (id)makeNew;
-(void)fixProgrammeName;
-(void)makeEpisodeName;
- (void)createDownloadPaths;
-(NSString *)getDateAiredFromString:(NSString *)theString;
-(void)analyseTitle:(NSString *)title;
-(BOOL)isValid;

@end




#endif /* ProgrammeData_h */
