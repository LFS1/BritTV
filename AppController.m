//
//  AppController.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/10/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//


#import "Growl.framework/Headers/GrowlApplicationBridge.h"
#import "ReasonForFailure.h"
#import "GetITVListings.h"
#import "getBBCListings.h"
#import "NPHistoryWindowController.h"
#import "DownloadHistoryCache.h"
#import "NewProgrammeHistory.h"
#import "AppController.h"
#import "ProgrammeCache.h"
#import "YoutubeDLDownload.h"
#import "GetiPlayerDownload.h"
#import "SeriesLink.h"
#import "DownloadHistoryEntry.h"


static AppController *sharedInstance;

bool runDownloads=NO;
bool runUpdate=NO;

LogController *theLogger;



@implementation AppController

#pragma mark Overriden Methods

+ (AppController *)sharedController {
	return sharedInstance;
}

- (id)init {
	
    if (!(self = [super init])) return nil;
	
    sharedInstance = self;
	[self convertHistory];
    sharedHistoryController = [NewProgrammeHistory sharedInstance];
    NSNotificationCenter *nc;
    nc = [NSNotificationCenter defaultCenter];
	
	//Initialize Arrays for Controllers
	
    pvrSearchResultsArray = [NSMutableArray array];
    pvrQueueArray = [NSMutableArray array];
	downloadTasksArray = [[NSMutableArray alloc]init];
	opsQueue = [[NSOperationQueue alloc] init];
	[opsQueue setMaxConcurrentOperationCount:25];
    
    //Register Default Preferences
	
    NSMutableDictionary *defaultValues = [[NSMutableDictionary alloc] init];
    
    NSString *defaultDownloadDirectory = @"~/Movies/TV Shows";
    defaultValues[@"DownloadPath"] = [defaultDownloadDirectory stringByExpandingTildeInPath];
    defaultValues[@"DefaultBrowser"] = @"Safari";
    defaultValues[@"CacheBBC_TV"] = @YES;
    defaultValues[@"CacheITV_TV"] = @YES;
    defaultValues[@"GetiPlayer"] = @NO;
    defaultValues[@"AutoPiAutoPillotHours"] = @"0";
    defaultValues[@"AutoPilotAbandonCount"] = @"10";
    defaultValues[@"CacheExpiryTime"] = @"1";
	defaultValues[@"numberConcurrentITVDownloads"] = @"1";
	defaultValues[@"numberConcurrentBBCDownloads"] = @"1";
	defaultValues[@"numberITVRetries"] = @"3";
	defaultValues[@"numberBBCRetries"] = @"3";
    defaultValues[@"Verbose"] = @NO;
	defaultValues[@"IgnoreGeoPositionService"] = @NO;
    defaultValues[@"SeriesLinkStartup"] = @YES;
    defaultValues[@"BBCOne"] = @YES;
    defaultValues[@"BBCTwo"] = @YES;
    defaultValues[@"BBCThree"] = @YES;
    defaultValues[@"BBCFour"] = @YES;
	defaultValues[@"ITV"] = @YES;
    defaultValues[@"IgnoreAllTVNews"] = @YES;
    defaultValues[@"ShowDownloadedInSearch"] = @YES;

    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultValues];
    defaultValues = nil;

    //Make sure Application Support folder exists
	
    NSString *folder = @"~/Library/Application Support/BriTv/";
    folder = [folder stringByExpandingTildeInPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
	
    if (![fileManager fileExistsAtPath:folder])
    {
        [fileManager createDirectoryAtPath:folder withIntermediateDirectories:NO attributes:nil error:nil];
    }
    [fileManager changeCurrentDirectoryPath:folder];
    
    //Initialize Arguments

    verbose = [[NSUserDefaults standardUserDefaults] boolForKey:@"Verbose"];
    
    [nc addObserver:self selector:@selector(itvUpdateFinished) name:@"ITVUpdateFinished" object:nil];
    [nc addObserver:self selector:@selector(forceITVUpdateFinished) name:@"ForceITVUpdateFinished" object:nil];
	
	[nc addObserver:self selector:@selector(bbcUpdateFinished) name:@"BBCUpdateFinished" object:nil];
	[nc addObserver:self selector:@selector(forceBBCUpdateFinished) name:@"ForceBBCUpdateFinished" object:nil];
	
    forceITVUpdateInProgress = NO;
	forceBBCUpdateInProgress = NO;
	
	sharedProgrammeCacheController = [ProgrammeCache sharedInstance];
    
    autoStartMinuteCount = [[[NSUserDefaults standardUserDefaults] objectForKey:@"AutoPilotHours"] intValue]*3600;
    autoStartMinuteOutlet.stringValue = [NSString stringWithFormat:@"%d", autoStartMinuteCount];
    autoPilot = false;
    autoPilotSleepDisabled = false;
    
	
    return self;
}

#pragma mark Delegate Methods
- (void)awakeFromNib
{
	[self amInUk];
	theLogger = logger;
	newITVListing =  [[GetITVShows alloc] init];
	newBBCListing =  [[GetBBCShows alloc]init];
	
    //Initialize Search Results Click Actions
    [searchResultsTable setTarget:self];
    [searchResultsTable setDoubleAction:@selector(addToQueue:)];
    
    
    //Read Queue & Series-Link from File
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString *folder = @"~/Library/Application Support/BriTv/";
    folder = [folder stringByExpandingTildeInPath];
	
    if ([fileManager fileExistsAtPath: folder] == NO)
        [fileManager createDirectoryAtPath:folder withIntermediateDirectories:NO attributes:nil error:nil];
    
    NSString *filename = @"Queue.automatorqueue";
    NSString *filePath = [folder stringByAppendingPathComponent:filename];
    
    NSDictionary * rootObject;
    @try
    {
        rootObject = [NSKeyedUnarchiver unarchiveObjectWithFile:filePath];
        lastUpdate = [rootObject valueForKey:@"lastUpdate"];
		
		NSArray *tempQueue = [rootObject valueForKey:@"queue"];
		tempQueue = [self sortQueue:tempQueue];
        [queueController addObjects:tempQueue];
		[queueController setSelectionIndexes:[NSIndexSet indexSet]];
		
		NSArray *tempSeries = [rootObject valueForKey:@"serieslink"];
		tempSeries = [self sortPVRQueue:tempSeries];
        [pvrQueueController addObjects:tempSeries];
		
		NSArray *tempUnderway = [rootObject valueForKey:@"underwayQueue"];
		[underwayController addObjects:tempUnderway];
		[underwayController setSelectionIndexes:[NSIndexSet indexSet]];
    }
    @catch (NSException *e)
    {
        [fileManager removeItemAtPath:filePath error:nil];
		[logger addToLog:@"Unable to load saved application data. Deleted the data file." :self];
        rootObject=nil;
    }
    
    //Growl Initialization
    @try {
        [GrowlApplicationBridge setGrowlDelegate:(id<GrowlApplicationBridgeDelegate>)@""];
    }
    @catch (NSException *e) {
        [logger addToLog:[NSString stringWithFormat:@"ERROR: Growl initialisation failed: %@: %@", [e name], [e description]]];
    }
	
    [self updateCache:nil];
    
    /* Set auto restart timer counts */
    
    autoStartSuccessCount = autoStartFailCount = autoStartFailCountBF = 0;
    downloadSuccessCountOutlet.stringValue = @"None";
    downloadFailCountOutlet.stringValue = @"None";
    
    if  ( [[[NSUserDefaults standardUserDefaults] objectForKey:@"AutoPilotHours"] intValue]) {
        autoPilotTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                          target:self
                                                        selector:@selector(updateAutoStart)
                                                        userInfo:nil
                                                         repeats:YES];
        
        autoPilotSleepDisabled = true;
        
        IOPMAssertionCreateWithDescription(kIOPMAssertionTypePreventUserIdleSystemSleep, (CFStringRef)@"Downloading Show", (CFStringRef)@"BriTV is in Autopilot mode.", NULL, NULL, (double)0, NULL, &powerAssertionID);
    }
}
-(void)updateAutoStart
{
    autoStartMinuteOutlet.stringValue = [NSString stringWithFormat:@"%d", --autoStartMinuteCount];
    
    if (autoStartMinuteCount > 0)
        return;
    
    autoStartMinuteCount = [[[NSUserDefaults standardUserDefaults] objectForKey:@"AutoPilotHours"] intValue]*3600;
	
	if ( [self amInUk] == false )
		return;

    if (runDownloads || runUpdate )
        return;

    int failsThisCycle = autoStartFailCount - autoStartFailCountBF;
    int maxFailsAllowed = [[[NSUserDefaults standardUserDefaults] objectForKey:@"AutoPilotAbandonCount"] intValue];
    
    if ( failsThisCycle >  maxFailsAllowed )
    {
        [autoPilotTimer invalidate];
        autoStartMinuteOutlet.stringValue = @"Off";
        autoPilot = false;
        IOPMAssertionRelease(powerAssertionID);
        autoPilotSleepDisabled = false;
        return;
    }
    
    autoPilot = true;
    autoStartFailCountBF = autoStartFailCount;
    
    [self forceUpdate:nil];
    
}
-(void) reStart
{
    NSString *killArg1AndOpenArg2Script = @"kill -9 $1 \n open \"$2\"";
    NSString *ourPID = [NSString stringWithFormat:@"%d",[[NSProcessInfo processInfo] processIdentifier]];
    NSString *pathToUs = [[NSBundle mainBundle] bundlePath];
    NSArray *shArgs = [NSArray arrayWithObjects:@"-c",
                       killArg1AndOpenArg2Script,
                       @"",
                       ourPID,
                       pathToUs,
                       nil];
    
    NSTask *restartTask = [NSTask launchedTaskWithLaunchPath:@"/bin/sh" arguments:shArgs];
    
    [restartTask waitUntilExit]; //wait for killArg1AndOpenArg2Script to finish
    
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)application
{
    return YES;
}
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
	if ( mainWindowClosed )
		return NSTerminateNow;
	
	if ( [self okToClose] )
		return  NSTerminateNow;
	
	return NSTerminateCancel;
	
}

