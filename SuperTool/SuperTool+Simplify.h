//
//  SuperTool+Simplify.h
//  SuperTool
//
//  Created by Simon Cozens on 26/05/2016.
//  Copyright © 2016 Simon Cozens. All rights reserved.
//

#import "SuperTool.h"

@interface SuperTool (Simplify)
- (void) showSimplifyWindow;
- (void)commitSimplify;
- (void)revertSimplify;
- (void)doSimplify;

+ (NSMutableArray*)chordLengthParameterize:(NSMutableArray*)points;
- (NSUInteger)splice:(GSPath*)newPath into:(GSPath*)path at:(NSRange)splice;
+ (GSPath*)generateBezier:(NSMutableArray*)points parameters:(NSMutableArray*)u  leftTangent:(NSPoint)leftTangent rightTangent:(NSPoint)rightTangent;
+ (CGFloat)computeMaxErrorForPath:(GSPath*) path ThroughPoints:(NSMutableArray*)points parameters:(NSMutableArray*)parameters returningSplitPoint:(NSUInteger*)splitPoint;
+ (GSPath*)fitCurveThrough:(NSMutableArray*)points leftTangent:(NSPoint)leftTangent rightTangent:(NSPoint)rightTangent precision:(CGFloat)precision;
//+ (void)appendCurve:(GSPath*)source toPath:(GSPath*)target;


@end
