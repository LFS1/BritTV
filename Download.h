//
//  Download.h
//  
//
//  Created by Thomas Willson on 12/16/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Programme.h"
#import "ASIHTTPRequest.h"
#import "LogController.h"

@interface Download : NSObject {
    NSNotificationCenter *nc;
    LogController *logger;
    
    
	Programme *show;
    
    double lastDownloaded;
	NSDate *lastDate;
	NSMutableArray *rateEntries;
	double oldRateAverage;
	int outOfRange;
    NSMutableString *log;
    
    //RTMPDump Task
    NSTask *task;
    NSPipe *pipe;
    NSPipe *errorPipe;
    NSFileHandle *fh;
    NSFileHandle *errorFh;
    NSMutableString *errorCache;
    NSTimer *processErrorCache;
    
    //ffmpeg Conversion
    NSTask *ffTask;
    NSPipe *ffPipe;
    NSPipe *ffErrorPipe;
    NSFileHandle *ffFh;
    NSFileHandle *ffErrorFh;
    
    //Download Information
    NSString *downloadPath;
    
    //Subtitle Conversion
    NSTask *subsTask;
    NSPipe *subsErrorPipe;
    NSString *defaultsPrefix;
    
    NSArray *formatList;
    BOOL running;
    
    NSInteger attemptNumber;

    //Verbose Logging
    BOOL verbose;
    
    //Download Parameters
    NSMutableDictionary *downloadParams;
    
    BOOL isFilm;

    ASIHTTPRequest *currentRequest;

}
- (id)initWithLogController:(LogController *)logger;
- (void)setCurrentProgress:(NSString *)string;
- (void)setPercentage:(double)d;
- (void)cancelDownload:(id)sender;
- (void)addToLog:(NSString *)logMessage noTag:(BOOL)b;
- (void)addToLog:(NSString *)logMessage;
- (void)processFLVStreamerMessage:(NSString *)message;

- (void)launchMetaRequest;
- (void)launchRTMPDumpWithArgs:(NSArray *)args;
- (void)processGetiPlayerOutput:(NSString *)outp;
- (void)createDownloadPath;
- (void)processError;

@property (readonly) Programme *show;
@end