-(BOOL)okToClose
{
	if (runDownloads)
	{
        NSAlert *alert = [[NSAlert alloc]init];
        alert.messageText = @"Are you sure you wish to quit?";
        alert.informativeText = @"You are currently downloading shows. If you quit, they will be cancelled.";
        [alert addButtonWithTitle:@"No"];
        [alert addButtonWithTitle:@"Yes"];
        NSModalResponse response = [alert runModal];
        
		if (response == NSAlertFirstButtonReturn)
			return NO;
	}
    
	return YES;
}
- (BOOL)windowShouldClose:(id)sender
{
	mainWindowClosed = false;
	
    if (![sender isEqualTo:mainWindow])
		return YES;
	
	if ( ![self okToClose] )
		return NO;
		
	mainWindowClosed = true;
	return YES;
}
- (void)windowWillClose:(NSNotification *)note
{
    if ([[note object] isEqualTo:mainWindow]) [application terminate:self];
}
- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    //End Downloads if Running
	
    if (runDownloads)
	{
		for ( YoutubeDLDownload *d in downloadTasksArray )
        	[d cancelDownload:nil];
		
		[downloadTasksArray removeAllObjects];
	}
	[self saveAppData];
	
	runDownloads = false;
	runUpdate = false;
}

#pragma mark Cache Update
-(IBAction)checkCacheUpdate:(id)sender
{
	[self updateCache:@"Check"];
}
- (void)updateCache:(id)sender
{
	
	if ( [[_solutionsArrayController arrangedObjects] count] )
			[_solutionsArrayController removeObjectsAtArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [_solutionsArrayController.arrangedObjects count])]];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	NSString *bbcFilePath = @"~/Library/Application Support/BriTv/bbcprogrammes.gia";
	NSString *itvFilePath = @"~/Library/Application Support/BriTv/itvprogrammes.gia";
	bbcFilePath = [bbcFilePath stringByExpandingTildeInPath];
	itvFilePath = [itvFilePath stringByExpandingTildeInPath];
	
	if (![fileManager fileExistsAtPath:bbcFilePath] || ![fileManager fileExistsAtPath:itvFilePath] )
		lastUpdate = 0;
			
	if ( [sender isEqualToString:@"force"] )
		lastUpdate = 0;
			
	if (lastUpdate &&
		([[NSDate date] timeIntervalSinceDate:lastUpdate] < ([[defaults objectForKey:@"CacheExpiryTime"] intValue]*3600))) {
		[self getiPlayerUpdateFinished];
		return;
	}

    runSinceChange=YES;
    runUpdate=YES;

    [mainWindow setDocumentEdited:YES];
    
    NSArray *tempQueue = [queueController arrangedObjects];
    for (ProgrammeData *show in tempQueue)
    {
        if (show.downloadStatus == FinishedOK )
        {
            [queueController removeObject:show];
        }
    }
	
	[searchField setEnabled:NO];
	[stopButton setEnabled:NO];
	[startButton setEnabled:NO];
	[pvrSearchField setEnabled:NO];
	[addSeriesLinkToQueueButton setEnabled:NO];
	[refreshCacheButton setEnabled:NO];
	[forceCacheUpdateMenuItem setEnabled:NO];
	[checkForCacheUpdateMenuItem setEnabled:NO];
	[showNewProgrammesMenuItem setEnabled:NO];
	[forceITVUpdateMenuItem setEnabled:NO];
	[forceBBCUpdateMenuItem setEnabled:NO];
	[updatingIndexesText setHidden:false];
	
	if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"CacheBBC_TV"] boolValue])
	{
		updatingBBCIndex = true;
		
		[[self bbcProgressIndicator] setDoubleValue:0.0];
		[[self bbcProgressIndicator] setHidden:false];
		[bbcProgressText setHidden:false];
		[opsQueue addOperation:[[NSInvocationOperation alloc] initWithTarget:newBBCListing selector:@selector(bbcUpdate) object:NULL]];
	}
	
	if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"CacheITV_TV"] boolValue])
	{
		updatingITVIndex = true;
	
		[[self itvProgressIndicator] setDoubleValue:0.0];
		[[self itvProgressIndicator] setHidden:false];
		[itvProgressText setHidden:false];
		[opsQueue addOperation:[[NSInvocationOperation alloc] initWithTarget:newITVListing selector:@selector(itvUpdate) object:NULL]];
	}
	
	if (!updatingITVIndex && !updatingBBCIndex)
		[self getiPlayerUpdateFinished];

}

- (void)itvUpdateFinished
{
    
    updatingITVIndex = false;
	[self getiPlayerUpdateFinished];
}

- (void)bbcUpdateFinished
{
	
	updatingBBCIndex = false;
	[self getiPlayerUpdateFinished];

}
- (void)getiPlayerUpdateFinished
{
    if (updatingITVIndex || updatingBBCIndex)
        return;
	
	lastUpdate = [NSDate date];
	
	[sharedProgrammeCacheController buildProgrammeCache];
	[self cleanUpQueue];
	[self updateHistory];
	
	[updatingIndexesText setHidden:true];
	[[self itvProgressIndicator] setHidden:true];
	[itvProgressText setHidden:true];
	[[self bbcProgressIndicator] setHidden:true];
	[bbcProgressText setHidden:true];

    runUpdate=NO;
    [mainWindow setDocumentEdited:NO];
    
    getiPlayerUpdatePipe = nil;
    getiPlayerUpdateTask = nil;
    [searchField setEnabled:YES];
    [startButton setEnabled:YES];
    [pvrSearchField setEnabled:YES];
    [addSeriesLinkToQueueButton setEnabled:YES];
    [refreshCacheButton setEnabled:YES];
    [forceCacheUpdateMenuItem setEnabled:YES];
    [checkForCacheUpdateMenuItem setEnabled:YES];
    [showNewProgrammesMenuItem setEnabled:YES];
	[forceITVUpdateMenuItem setEnabled:YES];
	[forceBBCUpdateMenuItem setEnabled:YES];
	
    //Don't want to add these until the cache is up-to-date!
	
    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"SeriesLinkStartup"] boolValue])
        [self addSeriesLinkToQueue:self];
	
	if ( [[_solutionsArrayController arrangedObjects]count] )
		[solutionsWindow makeKeyAndOrderFront:self];
    
    if (autoPilot) 
        [self startDownloads:nil];
	
}
- (IBAction)forceUpdate:(id)sender
{
    [self updateCache:@"force"];
}

