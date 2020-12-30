//
//  ProgrammeData.m
//  Get_iPlayer GUI
//
//  Created by LFS on 5/1/17.
//
//

#import <Foundation/Foundation.h>
#import "ProgrammeData.h"

extern bool runDownloads;
extern  LogController *theLogger;

@implementation ProgrammeData

- (id)init
{
	afield = 0;
	isNew = false;

	self.programmeName = @"";
	self.episodeName = @"";
	self.productionId = @"";
	self.programmeURL = @"";
	self.numberEpisodes = 0;
	self.forceCacheUpdate = false;
	self.tvNetwork = @"";
	self.seriesNumber = 0;
	self.episodeNumber = 0;
	self.episodeTitle = @"";
	self.status = @"";
	self.mp4Path = @"Unknown";
	self.tempMp4Path = @"Unknown";
	self.reasonForFailure = @"";
	self.addedByPVR = false;
	self.shortEpisodeName = @"";
	self.dateWithTime = false;
	self.downloadPath = @"Unknown";
	self.mp4FileName = @"Unknown";
	self.programDuration = 0;
	self.dateAiredString = @"-";
	self.timeAiredString = @"-";
	self.fullITVProductionID = @"";
	self.displayInfo = @"";
	self.episodeImage = NULL;
	self.episodeImageURL = NULL;
	
	self.progressDoubleValue = 0.0;
	self.progressIsHidden = YES;
	self.progressIsIndeterminate = NO;
	self.displayInfoIsHidden = NO;
	self.statusIsHidden = YES;
	self.progressMinValue = 0.0;
	self.progressMaxValue = 100.0;
	self.downloadStatus = NotStarted;
	self.downloadFailCount = 0;
	
	return self;
}

- (id)initWithName:(NSString *)name andChannel:(NSString *)tvNetwork andPID:(NSString *)pid andURL:(NSString *)url andNUMBEREPISODES:(int)numberEpisodes
{
	if (![self init]) return nil;
	
	self.programmeName = name;
	self.productionId = pid;
	self.programmeURL = url;
	self.numberEpisodes = numberEpisodes;
	self.forceCacheUpdate = false;
	self.tvNetwork = tvNetwork;
	
	if ( [tvNetwork isEqualToString:@"ITV"] )
		[self fixProgrammeName];
	
	return self;
}


- (id)initWithInfo:(id)sender pid:(NSString *)productionId programmeName:(NSString *)programmeName network:(NSString *)tvNetwork
{
	if (![self init]) return nil;
	
	self.productionId = productionId;
	self.programmeName = programmeName;
	self.tvNetwork = tvNetwork;
	
	if ( [tvNetwork isEqualToString:@"ITV"] )
		[self fixProgrammeName];

	return self;
}

- (id)description
{
	return [NSString stringWithFormat:@"%@: %@",self.productionId,self.programmeName];
}
- (void) encodeWithCoder: (NSCoder *)encoder
{
	[encoder encodeBool:self.addedByPVR forKey:@"addedByPVR"];
	[encoder encodeObject:[NSNumber numberWithInt:isNew] forKey:@"isNew"];
	[encoder encodeObject:self.programmeName forKey:@"programmeName"];
	[encoder encodeObject:self.episodeName forKey:@"episodeName"];
	[encoder encodeObject:self.productionId forKey:@"productionId"];
	[encoder encodeObject:self.programmeURL forKey:@"programmeURL"];
	[encoder encodeObject:[NSNumber numberWithInt:self.numberEpisodes] forKey:@"numberEpisodes"];
	[encoder encodeObject:[NSNumber numberWithInt:self.seriesNumber] forKey:@"seriesNumber"];
	[encoder encodeObject:[NSNumber numberWithInt:self.episodeNumber] forKey:@"episodeNumber"];
	[encoder encodeObject:[NSNumber numberWithInt:self.forceCacheUpdate] forKey:@"forceCacheUpdate"];
	[encoder encodeObject:self.episodeTitle forKey:@"episodeTitle"];
	[encoder encodeObject:self.tvNetwork forKey:@"tvNetwork"];
	[encoder encodeObject:self.dateAired forKey:@"dateAired"];
	[encoder encodeObject:self.shortEpisodeName forKey:@"shortEpisodeName"];
	[encoder encodeObject:self.dateAiredString forKey:@"dateAiredString"];
	[encoder encodeObject:self.timeAiredString forKey:@"timeAiredString"];
	[encoder encodeObject:[NSNumber numberWithInt:self.dateWithTime] forKey:@"dateWithTime"];
	[encoder encodeObject:self.displayInfo forKey:@"displayInfo"];
	[encoder encodeObject:self.episodeImage forKey:@"episodeImage"];
	[encoder encodeObject:self.episodeImageURL forKey:@"episodeImageURL"];
	[encoder encodeObject:[NSNumber numberWithInt:self.downloadStatus] forKey:@"downloadStatus"];
	
}

