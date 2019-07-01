//
//  PageData.h
//  BriTv
//
//  Created by LFS on 6/12/18.
//

#import <Foundation/Foundation.h>

@interface PageData : NSObject

@property	NSString	*pageContent;
@property	NSString	*pageURL;
@property	NSString	*pageChannel;
@property	int			pageNumber;
@property	BOOL		firstPage;
@property	int			numberEpisodes;

@end