#pragma mark Search

- (IBAction)goToSearch:(id)sender {
    [mainWindow makeKeyAndOrderFront:self];
    [mainWindow makeFirstResponder:searchField];
}
- (IBAction)mainSearch:(id)sender
{
	
	if( [searchField.stringValue length] == 0)
		return;
	
	NSArray	*searchResult;

	[resultsController removeObjectsAtArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [resultsController.arrangedObjects count])]];
	
	BOOL allowDownloaded = [[[NSUserDefaults standardUserDefaults] valueForKey:@"ShowDownloadedInSearch"] boolValue] ? YES:NO;
	
	searchResult = [sharedProgrammeCacheController searchProgrammeCache:searchField.stringValue andSEARCHTYPE:@"Contains" andAllowDownloaded:allowDownloaded];
	
	if ( !searchResult.count ) {
        
        NSAlert *alert = [[NSAlert alloc]init];
        alert.messageText = @"No Shows Found";
        alert.informativeText = @"0 shows were found for your search terms. Please check your spelling!";
        [alert runModal];

		return;
	}
	
	[self loadSearchResultIntoQueue:searchResult intoQueue:resultsController];

}

-(void)loadSearchResultIntoQueue:(NSArray *)searchResult intoQueue:(NSArrayController *)resultQueue
{
	searchResult = [self sortQueue:searchResult];
	
	NSMutableArray *resultsArray = [[NSMutableArray alloc]init];
	
	for ( ProgrammeData *p in searchResult )  {
	
		if (p.productionId == nil || p.tvNetwork == nil || p.programmeURL == nil) {
			[logger addToLog: [NSString stringWithFormat:@"WARNING: Invalid programme %@ found on search PID %@ tvN %@ URL %@", p.programmeName, p.productionId, p.tvNetwork, p.programmeURL]];
			continue;
		}
		[p makeEpisodeName];
		[resultsArray addObject:p];
	}

	[resultQueue addObjects:resultsArray];
	[resultQueue setSelectionIndexes:[NSIndexSet indexSet]];
	[self updateImages:resultsArray];
}
-(void)updateImages:(NSArray *)programmes
{
	for ( ProgrammeData *p in programmes )
		if ( p.episodeImageURL && !p.episodeImage )
			[opsQueue addOperation:[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(getImage:) object:p]];
}

-(void)getImage:(ProgrammeData *)p
{
	NSData *data = [[NSData alloc] initWithContentsOfURL:p.episodeImageURL];
	p.episodeImage = [[NSImage alloc] initWithData:data];
}



#pragma mark Queue
-(NSArray *)sortQueue:(NSArray *)qToSort
{
	for (ProgrammeData *p in qToSort )
		p.sortKey = [p.dateAired timeIntervalSince1970];
	
	NSSortDescriptor *sort1 = [NSSortDescriptor sortDescriptorWithKey:@"programmeName" ascending:YES];
	NSSortDescriptor *sort2 = [NSSortDescriptor sortDescriptorWithKey:@"sortKey" ascending:YES];
	NSSortDescriptor *sort3 = [NSSortDescriptor sortDescriptorWithKey:@"productionId" ascending:YES];
	
	return [qToSort sortedArrayUsingDescriptors:[NSArray arrayWithObjects:sort1, sort2, sort3, nil]];
}
- (IBAction)addFailedDownloadsToQueue:(id)sender
{
	NSArray *shows = [underwayController arrangedObjects];
	[self putShowsBackInQueue:shows];
}
- (IBAction)putBackInQueue:(id)sender
{
	NSArray *selected = [underwayController selectedObjects];
	[self putShowsBackInQueue:selected];
}
-(void)putShowsBackInQueue:(NSArray *) shows
{
	for ( ProgrammeData *p in shows )
	{
		if (p.downloadStatus == FinishedWithError || p.downloadStatus == Cancelled )
		{
			[queueController insertObject:p atArrangedObjectIndex:0];
			[underwayController removeObject:p];
		}
	}
	[underwayTableView deselectAll:NULL];
	[queueTableView deselectAll:NULL];
}

- (IBAction)addToQueue:(id)sender
{
    for (ProgrammeData *show in resultsController.selectedObjects)
    {
        if ([queueController.arrangedObjects containsObject:show])
		{
            NSAlert *alert = [[NSAlert alloc]init];
            alert.messageText = @"Programme is slready queued for download?";
            [alert runModal];
		}
		else
        {
			if ( [sharedProgrammeCacheController isPidDownloaded:show.productionId])
			{
                
                NSAlert *alert = [[NSAlert alloc]init];
                alert.messageText = @"Programme is slready downloaded. Do you want to download again?";
                alert.informativeText = @"If yes, make sure to delete the programme from your disk before you start downloading.";
                [alert addButtonWithTitle:@"No"];
                [alert addButtonWithTitle:@"Yes"];
                NSModalResponse response = [alert runModal];
                
                if (response == NSAlertSecondButtonReturn)
                {
					NSDictionary *info = @{@"Programme": show};
					[[NSNotificationCenter defaultCenter] postNotificationName:@"RemoveProgFromHistory" object:self userInfo:info];
					
					if ( ![sharedProgrammeCacheController isPidDownloaded:show.productionId])
						[self addToQueue:sender];
				}
			}
            else
			{
				if (runDownloads)
				{
					show.status = @"Waiting...";
				}
				else
				{
					show.status = @"Available";
				}
				[show.downloadProgress setHidden:false];
				[show.downloadProgress setIndeterminate:true];
				[show.downloadProgress startAnimation:NULL];
				[queueController insertObject:show atArrangedObjectIndex:0];
				[queueTableView scrollRowToVisible:0];
				[queueTableView deselectAll:NULL];
			}
        }
    }
}

- (IBAction)removeFromQueue:(id)sender
{
	NSArray *selected = [queueController selectedObjects];
		
	for (ProgrammeData *p in selected )
		[queueController removeObject:p];

}
- (IBAction)hidePvrShow:(id)sender
{
    NSArray *temp_queue = [queueController selectedObjects];
	
    for (ProgrammeData *show in temp_queue)
    {
		[queueController removeObject:show];
		
		NSDictionary *info = @{@"Programme": show};
		[[NSNotificationCenter defaultCenter] postNotificationName:@"AddProgToHistory" object:self userInfo:info];
    }
}
-(void)cleanUpQueue
{
	
	if ( [underwayController.arrangedObjects count] > 0 )
	{
		NSArray *underway = [underwayController arrangedObjects];
		
		for ( ProgrammeData *show in underway )
			if ( show.downloadStatus != FinishedOK )
			{
				if ( [queueController.arrangedObjects count] > 0)
					[queueController insertObject:show atArrangedObjectIndex:0];
				else
					[queueController addObject:show];
			}
		
		[underwayController removeObjectsAtArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [underwayController.arrangedObjects count])]];
	}
	
	if ([[queueController arrangedObjects] count] > 0)
	{
		NSArray *tempQueue = [queueController arrangedObjects];
		NSArray	*searchResult = [[NSArray alloc]init];
		BOOL foundIt;
		
		for (ProgrammeData *show in tempQueue)
		{
			foundIt = false;
			
			if ( show.downloadStatus != FinishedOK )
			{
				searchResult = [sharedProgrammeCacheController searchProgrammeCache:[show programmeName] andSEARCHTYPE:@"Exact" andAllowDownloaded:true];
		
				if ( searchResult.count )
				{
					for ( ProgrammeData *foundProgramme in searchResult )
					{
						if ( [[foundProgramme productionId] isEqualToString:[show productionId]] )
						{
							foundIt = true;
							show.status = @"Available";
							break;
						}
					}
					if ( !foundIt )
					{
						show.status = @"No Longer Available";
						show.downloadStatus = Expired;
					}
				}
			}
		}
	}
	[queueTableView deselectAll:NULL];
	[self saveAppData];
}

