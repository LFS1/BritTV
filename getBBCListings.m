//
//  getBBCListings.m
//  Get_iPlayer GUI
//
//  Created by LFS on 4/29/17.
//
//

#import <Foundation/Foundation.h>

#import "getBBCListings.h"
#import "NSString+HTML.h"
#import "ReasonForFailure.h"


extern  LogController *theLogger;

@implementation GetBBCShows
	
- (id)init;
{
    if (!(self = [super init])) return nil;

    nc = [NSNotificationCenter defaultCenter];

    forceUpdateAllProgrammes = false;
    getBBCShowRunning = false;
	processingError = false;
    
    return self;
}

-(void)forceBBCUpdate
{
    [theLogger addToLog:@"GetBBCShows: Force all programmes update "];
    
    forceUpdateAllProgrammes = true;
	
    [self bbcUpdate];
    
}

-(void)bbcUpdate
{
    /* cant run if we are already running */
    
    if ( getBBCShowRunning == true )
		return;
	
    NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
    mySession = [NSURLSession sessionWithConfiguration:defaultConfigObject delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    
    
    [[[AppController sharedController] bbcProgressIndicator] setIndeterminate:false];

    getBBCShowRunning = true;
	myQueueLeft = 0;
	pagesRead = 0;
	pagesNotRead = 0;
    myQueueSize = 0;
    gotAZ = false;
    lastPercentDone = 0;
    
    /* Load in carried forward programmes & programme History */
    
    filesPath = @"~/Library/Application Support/BriTv/";
    filesPath= [filesPath stringByExpandingTildeInPath];
    
    programmesFilePath = [filesPath stringByAppendingString:@"/bbcprogrammes.gia"];
    
    if ( !forceUpdateAllProgrammes )
    	boughtForwardProgrammeArray = [NSKeyedUnarchiver unarchiveObjectWithFile:programmesFilePath];

    if ( boughtForwardProgrammeArray == nil || forceUpdateAllProgrammes || boughtForwardProgrammeArray.count == 0 ) {
		ProgrammeData *emptyProgramme = [[ProgrammeData alloc]initWithName:@"program to be deleted" andChannel:@"BBC" andPID:@"PID" andURL:@"URL" andNUMBEREPISODES:0];
        boughtForwardProgrammeArray = [[NSMutableArray alloc]init];
        [boughtForwardProgrammeArray addObject:emptyProgramme];
    }
    
    /* Create empty carriedForwardProgrammeArray & history array */
    
    carriedForwardProgrammeArray = [[NSMutableArray alloc]init];
    
    /* Load in todays shows for bbc.com */
    
    myOpQueue = [[NSOperationQueue alloc] init];
    [myOpQueue setMaxConcurrentOperationCount:1];
    
    myQueueLeft++;
    myQueueSize++;
    
    [myOpQueue addOperation:[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(getBBCProgrammePages) object:nil]];
	
    return;
}

-(void)getBBCProgrammePages
{
    myQueueLeft--;
	
    NSArray *programmePages = @[@"a", @"b", @"c", @"d", @"e", @"f", @"g", @"h", @"i", @"j", @"k", @"l", @"m", @"n", @"o", @"p", @"q", @"r", @"s", @"t", @"u", @"v", @"w", @"x", @"y", @"z", @"0-9"];
    
	todayProgrammeArray = [[NSMutableArray alloc]init];
    
	myQueueLeft += programmePages.count;
	myQueueSize += programmePages.count;
    
    /* Cycle through channels loading programme pages  */

	for (int i=0; i < programmePages.count; i++) {
	
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://www.bbc.co.uk/iplayer/a-z/%@", programmePages[i]]];
		
        [[mySession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
			
			pagesRead++;
			myQueueLeft--;
			
			if ( error )  {
				NSString *reason = [NSString stringWithFormat:@"Unable to load BBC Index page error code %@", error];
				[self reportProcessingError:[NSString stringWithFormat:@"%@",url] andWithREASON:reason];
				[self processProgrammePage:@"" :url :programmePages[i]];
			}
			else {
            	NSString *thePage  = [[NSString alloc]initWithData:data encoding:NSASCIIStringEncoding];
            	thePage = [thePage stringByDecodingHTMLEntities];
                [self processProgrammePage:thePage :url :programmePages[i]];
			}
            
            [self updateProgressBar];
            
        }] resume];
    }
}

