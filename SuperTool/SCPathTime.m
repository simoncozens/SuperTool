//
//  SCPathTime.m
//  Callipers
//
//  Created by Simon Cozens on 21/12/2015.
//  Copyright © 2015 Simon Cozens. All rights reserved.
//

#import "SCPathTime.h"
#import <GlyphsCore/GSGeometrieHelper.h>

@implementation SCPathTime

- (void) stepTimeBy:(float)step {
    t += step;
    if (t <= 0) { t += 1; segId--; }
    if (t >= 1) { t -= 1; segId++; }
}

/* We do this madness instead of the path's pointAtTime function because
 a) that fails on lines
 b) the path time includes both on-curve and off-curve points (!)
 */
- (NSPoint) point {
    NSArray* seg = path.segments[segId];
    if ([ seg count] == 2) {
        NSPoint p1 = [[seg objectAtIndex:0] pointValue];
        NSPoint p2 = [[seg objectAtIndex:1] pointValue];
        CGFloat x = p1.x + (p2.x-p1.x)*fmod(t,1.0);
        CGFloat y = p1.y + (p2.y-p1.y)*fmod(t,1.0);
        // NSLog(@"p1=[%g,%g] at t(%g)= [%g,%g] p2=[%g,%g]",p1.x,p1.y,fmod(t,1.0),x,y,p2.x,p2.y);
        return NSMakePoint(x, y);
    }
    NSPoint p = GSPointAtTime(
                              [[seg objectAtIndex:0] pointValue],
                              [[seg objectAtIndex:1] pointValue],
                              [[seg objectAtIndex:2] pointValue],
                              [[seg objectAtIndex:3] pointValue],
                              t);
    return p;
}

- (int) compareWith:(SCPathTime*)t2 {
    if (segId < t2->segId) return -1;
    if (segId > t2->segId) return 1;
    return t < t2->t ? -1 : t > t2->t ? 1 : 0;
}

- (SCPathTime*) copy {
    SCPathTime* n = [[SCPathTime alloc] init];
    n->path = self->path;
    n->segId = self->segId;
    n->t = self->t;
    return n;
}

- (SCPathTime*) initWithPath:(GSPath*)p SegId:(NSInteger)i t:(CGFloat)_t {
    segId = i;
    t = _t;
    path = p;
    return self;
}

- (SCPathTime*) init {
    segId = NSNotFound;
    t = 0;
    path = NULL;
    return self;
}


@end
