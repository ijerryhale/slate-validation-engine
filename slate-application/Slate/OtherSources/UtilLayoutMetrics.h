//
//  UtilLayoutMetrics.h
//  Slate
//
//  Created by Jerry Hale on 4/25/26.
//  Copyright (c) 2026 Jerry Hale. All rights reserved.
//
//  Proprietary and confidential.
//  This file is part of Slate and is not open source software.
//
//  No license is granted to copy, modify, distribute, sublicense, or use this
//  source code except under a written agreement with the copyright holder.
//  Unauthorized use, disclosure, reproduction, or distribution is prohibited.
//

#ifndef UtilLayoutMetrics_h
#define UtilLayoutMetrics_h

#import <Cocoa/Cocoa.h>

static inline CGFloat SlateWorkspacePrimaryPaneLeadingInset(void) { return 14.0; }
static inline CGFloat SlateWorkspacePrimaryPaneTableAnchorX(void) { return 14.0; }
// Shared hard handoff used by Chapter + Track rail choreography near the
// class-2 -> class-1 transition window.
// With <= threshold held to readiness-only, inspector+readiness appears at
// threshold+1 (currently 1295).
static inline CGFloat SlateWorkspaceRailBreakWidthClass2To1(void) { return 1294.0; }
// Keep Chapter/Track top choreography aligned with Package rail baseline.
static inline CGFloat SlateWorkspacePrimaryPaneTableAnchorTopY(void) { return 323.0; }
static inline CGFloat SlateWorkspaceTopInset(void) { return 24.0; }
static inline CGFloat SlateWorkspaceTrailingInsetMinimum(void) { return 8.0; }
static inline CGFloat SlateWorkspaceSectionLabelHeight(void) { return 16.0; }
static inline CGFloat SlateWorkspaceSectionLabelGap(void) { return 6.0; }
static inline CGFloat SlateWorkspaceSectionLabelYOffset(void) { return 4.0; }
static inline CGFloat SlateWorkspaceMinimumContentHeight(void) { return 120.0; }
// Allow horizontal stretch beyond the class-2 design width so table views can
// surface more content, then freeze and center once that headroom is exhausted.
static inline CGFloat SlateWorkspaceHorizontalExpansionAllowance(void) { return 180.0; }
// Allow bounded vertical growth for dense pane content, then keep centered.
static inline CGFloat SlateWorkspaceVerticalExpansionAllowance(void) { return 200.0; }
static inline NSRect SlateWorkspaceCenteredContentEnvelope(NSRect rootBounds,
                                                           CGFloat designWidth,
                                                           CGFloat designHeight,
                                                           CGFloat extraWidthAllowance,
                                                           CGFloat extraHeightAllowance)
{
    CGFloat maxWidth = MAX(1.0, designWidth + MAX(0.0, extraWidthAllowance));
    CGFloat maxHeight = MAX(1.0, designHeight + MAX(0.0, extraHeightAllowance));
    CGFloat envelopeWidth = MIN(NSWidth(rootBounds), maxWidth);
    CGFloat envelopeHeight = MIN(NSHeight(rootBounds), maxHeight);
    CGFloat originX = NSMinX(rootBounds) + floor((NSWidth(rootBounds) - envelopeWidth) * 0.5);
    CGFloat originY = NSMinY(rootBounds) + floor((NSHeight(rootBounds) - envelopeHeight) * 0.5);
    return NSMakeRect(originX, originY, envelopeWidth, envelopeHeight);
}

#endif /* UtilLayoutMetrics_h */
