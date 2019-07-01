//
//  GetITVListings.m
//  ITVLoader
//
//  Created by LFS on 6/25/16.
//

#import <Foundation/Foundation.h>
#import "GetITVListings.h"
#import "ReasonForFailure.h"

extern  LogController *theLogger;

@implementation GetITVShows

- (id)init
{
    if (!(self = [super init])) return nil;
    
    nc = [NSNotificationCenter defaultCenter];
    forceUpdateAllProgrammes = false;
    getITVShowRunning = false;

    return self;
}


-(void)forceITVUpdate
{
    
    [theLogger addToLog:@"GetITVShows: Force all programmes update "];
    
    forceUpdateAllProgrammes = true;
    [self itvUpdate];

}

-(void)itvUpdate
{
    /* cant run if we are already running */
    
    if ( getITVShowRunning == true )
        return;
    
    getITVShowRunning = true;
    myQueueSize = 0;
    myQueueLeft = 0;
    htmlData = nil;
	pagesRead = 0;
	pagesNotRead = 0;
    processingError = false;
    mergeUnderway = false;
    
    /* Create the NUSRLSession */
    
    NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
    mySession = [NSURLSession sessionWithConfiguration:defaultConfigObject delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    
    /* Load in carried forward programmes & programme History*/
    
    filesPath = @"~/Library/Application Support/BriTv/";
    filesPath= [filesPath stringByExpandingTildeInPath];

    programmesFilePath = [filesPath stringByAppendingString:@"/itvprogrammes.gia"];
    
    if ( !forceUpdateAllProgrammes )
        boughtForwardProgrammeArray = [NSKeyedUnarchiver unarchiveObjectWithFile:programmesFilePath];

    if ( boughtForwardProgrammeArray == nil || forceUpdateAllProgrammes ) {
		ProgrammeData *emptyProgramme = [[ProgrammeData alloc]initWithName:@"program to be deleted" andChannel:@"ITV" andPID:@"PID" andURL:@"URL" andNUMBEREPISODES:0 ];
        boughtForwardProgrammeArray = [[NSMutableArray alloc]init];
        [boughtForwardProgrammeArray addObject:emptyProgramme];
    }
    
    /* Create empty carriedForwardProgrammeArray & history array */
    
    carriedForwardProgrammeArray = [[NSMutableArray alloc]init];

    /* Load in todays shows for itv.com */
    
    self.myOpQueue = [[NSOperationQueue alloc] init];
    [self.myOpQueue setMaxConcurrentOperationCount:1];
    [self.myOpQueue addOperation:[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(requestTodayListing) object:nil]];
    
    return;
}



- (id)requestTodayListing
{
	pagesRead++;
	
    NSURL *url = [NSURL URLWithString:@"https://www.itv.com/hub/shows"] ;
    
    [[mySession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        if ( error )  {
            NSString *reason = [NSString stringWithFormat:@"Unable to load ITV shows page. Error code %@", error];
            [self reportProcessingError:[NSString stringWithFormat:@"%@",url] andWithREASON:reason];
            [self endOfRun];
        }

        htmlData = [[NSString alloc]initWithData:data encoding:NSASCIIStringEncoding];
            
        if ( ![self createTodayProgrammeArray] )
            [self endOfRun];
        else
            [self mergeAllProgrammes];
        
    } ] resume];

    return self;

}


- (void)requestProgrammeEpisodes:(ProgrammeData *)myProgramme
{
    /* Get all episodes for the programme name identified in MyProgramme */
    
    usleep(1);
	
	pagesRead++;
    myQueueLeft++;

    [[mySession dataTaskWithURL:[NSURL URLWithString:myProgramme.programmeURL] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)   {
        
        myQueueLeft--;
          
        if ( error )  {
            NSString *reason = @"Could not get episodes from URL";
            [self reportProcessingError:myProgramme.programmeURL andWithREASON:reason];
              
            if ( myQueueLeft == 0 && !mergeUnderway  )
                [self processCarriedForwardProgrammes];
              
            return;
        }
        
        NSString *myHtmlData = [[NSString alloc]initWithData:data encoding:NSASCIIStringEncoding];
        [self processProgrammeEpisodesData:myProgramme : myHtmlData];
          
    } ] resume];

    return;
    
}