-(void)processProgrammePage:(NSString *)thePage :(NSURL *)theURL :(NSString *)thePageLetter
{
	if ( thePage.length == 0 )  {
		if ( !myQueueLeft )
			[self mergeAllProgrammes];
		
		return;
	}
    
    NSScanner *scanner = [NSScanner scannerWithString:thePage];
    NSString *programmeName = nil;
    NSString *productionId = nil;
    
    /* Get number of programmes */
    
    NSString *find = [NSString stringWithFormat:@"\"%@\":{\"count\":", thePageLetter];
        
    [scanner scanUpToString:find intoString:NULL];
    [scanner scanString:find intoString:NULL];
        
    int numberProgrammes = 0;
    [scanner scanInt:&numberProgrammes];
        
    if ( !numberProgrammes || numberProgrammes > 500 ) {
        [self reportProcessingError:[NSString stringWithFormat:@"%@",theURL] andWithREASON:[NSString stringWithFormat:@"Invalid number of programmes (%d) - Ignoring page", numberProgrammes]];
        
        if ( !myQueueLeft )
            [self mergeAllProgrammes];
        
        return;
    }
    
    /* Loop through and pick up each programme */
        
    int programmesFound = 0;
    BOOL forceUpdate;
        
    [scanner scanUpToString:@"{\"props\":" intoString:NULL];

    while ( (![scanner isAtEnd]) ) {
   
        forceUpdate = false;
        programmesFound++;
            
        [scanner scanString:@"{\"props\":" intoString:NULL];
		
        [scanner scanUpToString:@"/iplayer/episode/" intoString:NULL];
        [scanner scanString:@"/iplayer/episode/" intoString:NULL];
            
        /* Production ID (Required) */
            
        productionId = @"";
            
        [scanner scanUpToString:@"/" intoString: &productionId];
		
        if ( productionId.length == 0 )	{
            [self reportProcessingError:[NSString stringWithFormat:@"%@",theURL] andWithREASON:@"Could not find PID - ignoring programme"];
            [scanner scanUpToString:@"{\"props\":" intoString:NULL];
            continue;
        }
		
        /* Programme Name  (Required) */
		
        programmeName = @"";

        [scanner scanUpToString:@"\"title\":\"" intoString:NULL];
        [scanner scanString:@"\"title\":\"" intoString:NULL];
            
        [scanner scanUpToString:@"\"" intoString:&programmeName];
		
        if ( programmeName.length == 0 )	{
            [self reportProcessingError:[NSString stringWithFormat:@"%@", theURL] andWithREASON:@"Could not find programme name - ignoring programme"];
            [scanner scanUpToString:@"{\"props\":" intoString:NULL];
            continue;
        }
        
        /* look for available episodes */
            
        int numberEpisodes = 0;
            
        [scanner scanUpToString:@"\"episodesAvailable\":" intoString:NULL];
        [scanner scanString:@"\"episodesAvailable\":" intoString:NULL];
        [scanner scanInt:&numberEpisodes];
		
        if ( numberEpisodes == 0 )    {
            NSString *reason = [NSString stringWithFormat:@"invalid number of episodes (%d) in a-z listing for programme %@", numberEpisodes, programmeName];
            [self reportProcessingError:[NSString stringWithFormat:@"%@",theURL] andWithREASON:reason];
            forceUpdate = true;
        }
        
        /* Create ProgrammeData Object and store in array */
		
        ProgrammeData *myProgramme = [[ProgrammeData alloc]initWithName:programmeName andChannel:@"" andPID:productionId andURL:@"" andNUMBEREPISODES:numberEpisodes];
		
        myProgramme.programmeURL = [NSString stringWithFormat:@"https://www.bbc.co.uk/iplayer/episode/%@", productionId];
        myProgramme.forceCacheUpdate = forceUpdate;
		
        [todayProgrammeArray addObject:myProgramme];
            
        /* Point to next programme */
            
        [scanner scanUpToString:@"{\"props\":" intoString:NULL];
    }
        
    if (  programmesFound  != numberProgrammes )
		[self reportProcessingError:[NSString stringWithFormat:@"%@", theURL] andWithREASON:[NSString stringWithFormat:@"Warning: Programmes expected/found do not match (%d/%d)", numberProgrammes, programmesFound]];
    
	if (!myQueueLeft)
        [self mergeAllProgrammes];
    
}

