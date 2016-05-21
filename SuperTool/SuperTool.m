//
//  SuperTool.m
//  SuperTool
//
//  Created by Simon Cozens on 21/04/2016.
//    Copyright © 2016 Simon Cozens. All rights reserved.
//

#import "SuperTool.h"
#import "SuperTool+TunniEditing.h"
#import "SuperTool+Curvature.h"
#import "SuperTool+Harmonize.h"

@implementation SuperTool

const int SAMPLE_SIZE = 200;

- (id)init {
	self = [super init];
    NSArray *arrayOfStuff;
	NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];
	if (thisBundle) {
		// The toolbar icon:
		_toolBarIcon = [[NSImage alloc] initWithContentsOfFile:[thisBundle pathForImageResource:@"ToolbarIconTemplate"]];
		[_toolBarIcon setTemplate:YES];
	}

    [self initTunni];
    [self initCurvature];
    
    simplifySegSet = [[NSMutableArray alloc] init];
    simplifySpliceSet = [[NSMutableArray alloc] init];
    simplifyPathSet = [[NSMutableArray alloc] init];
    copiedPaths = [[NSMutableDictionary alloc] init];
    originalPaths = [[NSMutableDictionary alloc] init];

    [thisBundle loadNibNamed:@"SimplifyInterface" owner:self topLevelObjects:&arrayOfStuff];
    NSUInteger viewIndex = [arrayOfStuff indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        return [obj isKindOfClass:[NSWindow class]];
    }];
    
    simplifyWindow = [arrayOfStuff objectAtIndex:viewIndex];
    [simplifySlider setTarget:self];
    [simplifyWindow setDelegate:self];
    [simplifySlider setAction:@selector(doSimplify)];
    [simplifyDismiss setTarget: self];
    [simplifyDismiss setAction:@selector(dismissSimplify)];
    
    return self;
}

- (NSUInteger)interfaceVersion {
	// Distinguishes the API verison the plugin was built for. Return 1.
	return 1;
}

- (NSUInteger)groupID {
	// Return a number between 50 and 1000 to position the icon in the toolbar.
	return 99;
}

- (NSString *)trigger {
    return @"u";
}

- (NSString *)title {
	// return the name of the tool as it will appear in the tooltip of in the toolbar.
	return @"SuperTool";
}

- (BOOL)willSelectTempTool:(id)tempTool {
    if ([[[tempTool class] description] isEqualToString:@"GlyphsToolSelect"]) return NO;
    return YES;
}

- (NSMenu *)defaultContextMenu {
	// Adds items to the context menu.
    NSMenu *theMenu = [super defaultContextMenu];
    [self addCurvatureToContextMenu:theMenu];
    [self addTunniToContextMenu:theMenu];
    [theMenu insertItem:[NSMenuItem separatorItem] atIndex:2];

    return theMenu;
}

- (void)addMenuItemsForEvent:(NSEvent *)theEvent toMenu:(NSMenu *)theMenu {
    [super addMenuItemsForEvent:theEvent toMenu:theMenu];

    [theMenu insertItem:[NSMenuItem separatorItem] atIndex:0];
    [self addHarmonizeItemToMenu:theMenu];
    if ([self multipleSegmentsSelected]) {
        [theMenu insertItemWithTitle:@"Simplify..." action:@selector(showSimplifyWindow) keyEquivalent:@"" atIndex:0];
    }
    if ([self anyCurvesSelected]) {
        [theMenu insertItemWithTitle:@"Balance" action:@selector(balance) keyEquivalent:@"" atIndex:0];
    }
}

- (BOOL) multipleSegmentsSelected {
    GSLayer* currentLayer = [_editViewController.graphicView activeLayer];
    GSNode* n;
    NSOrderedSet* sel = [currentLayer selection];
    for (n in sel) {
        if ([n type] != OFFCURVE) {
            if ([sel containsObject:[n nextOnCurve]]) return TRUE;
            if ([sel containsObject:[n prevOnCurve]]) return TRUE;
        }
    }
    return FALSE;
}

