//
//  SuperTool+Simplify.m
//  SuperTool
//
//  Created by Simon Cozens on 26/05/2016.
//  Copyright © 2016 Simon Cozens. All rights reserved.
//

#import "SuperTool+Simplify.h"
#import "SuperTool+Harmonize.h"

@implementation SuperTool (Simplify)

// Ensure selection array contains [s,e]
- (void) addToSelectionSegmentStarting:(GSNode*)s Ending:(GSNode*)e {
    NSMutableArray *a;
    for (a in simplifySegSet) {
        // Are s e already in the array? Go home
        if ([a containsObject:s] && [a containsObject:e]) { return; }
        // Is s the last member of any array? Add e after it.
        if ([a lastObject] == s) {
            [a addObject:e];
            return;
        }
        // Is e the first member of any array? Add s before it.
        if ([a firstObject] == e) {
            [a insertObject:s atIndex:0];
            return;
        }
    }
    // Create a new entry for [s,e]
    NSMutableArray *holder = [[NSMutableArray alloc]initWithObjects:(GSNode*)s,e, nil];
    [simplifySegSet addObject: holder];
}

- (void) showSimplifyWindow {
    // Capture current seg selection
    // A segment is selected if its start and end nodes are selected.
    GSLayer* currentLayer = [_editViewController.graphicView activeLayer];
    NSMutableOrderedSet* sel = [currentLayer selection];
    [simplifySegSet removeAllObjects];
    [simplifySpliceSet removeAllObjects];
    [originalPaths removeAllObjects];
    [copiedPaths removeAllObjects];
    [simplifyPathSet removeAllObjects];
    GSNode *n, *nn;
    NSMutableArray *mySelection = [[NSMutableArray alloc] init];
    for (n in sel) {
        if (![n isKindOfClass:[GSNode class]]) continue;
        if ([n type] == OFFCURVE) continue;
        GSPath* rerootedPath;
        GSPath* origPath = [n parent];
        GSLayer* layer = [origPath parent];
        SCLog(@"Looking for %@ in %@", origPath, copiedPaths);
        NSNumber* pindex = [NSNumber numberWithLong:[layer indexOfPath:origPath]];
        rerootedPath = [copiedPaths objectForKey:pindex];
        if (!rerootedPath) {
            rerootedPath = [[n parent] copy];
            [copiedPaths setObject:rerootedPath forKey:pindex];
            SCLog(@"Cloned %@ to %@", [n parent], rerootedPath);
        }
        GSNode* rerootedNode = [rerootedPath nodeAtIndex:[[n parent] indexOfNode:n]];
        [mySelection addObject:rerootedNode];
        NSValue* rerootedNodeKey = [NSValue valueWithNonretainedObject:rerootedNode];
        [originalPaths setObject:[n parent] forKey:rerootedNodeKey];
        SCLog(@"Associated %@ with %@, dictionary is now %@", [n parent], rerootedNode, originalPaths);
        
    }
    SCLog(@"Sorting selection %@", mySelection);
    [mySelection sortUsingComparator:^ NSComparisonResult(GSNode* a, GSNode*b) {
        GSPath *p = [a parent];
        if (p != [b parent]) {
            GSLayer *l = [p parent];
            return [l indexOfPath:p] < [l indexOfPath:[b parent]] ? NSOrderedAscending : NSOrderedDescending;
        }
        return ([p indexOfNode:a] < [p indexOfNode:b]) ? NSOrderedAscending : NSOrderedDescending;
    }];
    SCLog(@"Selection is now %@", mySelection);
    for (n in mySelection) {
        nn = [n nextOnCurve];
        if ([[nn parent] indexOfNode:nn] < [[n parent] indexOfNode:n]) {
            continue;
        }
                SCLog(@"Considering %@ (parent: %@, index %i), next-on-curve: %@", n, [n parent],[[n parent] indexOfNode:n], nn);
        if ([mySelection containsObject:nn]) {
            [self addToSelectionSegmentStarting:n Ending:nn];
                        SCLog(@"Added %@ -> %@ (next), Selection set is %@", n, nn, simplifySegSet);
        }
    }
    NSMutableArray *a;
    for (a in simplifySegSet) {
        GSNode *b = [a firstObject];
        GSNode *e = [a lastObject];
        SCLog(@"Fixing seg set to splice set: %@, %@ (parents: %@, %@)", b, e, [b parent], [e parent]);
        NSUInteger bIndex = [[b parent] indexOfNode:b];
        NSUInteger eIndex = [[e parent] indexOfNode:e];
        NSRange range = NSMakeRange(bIndex, eIndex-bIndex);
        [simplifySpliceSet addObject:[NSValue valueWithRange:range]];
        // Here we must add the original parent
        SCLog(@"Added range %lu, %lu", (unsigned long)bIndex, (unsigned long)eIndex);
        
        GSPath * originalPath = [originalPaths objectForKey:[NSValue valueWithNonretainedObject:b]];
        if (!originalPath) {
            SCLog(@"I didn't find the original path for %@ in the %@!", b, originalPaths);
            return;
        }
        [simplifyPathSet addObject:originalPath];
    }
    
    //    SCLog(@"Splice set is %@", simplifySpliceSet);
    SCLog(@"Path set is %@", simplifyPathSet);
    [[currentLayer undoManager] beginUndoGrouping];
    
    [simplifyWindow makeKeyAndOrderFront:nil];
    [self doSimplify];
}

