//
//  SuperTool.m
//  SuperTool
//
//  Created by Simon Cozens on 21/04/2016.
//    Copyright © 2016 Simon Cozens. All rights reserved.
//

#import "SuperTool.h"


@implementation SuperTool

NSMenuItem* drawCurves;
NSMenuItem* drawTunni;

NSString* drawCurvesDefault = @"org.simon-cozens.SuperTool.drawingCurvature";
NSString* drawTunniDefault = @"org.simon-cozens.SuperTool.drawingTunni";

const int SAMPLE_SIZE = 200;
const float HANDLE_SIZE = 5.0;

- (id)init {
	self = [super init];
    NSArray *arrayOfStuff;
	NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];
	if (thisBundle) {
		// The toolbar icon:
		_toolBarIcon = [[NSImage alloc] initWithContentsOfFile:[thisBundle pathForImageResource:@"ToolbarIconTemplate"]];
		[_toolBarIcon setTemplate:YES];
	}
    drawCurves = [[NSMenuItem alloc] initWithTitle:@"Show curvature" action:@selector(displayCurvatureState) keyEquivalent:@""];
    drawTunni = [[NSMenuItem alloc] initWithTitle:@"Show Tunni lines" action:@selector(displayTunniState) keyEquivalent:@""];
    if ([[[NSUserDefaults standardUserDefaults] objectForKey:drawCurvesDefault]boolValue]) {
        [drawCurves setState:NSOnState];
    }
    if ([[[NSUserDefaults standardUserDefaults] objectForKey:drawTunniDefault]boolValue]) {
        [drawTunni setState:NSOnState];
    }
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

- (void) displayCurvatureState {
    if ([drawCurves state] == NSOnState) {
        [drawCurves setState:NSOffState];
        [[NSUserDefaults standardUserDefaults] setObject:@NO forKey:drawCurvesDefault];
    } else {
        [drawCurves setState:NSOnState];
        [[NSUserDefaults standardUserDefaults] setObject:@YES forKey:drawCurvesDefault];

    }
    [_editViewController.graphicView setNeedsDisplay: TRUE];
}

- (void) displayTunniState {
    if ([drawTunni state] == NSOnState) {
        [drawTunni setState:NSOffState];
        [[NSUserDefaults standardUserDefaults] setObject:@NO forKey:drawTunniDefault];
    } else {
        [drawTunni setState:NSOnState];
        [[NSUserDefaults standardUserDefaults] setObject:@YES forKey:drawTunniDefault];
    }
    [_editViewController.graphicView setNeedsDisplay: TRUE];
}

- (NSMenu *)defaultContextMenu {
	// Adds items to the context menu.
    NSMenu *theMenu = [super defaultContextMenu];
    [theMenu insertItem:drawCurves atIndex:0];
    [theMenu insertItem:drawTunni atIndex:1];
    [theMenu insertItem:[NSMenuItem separatorItem] atIndex:2];

    return theMenu;
}

- (void)addMenuItemsForEvent:(NSEvent *)theEvent toMenu:(NSMenu *)theMenu {
    if ([self anyCurvesSelected]) {
        [theMenu addItemWithTitle:@"Balance" action:@selector(balance) keyEquivalent:@""];
    }
    if ([self multipleSegmentsSelected]) {
        [theMenu addItemWithTitle:@"Simplify..." action:@selector(showSimplifyWindow) keyEquivalent:@""];
    }
    [theMenu addItemWithTitle:@"Harmonize" action:@selector(harmonize) keyEquivalent:@""];
    [theMenu addItem:[NSMenuItem separatorItem]];
    [super addMenuItemsForEvent:theEvent toMenu:theMenu];
}

- (GSNode*) nextNode:(GSNode*)n {
    GSPath *p = [n parent];
    NSUInteger index = [p indexOfNode:n];
    return index == [p countOfNodes] ? [p nodeAtIndex:0] : [p nodeAtIndex: index+1];
}

- (GSNode*) prevNode:(GSNode*)n {
    GSPath *p = [n parent];
    NSUInteger index = [p indexOfNode:n];
    return index == 0 ? [p nodeAtIndex:([p countOfNodes]-1)] : [p nodeAtIndex: index-1];
}

