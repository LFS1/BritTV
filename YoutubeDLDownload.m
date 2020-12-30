//
//  YoutubeDLDownload.m
//  BriTv
//
//  Created by LFS on 1/28/18.
//

#import "YoutubeDLDownload.h"
#import "NSString+HTML.h"

extern  LogController *theLogger;

@implementation YoutubeDLDownload

- (id)initWithProgramme:(ProgrammeData *)tempShow downloadNumber:(int)theDownloadNumber
{
	if (!(self = [super init])) return nil;
	
	verbose = [[NSUserDefaults standardUserDefaults] boolForKey:@"Verbose"];
	
	downloadNumber = theDownloadNumber;
	addFailedDownloadToHistory = false;

	show = tempShow;
	show.downloadFailCount = 0;

	[self logActivity:@"Starting"];
	
	if ( [show.tvNetwork containsString:@"BBC"] )
		[self getBBCEpisodeDetails];
	else
		[self startDownload];
	
	return self;
}

-(void)startDownload
{
	
	show.reasonForFailure = @"";
	show.downloadStatus = Started;
	show.displayInfoIsHidden = YES;
	show.progressIsHidden = NO;
	show.progressDoubleValue = 0.0;
	show.statusIsHidden = NO;
	show.status = @"Starting download: Getting Metadata";
	
	[show makeEpisodeName];
	
	if ( [[NSFileManager defaultManager] fileExistsAtPath:show.mp4Path] )
	{
		[self logActivity:@"Finished: File already exists"];
		show.downloadStatus = FinishedWithError;
		[show setValue:@"File Already Exists" forKey:@"status"];
		[show setReasonForFailure:@"FileExists"];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"DownloadFinished" object:show];
		show.progressIsHidden = YES;
		show.displayInfoIsHidden = NO;
		return;
	}
	
	NSMutableArray *getProgrammeArgs = [[NSMutableArray alloc] initWithObjects:
										@"--no-part",
										@"--format=best",
										[show programmeURL],
										@"--external-downloader-args=-stats -loglevel fatal",
										[NSString stringWithFormat:@"--output=%@.%%(duration)s", show.tempMp4Path],
										nil];
	
	[self startTask:getProgrammeArgs];
}



