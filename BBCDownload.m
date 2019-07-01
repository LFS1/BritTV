//
//  Download.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/14/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "BBCDownload.h"

@implementation BBCDownload


#pragma mark Overridden Methods
- (id)initWithProgramme:(Programme *)tempShow logController:(LogController *)aLogger
{
	if (!(self = [super initWithLogController:aLogger])) return nil;
	
	runAgain = NO;
	running=YES;
	foundLastLine=NO;
	errorCache = [[NSMutableString alloc] init];
	processErrorCache = [NSTimer scheduledTimerWithTimeInterval:.25 target:self selector:@selector(processError) userInfo:nil repeats:YES];
	reasonForFailure = @"None";
	defaultsPrefix = @"BBC_";
   
	log = [[NSMutableString alloc] initWithString:@""];
	nc = [NSNotificationCenter defaultCenter];
	show = tempShow;
	[self addToLog:[NSString stringWithFormat:@"Downloading %@", [show showName]]];
	noDataCount=0;
   
   //Initialize Paths
	
	NSBundle *bundle = [NSBundle mainBundle];
	NSString *getiPlayerPath = [bundle pathForResource:@"get_iplayer" ofType:@"pl"];
	downloadPath = [[NSString alloc] initWithString:[[NSUserDefaults standardUserDefaults] valueForKey:@"DownloadPath"]];
	NSString *appSupportFolder = [@"~/Library/Application Support/Get iPlayer Automator Lite/" stringByExpandingTildeInPath];
	NSString *executablesPath = [bundle.executablePath stringByDeletingLastPathComponent];
	
	// Build args for iplayer
	
	profileDirArg				=	[NSString stringWithFormat:@"--profile-dir=%@", appSupportFolder];
	NSString *typeArg			=	@"--type=tv";
	NSString *logArg            =   @"--log-progress";
	NSString *noWarningArg		=	@"--nocopyright";
	NSString *pidArg			=	[NSString stringWithFormat:@"--pid=%@", show.pid];
	NSString *attemptsArg		=	@"--attempts=5";
	NSString *formatArg			=	@"--modes=tvbest,tvbetter,tvvgood,tvgood";
	NSString *noPurgeArg		=	@"--nopurge";
	NSString *subDirArg			=	@"--subdir";
	NSString *subDirFormatArg;
	
	if ( [tempShow season] )
		subDirFormatArg	=	@"--subdir-format=<nameshort> (<series>)";
	else
		subDirFormatArg	=	@"--subdir-format=<nameshort>";
	
	NSString *downloadPathArg	=	[[NSString alloc] initWithFormat:@"--output=%@", downloadPath];
	NSString *versionArg		=	[NSMutableString stringWithString:@"--versions=default"];
	NSString *cacheExpiryArg	=	@"--expiry=604800000000";
	NSString *whitespaceArg		=	@"--whitespace";
	
	NSString *filePrefixArg		=	[NSString stringWithFormat:@"--file-prefix=<nameshort> (%@ - Episode <episode> <episodepart> - <modeshort>)", [show tvNetwork]];
	
	NSString *atomicParsleyArg = [[NSString alloc] initWithFormat:@"--atomicparsley=%@", [executablesPath stringByAppendingPathComponent:@"AtomicParsley"]];
	NSString *ffmpegArg		= [[NSString alloc] initWithFormat:@"--ffmpeg=%@", [executablesPath stringByAppendingPathComponent:@"ffmpeg"]];
	
   //Add Arguments that can't be NULL
	NSMutableArray *args = [[NSMutableArray alloc] initWithObjects:	getiPlayerPath,
																	profileDirArg,
																	logArg,
																	typeArg,
																	noWarningArg,
																	pidArg,
																	attemptsArg,
																	formatArg,
																	noPurgeArg,
																	subDirArg,
																	subDirFormatArg,
																	downloadPathArg,
																	versionArg,
																	cacheExpiryArg,
																	whitespaceArg,
																	filePrefixArg,
																	atomicParsleyArg,
																	ffmpegArg,
																	nil ];
	
	if (verbose)
		[args addObject:@"--verbose"];
	
	task = [[NSTask alloc] init];
	pipe = [[NSPipe alloc] init];
	errorPipe = [[NSPipe alloc] init];
	
	[task setArguments:args];
	[task setLaunchPath:@"/usr/bin/perl"];
	[task setStandardOutput:pipe];
	[task setStandardError:errorPipe];
   
	NSMutableDictionary *envVariableDictionary = [NSMutableDictionary dictionaryWithDictionary:[task environment]];
	envVariableDictionary[@"HOME"] = [@"~" stringByExpandingTildeInPath];
	envVariableDictionary[@"PERL_UNICODE"] = @"AS";
	[task setEnvironment:envVariableDictionary];
	
	fh = [pipe fileHandleForReading];
	errorFh = [errorPipe fileHandleForReading];
	
	[nc addObserver:self
          selector:@selector(DownloadDataReady:)
              name:NSFileHandleReadCompletionNotification
            object:fh];
	[nc addObserver:self
          selector:@selector(ErrorDataReady:)
              name:NSFileHandleReadCompletionNotification
            object:errorFh];
	[task launch];
	[fh readInBackgroundAndNotify];
	[errorFh readInBackgroundAndNotify];
	
	//Prepare UI
	[self setCurrentProgress:@"Beginning..."];
    [show setValue:@"Starting..." forKey:@"status"];
   
	return self;
}
- (id)description
{
	return [NSString stringWithFormat:@"BBC Download (ID=%@)", [show pid]];
}
#pragma mark Task Control
- (void)DownloadDataReady:(NSNotification *)note
{
	[[pipe fileHandleForReading] readInBackgroundAndNotify];
    NSData *d = [[note userInfo] valueForKey:NSFileHandleNotificationDataItem];
	
   if ([d length] > 0)
   {
	   NSString *s = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
	   [self processGetiPlayerOutput:s];
   }
   else
   {
		noDataCount++;
	   
		if (noDataCount>20 && running)
		{
			running=NO;
			task = nil;
			pipe = nil;
			
			if (runDownloads)
			{
				if (!foundLastLine)
				{
					NSLog(@"Setting Last Line Here...");
					NSArray *logComponents =[ log componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
					LastLine = [logComponents lastObject];
					unsigned int offsetFromEnd=1;
					
					while (!LastLine.length)
					{
						LastLine = [logComponents objectAtIndex:(logComponents.count - offsetFromEnd)];
						++offsetFromEnd;
					}
				}
				
				NSLog(@"Last Line: %@", LastLine);
				NSLog(@"Length of Last Line: %lu", (unsigned long)[LastLine length]);
				
				NSScanner *scn = [NSScanner scannerWithString:LastLine];
				
				if ([reasonForFailure isEqualToString:@"unresumable"])
				{
					[show setValue:@YES forKey:@"complete"];
					[show setValue:@NO forKey:@"successful"];
					[show setValue:@"Failed: Unresumable File" forKey:@"status"];
					[show setReasonForFailure:@"Unresumable_File"];
				}
				else if ([reasonForFailure isEqualToString:@"FileExists"])
				{
					show.complete = @YES;
					show.successful = @NO;
					show.status = @"Failed: File Exists";
					show.reasonForFailure = reasonForFailure;
				}
				else if ([reasonForFailure isEqualToString:@"Outside_UK"])
				{
					[show setValue:@YES forKey:@"complete"];
					[show setValue:@NO forKey:@"successful"];
					[show setValue:@"Failed: Outside UK" forKey:@"status"];
					[self addToLog:@"REASON FOR FAILURE: BBC refused access because get-iplayer is being run outside of UK" noTag:YES];
					[self addToLog:[NSString stringWithFormat:@"%@ Failed",[show showName]]];
					[show setReasonForFailure:@"Outside_UK"];
				}
				else if ([reasonForFailure isEqualToString:@"AudioDescribedOnly"])
				{
					[show setValue:@YES forKey:@"complete"];
					[show setValue:@NO forKey:@"successful"];
					[show setValue:@"Failed: Only audio described versions are avalable" forKey:@"status"];
					[self addToLog:@"REASON FOR FAILURE: There are only audio described versions available" noTag:YES];
					[self addToLog:[NSString stringWithFormat:@"%@ Failed",[show showName]]];
					[show setReasonForFailure:@"AudioDescribedOnly"];
				}
				else if ([reasonForFailure isEqualToString:@"modes"])
				{
					[show setValue:@YES forKey:@"complete"];
					[show setValue:@NO forKey:@"successful"];
					[show setValue:@"Failed: No Specified Modes" forKey:@"status"];
					[self addToLog:@"REASON FOR FAILURE: None of the modes in the format list are available for this show." noTag:YES];
					[self addToLog:[NSString stringWithFormat:@"%@ Failed",[show showName]]];
					[show setReasonForFailure:@"Specified_Modes"];
					NSLog(@"Set Modes");
				}
				else if ([[show reasonForFailure] isEqualToString:@"InHistory"])
				{
					NSLog(@"InHistory");
				}
				else if ([LastLine containsString:@"Permission denied"])
				{
					if ([LastLine containsString:@"/Volumes"]) //Most likely disconnected external HDD
					{
						show.complete = @YES;
						show.successful = @NO;
						show.status = @"Failed: HDD not Accessible";
						[self addToLog:@"REASON FOR FAILURE: The specified download directory could not be written to." noTag:YES];
						[self addToLog:@"Most likely this is because your external hard drive is disconnected but it could also be a permission issue"
                           noTag:YES];
						[self addToLog:[NSString stringWithFormat:@"%@ Failed",[show showName]]];
						[show setReasonForFailure:@"External_Disconnected"];
               
					}
					else
					{
						show.complete = @YES;
						show.successful = @NO;
						show.status = @"Failed: Download Directory Unwriteable";
						[self addToLog:@"REASON FOR FAILURE: The specified download directory could not be written to." noTag:YES];
						[self addToLog:@"Please check the permissions on your download directory."
                           noTag:YES];
						[self addToLog:[NSString stringWithFormat:@"%@ Failed",[show showName]]];
						[show setReasonForFailure:@"Download_Directory_Permissions"];
					}
				}
				else if ([LastLine hasPrefix:@"INFO: Recorded"])
				{
					[show setValue:@YES forKey:@"complete"];
					[show setValue:@YES forKey:@"successful"];
					[show setValue:@"Download Complete" forKey:@"status"];
					NSScanner *scanner = [NSScanner scannerWithString:LastLine];
					NSString *path;
					[scanner scanString:@"INFO: Recorded" intoString:nil];
					
					if (![scanner scanFloat:nil])
					{
						[scanner scanUpToString:@"kjkjkjkjk" intoString:&path];
					}
					else
					{
						[scanner scanUpToString:@"to" intoString:nil];
						[scanner scanString:@"to " intoString:nil];
						[scanner scanUpToString:@"kjkfjkj" intoString:&path];
					}
				[show setPath:path];
				[self addToLog:[NSString stringWithFormat:@"%@ Completed Successfully",[show showName]]];
				}
				else if ([LastLine hasPrefix:@"INFO: All streaming threads completed"])
				{
					[show setValue:@YES forKey:@"complete"];
					[show setValue:@YES forKey:@"successful"];
					[show setValue:@"Download Complete" forKey:@"status"];
					[show setPath:@"Unknown"];
				}
				else if ([scn scanUpToString:@"Already in history" intoString:nil] && [scn scanString:@"Already in" intoString:nil])
				{
					[show setValue:@YES forKey:@"complete"];
					[show setValue:@NO forKey:@"successful"];
					[show setValue:@"Failed: Download in History" forKey:@"status"];
					[self addToLog:[NSString stringWithFormat:@"%@ Failed",[show showName]]];
					[show setReasonForFailure:@"InHistory"];
				}
				else
				{
					[show setValue:@YES forKey:@"complete"];
					[show setValue:@NO forKey:@"successful"];
					[show setValue:@"Download Failed" forKey:@"status"];
					[self addToLog:[NSString stringWithFormat:@"%@ Failed",[show showName]]];
				}
			}
			[nc removeObserver:self];
			[nc postNotificationName:@"DownloadFinished" object:show];
		}
	}
}

- (void)ErrorDataReady:(NSNotification *)note
{
	[[errorPipe fileHandleForReading] readInBackgroundAndNotify];
   NSData *d = [[note userInfo] valueForKey:NSFileHandleNotificationDataItem];
   if ([d length] > 0)
	{
		[errorCache appendString:[[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding]];
	}
	else
	{
		noDataCount++;
		if (noDataCount>20)
		{
			//Close the error pipe when it is empty.
			errorPipe = nil;
         [processErrorCache invalidate];
		}
	}
}
- (void)processError
{
	if (running)
	{
		NSString *outp = [errorCache copy];
		errorCache = [NSMutableString stringWithString:@""];
		
		if ([outp length] == 0)
			return;
		
		NSArray *array = [outp componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
			
		for (NSString *message in array)
		{
			NSString *shortStatus=nil;
			NSScanner *scanner = [NSScanner scannerWithString:message];
				
			if ([message length] == 0)
			{
				continue;
			}
			
			if ([scanner scanFloat:nil]) //RTMPDump
			{
				[self processFLVStreamerMessage:message];
				continue;
			}
			
			if ([message hasPrefix:@"frame="])
			{
				shortStatus= @"Converting..."; //FFMpeg
			}
			else if ([message hasPrefix:@" Progress"])
			{
				shortStatus= @"Processing Download..."; //Download Artwork
			}
			else if ([message hasPrefix:@"ERROR:"] || [message hasPrefix:@"\rERROR:"] || [message hasPrefix:@"\nERROR:"]) //Could be unresumable.
			{
				BOOL isUnresumable = NO;
				
				if ([scanner scanUpToString:@"corrupt file!" intoString:nil] && [scanner scanString:@"corrupt file!" intoString:nil])
				{
					isUnresumable = YES;
				}
				if (!isUnresumable)
				{
					[scanner setScanLocation:0];
					if ([scanner scanUpToString:@"Couldn't find the seeked keyframe in this chunk!" intoString:nil] && [scanner scanString:@"Couldn't find the seeked keyframe in this chunk!" intoString:nil])
					{
						isUnresumable = YES;
					}
				}
				if (isUnresumable)
				{
					[self addToLog:@"Unresumable file, please delete the partial file and try again." noTag:NO];
					[task interrupt];
					reasonForFailure=@"unresumable";
					[show setReasonForFailure:@"Unresumable_File"];
				}
			}

			if (shortStatus != nil)
			{
				[self setCurrentProgress:[NSString stringWithFormat:@"%@ -- %@",shortStatus,[show valueForKey:@"showName"]]];
				[self setPercentage:102];
				[show setValue:shortStatus forKey:@"status"];
			}
		}
	}

}
- (void)cancelDownload:(id)sender
{
	//Some basic cleanup.
	[task interrupt];
	[nc removeObserver:self name:NSFileHandleReadCompletionNotification object:fh];
	[nc removeObserver:self name:NSFileHandleReadCompletionNotification object:errorFh];
	[show setValue:@"Cancelled" forKey:@"status"];
	[self addToLog:@"Download Cancelled"];
   [processErrorCache invalidate];
}
- (void)processGetiPlayerOutput:(NSString *)outp
{
	NSArray *array = [outp componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
	//Parse each line individually.
	for (NSString *output in array)
	{
		if ([output hasSuffix:@"already exists"])
		{
			reasonForFailure=@"FileExists";
			[self addToLog:output noTag:YES];
		}
		else if ([output hasSuffix:@"outside the UK."])
		{
			reasonForFailure=@"Outside_UK";
			[self addToLog:output noTag:YES];
		}
		else if ([output hasPrefix:@"INFO: Recorded"])
		{
			LastLine = [NSString stringWithString:output];
			foundLastLine=YES;
		}
		else if ([output hasPrefix:@"INFO: No specified modes"])
		{
			reasonForFailure=@"modes";
			[show setReasonForFailure:@"Specified_Modes"];
			[self addToLog:output noTag:YES];
		}
		else if ([output hasSuffix:@"use --force to override"])
		{
         [show setValue:@YES forKey:@"complete"];
         [show setValue:@NO forKey:@"successful"];
         [show setValue:@"Failed: Download in History" forKey:@"status"];
         [self addToLog:[NSString stringWithFormat:@"%@ Failed",[show showName]]];
         [show setReasonForFailure:@"InHistory"];
         foundLastLine=YES;
		}
		else if ([output hasPrefix:@"ERROR: Failed to get version pid"])
		{
			[show setReasonForFailure:@"ShowNotFound"];
			[self addToLog:output noTag:YES];
		}
		else if ([output hasPrefix:@"WARNING: No programmes are available for this pid with version(s):"] ||
               [output hasPrefix:@"INFO: No versions of this programme were selected"])
		{
			NSScanner *versionScanner = [NSScanner scannerWithString:output];
			[versionScanner scanUpToString:@"available versions:" intoString:nil];
			[versionScanner scanString:@"available versions:" intoString:nil];
			[versionScanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];
			NSString *availableVersions;
			[versionScanner scanUpToString:@")" intoString:&availableVersions];
			
			if ([availableVersions rangeOfString:@"audiodescribed"].location != NSNotFound ||
				[availableVersions rangeOfString:@"signed"].location != NSNotFound         ||
				[availableVersions rangeOfString:@"signed2"].location != NSNotFound)
			{
				[show setReasonForFailure:@"AudioDescribedOnly"];
			}
			
			[self addToLog:output noTag:YES];
		}
		else if ([output hasPrefix:@"INFO: 1 Matching Programmes"])
		{
			[self setCurrentProgress:[NSString stringWithFormat:@"Getting metadata - %@", [show valueForKey:@"showName"]]];
		}
		else if ([output hasPrefix:@"INFO:"] || [output hasPrefix:@"WARNING:"] || [output hasPrefix:@"ERROR:"] ||
				[output hasSuffix:@"default"] || [output hasPrefix:[show pid]])
		{
			//Add Status Message to Log
			[self addToLog:output noTag:YES];
		}
		else if ([output hasPrefix:@" Progress"])
		{
			[self setPercentage:102];
			[self setCurrentProgress:[NSString stringWithFormat:@"Processing Download... - %@", [show valueForKey:@"showName"]]];
			[self setValue:@"Processing Download..." forKey:@"status"];
		}
		else if ([output hasPrefix:@"Recording:"])
		{
			
			NSScanner *scanner = [NSScanner scannerWithString:output];
			NSDecimal recieved, total, percentage, speed, ignored;
			NSString *timeRemaining;
			
			[scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
			
			if(![scanner scanDecimal:&recieved])
				recieved = (@0).decimalValue;
			
			[scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
			
			if(![scanner scanDecimal:&total])
				total = (@0).decimalValue;
			
			[scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
			
			if (verbose) {
				// skip next 8 fields -- elapsed time (H:M:S), expected time (H:M:S), blocks finished/remaining
				for (NSInteger i = 0; i < 8; i++) {
					[scanner scanDecimal:&ignored];
					[scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet]
											intoString:nil];
				}
			}
			
			if(![scanner scanDecimal:&percentage])
				percentage = (@0).decimalValue;
			
			[scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
			
			if(![scanner scanDecimal:&speed])
				speed = (@0).decimalValue;
			
			[scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
			
			if(![scanner scanUpToString:@"rem" intoString:&timeRemaining])
				timeRemaining=@"Unknown";
			
			double adjustedSpeed = [NSDecimalNumber decimalNumberWithDecimal:speed].doubleValue/8;
			
			[self setPercentage:[NSDecimalNumber decimalNumberWithDecimal:percentage].doubleValue];
			
			[self setCurrentProgress:[NSString stringWithFormat:@"%3.1f%% (%3.2fMB/%3.2fMB) - %.1fKB/s - %@ Remaining -- %@",
										[NSDecimalNumber decimalNumberWithDecimal:percentage].doubleValue,
										[NSDecimalNumber decimalNumberWithDecimal:recieved].doubleValue,
										[NSDecimalNumber decimalNumberWithDecimal:total].doubleValue,
										adjustedSpeed,timeRemaining,self.show.showName]];
			
			[self.show setValue:[NSString stringWithFormat:@"Downloading: %3.1f%%",
								 [NSDecimalNumber decimalNumberWithDecimal:percentage].doubleValue]
							 forKey:@"status"];
		}
	}
}

@end