- (id) initWithCoder: (NSCoder *)decoder
{
	if (![self init]) return nil;
	
	self.status = @"";
	
	self.addedByPVR = [decoder decodeBoolForKey:@"addedByPVR"];
	self.programmeName = [decoder decodeObjectForKey:@"programmeName"];
	self.productionId = [decoder decodeObjectForKey:@"productionId"];
	self.programmeURL = [decoder decodeObjectForKey:@"programmeURL"];
	self.numberEpisodes = [[decoder decodeObjectForKey:@"numberEpisodes"] intValue];
	self.seriesNumber = [[decoder decodeObjectForKey:@"seriesNumber"] intValue];
	self.episodeNumber = [[decoder decodeObjectForKey:@"episodeNumber"] intValue];
	self.forceCacheUpdate = [[decoder decodeObjectForKey:@"forceCacheUpdate"] intValue];
	self.episodeName = [decoder decodeObjectForKey:@"episodeName"];
	self.episodeTitle = [decoder decodeObjectForKey:@"episodeTitle"];
	self.tvNetwork = [decoder decodeObjectForKey:@"tvNetwork"];
	self.dateAired = [decoder decodeObjectForKey:@"dateAired"];
	self.shortEpisodeName = [decoder decodeObjectForKey:@"shortEpisodeName"];
	self.dateAiredString = [decoder decodeObjectForKey:@"dateAiredString"];
	self.timeAiredString = [decoder decodeObjectForKey:@"timeAiredString"];
	isNew = [[decoder decodeObjectForKey:@"isNew"] intValue];
	self.dateWithTime = [[decoder decodeObjectForKey:@"dateWithTime"] intValue];
	self.displayInfo = [decoder decodeObjectForKey:@"displayInfo"];
	self.episodeImage = [decoder decodeObjectForKey:@"episodeImage"];
	self.episodeImageURL = [decoder decodeObjectForKey:@"episodeImageURL"];
	self.downloadStatus = [[decoder decodeObjectForKey:@"downloadStatus"] intValue];
	
	return self;
}

- (BOOL)isEqual:(id)object
{
	if ([object isKindOfClass:[self class]]) {
		ProgrammeData *otherP = (ProgrammeData *)object;
		return [otherP.productionId isEqual:self.productionId];
	}
	else {
		return false;
	}
}

- (id)makeNew
{
	isNew = true;
	
	return self;
}

-(void)fixProgrammeName
{
	self.programmeName = [self.programmeName stringByReplacingOccurrencesOfString:@"-" withString:@" "];
	self.programmeName = [self.programmeName capitalizedString];
}

