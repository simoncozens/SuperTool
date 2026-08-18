#import <GlyphsCore/GSPathSegment.h>

/** Convert Glyphs 4's GSPathSegment objects to the point-value arrays used by
 * the original SuperTool algorithms. */
static inline NSArray<NSValue *> *STPointsForSegment(GSPathSegment *segment) {
    NSMutableArray<NSValue *> *points = [NSMutableArray arrayWithCapacity:segment.countOfPoints];
    for (NSUInteger index = 0; index < segment.countOfPoints; index++) {
        [points addObject:[NSValue valueWithPoint:[segment pointAtIndex:index]]];
    }
    return points;
}