-(void)getBBCEpisodeDetails
{
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://www.bbc.co.uk/programmes/%@.json", show.productionId]];
	
	NSData *data = [[NSData alloc] initWithContentsOfURL:url];

	NSString *pageContent = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
	pageContent = [pageContent stringByDecodingHTMLEntities];
		
	NSScanner *scanner = [[NSScanner alloc]initWithString:pageContent];
		
	/* Episode Number */
		
	int episodeNumber = 0;
	[scanner scanUpToString:@"\"position\":" intoString:NULL];
	[scanner scanString:@"\"position\":" intoString:NULL];
	[scanner scanInt:&episodeNumber];
		
	if (episodeNumber)
		show.episodeNumber = episodeNumber;
		
	/* title */
		
	NSString *episodeTitle = @"";
	[scanner scanUpToString:@"title\":\"" intoString:NULL];
	[scanner scanString:@"title\":\"" intoString:NULL];
	[scanner scanUpToString:@"\"" intoString:&episodeTitle];
		
	if (episodeTitle.length) {
		episodeTitle = [episodeTitle stringByReplacingOccurrencesOfString:@"\\"  withString:@""];
		[show analyseTitle:episodeTitle];
	}
		
	// Broadcast date: 2018-03-08T19:30:00Z */
		
	NSString *dateAiredString = @"";
	[scanner scanUpToString:@"\"first_broadcast_date\":\"" intoString:NULL];
	[scanner scanString:@"\"first_broadcast_date\":\"" intoString:NULL];
	[scanner scanUpToString:@"\"" intoString:&dateAiredString];
	
	if ([dateAiredString containsString:@"+"]) {
		NSArray *a = [dateAiredString componentsSeparatedByString:@"+"];
		dateAiredString = [a firstObject];
	}
	dateAiredString = [dateAiredString stringByReplacingOccurrencesOfString:@"Z" withString:@""];
		
	if ( dateAiredString.length)  {
		NSDate *date;
		NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
		[dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss"];
		date = [dateFormatter dateFromString:dateAiredString];
			
		if (date) {
			show.dateAired = date;
			show.dateWithTime = true;
		}
	}
	
	[show makeEpisodeName];
	[self startDownload];
	
	return;
}

- (void)processTaskData:(NSString *)output
{
	if ( [output containsString:@"[download] Destination:"] )
	{
		show.programDuration = 0;
		NSScanner *s = [[NSScanner alloc]initWithString:output];
		
		NSString *path;
		[s scanUpToString:@"[download] Destination:" intoString:NULL];
		[s scanString:@"[download] Destination:" intoString:NULL];
		[s scanUpToString:@"@@@@" intoString:&path];
		show.tempMp4Path = [path stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		
		NSInteger duration;
		s = [NSScanner scannerWithString:show.tempMp4Path];
		[s scanUpToString:@".mp4." intoString:NULL];
		[s scanString:@".mp4." intoString:NULL];
		[s scanInteger:&duration];
		show.programDuration = duration / 60;
		
		if ( !show.programDuration ) {
			[show setValue:@"Failed: No duration" forKey:@"status"];
			[self logActivity:@"Could not find duration of programme"];
			[show setReasonForFailure:@"No_Duration"];
			[youTubeTask interrupt];
		}

	}
	else if ( [output containsString:@"[download]"] && [output containsString:@"ETA"])
	{
		// [download]  98.7% of ~111.41MiB at  1.18MiB/s ETA 00:01
		
		NSScanner *scanner = [[NSScanner alloc]initWithString:output];
		
		[scanner scanUpToString:@"[download]" intoString:NULL];
		[scanner scanString:@"[download]" intoString:NULL];
		
		double progress;
		
		[scanner scanDouble:&progress];
		
		if ( progress && progress > show.progressDoubleValue  )
		{
			show.progressDoubleValue = progress;
			[show setValue:[NSString stringWithFormat:@"Downloading: %3.1f%%", progress] forKey:@"status"];
		}
	}
	else if ( [output containsString:@"[download] 100%"] && [output containsString:@"of"] )
	{
		show.progressDoubleValue = 100.00;
		[show setValue:@"Download Complete" forKey:@"status"];
	}
	else if ( [output containsString:@"frame"] && [output containsString:@"time="] )
	{
		NSScanner *scanner = [[NSScanner alloc]initWithString:output];
		[scanner scanUpToString:@"time=" intoString:NULL];
		[scanner scanString:@"time=" intoString:NULL];
		int hh = 0;
		int mm = 0;
		int ss = 0;
		[scanner scanInt:&hh];
		[scanner scanString:@":" intoString:NULL];
		[scanner scanInt:&mm];
		[scanner scanString:@":" intoString:NULL];
		[scanner scanInt:&ss];
		
		if (hh < 4 && mm < 60  & ss < 60)
		{
			double currentSecs = (hh * 60 * 60) + (mm * 60) + ss;
			
			if (currentSecs)
			{
				double progress = currentSecs / (double)(show.programDuration / 100.0);
				
				if (progress > 100)
					progress = 100.0;

				[show setValue:[NSString stringWithFormat:@"Downloading: %3.1f%%",progress] forKey:@"status"];
				show.progressDoubleValue = progress;
			}
		}
	}
}


- (void)processErrorData:(NSString *)data
{
	if ( !data.length )
		return;
	
	/* Progress reports come through the error port for hls files */
	
	if ( [data containsString:@"frame"] && [data containsString:@"time="] )
	{
		[self processTaskData:data];
	}
	else if ( [data containsString:@"geolocation"]  ||  [data containsString:@"ERROR: No video formats found"]  )
	{
		[show setValue:@"Failed: Outside UK" forKey:@"status"];
		[self logActivity:@"Refused outside of ok"];
		[show setReasonForFailure:@"Outside_UK"];
	}
	else if ( [data containsString:@"Downloading legacy playlist XML"]  )
	{
		[show setValue:@"Failed: Signed Recording Only" forKey:@"status"];
		[self logActivity:@"Failed: Programme was only available as a signed recording"];
		[show setReasonForFailure:@"Signed_Only"];
		addFailedDownloadToHistory = true;
	}
}




-(void)getProgrammeTaskFinished:(NSNotification *)finishedNote
{
	[theLogger addToLog:[NSString stringWithFormat:@"Download task terminated: %@  - Status is (%d)", show.programmeName, [finishedNote.object terminationStatus]]];
	
	if ( [finishedNote.object terminationStatus] == 0)
	{
		NSError *error;
		
		[[NSFileManager defaultManager] moveItemAtPath:show.tempMp4Path toPath:show.mp4Path error:&error];
			
		if (error)
			[theLogger addToLog:[NSString stringWithFormat:@"%@", [NSString stringWithFormat:@"Cant rename file %@ error %@",show.tempMp4Path, error]]];

		show.downloadStatus = FinishedOK;
		show.status = @"Complete";
			
		NSDictionary *info = @{@"Programme": show};
		[[NSNotificationCenter defaultCenter] postNotificationName:@"AddProgToHistory" object:self userInfo:info];
		[self logActivity:@"FinishedL Download OK"];
	}
	else
	{
		
		// issue n retries before final fail
		
		if ( ([show.tvNetwork containsString:@"BBC"] && (show.downloadFailCount < [[[NSUserDefaults standardUserDefaults] objectForKey:@"numberBBCRetries"] intValue])) ||
			 ([show.tvNetwork containsString:@"ITV"] && (show.downloadFailCount < [[[NSUserDefaults standardUserDefaults] objectForKey:@"numberITVRetries"] intValue]))    )
		{
			show.downloadFailCount++;
			[theLogger addToLog:[NSString stringWithFormat:@"INFO: download of %@ failed - attempting retry # %d", show.shortEpisodeName, show.downloadFailCount]];
			[self startDownload];
			return;
		}
		
		show.downloadStatus = FinishedWithError;
		[self logActivity:@"Finshed: with bad exit code"];
		[theLogger addToLog:[NSString stringWithFormat:@"Programme %@ task terminated with Exit Code (%d)", show.programmeName, [finishedNote.object terminationStatus]]];
		
		if ( [show.reasonForFailure isEqualToString:@"" ] )
		{
			[show setValue:@"Failed" forKey:@"status"];
			[show setValue:@"Download Failed: Unexpected error (see log)" forKey:@"reasonForFailure"];
		}
		
		if ( addFailedDownloadToHistory )  {
			NSDictionary *info = @{@"Programme": show};
			[[NSNotificationCenter defaultCenter] postNotificationName:@"AddProgToHistory" object:self userInfo:info];
		}

	}

	show.progressIsHidden = YES;
	show.displayInfoIsHidden = NO;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"DownloadFinished" object:show];
}

-(void)startTask:(NSMutableArray *)args
{
	[self logActivity:@"Task Starting"];

	youTubeTask    = [[NSTask alloc] init];
	youTubeTask.standardOutput = [[NSPipe alloc]init];
	youTubeTask.standardError = [[NSPipe alloc]init];
	youTubeStdFh = [youTubeTask.standardOutput fileHandleForReading];
	youTubeErrFh = [youTubeTask.standardError fileHandleForReading];
	
	[youTubeTask setLaunchPath:[[[NSBundle mainBundle].executablePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"youtube-dl"]];

	if ( verbose )
		[args addObject:@"-v"];
	
	[youTubeTask setArguments:args];

	NSMutableDictionary *envVariableDictionary = [NSMutableDictionary dictionaryWithDictionary:[youTubeTask environment]];
	envVariableDictionary[@"HOME"] = [@"~" stringByExpandingTildeInPath];
	envVariableDictionary[@"PATH"] = [NSString stringWithFormat:@"%@:%@",[[NSBundle mainBundle].executablePath stringByDeletingLastPathComponent],[[[NSProcessInfo processInfo] environment] objectForKey:@"PATH"]];
	
	[youTubeTask setEnvironment:envVariableDictionary];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataReady:) name:NSFileHandleReadCompletionNotification object:youTubeStdFh];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataReady:) name:NSFileHandleReadCompletionNotification object:youTubeErrFh];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(taskFinished:) name:NSTaskDidTerminateNotification object:youTubeTask];
	
	NSError *error;
	
	[youTubeTask launchAndReturnError:&error];
	
	if ( error )
		NSLog(@"Launch Task Error %@", error);
	
	[youTubeStdFh readInBackgroundAndNotify];
	[youTubeErrFh readInBackgroundAndNotify];
	
	return;
}

