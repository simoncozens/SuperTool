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
- (void)initSimplify;

- (NSUInteger)splice:(GSPath*)newPath into:(GSPath*)path at:(NSRange)splice;

@end
