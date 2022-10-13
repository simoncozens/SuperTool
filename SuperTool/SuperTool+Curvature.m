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

#import "SuperTool+Curvature.h"
#import <AppKit/AppKit.h>

@implementation SuperTool (Curvature)

NSMenuItem *drawCurves;
NSMenuItem *drawCurvesTwo;
NSString *drawCurvesDefault = @"org.simon-cozens.SuperTool.drawingCurvature";

NSMenuItem *drawRainbows;
NSString *drawRainbowsDefault = @"org.simon-cozens.SuperTool.drawingRainbows";

NSMenuItem *drawSpots;
NSString *drawSpotsDefault = @"org.simon-cozens.SuperTool.drawingSpots";

NSMenuItem *fade;
NSString *fadeDefault = @"org.simon-cozens.SuperTool.dontFade";

NSMenuItem *flip;
NSString *flipDefault = @"org.simon-cozens.SuperTool.flipCurves";

NSView *combScaleSliderView;
NSSlider *combScaleSlider;
NSMenuItem *combScaleSliderMenuItem;
const float CombScale = 100;
NSString *combScaleDefault = @"org.simon-cozens.SuperTool.combScale";
static bool inited = false;

- (void)initCurvature {
    if (inited) { return; }
    drawCurves = [[NSMenuItem alloc] initWithTitle:@"Show curvature" action:@selector(displayCurvatureState:) keyEquivalent:@"V"];
    [drawCurves setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
    [drawCurves setRepresentedObject:drawCurvesDefault];

    NSMenuItem *viewMenu = [[[NSApplication sharedApplication] mainMenu] itemAtIndex:6];
    [viewMenu.submenu addItem:drawCurves];

    drawCurvesTwo = [[NSMenuItem alloc] initWithTitle:@"Show curvature" action:@selector(displayCurvatureState:) keyEquivalent:@""];
    [drawCurvesTwo setRepresentedObject:drawCurvesDefault];

    drawRainbows = [[NSMenuItem alloc] initWithTitle:@"Show pen angle rainbows" action:@selector(displayCurvatureState:) keyEquivalent:@""];
    [drawRainbows setRepresentedObject:drawRainbowsDefault];
    drawSpots = [[NSMenuItem alloc] initWithTitle:@"Show discontinuities" action:@selector(displayCurvatureState:) keyEquivalent:@""];
    [drawSpots setRepresentedObject:drawSpotsDefault];
    fade = [[NSMenuItem alloc] initWithTitle:@"Hide pathological curves" action:@selector(displayCurvatureState:) keyEquivalent:@""];
    [fade setRepresentedObject:fadeDefault];

    float cs = [[[NSUserDefaults standardUserDefaults] objectForKey:combScaleDefault]floatValue];
    if (!cs) {
        [[NSUserDefaults standardUserDefaults] setFloat:CombScale forKey:combScaleDefault];
    }
    combScaleSliderView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 200, 25)];
    NSTextField *textField = [[NSTextField alloc] initWithFrame:NSMakeRect(25, 0, 75, 25)];
    [textField setFont:[NSFont menuFontOfSize:0]];
    [textField setStringValue:@"Volume"];
    [textField setBezeled:NO];
    [textField setDrawsBackground:NO];
    [textField setEditable:NO];
    [textField setSelectable:NO];
    combScaleSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(75, 0, 125, 25)];
    [combScaleSlider setMinValue:10];
    [combScaleSlider setMaxValue:200];
    [combScaleSlider setFloatValue:cs];
    [combScaleSlider setTarget:self];
    [combScaleSlider setAction:@selector(setCombScale:)];
    [combScaleSliderView addSubview:textField];
    [combScaleSliderView addSubview:combScaleSlider];
    combScaleSliderMenuItem = [[NSMenuItem alloc] init];
    [combScaleSliderMenuItem setView:combScaleSliderView];
    flip = [[NSMenuItem alloc] initWithTitle:@"Invert curve" action:@selector(displayCurvatureState:) keyEquivalent:@""];
    [flip setRepresentedObject:flipDefault];

    
    if ([[[NSUserDefaults standardUserDefaults] objectForKey:drawCurvesDefault]boolValue]) {
        [drawCurves setState:NSOnState];
        [drawCurvesTwo setState:NSOnState];
    }
    if ([[[NSUserDefaults standardUserDefaults] objectForKey:drawRainbowsDefault]boolValue]) {
        [drawRainbows setState:NSOnState];
    }
    if ([[[NSUserDefaults standardUserDefaults] objectForKey:drawSpotsDefault]boolValue]) {
        [drawSpots setState:NSOnState];
    }
    if (![[[NSUserDefaults standardUserDefaults] objectForKey:fadeDefault]boolValue]) {
        [fade setState:NSOffState];
    } else {
        [fade setState:NSOnState];
    }
    inited = true;
}