- (void) taskFinished:(NSNotification *)finishedNote
{	
	[self logActivity:[NSString stringWithFormat:@"Task finished error code was (%d)", [finishedNote.object terminationStatus]]];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadCompletionNotification object:youTubeStdFh];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadCompletionNotification object:youTubeErrFh];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	if ( show.downloadStatus == Cancelled )
		[[NSNotificationCenter defaultCenter] postNotificationName:@"DownloadFinished" object:show];
	else
        [self getProgrammeTaskFinished:finishedNote];
}

- (void)dataReady:(NSNotification *)note
{
	NSData *d = [[note userInfo] valueForKey:NSFileHandleNotificationDataItem];
	NSString *s = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
	
	if ( s.length )
	{
		[note.object readInBackgroundAndNotify];
		
		NSArray *array = [s componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

		for (NSString *outputLine in array)
		{
			if ([outputLine length]) {
				if ( verbose )
					[theLogger addToLog:outputLine];
				
				if ( note.object == youTubeStdFh )
					[self processTaskData:outputLine];
				else
					[self processErrorData:outputLine];
			}
		}
	}
}

- (void)cancelDownload:(id)sender
{
	if ( [youTubeTask isRunning] )
	{
		[self logActivity:@"Cancelling"];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadCompletionNotification object:youTubeStdFh];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadCompletionNotification object:youTubeErrFh];
		[[NSNotificationCenter defaultCenter] removeObserver:self];
		show.downloadStatus = Cancelled;
		show.status = @"Download Cancelled by user";
		show.progressIsHidden = YES;
		show.displayInfoIsHidden = NO;
		[youTubeTask interrupt];
	}
}


- (void)addToLog:(NSString *)logMessage noTag:(BOOL)b
{
	if (b)
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"AddToLog" object:nil userInfo:@{@"message": logMessage}];
	}
	else
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"AddToLog" object:self userInfo:@{@"message": logMessage}];
	}
}

- (void)addToLog:(NSString *)logMessage
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"AddToLog" object:self userInfo:@{@"message": logMessage}];
}

-(void)logActivity:(NSString *)activity
{
	if ( verbose )
	{
		NSString *gap = [@"." stringByPaddingToLength:downloadNumber -1 withString:@"." startingAtIndex:0];
		NSString *entry = [NSString stringWithFormat:@"%@T%d-%@ (%@)", gap, downloadNumber, activity, show.programmeName];
		NSLog(@"%@", entry);
	}
}

@end


