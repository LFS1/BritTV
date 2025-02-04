//
//  ITVDownload.m
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 12/16/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ITVDownload.h"
#import "ASIHTTPRequest.h"
#import "NSString+HTML.h"
#import "ITVMediaFileEntry.h"

@implementation ITVDownload

- (id)init
{
   if (!(self = [super init])) return nil;
   
   return self;
}
- (id)description
{
	return [NSString stringWithFormat:@"ITV Download (ID=%@)", [show pid]];
}

- (id)initWithProgramme:(Programme *)tempShow logController:(LogController *)aLogger
{
	if (!(self = [super initWithLogController:aLogger]))
		return nil;
	
   show = tempShow;
   attemptNumber=1;
   nc = [NSNotificationCenter defaultCenter];
   defaultsPrefix = @"ITV_";
   
   running=TRUE;
   
   [self setCurrentProgress:[NSString stringWithFormat:@"Retrieving Programme Metadata... -- %@",[show showName]]];
   [self setPercentage:102];
   [tempShow setValue:@"Initialising..." forKey:@"status"];

	
   [self addToLog:[NSString stringWithFormat:@"Downloading %@",[show showName]]];
   [self addToLog:@"INFO: Preparing Request for Auth Info" noTag:YES];
   
   [self launchMetaRequest];
   return self;
}

- (void)launchMetaRequest
{
   errorCache = [[NSMutableString alloc] initWithString:@""];
   processErrorCache = [NSTimer scheduledTimerWithTimeInterval:.25 target:self selector:@selector(processError) userInfo:nil repeats:YES];
   
   NSString *soapBody = nil;
   if ([show url] && [[show url] rangeOfString:@"Filter=" options:NSCaseInsensitiveSearch].location == NSNotFound) {
      [show setRealPID:[show pid]];
      soapBody = @"Body2";
      downloadParams[@"UseCurrentWebPage"] = @YES;
   }
   else
   {
      NSString *pid = nil;
      NSScanner *scanner = [NSScanner scannerWithString:[show url]];
      [scanner scanUpToString:@"Filter=" intoString:nil];
      [scanner scanString:@"Filter=" intoString:nil];
      [scanner scanUpToString:@"kljkjj" intoString:&pid];
      if (!pid)
      {
         NSLog(@"ERROR: GiA cannot interpret the ITV URL: %@", [show url]);
         [self addToLog:[NSString stringWithFormat:@"ERROR: GiA cannot interpret the ITV URL: %@", [show url]]];
         [show setReasonForFailure:@"MetadataProcessing"];
         [show setComplete:@YES];
         [show setSuccessful:@NO];
         [show setValue:@"Download Failed" forKey:@"status"];
         [nc postNotificationName:@"DownloadFinished" object:show];
         return;
      }
      [show setRealPID:pid];
      soapBody = @"Body";
   }
   NSString *body;

	body = [[NSString alloc] initWithData:[NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:soapBody ofType:nil]]
                                   encoding:NSUTF8StringEncoding];
   
   body = [body stringByReplacingOccurrencesOfString:@"!!!ID!!!" withString:[show realPID]];
   
   NSURL *requestURL = [NSURL URLWithString:@"http://mercury.itv.com/PlaylistService.svc"];
	
   if (verbose)
      [self addToLog:[NSString stringWithFormat:@"DEBUG: Metadata URL: %@", requestURL] noTag:YES];
	
   [currentRequest clearDelegatesAndCancel];
   currentRequest = [ASIHTTPRequest requestWithURL:requestURL];
   [currentRequest addRequestHeader:@"Referer" value:@"http://www.itv.com/mercury/Mercury_VideoPlayer.swf?v=1.5.309/[[DYNAMIC]]/2"];
   [currentRequest addRequestHeader:@"Content-Type" value:@"text/xml; charset=utf-8"];
   [currentRequest addRequestHeader:@"SOAPAction" value:@"\"http://tempuri.org/PlaylistService/GetPlaylist\""];
   [currentRequest setRequestMethod:@"POST"];
   [currentRequest setPostBody:[NSMutableData dataWithData:[body dataUsingEncoding:NSUTF8StringEncoding]]];
   [currentRequest setDelegate:self];
   [currentRequest setDidFailSelector:@selector(metaRequestFinished:)];
   [currentRequest setDidFinishSelector:@selector(metaRequestFinished:)];
   [currentRequest setTimeOutSeconds:10];
   [currentRequest setNumberOfTimesToRetryOnTimeout:3];
   [currentRequest addRequestHeader:@"Accept" value:@"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"];

   [self addToLog:@"INFO: Requesting Metadata." noTag:YES];
   [currentRequest startAsynchronous];
}

