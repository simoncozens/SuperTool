//
//  SCCurveFitter+Tangents.h
//  SuperTool
//
//  Created by Simon Cozens on 03/04/2017.
//  Copyright © 2017 Simon Cozens. All rights reserved.
//

#import "SCCurveFitter.h"

@interface SCCurveFitter (Tangents)

+ (NSPoint) leftTangent:(NSArray*)d;
+ (NSPoint) rightTangent:(NSArray*)d;
+ (NSPoint) leftTangent:(NSArray*)d tolerance:(double)toleranceSq;
+ (NSPoint) rightTangent:(NSArray*)d tolerance:(double)toleranceSq;
+ (NSPoint) centerTangent:(NSArray*)d center:(NSUInteger)center;


@end
