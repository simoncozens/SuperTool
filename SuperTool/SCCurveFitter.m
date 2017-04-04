//
//  SCCurveFitter.m
//  SuperTool
//
//  Created by Simon Cozens on 03/04/2017.
//  Copyright © 2017 Simon Cozens. All rights reserved.
//

#import "SCCurveFitter.h"
#import "SCCurveFitter+Tangents.h"
#define B0(u) ( ( 1.0 - u )  *  ( 1.0 - u )  *  ( 1.0 - u ) )
#define B1(u) ( 3 * u  *  ( 1.0 - u )  *  ( 1.0 - u ) )
#define B2(u) ( 3 * u * u  *  ( 1.0 - u ) )
#define B3(u) ( u * u * u )

//#define DEBUG_MODE

#ifdef DEBUG_MODE
#define SCLog NSLog
#else
#define SCLog( ... )
#endif

boolean_t is_zero(NSPoint t) { return t.x == 0 && t.y == 0; }

@implementation SCCurveFitter
const NSPoint unconstrained_tangent = {.x = 0, .y =0};

+ (GSPath*)fitCurveToPoints:(NSArray*)data withError:(double)error cornerTolerance:(double)corner maxSegments:(double)maxSegments {
    data = [ [[NSOrderedSet alloc] initWithArray:data] array]; // Deduplicate
    if ([data count] < 2) return NULL;
    return [self fitCurveToPoints:data tangent1:unconstrained_tangent tangent2:unconstrained_tangent withError:error cornerTolerance:(double)corner maxSegments:maxSegments ];
}

+ (GSPath*)fitLine:(NSArray*)data tangent1:(NSPoint)tHat1 tangent2:(NSPoint)tHat2 {
    NSPoint p0 = [(GSNode*)[data firstObject] position];
    NSPoint p3 = [(GSNode*)[data lastObject] position];
    double dist = GSDistance(p0,p3) / 3.0;
    NSPoint p1,p2;
    p1 = is_zero(tHat1) ? GSScalePoint(GSAddPoints(GSScalePoint(p0, 2), p3), 1/3.0) :
    GSAddPoints(p0, GSScalePoint(tHat1, dist));
    p2 = is_zero(tHat2) ? GSScalePoint(GSAddPoints(GSScalePoint(p3, 2), p0), 1/3.0) :
    GSAddPoints(p3, GSScalePoint(tHat2, dist));

    GSPath* p = [GSPath initWithp0:p0 p1:p1 p2:p2 p3:p3];
    return p;
}

+ (void) estimateBi:(NSMutableArray*)bez data:(NSArray*)data parameters:(NSArray*)u {
    NSPoint num = NSMakePoint(0,0);
    double den = 0.;
    for (unsigned i = 0; i < [data count]; ++i) {
        double const ui = [u[i] floatValue];
        double const b[4] = { B0(ui), B1(ui), B2(ui), B3(ui) };
        num.x += b[1] * (b[0]  * [bez[0] pointValue].x +
                           b[2] * [bez[2] pointValue].x +
                           b[3]  * [bez[3] pointValue].x +
                           - [(GSNode*)data[i] position].x);
        num.y += b[1] * (b[0]  * [bez[0] pointValue].y +
                     b[2] * [bez[2] pointValue].y +
                     b[3]  * [bez[3] pointValue].y +
                     - [(GSNode*)data[i] position].y);

        den -= b[1] * b[1];
    }
    
    if (den != 0.) {
        SCLog(@"Path number 1, den is %f, num.x = %f, num.y = %f", den, num.x, num.y);
        bez[1] = [NSValue valueWithPoint:NSMakePoint(num.x / den, num.y / den)];
    } else {
        bez[1] = [NSValue valueWithPoint:GSLerp([bez[0] pointValue], [bez[3] pointValue], 1.0/3.0)];
    }
}

+ (GSPath*) generateBezierFromPoints:(NSArray*)data withParameters:(NSArray*)u leftTangent: (NSPoint)tHat1 rightTangent: (NSPoint)tHat2 error:(double) tolerance_sq {
    bool const est1 = is_zero(tHat1);
    bool const est2 = is_zero(tHat2);
    NSPoint est_tHat1 = est1 ? [self leftTangent:data tolerance:tolerance_sq] : tHat1;
    NSPoint est_tHat2 = est2 ? [self rightTangent:data tolerance:tolerance_sq] : tHat2;
    NSMutableArray* bez = [self estimateLengths: data parameters:u left:est_tHat1 right:est_tHat2];
    if (est1) {
        SCLog(@"Refining estimate %@", bez);
        [self estimateBi:bez data:data parameters:u];
        SCLog(@"Resule of estimateBi: %@", bez);
        if (GSSquareDistance([bez[1] pointValue], [bez[0] pointValue]) > FLT_EPSILON) {
            est_tHat1 = GSUnitVector(GSSubtractPoints([bez[1] pointValue], [bez[0] pointValue]));
        }
        SCLog(@"tHat1 is now %@", NSStringFromPoint(est_tHat1));
        bez = [self estimateLengths: data parameters:u left:est_tHat1 right:est_tHat2];
    }
    return [GSPath initWithPointArray:bez];
}

