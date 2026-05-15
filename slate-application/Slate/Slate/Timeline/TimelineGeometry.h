//
//  TimelineGeometry.h
//  Slate
//
//  Created by Jerry Hale on 4/24/26.
//  Copyright (c) 2026 Jerry Hale. All rights reserved.
//
//  Proprietary and confidential.
//  This file is part of Slate and is not open source software.
//
//  No license is granted to copy, modify, distribute, sublicense, or use this
//  source code except under a written agreement with the copyright holder.
//  Unauthorized use, disclosure, reproduction, or distribution is prohibited.
//

#import <Cocoa/Cocoa.h>

typedef struct TimelineLayoutSnapshot {
    NSRect outerBounds;
    NSRect laneBounds;
    NSRect bodyLaneRect;
    NSRect fullHeightLaneRect;
    NSRect rulerBandRect;
    NSRect rulerTickRect;
    NSRect rulerLabelSafeRect;
    NSRect regionBandRect;
    NSRect laneRect;
    NSRect laneHitRect;
    NSTimeInterval duration;
    NSTimeInterval currentTime;
    NSTimeInterval selectionStart;
    NSTimeInterval selectionEnd;
    double frameRate;
    BOOL collapsedSelection;
} TimelineLayoutSnapshot;

CGFloat TimelineTrackSeekDragThreshold(void);
CGFloat TimelineLaneCornerRadius(void);
CGFloat TimelineRulerLabelWidth(void);
CGFloat TimelineRulerLabelHeight(void);

NSRect TimelineOuterBoundsRect(NSRect bounds);

NSUInteger TimelineRulerMaximumMajorTickCount(void);
NSUInteger TimelineRulerAdaptiveMajorTickCount(TimelineLayoutSnapshot layout);
NSUInteger TimelineRulerAdaptiveMinorTickCount(TimelineLayoutSnapshot layout, NSUInteger majorTickCount);
NSTimeInterval TimelineRulerMajorTickTime(TimelineLayoutSnapshot layout, NSUInteger tickIndex, NSUInteger majorTickCount);

TimelineLayoutSnapshot TimelineMakeLayoutSnapshot(NSRect bounds,
                                                  NSTimeInterval duration,
                                                  NSTimeInterval currentTime,
                                                  double frameRate,
                                                  NSTimeInterval selectionStart,
                                                  NSTimeInterval selectionEnd,
                                                  CGFloat sideReadoutWidth,
                                                  CGFloat contentTopInset);

CGFloat TimelineXPositionForTime(NSTimeInterval time, TimelineLayoutSnapshot layout);
NSTimeInterval TimelineTimeForXPosition(CGFloat xPosition, TimelineLayoutSnapshot layout);
CGFloat TimelinePlayheadCenterX(TimelineLayoutSnapshot layout);

NSRect TimelinePlayheadCapRect(TimelineLayoutSnapshot layout);
NSRect TimelinePlayheadStemRect(TimelineLayoutSnapshot layout);
NSRect TimelinePlayheadVisualRect(TimelineLayoutSnapshot layout);
NSRect TimelinePlayheadHitRect(TimelineLayoutSnapshot layout);
CGPathRef TimelineCreatePlayheadCapPath(NSRect capRect);
NSRect TimelineRegionRectForLayout(TimelineLayoutSnapshot layout);

void TimelineAssertLayoutIntegrity(TimelineLayoutSnapshot layout);
NSString *TimelineRectString(NSRect rect);
