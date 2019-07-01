//
//  getBBCListings.h
//  Get_iPlayer GUI
//
//  Created by LFS on 4/29/17.
//
//

#ifndef getBBCListings_h
#define getBBCListings_h

#import "AppController.h"
#import "ProgrammeData.h"
#import "PageData.h"

@interface GetBBCShows : NSObject <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate>
{
    NSUInteger          myQueueLeft;
	NSUInteger			myQueueSize;
    NSMutableArray      *boughtForwardProgrammeArray;
    NSMutableArray      *todayProgrammeArray;
    NSMutableArray      *carriedForwardProgrammeArray;
    NSString            *filesPath;
    NSString            *programmesFilePath;
    BOOL                getBBCShowRunning;
    BOOL                forceUpdateAllProgrammes;
    NSNotificationCenter *nc;
	NSOperationQueue	*myOpQueue;
	BOOL				processingError;
    NSURLSession        *mySession;
	BOOL				mergeUnderway;
    BOOL                gotAZ;
	int					pagesRead;
	int					pagesNotRead;
    float               lastPercentDone;
}

-(void) bbcUpdate;
-(void) forceBBCUpdate;

@end

#endif /* getBBCListings_h */
