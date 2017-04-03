//
//  SuperTool.h
//  SuperTool
//
//  Created by Simon Cozens on 21/04/2016.
//  Copyright © 2016 Simon Cozens. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <GlyphsCore/GlyphsToolDrawProtocol.h>
#import <GlyphsCore/GlyphsToolEventProtocol.h>
#import <GlyphsCore/GlyphsPathPlugin.h>
#import <GlyphsCore/GSToolSelect.h>
#import <GlyphsCore/GSLayer.h>
#import <GlyphsCore/GSPath.h>
#import <GlyphsCore/GSGeometrieHelper.h>
#import "GSNode+SCNodeUtils.h"
#import "GSPath+SCPathUtils.h"

//#define DEBUG_MODE

#ifdef DEBUG_MODE
#define SCLog( ... ) NSLog( ##__VA_ARGS__ )
#else
#define SCLog( ... )
#endif

@interface SuperTool : GSToolSelect <NSWindowDelegate> {
    NSMutableArray* simplifySegSet;
    NSMutableArray* simplifySpliceSet;
    NSMutableArray* simplifyPathSet;
    NSMutableDictionary *copiedPaths;
    NSMutableDictionary *originalPaths;
    NSArray* tunniSeg;
    bool tunniDraggingLine;
    GSNode* tunniSegP2;
    GSNode* tunniSegP3;
    IBOutlet NSWindow *simplifyWindow;
    __weak IBOutlet NSButton *simplifyOK;
    __weak IBOutlet NSButton *simplifyCancel;
    __weak IBOutlet NSSlider *simplifySlider;
}


- (void)iterateOnCurvedSegmentsOfLayer:(GSLayer*)l withBlock:(void (^)(NSArray*seg))handler;

@end

