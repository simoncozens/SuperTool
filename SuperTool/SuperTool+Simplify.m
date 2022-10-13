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

#import "SuperTool+Simplify.h"
#import "SuperTool+Harmonize.h"
#import "SCCurveFitter.h"

@implementation SuperTool (Simplify)

bool inited = false;
bool willUndo = true;

- (void)initSimplify {
    NSMenuItem *editMenu = [[[NSApplication sharedApplication] mainMenu] itemAtIndex:2];
    NSMenuItem *simplifyItem = [[NSMenuItem alloc] initWithTitle:@"Simplify.." action:@selector(showSimplifyWindow) keyEquivalent:@"s"];
    
    [simplifyItem setKeyEquivalentModifierMask:NSEventModifierFlagCommand|NSEventModifierFlagOption];
    if (!inited) {
        [editMenu.submenu addItem:simplifyItem];
        inited = true;
    }
}
// Ensure selection array contains [s, e]
- (void)addToSelectionSegmentStarting:(GSNode *)s Ending:(GSNode *)e {
    NSMutableArray *a;
    for (a in simplifySegSet) {
        // Are s e already in the array? Go home
        if ([a containsObject:s] && [a containsObject:e]) { return; }
        // Is s the last member of any array? Add e after it.
        if ([a lastObject] == s) {
            [a addObject:e];
            return;
        }
        // Is e the first member of any array? Add s before it.
        if ([a firstObject] == e) {
            [a insertObject:s atIndex:0];
            return;
        }
    }
    // Create a new entry for [s, e]
    NSMutableArray *holder = [[NSMutableArray alloc] initWithObjects:(GSNode *)s, e, nil];
    [simplifySegSet addObject:holder];
}

- (void)showSimplifyWindow {
    // Capture current seg selection
    // A segment is selected if its start and end nodes are selected.
    if (![self multipleSegmentsSelected]) { return; }

    GSLayer *currentLayer = [_editViewController.graphicView activeLayer];
    willUndo = true;
    NSMutableOrderedSet *sel = [currentLayer selection];
    [simplifySegSet removeAllObjects];
    [simplifySpliceSet removeAllObjects];
    [originalPaths removeAllObjects];
    [copiedPaths removeAllObjects];
    [simplifyPathSet removeAllObjects];
    GSNode *n, *nn;
    NSMutableArray *mySelection = [[NSMutableArray alloc] init];
    for (n in sel) {
        if (![n isKindOfClass:[GSNode class]]) continue;
        if ([n type] == OFFCURVE) continue;
        GSPath *rerootedPath;
        GSPath *origPath = [n parentPath];
        GSLayer *layer = [[origPath parent] layer];
        SCLog(@"Looking for %@ in %@", origPath, copiedPaths);
        NSNumber *pindex = [NSNumber numberWithLong:[layer indexOfObjectInShapes:origPath]];
        rerootedPath = [copiedPaths objectForKey:pindex];
        if (!rerootedPath) {
            rerootedPath = [[n parent] copy];
            [copiedPaths setObject:rerootedPath forKey:pindex];
            SCLog(@"Cloned %@ to %@", [n parent], rerootedPath);
        }
        GSNode *rerootedNode = [rerootedPath nodeAtIndex:[[n parentPath] indexOfNode:n]];
        [mySelection addObject:rerootedNode];
        NSValue *rerootedNodeKey = [NSValue valueWithNonretainedObject:rerootedNode];
        [originalPaths setObject:[n parent] forKey:rerootedNodeKey];
        SCLog(@"Associated %@ with %@, dictionary is now %@", [n parent], rerootedNode, originalPaths);
        
    }
    SCLog(@"Sorting selection %@", mySelection);
    [mySelection sortUsingComparator:^ NSComparisonResult(GSNode *a, GSNode *b) {
        GSPath *p = [a parentPath];
        if (p != [b parent]) {
            GSLayer *l = [[p parent] layer];
            return [l indexOfObjectInShapes:p] < [l indexOfObjectInShapes:[b parentPath]] ? NSOrderedAscending : NSOrderedDescending;
        }
        return ([p indexOfNode:a] < [p indexOfNode:b]) ? NSOrderedAscending : NSOrderedDescending;
    }];
    SCLog(@"Selection is now %@", mySelection);
    for (n in mySelection) {
        nn = [n nextOnCurve];
        if ([[nn parentPath] indexOfNode:nn] < [[n parentPath] indexOfNode:n]) {
            continue;
        }
        SCLog(@"Considering %@ (parent: %@, index %ld), next-on-curve: %@", n, [n parentPath], [[n parentPath] indexOfNode:n], nn);
        if ([mySelection containsObject:nn]) {
            [self addToSelectionSegmentStarting:n Ending:nn];
            SCLog(@"Added %@ -> %@ (next), Selection set is %@", n, nn, simplifySegSet);
        }
    }
    NSMutableArray *a;
    for (a in simplifySegSet) {
        GSNode *b = [a firstObject];
        GSNode *e = [a lastObject];
        SCLog(@"Fixing seg set to splice set: %@, %@ (parents: %@, %@)", b, e, [b parent], [e parent]);
        NSUInteger bIndex = [[b parentPath] indexOfNode:b];
        NSUInteger eIndex = [[e parentPath] indexOfNode:e];
        NSRange range = NSMakeRange(bIndex, eIndex-bIndex);
        [simplifySpliceSet addObject:[NSValue valueWithRange:range]];
        // Here we must add the original parent
        SCLog(@"Added range %lu, %lu", (unsigned long)bIndex, (unsigned long)eIndex);
        
        GSPath *originalPath = [originalPaths objectForKey:[NSValue valueWithNonretainedObject:b]];
        if (!originalPath) {
            SCLog(@"I didn't find the original path for %@ in the %@!", b, originalPaths);
            return;
        }
        [simplifyPathSet addObject:originalPath];
    }
    
    // SCLog(@"Splice set is %@", simplifySpliceSet);
    SCLog(@"Path set is %@", simplifyPathSet);
    [[currentLayer undoManager] beginUndoGrouping];
    
    [simplifyWindow makeKeyAndOrderFront:nil];
    [self doSimplify];
}

