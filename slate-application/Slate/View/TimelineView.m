//
//  TimelineView.m
//  Slate
//

#import "TimelineView.h"
#import "TimelineState.h"
#import "../Controller/AppController+Timeline.h"
#import "../Slate/Timeline/TimelineController.h"
#import "../Slate/Timeline/TimelineGeometry.h"
#import "../Slate/Timeline/TimelineRenderer.h"
#import "../Slate/Timeline/TimelineReadouts.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

@interface TimelineView () <TimelineControllerDelegate>
@end

@implementation TimelineView
{
    TimelineController *_controller;
    TimelineRenderer *_renderer;
    TimelineReadouts *_readouts;
}

@synthesize timelineState = _timelineState;
@synthesize usableMovie = _usableMovie;

- (void)commonInit
{
    [self setWantsLayer:YES];
    [self setHidden:NO];
    [self setEnabled:YES];
    [self ensureTimelineControllerIfNeeded];
    [self ensureTimelineRendererIfNeeded];
    [self ensureReadoutLabelsIfNeeded];
    [self layoutReadoutLabels];
    [self updateReadoutLabels];
    [self updatePassiveTimelineLayers];
    [self updateActiveMarkerLayers];
    [self setNeedsDisplay:YES];
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self commonInit];
}

- (BOOL)isOpaque { return NO; }

- (void)setTimelineState:(TimelineState *)timelineState
{
    _timelineState = timelineState;
    [self updatePassiveTimelineLayers];
    [self updateActiveMarkerLayers];
    [self updateReadoutLabels];
    [self setNeedsDisplay:YES];
}

- (void)setUsableMovie:(BOOL)usableMovie
{
    if (_usableMovie == usableMovie) return;

    _usableMovie = usableMovie;
    [self updatePassiveTimelineLayers];
    [self updateActiveMarkerLayers];
    [self updateReadoutLabels];
    [self setNeedsDisplay:YES];
}

- (void)ensureReadoutLabelsIfNeeded
{
    [self ensureTimelineReadoutsIfNeeded];
    [_readouts ensureReadoutLayersIfNeeded];
}

- (void)layoutReadoutLabels
{
    [self ensureTimelineReadoutsIfNeeded];
    [_readouts layoutReadoutLayersForBounds:[self bounds] layout:[self currentLayoutSnapshot]];
}

- (void)updateReadoutLabels
{
    [self ensureTimelineReadoutsIfNeeded];
    [_readouts updateReadoutValuesForLayout:[self currentLayoutSnapshot]
                                     bounds:[self bounds]
                                  usableMovie:_usableMovie
                         currentTimecodeString:[_timelineState currentTimecodeString]];
}

- (void)updateScrubberHeadReadoutPosition
{
    [self ensureTimelineReadoutsIfNeeded];
    [_readouts updateCurrentTimePositionForBounds:[self bounds]
                                           layout:[self currentLayoutSnapshot]
                                    playheadCenterX:[self playheadCenterX]];
}

- (void)syncFromTimelineState
{
    [self updatePassiveTimelineLayers];
    [self updateActiveMarkerLayers];
    [self updateReadoutLabels];
    [self setNeedsDisplay:YES];
    [self displayIfNeeded];
}

- (void)layout
{
    [super layout];
    [self layoutReadoutLabels];
    [self updatePassiveTimelineLayers];
    [self updateActiveMarkerLayers];
    [self updateScrubberHeadReadoutPosition];
}

- (void)dealloc
{
    [_controller release];
    [_renderer release];
    [_readouts release];

    [super dealloc];
}

