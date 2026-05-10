//
//  TimelineView.h
//  Slate
//
//  Created by Jerry Hale on 3/25/26.
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

@class TimelineView;
@class TimelineState;

@interface TimelineView : NSControl
{
    TimelineState *_timelineState;
    BOOL _usableMovie;
}

@property (nonatomic, assign) TimelineState *timelineState;
@property (nonatomic, assign, getter=hasUsableMovie) BOOL usableMovie;

- (void)syncFromTimelineState;
- (CGFloat)playheadCenterX;
- (void)ensureReadoutLabelsIfNeeded;
- (void)layoutReadoutLabels;
- (void)updateReadoutLabels;
- (void)updateScrubberHeadReadoutPosition;

@end
