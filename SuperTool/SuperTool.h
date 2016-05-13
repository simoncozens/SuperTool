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

@interface SuperTool : GSToolSelect {
    NSArray* tunniSeg;
    NSMutableArray* simplifySegSet;
    NSMutableArray* simplifySpliceSet;
    NSMutableArray* simplifyPathSet;
    NSMutableDictionary *copiedPaths;
    NSMutableDictionary *originalPaths;
    bool tunniDraggingLine;
    GSNode* tunniSegP2;
    GSNode* tunniSegP3;
    IBOutlet NSWindow *simplifyWindow;
    __weak IBOutlet NSButton *simplifyDismiss;
    __weak IBOutlet NSSlider *simplifySlider;
}
- (void) displayCurvatureState;
+ (void)SCfitCurveOn1:(NSPoint)On1 off1:(NSPoint*)Off1 Off2:(NSPoint*)Off2 on2:(NSPoint)On2 toOrigiPoints:(NSMutableArray*)OrigiPoints;
+ (NSMutableArray*)chordLengthParameterize:(NSMutableArray*)points;
- (NSUInteger)splice:(GSPath*)newPath into:(GSPath*)path at:(NSRange)splice;
@end

