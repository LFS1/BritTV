//
//  AppController.h
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/10/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#ifndef AppController_h
#define AppController_h


#import <Cocoa/Cocoa.h>
#import <IOKit/pwr_mgt/IOPMLib.h>

@class GetITVShows;
@class GetBBCShows;
@class LogController;
@class NPHistoryTableViewController;
@class NewProgrammeHistory;
@class ProgrammeCache;


@interface AppController : NSObject {
	//General

	IBOutlet NSWindow *mainWindow;
	IBOutlet NSApplication *application;
   IBOutlet NSWindow *historyWindow;
   IOPMAssertionID powerAssertionID;
	NSOperationQueue *opsQueue;
	BOOL mainWindowClosed;
	
	//Update Components
	NSTask *getiPlayerUpdateTask;
	NSPipe *getiPlayerUpdatePipe;
	NSArray *getiPlayerUpdateArgs;
   NSMutableArray *typesToCache;
	BOOL runSinceChange;
   NSUInteger nextToCache;
   NSDictionary *updateURLDic;
   NSDate *lastUpdate;
	
	//Main Window: Search
	IBOutlet NSTextField *searchField;
	IBOutlet NSArrayController *resultsController;
   IBOutlet NSTableView *searchResultsTable;
	
	//PVR
	IBOutlet NSTextField *pvrSearchField;
	IBOutlet NSArrayController *pvrResultsController;
	IBOutlet NSArrayController *pvrQueueController;
   IBOutlet NSPanel *pvrPanel;
	NSMutableArray *pvrSearchResultsArray;
	NSMutableArray *pvrQueueArray;
	
	//Queue
	IBOutlet NSButton *addToQueue;
	IBOutlet NSArrayController *queueController;
	IBOutlet NSTableView *queueTableView;

    IBOutlet NSToolbarItem *addSeriesLinkToQueueButton;

	// Underway
	IBOutlet NSArrayController *underwayController;
	IBOutlet NSTableView *underwayTableView;

	
	//Download Controller
	IBOutlet NSToolbarItem *stopButton;
	IBOutlet NSToolbarItem *startButton;
	int	numberOfITVDownloadsRunning;
	int numberOfBBCDownloadsRunning;
	int	downloadNumber;
	NSMutableArray *downloadTasksArray;
	
	//Preferences
   IBOutlet NSPanel *prefsPanel;
	
   //Download Solutions
   IBOutlet NSWindow *solutionsWindow;
   //IBOutlet NSArrayController *solutionsArrayController;
   IBOutlet NSTableView *solutionsTableView;
   NSDictionary *solutionsDictionary;
   
   //Verbose Logging
   BOOL verbose;
   IBOutlet LogController *logger;
    
   // Misc Menu Items / Buttons
    IBOutlet NSToolbarItem *refreshCacheButton;
    IBOutlet NSMenuItem *forceCacheUpdateMenuItem;
    IBOutlet NSMenuItem *checkForCacheUpdateMenuItem;
    
   //ITV Cache
   BOOL                         updatingITVIndex;
   BOOL                         updatingBBCIndex;
   BOOL                         forceITVUpdateInProgress;
   BOOL                         forceBBCUpdateInProgress;
   IBOutlet NSMenuItem          *showNewProgrammesMenuItem;
   IBOutlet NSTextField         *itvProgressText;

   IBOutlet NSTextField		    *updatingIndexesText;
   IBOutlet NSMenuItem          *forceITVUpdateMenuItem;
   IBOutlet NSMenuItem          *forceBBCUpdateMenuItem;
	IBOutlet NSTextField		*bbcProgressText;

    //New Programmes History
	
    NSWindow *newProgrammesWindow;
	
	GetITVShows                   *newITVListing;
	GetBBCShows					  *newBBCListing;

	NPHistoryTableViewController  *npHistoryTableViewController;
	
	NewProgrammeHistory           *sharedHistoryController;
	ProgrammeCache				  *sharedProgrammeCacheController;
    
    // Autostart controlls
    
    int autoStartMinuteCount;
    int autoStartSuccessCount;
    int autoStartFailCount;
    int autoStartFailCountBF;
    NSTimer *autoPilotTimer;
    
    BOOL autoPilot;
    BOOL autoPilotSleepDisabled;
    
    IBOutlet NSTextField *downloadFailCountOutlet;
    IBOutlet NSTextField *downloadSuccessCountOutlet;
    IBOutlet NSTextField *autoStartMinuteOutlet;
	IBOutlet NSTextField *location;
}

@property   IBOutlet NSProgressIndicator *itvProgressIndicator;
@property   IBOutlet NSProgressIndicator *bbcProgressIndicator;
@property   IBOutlet NSArrayController *solutionsArrayController;


//Update
- (void)getiPlayerUpdateFinished;
- (IBAction)forceUpdate:(id)sender;

//Search
- (IBAction)pvrSearch:(id)sender;
- (IBAction)mainSearch:(id)sender;

//PVR
- (IBAction)addToAutoRecord:(id)sender;

//Misc.
- (IBAction)chooseDownloadPath:(id)sender;
- (IBAction)restoreDefaults:(id)sender;
- (IBAction)closeWindow:(id)sender;
+ (AppController*)sharedController;

//Queue
- (IBAction)addToQueue:(id)sender;
- (IBAction)removeFromQueue:(id)sender;

//Download Controller
- (IBAction)startDownloads:(id)sender;
- (IBAction)stopDownloads:(id)sender;

//PVR
- (IBAction)addSeriesLinkToQueue:(id)sender;
- (IBAction)hidePvrShow:(id)sender;

-(void)updateHistory;
-(void)updateHistoryForType:(NSString *)chanelType andBFFile:(NSString *)bfFile andCFFile:(NSString *)cfFile;
-(void)itvUpdateFinished;
-(void)forceITVUpdateFinished;
-(void)updateAutoStart;

@end


#endif