+ (NSMutableArray*)estimateLengths:(NSArray*)data parameters:(NSArray*)uPrime left:(NSPoint)tHat1 right:(NSPoint)tHat2 {
    double C[2][2];   /* Matrix C. */
    double X[2];      /* Matrix X. */
    C[0][0] = 0.0;
    C[0][1] = 0.0;
    C[1][0] = 0.0;
    C[1][1] = 0.0;
    X[0]    = 0.0;
    X[1]    = 0.0;
    NSMutableArray* bez = [[NSMutableArray alloc] init];
    NSPoint start =[(GSNode*)[data firstObject] position];
    NSPoint end = [(GSNode*)[data lastObject] position];
    [bez addObject:[NSValue valueWithPoint:start]];
    [bez addObject:[NSNull null]];
    [bez addObject:[NSNull null]];
    [bez addObject:[NSValue valueWithPoint:end]];
    SCLog(@"tHat1= %@, tHat2= %@",NSStringFromPoint(tHat1), NSStringFromPoint(tHat2));
    for (unsigned i = 0; i < [data count]; i++) {
        double const b0 = B0([uPrime[i] floatValue]);
        double const b1 = B1([uPrime[i] floatValue]);
        double const b2 = B2([uPrime[i] floatValue]);
        double const b3 = B3([uPrime[i] floatValue]);
        NSPoint a1 = GSScalePoint(tHat1, b1);
        NSPoint a2 = GSScalePoint(tHat2, b2);
        C[0][0] += GSDot(a1, a1);
        C[0][1] += GSDot(a1, a2);
        C[1][0] = C[0][1];
        C[1][1] += GSDot(a2, a2);
        NSPoint shortfall = [(GSNode*)data[i] position];
        shortfall = GSSubtractPoints(shortfall, GSScalePoint([bez[0] pointValue], b0+b1));
        shortfall = GSSubtractPoints(shortfall, GSScalePoint([bez[3] pointValue], b2+b3));
        X[0] += GSDot(a1, shortfall);
        X[1] += GSDot(a2, shortfall);
    }
    double alpha_l, alpha_r;
    
    /* Compute the determinants of C and X. */
    double const det_C0_C1 = C[0][0] * C[1][1] - C[1][0] * C[0][1];
    if ( det_C0_C1 != 0 ) {
        /* Apparently Kramer's rule. */
        double const det_C0_X  = C[0][0] * X[1]    - C[0][1] * X[0];
        double const det_X_C1  = X[0]    * C[1][1] - X[1]    * C[0][1];
        alpha_l = det_X_C1 / det_C0_C1;
        alpha_r = det_C0_X / det_C0_C1;
    } else {
        /* The matrix is under-determined.  Try requiring alpha_l == alpha_r.
         *
         * One way of implementing the constraint alpha_l == alpha_r is to treat them as the same
         * variable in the equations.  We can do this by adding the columns of C to form a single
         * column, to be multiplied by alpha to give the column vector X.
         *
         * We try each row in turn.
         */
        double const c0 = C[0][0] + C[0][1];
        if (c0 != 0) {
            alpha_l = alpha_r = X[0] / c0;
        } else {
            double const c1 = C[1][0] + C[1][1];
            if (c1 != 0) {
                alpha_l = alpha_r = X[1] / c1;
            } else {
                /* Let the below code handle this. */
                alpha_l = alpha_r = 0.;
            }
        }
    }
//    if ( alpha_l < 1.0e-6 ||
//        alpha_r < 1.0e-6   )
//    {
        alpha_l = alpha_r = GSDistance(start,end) / 3.0;
//    }
    bez[1] = [NSValue valueWithPoint: GSAddPoints(start, GSScalePoint(tHat1, alpha_l))];
    bez[2] = [NSValue valueWithPoint: GSAddPoints(end, GSScalePoint(tHat2, alpha_r))];
    SCLog(@"alpha_l = %f, alpha_r = %f, bez = %@", alpha_l, alpha_r, bez);
    return bez;
}

+ (NSMutableArray*)chordLengthParameterize:(NSArray*)points {
    NSMutableArray* u = [[NSMutableArray alloc]init];
    [u addObject:@0.0];
    NSUInteger i = 1;
    CGFloat v = 0;
    for (unsigned i = 1; i < [points count]; ++i) {
        v += GSDistance([(GSNode*)points[i] position], [(GSNode*)points[i-1] position]);
        [u addObject:[NSNumber numberWithFloat:v]];
    }
    i = 0;
    for (unsigned i = 1; i < [points count]; ++i) {
        u[i] = [NSNumber numberWithFloat:([u[i] floatValue] / v)];
    }
    u[[u count]-1] = @1.0;
    return u;
}