- (BOOL) anyCurvesSelected {
    GSLayer* currentLayer = [_editViewController.graphicView activeLayer];
    GSNode* n;
    for (n in [currentLayer selection]) {
        if ([n type] == OFFCURVE && [[n nextNode] type] == OFFCURVE) {
            return TRUE;
        } else if ([n type] == OFFCURVE && [[n prevNode] type] == OFFCURVE) {
            return TRUE;
        }
    }
    return FALSE;
}

- (void)iterateOnCurvedSegmentsOfLayer:(GSLayer*)l withBlock:(void (^)(NSArray*seg))handler {
    GSPath *p;
    for (p in l.paths) {
        NSArray* seg;
        for (seg in p.segments) {
            if ([seg count] == 4) {
                handler(seg);
            }
        }
    }
}

- (void)drawForegroundForLayer:(GSLayer *)layer {
    if ([simplifyWindow isKeyWindow]) {
        
        for (GSPath *p in [copiedPaths allValues]) {
            NSBezierPath* bez = [p bezierPath];
            [[NSColor colorWithCalibratedRed:0.2 green:0.2 blue:0.2 alpha:0.8] set];
            [bez setLineWidth:0];
            CGFloat dash[2] = {1.0,1.0};
            [bez setLineDash:dash count:2 phase:0];
            [bez stroke];
        }
    }
}

- (void)drawBackgroundForLayer:(GSLayer*)Layer {
    [self drawTunniBackground:Layer];
    [self drawCurvatureBackground:Layer];
}

#pragma mark Simplify
/*! @methodgroup Simplify */
/*! @name Simplify */

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
        if ([n type] == OFFCURVE) continue;
        GSPath* rerootedPath;
        GSPath* origPath = [n parent];
        GSLayer* layer = [origPath parent];
        NSLog(@"Looking for %@ in %@", origPath, copiedPaths);
        NSNumber* pindex = [NSNumber numberWithLong:[layer indexOfPath:origPath]];
        rerootedPath = [copiedPaths objectForKey:pindex];
        if (!rerootedPath) {
            rerootedPath = [[n parent] copy];
            [copiedPaths setObject:rerootedPath forKey:pindex];
            NSLog(@"Cloned %@ to %@", [n parent], rerootedPath);
        }
        GSNode* rerootedNode = [rerootedPath nodeAtIndex:[[n parent] indexOfNode:n]];
        [mySelection addObject:rerootedNode];
        NSValue* rerootedNodeKey = [NSValue valueWithNonretainedObject:rerootedNode];
        [originalPaths setObject:[n parent] forKey:rerootedNodeKey];
        NSLog(@"Associated %@ with %@, dictionary is now %@", [n parent], rerootedNode, originalPaths);

    }
    NSLog(@"Sorting selection %@", mySelection);
    [mySelection sortUsingComparator:^ NSComparisonResult(GSNode* a, GSNode*b) {
        GSPath *p = [a parent];
        if (p != [b parent]) {
            GSLayer *l = [p parent];
            return [l indexOfPath:p] < [l indexOfPath:[b parent]] ? NSOrderedAscending : NSOrderedDescending;
        }
        return ([p indexOfNode:a] < [p indexOfNode:b]) ? NSOrderedAscending : NSOrderedDescending;
    }];
    NSLog(@"Selection is now %@", mySelection);
    for (n in mySelection) {
        nn = [n nextOnCurve];
//        NSLog(@"Considering %@ (parent: %@, index %i), next-on-curve: %@", n, [n parent],[[n parent] indexOfNode:n], nn);
        if ([mySelection containsObject:nn]) {
            [self addToSelectionSegmentStarting:n Ending:nn];
//            NSLog(@"Added %@ -> %@ (next), Selection set is %@", n, nn, simplifySegSet);
        }
    }
    NSMutableArray *a;
    for (a in simplifySegSet) {
        GSNode *b = [a firstObject];
        GSNode *e = [a lastObject];
        NSLog(@"Fixing seg set to splice set: %@, %@ (parents: %@, %@)", b, e, [b parent], [e parent]);
        NSUInteger bIndex = [[b parent] indexOfNode:b];
        NSUInteger eIndex = [[e parent] indexOfNode:e];
        NSRange range = NSMakeRange(bIndex, eIndex-bIndex);
        [simplifySpliceSet addObject:[NSValue valueWithRange:range]];
        // Here we must add the original parent
        NSLog(@"Added range %u, %u", bIndex, eIndex);

        GSPath * originalPath = [originalPaths objectForKey:[NSValue valueWithNonretainedObject:b]];
        if (!originalPath) {
            NSLog(@"I didn't find the original path for %@ in the %@!", b, originalPaths);
            return;
        }
        [simplifyPathSet addObject:originalPath];
    }
    
