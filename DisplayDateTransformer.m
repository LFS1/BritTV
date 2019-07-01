//
//  DisplayDateTransformer.m
//  BriTv
//
//  Created by LFS on 8/20/18.
//

#import "DisplayDateTransformer.h"

@implementation DisplayDateTransformer

- (id)transformedValue:(id)value
{
	
	NSDate *dateTimeRecorded = [[NSDate alloc]init];
	NSDateFormatter *df = [[NSDateFormatter alloc]init];
	[df setDateFormat:@"yyyy-MM-dd' at 'HH:mm:ss"];
	dateTimeRecorded = [df dateFromString:value];
	[df   setDateFormat:@"E d MMM' at 'h:mm a"];
	
	return  [df stringFromDate:dateTimeRecorded];

}

@end
