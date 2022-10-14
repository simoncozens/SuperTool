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

#import "SuperTool+TunniEditing.h"

@implementation SuperTool (TunniEditing)

const float HANDLE_SIZE = 5.0;

NSMenuItem *drawTunni;
NSMenuItem *drawTunniTwo;
NSString *drawTunniDefault = @"org.simon-cozens.SuperTool.drawingTunni";

const float DEFAULT_ZOOM_THRESHOLD = 1.0;
NSString *lineZoomDefault = @"org.simon-cozens.SuperTool.tunniZoomThreshold";
bool initDone = false;

- (void)initTunni {
    drawTunni = [[NSMenuItem alloc] initWithTitle:@"Show Tunni lines" action:@selector(displayTunniState:) keyEquivalent:@"U"];
    [drawTunni setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
    drawTunniTwo = [[NSMenuItem alloc] initWithTitle:@"Show Tunni lines" action:@selector(displayTunniState:) keyEquivalent:@""];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:drawTunniDefault]) {
        [drawTunni setState:NSOnState];
        [drawTunniTwo setState:NSOnState];
    }
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{lineZoomDefault: @(DEFAULT_ZOOM_THRESHOLD)}];
    
    NSMenuItem *viewMenu = [[[NSApplication sharedApplication] mainMenu] itemAtIndex:6];

    NSMenuItem *editMenu = [[[NSApplication sharedApplication] mainMenu] itemAtIndex:2];
    NSMenuItem *balanceItem = [[NSMenuItem alloc] initWithTitle:@"Balance" action:@selector(balance) keyEquivalent:@"b"];
    
    [balanceItem setKeyEquivalentModifierMask:NSEventModifierFlagCommand|NSEventModifierFlagOption];
    if (!initDone) {
        [viewMenu.submenu addItem:drawTunni];
        [editMenu.submenu addItem:balanceItem];
        initDone = true;
    }
}

- (void)addTunniToContextMenu:(NSMenu *)theMenu {
    [theMenu insertItem:drawTunniTwo atIndex:0];
}

- (void)displayTunniState:(id)sender {
    if ([sender state] == NSOnState) {
        [drawTunni setState:NSOffState];
        [drawTunniTwo setState:NSOffState];
        [[NSUserDefaults standardUserDefaults] setObject:@NO forKey:drawTunniDefault];
    } else {
        [drawTunni setState:NSOnState];
        [drawTunniTwo setState:NSOnState];
        [[NSUserDefaults standardUserDefaults] setObject:@YES forKey:drawTunniDefault];
    }

    [_editViewController.graphicView setNeedsDisplay:TRUE];
}

