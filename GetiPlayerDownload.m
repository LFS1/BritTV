//
//  GetiPlayerDownload.m
//  BriTv
//
//  Created by LFS on 9/12/19.
//

#import "GetiPlayerDownload.h"
#import "NSString+HTML.h"

extern  LogController *theLogger;

@implementation GetiPlayerDownload

- (id)initWithProgramme:(ProgrammeData *)tempShow downloadNumber:(int)theDownloadNumber
{
    if (!(self = [super init])) return nil;
    
    verbose = [[NSUserDefaults standardUserDefaults] boolForKey:@"Verbose"];
    
    downloadNumber = theDownloadNumber;
    addFailedDownloadToHistory = false;
    
    show = tempShow;
    
    show.reasonForFailure = @"";
    [self logActivity:@"Starting (get_iPlayer download)"];
    
    show.downloadStatus = Started;
    show.displayInfoIsHidden = YES;
    show.progressIsHidden = NO;
    show.progressDoubleValue = 0.0;
    show.statusIsHidden = NO;
    show.status = @"Starting download: Getting Metadata";
    
    [self getBBCEpisodeDetails];
    [self startDownload];
    
    return self;
}
-(void)startDownload
{
    [show makeEpisodeName];

    NSString *executablesPath = [[[NSBundle mainBundle] executablePath]stringByDeletingLastPathComponent];
    NSString *profileDir = [NSString stringWithFormat:@"~/Library/Application Support/BriTv/Thread-%02d/", downloadNumber];
    
    NSMutableArray *getProgrammeArgs = [[NSMutableArray alloc] initWithObjects:
                    [[NSBundle mainBundle] pathForResource:@"get_iplayer" ofType:@"pl"],
                    [NSString stringWithFormat:@"--profile-dir=%@",[profileDir stringByExpandingTildeInPath]],
                    [NSString stringWithFormat:@"--pid=%@", show.productionId],
                    [NSString stringWithFormat:@"--output=%@", show.downloadPath],
                    [NSString stringWithFormat:@"--fileprefix=%@",[show.mp4FileName stringByReplacingOccurrencesOfString:@".mp4" withString:@""]],
                    [NSString stringWithFormat:@"--ffmpeg=%@", [executablesPath stringByAppendingPathComponent:@"ffmpeg"]],
                    [NSString stringWithFormat:@"--atomicparsley=%@", [executablesPath stringByAppendingPathComponent:@"AtomicParsley"]],
                    @"--nocopyright",
                    @"--nopurge",
                    @"--logprogress",
                    @"--expiry=604800000000",
                    @"--attempts=1",
                    @"--force",
                    @"--overwrite",
                    @"--modes=best",
                    @"--whitespace",
                    nil];

    if ( verbose )
        [getProgrammeArgs addObject:@"-v"];
    
    NSMutableDictionary *envVariableDictionary = [NSMutableDictionary dictionaryWithDictionary:getiPlayerTask.environment];
    NSString *perlPath = [[NSBundle mainBundle] resourcePath];
    perlPath = [perlPath stringByAppendingPathComponent:@"perl5"];
    NSString *cacertPath = [perlPath stringByAppendingPathComponent:@"Mozilla/CA/cacert.pem"];
        
    envVariableDictionary[@"HOME"] = (@"~").stringByExpandingTildeInPath;
    envVariableDictionary[@"PERL_UNICODE"] = @"AS";
    envVariableDictionary[@"PERL5LIB"] = perlPath;
    envVariableDictionary[@"SSL_CERT_DIR"] = perlPath;
    envVariableDictionary[@"MOJO_CA_FILE"] = cacertPath;
    envVariableDictionary[@"PATH"] = [NSString stringWithFormat:@"%@:%@",[[NSBundle mainBundle].executablePath stringByDeletingLastPathComponent],[[[NSProcessInfo processInfo] environment] objectForKey:@"PATH"]];
        
    getiPlayerTask    = [[NSTask alloc] init];
    getiPlayerTask.standardOutput = [[NSPipe alloc]init];
    getiPlayerTask.standardError = [[NSPipe alloc]init];
    getiPlayerStdFh = [getiPlayerTask.standardOutput fileHandleForReading];
    getiPlayerErrFh = [getiPlayerTask.standardError fileHandleForReading];
        
    getiPlayerTask.launchPath  =@"/usr/bin/perl";
    getiPlayerTask.environment = envVariableDictionary;
    getiPlayerTask.arguments = getProgrammeArgs;
        
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataReady:) name:NSFileHandleReadCompletionNotification object:getiPlayerStdFh];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataReady:) name:NSFileHandleReadCompletionNotification object:getiPlayerErrFh];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(taskFinished:) name:NSTaskDidTerminateNotification object:getiPlayerTask];
        
    NSError *error;
        
    [getiPlayerTask launchAndReturnError:&error];
        
    if ( error )
        NSLog(@"Launch Task Error %@", error);
        
    [getiPlayerStdFh readInBackgroundAndNotify];
    [getiPlayerErrFh readInBackgroundAndNotify];

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
    
    return;
}