- (TimelineLayoutSnapshot)currentLayoutSnapshot
{
    [self ensureTimelineReadoutsIfNeeded];
    NSTimeInterval duration = (_timelineState != nil) ? [_timelineState duration] : 0.0;
    NSTimeInterval currentTime = (_timelineState != nil) ? [_timelineState currentTime] : 0.0;
    double frameRate = (_timelineState != nil) ? [_timelineState frameRate] : 0.0;
    NSTimeInterval selectionStart = (_timelineState != nil) ? [_timelineState selectionStart] : 0.0;
    NSTimeInterval selectionEnd = (_timelineState != nil) ? [_timelineState selectionEnd] : 0.0;
    CGFloat sideReadoutWidth = [_readouts gutterLabelWidth];
    CGFloat contentTopInset = [_readouts contentTopInset];
    return TimelineMakeLayoutSnapshot(self.bounds,
                                      duration,
                                      currentTime,
                                      frameRate,
                                      selectionStart,
                                      selectionEnd,
                                      sideReadoutWidth,
                                      contentTopInset);
}

- (void)ensureTimelineRendererIfNeeded
{
    if (_renderer == nil) {
        _renderer = [[TimelineRenderer alloc] init];
    }

    [_renderer attachToHostLayer:[self layer]];
}

- (void)ensureTimelineControllerIfNeeded
{
    if (_controller == nil) {
        _controller = [[TimelineController alloc] init];
    }

    [_controller setDelegate:self];
}

- (void)ensureTimelineReadoutsIfNeeded
{
    if (_readouts == nil) {
        _readouts = [[TimelineReadouts alloc] init];
    }

    [_readouts attachToHostLayer:[self layer]];
}

- (void)updatePassiveTimelineLayers
{
    [self ensureTimelineRendererIfNeeded];
    TimelineLayoutSnapshot layout = [self currentLayoutSnapshot];
    TimelineAssertLayoutIntegrity(layout);
    [_renderer updatePassiveLayersForBounds:[self bounds]
                                     layout:layout
                                 usableMovie:_usableMovie];
}

- (void)updateActiveMarkerLayers
{
    [self ensureTimelineControllerIfNeeded];
    [self ensureTimelineRendererIfNeeded];
    TimelineLayoutSnapshot layout = [self currentLayoutSnapshot];
    [_renderer updatePlayheadLayersForLayout:layout
                             playheadDragging:[_controller isPlayheadDragging]
                                  usableMovie:_usableMovie];
}

- (CGFloat)playheadCenterX
{
    TimelineLayoutSnapshot layout = [self currentLayoutSnapshot];
    return TimelinePlayheadCenterX(layout);
}

- (void)syncAppControllerTransport
{
    AppController *appController = appcontroller();
    [appController syncTransportViewsFromTimelineState];
}