#pragma mark Download Controller
- (IBAction)startDownloads:(id)sender
{
	
	
	if ([self amInUk] == false)
	{
		NSAlert *alert = [[NSAlert alloc]init];
		alert.messageText = @"You are not in the UK?";
		alert.informativeText = @"Your downloads will likely fail - Do you want to continue";
		[alert addButtonWithTitle:@"No"];
		[alert addButtonWithTitle:@"Yes"];
		NSModalResponse response = [alert runModal];
		
		if (response == NSAlertFirstButtonReturn)
			return;
	}

    [self saveAppData]; //Save data in case of crash.
	runDownloads = NO;
	BOOL foundOne=NO;
	[mainWindow setDocumentEdited:NO];
	[downloadTasksArray removeAllObjects];
	
	if (!solutionsDictionary)
		solutionsDictionary = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"ReasonsForFailure" ofType:@"plist"]];
	
	[self cleanUpQueue];
	
	if ([[queueController arrangedObjects] count] > 0)
    {

		NSArray *tempQueue = [queueController arrangedObjects];
	
		for (ProgrammeData *show in tempQueue)
		{
			if ( show.downloadStatus == FinishedOK || show.downloadStatus == Expired )
			{
				[queueController removeObject:show];
			}
			else
			{
				show.downloadStatus = NotStarted;
				[show setStatus:@"Waiting..."];
				foundOne=YES;
			}
		}
	}
	
	if (!foundOne)
	{
        if ( !autoPilot ) {
            NSAlert *noShowAlert = [[NSAlert alloc]init];
            noShowAlert.messageText = @"No Shows in Queue!";
            noShowAlert.informativeText = @"Try adding shows to the queue before clicking start; ";
            [noShowAlert runModal];
        }
        autoPilot = false;
		return;
	}
    
    autoPilot = false;
    
	if ( [[_solutionsArrayController arrangedObjects] count] )
			[_solutionsArrayController removeObjectsAtArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [_solutionsArrayController.arrangedObjects count])]];

	runDownloads=YES;
	numberOfITVDownloadsRunning = 0;
	numberOfBBCDownloadsRunning = 0;
	downloadNumber   = 0;
    autoStartMinuteCount = [[[NSUserDefaults standardUserDefaults] objectForKey:@"AutoPilotHours"] intValue]*3600;
	[mainWindow setDocumentEdited:YES];
	[stopButton setEnabled:YES];
	[startButton setEnabled:NO];

	[logger addToLog:@"\rAppController: Starting Downloads" :nil];
    
    if (!autoPilotSleepDisabled)
        IOPMAssertionCreateWithDescription(kIOPMAssertionTypePreventUserIdleSystemSleep, (CFStringRef)@"Downloading Show", (CFStringRef)@"BriTv is downloading shows.", NULL, NULL, (double)0, NULL, &powerAssertionID);
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nextDownload:) name:@"DownloadFinished" object:nil];
            
	NSArray *tempQueue = [queueController arrangedObjects];

	for (ProgrammeData *show in tempQueue)
	{
		if ([[show tvNetwork] hasPrefix:@"ITV"])
		{
			if ( numberOfITVDownloadsRunning < [[[NSUserDefaults standardUserDefaults] objectForKey:@"numberConcurrentITVDownloads"] intValue])
			{
                numberOfITVDownloadsRunning++;
				[self makeProgrammeUnderway:show];
				[downloadTasksArray addObject:[[YoutubeDLDownload alloc] initWithProgramme:show downloadNumber:++downloadNumber]];
			}
		}
		else if ([[show tvNetwork] hasPrefix:@"BBC"])
		{
			if ( numberOfBBCDownloadsRunning < [[[NSUserDefaults standardUserDefaults] objectForKey:@"numberConcurrentBBCDownloads"] intValue])
			{
                numberOfBBCDownloadsRunning++;
				[self makeProgrammeUnderway:show];
                
                if (![[[NSUserDefaults standardUserDefaults] valueForKey:@"GetiPlayer"] boolValue])
                    [downloadTasksArray addObject:[[YoutubeDLDownload  alloc] initWithProgramme:show downloadNumber:++downloadNumber]];
                else
                    [downloadTasksArray addObject:[[GetiPlayerDownload  alloc] initWithProgramme:show downloadNumber:++downloadNumber]];
			}
		}
	}
}