//    NSLog(@"Splice set is %@", simplifySpliceSet);
    NSLog(@"Path set is %@", simplifyPathSet);
    [[currentLayer undoManager] beginUndoGrouping];

    [simplifyWindow makeKeyAndOrderFront:nil];
    [self doSimplify];
}

- (void) doSimplify {
    CGFloat reducePercentage = [simplifySlider maxValue] - [simplifySlider floatValue] + [simplifySlider minValue];
    int i = 0;
//    NSLog(@"Seg set is %@", simplifySegSet);
//    NSLog(@"copied paths is %@", copiedPaths);
//    NSLog(@"original paths is %@", originalPaths);
    while (i <= [simplifySegSet count]-1) {
        NSMutableArray* s = simplifySegSet[i];
        GSPath* p = simplifyPathSet[i];
        NSRange startEnd = [simplifySpliceSet[i] rangeValue];
        NSLog(@"Must reduce %@ (%li, %f)", s, (unsigned long)[s count], reducePercentage);

        if ([[s firstObject] parent]) {
            NSLog(@"ALERT! Parent of %@ is %@", [s firstObject], [[s firstObject]parent]);
        } else {
            NSLog(@"Parent dead before simplifying!");
            return;
        }
        GSPath *newPath = [SuperTool SCfitCurvetoOrigiPoints:s precision:reducePercentage];
//        [newPath addExtremes:TRUE];
        NSUInteger newend = [self splice:newPath into:p at:startEnd];
        NSLog(@"New end is %i",newend );
        simplifySpliceSet[i] = [NSValue valueWithRange:NSMakeRange(startEnd.location, newend)];
        if (![[s firstObject] parent]) {
            NSLog(@"ALERT! Parent dead after simplifying!");
        }
//        NSUInteger j = startEnd.location;
//        while (j <= startEnd.location+newend) {
//            [self harmonize:[p nodeAtIndex:j++]];
//        }
        NSLog(@"Simplify splice set = %@", simplifySpliceSet);
        i++;
    }
}

- (NSUInteger)splice:(GSPath*)newPath into:(GSPath*)path at:(NSRange)splice {
    GSNode* n;
    NSLog(@"Splicing into path %@, at range %i-%i", path, splice.location, NSMaxRange(splice));
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
        [self harmonize:[path nodeAtIndex:j]];
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

    return [self fitCurveThrough:points leftTangent:leftTangent rightTangent:rightTangent precision:precision];
}