- (void)createDownloadPaths
{
	if ( [self.tvNetwork isEqualToString:@"ITV"] )
		[self fixProgrammeName];
	
	NSString *fileName = self.episodeName;
	
	//Create Download Path
	
	NSString *downloadPath = [[NSUserDefaults standardUserDefaults] valueForKey:@"DownloadPath"];
	
	NSString *dirName = @"";
	dirName = [dirName stringByAppendingPathComponent:[NSString stringWithFormat:@"%@ (%@", self.programmeName, self.tvNetwork]];
	
	if ( [self seriesNumber] )
		dirName = [NSString stringWithFormat:@"%@ - Series %d", dirName, [self seriesNumber]];
	
	dirName = [dirName stringByAppendingString:@")"];
	
	dirName = [[dirName stringByReplacingOccurrencesOfString:@"/" withString:@"-"] stringByReplacingOccurrencesOfString:@":" withString:@" -"];
	self.downloadPath = [downloadPath stringByAppendingPathComponent:dirName];
	
	NSString *filePath = [[[NSString stringWithFormat:@"%@.%@", fileName, @"temp.mp4"] stringByReplacingOccurrencesOfString:@"/" withString:@"-"] stringByReplacingOccurrencesOfString:@":" withString:@" -"];
	
	self.tempMp4Path = [self.downloadPath stringByAppendingPathComponent:filePath];
	
	filePath = [[[NSString stringWithFormat:@"%@.%@",fileName, @"mp4"] stringByReplacingOccurrencesOfString:@"/" withString:@"-"] stringByReplacingOccurrencesOfString:@":" withString:@" -"];
	
	self.mp4Path = [self.downloadPath stringByAppendingPathComponent:filePath];
	self.mp4FileName = filePath;
	
}

-(NSString *)removeTags:(NSString *)theString
{
	NSError *error = NULL;
	
	NSRegularExpression *regex1 = [NSRegularExpression regularExpressionWithPattern:@"<[^<>]+>" options:NSRegularExpressionCaseInsensitive error:&error];
	
	while ( [regex1 numberOfMatchesInString:theString options:0 range:NSMakeRange(0, [theString length])] )
	{
		NSRange range = [regex1 rangeOfFirstMatchInString:theString options:0 range:NSMakeRange(0, theString.length)];
		theString = [theString stringByReplacingOccurrencesOfString: [theString substringWithRange:range] withString:@""];
	}
	
	return theString;
}