-(void)processProgrammeEpisodesData:(ProgrammeData *)aProgramme :(NSString *)myHtmlData
{
	/* Some single episode shows will point to the play page from the shows page - check here and if so use a different routine to process from that page
	 */
	
	if ( [myHtmlData containsString:@"data-video-production-id"] )	{
		[self processSingleEpisodesData:aProgramme :myHtmlData];
		return;
	}
	
    /*  Scan through episode page and create carried forward programme entries for each eipsode of aProgramme */

    NSScanner *scanner = [NSScanner scannerWithString:myHtmlData];
    NSScanner *fullProgrammeScanner;
    NSString *fullProgramme = nil;
    NSUInteger scanPoint   = 0;
    int numberEpisodesFound = 0;
    NSString *temp = nil;

	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
    
    /* Get first episode  */

	[scanner scanUpToString:@"data-episode-id=\"" intoString:NULL];
    [scanner scanUpToString:@"</li>" intoString:&fullProgramme];

    while ( ![scanner isAtEnd] ) {
        
        fullProgrammeScanner = [NSScanner scannerWithString:fullProgramme];
		
        /* URL & Prodiction ID */
        
        NSString *programmeURL;
        
        [fullProgrammeScanner scanUpToString:@"<a href=\"" intoString:&temp];
        [fullProgrammeScanner scanString:@"<a href=\"" intoString:&temp];
		[fullProgrammeScanner scanUpToString:@"\"" intoString:&programmeURL];
        
        if ( !programmeURL )  {
            NSString *reason = [NSString stringWithFormat:@"Could not get episode URL for programme %@ - Ignoring", aProgramme.programmeName];
            [self reportProcessingError:aProgramme.programmeURL andWithREASON:reason];
            
            [scanner scanUpToString:@"data-episode-id=\"" intoString:NULL];
            [scanner scanUpToString:@"</li>" intoString:&fullProgramme];
            
            continue;
        }
		
        NSString *productionId;
        
		productionId = [[programmeURL componentsSeparatedByString:@"/"]lastObject];
        
        if ( !productionId )  {
            NSString *reason = [NSString stringWithFormat:@"Could not get production id for programme %@ URL %@- Ignoring", aProgramme.programmeName, programmeURL];
            [self reportProcessingError:aProgramme.programmeURL andWithREASON:reason];
            
            [scanner scanUpToString:@"data-episode-id=\"" intoString:NULL];
            [scanner scanUpToString:@"</li>" intoString:&fullProgramme];
            
            continue;
        }
        
		
		/* Check that this is the correct programme as sometimes other programmes are included on the page */
		
        if ( [self programmeNameInURLIsEqual:programmeURL :aProgramme.programmeURL] == false ) {
            [scanner scanUpToString:@"data-episode-id=\"" intoString:NULL];
            [scanner scanUpToString:@"</li>" intoString:&fullProgramme];
            
            continue;
        }
	
		/* Episode Title  */
		
		NSString *title = @"";
		
		[fullProgrammeScanner scanUpToString:@"<h3 class=\"tout__title complex-link__target theme__target \">" intoString:NULL];
		[fullProgrammeScanner scanString:@"<h3 class=\"tout__title complex-link__target theme__target \">" intoString:NULL];
		[fullProgrammeScanner scanUpToString:@"<"  intoString:&title];
			
		if ( title.length > 0 ) {
			title = [title stringByTrimmingCharactersInSet:[NSCharacterSet punctuationCharacterSet]];
			title = [title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		}
		
		/* Create ProgrammeData Object & update */
		
		ProgrammeData *myProgramme = [[ProgrammeData alloc]initWithName:aProgramme.programmeName andChannel:@"ITV" andPID:productionId andURL:programmeURL andNUMBEREPISODES:aProgramme.numberEpisodes];
		
		if (numberEpisodesFound == 0)
			[myProgramme makeNew];
		
        /* get date aired  */
		
        fullProgrammeScanner.scanLocation = scanPoint;
        [fullProgrammeScanner scanUpToString:@"datetime=\"" intoString:&temp];
		
		temp = @"";
		
        if ( ![fullProgrammeScanner isAtEnd])  {
            [fullProgrammeScanner scanString:@"datetime=\"" intoString:&temp];
            [fullProgrammeScanner scanUpToString:@"\"" intoString:&temp];
			temp = [temp stringByReplacingOccurrencesOfString:@"Z" withString:@"EST"];
			[dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mmzzz"];
			myProgramme.dateAired = [dateFormatter dateFromString:temp];
			myProgramme.dateWithTime = true;
        }

		[myProgramme analyseTitle:title];
		[myProgramme makeEpisodeName];

		if ( [myProgramme isValid] ) {
			numberEpisodesFound++;
			[carriedForwardProgrammeArray addObject:myProgramme];
		}
		
        /* Scan for next programme */
		
		[scanner scanUpToString:@"data-episode-id=\"" intoString:NULL];
		[scanner scanUpToString:@"</li>" intoString:&fullProgramme];
    }
    
    /* Quick sanity check - did we find the number of episodes that we expected */
    
    if ( numberEpisodesFound != aProgramme.numberEpisodes)  {
        
        /* if not - mark first entry as requireing a full update on next run - hopefully this will repair the issue */
        
        if ( numberEpisodesFound > 0 )
			[[carriedForwardProgrammeArray objectAtIndex:[carriedForwardProgrammeArray count]-numberEpisodesFound] setForceCacheUpdate:true];
        
        
        NSString *reason = [NSString stringWithFormat:@"GetITVListings (Warning): Processing Error - episodes expected/found %d/%d", aProgramme.numberEpisodes, numberEpisodesFound];
        
        [self reportProcessingError:aProgramme.programmeURL andWithREASON:reason];

    }
    
    /* Check if there is any outstanding work before processing the carried forward programme list */
    
    [[[AppController sharedController] itvProgressIndicator]incrementBy:myQueueSize -1 ? 100.0f/(float)(myQueueSize -1.0f) : 100.0f];

    if ( !myQueueLeft && !mergeUnderway )
        [self processCarriedForwardProgrammes];
}

-(BOOL)programmeNameInURLIsEqual:(NSString *)urlOne :(NSString *)urlTwo
{
	NSArray *urlComponents1 = [urlOne componentsSeparatedByString:@"/"];
	NSArray *urlComponents2 = [urlTwo componentsSeparatedByString:@"/"];
	
	if (urlComponents1.count > 2 && urlComponents2.count > 2 ) {
		NSString *programmeName1 = [urlComponents1 objectAtIndex:urlComponents1.count -2];
		NSString *programmeName2 = [urlComponents2 objectAtIndex:urlComponents2.count -2];
	
		if ( [programmeName1 caseInsensitiveCompare:programmeName2] == NSOrderedSame )
			return true;
	}
	
	return false;
}

-(void)processSingleEpisodesData:(ProgrammeData *)aProgramme :(NSString *)myHtmlData
{
	NSScanner *scanner = [NSScanner scannerWithString:myHtmlData];
    
    NSString *programmeURL;
    
	[scanner scanUpToString:@"<link rel=\"canonical\" href=\""  intoString:NULL];
	[scanner scanString:@"<link rel=\"canonical\" href=\""  intoString:NULL];
	[scanner scanUpToString:@"\"" intoString:&programmeURL];
	
	/* Check we have the right programme */
	
	if ( [self programmeNameInURLIsEqual:programmeURL :aProgramme.programmeURL] == false )  {
        NSString *reason = [NSString stringWithFormat:@"Single episode programme names do not match %@/%@ - ignoring", aProgramme.programmeName, programmeURL];
        [self reportProcessingError:aProgramme.programmeURL andWithREASON:reason];
        
        if ( !myQueueLeft && !mergeUnderway  )
            [self processCarriedForwardProgrammes];
        
        return;
	}
	
    NSString *productionId;
    
    productionId  = [[programmeURL componentsSeparatedByString:@"/"] lastObject];
    
    if ( !productionId )  {
        NSString *reason = [NSString stringWithFormat:@"Single episode programme %@ cannot find production id - ignoring", aProgramme.programmeName];
        [self reportProcessingError:aProgramme.programmeURL andWithREASON:reason];
        
        if ( !myQueueLeft && !mergeUnderway  )
            [self processCarriedForwardProgrammes];
        
        return;
    }
	
    NSString *dateTimeAiredString = nil;
    
    [scanner scanUpToString:@"data-video-broadcast-date-time=\"" intoString:NULL];
    [scanner scanString:@"data-video-broadcast-date-time=\"" intoString:NULL];
    [scanner scanUpToString:@"\"" intoString:&dateTimeAiredString];
	
    /* Create ProgrammeData Object & update */

    [theLogger addToLog:[NSString stringWithFormat:@"Single: %@", programmeURL] :self];
		
    ProgrammeData *myProgramme = [[ProgrammeData alloc]initWithName:aProgramme.programmeName andChannel:@"ITV" andPID:productionId andURL:programmeURL andNUMBEREPISODES:1];
	
    [myProgramme makeNew];
		
    /* get date aired "Monday 5 Mar 12.50am"  - we need to add in the year as that was not supplied */

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
    NSDataDetector *detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeDate error:NULL];
    NSArray *matches = [detector matchesInString:dateTimeAiredString options:0 range:NSMakeRange(0, [dateTimeAiredString length])];
		
    if ( matches.count )  {
        NSTextCheckingResult *match = matches[0];
        NSDate *dateFound = match.date;
        [dateFormatter setDateFormat:@"M"];
        int foundMonth = [[dateFormatter stringFromDate:dateFound]intValue];
        NSDate *today = [NSDate date];
        int todayMonth = [[dateFormatter stringFromDate:today]intValue];
        [dateFormatter setDateFormat:@"yyyy"];
        int todayYear = [[dateFormatter stringFromDate:today]intValue];
	
        if (foundMonth < todayMonth )
            todayYear++;
		
        dateTimeAiredString = [NSString stringWithFormat:@"%@ %d", dateTimeAiredString, todayYear];
        matches = [detector matchesInString:dateTimeAiredString options:0 range:NSMakeRange(0, [dateTimeAiredString length])];
        match = matches[0];
        myProgramme.dateAired = match.date;
        myProgramme.dateWithTime = true;
    }
		
    [myProgramme makeEpisodeName];
		
    if ( [myProgramme isValid] )
        [carriedForwardProgrammeArray addObject:myProgramme];
	
	/* Check if there is any outstanding work before processing the carried forward programme list */
	
	[[[AppController sharedController] itvProgressIndicator]incrementBy:myQueueSize -1 ? 100.0f/(float)(myQueueSize -1.0f) : 100.0f];
	
	if ( !myQueueLeft && !mergeUnderway  )
		[self processCarriedForwardProgrammes];
}

-(void)processCarriedForwardProgrammes
{
	
	/* add in image URL */
	
	for ( ProgrammeData *p in carriedForwardProgrammeArray )
		p.episodeImageURL =  [NSURL URLWithString:[NSString stringWithFormat:@"https://hubimages.itv.com/episode/%@?w=192&h=108&q=60&blur=0&bg=false&image_format=jpg", [p.productionId stringByReplacingOccurrencesOfString:@"a" withString:@"_"]]];

	/* Sort the programmes & write CF to disk */
    
    NSSortDescriptor *sort1 = [NSSortDescriptor sortDescriptorWithKey:@"programmeName" ascending:YES];
    NSSortDescriptor *sort2 = [NSSortDescriptor sortDescriptorWithKey:@"isNew" ascending:NO];
    
    [carriedForwardProgrammeArray sortUsingDescriptors:[NSArray arrayWithObjects:sort1, sort2, nil]];
    
    [NSKeyedArchiver archiveRootObject:carriedForwardProgrammeArray toFile:programmesFilePath];
	
	[self endOfRun];
}


-(void)endOfRun
{
    if ( processingError )  {
        ReasonForFailure *failure = [[ReasonForFailure alloc] init];
        failure.shortEpisodeName = @"ITV Listings";
        failure.solution = @"Error(s) occured getting the ITV programme listings - Check the log for details";
        [[[AppController sharedController] solutionsArrayController]addObject:failure];
    }
    
    /* Notify finish and invaliate the NSURLSession */

    getITVShowRunning = false;
    [mySession finishTasksAndInvalidate];

    if (forceUpdateAllProgrammes)
        [nc postNotificationName:@"ForceITVUpdateFinished" object:nil];
    else
        [nc postNotificationName:@"ITVUpdateFinished" object:NULL];
    
    forceUpdateAllProgrammes = false;
	
	float efficiency = 100.0f * ( (float)pagesNotRead / ((float)pagesRead + (float)pagesNotRead) );
	
	NSString *stats = [NSString stringWithFormat:@"ITV cache updated: Pages read: %d - not read: %d - Cache Efficiency: %3.2f%%", pagesRead, pagesNotRead, efficiency];
	
	[theLogger addToLog:stats];
}

-(void)mergeAllProgrammes
{
    int bfIndex = 0;
    int todayIndex = 0;
    mergeUnderway = true;
    
    ProgrammeData *bfProgramme = [boughtForwardProgrammeArray objectAtIndex:bfIndex];
    ProgrammeData *todayProgramme  = [todayProgrammeArray objectAtIndex:todayIndex];
    NSString *bfProgrammeName;
    NSString *todayProgrammeName;
    
    do {

        if (bfIndex < boughtForwardProgrammeArray.count) {
            bfProgramme = [boughtForwardProgrammeArray objectAtIndex:bfIndex];
            bfProgrammeName = bfProgramme.programmeName;
        }
        else {
            bfProgrammeName = @"~~~~~~~~~~";
        }
        if (todayIndex < todayProgrammeArray.count) {
            todayProgramme = [todayProgrammeArray objectAtIndex:todayIndex];
            todayProgrammeName = todayProgramme.programmeName;
        }
        else {
            todayProgrammeName = @"~~~~~~~~~~";
        }

        NSComparisonResult result = [bfProgrammeName compare:todayProgrammeName];
		
        switch ( result )  {

            case NSOrderedDescending:
            
                /* New; get all episodes & add tocarriedForwardProgrammeArray */
				
				myQueueSize++;
				[self.myOpQueue addOperation:[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(requestProgrammeEpisodes:) object:todayProgramme]];
            
                todayIndex++;
                
                break;

            case NSOrderedSame:
                
                /* for programmes that have more then one current episode and cache update is forced or current episode has changed or new episodes have been found; get full episode listing */
				
                if (  todayProgramme.numberEpisodes > 1  &&
                     ( bfProgramme.forceCacheUpdate == true || ![todayProgramme.productionId isEqualToString:bfProgramme.productionId] ||todayProgramme.numberEpisodes != bfProgramme.numberEpisodes) )  {
                    
                        if (bfProgramme.forceCacheUpdate == true)
                            [theLogger addToLog:[NSString stringWithFormat:@"GetITVListings (Warning): Cache upate forced for: %@", bfProgramme.programmeName]];
                        
                        myQueueSize++;
                        
                        [self.myOpQueue addOperation:[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(requestProgrammeEpisodes:)object:todayProgramme]];
                    
                        /* Now skip remaining BF episodes */
                    
                        for (bfIndex++; (bfIndex < boughtForwardProgrammeArray.count  &&
                                     [todayProgramme.programmeName isEqualToString:((ProgrammeData *)[boughtForwardProgrammeArray objectAtIndex:bfIndex]).programmeName]); bfIndex++ );
                 
                }
                
                else if ( todayProgramme.numberEpisodes == 1 )  {
					
					if ( [todayProgramme.productionId isEqualToString:bfProgramme.productionId] ) {
						
						/* if same programe that was BF then just copy it */
						[carriedForwardProgrammeArray addObject:bfProgramme];
					}
					else {
							
						/* Different episode so get programme data from web */
						myQueueSize++;
						[self.myOpQueue addOperation:[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(requestProgrammeEpisodes:) object:todayProgramme]];
					}
                
                    /* Now skip remaining BF episodes (if any) */
                
                    for (bfIndex++; (bfIndex < boughtForwardProgrammeArray.count  &&
                                     [todayProgramme.programmeName isEqualToString:((ProgrammeData *)[boughtForwardProgrammeArray objectAtIndex:bfIndex]).programmeName]); bfIndex++ );
                }
                
                else if ( [todayProgramme.productionId isEqualToString:bfProgramme.productionId] && todayProgramme.numberEpisodes == bfProgramme.numberEpisodes  )              {
                    
                    /* For programmes where the current episode and number of episodes has not changed so just copy BF to CF  */
					
					pagesNotRead++;
					
                    do {
                        [carriedForwardProgrammeArray addObject:[boughtForwardProgrammeArray objectAtIndex:bfIndex]];
                        
                    } while (  ++bfIndex < boughtForwardProgrammeArray.count  &&
                             [todayProgramme.programmeName isEqualToString:((ProgrammeData *)[boughtForwardProgrammeArray objectAtIndex:bfIndex]).programmeName]);
                }
                
                else {
                
                    /* Should never get here fo full reload & skip all episodes for this programme */
                    
                    [theLogger addToLog:[NSString stringWithFormat:@"GetITVListings (Error): Failed to correctly process %@ will issue a full refresh", todayProgramme]];
                    
                    myQueueSize++;
                    
                    [self.myOpQueue addOperation:[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(requestProgrammeEpisodes:)object:todayProgramme]];
                    
                    for (bfIndex++; (bfIndex < boughtForwardProgrammeArray.count  &&
                                     [todayProgramme.programmeName isEqualToString:((ProgrammeData *)[boughtForwardProgrammeArray objectAtIndex:bfIndex]).programmeName]); bfIndex++ );
                }
        
        todayIndex++;
        
        break;
        
            case NSOrderedAscending:

                /*  BF not found; Skip all episdoes on BF as programme no longer available */
            
                for (bfIndex++; (bfIndex < boughtForwardProgrammeArray.count  &&
                             [bfProgramme.programmeName isEqualToString:((ProgrammeData *)[boughtForwardProgrammeArray objectAtIndex:bfIndex]).programmeName]);  bfIndex++ );
                
                break;
        }
        
    } while ( bfIndex < boughtForwardProgrammeArray.count  || todayIndex < todayProgrammeArray.count  );
    
    mergeUnderway = false;
    
    if (myQueueSize < 2 )
        [[[AppController sharedController] itvProgressIndicator]incrementBy:100.0f];

    if (!myQueueSize)
        [self processCarriedForwardProgrammes];
}

-(BOOL)createTodayProgrammeArray
{
    /* Scan itv.com/shows to create full listing of programmes (not episodes) that are available today */
    
    todayProgrammeArray = [[NSMutableArray alloc]init];
    NSScanner *scanner = [NSScanner scannerWithString:htmlData];
    
    NSString *listingData;
    
    [scanner scanUpToString:@"<a href=\"https://www.itv.com/hub/" intoString:NULL];
    [scanner scanUpToString:@"</section>" intoString:&listingData];
    scanner = [NSScanner scannerWithString:listingData];

    NSString *fullProgramme = nil;
    NSString *temp = nil;
    
    NSUInteger scanPoint = 0;
    int numberEpisodes = 0;
    int testingProgrammeCount = 0;
	
    /* Get first programme  */
    
    [scanner scanUpToString:@"<a href=\"https://www.itv.com/hub/" intoString:NULL];
    [scanner scanUpToString:@"</a>" intoString:&fullProgramme];
    
    while ( (![scanner isAtEnd]) && ++testingProgrammeCount  /* < 5 */  ) {
    
        NSScanner *fullProgrammeScanner = [NSScanner scannerWithString:fullProgramme];
        scanPoint = fullProgrammeScanner.scanLocation;
        
        /* URL */
        
        NSString *programmeURL;
        
        [fullProgrammeScanner scanString:@"<a href=\"" intoString:NULL];
        [fullProgrammeScanner scanUpToString:@"\"" intoString:&programmeURL];
        
        if ( !programmeURL )  {
            NSString *reason = [NSString stringWithFormat:@"Could not get URL from ITV shows page - Index creation is abandoned"];
            [self reportProcessingError:@"https://www.itv.com/hub/shows" andWithREASON:reason];
            
            return NO;
        }
        
        /* Programme Name */
        
        NSString *programmeName;
		
        fullProgrammeScanner.scanLocation = scanPoint;
        [fullProgrammeScanner scanString:@"<a href=\"https://www.itv.com/hub/" intoString:NULL];
        [fullProgrammeScanner scanUpToString:@"/" intoString:&programmeName];
        
        if ( !programmeName )  {
            NSString *reason = [NSString stringWithFormat:@"Could not get programme name for URL %@ - Ignoring", programmeURL];
            [self reportProcessingError:@"https://www.itv.com/hub/shows" andWithREASON:reason];
            
            [scanner scanUpToString:@"<a href=\"https://www.itv.com/hub/" intoString:NULL];
            [scanner scanUpToString:@"</a>" intoString:&fullProgramme];
            
            continue;
        }
		
		/* Production ID */
		
        NSString *productionId;
        
		[fullProgrammeScanner scanUpToString:@"src=\"https://hubimages.itv.com/episode/" intoString:NULL];
		[fullProgrammeScanner scanString:@"src=\"https://hubimages.itv.com/episode/" intoString:NULL];
		[fullProgrammeScanner scanUpToString:@"?" intoString:&productionId];
		productionId = [productionId stringByReplacingOccurrencesOfString:@"_" withString:@"a"];
        
        if ( !productionId )  {
            NSString *reason = [NSString stringWithFormat:@"Could not get production id  for programme %@ - Ignoring", programmeName];
            [self reportProcessingError:@"https://www.itv.com/hub/shows" andWithREASON:reason];
            
            [scanner scanUpToString:@"<a href=\"https://www.itv.com/hub/" intoString:NULL];
            [scanner scanUpToString:@"</a>" intoString:&fullProgramme];
            
            continue;
        }
        

        /* Get mumber of episodes, assume 1 if you cant figure it out */
        
        numberEpisodes  = 1;
        
        [fullProgrammeScanner scanUpToString:@"<p class=\"tout__meta theme__meta\">" intoString:&temp];
        
        if ( ![fullProgrammeScanner isAtEnd])  {
            [fullProgrammeScanner scanString:@"<p class=\"tout__meta theme__meta\">" intoString:&temp];
            scanPoint = fullProgrammeScanner.scanLocation;
            [fullProgrammeScanner scanUpToString:@"episode" intoString:&temp];
                
            if ( ![fullProgrammeScanner isAtEnd])  {
                fullProgrammeScanner.scanLocation = scanPoint;
                [fullProgrammeScanner scanInt:&numberEpisodes];
            }
        }
        
        /* Create ProgrammeData Object and store in array */
        
		ProgrammeData *myProgramme = [[ProgrammeData alloc]initWithName:programmeName andChannel:@"ITV" andPID:productionId andURL:programmeURL andNUMBEREPISODES:numberEpisodes];

        [todayProgrammeArray addObject:myProgramme];
		
        /* Scan for next programme */
		
        [scanner scanUpToString:@"<a href=\"https://www.itv.com/hub/" intoString:NULL];
        [scanner scanUpToString:@"</a>" intoString:&fullProgramme];
        
    }

    /* Now we sort the programmes and the drop duplicates */
    
    if ( !todayProgrammeArray.count )  {
        [theLogger addToLog:@"No programmes found on www.itv.com/hub/shows"];
        
        NSAlert *alert = [[NSAlert alloc]init];
        alert.messageText = @"No programmes were found on www.itv.com/hub/shows";
        alert.informativeText = @"Try again later, if problem persists create a support request";
        [alert runModal];

        return NO;
    }
    
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"programmeName" ascending:YES];
    [todayProgrammeArray sortUsingDescriptors:[NSArray arrayWithObject:sort]];
    
    for (int i=0; i < todayProgrammeArray.count -1; i++) {
        ProgrammeData *programme1 = [todayProgrammeArray objectAtIndex:i];
        ProgrammeData *programme2 = [todayProgrammeArray objectAtIndex:i+1];
        
        if ( [programme1.programmeName isEqualToString:programme2.programmeName] ) {
            [todayProgrammeArray removeObjectAtIndex:i];
        }
    }

    return YES;
}

-(void)reportProcessingError:(NSString *)url andWithREASON: (NSString *)reason
{
    NSString *myError = [NSString stringWithFormat:@"getITVListings: Unable to process URL: %@  because %@", url, reason];
    [theLogger addToLog:myError :self];
    NSLog(@"%@", myError);
    processingError = true;
}

@end