-(void)makeProgrammeUnderway:(ProgrammeData *)show
{
	[underwayController insertObject:show atArrangedObjectIndex:0];
	[queueController removeObject:show];
	[queueTableView deselectAll:NULL];
	[underwayTableView deselectAll:NULL];
}
- (IBAction)stopDownloads:(id)sender
{
    if (!autoPilotSleepDisabled)
        IOPMAssertionRelease(powerAssertionID);
    
    runDownloads=NO;
	
	for ( YoutubeDLDownload *d in downloadTasksArray )
    	[d cancelDownload:self];
	
    if (!runUpdate) {
        [startButton setEnabled:YES];
		[mainWindow setDocumentEdited:NO];
	}
	
    [stopButton setEnabled:NO];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"DownloadFinished" object:nil];
    
    NSArray *tempQueue = [queueController arrangedObjects];
	
    for (ProgrammeData *show in tempQueue)
	{
        if ([[show status] isEqualToString:@"Waiting..."])
		{
			if ( [show addedByPVR])
				[show setStatus:@"Added by Series-Link"];
			else
				[show setStatus:@"Available"];
		}
	}
	
	[downloadTasksArray removeAllObjects];

	
}
- (void)nextDownload:(NSNotification *)note
{
    if (!runDownloads)
		return;
	
	ProgrammeData *finishedShow = [note object];

	if ( [finishedShow.tvNetwork containsString:@"ITV"])
		numberOfITVDownloadsRunning--;
	else
		numberOfBBCDownloadsRunning--;
		
		
	if ( finishedShow.downloadStatus == FinishedOK )
	{
		[finishedShow setValue:@"Download Complete" forKey:@"status"];
        autoStartSuccessCount++;
        downloadSuccessCountOutlet.stringValue = [NSString stringWithFormat:@"%d", autoStartSuccessCount];
        
        [NSString  stringWithFormat:@"%d", autoStartSuccessCount];
            
		@try
		{
			[GrowlApplicationBridge notifyWithTitle:@"Download Finished"
										description:[NSString stringWithFormat:@"%@ Completed Successfully",[finishedShow episodeName]]
									notificationName:@"Download Finished"
											iconData:nil
											priority:0
											isSticky:NO
                                           clickContext:nil];
		}
		@catch (NSException *e)
		{
			[logger addToLog:[NSString stringWithFormat:@"ERROR: Growl notification failed (nextDownload - finished): %@: %@", [e name], [e description]]];
        }
	}
	else
	{
        autoStartFailCount++;
        downloadFailCountOutlet.stringValue = [NSString stringWithFormat:@"%d", autoStartFailCount];
        
		@try
		{
			[GrowlApplicationBridge notifyWithTitle:@"Download Failed"
                                           description:[NSString stringWithFormat:@"%@ failed. See log for details.",[finishedShow episodeName]]
									notificationName:@"Download Failed"
											iconData:nil
											priority:0
											isSticky:NO
										clickContext:nil];
		}
		@catch (NSException *e)
		{
			[logger addToLog:[NSString stringWithFormat:@"ERROR: Growl notification failed (nextDownload - failed): %@: %@", [e name], [e description]]];
		}
            
		ReasonForFailure *showSolution = [[ReasonForFailure alloc] init];
		[showSolution setShortEpisodeName:[finishedShow shortEpisodeName]];
		[showSolution setSolution:solutionsDictionary[finishedShow.reasonForFailure]];
			
		if (![showSolution solution])
			[showSolution setSolution:@"Problem Unknown.\nPlease submit a bug report from the application menu."];

		[_solutionsArrayController addObject:showSolution];
		[solutionsTableView setRowHeight:68];
	}
	
	[self saveAppData]; //Save app data in case of crash.
        
	NSArray *tempQueue = [queueController arrangedObjects];
	
	for (ProgrammeData *nextShow in tempQueue)
	{
		
		if ( nextShow.downloadStatus != NotStarted )
			continue;
		
		if ([[nextShow tvNetwork] hasPrefix:@"ITV"])
		{
			if ( numberOfITVDownloadsRunning < [[[NSUserDefaults standardUserDefaults] objectForKey:@"numberConcurrentITVDownloads"] intValue])
			{
                numberOfITVDownloadsRunning++;
                [logger addToLog:[NSString stringWithFormat:@"\rDownloading Show %@", nextShow.shortEpisodeName] :nil];
				[self makeProgrammeUnderway:nextShow];
				[downloadTasksArray addObject:[[YoutubeDLDownload  alloc] initWithProgramme:nextShow downloadNumber:++downloadNumber]];
			}
		}
		else if ([[nextShow tvNetwork] hasPrefix:@"BBC"])
		{
			if ( numberOfBBCDownloadsRunning < [[[NSUserDefaults standardUserDefaults] objectForKey:@"numberConcurrentBBCDownloads"] intValue])
			{
                numberOfBBCDownloadsRunning++;
                [logger addToLog:[NSString stringWithFormat:@"\rDownloading Show %@", nextShow.shortEpisodeName] :nil];
				[self makeProgrammeUnderway:nextShow];
                
                if (![[[NSUserDefaults standardUserDefaults] valueForKey:@"GetiPlayer"] boolValue])
                    [downloadTasksArray addObject:[[YoutubeDLDownload  alloc] initWithProgramme:nextShow downloadNumber:++downloadNumber]];
                else
                    [downloadTasksArray addObject:[[GetiPlayerDownload  alloc] initWithProgramme:nextShow downloadNumber:++downloadNumber]];

			}
		}
	}
	
	if (numberOfBBCDownloadsRunning == 0 && numberOfITVDownloadsRunning == 0)
	{
		//Downloads must be finished.
        
        if (!autoPilotSleepDisabled)
            IOPMAssertionRelease(powerAssertionID);
            
		[stopButton setEnabled:NO];
		[startButton setEnabled:YES];
		[logger addToLog:@"\rAppController: Downloads Finished" :nil];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:@"DownloadFinished" object:nil];
            
		runDownloads=NO;
		[mainWindow setDocumentEdited:NO];
            
		//Growl Notification
		
		NSUInteger downloadsSuccessful=0, downloadsFailed=0;
		NSArray *tempQueue = [underwayController arrangedObjects];
		
		for (ProgrammeData *show in tempQueue)
			show.downloadStatus == FinishedOK ? downloadsSuccessful++ : downloadsFailed++;

		@try
		{
			[GrowlApplicationBridge notifyWithTitle:@"Downloads Finished"
										description:[NSString stringWithFormat:@"Downloads Successful = %lu\nDownload Failed = %lu",
														(unsigned long)downloadsSuccessful,(unsigned long)downloadsFailed]
									notificationName:@"Downloads Finished"
											iconData:nil
											priority:0
											isSticky:NO
                                           clickContext:nil];
		}
		@catch (NSException *e)
		{
			[logger addToLog:[NSString stringWithFormat:@"ERROR: Growl notification failed (nextDownload - complete): %@: %@", [e name], [e description]]];
		}
		if (downloadsFailed>0)
			[solutionsWindow makeKeyAndOrderFront:self];
	}
}

#pragma mark PVR

-(NSArray *)sortPVRQueue:(NSArray *)qToSort
{
	NSSortDescriptor *sort1 = [NSSortDescriptor sortDescriptorWithKey:@"programmeName" ascending:YES];
	return [qToSort sortedArrayUsingDescriptors:[NSArray arrayWithObjects:sort1, nil]];
}
- (IBAction)pvrSearch:(id)sender
{
	
	if( [pvrSearchField.stringValue length] == 0)
		return;
	
	NSArray	*searchResult;

	[pvrResultsController removeObjectsAtArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [pvrResultsController.arrangedObjects count])]];

	searchResult = [sharedProgrammeCacheController searchProgrammeCache:pvrSearchField.stringValue andSEARCHTYPE:@"Contains" andAllowDownloaded:YES];
	
	if (![searchResult count]) {
        NSAlert *alert = [[NSAlert alloc]init];
        alert.messageText = @"No Shows Found";
        alert.informativeText = @"0 shows were found for your search terms. Please check your spelling!";
		[alert runModal];
		return;
	}

	/* remove duplicates to make it easier to look down the list of available programmes */
	
	searchResult = [self sortQueue:searchResult];
	
	if ( searchResult.count > 1)  {
		NSMutableArray *deDuped = [[NSMutableArray alloc]init];
		NSString *currentProgrammeName = @"";
	
		for ( ProgrammeData *p in searchResult ) {
			if ( ![p.programmeName isEqualToString:currentProgrammeName] ) {
				[deDuped addObject:p];
				currentProgrammeName = p.programmeName;
			}
		}
		searchResult = [[NSArray alloc]initWithArray:deDuped];
	}
	
	[self loadSearchResultIntoQueue:searchResult intoQueue:pvrResultsController];
}

- (IBAction)addToAutoRecord:(id)sender
{
    NSArray *selected = [[NSArray alloc] initWithArray:[pvrResultsController selectedObjects]];
	
    for (ProgrammeData *programme in selected)
    {
        SeriesLink *show = [[SeriesLink alloc] initWithShowname:[programme programmeName]];
        show.tvNetwork = programme.tvNetwork;
        
        //Check to make sure the programme isn't already in the queue before adding it.
		
        NSArray *queuedObjects = [pvrQueueController arrangedObjects];
        BOOL add=YES;
        for (ProgrammeData *queuedShow in queuedObjects)
        {
            if ([[show programmeName] isEqualToString:[queuedShow programmeName]] && [show tvNetwork] == [queuedShow tvNetwork])
                add=NO;
        }
        if (add)
        {
            [pvrQueueController addObject:show];
        }
    }
}

-(IBAction)addSeriesLinkToQueue:(id)sender
{
    
	/* Remove items in Q that have been downloaded or have expired  */

	NSArray *tempQueue = [queueController arrangedObjects];
	NSMutableArray *showsToDeleteFromQueue = [[NSMutableArray alloc]init];
	
	for (ProgrammeData *show in tempQueue)
		if ( show.downloadStatus == FinishedOK || [show addedByPVR] )
			[showsToDeleteFromQueue addObject:show];
	
	[queueController removeObjects:showsToDeleteFromQueue];
	
	/* Now rebuild based on full cache */
	
	NSArray *seriesLink = [pvrQueueController arrangedObjects];
	NSArray *searchResult;
	NSMutableArray *showsToAdd = [[NSMutableArray alloc]init];
	
	for (SeriesLink *series in seriesLink) {
		
		searchResult = [sharedProgrammeCacheController searchProgrammeCache:series.programmeName andSEARCHTYPE:@"Exact" andAllowDownloaded:NO];
		
		if ( !searchResult.count )
			continue;
		
		NSArray *currentQueue = [queueController arrangedObjects];
		
		for ( ProgrammeData *p in searchResult )  {

			p.status =  @"Added by Series-Link";
			p.addedByPVR = true;
			BOOL inQueue=NO;
			
			for (ProgrammeData *show in currentQueue)
				if ( [[show productionId]isEqualToString:[p productionId]])
					inQueue=YES;
			
			if (inQueue)
				continue;
			
			if (runDownloads)
				[p setValue:@"Waiting..." forKey:@"status"];
			
			[showsToAdd addObject:p];
		}
	}

	NSArray *sortedShowsToAdd = [self sortQueue:showsToAdd];
	
	for (ProgrammeData *p in sortedShowsToAdd)
		[queueController insertObject:p atArrangedObjectIndex:0];
																		
	[self updateImages:sortedShowsToAdd];
	[queueController setSelectionIndexes:[NSIndexSet indexSet]];
	[queueTableView scrollRowToVisible:0];
	[queueTableView deselectAll:NULL];
	
}