- (void) doSimplify {
    CGFloat reducePercentage = [simplifySlider floatValue];
    int i = 0;
    //    SCLog(@"Seg set is %@", simplifySegSet);
    //    SCLog(@"copied paths is %@", copiedPaths);
    //    SCLog(@"original paths is %@", originalPaths);
    while (i <= [simplifySegSet count]-1) {
        NSMutableArray* s = simplifySegSet[i];
        GSPath* p = simplifyPathSet[i];
        NSRange startEnd = [simplifySpliceSet[i] rangeValue];
        SCLog(@"Must reduce %@ (%li, %f)", s, (unsigned long)[s count], reducePercentage);
        
        if ([[s firstObject] parent]) {
            SCLog(@"ALERT! Parent of %@ is %@", [s firstObject], [[s firstObject]parent]);
        } else {
            SCLog(@"Parent dead before simplifying!");
            return;
        }
        GSPath *newPath = [SuperTool SCfitCurvetoOrigiPoints:s precision:reducePercentage];
        //        [newPath addExtremes:TRUE];
        NSUInteger newend = [self splice:newPath into:p at:startEnd];
        SCLog(@"New end is %lu",(unsigned long)newend );
        simplifySpliceSet[i] = [NSValue valueWithRange:NSMakeRange(startEnd.location, newend)];
        if (![[s firstObject] parent]) {
            SCLog(@"ALERT! Parent dead after simplifying!");
        }
        //        NSUInteger j = startEnd.location;
        //        while (j <= startEnd.location+newend) {
        //            [self harmonize:[p nodeAtIndex:j++]];
        //        }
        SCLog(@"Simplify splice set = %@", simplifySpliceSet);
        i++;
    }
}

- (NSUInteger)splice:(GSPath*)newPath into:(GSPath*)path at:(NSRange)splice {
    GSNode* n;
    SCLog(@"Splicing into path %@, at range %lu-%lu", path, (unsigned long)splice.location, (unsigned long)NSMaxRange(splice));
    long j = NSMaxRange(splice);
    while (j >= 0 && j >= splice.location) {
        [path removeNodeAtIndex:j];
        j--;
    }
    for (n in [newPath nodes]) {
        GSNode *n2 = [n copy];
        [path insertNode:n2 atIndex:++j];
    }
    splice.length =  [newPath countOfNodes] -1;
    j = splice.location;
    while (j - splice.location < splice.length ) {
        [[path nodeAtIndex:j] correct];
//        [self harmonize:[path nodeAtIndex:j]];
        j++;
    }
    if ([path startNode] && [[path startNode] type] == CURVE) {
        [path startNode].type = LINE;
    }
    if ([path endNode] && [[path endNode] type] == CURVE) {
        [path endNode].type = LINE;
    }
    if ([[[path nodeAtIndex:j] nextNode] type] != OFFCURVE) {
        [path nodeAtIndex:j].type = LINE;
    }
    if ([[[path nodeAtIndex:splice.location] prevNode] type] != OFFCURVE) {
        [path nodeAtIndex:splice.location].type = LINE;
    }
    
    return [newPath countOfNodes] -1;
}

+(void)addOffcurve:(NSPoint)pos toPath:(GSPath*)p {
    GSNode *n = [[GSNode alloc] init];
    n.position = pos;
    n.type = OFFCURVE;
    [p addNode: n];
}
+(void)addSmooth:(NSPoint)pos toPath:(GSPath*)p {
    GSNode *n = [[GSNode alloc] init];
    n.position = pos;
    n.type = CURVE; n.connection = SMOOTH;
    [p addNode: n];
}

