//
//  NPHistoryWindowController.h
//  Get_iPlayer GUI
//
//  Created by LFS on 8/6/16.
//
//


#ifndef NPHistoryWindowController_h
#define NPHistoryWindowController_h

#import <Cocoa/Cocoa.h>
#import "ProgrammeHistoryObject.h"


@interface NPHistoryTableViewController : NSWindowController  <NSTableViewDataSource>
{
    IBOutlet NSTableView    *historyTable;
    NSMutableArray          *historyDisplayArray;
    NSArray                 *programmeHistoryArray;
}

-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView;
-(id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row;
-(void)loadDisplayData;
-(BOOL)showITVProgramme:(ProgrammeHistoryObject *)np;
-(BOOL)showBBCTVProgramme:(ProgrammeHistoryObject *)np;

@end

@interface HistoryDisplay : NSObject
{
    NSString *programmeNameString;
    NSString *networkNameString;
    int lineNumber;
    int pageNumber;
}

- (id)initWithItemString:(NSString *)aItemString andTVChannel:(NSString *)aTVChannel andLineNumber:(int)aLineNumber andPageNumber:(int)aPageNumber;

@end

#endif



