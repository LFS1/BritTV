//
//  GetITVListings.h
//  ITVLoader
//
//  Created by LFS on 6/25/16.
//

#ifndef GetITVListings_h
#define GetITVListings_h

#import "AppController.h"
#import "LogController.h"
#import "ProgrammeData.h"

@interface GetITVShows : NSObject <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate>
{
    NSUInteger          myQueueSize;
    NSUInteger          myQueueLeft;
    NSURLSession        *mySession;
    NSString            *htmlData;
    NSMutableArray      *boughtForwardProgrammeArray;
    NSMutableArray      *todayProgrammeArray;
    NSMutableArray      *carriedForwardProgrammeArray;
    NSString            *filesPath;
    NSString            *programmesFilePath;
    BOOL                getITVShowRunning;
    BOOL                forceUpdateAllProgrammes;
    NSNotificationCenter *nc;
	int					pagesRead;
	int					pagesNotRead;
    BOOL                processingError;
    BOOL                mergeUnderway;
}

@property NSOperationQueue  *myOpQueue;

-(id)init;
-(void)itvUpdate;
-(void)forceITVUpdate;
-(id)requestTodayListing;
-(BOOL)createTodayProgrammeArray;
-(void)requestProgrammeEpisodes:(ProgrammeData *)myProgramme;
-(void)processProgrammeEpisodesData:(ProgrammeData *)myProgramm :(NSString *)myHtmlData;
-(void)processCarriedForwardProgrammes;
-(void)endOfRun;
-(BOOL)programmeNameInURLIsEqual:(NSString *)urlOne :(NSString *)urlTwo;


@end


#endif /* GetITVListings_h */
