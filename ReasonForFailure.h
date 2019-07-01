//
//  ReasonForFailure.h
//  Get_iPlayer GUI
//
//  Created by Thomas E. Willson on 8/3/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#ifndef ReasonForFailure_h
#define ReasonForFailure_h

#import <Foundation/Foundation.h>

@interface ReasonForFailure : NSObject {
    NSString *shortEpisodeName;
    NSString *solution;
}

@property (readwrite) NSString *shortEpisodeName;
@property (readwrite) NSString *solution;

@end

#endif

