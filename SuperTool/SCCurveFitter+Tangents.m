//
//  SCCurveFitter+Tangents.m
//  SuperTool
//
//  Created by Simon Cozens on 03/04/2017.
//  Copyright © 2017 Simon Cozens. All rights reserved.
//

#import "SCCurveFitter+Tangents.h"

@implementation SCCurveFitter (Tangents)

+ (NSPoint) centerTangent:(NSArray*)d center:(NSUInteger)center {
    assert( center != 0 );
    assert( center < [d count] - 1 );
    NSPoint ret;
    NSPoint middle =[(GSNode*)d[center] position];
    NSPoint before =[(GSNode*)d[center - 1] position];
    NSPoint after = [(GSNode*)d[center + 1] position];
    if ( GSSquareDistance( before , after  ) < FLT_EPSILON ) {
        NSPoint const diff = GSSubtractPoints(middle, before);
        ret = GSNormalVector2(diff);
    } else {
        ret = GSSubtractPoints(before, after);
    }
    return GSUnitVector(ret);
}


+ (NSPoint) leftTangent:(NSArray*)d {
    NSPoint first =[(GSNode*)d[0] position];
    NSPoint second =[(GSNode*)d[1] position];
    return GSUnitVector(GSSubtractPoints(second,first));
}

+ (NSPoint) rightTangent:(NSArray*)d {
    NSPoint last =[(GSNode*)[d lastObject] position];
    NSPoint penultimate =[(GSNode*)d[[d count]-2] position];
    return GSUnitVector(GSSubtractPoints(penultimate,last));
}

+ (NSPoint) leftTangent:(NSArray*)d tolerance:(double)toleranceSq {
    for (unsigned i = 1;;) {
        NSPoint pi = [(GSNode*)d[i] position];
        NSPoint first =[(GSNode*)d[0] position];
        NSPoint t = GSSubtractPoints(pi, first);
        double const distsq = GSDot(t,t);
        if ( toleranceSq < distsq ) {
            return GSUnitVector(t);
        }
        ++i;
        if (i == [d count]) {
            return distsq == 0 ? [self leftTangent:d] : GSUnitVector(t);
        }
    }
}

+ (NSPoint) rightTangent:(NSArray*)d tolerance:(double)toleranceSq {
    NSUInteger last = [d count]-1;
    for (NSUInteger i = last - 1;; i--) {
        NSPoint pi = [(GSNode*)d[i] position];
        NSPoint final =[(GSNode*)[d lastObject] position];
        NSPoint t = GSSubtractPoints(pi, final);
        double const distsq = GSDot(t,t);
        if ( toleranceSq < distsq ) {
            return GSUnitVector(t);
        }
        if (i == 0) {
            return distsq == 0 ? [self rightTangent:d] : GSUnitVector(t);
        }
    }
}
@end