- (void)updatePlayheadTime:(NSTimeInterval)time
{
    [_timelineState setCurrentTime:time];
    [appcontroller() setMovieCurrentTime:[_timelineState currentTime]];
    [self updateActiveMarkerLayers];
    [self updateScrubberHeadReadoutPosition];
    [self syncAppControllerTransport];
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event
{
    #pragma unused(event)
    return YES;
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (BOOL)mouseDownCanMoveWindow
{
    return NO;
}

- (NSView *)hitTest:(NSPoint)point
{
    [self ensureTimelineControllerIfNeeded];
    NSPoint localPoint = [self convertPoint:point fromView:[self superview]];
    BOOL pointInsideControl = NO;
    if (!self.hidden) {
        pointInsideControl = [_controller isPointInInteractiveRegion:localPoint
                                                                       bounds:self.bounds
                                                                       layout:[self currentLayoutSnapshot]];
    }

    if (!pointInsideControl) {
        SMTimelineLog(@"Timeline hitTest miss point=%@ localPoint=%@ hidden=%d bounds=%@",
              NSStringFromPoint(point),
              NSStringFromPoint(localPoint),
              self.hidden,
              TimelineRectString(self.bounds));
        return nil;
    }

    SMTimelineLog(@"Timeline hitTest self point=%@ localPoint=%@ bounds=%@",
                  NSStringFromPoint(point),
                  NSStringFromPoint(localPoint),
                  TimelineRectString(self.bounds));
    return self;
}

- (void)mouseDown:(NSEvent *)event
{
    [self ensureTimelineControllerIfNeeded];
    NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
    SMTimelineLog(@"Timeline mouseDown: point=%@", NSStringFromPoint(point));
    [_controller handleMouseDownAtPoint:point
                                         layout:[self currentLayoutSnapshot]
                               hasTimelineState:(_timelineState != nil)];
}

- (void)mouseDragged:(NSEvent *)event
{
    [self ensureTimelineControllerIfNeeded];
    NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
    SMTimelineLog(@"Timeline mouseDragged: point=%@", NSStringFromPoint(point));
    [_controller handleMouseDraggedAtPoint:point
                                            layout:[self currentLayoutSnapshot]
                                  hasTimelineState:(_timelineState != nil)];
}

- (void)mouseUp:(NSEvent *)event
{
    [self ensureTimelineControllerIfNeeded];
    #pragma unused(event)
    SMTimelineLog(@"Timeline mouseUp:");
    [_controller handleMouseUp];
}

- (void)keyDown:(NSEvent *)event
{
    NSString *characters = [event charactersIgnoringModifiers];
    if ([characters length] == 0) {
        [super keyDown:event];
        return;
    }

    unichar character = [characters characterAtIndex:0];
    BOOL isLeftArrow = (character == NSLeftArrowFunctionKey || [event keyCode] == 123);
    BOOL isRightArrow = (character == NSRightArrowFunctionKey || [event keyCode] == 124);
    BOOL isSpacebar = (character == ' ' || [event keyCode] == 49);

    AppController *appController = appcontroller();
    if (isSpacebar && appController != nil) {
        [appController togglePlayPause:self];
        return;
    }

    if (!isLeftArrow && !isRightArrow) {
        [super keyDown:event];
        return;
    }

    if (_timelineState == nil || !_usableMovie) {
        NSBeep();
        return;
    }

    double frameRate = [appController movieFrameRate];
    if (!isfinite(frameRate) || frameRate <= 0.0) {
        frameRate = 24.0;
    }

    NSTimeInterval step = 1.0 / frameRate;
    NSEventModifierFlags flags = [event modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask;
    if ((flags & NSEventModifierFlagShift) == NSEventModifierFlagShift) {
        step *= 10.0;
    }

    NSTimeInterval duration = MAX([_timelineState duration], 0.0);
    NSTimeInterval currentTime = [_timelineState currentTime];
    NSTimeInterval nextTime = currentTime + (isRightArrow ? step : -step);
    nextTime = MAX(0.0, MIN(duration, nextTime));
    [self updatePlayheadTime:nextTime];
}

- (void)timelineControllerBeginScrubSession:(TimelineController *)controller
{
    #pragma unused(controller)
    TimelineLayoutSnapshot layout = [self currentLayoutSnapshot];
    SMTimelineLog(@"Timeline playhead mouseDown cap=%@ stem=%@ visual=%@ hit=%@",
                  TimelineRectString(TimelinePlayheadCapRect(layout)),
                  TimelineRectString(TimelinePlayheadStemRect(layout)),
                  TimelineRectString(TimelinePlayheadVisualRect(layout)),
                  TimelineRectString(TimelinePlayheadHitRect(layout)));
    SMTimelineLog(@"Timeline playhead layers %@", [_renderer playheadLayerDebugString]);
    [appcontroller() beginTimelineScrubSession];
}

- (void)timelineControllerSeekImmediatelyToTime:(TimelineController *)controller time:(NSTimeInterval)time
{
    #pragma unused(controller)
    [appcontroller() seekTimelineImmediatelyToTime:time];
}

- (void)timelineControllerUpdatePlayheadToTime:(TimelineController *)controller time:(NSTimeInterval)time
{
    #pragma unused(controller)
    [self updatePlayheadTime:time];
}

- (void)timelineControllerEndScrubSession:(TimelineController *)controller
{
    #pragma unused(controller)
    [appcontroller() endTimelineScrubSession];
}

- (void)timelineControllerSyncFromState:(TimelineController *)controller
{
    #pragma unused(controller)
    [self syncFromTimelineState];
}

- (void)drawRect:(NSRect)dirtyRect
{
    #pragma unused(dirtyRect)
}

@end