-(void)makeEpisodeName
{
	// EastEnders    PID  Episode 5665  -  Fri 2 Mar at 2000 (a funny old title)
	
	if ( [self.tvNetwork isEqualToString:@"ITV"] )
		[self fixProgrammeName];
	
	self.programmeName = [self removeTags:self.programmeName];
	self.episodeTitle  = [self removeTags:self.episodeTitle];
	
	self.episodeName = self.programmeName;
	
	if ( [self.tvNetwork containsString:@"BBC"] )
	{
		NSDate *d = [NSDate date];
		NSDateFormatter *yymmdd = [[NSDateFormatter alloc]init];
		[yymmdd  setDateFormat:@"yyMMdd"];
		
		if ( self.dateAired )
			d = self.dateAired;
		
		self.episodeName = [NSString stringWithFormat:@"%@ %@", self.episodeName, [yymmdd stringFromDate:d]];
	}
	else
	{
		self.episodeName = [NSString stringWithFormat:@"%@ %@", self.episodeName, self.productionId];
	}
	
	if ( self.episodeNumber )
		self.episodeName = [self.episodeName stringByAppendingFormat:@" Episode %d", self.episodeNumber];
	
	
	/* Use date aired if we have it */
	
	if ( self.dateAired )
	{
		NSDateFormatter *hhmm = [[NSDateFormatter alloc]init];
		NSDateFormatter *episodeNameFormat = [[NSDateFormatter alloc]init];
		
		[hhmm   setDateFormat:@"HHmm"];
		[episodeNameFormat setDateFormat:@"E MMM d"];
		
		self.episodeName = [self.episodeName stringByAppendingFormat:@" - %@", [episodeNameFormat stringFromDate:self.dateAired]];
		
		if (self.dateWithTime )
			self.episodeName = [self.episodeName stringByAppendingFormat:@" at %@", [hhmm stringFromDate:self.dateAired]];
	}

	if (self.episodeTitle.length)
		self.episodeName = [NSString stringWithFormat:@"%@ (%@)", self.episodeName, self.episodeTitle];
	
	if ( [self.tvNetwork containsString:@"BBC"] )
		self.episodeName = [NSString stringWithFormat:@"%@ - %@", self.episodeName, self.productionId];

	/* Add some formatting data for display purposes only */
	
	NSDateFormatter *timeFormat = [[NSDateFormatter alloc]init];
	NSDateFormatter *dateFormat = [[NSDateFormatter alloc]init];
	
	[timeFormat   setDateFormat:@"h:mm a"];
	[dateFormat   setDateFormat:@"E d MMM"];
	
	if ( self.dateAired )
		self.dateAiredString = [dateFormat stringFromDate:self.dateAired];
	else
		self.dateAiredString = @"-";
			
	if ( self.dateWithTime )
			self.timeAiredString = [timeFormat stringFromDate:self.dateAired];
	else
		self.timeAiredString = @"-";
	
	/* Create short episode name */
	
	if ( self.dateAired )  {
		self.shortEpisodeName = [NSString stringWithFormat:@"%@ - %@", self.programmeName, [dateFormat stringFromDate:self.dateAired]];
	
		if (self.dateWithTime ) {
			self.shortEpisodeName = [self.shortEpisodeName stringByAppendingFormat:@" at %@", [timeFormat stringFromDate:self.dateAired]];
		}
	}
	else
		self.shortEpisodeName = self.episodeName;

	[self createDownloadPaths];
	
	/* Display name for the UI */
	
	[dateFormat setDateFormat:@"EEEE MMM d yyyy, "];
	[timeFormat   setDateFormat:@"h:mma"];
	
	NSString *dateAired = self.dateAired ? [dateFormat stringFromDate:self.dateAired] : @"";
	NSString *timeAired = self.dateWithTime ? [timeFormat stringFromDate:self.dateAired] : @"";
	NSString *seriesString  = self.seriesNumber ? [NSString stringWithFormat:@"Series %d ", self.seriesNumber]  : @"";
	NSString *episodeString = self.episodeNumber ? [NSString stringWithFormat:@"Episode %d ", self.episodeNumber] : @"";
	
	self.displayInfo = [NSString stringWithFormat:@"%@: %@%@%@%@", self.tvNetwork, dateAired, seriesString, episodeString, timeAired];
	
	return;
}

-(NSString *)getDateAiredFromString:(NSString *)theString
{
	
	NSError *error = NULL;
	NSString *pattern = @"(\\d{1,2}[-/.]\\d{1,2}[-/.]\\d{1,4})";
	
	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:&error];
	
	for (NSTextCheckingResult *match in [regex matchesInString:theString options:0 range:NSMakeRange(0, theString.length)])
	{
		NSArray *dateArray = [[theString substringWithRange:match.range] componentsSeparatedByString:@"/"];
		
		if ( dateArray.count < 3 )
			dateArray = [[theString substringWithRange:match.range] componentsSeparatedByString:@"-"];
		
		if ( dateArray.count == 3)
		{
			int dd = [[dateArray objectAtIndex:0] intValue];
			int mm = [[dateArray objectAtIndex:1] intValue];
			int yyyy = [[dateArray objectAtIndex:2] intValue];
		
			if (yyyy < 100 ) yyyy+=2000;
		
			NSString *newDate = [NSString stringWithFormat:@"%2d/%2d/%4d", dd, mm, yyyy];
			NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
			[dateFormatter setDateFormat:@"dd/MM/yyyy"];
			NSDate *progDate = [dateFormatter dateFromString:newDate];
		
			if ( [progDate timeIntervalSinceNow] > 0-(90 * 86400) && [progDate timeIntervalSinceNow] < 6 * 3600)  {
				self.dateAired = progDate;
				theString = [theString stringByReplacingOccurrencesOfString: [theString substringWithRange:match.range] withString:@""];
			}
		}
	}
	
	return theString;
}

