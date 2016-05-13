//
//  SCPathTime.h
//  Callipers
//
//  Created by Simon Cozens on 21/12/2015.
//  Copyright © 2015 Simon Cozens. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GlyphsCore/GSPath.h>

@interface SCPathTime : NSObject {
    @public NSInteger segId;
    @public CGFloat t;
    @public GSPath* path;
};

- (SCPathTime*) initWithPath:(GSPath*)p SegId:(NSInteger)i t:(CGFloat)_t;
- (int) compareWith:(SCPathTime*)t2;
- (void) stepTimeBy:(float)step;
- (NSPoint) point;
@end
