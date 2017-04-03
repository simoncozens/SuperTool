//
//  GSPath+SCPathUtils.m
//  SuperTool
//
//  Created by Simon Cozens on 14/07/2016.
//  Copyright © 2016 Simon Cozens. All rights reserved.
//

#import "GSPath+SCPathUtils.h"

@implementation GSPath (SCPathUtils)

+ (GSPath*)initWithp0:(NSPoint)p0 p1:(NSPoint)p1 p2:(NSPoint)p2 p3:(NSPoint)p3 {
    GSPath* p = [[GSPath alloc] init];
    [p addSmooth:p0];
    [p addOffcurve:p1];
    [p addOffcurve:p2];
    [p addSmooth:p3];
    return p;
}

+ (GSPath*)initWithPointArray:(NSArray*)pts {
    GSPath* p = [[GSPath alloc] init];
    [p addSmooth:[pts[0] pointValue]];
    [p addOffcurve:[pts[1] pointValue]];
    [p addOffcurve:[pts[2] pointValue]];
    [p addSmooth:[pts[3] pointValue]];
    return p;
}

- (CGFloat)distanceFromPoint: (NSPoint)p {
    CGFloat d = MAXFLOAT;
    for (NSArray* seg in [self segments]) {
        CGFloat localD;
        if ([seg count] ==  2) {
            localD = GSDistanceOfPointFromLineSegment(p, [seg[0] pointValue], [seg[1] pointValue]);
        } else {
            localD = GSDistanceOfPointFromCurve(p, [seg[0] pointValue], [seg[1] pointValue], [seg[2] pointValue], [seg[3] pointValue]);
        }
        if (localD < d) d = localD;
    }
    return d;
}


-(void)addOffcurve:(NSPoint)pos {
    GSNode *n = [[GSNode alloc] init];
    n.position = pos;
    n.type = OFFCURVE;
    [self addNode: n];
}
-(void)addSmooth:(NSPoint)pos {
    GSNode *n = [[GSNode alloc] init];
    n.position = pos;
    n.type = CURVE; n.connection = SMOOTH;
    [self addNode: n];
}

- (void)append:(GSPath*)source { [self addNodes:[source nodes]]; }

- (NSPoint)qPrimeAtTime:(CGFloat)t {
    return GSAddPoints(
                       GSAddPoints(
                                   GSScalePoint(
                                                GSSubtractPoints([[self nodeAtIndex:1] position], [[self nodeAtIndex:0] position]),
                                                3*(1.0-t)*(1.0-t)
                                                ),
                                   GSScalePoint(
                                                GSSubtractPoints([[self nodeAtIndex:2] position], [[self nodeAtIndex:1] position]),
                                                6*(1.0-t) * t
                                                )
                                   ),
                       GSScalePoint(
                                    GSSubtractPoints([[self nodeAtIndex:3] position], [[self nodeAtIndex:2] position]),
                                    3 * t * t
                                    )
                       );
}

- (NSPoint)qPrimePrimeAtTime:(CGFloat)t {
    NSPoint alpha = GSScalePoint(
                                 GSAddPoints(
                                             GSSubtractPoints([[self nodeAtIndex:2] position], GSScalePoint([[self nodeAtIndex:1] position], 2)),
                                             [[self nodeAtIndex:0] position]
                                             ),
                                 6*(1.0-t)
                                 );
    NSPoint beta =GSScalePoint(
                               GSAddPoints(
                                           GSSubtractPoints([[self nodeAtIndex:3] position], GSScalePoint([[self nodeAtIndex:2] position], 2)),
                                           [[self nodeAtIndex:1] position]
                                           ),
                               6*(t)
                               );
    return GSAddPoints(alpha, beta);
}

- (NSPoint)SCPointAtPathTime:(CGFloat)t {
    return GSPointAtTime( [[self nodeAtIndex:0] position],
                  [[self nodeAtIndex:1] position],
                  [[self nodeAtIndex:2] position],
                  [[self nodeAtIndex:3] position], t);
}

@end