- (BOOL) anyCurvesSelected {
    GSLayer* currentLayer = [_editViewController.graphicView activeLayer];
    GSNode* n;
    for (n in [currentLayer selection]) {
        if ([n type] == OFFCURVE && [[self nextNode:n] type] == OFFCURVE) {
            return TRUE;
        } else if ([n type] == OFFCURVE && [[self prevNode:n] type] == OFFCURVE) {
            return TRUE;
        }
    }
    return FALSE;
}

- (void) balance {
    GSLayer* currentLayer = [_editViewController.graphicView activeLayer];
    NSMutableOrderedSet* segments = [[NSMutableOrderedSet alloc] init];
    GSNode* n;
    for (n in [currentLayer selection]) {
        // Find the segment for this node and add it to the set
        if ([n type] == OFFCURVE && [[self nextNode:n] type] == OFFCURVE) {
            // Add prev, this, next, and next next to the set
            NSArray* a = [NSArray arrayWithObjects:[self prevNode:n],n,[self nextNode:n],[self nextNode:[self nextNode:n]],nil];
            [segments addObject:a];
        } else if ([n type] == OFFCURVE && [[self prevNode:n] type] == OFFCURVE) {
            // Add prev prev, prev, this and next to the set
            NSArray* a = [NSArray arrayWithObjects:[self prevNode:[self prevNode:n]],[self prevNode:n],n,[self nextNode:n],nil];
            [segments addObject:a];
        }
    }
    NSArray* seg;
    for (seg in segments) {
        NSPoint p1 = [(GSNode*)seg[0] position];
        NSPoint p2 = [(GSNode*)seg[1] position];
        NSPoint p3 = [(GSNode*)seg[2] position];
        NSPoint p4 = [(GSNode*)seg[3] position];
        NSPoint t = GSIntersectLineLineUnlimited(p1,p2,p3,p4);
        CGFloat sDistance = GSDistance(p1,t);
        CGFloat eDistance = GSDistance(p4, t);
        if (sDistance <= 0 || eDistance <= 0) return;
        CGFloat xPercent = GSDistance(p1,p2) / sDistance;
        CGFloat yPercent = GSDistance(p3,p4) / eDistance;
        if (xPercent > 1 && yPercent >1) return; // Inflection point
        if (xPercent < 0.01 && yPercent <0.01) return; // Inflection point
        CGFloat avg = (xPercent+yPercent)/2.0;
        NSPoint newP2 = GSLerp(p1, t, avg);
        NSPoint newP3 = GSLerp(p4, t, avg);
        [(GSNode*)seg[1] setPosition:newP2];
        [(GSNode*)seg[2] setPosition:newP3];
    }
}

- (void)drawCurvatureForSegment:(NSArray*)seg {
    NSPoint p1 = [seg[0] pointValue];
    NSPoint p2 = [seg[1] pointValue];
    NSPoint p3 = [seg[2] pointValue];
    NSPoint p4 = [seg[3] pointValue];
    float t=0.0;
    NSBezierPath * path = [NSBezierPath bezierPath];
    [path moveToPoint: GSPointAtTime(p1,p2,p3,p4, 0)];
    NSColor* first = [NSColor colorWithCalibratedRed:0.1 green:0.1 blue:0.1 alpha:0.3];
    NSColor* emptyRed = [NSColor colorWithCalibratedRed:1.0 green:0 blue:0 alpha:0];
    NSColor* second = [first copy];
    float maxC = 0.0;
    float maxAngle = 0;
    while (t<=1.0) {
        NSPoint normal = normalForT(p1,p2,p3,p4, t);
        CGFloat c = sqrt(curvatureSquaredForT(p1,p2,p3,p4,t));
        if (c > maxC) {
            maxC = c;
            maxAngle = GSAngleOfVector(normal);
        }
        if (c <= 10.0) {
            NSPoint end = GSAddPoints(GSPointAtTime(p1,p2,p3,p4, t), GSScalePoint(normal, 1000*c));
            [path setLineWidth: 1];
            [path lineToPoint: end];
        }
        t+= 0.02;
    }
    second = [second blendedColorWithFraction:maxC*20 ofColor:emptyRed];
    [second set];
    [path lineToPoint: GSPointAtTime(p1,p2,p3,p4, 1)];
    [path curveToPoint:p1 controlPoint1:p3 controlPoint2:p2];
    [path fill];
}