- (void)processTaskData:(NSString *)output
{
    if (!output.length)
        return;
    
    if ( [output containsString:@"ETA"] )
    {
        /* 63.2% of ~75.07 MB @   7.9 Mb/s ETA: 00:00:27 (hvfhd1/ll) [audio+video] */
        
        NSScanner *scanner = [[NSScanner alloc]initWithString:output];
        
        double progress;
        
        [scanner scanDouble:&progress];
        
        show.progressDoubleValue = progress;
        [show setValue:[NSString stringWithFormat:@"Downloading: %3.1f%%", progress] forKey:@"status"];

    }
    else if ( [output containsString:@"INFO: Tagging MP4"]  )
    {
        show.progressDoubleValue = 100.00;
        [show setValue:@"Download Complete" forKey:@"status"];
    }
    else if ( [output containsString:@"frame"] && [output containsString:@"time="] )
    {

    }
    else if ( [output containsString:@"it may have been blocked"]   )
    {
        [show setValue:@"Failed: Outside UK" forKey:@"status"];
        [self logActivity:@"Refused outside of uk"];
        [show setReasonForFailure:@"Outside_UK"];
    }
    
}

-(void)getProgrammeTaskFinished:(NSNotification *)finishedNote
{
    [theLogger addToLog:[NSString stringWithFormat:@"Download task terminated: %@  - Status is (%d)", show.programmeName, [finishedNote.object terminationStatus]]];
    
    if ( [finishedNote.object terminationStatus] == 0)
    {
        show.downloadStatus = FinishedOK;
        show.status = @"Complete";
        
        NSDictionary *info = @{@"Programme": show};
        [[NSNotificationCenter defaultCenter] postNotificationName:@"AddProgToHistory" object:self userInfo:info];
        [self logActivity:@"FinishedL Download OK"];
    }
    else
    {
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



- (void) taskFinished:(NSNotification *)finishedNote
{
    [self logActivity:[NSString stringWithFormat:@"Task finished error code was (%d)", [finishedNote.object terminationStatus]]];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadCompletionNotification object:getiPlayerStdFh];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadCompletionNotification object:getiPlayerErrFh];
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
                
                [self processTaskData:outputLine];
            }
        }
    }
}

- (void)cancelDownload:(id)sender
{
    if ( [getiPlayerTask isRunning] )
    {
        [self logActivity:@"Cancelling"];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadCompletionNotification object:getiPlayerStdFh];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadCompletionNotification object:getiPlayerErrFh];
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        show.downloadStatus = Cancelled;
        show.status = @"Download Cancelled by user";
        show.progressIsHidden = YES;
        show.displayInfoIsHidden = NO;
        [getiPlayerTask interrupt];
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
