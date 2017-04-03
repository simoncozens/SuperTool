//
//  SuperTool+Curvature.h
//  SuperTool
//
//  Created by Simon Cozens on 21/05/2016.
//  Copyright © 2016 Simon Cozens. All rights reserved.
//

#import "SuperTool.h"

@interface SuperTool (Curvature)

- (void)initCurvature;
- (void)addCurvatureToContextMenu:(NSMenu*)theMenu;
- (void)drawCurvatureForSegment:(NSArray*)seg;
- (void) displayCurvatureState:(id)sender;
- (void) drawCurvatureBackground:(GSLayer*)Layer;

@end
