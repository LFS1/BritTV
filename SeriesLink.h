//
//  Series.h
//  Get_iPlayer GUI
//
//  Created by Thomas Willson on 7/19/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//


#ifndef Series_h
#define Series_h

#import <Foundation/Foundation.h>


@interface SeriesLink : NSObject <NSCoding> {
	NSString *showName;
	NSString *tvNetwork;

}
- (id)initWithShowname:(NSString *)SHOWNAME;
@property (readwrite) NSString *programmeName;
@property (readwrite) NSString *tvNetwork;
@end


#endif

