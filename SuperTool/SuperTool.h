/*
 * Copyright 2019 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <Cocoa/Cocoa.h>
#import <GlyphsCore/GSToolSelect.h>
#import <GlyphsCore/GSLayer.h>
#import <GlyphsCore/GSPath.h>
#import <GlyphsCore/GSPathSegment.h>
#import <GlyphsCore/GSGeometrieHelper.h>
#import "GSNode+SCNodeUtils.h"
#import "GSPath+SCPathUtils.h"
#import "SCPathTime.h"

//#define DEBUG_MODE

/* Modes for Callipers */
typedef enum {
    DRAWING_START,
    DRAWING_END
} TOOL_STATE ;

typedef enum {
    MEASURE_CLOSEST,
    MEASURE_CORRESPONDING
} MEASURE_MODE ;


@interface SuperTool : GSToolSelect <NSWindowDelegate> {
    // Tunni lines data storage
    GSPathSegment *tunniSeg;
    bool tunniDraggingLine;
    GSNode *tunniSegP2;
    GSNode *tunniSegP3;

    // Simplify interface
    IBOutlet NSWindow *simplifyWindow;
    __weak IBOutlet NSButton *simplifyOK;
    __weak IBOutlet NSButton *simplifyCancel;
    __weak IBOutlet NSSlider *simplifySlider;
    __weak IBOutlet NSSlider *cornerSlider;

    // Simplify data storage
    NSMutableArray *simplifySegSet;
    NSMutableArray *simplifySpliceSet;
    NSMutableArray *simplifyPathSet;
    NSMutableDictionary *copiedPaths;
    NSMutableDictionary *originalPaths;

    // Callipers
    GSLayer *callipersLayer;
    SCPathTime *segStart1;
    SCPathTime *segStart2;
    SCPathTime *segEnd1;
    SCPathTime *segEnd2;
    long cacheMin;
    long cacheMax;
    long cacheAvg;
    TOOL_STATE tool_state;
    MEASURE_MODE measure_mode;
}

- (BOOL)multipleSegmentsSelected;
- (BOOL)anyCurvesSelected;

- (void)iterateOnCurvedSegmentsOfLayer:(GSLayer *)l withBlock:(void (^)(NSPoint P1, NSPoint P2, NSPoint P3, NSPoint P4))handler;

@end