+ (GSPath*)SCfitCurvetoOrigiPoints:(NSMutableArray*)points precision:(CGFloat)precision {
    NSUInteger pcount = [points count];
    NSPoint leftTangent = GSUnitVector(GSSubtractPoints([(GSNode*)points[1] position], [(GSNode*)points[0] position] ));
    NSPoint rightTangent = GSUnitVector(GSSubtractPoints([(GSNode*)points[pcount-2] position], [(GSNode*)points[pcount-1] position]));
    NSRect pointBounds = [self boundsOfPoints:points];
    precision = sqrt((NSHeight(pointBounds)+NSWidth(pointBounds)) /precision);

    return [self fitCurveThrough:points leftTangent:leftTangent rightTangent:rightTangent precision:precision];
}

+ (NSRect) boundsOfPoints:(NSArray*)points {
    NSPoint bl = NSMakePoint(MAXFLOAT, MAXFLOAT);
    NSPoint tr = NSMakePoint(-MAXFLOAT, -MAXFLOAT);
    NSPoint p;
    for (GSNode *n in points) {
        p = [n position];
        if (p.x > tr.x) tr.x = p.x;
        if (p.y > tr.y) tr.y = p.y;
        if (p.x < bl.x) bl.x = p.x;
        if (p.y < bl.y) bl.y = p.y;
    }
    return GSRectFromTwoPoints(bl,tr);
}

+ (GSPath*)fitCurveThrough:(NSMutableArray*)points leftTangent:(NSPoint)leftTangent rightTangent:(NSPoint)rightTangent precision:(CGFloat)precision {
    NSPoint start = [(GSNode*)points[0] position];
    NSPoint end = [(GSNode*)[points lastObject] position];
    CGFloat dist = GSDistance(start, end);
    NSUInteger pcount = [points count];
    if (pcount ==2) {
        GSPath* p = [[GSPath alloc] init];
        // Approximate
        [self addSmooth:start toPath:p];
        [self addOffcurve:GSAddPoints(start, GSScalePoint(leftTangent, dist / 3.0)) toPath:p];
        [self addOffcurve:GSAddPoints(end, GSScalePoint(rightTangent, dist / 3.0)) toPath:p];
        [self addSmooth:end toPath:p];
        return p;
    }
    NSUInteger splitPoint = 0;
    NSMutableArray *u = [self chordLengthParameterize:points];
    
    for (int i =0; i <=20 ; i++) {
        SCLog(@"Attempt %i, parameters are: %@", i, u);
        GSPath* bezCurve = [self generateBezier:points parameters:u leftTangent:leftTangent rightTangent:rightTangent];
        SCLog(@"Attempt %i, got bezier: %@", i, [bezCurve nodes]);
        
        CGFloat maxError = [self computeMaxErrorForPath:bezCurve ThroughPoints:points parameters:u returningSplitPoint:&splitPoint];
        SCLog(@"Maxerror = %f, precision = %f", maxError, precision);
        if (maxError < precision)
            return bezCurve;
        u = [self reparameterize:bezCurve throughPoints:points originalParameters:u];
        if (i > 0 && maxError > precision * precision) break;
        
    }
    SCLog(@"Trying to split");
    GSPath *p = [[GSPath alloc] init];
    NSPoint centerTangent = GSUnitVector(GSSubtractPoints([(GSNode*)points[splitPoint-1] position], [(GSNode*)points[splitPoint+1] position]));
    NSMutableArray* leftPoints = [[NSMutableArray alloc] init];
    NSMutableArray* rightPoints = [[NSMutableArray alloc] init];
    
    NSUInteger i = 0;
    SCLog(@"Split point is %lu", (unsigned long)splitPoint);
    while (i <= splitPoint) {
        [leftPoints addObject:[points objectAtIndex:i]];
        i++;
    }
    SCLog(@"Left points are %@", leftPoints);
    [self appendCurve:
     [self fitCurveThrough:leftPoints leftTangent:leftTangent rightTangent:centerTangent precision:precision]
               toPath:p];
    i--;
    while (i < [points count]) {
        [rightPoints addObject:[points objectAtIndex:i]];
        i++;
    }
    SCLog(@"Right points are %@", rightPoints);
    [p removeNodeAtIndex:([p countOfNodes]-1)];
    [self appendCurve:
     [self fitCurveThrough:rightPoints leftTangent:GSScalePoint(centerTangent, -1.0) rightTangent:rightTangent precision:precision]
               toPath:p];
    SCLog(@"Final path is %@", [p nodes]);
    return p;
}

