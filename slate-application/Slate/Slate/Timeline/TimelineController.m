//
//  TimelineController.m
//  Slate
//

#import "TimelineController.h"

enum
{
    TimelineControllerDragModeNone = 0,
    TimelineControllerDragModePlayhead,
    TimelineControllerDragModeTrackSeek
};

static NSString *TimelineControllerDragModeName(NSInteger dragMode)
{
    switch (dragMode) {
        case TimelineControllerDragModePlayhead:
            return @"playhead";
        case TimelineControllerDragModeTrackSeek:
            return @"track-seek";
        default:
            return @"none";
    }
}

@interface TimelineController ()
{
    NSInteger _dragMode;
    BOOL _scrubSessionActive;
    NSPoint _mouseDownPoint;
    CGFloat _playheadGrabOffsetX;
}
@end

@implementation TimelineController

@synthesize delegate = _delegate;

- (NSInteger)dragModeForPoint:(NSPoint)point layout:(TimelineLayoutSnapshot)layout
{
    NSRect playheadVisualRect = TimelinePlayheadVisualRect(layout);
    NSRect playheadHitRect = TimelinePlayheadHitRect(layout);
    NSRect laneHitRect = layout.laneHitRect;

    if (NSPointInRect(point, playheadVisualRect)) {
        return TimelineControllerDragModePlayhead;
    }

    if (NSPointInRect(point, playheadHitRect)) {
        return TimelineControllerDragModePlayhead;
    }

    if (NSPointInRect(point, laneHitRect)) {
        return TimelineControllerDragModeTrackSeek;
    }

    return TimelineControllerDragModeNone;
}

- (NSString *)hitRegionNameForDragMode:(NSInteger)dragMode
{
    switch (dragMode) {
        case TimelineControllerDragModePlayhead:
            return @"playhead";
        case TimelineControllerDragModeTrackSeek:
            return @"lane-hit";
        default:
            return @"none";
    }
}

- (BOOL)isPlayheadDragging
{
    return _dragMode == TimelineControllerDragModePlayhead;
}

- (BOOL)isPointInInteractiveRegion:(NSPoint)point bounds:(NSRect)bounds layout:(TimelineLayoutSnapshot)layout
{
    return NSPointInRect(point, bounds)
        || NSPointInRect(point, layout.laneHitRect)
        || NSPointInRect(point, TimelinePlayheadHitRect(layout));
}

- (void)handleMouseDownAtPoint:(NSPoint)point layout:(TimelineLayoutSnapshot)layout hasTimelineState:(BOOL)hasTimelineState
{
    if (!hasTimelineState) {
        return;
    }

    _dragMode = TimelineControllerDragModeNone;
    _scrubSessionActive = NO;
    _mouseDownPoint = point;
    _playheadGrabOffsetX = 0.0;
    _dragMode = [self dragModeForPoint:point layout:layout];
    NSString *hitRegion = [self hitRegionNameForDragMode:_dragMode];

    SMTimelineLog(@"Timeline mouseDown region=%@ point=%@ dragMode=%@ startHit=%@ endHit=%@ playheadHit=%@ laneHit=%@",
                  hitRegion,
                  NSStringFromPoint(point),
                  TimelineControllerDragModeName(_dragMode),
                  @"(disabled)",
                  @"(disabled)",
                  TimelineRectString(TimelinePlayheadHitRect(layout)),
                  TimelineRectString(layout.laneHitRect));
    SMTimelineLog(@"Timeline state mouseDown dragMode=%@ scrubActive=%d", TimelineControllerDragModeName(_dragMode), _scrubSessionActive);

    NSTimeInterval pointTime = TimelineTimeForXPosition(point.x, layout);

    if (_dragMode == TimelineControllerDragModePlayhead) {
        _playheadGrabOffsetX = point.x - (TimelinePlayheadCenterX(layout) + TimelinePlayheadCenterXOffset());
        if (_delegate != nil) {
            [_delegate timelineControllerBeginScrubSession:self];
        }
        _scrubSessionActive = YES;
        SMTimelineLog(@"Timeline state beginScrubFromPlayhead dragMode=%@ scrubActive=%d", TimelineControllerDragModeName(_dragMode), _scrubSessionActive);
        if (_delegate != nil) {
            NSTimeInterval grabbedPointTime = TimelineTimeForXPosition(point.x - _playheadGrabOffsetX, layout);
            [_delegate timelineControllerUpdatePlayheadToTime:self time:grabbedPointTime];
        }
    } else if (_dragMode == TimelineControllerDragModeTrackSeek) {
        if (_delegate != nil) {
            [_delegate timelineControllerSeekImmediatelyToTime:self time:pointTime];
            [_delegate timelineControllerSyncFromState:self];
        }
    }
}

- (void)handleMouseDraggedAtPoint:(NSPoint)point layout:(TimelineLayoutSnapshot)layout hasTimelineState:(BOOL)hasTimelineState
{
    if (!hasTimelineState) {
        return;
    }

    SMTimelineLog(@"Timeline mouseDragged point=%@ dragMode=%@ scrubActive=%d",
                  NSStringFromPoint(point),
                  TimelineControllerDragModeName(_dragMode),
                  _scrubSessionActive);

    NSTimeInterval pointTime = TimelineTimeForXPosition(point.x, layout);

    switch (_dragMode) {
        case TimelineControllerDragModePlayhead:
            if (_delegate != nil) {
                NSTimeInterval grabbedPointTime = TimelineTimeForXPosition(point.x - _playheadGrabOffsetX, layout);
                [_delegate timelineControllerUpdatePlayheadToTime:self time:grabbedPointTime];
            }
            break;
        case TimelineControllerDragModeTrackSeek:
            if (!_scrubSessionActive) {
                CGFloat deltaX = point.x - _mouseDownPoint.x;
                CGFloat deltaY = point.y - _mouseDownPoint.y;
                CGFloat dragDistance = hypot(deltaX, deltaY);
                if (dragDistance < TimelineTrackSeekDragThreshold()) {
                    break;
                }
                if (_delegate != nil) {
                    [_delegate timelineControllerBeginScrubSession:self];
                }
                _scrubSessionActive = YES;
                SMTimelineLog(@"Timeline state promoteTrackSeekToScrub dragDistance=%.3f dragMode=%@ scrubActive=%d",
                              dragDistance,
                              TimelineControllerDragModeName(_dragMode),
                              _scrubSessionActive);
            }
            if (_delegate != nil) {
                [_delegate timelineControllerUpdatePlayheadToTime:self time:pointTime];
            }
            break;
        default:
            break;
    }
}

- (void)handleMouseUp
{
    SMTimelineLog(@"Timeline handleMouseUp dragMode=%@ scrubActive=%d",
                  TimelineControllerDragModeName(_dragMode),
                  _scrubSessionActive);
    if (_scrubSessionActive && _delegate != nil) {
        [_delegate timelineControllerEndScrubSession:self];
    }

    _scrubSessionActive = NO;
    _dragMode = TimelineControllerDragModeNone;
    _playheadGrabOffsetX = 0.0;
    SMTimelineLog(@"Timeline state resetAfterMouseUp dragMode=%@ scrubActive=%d",
                  TimelineControllerDragModeName(_dragMode),
                  _scrubSessionActive);
    if (_delegate != nil) {
        [_delegate timelineControllerSyncFromState:self];
    }
}

@end