-(void)analyseTitle:(NSString *)title
{
	
	title = [title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
	if  ( ![title length]  ) {
		[self makeEpisodeName];
		return;
	}
	
	self.programmeName = [self removeTags:self.programmeName];
	title  = [self removeTags:title];
	
	/* First try and pull out any dates thay might be hiding in the title */
	
	title = [self getDateAiredFromString:title];
	
	/* Now pull out all punctuation & crearte a word array of remaining contents */
	
	NSMutableArray *newTitleArray = [[NSMutableArray alloc]init];
	NSArray *titleArray = [title componentsSeparatedByCharactersInSet:[NSCharacterSet punctuationCharacterSet]];
	title = [titleArray componentsJoinedByString:@" "];
	titleArray = [title componentsSeparatedByString:@" "];
	
	BOOL getEpisodeNumber = false;
	BOOL getSeriesNumber = false;
	BOOL getPartNumber = false;
	
	/* Scan array pulling out episode or series numbers and keep the remainder as title text */
	
	for ( NSString *itemStr in titleArray ) {
		
		NSString *item = [itemStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		
		if (!item.length)
			continue;
		
		if ( getEpisodeNumber ) {
			self.episodeNumber = [item intValue];
			getEpisodeNumber = false;
		}
		else if ( getSeriesNumber ) {
			self.seriesNumber = [item intValue];
			getSeriesNumber = false;
		}
		else if ( getPartNumber ) {
			[newTitleArray addObject:[item stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
			getPartNumber = false;
		}
		else if ( [item caseInsensitiveCompare:@"Episode"]  == NSOrderedSame ) {
			getEpisodeNumber = true;
		}
		else if ( [item caseInsensitiveCompare:@"Series"] == NSOrderedSame ) {
			getSeriesNumber = true;
		}
		else if ( [item caseInsensitiveCompare:@"Part"] == NSOrderedSame ) {
			getPartNumber = true;
			[newTitleArray addObject:[item stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
		}
		else  if ( !self.episodeNumber && [item intValue] && !( [item intValue] > 1900 && [item intValue] < 2100 ) )  {
			self.episodeNumber = [item intValue];
		}
		else {
			[newTitleArray addObject:[item stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
		}
	}
	
	self.episodeTitle = [newTitleArray componentsJoinedByString:@" "];
	
	[self makeEpisodeName];
	
	return;
}

-(BOOL)isValid
{
	if ( self.programmeName.length == 0 || self.episodeName.length == 0 || self.productionId.length == 0 || self.programmeURL.length == 0 || self.numberEpisodes == 0 || self.tvNetwork.length == 0 || self.shortEpisodeName.length == 0)  {
		[theLogger addToLog:[NSString stringWithFormat:@"Invalid Programme Data - Ignoring"]];
		[theLogger addToLog:[NSString stringWithFormat:@"self.programmeName    = %@", self.programmeName]];
		[theLogger addToLog:[NSString stringWithFormat:@"self.episodeName      = %@", self.episodeName]];
		[theLogger addToLog:[NSString stringWithFormat:@"self.productionId     = %@", self.productionId]];
		[theLogger addToLog:[NSString stringWithFormat:@"self.programmeURL     = %@", self.programmeURL]];
		[theLogger addToLog:[NSString stringWithFormat:@"self.numberEpisodes   = %d", self.numberEpisodes]];
		[theLogger addToLog:[NSString stringWithFormat:@"self.tvNetwork        = %@", self.tvNetwork]];
		[theLogger addToLog:[NSString stringWithFormat:@"self.shortEpisodeName = %@", self.shortEpisodeName]];
		return false;
	}
	
	return true;
}

@end