#pragma mark Misc.

- (void)saveAppData
{
    //Save Queue & Series-Link
    NSMutableArray *tempQueue = [[NSMutableArray alloc] initWithArray:[queueController arrangedObjects]];
    NSMutableArray *tempSeries = [[NSMutableArray alloc] initWithArray:[pvrQueueController arrangedObjects]];
    NSMutableArray *temptempQueue = [[NSMutableArray alloc] initWithArray:tempQueue];
	
    for (ProgrammeData *show in temptempQueue)
        if ( show.downloadStatus == FinishedOK || [show addedByPVR] )
			[tempQueue removeObject:show];
			
    NSMutableArray *temptempSeries = [[NSMutableArray alloc] initWithArray:tempSeries];
    for (SeriesLink *series in temptempSeries)
    {
        if ([[series programmeName] length] == 0) {
            [tempSeries removeObject:series];
        } else if ([[series tvNetwork] length] == 0) {
            [series setTvNetwork:@"*"];
        }
        
    }
	
	NSMutableArray *tempUnderwayQueue = [[NSMutableArray alloc] initWithArray:[underwayController arrangedObjects]];
	
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString *folder = @"~/Library/Application Support/BriTv/";
    folder = [folder stringByExpandingTildeInPath];
    if ([fileManager fileExistsAtPath: folder] == NO)
    {
        [fileManager createDirectoryAtPath:folder withIntermediateDirectories:NO attributes:nil error:nil];
    }
    NSString *filename = @"Queue.automatorqueue";
    NSString *filePath = [folder stringByAppendingPathComponent:filename];
    
    NSMutableDictionary * rootObject;
    rootObject = [NSMutableDictionary dictionary];
    
    [rootObject setValue:tempQueue forKey:@"queue"];
    [rootObject setValue:tempSeries forKey:@"serieslink"];
    [rootObject setValue:tempUnderwayQueue forKey:@"underwayQueue"];
    [rootObject setValue:lastUpdate forKey:@"lastUpdate"];
    [NSKeyedArchiver archiveRootObject: rootObject toFile: filePath];
    
    //Store Preferences in case of crash
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (IBAction)closeWindow:(id)sender
{
    if ([logger.window isKeyWindow]) [logger.window performClose:self];
    else if ([historyWindow isKeyWindow]) [historyWindow performClose:self];
    else if ([pvrPanel isKeyWindow]) [pvrPanel performClose:self];
    else if ([prefsPanel isKeyWindow]) [prefsPanel performClose:self];
    else if ([newProgrammesWindow isKeyWindow]) [newProgrammesWindow performClose:self];
    else if ([mainWindow isKeyWindow])
    {
        NSAlert *alert = [[NSAlert alloc]init];
        alert.messageText = @"Are you sure you wish to quit?";
        [alert addButtonWithTitle:@"Yes"];
        [alert addButtonWithTitle:@"No"];
        NSModalResponse response = [alert runModal];
        
        if (response == NSAlertFirstButtonReturn)
            [mainWindow performClose:self];
    }
}
- (NSString *)escapeSpecialCharactersInString:(NSString *)string
{
    NSArray *characters = @[@"+", @"-", @"&", @"!", @"(", @")", @"{" ,@"}",
                            @"[", @"]", @"^", @"~", @"*", @"?", @":", @"\""];
    for (NSString *character in characters)
        string = [string stringByReplacingOccurrencesOfString:character withString:[NSString stringWithFormat:@"\\%@",character]];
    
    return string;
}

- (IBAction)chooseDownloadPath:(id)sender
{
    NSOpenPanel *openPanel = [[NSOpenPanel alloc] init];
    [openPanel setCanChooseFiles:NO];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setCanCreateDirectories:YES];
    [openPanel runModal];
    NSArray *urls = [openPanel URLs];
    [[NSUserDefaults standardUserDefaults] setValue:[urls[0] path] forKey:@"DownloadPath"];
}
- (IBAction)restoreDefaults:(id)sender
{
    NSUserDefaults *sharedDefaults = [NSUserDefaults standardUserDefaults];
    [sharedDefaults removeObjectForKey:@"DownloadPath"];
    [sharedDefaults removeObjectForKey:@"DefaultBrowser"];
    [sharedDefaults removeObjectForKey:@"CacheBBC_TV"];
    [sharedDefaults removeObjectForKey:@"CacheITV_TV"];
    [sharedDefaults removeObjectForKey:@"GetiPlayer"];
    [sharedDefaults removeObjectForKey:@"AutoPilotHours"];
    [sharedDefaults removeObjectForKey:@"AutoPilotAbandonCount"];
    [sharedDefaults removeObjectForKey:@"CacheExpiryTime"];
	[sharedDefaults removeObjectForKey:@"numberConcurrentITVDownloads"];
	[sharedDefaults removeObjectForKey:@"numberConcurrentBBCDownloads"];
	[sharedDefaults removeObjectForKey:@"numberITVRetries"];
	[sharedDefaults removeObjectForKey:@"numberBBCRetries"];
    [sharedDefaults removeObjectForKey:@"Verbose"];
	[sharedDefaults removeObjectForKey:@"IgnoreGeoPositionService"];
    [sharedDefaults removeObjectForKey:@"SeriesLinkStartup"];
    [sharedDefaults removeObjectForKey:@"BBCOne"];
    [sharedDefaults removeObjectForKey:@"BBCTwo"];
    [sharedDefaults removeObjectForKey:@"BBCThree"];
    [sharedDefaults removeObjectForKey:@"BBCFour"];
	[sharedDefaults removeObjectForKey:@"ITV"];
    [sharedDefaults removeObjectForKey:@"IgnoreAllTVNews"];
	[sharedDefaults removeObjectForKey:@"ShowDownloadedInSearch"];
}
#pragma mark ITV Cache Reset
- (IBAction)forceITVUpdate:(id)sender
{
    forceITVUpdateInProgress = YES;
    forceITVUpdateMenuItem.enabled = NO;
    
    [searchField setEnabled:NO];
    [stopButton setEnabled:NO];
    [startButton setEnabled:NO];
    [pvrSearchField setEnabled:NO];
    [addSeriesLinkToQueueButton setEnabled:NO];
    [refreshCacheButton setEnabled:NO];
    [forceCacheUpdateMenuItem setEnabled:NO];
    [checkForCacheUpdateMenuItem setEnabled:NO];
        
    [[self itvProgressIndicator] setDoubleValue:0.0];
    [[self itvProgressIndicator] setHidden:false];
    [itvProgressText setHidden:false];
	[updatingIndexesText setHidden:false];
	
    updatingITVIndex=true;
	
	[opsQueue addOperation:[[NSInvocationOperation alloc] initWithTarget:newITVListing selector:@selector(forceITVUpdate) object:NULL]];
}

-(void)forceITVUpdateFinished
{
    forceITVUpdateInProgress = NO;
    forceITVUpdateMenuItem.enabled = YES;
    
    [self itvUpdateFinished];
}


#pragma mark BBC Cache Reset

- (IBAction)forceBBCUpdate:(id)sender
{
	forceBBCUpdateInProgress = YES;
	forceBBCUpdateMenuItem.enabled = NO;
	
	[searchField setEnabled:NO];
	[stopButton setEnabled:NO];
	[startButton setEnabled:NO];
	[pvrSearchField setEnabled:NO];
	[addSeriesLinkToQueueButton setEnabled:NO];
	[refreshCacheButton setEnabled:NO];
	[forceCacheUpdateMenuItem setEnabled:NO];
	[checkForCacheUpdateMenuItem setEnabled:NO];
	
	[[self bbcProgressIndicator] setDoubleValue:0.0];
	[[self bbcProgressIndicator] setHidden:false];
	[bbcProgressText setHidden:false];
	[updatingIndexesText setHidden:false];
	updatingBBCIndex=true;
	
	[opsQueue addOperation:[[NSInvocationOperation alloc] initWithTarget:newBBCListing selector:@selector(forceBBCUpdate) object:NULL]];	
}

