//
//  TimelineController.h
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
#import "TimelineGeometry.h"

@class TimelineController;

@protocol TimelineControllerDelegate <NSObject>
- (void)timelineControllerBeginScrubSession:(TimelineController *)controller;
- (void)timelineControllerSeekImmediatelyToTime:(TimelineController *)controller time:(NSTimeInterval)time;
- (void)timelineControllerUpdatePlayheadToTime:(TimelineController *)controller time:(NSTimeInterval)time;
- (void)timelineControllerEndScrubSession:(TimelineController *)controller;
- (void)timelineControllerSyncFromState:(TimelineController *)controller;
@end

@interface TimelineController : NSObject

@property (nonatomic, assign) id<TimelineControllerDelegate> delegate;

- (BOOL)isPlayheadDragging;
- (BOOL)isPointInInteractiveRegion:(NSPoint)point bounds:(NSRect)bounds layout:(TimelineLayoutSnapshot)layout;
- (void)handleMouseDownAtPoint:(NSPoint)point layout:(TimelineLayoutSnapshot)layout hasTimelineState:(BOOL)hasTimelineState;
- (void)handleMouseDraggedAtPoint:(NSPoint)point layout:(TimelineLayoutSnapshot)layout hasTimelineState:(BOOL)hasTimelineState;
- (void)handleMouseUp;

@end