- (void)addCurvatureToContextMenu:(NSMenu* )theMenu {
    [theMenu insertItem:drawRainbows atIndex:0];
    [theMenu insertItem:drawSpots atIndex:0];
    [theMenu insertItem:fade atIndex:0];
    [theMenu insertItem:flip atIndex:0];
    [theMenu insertItem:combScaleSliderMenuItem atIndex:0];
    [theMenu insertItem:drawCurvesTwo atIndex:0];
}

// Called when the volume slider is slid.
- (void)setCombScale:(id)sender {
    [[NSUserDefaults standardUserDefaults] setFloat:[combScaleSlider floatValue] forKey:combScaleDefault];
    [_editViewController.graphicView setNeedsDisplay:YES];
}

- (void)displayCurvatureState:(id)sender {
    if ([sender state] == NSOnState) {
        [sender setState:NSOffState];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:[sender representedObject]];
    } else {
        [sender setState:NSOnState];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:[sender representedObject]];
    }
    if (sender == drawCurves) { [drawCurvesTwo setState:[sender state]]; }
    if (sender == drawCurvesTwo) { [drawCurves setState:[sender state]]; }
    [_editViewController.graphicView setNeedsDisplay:YES];
}

- (void)drawCurvatureBackground:(GSLayer *)Layer {
    BOOL doDrawCurves = [drawCurves state] == NSOnState;
    BOOL doDrawRainbows = [drawRainbows state] == NSOnState;
    BOOL doDrawSpots = [drawSpots state] == NSOnState;
    __block float maxC = 0.0;
    if (doDrawCurves) {
        [self iterateOnCurvedSegmentsOfLayer:Layer withBlock:^(GSPathSegment *seg) {
            float thisC = [self maxCurvatureForSegment:seg];
            SCLog(@"Max curve for segments: %f", thisC);
            if (thisC > maxC) maxC = thisC;
        }];
    }
    maxC = MIN(maxC, 1);
    SCLog(@"Max curve for glyph: %f", maxC);
    [self iterateOnCurvedSegmentsOfLayer:Layer withBlock:^(GSPathSegment *seg) {
        if (doDrawCurves) { [self drawCurvatureForSegment:seg maxCurvature:maxC]; }
        if (doDrawRainbows) { [self drawRainbowsForSegment:seg]; }
    }];
    if (doDrawSpots) { [self drawSpotsForLayer:Layer]; }
}

// This draws a circle where there is a discontinuity
- (void)drawSpotsForLayer:(GSLayer *)Layer {
    for (GSPath *p in Layer.shapes) {
        if (![p isKindOfClass:[GSPath class]]) continue;
        for (GSNode *n in p.nodes) {
            // We only want smooth nodes with handles on each side
            if (n.type != CURVE || n.connection != SMOOTH) continue;
            if ([n nextNode].type != OFFCURVE || [n prevNode].type != OFFCURVE) continue;

            // Compute the curvature coming out of the node
            CGFloat cForward = GSDistance(n.position, [n nextNode].position);
            CGFloat dForward = GSDistanceOfPointFromLine([[n nextNode] nextNode].position, n.position, [n nextNode].position);
            CGFloat curvForward = dForward / (cForward * cForward);

            // Compute the curvature going into of the node
            CGFloat cBack = GSDistance(n.position, [n prevNode].position);
            CGFloat dBack = GSDistanceOfPointFromLine([[n prevNode] prevNode].position, n.position, [n prevNode].position);
            CGFloat curvBack = dBack / (cBack * cBack);

            // And show the difference
            CGFloat diff = fabs(curvBack - curvForward) * 1000 * 10;
            SCLog( @"At point %@: diff = %f", n, diff);
            if (diff > 250 || diff < FLT_EPSILON) continue;

            NSColor *pinkish = [NSColor colorWithCalibratedRed:1 green:0.1 blue:0.1 alpha:MAX(1 - diff / 250, 0.5)];
            NSBezierPath *path = [NSBezierPath bezierPath];
            [path appendBezierPathWithArcWithCenter:[n position] radius:diff startAngle:0 endAngle:359];
            [pinkish setFill];
            [path fill];
        }
    }
}

