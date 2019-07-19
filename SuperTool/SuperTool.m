//
//  SuperTool.m
//  SuperTool
//
//  Created by Simon Cozens on 21/04/2016.
//    Copyright © 2016 Simon Cozens. All rights reserved.
//

// XXX - curvefitter needs rewriting

#import "SuperTool.h"
#import "SuperTool+TunniEditing.h"
#import "SuperTool+Curvature.h"
#import "SuperTool+Harmonize.h"
#import "SuperTool+Simplify.h"
#import "SuperTool+Callipers.h"
#import "SuperTool+Coverage.h"

@implementation SuperTool

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

    [simplifyOK setTarget: self];
    [simplifyOK setAction:@selector(commitSimplify)];
    [simplifyCancel setTarget: self];
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
    [self addTunniToContextMenu:theMenu];
    [self addCurvatureToContextMenu:theMenu];
    [self addCoverageToContextMenu:theMenu];
    [theMenu insertItem:[NSMenuItem separatorItem] atIndex:3];
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
        if ([n isKindOfClass:[GSNode class]] && [n type] != OFFCURVE) {
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
        if (![n isKindOfClass:[GSNode class]]) continue;
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
    [self drawCallipers:Layer];
    [self showCoverage:Layer];
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