- (void)drawTunniLinesForSegment:(NSArray*)seg {
    NSPoint p1 = [seg[0] pointValue];
    NSPoint p2 = [seg[1] pointValue];
    NSPoint p3 = [seg[2] pointValue];
    NSPoint p4 = [seg[3] pointValue];
    NSPoint tunniPoint = GSIntersectLineLineUnlimited(p1,p2,p3,p4);
    CGFloat sDistance = GSDistance(p1,tunniPoint);
    CGFloat eDistance = GSDistance(p4, tunniPoint);
    CGFloat currentZoom =  [_editViewController.graphicView scale];
    NSColor* col;
    if (currentZoom < 2.0)
        col = [NSColor colorWithCalibratedRed: 0 green:0 blue:1 alpha:currentZoom-1.0];
    else
        col = [NSColor blueColor];
    [col set];
//    [self drawHandle:NSMakePoint(0,0) isSelected:FALSE atPoint:tunniPoint];
    
    NSDictionary* attrs = @{
                            NSFontAttributeName: [NSFont labelFontOfSize: 10/currentZoom ],
        NSForegroundColorAttributeName:col
                           };
    if (sDistance > 0) {
        CGFloat xPercent = GSDistance(p1,p2) / sDistance;
        NSAttributedString *label = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%.1f%%", xPercent*100.0] attributes:attrs];
//        NSAffineTransform *rotate = [NSAffineTransform transform];
//        [rotate rotateByDegrees:GSAngleOfVector(GSSubtractPoints(p2, p1)) / M_PI * 180.0];
//        [rotate concat];
        [_editViewController.graphicView drawText:label atPoint:GSMiddlePoint(p1, p2) alignment:4];
//        [rotate invert];
//        [rotate concat];
    }
    if (eDistance > 0) {
        CGFloat yPercent = GSDistance(p3,p4) / eDistance;
        NSAttributedString *label = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%.1f%%", yPercent*100.0] attributes:attrs];
        [_editViewController.graphicView drawText:label atPoint:GSMiddlePoint(p3, p4) alignment:4];
    }
    if (sDistance > 0 && eDistance > 0) {
        NSBezierPath* bez = [NSBezierPath bezierPath];
        CGFloat dash[2] = {1.0,1.0};
        [bez setLineWidth:0.0];
        [bez appendBezierPathWithArcWithCenter:tunniPoint radius:HANDLE_SIZE/currentZoom startAngle:0 endAngle:359];
        [bez stroke];
        [bez closePath];
        [bez setLineDash:dash count:2 phase:0];
        [bez moveToPoint:p2];
        [bez lineToPoint:p3];
        [bez stroke];
    }
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

- (void)drawBackgroundForLayer:(GSLayer*)Layer {
    BOOL doDrawCurves = [drawCurves state] == NSOnState;
    BOOL doDrawTunni = [drawTunni state] == NSOnState;
    if (!doDrawCurves && !doDrawTunni) return;
    [self iterateOnCurvedSegmentsOfLayer:Layer withBlock:^(NSArray* seg) {
        if (doDrawCurves) [self drawCurvatureForSegment:seg];
        if (doDrawTunni) [self drawTunniLinesForSegment:seg];
    }];
}

#pragma mark TunniEditing
/*! @methodgroup TunniEditing */
/*! @name Tunni Editing */

- (void) mouseDown:(NSEvent*)theEvent {
    // Called when the mouse button is clicked.
    if ([drawTunni state] != NSOnState) return [super mouseDown:theEvent];
    
    GSLayer* currentLayer = [_editViewController.graphicView activeLayer];
    NSPoint start = [_editViewController.graphicView getActiveLocation: theEvent];
    /* Would love to use the block here but variable scoping rules don't allow it */
    GSPath *p;

    for (p in currentLayer.paths) {
        NSArray* seg;
        for (seg in p.segments) {
            if ([seg count] == 4) {
                NSPoint p1 = [seg[0] pointValue];
                NSPoint p2 = [seg[1] pointValue];
                NSPoint p3 = [seg[2] pointValue];
                NSPoint p4 = [seg[3] pointValue];
                NSPoint t = GSIntersectLineLineUnlimited(p1,p2,p3,p4);
                if (GSDistance(t, start) <= HANDLE_SIZE/2) {
                    // We have a winner!
                    tunniDraggingLine = false;
                gotOne:
                    tunniSeg = seg;
                    tunniSegP2 = [currentLayer nodeAtPoint:p2 excludeNode:NULL tollerance:0.5];
                    tunniSegP3 = [currentLayer nodeAtPoint:p3 excludeNode:NULL tollerance:0.5];
                    [[currentLayer undoManager] beginUndoGrouping];
                    return;
                }
                if (GSDistanceOfPointFromLineSegment(start, p2, p3) <= 2.0) {
                    if (GSDistance(start, p2) <= HANDLE_SIZE/2 || GSDistance(start, p3) <= HANDLE_SIZE/2) {
                        // Actually dragging the handle, not the line.
                        return [super mouseDown:theEvent];
                    }
                    tunniDraggingLine = true;
                    goto gotOne;
                }
            }
        }
    }
    tunniSeg = NULL;
    return [super mouseDown:theEvent];
}

- (void) mouseDragged:(NSEvent *)theEvent {
    if (!tunniSeg) return [super mouseDragged:theEvent];
    GSLayer* currentLayer = [_editViewController.graphicView activeLayer];
    NSPoint Loc = [_editViewController.graphicView getActiveLocation: theEvent];
    NSPoint p1 = [tunniSeg[0] pointValue];
    NSPoint p2 = [tunniSeg[1] pointValue];
    NSPoint p3 = [tunniSeg[2] pointValue];
    NSPoint p4 = [tunniSeg[3] pointValue];
    NSPoint tunniPoint = GSIntersectLineLineUnlimited(p1,p2,p3,p4);
    CGFloat sDistance = GSDistance(p1,tunniPoint);
    CGFloat eDistance = GSDistance(p4, tunniPoint);
    CGFloat xPercent = GSDistance(p1,p2) / sDistance;
    CGFloat yPercent = GSDistance(p3,p4) / eDistance;
    NSPoint newP2;
    NSPoint newP3;
    if (tunniDraggingLine) {
        CGFloat sign = (GSPointIsLeftOfLine(p2, p3, tunniPoint) == GSPointIsLeftOfLine(p2, p3, Loc)) ? 1.0 : -1.0;
        xPercent += GSDistanceOfPointFromLineSegment(Loc, p2, p3) / ((sDistance+eDistance)/2) * sign;
        yPercent += GSDistanceOfPointFromLineSegment(Loc, p2, p3) / ((sDistance+eDistance)/2) * sign;
        /* ??? */
        newP2 = GSLerp(p1, tunniPoint, xPercent);
        newP3 = GSLerp(p4, tunniPoint, yPercent);
    } else {
        /* Arrange for the tunni point of this segment to be Loc, keeping curvature */
        newP2 = GSLerp(p1, Loc, xPercent);
        newP3 = GSLerp(p4, Loc, yPercent);
    }
    /* Now do magic */
    if (tunniSegP2) {
        [tunniSegP2 setPosition:newP2];
        [self correctNode:[currentLayer nodeAtPoint:p1 excludeNode:NULL tollerance:0.5] forward:FALSE];
    }
    if (tunniSegP3) {
        [tunniSegP3 setPosition:newP3];
        [self correctNode:[currentLayer nodeAtPoint:p4 excludeNode:NULL tollerance:0.5] forward:TRUE];
    }
}

- (void) correctNode:(GSNode*)n forward:(BOOL)f {
    if (!n) return;
    if (n.type != CURVE || n.connection != SMOOTH) return;
    NSInteger index = [[n parent] indexOfNode:n];
    GSNode* rhandle = [[n parent] nodeAtIndex:index+1];
    GSNode* lhandle = [[n parent] nodeAtIndex:index-1];
    CGFloat lHandleLen = GSDistance([n position], [lhandle position]);
    CGFloat rHandleLen = GSDistance([n position], [rhandle position]);
    // Average the two angles first
    NSPoint ua = GSUnitVectorFromTo([lhandle position], [n position]);
    NSPoint ub = GSUnitVectorFromTo([n position], [rhandle position]);
    NSPoint average = GSScalePoint(GSAddPoints(ua, ub),0.5);
    [rhandle setPosition:GSAddPoints([n position], GSScalePoint(average, rHandleLen))];
//    if (f) {
//        // Set rhandle
//        NSPoint newPos = GSLerp([lhandle position], [n position], (lHandleLen+rHandleLen)/lHandleLen);
//        [rhandle setPositionFast:newPos];
//    } else {
//        NSPoint newPos = GSLerp([rhandle position], [n position], (lHandleLen+rHandleLen)/rHandleLen);
//        [lhandle setPositionFast:newPos];
//
//    }
}

- (void) mouseUp:(NSEvent *)theEvent {
    if (tunniSeg) {
        GSLayer* currentLayer = [_editViewController.graphicView activeLayer];
        [[currentLayer undoManager] endUndoGrouping];
        tunniSeg = NULL;
    }
    return [super mouseUp:theEvent];
}

#pragma mark Harmonizing
/*! @methodgroup Harmonizing */
/*! @name Harmonizing */

- (void) harmonize:(NSArray *)a with:(NSArray*)b {
    NSPoint a0 = [(GSNode*)a[0] position];
    NSPoint a1 = [(GSNode*)a[1] position];
    NSPoint a2 = [(GSNode*)a[2] position];
    NSPoint a3 = [(GSNode*)a[3] position];
    NSPoint b0 = [(GSNode*)b[0] position];
    NSPoint b1 = [(GSNode*)b[1] position];
    NSPoint b2 = [(GSNode*)b[2] position];
    NSPoint b3 = [(GSNode*)b[3] position];

    NSPoint d = GSIntersectLineLineUnlimited(a1,a2,b1,b2);
    CGFloat p0 = GSDistance(a1, a2) / GSDistance(a2, d);
    CGFloat p1 = GSDistance(d, b1) / GSDistance(b1, b2);
    CGFloat p = sqrt(p0 * p1);
    CGFloat t = p / (p+1);
    [(GSNode*)a[3] setPosition:GSLerp(a2,b1,t)];
}

- (void) harmonize:(GSNode*)a3 {
    if ([a3 connection] != SMOOTH) return;
    GSNode* a2 = [self prevNode:a3]; if ([a2 type] != OFFCURVE) return;
    GSNode* a1 = [self prevNode:a2]; if ([a2 type] != OFFCURVE) return;
    GSNode* b1 = [self nextNode:a3]; if ([b1 type] != OFFCURVE) return;
    GSNode* b2 = [self nextNode:b1]; if ([b1 type] != OFFCURVE) return;
    NSPoint d = GSIntersectLineLineUnlimited([a1 position],[a2 position],[b1 position],[b2 position]);
    CGFloat p0 = GSDistance([a1 position], [a2 position]) / GSDistance([a2 position], d);
    CGFloat p1 = GSDistance(d, [b1 position]) / GSDistance([b1 position], [b2 position]);
    CGFloat r = sqrtf(p0 * p1);
    if (r == INFINITY) return;
    CGFloat t = r / (r+1);
    NSPoint newA3 =GSLerp([a2 position],[b1 position],t);
    // One way to do this:
    //    [a3 setPosition:newA3];
    // But we want to keep the oncurve point, so
    NSPoint fixup = GSSubtractPoints([a3 position], newA3);
    [a2 setPosition:GSAddPoints([a2 position], fixup)];
    [b1 setPosition:GSAddPoints([b1 position], fixup)];
};

- (void) harmonize {
    GSLayer* currentLayer = [_editViewController.graphicView activeLayer];
    GSNode* n;
    if ([[currentLayer selection] count] >0) {
        for (n in [currentLayer selection]) {
            [self harmonize:n];
        }
    } else {
        GSPath* p;
        for (p in [currentLayer paths]) {
            for (n in [p nodes]) {
                [self harmonize:n];
            }
        }
    }
}

#pragma mark Simplify
/*! @methodgroup Simplify */
/*! @name Simplify */

- (GSNode*)nextOnCurve:(GSNode*)n {
    GSNode* nn = [self nextNode:n];
    if ([nn type] != OFFCURVE) return nn;
    nn = [self nextNode:nn];
    if ([nn type] != OFFCURVE) return nn;
    nn = [self nextNode:nn];
    return nn;
}

- (GSNode*)prevOnCurve:(GSNode*)n {
    GSNode* nn = [self prevNode:n];
    if ([nn type] != OFFCURVE) return nn;
    nn = [self prevNode:nn];
    if ([nn type] != OFFCURVE) return nn;
    nn = [self prevNode:nn];
    return nn;
}

- (BOOL) multipleSegmentsSelected {
    GSLayer* currentLayer = [_editViewController.graphicView activeLayer];
    GSNode* n;
    NSOrderedSet* sel = [currentLayer selection];
    for (n in sel) {
        if ([n type] != OFFCURVE) {
            if ([sel containsObject:[self nextOnCurve:n]]) return TRUE;
            if ([sel containsObject:[self prevOnCurve:n]]) return TRUE;
        }
    }
    return FALSE;
}

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
        
//        nn = [self prevOnCurve:n];
//        if ([sel containsObject:nn]) {
//            [self addToSelectionSegmentStarting:nn Ending:n];
//            NSLog(@"Added %@ (prev) -> %@, Selection set is %@", nn, n, simplifySegSet);
//        }
        nn = [self nextOnCurve:n];
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

    [simplifyWindow makeKeyAndOrderFront:nil];
    [self doSimplify];
}

