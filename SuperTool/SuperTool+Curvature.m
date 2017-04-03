//
//  SuperTool+Curvature.m
//  SuperTool
//
//  Created by Simon Cozens on 21/05/2016.
//  Copyright © 2016 Simon Cozens. All rights reserved.
//

#import "SuperTool+Curvature.h"

@implementation SuperTool (Curvature)

NSMenuItem* drawCurves;
NSString* drawCurvesDefault = @"org.simon-cozens.SuperTool.drawingCurvature";

NSMenuItem* drawRainbows;
NSString* drawRainbowsDefault = @"org.simon-cozens.SuperTool.drawingRainbows";

NSMenuItem* drawSpots;
NSString* drawSpotsDefault = @"org.simon-cozens.SuperTool.drawingSpots";

NSMenuItem* fade;
NSString* fadeDefault = @"org.simon-cozens.SuperTool.dontFade";


- (void)initCurvature {
    drawCurves = [[NSMenuItem alloc] initWithTitle:@"Show curvature" action:@selector(displayCurvatureState:) keyEquivalent:@""];
    [drawCurves setRepresentedObject:drawCurvesDefault];
    drawRainbows = [[NSMenuItem alloc] initWithTitle:@"Show pen angle rainbows" action:@selector(displayCurvatureState:) keyEquivalent:@""];
    [drawRainbows setRepresentedObject:drawRainbowsDefault];
    drawSpots = [[NSMenuItem alloc] initWithTitle:@"Show discontinuities" action:@selector(displayCurvatureState:) keyEquivalent:@""];
    [drawSpots setRepresentedObject:drawSpotsDefault];
    fade = [[NSMenuItem alloc] initWithTitle:@"Hide pathological curves" action:@selector(displayCurvatureState:) keyEquivalent:@""];
    [fade setRepresentedObject:fadeDefault];

    
    if ([[[NSUserDefaults standardUserDefaults] objectForKey:drawCurvesDefault]boolValue]) {
        [drawCurves setState:NSOnState];
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

}

- (void)addCurvatureToContextMenu:(NSMenu*)theMenu {
    [theMenu insertItem:drawRainbows atIndex:0];
    [theMenu insertItem:drawSpots atIndex:0];
    [theMenu insertItem:fade atIndex:0];
    [theMenu insertItem:drawCurves atIndex:0];
}

- (void) displayCurvatureState:(id)sender {
    if ([sender state] == NSOnState) {
        [sender setState:NSOffState];
        [[NSUserDefaults standardUserDefaults] setObject:@NO forKey:[sender representedObject]];
    } else {
        [sender setState:NSOnState];
        [[NSUserDefaults standardUserDefaults] setObject:@YES forKey:[sender representedObject]];
    }
    [_editViewController.graphicView setNeedsDisplay: TRUE];
}

- (void) drawCurvatureBackground:(GSLayer*)Layer {
    BOOL doDrawCurves = [drawCurves state] == NSOnState;
    BOOL doDrawRainbows = [drawRainbows state] == NSOnState;
    BOOL doDrawSpots = [drawSpots state] == NSOnState;

    [self iterateOnCurvedSegmentsOfLayer:Layer withBlock:^(NSArray* seg) {
        if (doDrawCurves) { [self drawCurvatureForSegment:seg]; }
        if (doDrawRainbows) { [self drawRainbowsForSegment:seg]; }
    }];
    if (doDrawSpots) { [self drawSpotsForLayer:Layer]; }
}

- (void) drawSpotsForLayer:(GSLayer*)Layer {
    for (GSPath* p in Layer.paths) {
        for (GSNode* n in p.nodes) {
            if (n.type != CURVE || n.connection != SMOOTH) continue;
            if ([n nextNode].type != OFFCURVE || [n prevNode].type != OFFCURVE) continue;
            CGFloat cForward = GSDistance(n.position, [n nextNode].position);
            CGFloat dForward = GSDistanceOfPointFromLine([[n nextNode] nextNode].position, n.position, [n nextNode].position);
            CGFloat curvForward = dForward/(cForward * cForward);

            CGFloat cBack = GSDistance(n.position, [n prevNode].position);
            CGFloat dBack = GSDistanceOfPointFromLine([[n prevNode] prevNode].position, n.position, [n prevNode].position);
            CGFloat curvBack = dBack / (cBack * cBack);
            CGFloat diff = fabs(curvBack - curvForward) * 1000 * 10;
            SCLog( @"At point %@: diff = %f", n, diff);
            if (diff > 250) continue;
            NSColor* first = [NSColor colorWithCalibratedRed:1 green:0.1 blue:0.1 alpha:MAX(1-diff/250,0.5)];
            NSBezierPath * path = [NSBezierPath bezierPath];
            [path appendBezierPathWithArcWithCenter:[n position] radius:diff startAngle:0 endAngle:359];
            [first setFill];
            [path fill];
        }
    }
}

- (void)drawRainbowsForSegment:(NSArray*)seg {
    NSPoint p1 = [seg[0] pointValue];
    NSPoint p2 = [seg[1] pointValue];
    NSPoint p3 = [seg[2] pointValue];
    NSPoint p4 = [seg[3] pointValue];
    float t=0.0;
    CGFloat slen = GSLengthOfSegment(p1,p2,p3,p4);
    while (t<=1.0) {
        NSPoint normal = normalForT(p1,p2,p3,p4, t);
        CGFloat c = sqrt(curvatureSquaredForT(p1,p2,p3,p4,t));
        CGFloat angle = GSAngleOfVector(normal);
        if (angle <0) { angle = 180+angle; }
        angle = fmod(angle,90.0);
        NSLog(@"Normal: %f,%f; angle: %f; modangle: %f", normal.x,normal.y, GSAngleOfVector(normal), angle);
        // 0 -> 1, 1, 0,
        // PI/2 -> 1, 0.5 ,0
        // PI ->  0, 0, 0
        NSColor* col = [NSColor colorWithCalibratedHue:angle/90.0 saturation:1 brightness:1 alpha:1];

        if (c <= 10.0) {
            [col setStroke];
            NSBezierPath * path = [NSBezierPath bezierPath];
            [path moveToPoint: GSAddPoints(GSPointAtTime(p1,p2,p3,p4, t), GSScalePoint(normal, -4000*c))];
            NSPoint end = GSAddPoints(GSPointAtTime(p1,p2,p3,p4, t), GSScalePoint(normal, 4000*c));
            [path setLineWidth: 0];
            [path lineToPoint: end];
            [path stroke];
        }
        t+= 2/slen;
    }
}

- (void)drawCurvatureForSegment:(NSArray*)seg {
    NSPoint p1 = [seg[0] pointValue];
    NSPoint p2 = [seg[1] pointValue];
    NSPoint p3 = [seg[2] pointValue];
    NSPoint p4 = [seg[3] pointValue];
    BOOL alwaysShow = [fade state] == NSOffState;

    float t=0.0;
    NSBezierPath * path = [NSBezierPath bezierPath];
    [path moveToPoint: GSPointAtTime(p1,p2,p3,p4, 0)];
    NSColor* first = [NSColor colorWithCalibratedRed:0.1 green:0.1 blue:0.1 alpha:0.3];
    NSColor* emptyRed = [NSColor colorWithCalibratedRed:1.0 green:0 blue:0 alpha:alwaysShow?0.1:0];
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


@end
