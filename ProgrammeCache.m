//
//  ProgrammeCache.m
//  Get_iPlayer GUI
//
//  Created by LFS on 6/2/17.
//
//

#import "ProgrammeCache.h"
#import "ProgrammeData.h"
#import "DownloadHistoryCache.h"

@implementation ProgrammeCache

+(ProgrammeCache *)sharedInstance
{
	static ProgrammeCache *sharedInstance = nil;
	static dispatch_once_t onceToken;
	
	dispatch_once(&onceToken, ^{
		sharedInstance = [[ProgrammeCache alloc] init];
	});
	
	return sharedInstance;
}

-(id)init
{
	if (self = [super init]) {
		
		cacheExists = false;
		bbcCache = [[NSArray alloc]init];
		itvCache = [[NSArray alloc]init];
		downloadHistoryCache = [[DownloadHistoryCache alloc]init];
	}
	
	return self;
}


-(void)buildProgrammeCache
{
	
	/* Load in itv programme cache */
	
	NSString *itvCacheFile = @"~/Library/Application Support/BriTv/itvprogrammes.gia";
	itvCacheFile = [itvCacheFile stringByExpandingTildeInPath];

	itvCache = [NSKeyedUnarchiver unarchiveObjectWithFile:itvCacheFile];
	
	if ( itvCache == nil  )
		NSLog(@"ERROR: Cannot create search cache from %@", itvCacheFile);

	
	/* Load in bbc programme cache */
	
	NSString *bbcCacheFile = @"~/Library/Application Support/BriTv/bbcprogrammes.gia";
	bbcCacheFile = [bbcCacheFile stringByExpandingTildeInPath];
	
	NSMutableArray *bbcCacheTemp = [[NSMutableArray alloc]init];
	NSMutableArray *remove = [[NSMutableArray alloc]init];
	
	bbcCacheTemp = [NSKeyedUnarchiver unarchiveObjectWithFile:bbcCacheFile];
	
	for (ProgrammeData *programme in bbcCacheTemp)
		if ( [programme.tvNetwork isEqualToString:@"X"] )
			[remove addObject:programme];
	
	[bbcCacheTemp removeObjectsInArray:remove];
	bbcCache = [[NSArray alloc]initWithArray:bbcCacheTemp];
	
	if ( bbcCache == nil  )
		NSLog(@"ERROR: Cannot create search cache from %@", bbcCacheFile);
	
	cacheExists = true;
	
	return;
}

-(NSArray*)searchProgrammeCache:(NSString *)searchName andSEARCHTYPE:(NSString *)searchType andAllowDownloaded:(BOOL)allowDownloaded
{
	if ( cacheExists == false )
		[self buildProgrammeCache];

	NSMutableArray *result = [[NSMutableArray alloc]init];
	NSPredicate *predicate;
	
	if ( [@"Exact" isEqualToString:searchType])
		predicate = [NSPredicate predicateWithFormat:@"programmeName =[c] %@",searchName];
	
	else if ( [@"Contains" isEqualToString:searchType])
		predicate = [NSPredicate predicateWithFormat:@"programmeName CONTAINS[c] %@",searchName];
	
	else	{
		NSLog(@"Search programe cache: invalid argument: %@ for search %@", searchType, searchName );
		return NULL;
	}
	
	NSArray *itvResult = [NSArray arrayWithArray:[itvCache filteredArrayUsingPredicate:predicate]];
	NSArray *bbcResult = [NSArray arrayWithArray:[bbcCache filteredArrayUsingPredicate:predicate]];
	
	[result addObjectsFromArray:itvResult];
	[result addObjectsFromArray:bbcResult];
	
	if (allowDownloaded)
		return result;
	
	NSMutableArray *alreadyDownloaded = [[NSMutableArray alloc]init];
	
	for (ProgrammeData *programme in result)
		if ( [downloadHistoryCache searchHistory:programme.productionId] )
			[alreadyDownloaded addObject:programme];
		
	[result removeObjectsInArray:alreadyDownloaded];

	return result;
}

-(BOOL)isPidDownloaded:(NSString *)pid
{
	return  [downloadHistoryCache searchHistory:pid] ? YES:NO;
}

@end