- (void)doSimplify {
    CGFloat reducePercentage = [simplifySlider maxValue] - [simplifySlider floatValue] + [simplifySlider minValue];
    CGFloat cornerTolerance = [cornerSlider maxValue] - [cornerSlider floatValue] + [cornerSlider minValue];
    int i = 0;
    // SCLog(@"Seg set is %@", simplifySegSet);
    // SCLog(@"copied paths is %@", copiedPaths);
    // SCLog(@"original paths is %@", originalPaths);
    while (i <= [simplifySegSet count] - 1) {
        NSMutableArray *s = simplifySegSet[i];
        GSPath *p = simplifyPathSet[i];
        NSRange startEnd = [simplifySpliceSet[i] rangeValue];
        SCLog(@"Must reduce %@ (%li, %f)", s, [s count], reducePercentage);
        
        if ([[s firstObject] parent]) {
            SCLog(@"ALERT! Parent of %@ is %@", [s firstObject], [[s firstObject] parent]);
        } else {
            SCLog(@"Parent dead before simplifying!");
            return;
        }
        GSPath *newPath = [SCCurveFitter fitCurveToPoints:s withError:reducePercentage cornerTolerance:cornerTolerance maxSegments:240];
        
        NSUInteger newend = [self splice:newPath into:p at:startEnd];
        SCLog(@"New end is %lu",(unsigned long)newend );
        simplifySpliceSet[i] = [NSValue valueWithRange:NSMakeRange(startEnd.location, newend)];
        if (![[s firstObject] parent]) {
            SCLog(@"ALERT! Parent dead after simplifying!");
        }
        // NSUInteger j = startEnd.location;
        // while (j <= startEnd.location + newend) {
        //     [self harmonize:[p nodeAtIndex:j++]];
        // }
        SCLog(@"Simplify splice set = %@", simplifySpliceSet);
        i++;
    }
}

- (NSUInteger)splice:(GSPath *)newPath into:(GSPath *)path at:(NSRange)splice {
    GSNode *n;
    SCLog(@"Splicing into path %@, at range %lu-%lu", path, (unsigned long)splice.location, (unsigned long)NSMaxRange(splice));
    long j = NSMaxRange(splice);
    while (j >= 0 && j >= splice.location) {
        // [path removeNodeAtIndex:j];
        [path removeObjectFromNodesAtIndex:j];
        j--;
    }
    for (n in [newPath nodes]) {
        GSNode *n2 = [n copy];
        [path insertObject:n2 inNodesAtIndex:++j];
        // [path insertNode:n2 atIndex:++j];
    }
    splice.length =  [newPath countOfNodes] -1;
    j = splice.location;
    while (j - splice.location < splice.length ) {
        // [[path nodeAtIndex:j] correct];
        // [self harmonize:[path nodeAtIndex:j]];
        j++;
    }
    // if ([path startNode] && [[path startNode] type] == CURVE) {
    //     [path startNode].type = LINE;
    // }
    // if ([path endNode] && [[path endNode] type] == CURVE) {
    //     [path endNode].type = LINE;
    // }
    if ([[[path nodeAtIndex:j] nextNode] type] != OFFCURVE) {
        [path nodeAtIndex:j].type = LINE;
    }
    if ([[[path nodeAtIndex:splice.location] prevNode] type] != OFFCURVE) {
        [path nodeAtIndex:splice.location].type = LINE;
    }
    [path checkConnections];
    SCLog(@"spliced path: %@", [path nodes]);
    return [newPath countOfNodes] - 1;
}

- (void)commitSimplify {
    willUndo = false;
    [simplifyWindow close];
}

- (void)revertSimplify {
    willUndo= true;
    [simplifyWindow close];
}

- (void)windowWillClose:(NSNotification *)notification {
    if ([notification object] == simplifyWindow) {
        GSLayer *currentLayer = [_editViewController.graphicView activeLayer];
        [[currentLayer undoManager] endUndoGrouping];
        if (willUndo) {
            [[currentLayer undoManager] undo];
        }
    }
}

- (void)windowDidResignKey:(NSNotification *)notification {
    if ([notification object] == simplifyWindow) [simplifyWindow close];
}

@end
