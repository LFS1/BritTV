//
//  NPHistoryWindowController.m
//  Get_iPlayer GUI
//
//  Created by LFS on 8/6/16.
//
//

#import "NPHistoryWindowController.h"
#import "NewProgrammeHistory.h"

NewProgrammeHistory *sharedHistoryContoller;

@implementation NPHistoryTableViewController

-(id)init
{
    self = [super init];
    
    if (!self)
        return self;
    
    /* Load in programme History */

    sharedHistoryContoller = [NewProgrammeHistory sharedInstance];
    programmeHistoryArray =  [sharedHistoryContoller getHistoryArray];
    
    historyDisplayArray = [[NSMutableArray alloc]init];
    
    [self loadDisplayData];
    
    NSNotificationCenter *nc;
    nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self selector:@selector(loadDisplayData) name:@"NewProgrammeDisplayFilterChanged" object:nil];
    
    return self;
}

- (IBAction)changeFilter:(id)sender {
    [self loadDisplayData];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [historyDisplayArray count];
    
}


- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    
    ProgrammeHistoryObject *np = [historyDisplayArray objectAtIndex:row];
    
    NSString *identifer = [tableColumn identifier];
    
    return [np valueForKey:identifer];
    
}

-(void)loadDisplayData
{
    NSString *displayDate = nil;
    NSString *headerDate = nil;
    NSString *theItem = nil;
    int     pageNumber = 0;
    
    /* Set up date for use in headings comparison */
    
    double secondsSince1970 = [[NSDate date] timeIntervalSince1970];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];            [dateFormatter setDateFormat:@"EEE MMM dd"];
    NSDateFormatter *dateFormatterDayOfWeek = [[NSDateFormatter alloc] init];   [dateFormatterDayOfWeek setDateFormat:@"EEEE"];
    
    NSMutableDictionary *dayNames = [[NSMutableDictionary alloc]init];

    NSString *keyValue;
    NSString *key;
    
    for (int i=0;i<7;i++, secondsSince1970-=(24*60*60)) {
        
        if (i==0)
            keyValue = @"Today";
        else if (i==1)
            keyValue = @"Yesterday";
        else
            keyValue = [dateFormatterDayOfWeek stringFromDate:[NSDate dateWithTimeIntervalSince1970:secondsSince1970]];
        
        key = [dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:secondsSince1970]];
        
        [dayNames setValue:keyValue forKey:key];
    }
    
    [historyDisplayArray removeAllObjects];
    
    for (ProgrammeHistoryObject *np in programmeHistoryArray )  {
        
        if ( [self showITVProgramme:np] || [self showBBCTVProgramme:np] )  {
                                                                                                            
            if ( [np.dateFound isNotEqualTo:displayDate] ) {
                
                displayDate = np.dateFound;
                
                headerDate = [dayNames objectForKey:np.dateFound];
                
                if (!headerDate)  {
                    headerDate = @"On : ";
                    headerDate = [headerDate stringByAppendingString:displayDate];
                }
                
                [historyDisplayArray addObject:[[HistoryDisplay alloc]initWithItemString:nil andTVChannel:nil andLineNumber:2 andPageNumber:pageNumber]];
                
                [historyDisplayArray addObject:[[HistoryDisplay alloc]initWithItemString:headerDate andTVChannel:nil andLineNumber:0 andPageNumber:++pageNumber]];
            }
            
            theItem = @"     ";
            theItem = [theItem stringByAppendingString:[np programmeName]];
            
            [historyDisplayArray addObject:[[HistoryDisplay alloc]initWithItemString:theItem andTVChannel:np.tvChannel andLineNumber:1 andPageNumber:pageNumber]];
        }
    }
    
    [historyDisplayArray addObject:[[HistoryDisplay alloc]initWithItemString:nil andTVChannel:nil andLineNumber:2 andPageNumber:pageNumber]];
    
    /* Sort in to programme within reverse date order */

    NSSortDescriptor *sort4 = [NSSortDescriptor sortDescriptorWithKey:@"networkNameString" ascending:YES];
    NSSortDescriptor *sort3 = [NSSortDescriptor sortDescriptorWithKey:@"programmeNameString" ascending:YES];
    NSSortDescriptor *sort2 = [NSSortDescriptor sortDescriptorWithKey:@"lineNumber" ascending:YES];
    NSSortDescriptor *sort1 = [NSSortDescriptor sortDescriptorWithKey:@"pageNumber" ascending:NO];
    [historyDisplayArray sortUsingDescriptors:[NSArray arrayWithObjects:sort1, sort2, sort3, sort4, nil]];
    
    [historyTable reloadData];
    
    return;
}

-(BOOL)showITVProgramme:(ProgrammeHistoryObject *)np
{
	if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"IgnoreAllTVNews"]isEqualTo:@YES]) {
		if ([np.programmeName rangeOfString:@"news" options:NSCaseInsensitiveSearch].location != NSNotFound) {
			return NO;
		}
	}
	
    if (([[[NSUserDefaults standardUserDefaults] valueForKey:@"ITV"]isEqualTo:@YES] && [np.tvChannel hasPrefix:@"ITV"]))
		return YES;
    
    return NO;
}
-(BOOL)showBBCTVProgramme:(ProgrammeHistoryObject *)np
{
	
    if ( ![np.networkName isEqualToString:@"BBC TV"] )
        return NO;
    
    if ([[[NSUserDefaults standardUserDefaults] valueForKey:@"IgnoreAllTVNews"]isEqualTo:@YES]) {
        if ([np.programmeName rangeOfString:@"news" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return NO;
        }
    }

    if (([[[NSUserDefaults standardUserDefaults] valueForKey:@"BBCOne"]isEqualTo:@YES] && [np.tvChannel hasPrefix:@"BBC One"]) ||
         ([[[NSUserDefaults standardUserDefaults] valueForKey:@"BBCTwo"]isEqualTo:@YES] && [np.tvChannel hasPrefix:@"BBC Two"]) ||
         ([[[NSUserDefaults standardUserDefaults] valueForKey:@"BBCThree"]isEqualTo:@YES] && [np.tvChannel hasPrefix:@"BBC Three"]) ||
         ([[[NSUserDefaults standardUserDefaults] valueForKey:@"BBCFour"]isEqualTo:@YES] && [np.tvChannel hasPrefix:@"BBC Four"]) 
        )
        return YES;
	
	// New format channel names as of 6/27/2017 at some point above could be removed 
	if (([[[NSUserDefaults standardUserDefaults] valueForKey:@"BBCOne"]isEqualTo:@YES] && [np.tvChannel hasPrefix:@"BBC 1"]) ||
		([[[NSUserDefaults standardUserDefaults] valueForKey:@"BBCTwo"]isEqualTo:@YES] && [np.tvChannel hasPrefix:@"BBC 2"]) ||
		([[[NSUserDefaults standardUserDefaults] valueForKey:@"BBCThree"]isEqualTo:@YES] && [np.tvChannel hasPrefix:@"BBC 3"]) ||
		([[[NSUserDefaults standardUserDefaults] valueForKey:@"BBCFour"]isEqualTo:@YES] && [np.tvChannel hasPrefix:@"BBC 4"])
		)
		return YES;
	
    return NO;
}

@end




@implementation HistoryDisplay

- (id)initWithItemString:(NSString *)aItemString andTVChannel:(NSString *)aTVChannel andLineNumber:(int)aLineNumber andPageNumber:(int)aPageNumber;
{
    programmeNameString = aItemString;
    lineNumber = aLineNumber;
    pageNumber  = aPageNumber;
    networkNameString = aTVChannel;
    
    return self;
}

@end