-(void)forceBBCUpdateFinished
{
	forceBBCUpdateInProgress = NO;
	forceBBCUpdateMenuItem.enabled = YES;
	
	[self bbcUpdateFinished];
}


#pragma mark New Programmes History
- (IBAction)showNewProgrammesAction:(id)sender
{
    npHistoryTableViewController = [[NPHistoryTableViewController alloc]initWithWindowNibName:@"NPHistoryWindow"];
    [npHistoryTableViewController showWindow:self];
    newProgrammesWindow = [npHistoryTableViewController window];
}

-(void)updateHistory
{

    NSArray *files = @[@"bbcprogrammes", @"itvprogrammes"];
    NSArray *types = @[@"BBC TV", @"ITV"];
    BOOL active[] = {false, false};
    
    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"CacheBBC_TV"] boolValue])
        active[0]=true;
    
    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"CacheITV_TV"] boolValue])
        active[1]=true;
             
    NSString *filePath = @"~/Library/Application Support/BriTv";
    filePath= [filePath stringByExpandingTildeInPath];
    
    for (int i = 0; i < types.count; i++ )
    {
        NSString *bfFile = [filePath stringByAppendingFormat:@"/%@.bf", files[i]];
        NSString *cfFile = [filePath stringByAppendingFormat:@"/%@.gia", files[i]];
        
        if (active[i])
            [self updateHistoryForType:types[i] andBFFile:bfFile andCFFile:cfFile];
    }
    
    [sharedHistoryController flushHistoryToDisk];
}

-(void)updateHistoryForType:(NSString *)networkName andBFFile:(NSString *)bfFile andCFFile:(NSString *)cfFile
{

    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL firstTimeBuild;
    
    if ( [fileManager fileExistsAtPath:cfFile] && ![fileManager fileExistsAtPath:bfFile] )
        firstTimeBuild = true;
    else
        firstTimeBuild = false;
    
    NSMutableArray *oldProgrammesArray = [NSKeyedUnarchiver unarchiveObjectWithFile:bfFile];
   
    if ( oldProgrammesArray == nil )
        oldProgrammesArray = [[NSMutableArray alloc]init];
	
	NSMutableArray *cfProgrammesArray = [NSKeyedUnarchiver unarchiveObjectWithFile:cfFile];
	
	if ( cfProgrammesArray == nil )
		cfProgrammesArray = [[NSMutableArray alloc]init];

    /* Load in todays shows (CF) cached getITVListings and create a dictionary of show names */

    
    NSMutableSet *todayProgrammes = [[NSMutableSet alloc]init];
    
    for ( ProgrammeData *programme in cfProgrammesArray )
    {
        ProgrammeHistoryObject *p = [[ProgrammeHistoryObject alloc]initWithName:programme.programmeName andTVChannel:programme.tvNetwork andDateFound:@"" andSortKey:0 andNetworkName:networkName];
		
        [todayProgrammes addObject:p];
    }
    
    /* Put back today's programmes for comparison on the next run */
    
    NSArray *cfProgrammes = [todayProgrammes allObjects];
    [NSKeyedArchiver archiveRootObject:cfProgrammes toFile:bfFile];
    
    /* subtract bought forward from today to create new programmes list */
    
    NSSet *oldProgrammeSet  = [NSSet setWithArray:oldProgrammesArray];
    [todayProgrammes minusSet:oldProgrammeSet];
    NSArray *newProgrammesArray = [todayProgrammes allObjects];

    /* and update history file with new programmes */
    
    if ( !firstTimeBuild )
        for ( ProgrammeHistoryObject *p in newProgrammesArray )
            [sharedHistoryController addToNewProgrammeHistory:[p programmeName] andTVChannel:[p tvChannel] andNetworkName:networkName];


}

-(IBAction)changeNewProgrmmeDisplayFilter:(id)sender
{
    NSNotificationCenter *nc;
    nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:@"NewProgrammeDisplayFilterChanged" object:nil];
}

#pragma convertHistory

-(void)convertHistory
{
	
	// Current format is download_history.v2 so first see if any conversion is needed - options are:
	// 	from download_history to download_history.v1
	// 	from download_history.v1 to download_history.v2
	
	
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	NSString *historyFilePath = @"~/Library/Application Support/BriTv/download_history.v2";
	historyFilePath = [historyFilePath stringByExpandingTildeInPath];
	
	if ([fileManager fileExistsAtPath: historyFilePath] == YES )
		return;
	
	historyFilePath = @"~/Library/Application Support/BriTv/download_history.v1";
	historyFilePath = [historyFilePath stringByExpandingTildeInPath];
	
	if ([fileManager fileExistsAtPath: historyFilePath] == YES )
	{
		[self convertHistoryV1toV2];
		return;
	}
	
	historyFilePath = @"~/Library/Application Support/BriTv/download_history";
	historyFilePath = [historyFilePath stringByExpandingTildeInPath];
	
	if ([fileManager fileExistsAtPath: historyFilePath] == YES )
	{
		[self convertHistorytoV1];
		[self convertHistoryV1toV2];
		return;
	}

}

-(void)convertHistorytoV1
{
	[logger addToLog:@"Converting download_history to V1"];
	
	/* Used to do a one off conversion after ITV website changes to PID format of January 2018 */
	
	NSMutableArray *historyArray = [[NSMutableArray alloc]init];

	NSString *historyFilePath = @"~/Library/Application Support/BriTv/download_history";
	historyFilePath = [historyFilePath stringByExpandingTildeInPath];

	NSError *error;
	NSString *history = [NSString stringWithContentsOfFile:historyFilePath encoding:NSUTF8StringEncoding error:&error];
	
	BOOL finished = false;
	
	NSScanner *s1 = [NSScanner scannerWithString:history];
	NSScanner *s2 = [[NSScanner alloc]init];
	NSString  *record;
		
	[s1 scanUpToString:@"\n" intoString:&record];
		
	while ( !finished )  {
			
		if ( [s1 isAtEnd])
			finished = true;
			
		[s1 scanString:@"\n" intoString:NULL];
		s2 = [NSScanner scannerWithString:record];
			
		NSString *pidtwo, *showNametwo, *episodeNametwo, *typetwo, *someNumbertwo, *downloadFormattwo, *downloadPathtwo;
			
		[s2 scanUpToString:@"|" intoString:&pidtwo];				// 1  ProductionID
		[s2 scanString:@"|" intoString:nil];
		[s2 scanUpToString:@"|" intoString:&showNametwo];			// 2  programme Name
		[s2 scanString:@"|" intoString:nil];
		[s2 scanUpToString:@"|" intoString:&episodeNametwo];		// 3  Series
		[s2 scanString:@"|" intoString:nil];
		[s2 scanUpToString:@"|" intoString:&typetwo];				// 4  Episode
		[s2 scanString:@"|" intoString:nil];
		[s2 scanUpToString:@"|" intoString:&someNumbertwo];			// 5  Date Aired
		[s2 scanString:@"|" intoString:nil];
		[s2 scanUpToString:@"|" intoString:&downloadFormattwo];		// 6 Title
		[s2 scanString:@"|" intoString:nil];
		[s2 scanUpToString:@"|" intoString:&downloadPathtwo];		// 7 Version (2) = New otherwise only field 1 & 2 are valid
	
		if (  [pidtwo containsString:@"#"] )  {
			NSArray *pidComponents = [pidtwo componentsSeparatedByString:@"#"];
			pidtwo = [pidComponents firstObject];
		}
	
		if ( [pidtwo containsString:@"/"]  )  {
			pidtwo = [pidtwo stringByReplacingOccurrencesOfString:@"/" withString:@"a"];
		}
		
		int foundCount = 0;
		NSMutableString *newPid = [[NSMutableString alloc]init];
		
		for (int i=0; i<pidtwo.length;i++) {
			
			if ( [pidtwo characterAtIndex:i] == 'a')
				foundCount++;
			
			if ( foundCount > 2 ) {
				pidtwo = newPid;
				break;
			}
			
			[newPid appendString:[pidtwo substringWithRange:NSMakeRange(i, 1)]];
		}
		
		NSString *historyEntry = [NSString stringWithFormat:@"%@|%@|%@|%@|%@|%@|%@", pidtwo, showNametwo, episodeNametwo, typetwo, someNumbertwo, downloadFormattwo, downloadPathtwo];
		
		[historyArray addObject:historyEntry];
			
		[s1 scanUpToString:@"\n" intoString:&record];

	}

	/* Now write the new V1 format file */

	[logger addToLog:@"Writing download_history.v1"];
	
	NSMutableString *historyString = [[NSMutableString alloc] init];
		
	for (NSString *entry in historyArray)
		[historyString appendFormat:@"%@\n", entry];
	
	NSData *historyData = [historyString dataUsingEncoding:NSUTF8StringEncoding];
	
	NSFileManager *fileManager = [[NSFileManager alloc]init];
	historyFilePath = @"~/Library/Application Support/BriTv/download_history.v1";
	historyFilePath = [historyFilePath stringByExpandingTildeInPath];
	

	if (![fileManager createFileAtPath:historyFilePath contents:historyData attributes:nil])
	{
        NSAlert *alert = [[NSAlert alloc]init];
        alert.messageText = @"Could not create/write history file Version 1";
        alert.informativeText = @"Please submit a bug report saying that the history file could not be created.";
        [alert runModal];
        [logger addToLog:@"Could not create history file V1!"];
	}
}

