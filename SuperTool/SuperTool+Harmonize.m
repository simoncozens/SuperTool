//
//  SuperTool+Harmonize.m
//  SuperTool
//
//  Created by Simon Cozens on 21/05/2016.
//  Copyright © 2016 Simon Cozens. All rights reserved.
//

#import "SuperTool+Harmonize.h"

@implementation SuperTool (Harmonize)

- (void) addHarmonizeItemToMenu:(NSMenu*)theMenu {
    [theMenu insertItemWithTitle:@"Harmonize" action:@selector(harmonize) keyEquivalent:@"" atIndex:0];
}

- (void) harmonize:(GSNode*)a3 {
    if (![a3 isKindOfClass:[GSNode class]]) return;
    if ([a3 connection] != SMOOTH) return;
    GSNode* a2 = [a3 prevNode]; if ([a2 type] != OFFCURVE) return;
    GSNode* a1 = [a2 prevNode]; if ([a2 type] != OFFCURVE) return;
    GSNode* b1 = [a3 nextNode]; if ([b1 type] != OFFCURVE) return;
    GSNode* b2 = [b1 nextNode]; if ([b1 type] != OFFCURVE) return;
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

@end
