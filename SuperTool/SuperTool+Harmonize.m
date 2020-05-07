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

#import "SuperTool+Harmonize.h"
#import "SuperTool+TunniEditing.h"

@implementation SuperTool (Harmonize)
static bool inited = false;

- (void) initHarmonize {
    NSMenuItem* editMenu = [[[NSApplication sharedApplication] mainMenu] itemAtIndex:2];
    NSMenuItem* harmonizeItem = [[NSMenuItem alloc] initWithTitle:@"Harmonize" action:@selector(harmonize) keyEquivalent:@"z"];

    [harmonizeItem setKeyEquivalentModifierMask:NSEventModifierFlagCommand|NSEventModifierFlagOption];
    if (!inited) {
        [editMenu.submenu addItem:harmonizeItem];
        inited = true;
    }
}

- (void) addHarmonizeItemToMenu:(NSMenu*)theMenu {
    
    [theMenu insertItemWithTitle:@"Harmonize" action:@selector(harmonize) keyEquivalent:@"" atIndex:0];
}

- (void) harmonize:(GSNode*)a3 {
    if (![a3 isKindOfClass:[GSNode class]]) return;
    if ([a3 connection] != SMOOTH) return;
    GSNode* a2 = [a3 prevNode]; if ([a2 type] != OFFCURVE) return;
    GSNode* a1 = [a2 prevNode]; if ([a1 type] != OFFCURVE) return;
    GSNode* b1 = [a3 nextNode]; if ([b1 type] != OFFCURVE) return;
    GSNode* b2 = [b1 nextNode]; if ([b2 type] != OFFCURVE) return;
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
    [self balance];
    GSNode* n;
    if ([[currentLayer selection] count] >0) {
        for (n in [currentLayer selection]) {
            [self harmonize:n];
        }
    } else {
        GSPath* p;
        for (p in currentLayer.shapes) {
            if (![p isKindOfClass:[GSPath class]]) continue;
            for (n in [p nodes]) {
                [self harmonize:n];
            }
        }
    }
    [self balance];
}

@end