- (void)tunniMouseDown:(NSEvent *)theEvent {
    // Called when the mouse button is clicked.
    if ([drawTunni state] != NSOnState) return [super mouseDown:theEvent];
    
    GSLayer *currentLayer = [_editViewController.graphicView activeLayer];
    NSPoint start = [_editViewController.graphicView getActiveLocation:theEvent];
    /* Would love to use the block here but variable scoping rules don't allow it */
    GSPath *p;
    float tunniZoomThreshold = [[NSUserDefaults standardUserDefaults] floatForKey:lineZoomDefault];
    for (p in currentLayer.shapes) {
        if (![p isKindOfClass:[GSPath class]]) continue;
        GSPathSegment *seg;
        for (seg in p.segments) {
            if (seg.countOfPoints == 4) {
                NSPoint p1 = [seg pointAtIndex:0];
                NSPoint p2 = [seg pointAtIndex:1];
                NSPoint p3 = [seg pointAtIndex:2];
                NSPoint p4 = [seg pointAtIndex:3];
                NSPoint t = GSIntersectLineLineUnlimited(p1, p2, p3, p4);
                if (GSDistance(t, start) <= HANDLE_SIZE/2) {
                    // We have a winner!
                    tunniDraggingLine = false;
                gotOne:
                    tunniSeg = seg;
                    tunniSegP2 = [currentLayer nodeAtPoint:p2 excludeNode:NULL ignoreLocked:FALSE tolerance:0.5];
                    tunniSegP3 = [currentLayer nodeAtPoint:p3 excludeNode:NULL ignoreLocked:FALSE tolerance:0.5];
                    [[currentLayer undoManager] beginUndoGrouping];
                    return;
                }
                if (GSDistanceOfPointFromLineSegment(start, p2, p3) <= tunniZoomThreshold) {
                    if (GSDistance(start, p2) <= HANDLE_SIZE/2 || GSDistance(start, p3) <= HANDLE_SIZE / 2) {
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

- (void)tunniMouseDragged:(NSEvent *)theEvent {
    if (!tunniSeg) return [super mouseDragged:theEvent];
    GSLayer *currentLayer = [_editViewController.graphicView activeLayer];
    NSPoint Loc = [_editViewController.graphicView getActiveLocation:theEvent];
    NSPoint p1 = [tunniSeg pointAtIndex:0];
    NSPoint p2 = [tunniSeg pointAtIndex:1];
    NSPoint p3 = [tunniSeg pointAtIndex:2];
    NSPoint p4 = [tunniSeg pointAtIndex:3];
    NSPoint tunniPoint = GSIntersectLineLineUnlimited(p1, p2, p3, p4);
    CGFloat sDistance = GSDistance(p1, tunniPoint);
    CGFloat eDistance = GSDistance(p4, tunniPoint);
    CGFloat xPercent = GSDistance(p1, p2) / sDistance;
    CGFloat yPercent = GSDistance(p3, p4) / eDistance;
    NSPoint newP2;
    NSPoint newP3;
    if (tunniDraggingLine) {
        CGFloat sign = (GSPointIsLeftOfLine(p2, p3, tunniPoint) == GSPointIsLeftOfLine(p2, p3, Loc)) ? 1.0 : -1.0;
        xPercent += GSDistanceOfPointFromLineSegment(Loc, p2, p3) / ((sDistance + eDistance) / 2) * sign;
        yPercent += GSDistanceOfPointFromLineSegment(Loc, p2, p3) / ((sDistance + eDistance) / 2) * sign;
        /* ??? */
        newP2 = GSPointOnLine(p1, tunniPoint, xPercent);
        newP3 = GSPointOnLine(p4, tunniPoint, yPercent);
    } else {
        /* Arrange for the tunni point of this segment to be Loc, keeping curvature */
        newP2 = GSPointOnLine(p1, Loc, xPercent);
        newP3 = GSPointOnLine(p4, Loc, yPercent);
    }
    /* Now do magic */
    GSNode *n;
    if (tunniSegP2) {
        [tunniSegP2 setPosition:newP2];
        n =[currentLayer nodeAtPoint:p1 excludeNode:NULL ignoreLocked:FALSE tolerance:0.5];
        if (n) [n correct];
    }
    if (tunniSegP3) {
        [tunniSegP3 setPosition:newP3];
        n = [currentLayer nodeAtPoint:p4 excludeNode:NULL ignoreLocked:FALSE tolerance:0.5];
        if (n) [n correct];
    }
}

- (void)tunniMouseUp:(NSEvent *)theEvent {
    if (tunniSeg) {
        GSLayer *currentLayer = [_editViewController.graphicView activeLayer];
        [[currentLayer undoManager] endUndoGrouping];
        tunniSeg = NULL;
    }
    return [super mouseUp:theEvent];
}

- (void)balance {
    if (![self anyCurvesSelected]) { return; }
    GSLayer *currentLayer = [_editViewController.graphicView activeLayer];
    NSMutableOrderedSet *segments = [[NSMutableOrderedSet alloc] init];
    GSNode *n;
    for (n in [currentLayer selection]) {
        if (![n isKindOfClass:[GSNode class]]) continue;
        // Find the segment for this node and add it to the set
        if ([n type] == OFFCURVE && [[n nextNode] type] == OFFCURVE) {
            // Add prev, this, next, and next next to the set
            NSArray *a = [NSArray arrayWithObjects:[n prevNode], n, [n nextNode], [[n nextNode] nextNode], nil];
            [segments addObject:a];
        } else if ([n type] == OFFCURVE && [[n prevNode] type] == OFFCURVE) {
            // Add prev prev, prev, this and next to the set
            NSArray *a = [NSArray arrayWithObjects:[[n prevNode] prevNode], [n prevNode], n, [n nextNode], nil];
            [segments addObject:a];
        }
    }
    NSArray *seg;
    for (seg in segments) {
        NSPoint p1 = [(GSNode *)seg[0] position];
        NSPoint p2 = [(GSNode *)seg[1] position];
        NSPoint p3 = [(GSNode *)seg[2] position];
        NSPoint p4 = [(GSNode *)seg[3] position];
        NSPoint t = GSIntersectLineLineUnlimited(p1, p2, p3, p4);
        CGFloat sDistance = GSDistance(p1, t);
        CGFloat eDistance = GSDistance(p4, t);
        if (sDistance <= 0 || eDistance <= 0) return;
        CGFloat xPercent = GSDistance(p1, p2) / sDistance;
        CGFloat yPercent = GSDistance(p3, p4) / eDistance;
        if (xPercent > 1 && yPercent >1) return; // Inflection point
        if (xPercent < 0.01 && yPercent <0.01) return; // Inflection point
        CGFloat avg = (xPercent + yPercent)/2.0;
        NSPoint newP2 = GSPointOnLine(p1, t, avg);
        NSPoint newP3 = GSPointOnLine(p4, t, avg);
        [(GSNode *)seg[1] setPosition:newP2];
        [(GSNode *)seg[2] setPosition:newP3];
    }
}

- (void)drawTunniLinesForSegment:(GSPathSegment *)seg upem:(NSUInteger)upem {
    NSPoint p1 = [seg pointAtIndex:0];
    NSPoint p2 = [seg pointAtIndex:1];
    NSPoint p3 = [seg pointAtIndex:2];
    NSPoint p4 = [seg pointAtIndex:3];
    NSPoint tunniPoint = GSIntersectLineLineUnlimited(p1, p2, p3, p4);
    CGFloat sDistance = GSDistance(p1, tunniPoint);
    CGFloat eDistance = GSDistance(p4, tunniPoint);
    CGFloat currentZoom =  [_editViewController.graphicView scale];
    NSColor *col;
    float tunniZoomThreshold = [[NSUserDefaults standardUserDefaults] floatForKey:lineZoomDefault];
    tunniZoomThreshold /= (float)upem;
    tunniZoomThreshold *= 1000.0;
    
    if (currentZoom < tunniZoomThreshold)
        col = [NSColor colorWithCalibratedRed:0 green:0 blue:1 alpha:currentZoom - tunniZoomThreshold / 2.0];
    else
        col = [NSColor blueColor];
    [col set];
    // [self drawHandle:NSMakePoint(0, 0) isSelected:FALSE atPoint:tunniPoint];
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    [paragraphStyle setAlignment:NSTextAlignmentCenter];
    NSDictionary *attrs = @{
        NSFontAttributeName:[NSFont labelFontOfSize:10 / currentZoom],
        NSForegroundColorAttributeName:col,
        NSParagraphStyleAttributeName:paragraphStyle
    };
    if (sDistance > 0) {
        CGFloat xPercent = GSDistance(p1, p2) / sDistance;
        NSAttributedString *label = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%.1f%%", xPercent * 100.0] attributes:attrs];
        // NSAffineTransform *rotate = [NSAffineTransform transform];
        // [rotate rotateByDegrees:GSAngleOfVector(GSSubtractPoints(p2, p1)) / M_PI * 180.0];
        // [rotate concat];
        [label drawAtPoint:GSMiddlePointLine(p1, p2)];
        // [rotate invert];
        // [rotate concat];
    }
    if (eDistance > 0) {
        CGFloat yPercent = GSDistance(p3, p4) / eDistance;
        NSAttributedString *label = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%.1f%%", yPercent * 100.0] attributes:attrs];
        [label drawAtPoint:GSMiddlePointLine(p3, p4)];
    }
    if (sDistance > 0 && eDistance > 0) {
        NSBezierPath *bez = [NSBezierPath bezierPath];
        CGFloat dash[2] = {1.0, 1.0};
        [bez setLineWidth:0.0];
        [bez appendBezierPathWithArcWithCenter:tunniPoint radius:HANDLE_SIZE / currentZoom startAngle:0 endAngle:359];
        [bez stroke];
        [bez closePath];
        [bez setLineDash:dash count:2 phase:0];
        [bez moveToPoint:p2];
        [bez lineToPoint:p3];
        [bez stroke];
    }
}

- (void)drawTunniBackground:(GSLayer* )Layer {
    BOOL doDrawTunni = [drawTunni state] == NSOnState;
    if (!doDrawTunni) return;
    NSUInteger upem = Layer.font.unitsPerEm;
    [self iterateOnCurvedSegmentsOfLayer:Layer withBlock:^(GSPathSegment *seg) {
        [self drawTunniLinesForSegment:seg upem:upem];
    }];
}
@end
