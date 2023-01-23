// Copyright 2019 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "SCPathTime.h"
#import <GlyphsCore/GSPath.h>
#import <GlyphsCore/GSPathSegment.h>
#import <GlyphsCore/GSGeometrieHelper.h>

@implementation SCPathTime

- (void)stepTimeBy:(float)step {
    t += step;
    if (t <= 0) { t += 1; segId--; }
    if (t >= 1) { t -= 1; segId++; }
}

/* We do this madness instead of the path's pointAtTime function because
 a) that fails on lines
 b) the path time includes both on-curve and off-curve points (!)
 */
- (NSPoint)point {
    GSPathSegment *seg = path.segments[segId];
    if (seg.countOfPoints == 2) {
        NSPoint p1 = [seg pointAtIndex:0];
        NSPoint p2 = [seg pointAtIndex:1];
        CGFloat x = p1.x + (p2.x - p1.x) * fmod(t, 1.0);
        CGFloat y = p1.y + (p2.y - p1.y) * fmod(t, 1.0);
        // NSLog(@"p1=[%g,%g] at t(%g)= [%g,%g] p2=[%g,%g]", p1.x, p1.y, fmod(t, 1.0), x, y, p2.x, p2.y);
        return NSMakePoint(x, y);
    }
    NSPoint p = GSPointAtTime(
        [seg pointAtIndex:0],
        [seg pointAtIndex:1],
        [seg pointAtIndex:2],
        [seg pointAtIndex:3],
        t
    );
    return p;
}

- (int)compareWith:(SCPathTime *)t2 {
    if (segId < t2->segId) return -1;
    if (segId > t2->segId) return 1;
    return t < t2->t ? -1 : t > t2->t ? 1 : 0;
}

- (SCPathTime *)copy {
    SCPathTime *n = [[SCPathTime alloc] init];
    n->path = self->path;
    n->segId = self->segId;
    n->t = self->t;
    return n;
}

- (SCPathTime *)initWithPath:(GSPath *)p segId:(NSInteger)i t:(CGFloat)_t {
    segId = i;
    t = _t;
    path = p;
    return self;
}

- (SCPathTime *)init {
    segId = NSNotFound;
    t = 0;
    path = NULL;
    return self;
}

+ (CGFloat)segLength:(GSPath *)p segId:(NSInteger)segId from:(CGFloat)t1 to:(CGFloat)t2 {
    GSPathSegment *seg = p.segments[segId];
    if (seg.countOfPoints == 2) {
        NSPoint start = [seg pointAtIndex:0];
        NSPoint end = [seg pointAtIndex:1];
        CGFloat x1 = start.x + (end.x - start.x) * fmod(t1, 1.0);
        CGFloat y1 = start.y + (end.y - start.y) * fmod(t1, 1.0);
        CGFloat x2 = start.x + (end.x - start.x) * fmod(t2, 1.0);
        CGFloat y2 = start.y + (end.y - start.y) * fmod(t2, 1.0);
        return sqrtf((float)(((x1 - x2) * (x1 - x2)) + ((y1 - y2) * (y1 - y2))));
    } else {
        NSPoint o1, o2, o3, o4;
        NSPoint i1 = [seg pointAtIndex:0];
        NSPoint i2 = [seg pointAtIndex:1];
        NSPoint i3 = [seg pointAtIndex:2];
        NSPoint i4 = [seg pointAtIndex:3];
        GSSegmentBetweenPoints(i1, i2, i3, i4, &o1, &o2, &o3, &o4, GSPointAtTime(i1, i2, i3, i4, t1), GSPointAtTime(i1, i2, i3, i4, t2));
        return GSLengthOfSegment(o1, o2, o3, o4);
    }
}

+ (CGFloat)pathLength:(SCPathTime *)start to:(SCPathTime *)end {
    SCPathTime *p1, *p2;
    if (start->segId > end->segId || (start->segId == end->segId && start->t > end->t)) {
        p1 = end; p2 = start;
    } else {
        p1 = start; p2 = end;
    }
    NSInteger segId = p1->segId;
    CGFloat total = 0;
    CGFloat t = p1->t;
    while (segId < p2->segId) {
        total += [self segLength:p1->path segId:segId from:t to:1];
        segId++;
        t = 0;
    }
    total += [self segLength:p1->path segId:segId from:t to:p2->t];
    return total;
}

@end
