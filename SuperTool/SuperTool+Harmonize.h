//
//  SuperTool+Harmonize.h
//  SuperTool
//
//  Created by Simon Cozens on 21/05/2016.
//  Copyright © 2016 Simon Cozens. All rights reserved.
//

#import "SuperTool.h"

@interface SuperTool (Harmonize)

- (void) addHarmonizeItemToMenu:(NSMenu*)theMenu;
- (void) harmonize:(GSNode*)a3;
- (void) harmonize;
@end