+ (GSPath*)generateBezier:(NSMutableArray*)points parameters:(NSMutableArray*)parameters  leftTangent:(NSPoint)leftTangent rightTangent:(NSPoint)rightTangent {
    // A is an array of pairs of NSPoints, same length as parameters.
    NSMutableArray *a = [[NSMutableArray alloc]init];
    for (NSNumber *n in parameters) {
        CGFloat u = [n floatValue];
        NSArray *vector = [[NSArray alloc]initWithObjects:
                           [NSValue valueWithPoint:GSScalePoint(leftTangent, 3*(1-u)*(1-u) * u)],
                           [NSValue valueWithPoint:GSScalePoint(rightTangent, 3*(1-u)*u * u)],
                           nil];
        [a addObject:vector];
    }
    SCLog(@"A is %@",a);
    CGFloat c00 = 0, c01 = 0, c10 = 0, c11 = 0;
    CGFloat x0, x1;
    int i =0;
    
    while (i <= [parameters count]-1) {
        c00 += GSDot([a[i][0] pointValue], [a[i][0] pointValue]);
        c01 += GSDot([a[i][0] pointValue], [a[i][1] pointValue]);
        c10 += GSDot([a[i][0] pointValue], [a[i][1] pointValue]);
        c11 += GSDot([a[i][1] pointValue], [a[i][1] pointValue]);
        CGFloat u = [parameters[i] floatValue];
        NSPoint p = GSSubtractPoints([(GSNode*)points[i] position],
                                     GSPointAtTime([(GSNode*)points[0] position],[(GSNode*)points[0] position],[(GSNode*)[points lastObject] position],[(GSNode*)[points lastObject] position], u));
        SCLog(@"P is %f,%f", p.x,p.y);
        x0 += GSDot([a[i][0] pointValue], p);
        x1 += GSDot([a[i][1] pointValue], p);
        i++;
    }
    
    SCLog(@"C is [[ %f,%f],[%f,%f]]", c00, c01, c10, c11);
    SCLog(@"X is %f, %f", x0,x1);
    CGFloat det_C0_C1 = c00 * c11 - c10 * c01;
    CGFloat det_C0_X  = c00 * x1 - c10 * x0;
    CGFloat det_X_C1  = x0 * c11 - x1*c01;
    CGFloat alphaL = fabs(det_C0_C1) <= FLT_EPSILON ? 0 : det_X_C1 / det_C0_C1;
    CGFloat alphaR = fabs(det_C0_C1) <= FLT_EPSILON ? 0 : det_C0_X / det_C0_C1;
    SCLog(@"alphaL = %f, alphaR = %f", alphaL, alphaR);
    NSPoint start = [(GSNode*)points[0] position];
    NSPoint end = [(GSNode*)[points lastObject] position];
    CGFloat dist = GSDistance(start, end);
    
    CGFloat epsilon = 1.0e-6 * dist;
    GSPath* p = [[GSPath alloc] init];
    // Approximate
    [self addSmooth:start toPath:p];
    SCLog(@"right Tangent = %f,%f",  rightTangent.x, rightTangent.y);
    
    if (alphaL < epsilon || alphaR < epsilon) {
        [self addOffcurve:GSAddPoints(start, GSScalePoint(leftTangent, dist / 3.0)) toPath:p];
        [self addOffcurve:GSAddPoints(end, GSScalePoint(rightTangent, dist / 3.0)) toPath:p];
    } else {
        [self addOffcurve:GSAddPoints(start, GSScalePoint(leftTangent, alphaL)) toPath:p];
        [self addOffcurve:GSAddPoints(end, GSScalePoint(rightTangent, alphaR)) toPath:p];
    }
    [self addSmooth:end toPath:p];
    return p;
}

+ (CGFloat)computeMaxErrorForPath:(GSPath*) path ThroughPoints:(NSMutableArray*)points parameters:(NSMutableArray*)parameters returningSplitPoint:(NSUInteger*)splitPoint {
    CGFloat maxDist = 0.0;
    *splitPoint = [path countOfNodes] / 2;
    NSUInteger i =0;
    while (i < [points count]) {
//        CGFloat dist = GSSquareDistance([(GSNode*)points[i] position], GSPointAtTime(
//                                                                                     [[path nodeAtIndex:0] position],
//                                                                                     [[path nodeAtIndex:1] position],
//                                                                                     [[path nodeAtIndex:2] position],
//                                                                                     [[path nodeAtIndex:3] position],
//                                                                                     [parameters[i] floatValue]));
        CGFloat dist = GSDistanceOfPointFromCurve([(GSNode*)points[i] position],
                                                  [[path nodeAtIndex:0]position],
                                                  [[path nodeAtIndex:1]position],
                                                  [[path nodeAtIndex:2]position],
                                                  [[path nodeAtIndex:3]position]);
        dist = dist * dist;

        if (dist > maxDist) {
            maxDist = dist;
            *splitPoint = i;
        }
        i++;
    }
    SCLog(@"Furthest point between curve %@ and points %@ is %f", [path nodes], points, maxDist);
    return maxDist;
}

