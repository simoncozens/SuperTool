// Copyright 2019 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "SuperTool+Callipers.h"
#import <GlyphsCore/GSGeometrieHelper.h>

int STEPS_VALUE = 500;

@implementation SuperTool (Callipers)

NSMutableArray* rainbow;

- (void) initCallipers {
    tool_state = DRAWING_START;
    measure_mode = MEASURE_CLOSEST;
    rainbow = [[NSMutableArray alloc] init];
    segStart1 = [[SCPathTime alloc] init];
    segStart2 = [[SCPathTime alloc] init];
    segEnd1   = [[SCPathTime alloc] init];
    segEnd2   = [[SCPathTime alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(recompute) name:@"GSUpdateInterface" object:nil];

}

- (void) callipersMouseDown:(NSEvent*)theEvent {
    // Called when the mouse button is clicked.
    _editViewController = [_windowController activeEditViewController];
    callipersLayer = [_editViewController.graphicView activeLayer];
    _draggStart = [_editViewController.graphicView getActiveLocation: theEvent];
    _dragging = true;
    if (tool_state == DRAWING_START) {
        //        NSLog(@"Clearing start");
        segStart1 = [segStart1 init];
        segStart2 = [segStart2 init];
    }
    //    NSLog(@"Clearing end");
    segEnd1 = [segEnd1 init];
    segEnd2 = [segEnd2 init];
    [self recompute];
}

- (void) recompute {
    cacheMin = 0;
}

- (void) callipersMouseDragged:(NSEvent*)theEvent {
    NSPoint Loc = [_editViewController.graphicView getActiveLocation: theEvent];
    [_editViewController.graphicView setNeedsDisplay: TRUE];
    if ([theEvent modifierFlags] & NSShiftKeyMask) {
        CGFloat dx = fabs(Loc.x - _draggStart.x);
        CGFloat dy = fabs(Loc.y - _draggStart.y);
        if (dx < dy) {
            Loc.x = _draggStart.x;
        } else {
            Loc.y = _draggStart.y;
        }
    }
    _draggCurrent = Loc;
}

- (void) callipersMouseUp:(NSEvent*)theEvent {
    // Called when the primary mouse button is released.
    // editViewController.graphicView.cursor = [NSCursor openHandCursor];
    if (!([theEvent modifierFlags] & NSEventModifierFlagOption)) {
        return [super mouseUp:theEvent];
    }
    NSPoint startPoint = _draggStart;
    NSPoint endPoint   = _draggCurrent;
    GSLayer* layer = [_editViewController.graphicView activeLayer];
    _dragging = false;
    NSMutableArray* intersections = [NSMutableArray array];
    /* How many segments does my line intersect? */
    for (GSPath* p in [layer shapes]) {
        if (![p isKindOfClass:[GSPath class]]) continue;
        int i =0;
        NSArray* segs = [p segments];
        while (i < [segs count]) {
            NSArray *thisSeg = [segs objectAtIndex: i];
            if ([thisSeg count] == 2) {
                // Set up line intersection
                NSPoint segstart = [[thisSeg objectAtIndex:0] pointValue];
                NSPoint segend = [[thisSeg objectAtIndex:1] pointValue];
                NSPoint pt = GSIntersectLineLine(startPoint, endPoint, segstart, segend);
                if (pt.x != NSNotFound && pt.y != NSNotFound) {
                    CGFloat t = GSDistance(segstart,pt) / GSDistance(segstart, segend);
                    SCPathTime *intersection = [[SCPathTime alloc] initWithPath:p SegId:i t:t];
                    [intersections addObject: intersection];
                }
            } else {
                NSPoint segstart = [[thisSeg objectAtIndex:0] pointValue];
                NSPoint handle1 = [[thisSeg objectAtIndex:1] pointValue];
                NSPoint handle2 = [[thisSeg objectAtIndex:2] pointValue];
                NSPoint segend = [[thisSeg objectAtIndex:3] pointValue];
                NSArray* localIntersections = GSIntersectBezier3Line(segstart, handle1, handle2, segend, startPoint, endPoint);
                for (id _pt in localIntersections) {
                    NSPoint pt = [_pt pointValue];
                    CGFloat t;
                    [p nearestPointOnPath:pt pathTime:&t];
                    t = fmod(t, 1.0);
                    SCPathTime *intersection = [[SCPathTime alloc] initWithPath:p SegId:i t:t];
                    [intersections addObject: intersection];
                }
            }
            i++;
        }
    }
    //    NSLog(@"Found %lu intersections!", (unsigned long)[intersections count]);
    if ([intersections count] != 2) {
        [_editViewController.graphicView setNeedsDisplay: TRUE];
        return;
    }
    
    if (tool_state == DRAWING_START) {
        tool_state = DRAWING_END;
        segStart1 = [intersections objectAtIndex:0];
        segStart2 = [intersections objectAtIndex:1];
        //        NSLog(@"Setting start");
        //        NSLog(@"start1: %@, %lu, %g", segStart1->path, segStart1->segId, segStart1->t);
        //        NSLog(@"start2: %@, %lu, %g", segStart2->path, segStart2->segId, segStart2->t);
    } else {
        tool_state = DRAWING_START;
        segEnd1 = [intersections objectAtIndex:0];
        segEnd2 = [intersections objectAtIndex:1];
        _dragging = false;
        //        NSLog(@"Setting end");
        //        NSLog(@"start1: %@, %lu, %g", segStart1->path, segStart1->segId, segStart1->t);
        //        NSLog(@"start2: %@, %lu, %g", segStart2->path, segStart2->segId, segStart2->t);
        //        NSLog(@"end1: %@, %lu, %g", segEnd1->path, segEnd1->segId, segEnd1->t);
        //        NSLog(@"end2: %@, %lu, %g", segEnd2->path, segEnd2->segId, segEnd2->t);
        [_editViewController.graphicView setNeedsDisplay: TRUE];
    }
    
}

// Find the point on a curve nearest to a given point.
- (NSPoint) minSquareDistancePoint:(NSPoint) p Curve:(SCPathTime*)c {
    NSPoint best = [c point];
    if (measure_mode == MEASURE_CORRESPONDING) return best;
    long bestDist = GSSquareDistance(p, best);
    SCPathTime* c2 = [c copy];
    while (true){
        [c2 stepTimeBy:0.01];
        NSPoint p2 = [c2 point];
        long d = GSSquareDistance(p, p2);
        if (d < bestDist) {
            bestDist = d;
            best = p2;
        }
        if (d > bestDist) break;
    }
    c2 = [c copy];
    while (true){
        [c2 stepTimeBy:-0.01];
        NSPoint p2 = [c2 point];
        long d = GSSquareDistance(p, p2);
        if (d < bestDist) {
            bestDist = d;
            best = p2;
        }
        if (d > bestDist) break;
    }
    return best;
}

- (void) drawCallipers:(GSLayer *)layer {
    if (segStart1->segId == NSNotFound || segEnd1->segId == NSNotFound ||
        segStart2->segId == NSNotFound || segEnd2->segId == NSNotFound ||
        !segStart1->path || !segStart2->path) {
        if (_dragging) {
            NSBezierPath * path = [NSBezierPath bezierPath];
            [path setLineWidth: 1];
            [path moveToPoint: _draggStart];
            [path lineToPoint: _draggCurrent];
            if (tool_state == DRAWING_START) {
                [[NSColor greenColor] set];
            } else { [[NSColor redColor] set]; }
            [path stroke];
        }
        return;
    }
    //    NSLog(@"Drawing!");
    [self computeRainbow];
    [self drawRainbow];
    [super drawBackgroundForLayer:layer];
}

- (void) computeRainbow {
    if (cacheMin != 0) { return; }

    rainbow = [[NSMutableArray alloc] init];
    // Measure the two paths. Swap if needed
    CGFloat sl1 = [SCPathTime pathLength:segStart1 to:segEnd1];
    CGFloat sl2 = [SCPathTime pathLength:segStart2 to:segEnd2];
    //    NSLog(@"Length of intersections, 1: %g, 2: %g", sl1, sl2);
    if (sl1 < sl2) {
        SCPathTime* ss = segStart2;
        SCPathTime* se = segEnd2;
        segStart2 = segStart1; segStart1 = ss;
        segEnd2 = segEnd1; segEnd1 = se;
    }

    int steps = STEPS_VALUE;
    CGFloat step1 = ((segEnd1->segId + segEnd1->t) - (segStart1->segId + segStart1->t)) / steps; // XXX
    CGFloat step2 = ((segEnd2->segId + segEnd2->t) - (segStart2->segId + segStart2->t)) / steps;
    long maxLen, minLen, avgLen;
    SCPathTime* t1, *t2;

    // First pass over the two segments determines maximum, minimum and
    // average distances between them, for scaling the color map.
    minLen = 99999;
    maxLen = 0;
    avgLen = 0;
    t1 = [segStart1 copy];
    t2 = [segStart2 copy];
    int actualSteps = 0;
    while ([t1 compareWith: segEnd1] != copysign(1.0, step1)) {
        NSPoint p1 = [t1 point];
        NSPoint p2 = [self minSquareDistancePoint:p1 Curve:t2];
        long dist = GSSquareDistance(p1,p2);
        if (dist < minLen) minLen = dist;
        if (dist > maxLen) maxLen = dist;
        avgLen += dist;
        [t1 stepTimeBy:step1];
        [t2 stepTimeBy:step2];
        actualSteps++;
    }
    avgLen /= actualSteps;
    cacheMin = minLen;

    // Now we collect the lines which join the segments and determine
    // their coloring.
    // We could make this a lot faster by storing the p1 and p2 pairs
    // above in an array and then iterating over it.
    t1 = [segStart1 copy];
    t2 = [segStart2 copy];
    while ([t1 compareWith: segEnd1] != copysign(1.0, step1)) {
        NSPoint p1 = [t1 point];
        NSPoint p2 = [self minSquareDistancePoint:p1 Curve:t2];
        long dist = GSSquareDistance(p1,p2);
        CGFloat scale = fabs((CGFloat)maxLen-minLen);
        if (scale < 5) scale = 5;
        CGFloat hue = (120+((avgLen-dist)/scale*180.0))/360;
        //        if (hue < 0.2) hue -= 0.11;
        NSColor *c = [NSColor colorWithHue:hue saturation:1.0 brightness:1.0 alpha:1];
        // NSLog(@"Dist: %li, hue: %g. Min: %li, avg: %li, max: %li", dist, hue, minLen, avgLen, maxLen);
        NSDictionary *line = @{
                               @"start": [NSValue valueWithPoint:p1],
                               @"end": [NSValue valueWithPoint:p2],
                               @"hue": c
                               };
        [rainbow addObject:line];
        [t1 stepTimeBy:step1];
        [t2 stepTimeBy:step2];
    }
}

- (void) drawRainbow {
    for (NSDictionary* line in rainbow) {
        NSBezierPath * path = [NSBezierPath bezierPath];
        [path setLineWidth: 1.0];
        [path moveToPoint: [(NSValue*)line[@"start"] pointValue]];
        [path lineToPoint: [(NSValue*)line[@"end"] pointValue]];
        [(NSColor*)(line[@"hue"]) set];
        [path stroke];
    }
}

- (void) willActivate {
    GSLayer* layer = [_editViewController.graphicView activeLayer];
    if (layer != callipersLayer) {
        segStart1 = [segStart1 init];
        segStart2 = [segStart2 init];
        segEnd1 = [segEnd1 init];
        segEnd2 = [segEnd2 init];
        [self recompute];
    }
}

- (void) willDeactivate {
    callipersLayer = NULL;
}

@end