-(void)getBBCEpisodesNew:(ProgrammeData *)myProgramme
{
    myQueueLeft--;
    
    /* First we load the page with the current episode data */
    
    myQueueLeft++;
    myQueueSize++;
    
	[[mySession dataTaskWithURL:[NSURL URLWithString:myProgramme.programmeURL] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		
        myQueueLeft--;
		pagesRead++;
        
        [self updateProgressBar];
        
		if ( error )  {
			NSString *reason = [NSString stringWithFormat:@"Unable to load BBC current episode page for %@ - error %@", myProgramme.programmeName, error];
			[self reportProcessingError:[NSString stringWithFormat:@"%@",myProgramme.programmeURL] andWithREASON:reason];
			
			if ( myQueueLeft == 0 && !mergeUnderway  )
				[self processCarriedForwardProgrammes];
			
			return;
		}
		
		NSString *responseURL  =  [[response URL]absoluteString];
		
		if ( ![responseURL containsString:myProgramme.programmeURL] ) {
			if ( myQueueLeft == 0 && !mergeUnderway  )
				[self processCarriedForwardProgrammes];
			
			return;
		}
        
		NSString *thePage  = [[NSString alloc]initWithData:data encoding:NSASCIIStringEncoding];
		thePage = [thePage stringByDecodingHTMLEntities];

    	NSScanner *scanner = [NSScanner scannerWithString:thePage];
        
        /* Get the channel it is on - we are only interested in BBC1->4; if anything else we call it X so i can be ignored in future */
        
        NSString  *masterBrand;
			
        [scanner scanUpToString:@"\"masterBrand\":{\"id\":\"" intoString:NULL];
        [scanner scanString:@"\"masterBrand\":{\"id\":\"" intoString:NULL];
        [scanner scanUpToString:@"\"" intoString:&masterBrand];
		
		if ( !masterBrand )  {
			NSString *reason = [NSString stringWithFormat:@"Could not get mater brand for %@ - ignoring programme",  myProgramme.programmeName];
			[self reportProcessingError:myProgramme.programmeURL andWithREASON:reason];
			
			if ( myQueueLeft == 0 && !mergeUnderway  )
				[self processCarriedForwardProgrammes];
			
			return;
		}
        
        if ( [masterBrand isEqualToString:@"bbc_alba"]  || [masterBrand isEqualToString:@"bbc_parliament"]  ||
             [masterBrand isEqualToString:@"bbc_news"]  || [masterBrand isEqualToString:@"bbc_radio_one"]   ||
             [masterBrand isEqualToString:@"cbbc"]      || [masterBrand isEqualToString:@"cbeebies"]        ||
             [masterBrand isEqualToString:@"s4c"]       || masterBrand.length == 0)  {
            
            myProgramme.tvNetwork = @"X";
            [carriedForwardProgrammeArray addObject:myProgramme];
      
            if ( myQueueLeft == 0 && !mergeUnderway  )
                [self processCarriedForwardProgrammes];

            return;
        }
        
        if ( [masterBrand isEqualToString:@"bbc_one" ] )
            myProgramme.tvNetwork = @"BBC 1";
        else if ( [masterBrand isEqualToString:@"bbc_two" ] )
            myProgramme.tvNetwork = @"BBC 2";
        else if ( [masterBrand isEqualToString:@"bbc_three" ] )
            myProgramme.tvNetwork = @"BBC 3";
        else if ( [masterBrand isEqualToString:@"bbc_four" ] )
            myProgramme.tvNetwork = @"BBC 4";
        else
            myProgramme.tvNetwork = @"BBC";
        
    	NSString  *brandId;
        scanner.scanLocation = 1;
			
    	[scanner scanUpToString:@"\"tleoId\":\"" intoString:NULL];
    	[scanner scanString:@"\"tleoId\":\"" intoString:NULL];
    	[scanner scanUpToString:@"\"" intoString:&brandId];
        
        if ( !brandId )  {
            NSString *reason = [NSString stringWithFormat:@"Could not get brandId for %@ - ignoring programme",  myProgramme.programmeName];
            [self reportProcessingError:myProgramme.programmeURL andWithREASON:reason];
            
            if ( myQueueLeft == 0 && !mergeUnderway  )
                [self processCarriedForwardProgrammes];

            return;
        }

    	/* Now get the episodes */
		
		NSString *episodesURLPrefix = @"https://www.bbc.co.uk/iplayer/episodes/";
    
        NSURL *episodesURL = [NSURL URLWithString:[episodesURLPrefix stringByAppendingString:brandId]];
        
        myQueueLeft++;
        myQueueSize++;
        
        [[mySession dataTaskWithURL:episodesURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            
            myQueueLeft--;
			pagesRead++;
            
            [self updateProgressBar];
            
			if ( error )  {
				NSString *reason = [NSString stringWithFormat:@"Unable to load first page of BBC episodes for %@ - error %@", myProgramme.programmeName, error];
				[self reportProcessingError:[NSString stringWithFormat:@"%@",episodesURL] andWithREASON:reason];
                
                if ( myQueueLeft == 0 && !mergeUnderway  )
                    [self processCarriedForwardProgrammes];
                
				return;
			}
            
            NSString *thePage  = [[NSString alloc]initWithData:data encoding:NSASCIIStringEncoding];
            thePage = [thePage stringByDecodingHTMLEntities];
    
            NSScanner *scanner = [NSScanner scannerWithString:thePage];
            [scanner scanUpToString:@"availableSlices\":null}" intoString:NULL];
    
            if ( ![scanner isAtEnd] ) {
                [self processBBCEpisodesNew:myProgramme :thePage :episodesURL :@""];
                // NSLog(@"@@Programme: %@ - No slices: %@", myProgramme.programmeName, brandId);
                return;
            }
    
            /* Episodes mighty be broken down into multiple slices; in which case each slice (which is typically a series) will be on its own page */
	
            //  Notes: Sometimes there are no slices in which case this is the episdoes page
            //	Sometimes there is only 1 slice  in which case this is the slice and also the episodes page
            //	sometimes there are > 1 slice in whuch case this is the episodes page for slice 1 and you need to retreive episodes from slices 2 onwards
	
            int	numberSlices = 0;
            NSString *theSlices;
	
            scanner = [NSScanner scannerWithString:thePage];
            [scanner scanUpToString:@"availableSlices\":[{" intoString:NULL];
            [scanner scanUpToString:@"]" intoString:&theSlices];
            scanner = [NSScanner scannerWithString:theSlices];
	
            [scanner scanUpToString:@"\"id\":\"" intoString:NULL];
	
            while ( ![scanner isAtEnd] ) {
		
                numberSlices++;
		
                NSString *sliceTitle, *seriesId;
		
                [scanner scanString:@"\"id\":\"" intoString:NULL];
                [scanner scanUpToString:@"\"" intoString:&seriesId];
        
                [scanner scanUpToString:@"\"title\":\"" intoString:NULL];
                [scanner scanString:@"\"title\":\"" intoString:NULL];
                [scanner scanUpToString:@"\"" intoString:&sliceTitle];
		
                [scanner scanUpToString:@"\"id\":\"" intoString:NULL];
		
                if ( numberSlices == 1 )  {
                    [self processBBCEpisodesNew:myProgramme :thePage :episodesURL :sliceTitle];
                    // NSLog(@"Programme: %@ - process single slice: %@ Title: %@", myProgramme.programmeName, seriesId, sliceTitle);
                }
                else {
                    NSURL *episodesPageURL = [[NSURL alloc]initWithString:[NSString stringWithFormat:@"%@%@?seriesId=%@", episodesURLPrefix, brandId,seriesId]];
                    
                    myQueueLeft++;
                    myQueueSize++;
                    
                    [[mySession dataTaskWithURL:episodesPageURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                        
                        myQueueLeft--;
						pagesRead++;
                        
                        [self updateProgressBar];
						
						if ( error )  {
							NSString *reason = [NSString stringWithFormat:@"Unable to load next slice of BBC episode for %@ - error %@", myProgramme.programmeName, error];
							[self reportProcessingError:[NSString stringWithFormat:@"%@",episodesPageURL] andWithREASON:reason];
                            
                            if ( myQueueLeft == 0 && !mergeUnderway  )
                                [self processCarriedForwardProgrammes];
						}
						else {
						
                        	NSString *thePage = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
                        	thePage = [thePage stringByDecodingHTMLEntities];
                        	// NSLog(@"Programme: %@ - process Multiple slice: %@ Title: %@ - %@", myProgramme.programmeName, seriesId, sliceTitle, episodesPageURL);
                            [self processBBCEpisodesNew:myProgramme :thePage :episodesPageURL :sliceTitle];
						}
                    }] resume];
                }
            }
        }] resume];
	}] resume];
	
	return;
}