- (void) doSimplify {
    CGFloat reducePercentage = [simplifySlider floatValue];
    int i = 0;
//    NSLog(@"Seg set is %@", simplifySegSet);
//    NSLog(@"copied paths is %@", copiedPaths);
//    NSLog(@"original paths is %@", originalPaths);
    while (i <= [simplifySegSet count]-1) {
        NSMutableArray* s = simplifySegSet[i];
        GSPath* p = simplifyPathSet[i];
        NSRange startEnd = [simplifySpliceSet[i] rangeValue];
        NSInteger target = 2.5 + ([s count]-2) * reducePercentage /100;
        NSLog(@"Must reduce %@ to %li (%li, %f)", s, (long)target, (unsigned long)[s count], reducePercentage);

        if ([[s firstObject] parent]) {
            NSLog(@"ALERT! Parent of %@ is %@", [s firstObject], [[s firstObject]parent]);
        } else {
            NSLog(@"Parent dead before simplifying!");
            return;
        }
        if ([s count] <= target) {
            i++;
            // XXX Splice in the original curve!
            continue;
        }
        NSUInteger newend = [self simplifySegment:s toPoints:target splicing:startEnd intoPath:p];
        NSLog(@"New end is %i",newend );
        simplifySpliceSet[i] = [NSValue valueWithRange:NSMakeRange(startEnd.location, newend)];
        if (![[s firstObject] parent]) {
            NSLog(@"ALERT! Parent dead after simplifying!");
     
        }
        NSLog(@"Simplify splice set = %@", simplifySpliceSet);
        i++;
    }
}