-(void)convertHistoryV1toV2
{
	/* Used to do a one off conversion after ITV website changes of January 2018 */
	
	[logger addToLog:@"Converting download_history.V1 to V2"];
	
	NSMutableArray *historyArray = [[NSMutableArray alloc]init];
	
	NSString *historyFilePath = @"~/Library/Application Support/BriTv/download_history.v1";
	historyFilePath = [historyFilePath stringByExpandingTildeInPath];
	
	NSError *error;
	NSString *history = [NSString stringWithContentsOfFile:historyFilePath encoding:NSUTF8StringEncoding error:&error];
	
	BOOL finished = false;
	
	NSScanner *s1 = [NSScanner scannerWithString:history];
	NSScanner *s2 = [[NSScanner alloc]init];
	NSString  *record;
	
	[s1 scanUpToString:@"\n" intoString:&record];
	
	while ( !finished )  {
		
		if ( [s1 isAtEnd])
			finished = true;
		
		[s1 scanString:@"\n" intoString:NULL];
		s2 = [NSScanner scannerWithString:record];
		
		NSString *pidtwo, *showNametwo, *episodeNametwo, *typetwo, *someNumbertwo, *downloadFormattwo, *downloadPathtwo;
		
		[s2 scanUpToString:@"|" intoString:&pidtwo];				// 1  ProductionID
		[s2 scanString:@"|" intoString:nil];
		[s2 scanUpToString:@"|" intoString:&showNametwo];			// 2  programme Name
		[s2 scanString:@"|" intoString:nil];
		[s2 scanUpToString:@"|" intoString:&episodeNametwo];		// 3  Series
		[s2 scanString:@"|" intoString:nil];
		[s2 scanUpToString:@"|" intoString:&typetwo];				// 4  Episode
		[s2 scanString:@"|" intoString:nil];
		[s2 scanUpToString:@"|" intoString:&someNumbertwo];			// 5  Date Aired
		[s2 scanString:@"|" intoString:nil];
		[s2 scanUpToString:@"|" intoString:&downloadFormattwo];		// 6 Title
		[s2 scanString:@"|" intoString:nil];
		[s2 scanUpToString:@"|" intoString:&downloadPathtwo];		// 7 Version (2) = New otherwise only field 1 & 2 are valid
		
		NSArray *nameArray1 = [showNametwo componentsSeparatedByString:@"-"];
		NSArray *nameArray2 = [showNametwo componentsSeparatedByString:@":"];

		NSString *programmeName = [nameArray1[0] length] > [nameArray2[0] length] ? nameArray2[0] : nameArray1[0];
		NSString *episodeName = [showNametwo stringByReplacingOccurrencesOfString:programmeName withString:@""];
		episodeName = [episodeName stringByReplacingOccurrencesOfString:@"-" withString:@""];
		episodeName = [episodeName stringByReplacingOccurrencesOfString:@":" withString:@""];
		episodeName = [episodeName stringByReplacingOccurrencesOfString:@"  " withString:@" "];
		episodeName = [episodeName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		
		DownloadHistoryEntry *historyEntry = [[DownloadHistoryEntry alloc] initWithPID:pidtwo ProgrammeName:programmeName EpisodeName:episodeName];

		[historyArray addObject:historyEntry];
		
		[s1 scanUpToString:@"\n" intoString:&record];
	}
	
	/* Now write the new V2 format file */
	
	[logger addToLog:@"Writing download_history.v2"];
	
	NSMutableString *historyString = [[NSMutableString alloc] init];
	
	for (DownloadHistoryEntry *entry in historyArray)
		[historyString appendFormat:@"%@\n", [entry entryString]];
	
	NSData *historyData = [historyString dataUsingEncoding:NSUTF8StringEncoding];
	
	NSFileManager *fileManager = [[NSFileManager alloc]init];
	historyFilePath = @"~/Library/Application Support/BriTv/download_history.v2";
	historyFilePath = [historyFilePath stringByExpandingTildeInPath];
	
	if (![fileManager createFileAtPath:historyFilePath contents:historyData attributes:nil])
	{
        NSAlert *alert = [[NSAlert alloc]init];
        alert.messageText = @"Could not create/write history file Version 2";
        alert.informativeText = @"Please submit a bug report saying that the history file could not be created.";
        [alert runModal];
		[logger addToLog:@"Could not create history file V2!"];
	}
}


#pragma mark Properties

-(bool)amInUk
{
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"IgnoreGeoPositionService"] == true)
	{
		location.stringValue = @"Location Unknown";
		location.textColor = [NSColor grayColor];
		return true;
	}
	
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://iplocation.com"]];
	NSData *data = [[NSData alloc] initWithContentsOfURL:url];
	NSString *pageContent = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
	NSScanner *scanner = [[NSScanner alloc]initWithString:pageContent];
	
	NSString *locationString = @"";
	
	NSString *country;
	[scanner scanUpToString:@"\"country_name\">" intoString:NULL];
	[scanner scanString:@"\"country_name\">"  intoString:NULL];
	[scanner scanUpToString:@"<" intoString:&country];
	
	if (country != NULL)
		locationString = country;
						  
	NSString *region;
	[scanner scanUpToString:@"\"region_name\">" intoString:NULL];
	[scanner scanString:@"\"region_name\">"  intoString:NULL];
	[scanner scanUpToString:@"<" intoString:&region];
	
	NSString *city;
	[scanner scanUpToString:@"\"city\">" intoString:NULL];
	[scanner scanString:@"\"city\">"  intoString:NULL];
	[scanner scanUpToString:@"<" intoString:&city];
	
	if ( [city isEqualToString:region])
		city = NULL;
		
	if (city != NULL && region != NULL)
		locationString = [NSString stringWithFormat:@"%@ (%@, %@)", country, city, region];
	else if (city != NULL)
		locationString = [NSString stringWithFormat:@"%@ (%@)", country, city];
	else if (region != NULL)
		locationString = [NSString stringWithFormat:@"%@ (%@)", country, region];
	
	location.stringValue = locationString;
	
	if ( [country isEqualTo:@"United Kingdom"] )
		location.textColor = [NSColor blackColor];
	else
		location.textColor = [NSColor redColor];
	
	return [country isEqualTo:@"United Kingdom"];
}


@end
