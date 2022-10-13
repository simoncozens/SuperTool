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

#import "SuperTool+Coverage.h"
#import "GSLayer+SCLayerUtils.h"

@implementation SuperTool (Coverage)

NSMenuItem *drawCoverage;
NSString *drawCoverageDefault = @"org.simon-cozens.SuperTool.drawingCoverage";

- (void)initCoverage {
    drawCoverage = [[NSMenuItem alloc] initWithTitle:@"Show coverage" action:@selector(displayCoverageState) keyEquivalent:@""];
    if ([[[NSUserDefaults standardUserDefaults] objectForKey:drawCoverageDefault]boolValue]) {
        [drawCoverage setState:NSOnState];
    }
}

- (void)addCoverageToContextMenu:(NSMenu *)theMenu {
    [theMenu insertItem:drawCoverage atIndex:0];
}

- (void)displayCoverageState {
    if ([drawCoverage state] == NSOnState) {
        [drawCoverage setState:NSOffState];
        [[NSUserDefaults standardUserDefaults] setObject:@NO forKey:drawCoverageDefault];
    } else {
        [drawCoverage setState:NSOnState];
        [[NSUserDefaults standardUserDefaults] setObject:@YES forKey:drawCoverageDefault];
    }
    [_editViewController.graphicView setNeedsDisplay:YES];
}

- (void)showCoverage:(GSLayer *)Layer {
    BOOL doDrawCoverage = [drawCoverage state] == NSOnState;
    if (!doDrawCoverage) return;
    float cov = [Layer coverage];
    NSPoint p = NSMakePoint(Layer.width / 2, Layer.glyphMetrics.ascender);
    CGFloat currentZoom = [_editViewController.graphicView scale];

    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    [paragraphStyle setAlignment:NSTextAlignmentCenter];
    NSDictionary *attrs = @{
        NSFontAttributeName: [NSFont labelFontOfSize:10 / currentZoom],
        NSForegroundColorAttributeName: [NSColor redColor],
        NSParagraphStyleAttributeName: paragraphStyle
    };
    NSAttributedString *label = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"Coverage: %.1f%%", cov * 100.0] attributes:attrs];
    [label drawAtPoint:p];
    
}
@end
