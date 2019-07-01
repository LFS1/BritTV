//
//  DownloadHistoryController.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 10/15/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "DownloadHistoryController.h"
#import "DownloadHistoryEntry.h"
#import "ProgrammeData.h"


@implementation DownloadHistoryController

- (id)init
{
	if (!(self = [super init]))
		return nil;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addToHistory:) name:@"AddProgToHistory" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(removeProgFromHistory:) name:@"RemoveProgFromHistory" object:nil];
	
	historyFilePath = @"~/Library/Application Support/BriTv/download_history.v2";
	historyFilePath = [historyFilePath stringByExpandingTildeInPath];
	fileAttribs = [[NSFileManager defaultManager] attributesOfItemAtPath:historyFilePath error:nil];
	timeLastRead = [NSDate date];
	
	return self;
}

- (void)readHistory:(id)sender
{
	
	NSDate *timeChanged = [fileAttribs objectForKey:NSFileModificationDate];
	
	if ( [timeChanged compare:timeLastRead] == NSOrderedSame )
		return;
	
	timeLastRead = timeChanged;

	NSError *error;
	NSString *history = [NSString stringWithContentsOfFile:historyFilePath encoding:NSUTF8StringEncoding error:&error];
	
	if ([[historyArrayController arrangedObjects] count] > 0)
		[historyArrayController removeObjectsAtArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [[historyArrayController arrangedObjects] count])]];
	
	BOOL finished = false;
	
	if ([history length] > 0)
	{
		NSScanner *s1 = [NSScanner scannerWithString:history];
		NSScanner *s2 = [[NSScanner alloc]init];
		NSString  *record;
		
		[s1 scanUpToString:@"\n" intoString:&record];
		
		while ( !finished )  {
			
			if ( [s1 isAtEnd])
				finished = true;
			
			[s1 scanString:@"\n" intoString:NULL];
			s2 = [NSScanner scannerWithString:record];
			
			NSString *pid, *dateTimeRecorded, *programmeName, *episodeName;
			
			[s2 scanUpToString:@"|" intoString:&pid];
			[s2 scanString:@"|" intoString:nil];
			[s2 scanUpToString:@"|" intoString:&dateTimeRecorded];
			[s2 scanString:@"|" intoString:nil];
			[s2 scanUpToString:@"|" intoString:&programmeName];
			[s2 scanString:@"|" intoString:nil];
			[s2 scanUpToString:@"|" intoString:&episodeName];
			
			DownloadHistoryEntry *historyEntry = [[DownloadHistoryEntry alloc] initWithPID:pid
																			 ProgrammeName:programmeName
																			   EpisodeName:episodeName];
			historyEntry.dateTimeRecorded = dateTimeRecorded;
			
			[historyArrayController addObject:historyEntry];
			
			[s1 scanUpToString:@"\n" intoString:&record];
		}
	}
	[self sortHistory];
}
-(void)sortHistory
{
	NSMutableArray *historyArray = [[NSMutableArray alloc]initWithArray:[historyArrayController arrangedObjects]];

	NSSortDescriptor *sort1 = [NSSortDescriptor sortDescriptorWithKey:@"dateTimeRecorded" ascending:NO];
	NSSortDescriptor *sort2 = [NSSortDescriptor sortDescriptorWithKey:@"programmeName" ascending:YES];
	NSSortDescriptor *sort3 = [NSSortDescriptor sortDescriptorWithKey:@"productionId" ascending:YES];
	[historyArray sortUsingDescriptors:[NSArray arrayWithObjects:sort1, sort2, sort3, nil]];
	
	[historyArrayController removeObjectsAtArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [historyArrayController.arrangedObjects count])]];
	[historyArrayController addObjects:historyArray];
	[historyArrayController setSelectionIndexes:[NSIndexSet indexSet]];
	[historyTableView scrollRowToVisible:1];
}
- (IBAction)writeHistory:(id)sender
{
	if (!runDownloads || [sender isEqualTo:self])
	{
		NSArray *currentHistory = [historyArrayController arrangedObjects];
		NSMutableString *historyString = [[NSMutableString alloc] init];

		for (DownloadHistoryEntry *entry in currentHistory)
			[historyString appendFormat:@"%@\n", [entry entryString]];

		NSData *historyData = [historyString dataUsingEncoding:NSUTF8StringEncoding];
		NSFileManager *fileManager = [NSFileManager defaultManager];
		
		if (![fileManager fileExistsAtPath:historyFilePath])
        {
			if (![fileManager createFileAtPath:historyFilePath contents:historyData attributes:nil])
            {
                NSAlert *alert = [[NSAlert alloc]init];
                alert.messageText = @"Could not create history file!";
                alert.informativeText =  @"Please submit a bug report saying that the history file could not be created.";
                [alert runModal];
                [self addToLog:@"Could not create history file!"];
            }
        }
		else
        {
			NSError *writeToFileError;
			if (![historyData writeToFile:historyFilePath options:NSDataWritingAtomic error:&writeToFileError])
            {
                NSAlert *alert = [[NSAlert alloc]init];
                alert.messageText = @"Could not write to history file!";
                alert.informativeText =  @"Please submit a bug report saying that the history file could not be created.";
                [alert runModal];
                [self addToLog:@"Could not write to history file!"];
			}
        }
	}
	else
	{
        NSAlert *alert = [[NSAlert alloc]init];
        alert.messageText = @"Download History cannot be edited while downloads are running.";
        alert.informativeText =  @"Please try again after the current downloads have completed";
        [alert runModal];
		[historyWindow close];
	}
	[saveButton setEnabled:NO];
	[historyWindow setDocumentEdited:NO];
}

