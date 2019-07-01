//
//  Download.m
//  
//
//  Created by Thomas Willson on 12/16/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "Download.h"

@implementation Download
- (id)init
{
    if (!(self = [super init])) return nil;
    
    //Prepare Time Remaining
	rateEntries = [[NSMutableArray alloc] initWithCapacity:50];
	lastDownloaded=0;
	outOfRange=0;
    verbose = [[NSUserDefaults standardUserDefaults] boolForKey:@"Verbose"];
    downloadParams = [[NSMutableDictionary alloc] init];
    
    return self;
}
- (id)initWithLogController:(LogController *)aLogger {
    if ([self init]) {
        self->logger = aLogger;
        return self;
    }
    return nil;
}

@synthesize show;
#pragma mark Notification Posters
- (void)addToLog:(NSString *)logMessage noTag:(BOOL)b
{
	if (b)
	{
		[nc postNotificationName:@"AddToLog" object:nil userInfo:@{@"message": logMessage}];
	}
	else
	{
		[nc postNotificationName:@"AddToLog" object:self userInfo:@{@"message": logMessage}];
	}
    [log appendFormat:@"%@\n", logMessage];
}
- (void)addToLog:(NSString *)logMessage
{
	[nc postNotificationName:@"AddToLog" object:self userInfo:@{@"message": logMessage}];
    [log appendFormat:@"%@\n", logMessage];
}
- (void)setCurrentProgress:(NSString *)string
{
	[nc postNotificationName:@"setCurrentProgress" object:self userInfo:@{@"string": string}];
}
- (void)setPercentage:(double)d
{
	if (d<=100.0)
	{
		NSNumber *value = @(d);
		[nc postNotificationName:@"setPercentage" object:self userInfo:@{@"nsDouble": value}];
	}
	else
	{
		[nc postNotificationName:@"setPercentage" object:self userInfo:nil];
	}
}
- (void)requestFailed:(ASIHTTPRequest *)request
{
    [request startAsynchronous];
}
#pragma mark Message Processers
- (void)processFLVStreamerMessage:(NSString *)message
{    
    NSScanner *scanner = [NSScanner scannerWithString:message];
    [scanner setScanLocation:0];
    [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
    double downloaded, elapsed, percent, total;
    if ([scanner scanDouble:&downloaded])
    {
        [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
        if (![scanner scanDouble:&elapsed]) elapsed=0.0;
        [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
        if (![scanner scanDouble:&percent]) percent=102.0;
        if (downloaded>0 && percent>0 && percent!=102) total = ((downloaded/1024)/(percent/100));
        else total=0;
        if (percent != 102) {
            [show setValue:[NSString stringWithFormat:@"Downloading: %.1f%%", percent] forKey:@"status"];
        }
        else {
            [show setValue:@"Downloading..." forKey:@"status"];
        }
        [self setPercentage:percent];
        
        //Calculate Time Remaining
        downloaded/=1024;
        if (total>0 && downloaded>0 && percent>0)
        {
            if ([rateEntries count] >= 50)
            {
                double rateSum, rateAverage;
                double rate = ((downloaded-lastDownloaded)/(-[lastDate timeIntervalSinceNow]));
                double oldestRate = [rateEntries[0] doubleValue];
                if (rate < (oldRateAverage*5) && rate > (oldRateAverage/5) && rate < 50)
                {
                    [rateEntries removeObjectAtIndex:0];
                    [rateEntries addObject:@(rate)];
                    outOfRange=0;
                    rateSum= (oldRateAverage*50)-oldestRate+rate;
                    rateAverage = oldRateAverage = rateSum/50;
                }
                else 
                {
                    outOfRange++;
                    rateAverage = oldRateAverage;
                    if (outOfRange>10)
                    {
                        rateEntries = [[NSMutableArray alloc] initWithCapacity:50];
                        outOfRange=0;
                    }
                }
                
                lastDownloaded=downloaded;
                lastDate = [NSDate date];
                NSDate *predictedFinished = [NSDate dateWithTimeIntervalSinceNow:(total-downloaded)/rateAverage];
                
                unsigned int unitFlags = NSHourCalendarUnit | NSMinuteCalendarUnit;
                NSDateComponents *conversionInfo = [[NSCalendar currentCalendar] components:unitFlags fromDate:lastDate toDate:predictedFinished options:0];
                
                [self setCurrentProgress:[NSString stringWithFormat:@"%.1f%% - (%.2f MB/~%.0f MB) - %02ld:%02ld Remaining -- %@",percent,downloaded,total,(long)[conversionInfo hour],(long)[conversionInfo minute],[show valueForKey:@"showName"]]];
            }
            else 
            {
                if (lastDownloaded>0 && lastDate)
                {
                    double rate = ((downloaded-lastDownloaded)/(-[lastDate timeIntervalSinceNow]));
                    if (rate<50)
                    {
                        [rateEntries addObject:@(rate)];
                    }
                    lastDownloaded=downloaded;
                    lastDate = [NSDate date];
                    if ([rateEntries count]>48)
                    {
                        double rateSum=0;
                        for (NSNumber *entry in rateEntries)
                        {
                            rateSum+=[entry doubleValue];
                        }
                        oldRateAverage = rateSum/[rateEntries count];
                    }
                }
                else 
                {
                    lastDownloaded=downloaded;
                    lastDate = [NSDate date];
                }
                if (percent != 102)
                    [self setCurrentProgress:[NSString stringWithFormat:@"%.1f%% - (%.2f MB/~%.0f MB) -- %@",percent,downloaded,total,[show valueForKey:@"showName"]]];
                else
                    [self setCurrentProgress:[NSString stringWithFormat:@"%.2f MB Downloaded -- %@",downloaded/1024,[show showName]]];
            }
        }
        else
        {
            [self setCurrentProgress:[NSString stringWithFormat:@"%.2f MB Downloaded -- %@",downloaded,[show showName]]];
        }
    }
}
- (void)rtmpdumpFinished:(NSNotification *)finishedNote
{
    [self addToLog:@"RTMPDUMP finished"];
    [nc removeObserver:self name:NSFileHandleReadCompletionNotification object:fh];
	[nc removeObserver:self name:NSFileHandleReadCompletionNotification object:errorFh];
    [processErrorCache invalidate];
    
    NSInteger exitCode=[[finishedNote object] terminationStatus];
    NSLog(@"Exit Code = %ld",(long)exitCode);
    if (exitCode==0) //RTMPDump is successful
    {
        [show setComplete:@YES];
        [show setSuccessful:@YES];
        NSDictionary *info = @{@"Programme": show};
        [[NSNotificationCenter defaultCenter] postNotificationName:@"AddProgToHistory" object:self userInfo:info];
        
        ffTask = [[NSTask alloc] init];
        ffPipe = [[NSPipe alloc] init];
        ffErrorPipe = [[NSPipe alloc] init];
        
        [ffTask setStandardOutput:ffPipe];
        [ffTask setStandardError:ffErrorPipe];
        
        ffFh = [ffPipe fileHandleForReading];
        ffErrorFh = [ffErrorPipe fileHandleForReading];
        
        NSString *completeDownloadPath = [[downloadPath stringByDeletingPathExtension] stringByDeletingPathExtension];
        completeDownloadPath = [completeDownloadPath stringByAppendingPathExtension:@"mp4"];
        [show setPath:completeDownloadPath];
        
        [ffTask setLaunchPath:[[[NSBundle mainBundle].executablePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"ffmpeg"]];
        
        [ffTask setArguments:@[@"-i",[NSString stringWithFormat:@"%@",downloadPath],
                              @"-vcodec",@"copy",
                              @"-acodec",@"copy",
                              [NSString stringWithFormat:@"%@",completeDownloadPath]]];
        
        [nc addObserver:self
               selector:@selector(DownloadDataReady:)
                   name:NSFileHandleReadCompletionNotification
                 object:ffFh];
        [nc addObserver:self 
               selector:@selector(DownloadDataReady:) 
                   name:NSFileHandleReadCompletionNotification 
                 object:ffErrorFh];
        [nc addObserver:self 
               selector:@selector(ffmpegFinished:) 
                   name:NSTaskDidTerminateNotification 
                 object:ffTask];
        
        [ffTask launch];
        [ffFh readInBackgroundAndNotify];
        [ffErrorFh readInBackgroundAndNotify];
        
        [self setCurrentProgress:[NSString stringWithFormat:@"Converting... -- %@",[show showName]]];
        [show setStatus:@"Converting..."];
        [self addToLog:@"INFO: Converting FLV File to MP4" noTag:YES];
        [self setPercentage:102];
    }
    else if (exitCode==1 && running) //RTMPDump could not resume
    {
        if ([[[task arguments] lastObject] isEqualTo:@"--resume"])
        {
            [[NSFileManager defaultManager] removeItemAtPath:downloadPath error:nil];
            [self addToLog:@"WARNING: Download couldn't be resumed. Overwriting partial file." noTag:YES];
            [self addToLog:@"INFO: Preparing Request for Auth Info" noTag:YES];
            [self launchMetaRequest];
            return;
        }
        else if (attemptNumber < 4) //some other reason, so retry
        {
            attemptNumber++;
            [self addToLog:[NSString stringWithFormat:@"WARNING: Trying download again. Attempt %ld/4",(long)attemptNumber] noTag:YES];
            [self launchMetaRequest];
        }
        else // give up
        {
            [show setSuccessful:@NO];
            [show setComplete:@YES];
            [show setReasonForFailure:@"Unknown"];
            [nc removeObserver:self];
            [nc postNotificationName:@"DownloadFinished" object:show];
            [show setValue:@"Download Failed" forKey:@"status"];
        }
    }
    else if (exitCode==2 && attemptNumber<4 && running) //RTMPDump lost connection but should be able to resume.
    {
        attemptNumber++;
        [self addToLog:[NSString stringWithFormat:@"WARNING: Trying download again. Attempt %ld/4",(long)attemptNumber] noTag:YES];
        [self launchMetaRequest];
    }
    else //Some undocumented exit code or too many attempts
    {
        [show setSuccessful:@NO];
        [show setComplete:@YES];
        [show setReasonForFailure:@"Unknown"];
        [nc removeObserver:self];
        [nc postNotificationName:@"DownloadFinished" object:show];
        [show setValue:@"Download Failed" forKey:@"status"];
    }
    [processErrorCache invalidate];
}
- (void)ffmpegFinished:(NSNotification *)finishedNote
{
    NSLog(@"Conversion Finished");
    [self addToLog:@"INFO: Finished Converting." noTag:YES];
    
    if ([[finishedNote object] terminationStatus] == 0)
    {
        [[NSFileManager defaultManager] removeItemAtPath:downloadPath error:nil];
    }
    else
    {
        [self addToLog:[NSString stringWithFormat:@"INFO: Exit Code = %ld",(long)[[finishedNote object]terminationStatus]] noTag:YES];
        [show setPath:downloadPath];
    }
    
    [show setValue:@"Download Complete" forKey:@"status"];
    [nc removeObserver:self];
    [nc postNotificationName:@"DownloadFinished" object:show];
}

- (void)DownloadDataReady:(NSNotification *)note
{
	[[pipe fileHandleForReading] readInBackgroundAndNotify];
	NSData *d;
    d = [[note userInfo] valueForKey:NSFileHandleNotificationDataItem];
	
    if ([d length] > 0) {
		NSString *s = [[NSString alloc] initWithData:d
											encoding:NSUTF8StringEncoding];
		[self processGetiPlayerOutput:s];
	}
}
- (void)ErrorDataReady:(NSNotification *)note
{
	[[errorPipe fileHandleForReading] readInBackgroundAndNotify];
	NSData *d;
    d = [[note userInfo] valueForKey:NSFileHandleNotificationDataItem];
    if ([d length] > 0)
	{
		[errorCache appendString:[[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding]];
	}
}
- (void)processGetiPlayerOutput:(NSString *)output
{
	NSArray *array = [output componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
	for (NSString *outputLine in array)
	{
        if (![outputLine hasPrefix:@"frame="])
            [self addToLog:outputLine noTag:YES];
    }
}
- (void)processError
{
	//Separate the output by line.
	NSString *string = [[NSString alloc] initWithString:errorCache];
    errorCache = [NSMutableString stringWithString:@""];
	NSArray *array = [string componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
	//Parse each line individually.
	for (NSString *output in array)
	{
        NSScanner *scanner = [NSScanner scannerWithString:output];
        if ([scanner scanFloat:nil])
        {
            [self processFLVStreamerMessage:output];
        }
        else
            if([output length] > 1) [self addToLog:output noTag:YES];
    }
}
-(void)launchRTMPDumpWithArgs:(NSArray *)args
{
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:[[[downloadPath stringByDeletingPathExtension] stringByDeletingPathExtension] stringByAppendingPathExtension:@"mp4"]])
    {
        [self addToLog:@"ERROR: Destination file already exists." noTag:YES];
        [show setComplete:@YES];
        [show setSuccessful:@NO];
        [show setValue:@"Download Failed" forKey:@"status"];
        [show setReasonForFailure:@"FileExists"];
        [nc removeObserver:self];
        [nc postNotificationName:@"DownloadFinished" object:show];
        return;
    }
    else if ([[NSFileManager defaultManager] fileExistsAtPath:downloadPath])
    {
        [self addToLog:@"WARNING: Partial file already exists...attempting to resume" noTag:YES];
        args = [args arrayByAddingObject:@"--resume"];
    }

    NSMutableString *cmd = [NSMutableString stringWithCapacity:0];
    [cmd appendString:[NSString stringWithFormat:@"\"%@\"", [[[NSBundle mainBundle].executablePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"rtmpdump"]]];
    for (NSString *arg in args) {
        if ([arg hasPrefix:@"-"] || [arg hasPrefix:@"\""])
            [cmd appendString:[NSString stringWithFormat:@" %@", arg]];
        else
            [cmd appendString:[NSString stringWithFormat:@" \"%@\"", arg]];
    }
    NSLog(@"DEBUG: RTMPDump command: %@", cmd);
    if (verbose)
        [self addToLog:[NSString stringWithFormat:@"DEBUG: RTMPDump command: %@", cmd] noTag:YES];
    
    task = [[NSTask alloc] init];
    pipe = [[NSPipe alloc] init];
    errorPipe = [[NSPipe alloc] init];
    [task setLaunchPath:[[[NSBundle mainBundle].executablePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"rtmpdump"]];
    
    /* rtmpdump -r "rtmpe://cp72511.edgefcs.net/ondemand?auth=eaEc.b4aodIcdbraJczd.aKchaza9cbdTc0cyaUc2aoblaLc3dsdkd5d9cBduczdLdn-bo64cN-eS-6ys1GDrlysDp&aifp=v002&slist=production/" -W http://www.itv.com/mediaplayer/ITVMediaPlayer.swf?v=11.20.654 -y "mp4:production/priority/CATCHUP/e48ab1e2/1a73/4620/adea/dda6f21f45ee/1-6178-0002-001_THE-ROYAL-VARIETY-PERFORMANCE-2011_TX141211_ITV1200_16X9.mp4" -o test2 */
    
    [task setArguments:[NSArray arrayWithArray:args]];
    
    
    [task setStandardOutput:pipe];
    [task setStandardError:errorPipe];
    fh = [pipe fileHandleForReading];
	errorFh = [errorPipe fileHandleForReading];
    
    NSMutableDictionary *envVariableDictionary = [NSMutableDictionary dictionaryWithDictionary:[task environment]];
    envVariableDictionary[@"HOME"] = [@"~" stringByExpandingTildeInPath];
    [task setEnvironment:envVariableDictionary];
    
	
	[nc addObserver:self
		   selector:@selector(DownloadDataReady:)
			   name:NSFileHandleReadCompletionNotification
			 object:fh];
	[nc addObserver:self
		   selector:@selector(ErrorDataReady:)
			   name:NSFileHandleReadCompletionNotification
			 object:errorFh];
    [nc addObserver:self
           selector:@selector(rtmpdumpFinished:)
               name:NSTaskDidTerminateNotification
             object:task];
    
    [self addToLog:@"INFO: Launching RTMPDUMP..." noTag:YES];
	[task launch];
	[fh readInBackgroundAndNotify];
	[errorFh readInBackgroundAndNotify];
	[show setValue:@"Initialising..." forKey:@"status"];
	
	//Prepare UI
	[self setCurrentProgress:[NSString stringWithFormat:@"Initialising RTMPDump... -- %@",[show showName]]];
    [self setPercentage:102];
}
- (void)launchMetaRequest
{
    [[NSException exceptionWithName:@"InvalidDownload" reason:@"Launch Meta Request shouldn't be called on base class." userInfo:nil] raise];
}
- (void)createDownloadPath
{
    
    NSString *fileName = [NSString stringWithFormat:@"%@ (%@", [show seriesName], [show tvNetwork]];
    
    if ( [show episode] )
          fileName = [NSString stringWithFormat:@"%@ - Episode %ld", fileName, [show episode]];
    
    if ( [[show episodeName]length] )
            fileName = [NSString stringWithFormat:@"%@ - %@", fileName, [show episodeName]];
    
    fileName = [NSString stringWithFormat:@"%@)", fileName];
    
    //Create Download Path
    NSString *dirName = [show seriesName];
    
    if (!dirName)
        dirName = [show showName];
    
    if ( [show season] )
        dirName = [NSString stringWithFormat:@"%@ (Series %ld)", dirName, [show season]];
    
    downloadPath = [[NSUserDefaults standardUserDefaults] valueForKey:@"DownloadPath"];
    downloadPath = [downloadPath stringByAppendingPathComponent:[[dirName stringByReplacingOccurrencesOfString:@"/" withString:@"-"] stringByReplacingOccurrencesOfString:@":" withString:@" -"]];
    [[NSFileManager defaultManager] createDirectoryAtPath:downloadPath withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *filepart = [[[NSString stringWithFormat:@"%@.partial.flv",fileName] stringByReplacingOccurrencesOfString:@"/" withString:@"-"] stringByReplacingOccurrencesOfString:@":" withString:@" -"];

    downloadPath = [downloadPath stringByAppendingPathComponent:filepart];
}
- (void)cancelDownload:(id)sender
{
    [currentRequest clearDelegatesAndCancel];
	//Some basic cleanup.
	[task interrupt];
	[nc removeObserver:self name:NSFileHandleReadCompletionNotification object:fh];
	[nc removeObserver:self name:NSFileHandleReadCompletionNotification object:errorFh];
	[show setValue:@"Cancelled" forKey:@"status"];
    [show setComplete:@NO];
    [show setSuccessful:@NO];
	[self addToLog:@"Download Cancelled"];
    [processErrorCache invalidate];
    running=FALSE;
}

- (void)dealloc
{
    [nc removeObserver:self];
}
@end
