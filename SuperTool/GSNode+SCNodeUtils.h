//
//  GSNode+SCNodeUtils.h
//  SuperTool
//
//  Created by Simon Cozens on 21/05/2016.
//  Copyright © 2016 Simon Cozens. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <GlyphsCore/GlyphsCore.h>
#import <GlyphsCore/GSNode.h>
#import <GlyphsCore/GSPath.h>
#import <GlyphsCore/GSGeometrieHelper.h>

@interface GSNode (SCNodeUtils)

- (GSNode*) nextNode;
- (GSNode*) prevNode;
- (GSNode*) nextOnCurve;
- (GSNode*) prevOnCurve;
- (void) correct;
@end