-(void)processBBCEpisodesNew:(ProgrammeData *)theProgramme :(NSString *)thePage :(NSURL *)theURL :(NSString *)sliceTitle
{
	/*  Scan through episode page and create carried forward programme entries for each eipsode of aProgramme */
	
    NSString *theURLString = [NSString stringWithFormat:@"%@", theURL];
	
	NSScanner *scanner = [NSScanner scannerWithString:thePage];
	NSString *episodeName = nil;
	NSString *productionId = nil;
	int episodesFound = 0;
	
	int currentPage = 0;
	[scanner scanUpToString:@"{\"currentPage\":" intoString:NULL];
	[scanner scanString:@"{\"currentPage\":" intoString:NULL];
	[scanner scanInt:&currentPage];
	
	int totalEpisodes = 0;
	[scanner scanUpToString:@"\"totalEpisodes\":" intoString:NULL];
	[scanner scanString:@"\"totalEpisodes\":" intoString:NULL];
	[scanner scanInt:&totalEpisodes];
	
	int episodesPerPage = 0;
	[scanner scanUpToString:@"\"perPage\":" intoString:NULL];
	[scanner scanString:@"\"perPage\":" intoString:NULL];
	[scanner scanInt:&episodesPerPage];
	
	if ( !currentPage || !totalEpisodes || !episodesPerPage  )
		[self reportProcessingError:theURLString andWithREASON:[NSString stringWithFormat:@"page header data is inconssistent - continuing but episodes might be lost on %@", theProgramme.programmeName]];

	int episodesThisPage = totalEpisodes - ((currentPage -1) * episodesPerPage);
	
	if ( episodesThisPage > episodesPerPage )
		episodesThisPage = episodesPerPage;

	[scanner setScanLocation:1];

	/* loop through the page and pull out each programme */
	
    [scanner scanUpToString:@"\"props\":{" intoString:NULL];
	
	while ( (![scanner isAtEnd]) ) {
        
        episodesFound++;
        
        [scanner scanString:@"\"props\":{"  intoString:NULL];
        
        /* Try to get Episode Name - we need to get the token and see what it is */
        
        episodeName = @"";
        
        if  ( [scanner scanString:@"\"title\":\"" intoString:NULL]  )
            [scanner scanUpToString:@"\"" intoString:&episodeName];
        
        episodeName = [episodeName stringByAppendingString:@" "];
        episodeName = [episodeName stringByAppendingString:sliceTitle];
        
        /* Get Image File Name */
        
        NSString *imageFileName = NULL;
        NSURL    *imageURL = NULL;
        
        [scanner scanUpToString:@"https://ichef.bbci.co.uk/images/ic/" intoString:NULL];
        [scanner scanString:@"https://ichef.bbci.co.uk/images/ic/" intoString:NULL];
        [scanner scanUpToString:@"/" intoString:NULL];
        [scanner scanString:@"/" intoString:NULL];
        [scanner scanUpToString:@".jpg" intoString:&imageFileName];
        
        if (imageFileName) {
            imageURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://ichef.bbci.co.uk/images/ic/192x108/%@.jpg", imageFileName]];
        }
        else {
            NSString *reason = [NSString stringWithFormat:@"Getting episode detailes: ccould not get image filename for %@", theProgramme.programmeName];
            [self reportProcessingError:theURLString andWithREASON:reason];
            [scanner scanUpToString:@"\"props\":{"  intoString:NULL];
            continue;
        }
		
		/* Find Production ID (Required) & create programme URL */
        
        productionId = @"";
        [scanner scanUpToString:@"href\":\"/iplayer/episode/" intoString:NULL];
        [scanner scanString:@"href\":\"/iplayer/episode/" intoString:NULL];
        
		[scanner scanUpToString:@"/" intoString:&productionId];
		
		if ( productionId.length == 0 )	{
            NSString *reason = [NSString stringWithFormat:@"Getting episode detailes: could not find production id for %@", theProgramme.programmeName];
			[self reportProcessingError:theURLString andWithREASON:reason];
            [scanner scanUpToString:@"\"props\":{"    intoString:NULL];
			continue;
		}

		/* Create ProgrammeData Object and store in array */
		
		ProgrammeData *myProgramme = [[ProgrammeData alloc]initWithName:theProgramme.programmeName andChannel:theProgramme.tvNetwork andPID:productionId andURL:@"" andNUMBEREPISODES:theProgramme.numberEpisodes];
		
		myProgramme.programmeURL = [NSString stringWithFormat:@"https://www.bbc.co.uk/iplayer/episode/%@", productionId];
		myProgramme.episodeImageURL = imageURL;
		
		/* and update episode name */
		
		[myProgramme analyseTitle:episodeName];

		if ( [myProgramme isValid] ) {
			
            if (  [theProgramme.productionId isEqualToString:myProgramme.productionId] )
				[myProgramme makeNew];
    
			[carriedForwardProgrammeArray addObject:myProgramme];
		}
		
		/* Scan for next programme */
		
        [scanner scanUpToString:@"\"props\":{"    intoString:NULL];
        
        //NSLog(@"%@ - S:%d - %@ - %@", myProgramme.programmeName, myProgramme.seriesNumber, myProgramme.episodeName, myProgramme.productionId);
	}
    
    if (  episodesFound  != episodesThisPage)
        [self reportProcessingError:[NSString stringWithFormat:@"%@", theURL] andWithREASON:[NSString stringWithFormat:@"Warning: episodes expected/found do not match (%d/%d) - processing those that were found", episodesThisPage, episodesFound]];
	
	/* Check if there is any outstanding work before processing the carried forward programme list */
    
	if ( myQueueLeft == 0 && !mergeUnderway  )
		[self processCarriedForwardProgrammes];
	
}
-(void)updateProgressBar
{

    float actualPercentProgress;
    
    if ( !gotAZ ) {
        actualPercentProgress = 15.0 * (float)(((float)myQueueSize - (float)myQueueLeft)/(float)myQueueSize);
        [[[AppController sharedController] bbcProgressIndicator] setMaxValue:100];
        [[[AppController sharedController] bbcProgressIndicator] setDoubleValue:actualPercentProgress];
        return;
    }

    actualPercentProgress = 100.0  * (float)(((float)myQueueSize - (float)myQueueLeft)/(float)myQueueSize);
    
    /* Ignore updated were movevement is > 5% a trying to avoid big jumps in progress bar display */
    
    float percentThisCycle = actualPercentProgress - lastPercentDone;
    
    if ( percentThisCycle > 5 || actualPercentProgress < lastPercentDone ) {
        lastPercentDone = actualPercentProgress;
        return;
    }
    
    if ( myQueueSize ) {
        if ( myQueueLeft > 1 ) {
            [[[AppController sharedController] bbcProgressIndicator] setMaxValue:myQueueSize];
            [[[AppController sharedController] bbcProgressIndicator] setDoubleValue:myQueueSize - myQueueLeft];
        }
        else {
            [[[AppController sharedController] bbcProgressIndicator] setMaxValue:100];
            [[[AppController sharedController] bbcProgressIndicator] setDoubleValue:100];
        }
    
    }
    
    lastPercentDone = actualPercentProgress;
}