+ (float)newtonRaphsonFind:(GSPath*)p point:(NSPoint)pt parameter:(float)u {
    NSPoint q0 = [p pointAtPathTime:u];
    NSPoint q1 = [p qPrimeAtTime:u];
    NSPoint q2 = [p qPrimePrimeAtTime:u];
    NSPoint diff = GSSubtractPoints(q0, pt);
    double numerator = GSDot(diff, q1);
    double denominator = GSDot(q1,q1) + GSDot(diff, q2);
    double improvedU;
    if ( denominator > 0. ) {
        improvedU = u - ( numerator / denominator );
    } else {
        if ( numerator > 0. ) {
            improvedU = u * .98 - .01;
        } else if (numerator < 0. ) {
            improvedU = .031 + u * .98;
        } else {
            improvedU = u;
        }
    }
    if (improvedU < 0) { improvedU = 0; }
    if (improvedU > 1) { improvedU = 1; }
        
    /* Ensure that improved_u isn't actually worse. */
    CGFloat dist2 = GSSquareDistance(q0, pt);
    for (double proportion = .125; ; proportion += .125) {
        CGFloat newDistance2 = GSSquareDistance(pt, [p pointAtPathTime:improvedU]);
        if (newDistance2 > dist2) {
            if ( proportion > 1.0 ) { improvedU = u; break; }
            improvedU = ( ( 1 - proportion ) * improvedU  +
                          proportion         * u            );
        } else { break; }
    }
    return improvedU;
}

+ (NSMutableArray*)reparameterize:(GSPath*)path throughPoints:(NSArray*)points originalParameters:(NSArray*)parameters {
    NSMutableArray *result = [[NSMutableArray alloc] init];
    for (int i=0; i < [points count]-1; i++) {
        CGFloat u = [parameters[i] floatValue];
        NSPoint point = [(GSNode*)points[i] position];
        [result addObject:[NSNumber numberWithFloat:[self newtonRaphsonFind:path point:point parameter:u]]];
    }
    [result addObject:@1.0];
    return result;
}

+ (double)computeHookFrom:(NSPoint)prev To:(NSPoint)cur parameter:(CGFloat)u path:(GSPath*)path cornerTolerance:(double)tolerance {
    NSPoint p = [path pointAtPathTime:u];
    CGFloat dist = GSDistance(GSLerp(prev,cur,0.5),p);
    if (dist < tolerance) return 0;
    double const allowed = GSDistance(prev, cur) + tolerance;
    return dist / allowed;
}

+ (double)computeMaxErrorForPath:(GSPath*) path ThroughPoints:(NSArray*)points parameters:(NSMutableArray*)u tolerance:(double)tolerance cornerTolerance:(double)corner returningSplitPoint:(NSUInteger*)splitPoint {
    double maxDistsq = 0.0; /* Maximum error */
    double max_hook_ratio = 0.0;
    unsigned snap_end = 0;
    NSPoint prev = [[path startNode] position];
//    SCLog(@"Computing error for path : %@", [path nodes]);
//    SCLog(@"Parameters : %@", u);
    for (unsigned i = 1; i < [points count]-1; i++) {
//        SCLog(@"Path time is %f", [u[i] floatValue]);
        NSPoint cur = [path SCPointAtPathTime:[u[i] floatValue]];
        double const distsq = GSSquareDistance(cur, [(GSNode*)points[i] position]);
//        SCLog(@"Square distance: %@ - %@ = %f", NSStringFromPoint(cur), NSStringFromPoint([(GSNode*)points[i] position]), distsq);
        if ( distsq > maxDistsq ) {
            maxDistsq = distsq;
            *splitPoint = i;
        }
        double const hook_ratio = [self computeHookFrom:prev To:cur
                                              parameter:.5 * ([u[i - 1] floatValue] + [u[i] floatValue])
                                               path:path cornerTolerance:corner];
        if (max_hook_ratio < hook_ratio) {
            max_hook_ratio = hook_ratio;
            snap_end = i;
        }
        prev = cur;
    }
//    SCLog( @"Distance = %f tolerance = %f", sqrt(maxDistsq), tolerance);

    double const dist_ratio = sqrt(maxDistsq) / tolerance;
    double ret;
    if (max_hook_ratio <= dist_ratio) {
        ret = dist_ratio;
    } else {
        ret = -max_hook_ratio;
        *splitPoint = snap_end - 1;
    }
    NSLog( @"Computed max error = %f split point = %lu", ret, (unsigned long)*splitPoint);
    return ret;
}