- (NSUInteger) simplifySegment:(NSMutableArray*)s toPoints:(NSInteger)target splicing:(NSRange)splice intoPath:(GSPath*)path{
    // Sum the total length of the affected segs
    CGFloat len = 0.0;
    GSNode *n = [s firstObject];
    GSNode *last = [s lastObject];
    NSLog(@"Starting simplify; N is %@; curve is %@; start value %i, end value %i", n, [n parent], splice.location, splice.location+splice.length);

    while (n != last) {
        GSNode *next1 = [self nextNode:n];
        GSNode *next = [self nextOnCurve:n];

        NSAssert(next1, @"There is a following node");
        NSAssert(next, @"There is a following on-curve node");
        if ([next1 type] == OFFCURVE) {
            len += GSLengthOfSegment([n position], [next1 position], [[self nextNode:next1] position], [next position]);
        } else {
            // It's a straight
            len += GSDistance([n position], [next position]);
        }
        n = next;
    }
    // Divide line into n segs and gather the nodes in each segment.
    // This allows us to weight the distribution of nodes in the simplified version
    CGFloat interval = len/(target-1);
    CGFloat i = 0;
    NSInteger nodeCount = 1;
    NSMutableArray* segs = [[NSMutableArray alloc] init];
    n = [s firstObject];
//    NSLog(@"Dividing line of length %f into %lu segments of length %f each",len,(target-1),interval);
    [segs addObject:[[NSMutableArray alloc] init]];
    while (n != last) {
        GSNode *next1 = [self nextNode:n];
        GSNode *next = [self nextOnCurve:n];
        if ([next1 type] == OFFCURVE) {
            i += GSLengthOfSegment([n position], [next1 position], [[self nextNode:next1] position], [next position]);
        } else {
            // It's a straight
            i += GSDistance([n position], [next position]);
        }
        nodeCount++;
        [[segs lastObject] addObject:n];
        if (i > interval) {
            // Start a new interval
            i = 0;
            [segs addObject:[[NSMutableArray alloc] init]];
        }
        n = next;
    }
//    NSLog(@"Segmented: %@", segs);

    // Now produce a reweighted array of line positions
    NSMutableArray *nodesInSeg;
    NSMutableArray *linePositions = [[NSMutableArray alloc] init];
    CGFloat totalweight = 0.0;
    for (nodesInSeg in segs) {
        CGFloat weight = (nodeCount-[nodesInSeg count])/(CGFloat)nodeCount;
        totalweight += weight;
    }
    CGFloat cumulativeweight = 0.0;
    for (nodesInSeg in segs) {
        cumulativeweight += (nodeCount-[nodesInSeg count])/(CGFloat)nodeCount;
        CGFloat thispos = cumulativeweight / totalweight * len;
        [linePositions addObject:[NSNumber numberWithFloat:thispos]];
    }
//    NSLog(@"Weight array of line positions: %@", linePositions);
    
    // Now interpolate the new node positions.
    i = 0;
    n = [s firstObject];
    NSMutableArray* nodepositions = [[NSMutableArray alloc]init];
    GSNode* first = [s firstObject];
    [nodepositions addObject:[NSValue valueWithPoint:[first position]]];
    while (n != last) {
        CGFloat startI = i;
        GSNode *next1 = [self nextNode:n];
        GSNode *next = [self nextOnCurve:n];
        if ([next1 type] == OFFCURVE) {
            i += GSLengthOfSegment([n position], [next1 position], [[self nextNode:next1] position], [next position]);
        } else {
            // It's a straight
            i += GSDistance([n position], [next position]);
        }
        CGFloat target = [[linePositions firstObject] floatValue];
//        NSLog(@"Current target is %f, start line length was %f and after adding this length is %f, this node is %@", target, startI, i, n);
        if (i > target) {
            NSPoint pos;
            CGFloat timeOnLine = (target-startI) / (i-startI);
//            NSLog(@"Looking for time-on-line %f: ", timeOnLine);
            if (timeOnLine < 1.0f - FLT_EPSILON) {
                [linePositions removeObjectAtIndex:0];
                if ([next1 type] == OFFCURVE) {
                    pos = GSPointAtTime([n position], [next1 position], [[self nextNode:next1] position], [next position], timeOnLine);
//                    NSLog(@"On a curve between %f,%f and %f,%f =  %f,%f", [n position].x, [n position].y, [next position].x, [next position].y, pos.x, pos.y);

                } else {
                    pos = GSLerp([n position], [next position], timeOnLine);
//                    NSLog(@"On a straight between %f,%f and %f,%f =  %f,%f", [n position].x, [n position].y, [next position].x, [next position].y, pos.x, pos.y);
                }
                [nodepositions addObject:[NSValue valueWithPoint:pos]];
            }
        }
        n = next;
    }
    // Normally we should add the final node, except in cases of floating-point failure above.
    if (GSDistance([[nodepositions lastObject] pointValue], [last position]) >= 0.1) {
        [nodepositions addObject:[NSValue valueWithPoint:[last position]]];
    }
    
    [[segs objectAtIndex:0] removeObjectAtIndex:0];
    i = 0;
//    NSLog(@"Nodepositions: %@", nodepositions);
//    NSLog(@"Segs: %@", segs);
    GSPath *newPath = [[GSPath alloc] init];
    [newPath addNode:[[s firstObject] copy]];

    if ([segs count]+1 < [nodepositions count]) {
        NSLog(@"Assertion failed!");
        NSLog(@"Segs: %@", segs);
        NSLog(@"Node positions: %@", nodepositions);
        return splice.length;
    }

    while (i < [segs count]) {
        NSMutableArray* thisseg = [segs objectAtIndex:i];
//        NSLog(@"Segment runs from: %@ to: %@", [nodepositions objectAtIndex:i], [nodepositions objectAtIndex:(i+1)]);
//        NSLog(@"Segment interprets nodes: %@", [segs objectAtIndex:i]);
        NSPoint cp1, cp2;
        
        [SuperTool SCfitCurveOn1:[[nodepositions objectAtIndex:i] pointValue]
                       off1:&cp1
                       Off2:&cp2
                        on2:[[nodepositions objectAtIndex:(i+1)] pointValue]
                        toOrigiPoints:thisseg
         ];
//        NSLog(@"Curve fitting suggests: %@ - %f,%f - %f,%f - %@", [nodepositions objectAtIndex:i], cp1.x,cp1.y, cp2.x,cp2.y, [nodepositions objectAtIndex:i+1]);
        GSNode *n = [[GSNode alloc] init];
        n.position = cp1;
        n.type = OFFCURVE;
        [newPath addNode: n];
//        NSLog(@"Added cp1");
        n = [[GSNode alloc] init];
        n.position = cp2;
        n.type = OFFCURVE;
        [newPath addNode: n];
//        NSLog(@"Added cp2");
        n = [[GSNode alloc] init];
        n.position = [[nodepositions objectAtIndex:(i+1)] pointValue];
        n.type = CURVE;
        n.connection = SMOOTH;
        [newPath addNode: n];
//        NSLog(@"Added next");
        i++;
    }
//    NSLog(@"New path: %@", [newPath nodes]);
    
//    [[[first parent] parent] addPath: newPath];
    return [self splice:newPath into:path at:splice];
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
        [self correctNode:[path nodeAtIndex:j] forward:TRUE];
        [self harmonize:[path nodeAtIndex:j]];
        j++;
    }
    [path cleanUp];
    NSLog(@"Spliced path: %@", path);
    return [newPath countOfNodes] -1;
}

