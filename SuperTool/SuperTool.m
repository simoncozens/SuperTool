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

#import "SuperTool.h"
#import "SuperTool+TunniEditing.h"
#import "SuperTool+Curvature.h"
#import "SuperTool+Harmonize.h"
#import "SuperTool+Simplify.h"
#import "SuperTool+Callipers.h"
#import "SuperTool+Coverage.h"
#import <GlyphsCore/GSPath+PenDrawing.h>

static NSImage *_toolBarIcon = nil;

@implementation SuperTool

- (id)init {
    self = [super init];
    NSArray *arrayOfStuff;
    NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];
    if (thisBundle) {
        // The toolbar icon:
        _toolBarIcon = [thisBundle imageForResource:@"ToolbarIconTemplate"];
        [_toolBarIcon setTemplate:YES];
    }

    [self initTunni];
    [self initHarmonize];
    [self initSimplify];
    [self initCurvature];
    [self initCallipers];
    [self initCoverage];

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
    [cornerSlider setTarget:self];
    [cornerSlider setAction:@selector(doSimplify)];

    [simplifyOK setTarget:self];
    [simplifyOK setAction:@selector(commitSimplify)];
    [simplifyCancel setTarget:self];
    [simplifyCancel setAction:@selector(revertSimplify)];
    
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
    [theMenu insertItem:[NSMenuItem separatorItem] atIndex:0];
    [self addTunniToContextMenu:theMenu];
    [self addCurvatureToContextMenu:theMenu];
    [self addCoverageToContextMenu:theMenu];
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

/* Have we clicked on more than one segment? (If we have, we can Simplify) */
- (BOOL)multipleSegmentsSelected {
    GSLayer *currentLayer = [_editViewController.graphicView activeLayer];
    GSNode *n;
    NSOrderedSet *sel = [currentLayer selection];
    for (n in sel) {
        if ([n isKindOfClass:[GSNode class]] && [n type] != OFFCURVE) {
            if ([sel containsObject:[n nextOnCurve]]) return TRUE;
            if ([sel containsObject:[n prevOnCurve]]) return TRUE;
        }
    }
    return FALSE;
}

/* Have we clicked on either a handle or a node with two handles? */
- (BOOL)anyCurvesSelected {
    GSLayer *currentLayer = [_editViewController.graphicView activeLayer];
    GSNode *n;
    for (n in [currentLayer selection]) {
        if (![n isKindOfClass:[GSNode class]]) continue;
        if ([n type] == OFFCURVE && [[n nextNode] type] == OFFCURVE) {
            return TRUE;
        } else if ([n type] == OFFCURVE && [[n prevNode] type] == OFFCURVE) {
            return TRUE;
        }
    }
    return FALSE;
}

- (void)iterateOnCurvedSegmentsOfLayer:(GSLayer *)l withBlock:(void (^)(NSPoint P1, NSPoint P2, NSPoint P3, NSPoint P4))handler {
    for (GSPath *path in l.shapes) {
        if (![path isKindOfClass:[GSPath class]]) continue;
        NSUInteger nodeIdx = 0;
        for (GSNode *node in path.nodes) {
            // SCLog(@"Looking at segment %@", seg);
            if (node.type == CURVE) {
                handler([path positionAtIndex:nodeIdx - 3], [path positionAtIndex:nodeIdx - 2], [path positionAtIndex:nodeIdx - 1], node.position);
            }
            nodeIdx++;
        }
    }
}

- (void)drawBackgroundForLayer:(GSLayer *)layer options:(NSDictionary *)options {
    if ([simplifyWindow isKeyWindow]) {
        [[NSColor secondaryLabelColor] set];
        for (GSPath *p in [copiedPaths allValues]) {
            NSBezierPath *bez = [p bezierPath];
            [bez setLineWidth:0];
            CGFloat dash[2] = {1.0, 1.0};
            [bez setLineDash:dash count:2 phase:0];
            [bez stroke];
        }
    }
    [self drawTunniBackground:layer];
    [self drawCurvatureBackground:layer];
    [self drawCallipers:layer];
    // [super drawBackgroundForLayer:layer];
    [self showCoverage:layer];
}

- (void)mouseDown:(NSEvent *)theEvent {
    if ([theEvent modifierFlags] & NSEventModifierFlagOption) {
        return [self callipersMouseDown:theEvent];
    }
    [self tunniMouseDown:theEvent];
}

- (void)mouseDragged:(NSEvent *)theEvent {
    if ([theEvent modifierFlags] & NSEventModifierFlagOption) {
        return [self callipersMouseDragged:theEvent];
    }
    [self tunniMouseDragged:theEvent];
}

- (void)mouseUp:(NSEvent *)theEvent {
    if ([theEvent modifierFlags] & NSEventModifierFlagOption) {
        return [self callipersMouseUp:theEvent];
    }
    [self tunniMouseUp:theEvent];
}

@end
