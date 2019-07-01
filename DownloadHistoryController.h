//
//  DownloadHistoryController.h
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 10/15/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#ifndef DownloadHistoryController_h
#define DownloadHistoryController_h


#import <Cocoa/Cocoa.h>

extern bool runDownloads;

@interface DownloadHistoryController : NSObject {
	IBOutlet NSArrayController *historyArrayController;
	IBOutlet NSTableView *historyTableView;
	IBOutlet NSWindow *historyWindow;
	IBOutlet NSButton *cancelButton;
	IBOutlet NSButton *saveButton;
	NSDate *timeLastRead;
	NSString *historyFilePath;
	NSDictionary *fileAttribs;
	
}

- (IBAction)showHistoryWindow:(id)sender;
- (IBAction)removeSelectedFromHistory:(id)sender;
- (void)readHistory:(id)sender;
- (IBAction)writeHistory:(id)sender;
- (IBAction)cancelChanges:(id)sender;
- (void)addToLog:(NSString *)logMessage;
@end

#endif