+ (GSPath*)fitCurveThrough:(NSMutableArray*)points leftTangent:(NSPoint)leftTangent rightTangent:(NSPoint)rightTangent precision:(CGFloat)precision {
    NSPoint start = [(GSNode*)points[0] position];
    NSPoint end = [(GSNode*)[points lastObject] position];
    CGFloat dist = GSDistance(start, end);
    precision = sqrt(precision) / 2;
    NSUInteger pcount = [points count];
    NSLog(@"696: %@", points[0]);

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
        NSLog(@"Attempt %i, parameters are: %@", i, u);
        GSPath* bezCurve = [self generateBezier:points parameters:u leftTangent:leftTangent rightTangent:rightTangent];
        NSLog(@"Attempt %i, got bezier: %@", i, [bezCurve nodes]);

        CGFloat maxError = [self computeMaxErrorForPath:bezCurve ThroughPoints:points parameters:u returningSplitPoint:&splitPoint];
        NSLog(@"Maxerror = %f, precision = %f", maxError, precision);
        if (maxError < precision)
            return bezCurve;
        u = [self reparameterize:bezCurve throughPoints:points originalParameters:u];
        if (i > 0 && maxError > precision * precision) break;

    }
    NSLog(@"Trying to split");
    GSPath *p = [[GSPath alloc] init];
    NSPoint centerTangent = GSUnitVector(GSSubtractPoints([(GSNode*)points[splitPoint-1] position], [(GSNode*)points[splitPoint+1] position]));
    NSMutableArray* leftPoints = [[NSMutableArray alloc] init];
    NSMutableArray* rightPoints = [[NSMutableArray alloc] init];

    NSUInteger i = 0;
    NSLog(@"Split point is %i", splitPoint);
    while (i <= splitPoint) {
        [leftPoints addObject:[points objectAtIndex:i]];
        i++;
    }
    NSLog(@"Left points are %@", leftPoints);
    [self appendCurve:
         [self fitCurveThrough:leftPoints leftTangent:leftTangent rightTangent:centerTangent precision:precision]
           toPath:p];
    i--;
    while (i < [points count]) {
        [rightPoints addObject:[points objectAtIndex:i]];
        i++;
    }
    NSLog(@"Right points are %@", rightPoints);
    [p removeNodeAtIndex:([p countOfNodes]-1)];
    [self appendCurve:
     [self fitCurveThrough:rightPoints leftTangent:GSScalePoint(centerTangent, -1.0) rightTangent:rightTangent precision:precision]
               toPath:p];
    NSLog(@"Final path is %@", [p nodes]);
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
    NSLog(@"A is %@",a);
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
        NSLog(@"P is %f,%f", p.x,p.y);
        x0 += GSDot([a[i][0] pointValue], p);
        x1 += GSDot([a[i][1] pointValue], p);
        i++;
    }
    
    NSLog(@"C is [[ %f,%f],[%f,%f]]", c00, c01, c10, c11);
    NSLog(@"X is %f, %f", x0,x1);
    CGFloat det_C0_C1 = c00 * c11 - c10 * c01;
    CGFloat det_C0_X  = c00 * x1 - c10 * x0;
    CGFloat det_X_C1  = x0 * c11 - x1*c01;
    CGFloat alphaL = fabs(det_C0_C1) <= FLT_EPSILON ? 0 : det_X_C1 / det_C0_C1;
    CGFloat alphaR = fabs(det_C0_C1) <= FLT_EPSILON ? 0 : det_C0_X / det_C0_C1;
    NSLog(@"alphaL = %f, alphaR = %f", alphaL, alphaR);
    NSPoint start = [(GSNode*)points[0] position];
    NSPoint end = [(GSNode*)[points lastObject] position];
    CGFloat dist = GSDistance(start, end);

    CGFloat epsilon = 1.0e-6 * dist;
    GSPath* p = [[GSPath alloc] init];
    // Approximate
    [self addSmooth:start toPath:p];
    NSLog(@"right Tangent = %f,%f",  rightTangent.x, rightTangent.y);

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
        CGFloat dist = GSSquareDistance([(GSNode*)points[i] position], GSPointAtTime(
                                  [[path nodeAtIndex:0] position],
                                  [[path nodeAtIndex:1] position],
                                  [[path nodeAtIndex:2] position],
                                  [[path nodeAtIndex:3] position],
                                  [parameters[i] floatValue]));
        if (dist > maxDist) {
            maxDist = dist;
            *splitPoint = i;
        }
        i++;
    }
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