-(IBAction)showHistoryWindow:(id)sender
{
	if ([self editIsAllowed])
	{
		if (![historyWindow isDocumentEdited])
			[self readHistory:self];
		
		[self sortHistory];
		[historyWindow makeKeyAndOrderFront:self];
		[saveButton setEnabled:[historyWindow isDocumentEdited]];
	}
}

-(BOOL)editIsAllowed
{
	if ( runDownloads )
	{
        NSAlert *alert = [[NSAlert alloc]init];
        alert.messageText = @"Download History cannot be edited while downloads are running.";
        alert.informativeText =  @"Please try again after the current downloads have completed";
        [alert runModal];
		
		return false;
	}
	return true;
}
-(IBAction)removeSelectedFromHistory:(id)sender;
{
	if ([self editIsAllowed])
	{
		[saveButton setEnabled:YES];
		[historyWindow setDocumentEdited:YES];
		[historyArrayController remove:self];
	}
	else
	{
		[historyWindow close];
	}
}
- (IBAction)cancelChanges:(id)sender
{
	[historyWindow setDocumentEdited:NO];
	[saveButton setEnabled:NO];
	[historyWindow close];
}
- (void)addToHistory:(NSNotification *)note
{

	NSDictionary *userInfo = [note userInfo];
	ProgrammeData *prog = [userInfo valueForKey:@"Programme"];
		
	DownloadHistoryEntry *entry = [[DownloadHistoryEntry alloc] initWithPID:prog.productionId
															  ProgrammeName:prog.programmeName
																EpisodeName:prog.displayInfo];
								   
	[historyArrayController insertObject:entry atArrangedObjectIndex:0];

	NSMutableString *historyString = [[NSMutableString alloc] init];
	[historyString appendFormat:@"%@\n", [entry entryString]];

	NSFileManager *fileManager = [NSFileManager defaultManager];
		
	if(![fileManager fileExistsAtPath:historyFilePath])
	{
		NSError *error;
		[historyString writeToFile:historyFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
	}
	else
	{
		NSFileHandle *myHandle = [NSFileHandle fileHandleForWritingAtPath:historyFilePath];
		[myHandle seekToEndOfFile];
		[myHandle writeData:[historyString dataUsingEncoding:NSUTF8StringEncoding]];
	}

}

-(void)removeProgFromHistory:(NSNotification *)note
{
	
	NSDictionary *userInfo = [note userInfo];
	ProgrammeData *prog = [userInfo valueForKey:@"Programme"];
	
	if ( [self editIsAllowed])
	{
		[self readHistory:NULL];
		
		NSArray *currentHistory = [historyArrayController arrangedObjects];
		BOOL fountIt = false;
		
		for (DownloadHistoryEntry *entry in currentHistory)
		{
			
			if ( [[entry productionId] isEqualToString:prog.productionId]) {
				fountIt = true;
				[historyArrayController removeObject:entry];
				break;
			}
		}
		if ( fountIt )
		{
			[self writeHistory:NULL];
		}
		else
		{
            NSAlert *alert = [[NSAlert alloc]init];
            alert.messageText = @"Could not find the requested programme in the history.";
            [alert runModal];
		}
	}

}
- (void)addToLog:(NSString *)logMessage
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"AddToLog" object:self userInfo:@{@"message": logMessage}];
}

@end