-(void)processCarriedForwardProgrammes
{
	
    /* Now we sort the programmes & write CF to disk */

    NSSortDescriptor *sort1 = [NSSortDescriptor sortDescriptorWithKey:@"programmeName" ascending:YES];
    NSSortDescriptor *sort2 = [NSSortDescriptor sortDescriptorWithKey:@"isNew" ascending:NO];
    
    [carriedForwardProgrammeArray sortUsingDescriptors:[NSArray arrayWithObjects:sort1, sort2, nil]];
    
    /* Now fix any 'numberEpisodes, that might be incorrect because of listing page and the number foid were different */
    
    int outer;

    for ( outer = 0; outer < carriedForwardProgrammeArray.count; outer++ ) {
        
        ProgrammeData *outerP = [carriedForwardProgrammeArray objectAtIndex:outer];
        int numberEpisodesCF = 1;
        int inner;
        
        for ( inner = outer +1; inner < carriedForwardProgrammeArray.count; inner++ )  {
            ProgrammeData *innerP = [carriedForwardProgrammeArray objectAtIndex:inner];
            
            if ( ![innerP.programmeName isEqualToString:outerP.programmeName] )
                break;
            
            numberEpisodesCF++;
                
        }
        for ( ; outer < inner; outer++ ) {
            ProgrammeData *p = carriedForwardProgrammeArray[outer];
            p.numberEpisodes =numberEpisodesCF;
        }
        outer--;
    }
    
    [NSKeyedArchiver archiveRootObject:carriedForwardProgrammeArray toFile:programmesFilePath];
	
    [self endOfRun];
}

