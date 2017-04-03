//
//  GSPath+SCPathUtils.h
//  SuperTool
//
//  Created by Simon Cozens on 14/07/2016.
//  Copyright © 2016 Simon Cozens. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <GlyphsCore/GlyphsCore.h>
#import <GlyphsCore/GSNode.h>
#import <GlyphsCore/GSPath.h>
#import <GlyphsCore/GSGeometrieHelper.h>

@interface GSPath (SCPathUtils)
+ (GSPath*)initWithp0:(NSPoint)p0 p1:(NSPoint)p1 p2:(NSPoint)p2 p3:(NSPoint)p3;
+ (GSPath*)initWithPointArray:(NSArray*)pts;
- (CGFloat)distanceFromPoint:(NSPoint)p;
-(void)addOffcurve:(NSPoint)pos;
-(void)addSmooth:(NSPoint)pos;
- (void)append:(GSPath*)source;
- (NSPoint)qPrimeAtTime:(CGFloat)t;
- (NSPoint)qPrimePrimeAtTime:(CGFloat)t;
- (NSPoint)SCPointAtPathTime:(CGFloat)t;
@end