-(void)metaRequestFinished:(ASIHTTPRequest *)request
{
   if (!running)
      return;

	NSString *responseString = [[NSString alloc] initWithData:[request responseData] encoding:NSUTF8StringEncoding];
	
   if (verbose) {
       [self addToLog:[NSString stringWithFormat:@"DEBUG: Metadata response status code: %d", [request responseStatusCode]] noTag:YES];
	   NSLog(@"DEBUG: Metadata response: %@",responseString);
	   [self addToLog:[NSString stringWithFormat:@"DEBUG: Metadata response: %@", responseString] noTag:YES];
   }
	
   NSError *error = [request error];
	
   if ([request responseStatusCode] == 0)
   {
      NSLog(@"ERROR: No response received : %@", (error ? [error localizedDescription] : @"Unknown error"));
      [self addToLog:[NSString stringWithFormat:@"ERROR: No response received: %@", (error ? [error localizedDescription] : @"Unknown error")]];
      [show setSuccessful:@NO];
      [show setComplete:@YES];
	  [show setReasonForFailure:@"Internet_Connection"];
      [show setValue:@"Failed: Internet Connection" forKey:@"status"];
      [nc postNotificationName:@"DownloadFinished" object:show];
      [self addToLog:@"Download Failed" noTag:NO];
      return;
   }
   else if ([responseString length] > 0 &&
			([responseString rangeOfString:@"503 Service Unavailable" options:NSCaseInsensitiveSearch].location != NSNotFound  ||
			 [responseString rangeOfString:@"502 Bad Gateway" options:NSCaseInsensitiveSearch].location != NSNotFound ))
   {
      NSLog(@"ERROR: ITV Service Unavailable");
      [self addToLog:@"ERROR: ITV Service Unavailable (503)."];
      [show setSuccessful:@NO];
      [show setComplete:@YES];
      [show setReasonForFailure:@"Service_Unavailable"];
      [show setValue:@"ITV Service Unavailable" forKey:@"status"];
      [nc postNotificationName:@"DownloadFinished" object:show];
      [self addToLog:@"Download Failed" noTag:NO];
      return;
   }
   else if ([responseString length] > 0 && [responseString rangeOfString:@"" options:NSCaseInsensitiveSearch].location != NSNotFound)
   {
	   NSLog(@"ERROR: Access denied to users outside UK.");
	   [self addToLog:@"ERROR: Access denied to users outside UK."];
	   [show setSuccessful:@NO];
	   [show setComplete:@YES];
	   [show setReasonForFailure:@"Outside_UK"];
	   [show setValue:@"Failed: Outside UK" forKey:@"status"];
	   [nc postNotificationName:@"DownloadFinished" object:show];
	   [self addToLog:@"Download Failed" noTag:NO];
	   return;
   }
	
   else if ([request responseStatusCode] != 200 || [responseString length] == 0)
   {
      NSLog(@"ERROR: Could not retrieve programme metadata: %@", (error ? [error localizedDescription] : @"Unknown error"));
      [self addToLog:[NSString stringWithFormat:@"ERROR: Could not retrieve programme metadata: %@", (error ? [error localizedDescription] : @"Unknown error")]];
      [show setSuccessful:@NO];
      [show setComplete:@YES];
      [show setValue:@"Download Failed" forKey:@"status"];
      [nc postNotificationName:@"DownloadFinished" object:show];
      [self addToLog:@"Download Failed" noTag:NO];
      return;
   }
   
   responseString = [responseString stringByDecodingHTMLEntities];
   NSScanner *scanner = [NSScanner scannerWithString:responseString];
   
   if (downloadParams[@"UseCurrentWebPage"])
   {
      //Reset to numeric PID if originated from current web page
      NSString *pid = nil;
      [scanner scanUpToString:@"<Vodcrid>crid://itv.com/" intoString:nil];
      [scanner scanString:@"<Vodcrid>crid://itv.com/" intoString:nil];
      [scanner scanUpToString:@"</Vodcrid>" intoString:&pid];
      [show setRealPID:pid];
   }
   
   //Retrieve Series Name
/*
   NSString *seriesName = nil;
   [scanner scanUpToString:@"<ProgrammeTitle>" intoString:nil];
   [scanner scanString:@"<ProgrammeTitle>" intoString:nil];
   [scanner scanUpToString:@"</ProgrammeTitle>" intoString:&seriesName];
   [show setSeriesName:seriesName];
*/
   //Init date formatter
   NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
   [dateFormat setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
   
   //Retrieve Transmission Date
   NSString *dateString = nil;
   [scanner scanUpToString:@"<TransmissionDate>" intoString:nil];
   [scanner scanString:@"<TransmissionDate>" intoString:nil];
   [scanner scanUpToString:@"</TransmissionDate>" intoString:&dateString];
   [dateFormat setDateFormat:@"dd LLLL yyyy"];
   [show setDateAired:[dateFormat dateFromString:dateString]];
   
   //Retrieve Episode Name
/*
   NSString *episodeName = nil;
   [scanner scanUpToString:@"<EpisodeTitle" intoString:nil];
   if (![scanner scanString:@"<EpisodeTitle/>" intoString:nil])
   {
      [scanner scanString:@"<EpisodeTitle>" intoString:nil];
      [scanner scanUpToString:@"</EpisodeTitle>" intoString:&episodeName];
	   
	  [dateFormat setDateFormat:@"dd/MM/yyyy"];
	  NSDate *episodeDate = [dateFormat dateFromString:episodeName];
	  
	  if ( episodeDate )
	  {
		  [dateFormat setDateFormat:@"E dd/MM/yyyy"];
		  episodeName =  [dateFormat stringFromDate:episodeDate];
	  }

      [show setEpisodeName:episodeName];
   }
*/
	
   //Retrieve Episode Number

   NSInteger episodeNumber = [show episode];
   [scanner scanUpToString:@"<EpisodeNumber" intoString:nil];
   if (![scanner scanString:@"<EpisodeNumber/>" intoString:nil])
   {
      [scanner scanString:@"<EpisodeNumber>" intoString:nil];
      [scanner scanInteger:&episodeNumber];
   }
   [show setEpisode:episodeNumber];

   //Retrieve Auth URL
   NSString *authURL = nil;
   [scanner scanUpToString:@"rtmpe://" intoString:nil];
   [scanner scanUpToString:@"\"" intoString:&authURL];

/*
   NSLog(@"DEBUG: Metadata processed: seriesName=%@ dateString=%@ episodeName=%@ episodeNumber=%ld  authURL=%@",
         seriesName, dateString, episodeName, episodeNumber, authURL);
	
	if (verbose) {
		[self addToLog:[NSString stringWithFormat:@"DEBUG: Metadata processed: seriesName=%@ dateString=%@ episodeName=%@ episodeNumber=%ld authURL=%@",seriesName, dateString, episodeName, episodeNumber, authURL] noTag:YES];
		
		NSLog(@"DEBUG: Metadata processed: seriesName=%@ dateString=%@ episodeName=%@ episodeNumber=%ld authURL=%@", seriesName, dateString, episodeName, episodeNumber, authURL);
	
		NSLog(@"DEBUG: Retrieving Playpath");

		[self addToLog:@"DEBUG: Retrieving Playpath" noTag:YES];
	}
*/
	 NSString *playPath = nil;

	 NSArray *itvRateArray =  @[@"1800",       @"1500",              @"1200",         @"800",              @"600",         @"400"];
	 NSArray *bitRateArray =  @[@"1800000",    @"1500000",           @"1200000",      @"800000",           @"600000",      @"400000"];
	
   if (verbose)
      [self addToLog:@"DEBUG: Parsing MediaFile entries" noTag:YES];
	
	NSMutableArray *mediaEntries = [[NSMutableArray alloc] init];
	NSUInteger beforeMediaFiles = [scanner scanLocation];
	
	while ([scanner scanUpToString:@"MediaFile delivery" intoString:nil])
	{
      NSString *url = nil, *bitrate = nil, *itvRate = nil;
      ITVMediaFileEntry *entry = [[ITVMediaFileEntry alloc] init];
      [scanner scanUpToString:@"bitrate=" intoString:nil];
      [scanner scanString:@"bitrate=\"" intoString:nil];
      [scanner scanUpToString:@"\"" intoString:&bitrate];
      [scanner scanUpToString:@"CDATA" intoString:nil];
      [scanner scanString:@"CDATA[" intoString:nil];
      NSUInteger location = [scanner scanLocation];
      [scanner scanUpToString:@"]]" intoString:&url];
      [scanner setScanLocation:location];
      [scanner scanUpToString:@"_PC01" intoString:nil];
      [scanner scanString:@"_PC01" intoString:nil];
      [scanner scanUpToString:@"_" intoString:&itvRate];
		
      if (scanner.atEnd)
	  {
         [scanner setScanLocation:location];
         [scanner scanUpToString:@"_itv" intoString:nil];
         [scanner scanString:@"_itv" intoString:nil];
         [scanner scanUpToString:@"_" intoString:&itvRate];
      }
      
      [entry setBitrate:bitrate];
      [entry setUrl:url];
      [entry setItvRate:itvRate];
      [mediaEntries addObject:entry];

      if (verbose)
         [self addToLog:[NSString stringWithFormat:@"DEBUG: ITVMediaFileEntry: bitrate=%@ itvRate=%@ url=%@", bitrate, itvRate, url] noTag:YES];
   }

   if (verbose)
      [self addToLog:@"DEBUG: Searching for itvRate match" noTag:YES];
	
   BOOL foundIt=FALSE;
   for (NSString *rate in itvRateArray) {
      for (ITVMediaFileEntry *entry in mediaEntries) {
         if ([[entry itvRate] isEqualToString:rate]) {
            foundIt=TRUE;
            playPath=[entry url];

            if (verbose)
               [self addToLog:[NSString stringWithFormat:@"DEBUG: foundIt (itvRate): rate=%@ url=%@", rate, playPath] noTag:YES];
            break;
         }
      }
      if (foundIt) break;
   }
   if (!foundIt)
   {
      if (verbose)
         [self addToLog:@"DEBUG: Searching for bitrate match" noTag:YES];
	   
      for (NSString *rate in bitRateArray) {
         for (ITVMediaFileEntry *entry in mediaEntries) {
            if ([[entry bitrate] isEqualToString:rate]) {
               foundIt=TRUE;
               playPath=[entry url];

               if (verbose)
                  [self addToLog:[NSString stringWithFormat:@"DEBUG: foundIt (bitrate): rate=%@ url=%@", rate, playPath] noTag:YES];
               break;
            }
         }
         if (foundIt) break;
      }
   }
   
   if (!foundIt) {
      NSLog(@"ERROR: None of the modes in your download format list are available for this show. Try adding more modes if possible.");
      [self addToLog:@"ERROR: None of the modes in your download format list are available for this show. Try adding more modes if possible."];
      show.reasonForFailure = @"NoSpecifiedFormatAvailableITV";
      [show setComplete:@YES];
      [show setSuccessful:@NO];
      [show setValue:@"Download Failed" forKey:@"status"];
      [nc postNotificationName:@"DownloadFinished" object:show];
      return;
   }
   else {
      if (verbose)
         [self addToLog:[NSString stringWithFormat:@"DEBUG: playPath = %@", playPath] noTag:YES];
   }
   
   NSInteger seriesNumber = [show season];
   for (ITVMediaFileEntry *entry in mediaEntries) {
      NSScanner *mescanner = [NSScanner scannerWithString:[entry url]];
      [mescanner scanUpToString:@"(series-" intoString:nil];
      [mescanner scanString:@"(series-" intoString:nil];
      if ([mescanner scanInteger:&seriesNumber])
         break;
   }
   [show setSeason:seriesNumber];
   if (verbose)
      [self addToLog:[NSString stringWithFormat:@"DEBUG: seriesNumber=%ld", seriesNumber] noTag:YES];
   
   [scanner setScanLocation:beforeMediaFiles];
   [scanner scanUpToString:@"proggenre=films" intoString:nil];
   if ([scanner scanString:@"proggenre=films" intoString:nil]) {
      isFilm = YES;
   }
   if (verbose)
      [self addToLog:[NSString stringWithFormat:@"DEBUG: isFilm = %d", isFilm] noTag:YES];
   
   downloadParams[@"authURL"] = authURL;
   downloadParams[@"playPath"] = playPath;
   
   [self addToLog:@"INFO: Metadata processed." noTag:YES];
   NSURL *dataURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://www.itv.com/_app/Dynamic/CatchUpData.ashx?ViewType=5&Filter=%@",[show realPID]]];

   if (verbose)
      [self addToLog:[NSString stringWithFormat:@"DEBUG: Programme data URL: %@", dataURL] noTag:YES];
	
   [currentRequest clearDelegatesAndCancel];
   currentRequest = [ASIHTTPRequest requestWithURL:dataURL];
   [currentRequest setDidFailSelector:@selector(dataRequestFinished:)];
   [currentRequest setDidFinishSelector:@selector(dataRequestFinished:)];
   [currentRequest setTimeOutSeconds:10];
   [currentRequest setNumberOfTimesToRetryOnTimeout:3];
   [currentRequest setDelegate:self];
   [currentRequest addRequestHeader:@"Accept" value:@"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"];

   [self addToLog:@"INFO: Requesting programme data." noTag:YES];
   [currentRequest startAsynchronous];
}

-(void)dataRequestFinished:(ASIHTTPRequest *)request
{
   if (!running)
      return;
	
   NSScanner *scanner = nil;

   if (verbose)
      [self addToLog:[NSString stringWithFormat:@"DEBUG: Programme data response status code: %d", [request responseStatusCode]] noTag:YES];
	
   NSString *responseString = [[NSString alloc] initWithData:[request responseData] encoding:NSUTF8StringEncoding];

   if (verbose)
      [self addToLog:[NSString stringWithFormat:@"DEBUG: Programme data response: %@", responseString] noTag:YES];
	
   NSError *error = [request error];
   NSString *description = nil, *showname = nil, *senum = nil, *epnum = nil, *epname = nil, *temp_showname = nil;
	
   if ([request responseStatusCode] == 200 && [responseString length] > 0)
   {
      scanner = [NSScanner scannerWithString:responseString];
      [scanner scanUpToString:@"<h2>" intoString:nil];
      [scanner scanString:@"<h2>" intoString:nil];
      [scanner scanUpToString:@"</h2>" intoString:&temp_showname];
      [scanner scanUpToString:@"<p>" intoString:nil];
      [scanner scanString:@"<p>" intoString:nil];
      [scanner scanUpToString:@"</p>" intoString:&description];
      temp_showname = [temp_showname stringByConvertingHTMLToPlainText];
      description = [description stringByConvertingHTMLToPlainText];
   }
   else
   {
      NSLog(@"WARNING: Programme data request failed. Tagging will be incomplete.");
      [self addToLog:[NSString stringWithFormat:@"WARNING: Programme data request failed. Tagging will be incomplete."] noTag:YES];
      NSLog(@"DEBUG: Programme data response error: %@", (error ? [error localizedDescription] : @"Unknown error"));
      if (verbose)
         [self addToLog:[NSString stringWithFormat:@"DEBUG: Programme data response error: %@", (error ? [error localizedDescription] : @"Unknown error")] noTag:YES];
      
   }
   //Fix Showname
   if (!temp_showname)
      temp_showname = [show seriesName];
   showname = temp_showname;
   if ([show season])
      senum = [NSString stringWithFormat:@"Series %ld", [show season]];
   if ([show episode])
      epnum = [NSString stringWithFormat:@"Episode %ld", [show episode]];
   epname = [show episodeName];
   if (!epname || [epname isEqualToString:@"(No Episode Name)"])
   {
      //Air date as backup
      NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
      [dateFormat setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
      [dateFormat setDateFormat:@"dd/MM/yyyy"];
      epname = [dateFormat stringFromDate:[show dateAired]];
   }
   if (senum) {
      if (epnum) {
         showname = [NSString stringWithFormat:@"%@ - %@ %@", showname, senum, epnum];
      }
      else {
         showname = [NSString stringWithFormat:@"%@ - %@", showname, senum];
      }
   }
   else if (epnum) {
      showname = [NSString stringWithFormat:@"%@ - %@", showname, epnum];
   }
   if (epname && ![epname isEqualToString:temp_showname] && ![epname isEqualToString:epnum]) {
      showname = [NSString stringWithFormat:@"%@ - %@", showname, epname];
   }
   [show setShowName:showname];

   if (verbose)
      [self addToLog:[NSString stringWithFormat:@"DEBUG: Programme data processed: showname=%@ temp_showname=%@ senum=%@ epnum=%@ epname=%@ description=%@",
                      showname, temp_showname, senum, epnum, epname, description] noTag:YES];
	
   [self addToLog:@"INFO: Program data processed." noTag:YES];
   
   //Create Download Path
   [self createDownloadPath];
   
   NSString *swfplayer = [[NSUserDefaults standardUserDefaults] valueForKey:[NSString stringWithFormat:@"%@SWFURL", defaultsPrefix]];
   if (!swfplayer) {
      swfplayer = @"http://www.itv.com/mediaplayer/ITVMediaPlayer.swf?v=11.20.654";
   }
   
   NSMutableArray *args = [NSMutableArray arrayWithObjects:
                           @"-r",downloadParams[@"authURL"],
                           @"-W",swfplayer,
                           @"-y",downloadParams[@"playPath"],
                           @"-o",downloadPath,
                           nil];
	
   if (verbose) {
		[args addObject:@"--verbose"];
		[self addToLog:[NSString stringWithFormat:@"DEBUG: RTMPDump args: %@", args] noTag:YES];
   }
	
   [self launchRTMPDumpWithArgs:args];
}
@end
