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


- (void)initCurvature {
    drawCurves = [[NSMenuItem alloc] initWithTitle:@"Show curvature" action:@selector(displayCurvatureState) keyEquivalent:@""];
    if ([[[NSUserDefaults standardUserDefaults] objectForKey:drawCurvesDefault]boolValue]) {
        [drawCurves setState:NSOnState];
    }
}

- (void)addCurvatureToContextMenu:(NSMenu*)theMenu {
    [theMenu insertItem:drawCurves atIndex:0];
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

- (void) drawCurvatureBackground:(GSLayer*)Layer {
    BOOL doDrawCurves = [drawCurves state] == NSOnState;
    if (!doDrawCurves) return;
    [self iterateOnCurvedSegmentsOfLayer:Layer withBlock:^(NSArray* seg) {
        if (doDrawCurves) [self drawCurvatureForSegment:seg];
    }];
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


@end
