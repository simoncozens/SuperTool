//
//  SuperTool+Callipers.h
//  SuperTool
//
//  Created by Simon Cozens on 02/05/2017.
//  Copyright © 2017 Simon Cozens. All rights reserved.
//
#import "SCPathTime.h"
#import "SuperTool.h"

@interface SuperTool (Callipers)
- (void)initCallipers;
- (void)drawCallipers:(GSLayer*)layer;
- (void)callipersMouseDown:(NSEvent*)theEvent;
- (void)callipersMouseDragged:(NSEvent*)theEvent;
- (void)callipersMouseUp:(NSEvent*)theEvent;
@end