+ (NSMutableArray*)chordLengthParameterize:(NSMutableArray*)points {
    NSMutableArray* u = [[NSMutableArray alloc]init];
    [u addObject:@0.0];
    NSUInteger i = 1;
    while (i < [points count]) {
        CGFloat v = [u[i==0? [u count]-1 : i-1] floatValue];
        v += GSDistance([(GSNode*)points[i] position], [(GSNode*)points[i==0? [u count]-1 : i-1] position]);
        [u addObject:[NSNumber numberWithFloat:v]];
        i++;
    }
    i = 0;
    while (i < [u count]) {
        u[i] = [NSNumber numberWithFloat:([u[i] floatValue] / [u[[u count]-1] floatValue])];
        i++;
    }
    return u;
}

- (void)dismissSimplify {
    [simplifyWindow close];
}

- (void)windowWillClose:(NSNotification *)notification {
    if ([notification object] == simplifyWindow) {
        GSLayer* currentLayer = [_editViewController.graphicView activeLayer];
        [[currentLayer undoManager] endUndoGrouping];
    }
}

- (void)windowDidResignKey:(NSNotification *)notification {
    if ([notification object] == simplifyWindow) [simplifyWindow close];
}
+ (NSPoint)qPrime:(GSPath*)bez atTime:(CGFloat)t {
    return GSAddPoints(
                       GSAddPoints(
                                   GSScalePoint(
                                                GSSubtractPoints([[bez nodeAtIndex:1] position], [[bez nodeAtIndex:0] position]),
                                                3*(1.0-t)*(1.0-t)
                                                ),
                                   GSScalePoint(
                                                GSSubtractPoints([[bez nodeAtIndex:2] position], [[bez nodeAtIndex:1] position]),
                                                6*(1.0-t) * t
                                                )
                                   ),
                       GSScalePoint(
                                    GSSubtractPoints([[bez nodeAtIndex:3] position], [[bez nodeAtIndex:2] position]),
                                    3 * t * t
                                    )
                       );
}

+ (NSPoint)qPrimePrime:(GSPath*)bez atTime:(CGFloat)t {
    NSPoint alpha = GSScalePoint(
                                 GSAddPoints(
                                             GSSubtractPoints([[bez nodeAtIndex:2] position], GSScalePoint([[bez nodeAtIndex:1] position], 2)),
                                             [[bez nodeAtIndex:0] position]
                                             ),
                                 6*(1.0-t)
                                 );
    NSPoint beta =GSScalePoint(
                               GSAddPoints(
                                           GSSubtractPoints([[bez nodeAtIndex:3] position], GSScalePoint([[bez nodeAtIndex:2] position], 2)),
                                           [[bez nodeAtIndex:1] position]
                                           ),
                               6*(t)
                               );
    return GSAddPoints(alpha, beta);
}

static inline NSPoint SCMultiply(NSPoint P1, NSPoint P2) {
    return NSMakePoint(P1.x * P2.x, P1.y*P2.y);
}
static inline CGFloat SCSum(NSPoint P1) {
    return P1.x + P1.y;
}

+ (void)appendCurve:(GSPath*)source toPath:(GSPath*)target {
    [target addNodes:[source nodes]];
}

+ (NSMutableArray*)reparameterize:(GSPath*)path throughPoints:(NSMutableArray*)points originalParameters:(NSMutableArray*)parameters {
    NSMutableArray *result = [[NSMutableArray alloc] init];
    for (int i=0; i < [points count]; i++) {
        CGFloat u = [parameters[i] floatValue];
        NSPoint point = [(GSNode*)points[i] position];
        NSPoint d = GSSubtractPoints(GSPointAtTime( [[path nodeAtIndex:0] position],
                                                   [[path nodeAtIndex:1] position],
                                                   [[path nodeAtIndex:2] position],
                                                   [[path nodeAtIndex:3] position],
                                                   u), point);
        NSPoint qPrime = [self qPrime:path atTime:u];
        CGFloat numerator = SCSum(SCMultiply(d,qPrime));
        CGFloat denominator = SCSum(
                                    GSAddPoints(SCMultiply(qPrime, qPrime), SCMultiply(d, [self qPrimePrime:path atTime:u]))
                                    );
        if (fabs(denominator) <= FLT_EPSILON) {
            [result addObject:[NSNumber numberWithFloat:u]];
        } else {
            [result addObject:[NSNumber numberWithFloat:u-(numerator/denominator)]];
        }
    }
    return result;
}
@end
