//
//  GetiPlayerDownload.h
//  BriTv
//
//  Created by LFS on 9/12/19.
//

#ifndef getiPlayerDownload_h
#define getiPlayerDownload_h

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "ProgrammeData.h"
#import "LogController.h"
#import "AppController.h"

extern bool runDownloads;

@interface GetiPlayerDownload : NSObject {
    
    NSTask *getiPlayerTask;
    NSFileHandle *getiPlayerStdFh;
    NSFileHandle *getiPlayerErrFh;
    
    ProgrammeData *show;
    BOOL        verbose;
    int         downloadNumber;
    BOOL        addFailedDownloadToHistory;
}

- (id)initWithProgramme:(ProgrammeData *)tempShow downloadNumber:(int)downloadNumber;
- (void)startDownload;
- (void)cancelDownload:(id)sender;

@end

#endif /* getiPlayerDownload_h */



