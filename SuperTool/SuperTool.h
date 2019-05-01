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
#import "SCPathTime.h"

//#define DEBUG_MODE

#ifdef DEBUG_MODE
#define SCLog NSLog
#else
#define SCLog( ... )
#endif


typedef enum {
    DRAWING_START,
    DRAWING_END
} TOOL_STATE ;

typedef enum {
    MEASURE_CLOSEST,
    MEASURE_CORRESPONDING
} MEASURE_MODE ;


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
    __weak IBOutlet NSSlider *cornerSlider;
    
    // Callipers
    GSLayer* callipersLayer;
    SCPathTime* segStart1;
    SCPathTime* segStart2;
    SCPathTime* segEnd1;
    SCPathTime* segEnd2;
    long cacheMin;
    long cacheMax;
    long cacheAvg;
    TOOL_STATE tool_state;
    MEASURE_MODE measure_mode;

}

- (BOOL) multipleSegmentsSelected;
- (BOOL) anyCurvesSelected;

- (void)iterateOnCurvedSegmentsOfLayer:(GSLayer*)l withBlock:(void (^)(NSArray*seg))handler;

@end

