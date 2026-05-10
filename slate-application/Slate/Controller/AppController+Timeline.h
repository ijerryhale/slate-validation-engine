//
//  AppController+Timeline.h
//  Slate
//
//  Created by Jerry Hale on 3/27/26.
//  Copyright (c) 2026 Jerry Hale. All rights reserved.
//
//  Proprietary and confidential.
//  This file is part of Slate and is not open source software.
//
//  No license is granted to copy, modify, distribute, sublicense, or use this
//  source code except under a written agreement with the copyright holder.
//  Unauthorized use, disclosure, reproduction, or distribution is prohibited.
//

#import "AppController.h"

@interface AppController (Timeline)

- (NSView *)transportContainerView;
- (NSButton *)transportButtonForAction:(SEL)action;
- (NSArray *)transportTimelineFocusOrderViews;
- (void)rebuildTransportTimelineKeyViewLoop;

- (void)createScrubberTimeLabelsIfNeeded;
- (void)createTimelineViewIfNeeded;
- (void)enforcePlayerViewFrameLockedToTimeline;
- (NSTimeInterval)effectivePlaybackDuration;
- (void)refreshTimelineDurationFromPlaybackState;
- (void)syncTransportViewsFromTimelineState;
- (void)updateScrubberTimeLabels;
- (void)layoutScrubberTimeLabels;
- (BOOL)isTimelineScrubbing;
- (SMMovie *)activeMovieForTimeline;
- (void)beginTimelineScrubSession;
- (void)endTimelineScrubSession;
- (void)queueTimelineSeekForCurrentTime;
- (void)flushPendingTimelineSeek;
- (void)seekTimelineImmediatelyToTime:(NSTimeInterval)currentTime;
- (void)updateTimelinePosition:(NSTimer *)timer;
- (void)flushPendingTimelineSeekTimer:(NSTimer *)timer;

@end