-(void)endOfRun
{
    /* Notify finish and invaliate the NSURLSession */
	
	
	if ( processingError )  {
		ReasonForFailure *failure = [[ReasonForFailure alloc] init];
		failure.shortEpisodeName = @"BBC Listings";
		failure.solution = @"A minor error occured getting the BBC programme listings - Check the log for details";
		[[[AppController sharedController] solutionsArrayController]addObject:failure];
	}
    
    getBBCShowRunning = false;

    [mySession finishTasksAndInvalidate];
	
    if (forceUpdateAllProgrammes)
		[nc postNotificationName:@"ForceBBCUpdateFinished" object:nil];
    else
		[nc postNotificationName:@"BBCUpdateFinished" object:NULL];
    
    forceUpdateAllProgrammes = false;
	
	float efficiency = 100.0f * ( (float)pagesNotRead / ((float)pagesRead + (float)pagesNotRead) );
	
	NSString *stats = [NSString stringWithFormat:@"BBC cache updated: Pages read: %d - not read: %d - Cache Efficiency: %3.2f%%", pagesRead, pagesNotRead, efficiency];
	
    [theLogger addToLog:stats];
}

-(void)mergeAllProgrammes
{
    int bfIndex = 0;
    int todayIndex = 0;
    gotAZ = true;
	mergeUnderway = true;
    
	/* First we sort the programmes and the drop duplicates */
	
	if ( !todayProgrammeArray.count )  {
		[theLogger addToLog:@"No programmes found on www.bbc.com/hub/shows"];
        NSAlert *noProgs = [[NSAlert alloc]init];
        noProgs.messageText = @"No programmes were found on www.bbc.com/hub/shows";
        noProgs.informativeText = @"Try again later, if problem persists create a support request";
		[noProgs runModal];
		[self endOfRun];
		
		return;
	}
	
	NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"programmeName" ascending:YES];
	[todayProgrammeArray sortUsingDescriptors:[NSArray arrayWithObject:sort]];
	
	for (int i=0; i < todayProgrammeArray.count -1; i++) {
		ProgrammeData *programme1 = [todayProgrammeArray objectAtIndex:i];
		ProgrammeData *programme2 = [todayProgrammeArray objectAtIndex:i+1];
		
		if ( [programme1.programmeName isEqualToString:programme2.programmeName] )
			[todayProgrammeArray removeObjectAtIndex:i];

	}
	
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
            
            case NSOrderedDescending:   /* New; get episodes & add carriedForwardProgrammeArray  */

            myQueueLeft++;

            [myOpQueue addOperation:[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(getBBCEpisodesNew:) object:todayProgramme]];
            
            todayIndex++;
            
            break;
            
        case NSOrderedSame: /* Existing programme */
                
            /* if programme is not BBC1 through 4 - then we just carry forward so it can continue to be ignored */

            if ( [bfProgramme.tvNetwork isEqualToString:@"X"] ) {
				pagesNotRead++;
                [carriedForwardProgrammeArray addObject:bfProgramme];
            }
                
            /* For programmes where the current episode and number of episodes has not changed so just copy BF to CF  */
                
            else if (   [todayProgramme.productionId isEqualToString:bfProgramme.productionId]
                     && todayProgramme.numberEpisodes == bfProgramme.numberEpisodes
                     && bfProgramme.forceCacheUpdate == false
                     && todayProgramme.forceCacheUpdate == false )            {
                
                pagesNotRead++;
\
                do {
                    [carriedForwardProgrammeArray addObject:[boughtForwardProgrammeArray objectAtIndex:bfIndex]];
                    
                } while (  ++bfIndex < boughtForwardProgrammeArray.count  &&
                         [todayProgramme.programmeName isEqualToString:((ProgrammeData *)[boughtForwardProgrammeArray objectAtIndex:bfIndex]).programmeName]);
            }
            else {

            /* For programmes where the current or number of episodes has changed - get the episode details */

				myQueueLeft++;

                [myOpQueue addOperation:[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(getBBCEpisodesNew:)object:todayProgramme]];
                
                /* Now skip remaining BF episodes */
                
                for (bfIndex++; (bfIndex < boughtForwardProgrammeArray.count  &&
                                 [todayProgramme.programmeName isEqualToString:((ProgrammeData *)[boughtForwardProgrammeArray objectAtIndex:bfIndex]).programmeName]); bfIndex++ );
            }
            
            todayIndex++;
            
            break;
            
        case NSOrderedAscending:    /*  BF not found; Skip all episdoes on BF as programme no longer available */

            for (bfIndex++; (bfIndex < boughtForwardProgrammeArray.count  &&
                             [bfProgramme.programmeName isEqualToString:((ProgrammeData *)[boughtForwardProgrammeArray objectAtIndex:bfIndex]).programmeName]);  bfIndex++ );
            
            break;
        }
        
    } while ( bfIndex < boughtForwardProgrammeArray.count  || todayIndex < todayProgrammeArray.count  );
	
	mergeUnderway = false;
	
	myQueueSize += myQueueLeft;
	
	if (myQueueLeft == 0)
		[self processCarriedForwardProgrammes];
	
}

-(void)reportProcessingError:(NSString *)url andWithREASON: (NSString *)reason
{
	NSString *myError = [NSString stringWithFormat:@"getBBCListings: Unable to process URL: %@  because %@", url, reason];
	[theLogger addToLog:myError :self];
	NSLog(@"%@", myError);
	processingError = true;
}

@end