// This draws normals scaled by their curvature
- (void)drawRainbowsForSegment:(GSPathSegment *)seg {
    NSPoint p1 = [seg pointAtIndex:0];
    NSPoint p2 = [seg pointAtIndex:1];
    NSPoint p3 = [seg pointAtIndex:2];
    NSPoint p4 = [seg pointAtIndex:3];
    float t = 0.0;
    CGFloat slen = GSLengthOfSegment(p1, p2, p3, p4);
    while (t <= 1.0) {
        NSPoint normal = normalForT(p1, p2, p3, p4, t);
        CGFloat c = sqrt(curvatureSquaredForT(p1, p2, p3, p4, t));
        CGFloat angle = GSAngleOfVector(normal);
        if (angle <0) { angle = 180 + angle; }
        angle = fmod(angle, 90.0);
        SCLog(@"Normal: %f,%f; angle: %f; modangle: %f", normal.x, normal.y, GSAngleOfVector(normal), angle);
        // 0 -> 1, 1, 0,
        // PI/2 -> 1, 0.5 , 0
        // PI ->  0, 0, 0
        NSColor *col = [NSColor colorWithCalibratedHue:angle / 90.0 saturation:1 brightness:1 alpha:1];

        if (c <= 10.0) {
            [col setStroke];
            NSBezierPath *path = [NSBezierPath bezierPath];
            [path moveToPoint:GSAddPoints(GSPointOnCurve(p1, p2, p3, p4, t), GSScalePoint(normal, -4000 * c))];
            NSPoint end = GSAddPoints(GSPointOnCurve(p1, p2, p3, p4, t), GSScalePoint(normal, 4000 * c));
            [path setLineWidth:0];
            [path lineToPoint:end];
            [path stroke];
        }
        t += 2 / slen;
    }
}

- (float)maxCurvatureForSegment:(GSPathSegment *)seg {
    NSPoint p1 = [seg pointAtIndex:0];
    NSPoint p2 = [seg pointAtIndex:1];
    NSPoint p3 = [seg pointAtIndex:2];
    NSPoint p4 = [seg pointAtIndex:3];
    float maxC = 0.0;
    for (float t = 0.0 ; t <= 1.0; t+= 0.02) {
        CGFloat c = sqrt(curvatureSquaredForT(p1, p2, p3, p4, t));
        if (c > maxC) {
            maxC = c;
        }
    }
    return maxC;
}

// This is the main curvature comb drawing code. You need to have done
// an initial pass to find the max curvature for scaling.

- (void)drawCurvatureForSegment:(GSPathSegment *)seg maxCurvature:(float)maxC {
    NSPoint p1 = [seg pointAtIndex:0];
    NSPoint p2 = [seg pointAtIndex:1];
    NSPoint p3 = [seg pointAtIndex:2];
    NSPoint p4 = [seg pointAtIndex:3];

    // Grab user options
    BOOL alwaysShow = [fade state] == NSOffState;
    float combScale = [[[NSUserDefaults standardUserDefaults] objectForKey:combScaleDefault]floatValue];
    bool flipComb = [[[NSUserDefaults standardUserDefaults] objectForKey:flipDefault]boolValue];

    float t = 0.0;
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:GSPointOnCurve(p1, p2, p3, p4, 0)];

    NSColor *grey = [NSColor colorWithCalibratedRed:0.1 green:0.1 blue:0.1 alpha:0.3];
    NSColor *emptyRed = [NSColor colorWithCalibratedRed:1.0 green:0 blue:0 alpha:alwaysShow ? 0.1 : 0];

    combScale /= 5;
    combScale = combScale * combScale * (flipComb ? -1 : 1);
    combScale /= maxC;
    float thisMaxC = 0.0;
    for (t = 0.0 ; t <= 1.0; t += 0.02) {
        NSPoint normal = normalForT(p1, p2, p3, p4, t);
        CGFloat c = sqrt(curvatureSquaredForT(p1, p2, p3, p4, t));
        if (c > thisMaxC) thisMaxC = c;
        if (c <= 10.0) {
            // Push this point on the curve out along its normal by an amount related to the curvature
            NSPoint end = GSAddPoints(GSPointOnCurve(p1, p2, p3, p4, t), GSScalePoint(normal, combScale * c));
            [path setLineWidth:1];
            [path lineToPoint:end];
        }
    }

    // Fade from grey to light pink depending on tightness of segment
    [[grey blendedColorWithFraction:thisMaxC * 20 ofColor:emptyRed] set];
    [path lineToPoint:GSPointOnCurve(p1, p2, p3, p4, 1)];
    [path curveToPoint:p1 controlPoint1:p3 controlPoint2:p2];
    [path fill];
}

@end