+ (GSPath*)fitCurveToPoints:(NSArray*)data tangent1:(NSPoint)tHat1 tangent2:(NSPoint)tHat2 withError:(double)error cornerTolerance:(double)corner maxSegments:(double)maxSegments {
    SCLog(@"Fitting to data: %@", data);
    if ([data count] < 2) return NULL;
    if ([data count] == 2) {
        return [self fitLine:data tangent1:tHat1 tangent2:tHat2];
    }
    
    int const maxIterations = 20;
    bool isCorner = false;
    NSUInteger splitPoint;
    NSMutableArray* u = [self chordLengthParameterize:data];
    if ([[u lastObject] floatValue] == 0.0) return NULL;
    SCLog(@"tHat1:%@ tHat2: %@ error:%f", NSStringFromPoint(tHat1), NSStringFromPoint(tHat2), error);
    SCLog(@"parameters: %@", u);
    GSPath* bez = [self generateBezierFromPoints: data withParameters:u leftTangent: tHat1 rightTangent: tHat2 error: error];
    SCLog(@"Initial path attempt: %@", [bez nodes]);
    u = [self reparameterize:bez throughPoints:data originalParameters:u];
    double const tolerance = sqrt(pow(2,error) + 1e-9);
    corner = sqrt(pow(2,corner));
    CGFloat maxErrorRatio = [self computeMaxErrorForPath:bez ThroughPoints:data parameters:u
                                              tolerance: tolerance cornerTolerance:corner
                                    returningSplitPoint:&splitPoint];
    if ( fabs(maxErrorRatio) <= 1.0 ) { return bez; }
    if ( 0.0 <= maxErrorRatio && maxErrorRatio <= 3.0 ) {
        for (int i = 0; i < maxIterations; i++) {
            bez = [self generateBezierFromPoints: data withParameters:u leftTangent: tHat1 rightTangent: tHat2 error: error];
            u = [self reparameterize:bez throughPoints:data originalParameters:u];
            maxErrorRatio = [self computeMaxErrorForPath:bez ThroughPoints:data parameters:u
                                                      tolerance: tolerance cornerTolerance:corner
                                            returningSplitPoint:&splitPoint];
            if ( fabs(maxErrorRatio) <= 1.0 ) { return bez; }
        }
    }
    isCorner = (maxErrorRatio < 0);
    if (isCorner) {
        if (splitPoint == 0) {
            if (is_zero(tHat1)) {
                ++splitPoint;
            } else {
                return [self fitCurveToPoints:data tangent1:unconstrained_tangent tangent2:tHat2 withError:error cornerTolerance:corner maxSegments:maxSegments];
            }
        } else if (splitPoint == [data count] - 1) {
            if (is_zero(tHat2)) {
                --splitPoint;
            } else {
                return [self fitCurveToPoints:data tangent1:tHat1 tangent2:unconstrained_tangent withError:error cornerTolerance:corner maxSegments:maxSegments];
            }
        }
    }
    
    if (1 < maxSegments) {
        unsigned const rec_max_beziers1 = maxSegments - 1;
        NSPoint recTHat2, recTHat1;
        if (isCorner) {
            if(!(0 < splitPoint && splitPoint < [data count] - 1)) { return NULL; }
            recTHat1 = recTHat2 = unconstrained_tangent;
        } else {
            recTHat2 = [self centerTangent:data center:splitPoint];
            recTHat1 = GSScalePoint(recTHat2, -1);
        }
        NSMutableArray* leftPoints = [[NSMutableArray alloc] init];
        NSMutableArray* rightPoints = [[NSMutableArray alloc] init];
        
        NSUInteger i = 0;
        while (i <= splitPoint) {
            [leftPoints addObject:[data objectAtIndex:i]];
            i++;
        }
        SCLog(@"Left  points: %@", leftPoints);
        GSPath* left = [self fitCurveToPoints:leftPoints tangent1:tHat1 tangent2:recTHat2 withError:error cornerTolerance:corner maxSegments:rec_max_beziers1];
        if (!left) { return NULL; }
        i--;
        while (i < [data count]) {
            [rightPoints addObject:[data objectAtIndex:i]];
            i++;
        }
        SCLog(@"Right points: %@", rightPoints);
        unsigned const rec_max_beziers2 = maxSegments - [left countOfNodes];
        GSPath* right = [self fitCurveToPoints:rightPoints tangent1:recTHat1 tangent2:tHat2 withError:error cornerTolerance:corner  maxSegments:rec_max_beziers2];
        SCLog(@"Left  curve: %@", [left nodes]);

        [left removeNodeAtIndex:([left countOfNodes]-1)];
        SCLog(@"Right  curve: %@", [right nodes]);
        [left append:right];
        SCLog(@"Final  curve: %@", [left nodes]);
        return left;
    }
    return NULL;
}

@end
