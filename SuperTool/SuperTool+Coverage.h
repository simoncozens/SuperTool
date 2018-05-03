//
//  SuperTool+Coverage.h
//  SuperTool
//
//  Created by Simon Cozens on 04/12/2017.
//  Copyright © 2017 Simon Cozens. All rights reserved.
//

#import "SuperTool.h"

@interface SuperTool (Coverage)
- (void)initCoverage;
- (void) addCoverageToContextMenu:(NSMenu*)theMenu;
- (void) showCoverage:(GSLayer*)Layer;
@end