+ (void)SCfitCurveOn1:(NSPoint)On1 off1:(NSPoint*)Off1 Off2:(NSPoint*)Off2 on2:(NSPoint)On2 toOrigiPoints:(NSMutableArray*)OrigiPoints {
    NSMutableArray* points = [[NSMutableArray alloc] init];
    NSUInteger pcount = [OrigiPoints count] + 2;
    GSNode *n;
    [points addObject:[NSValue valueWithPoint:On1]];
    for (n in OrigiPoints) { [points addObject:[NSValue valueWithPoint:[n position]]]; }
    [points addObject:[NSValue valueWithPoint:On2]];
    
    NSPoint leftTangent = GSUnitVector(GSSubtractPoints([points[1] pointValue], [points[0] pointValue] ));
    NSPoint rightTangent = GSUnitVector(GSSubtractPoints([points[pcount-2] pointValue], [points[pcount-1] pointValue]));

    CGFloat dist = GSDistance([points[0] pointValue], [[points lastObject] pointValue]);

    if (pcount ==2) {
        // Approximate
        *Off1 = GSAddPoints(On1, GSScalePoint(leftTangent, dist / 3.0));
        *Off2 = GSAddPoints(On2, GSScalePoint(rightTangent, dist / 3.0));
        return;
    }
    NSMutableArray *parameters = [self chordLengthParameterize:points];

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

    CGFloat c00, c01, c10, c11;
    CGFloat x0, x1;
    int i =0;

    while (i <= [parameters count]-1) {
        c00 += GSDot([a[i][0] pointValue], [a[i][0] pointValue]);
        c01 += GSDot([a[i][0] pointValue], [a[i][1] pointValue]);
        c10 += GSDot([a[i][0] pointValue], [a[i][1] pointValue]);
        c11 += GSDot([a[i][1] pointValue], [a[i][1] pointValue]);
        CGFloat u = [parameters[i] floatValue];
        NSPoint p = GSSubtractPoints([points[i] pointValue],
                                     GSPointAtTime([points[0] pointValue],[points[0] pointValue],[[points lastObject] pointValue],[[points lastObject] pointValue], u));
        x0 += GSDot([a[i][0] pointValue], p);
        x1 += GSDot([a[i][1] pointValue], p);
        i++;
    }

    CGFloat det_C0_C1 = c00 * c11 - c10 * c01;
    CGFloat det_C0_X  = c00 * x1 - c10 * x0;
    CGFloat det_X_C1  = x0 * c11 - x1*c01;
    CGFloat alphaL = fabs(det_C0_C1) <= FLT_EPSILON ? 0 : det_X_C1 / det_C0_C1;
    CGFloat alphaR = fabs(det_C0_C1) <= FLT_EPSILON ? 0 : det_C0_X / det_C0_C1;
    CGFloat epsilon = 1.0e-6 * dist;
    if (alphaL < epsilon || alphaR < epsilon) {
        *Off1 = GSAddPoints(On1, GSScalePoint(leftTangent, dist / 3.0));
        *Off2 = GSAddPoints(On2, GSScalePoint(rightTangent, dist / 3.0));
        return;
    } else {
        *Off1 =GSAddPoints(On1, GSScalePoint(leftTangent, alphaL));
        *Off2 =GSAddPoints(On2, GSScalePoint(rightTangent, alphaR));
    }
}

+ (NSMutableArray*)chordLengthParameterize:(NSMutableArray*)points {
    NSMutableArray* u = [[NSMutableArray alloc]init];
    [u addObject:@0.0];
    NSUInteger i = 1;
    while (i < [points count]) {
        CGFloat v = [u[i==0? [u count]-1 : i-1] floatValue];
        v += GSDistance([points[i] pointValue], [points[i==0? [u count]-1 : i-1] pointValue]);
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

@end
