//
//  AppController+Timeline.m
//  Slate
//

#import "AppController+Timeline.h"

#import "PlayerView.h"
#import "TimelineState.h"
#import "TimelineView.h"
#import "SMMovie.h"

static BOOL TimelineTransportVerboseRefreshLoggingEnabled(void)
{
    return NO;
}

static CGFloat TransportGroupInsetForWidth(CGFloat width)
{
    if (width >= 1280.0) {
        return 20.0;
    }
    if (width >= 1100.0) {
        return 14.0;
    }
    return 10.0;
}

static NSButton *TransportButtonForAction(NSView *containerView, SEL action)
{
    if (containerView == nil || action == NULL) {
        return nil;
    }

    for (NSView *subview in [containerView subviews]) {
        if (![subview isKindOfClass:[NSButton class]]) {
            continue;
        }

        NSButton *button = (NSButton *)subview;
        if ([button action] == action) {
            return button;
        }
    }

    return nil;
}

static NSTextField *TransportLabelWithTitle(NSView *containerView, NSString *title)
{
    if (containerView == nil || [title length] == 0) {
        return nil;
    }

    for (NSView *subview in [containerView subviews]) {
        if (![subview isKindOfClass:[NSTextField class]]) {
            continue;
        }

        NSTextField *field = (NSTextField *)subview;
        if ([[field stringValue] isEqualToString:title]) {
            return field;
        }
    }

    return nil;
}

static void SetTransportSubviewFrameIfNeeded(NSView *view, NSRect frame)
{
    if (view == nil) {
        return;
    }

    NSRect integralFrame = NSIntegralRect(frame);
    if (!NSEqualRects([view frame], integralFrame)) {
        [view setFrame:integralFrame];
    }
}

@interface AppController (TimelinePrivate)
- (void)updateTimelineTimecodeReadoutString;
@end

@implementation AppController (Timeline)

- (NSView *)transportContainerView
{
    NSView *timelineContainer = [_timelineView superview];
    if (timelineContainer != nil) {
        return timelineContainer;
    }

    return [_playerView superview];
}

- (NSButton *)transportButtonForAction:(SEL)action
{
    return TransportButtonForAction([self transportContainerView], action);
}

- (NSArray *)transportTimelineFocusOrderViews
{
    NSMutableArray *focusViews = [NSMutableArray array];
    NSView *timelineView = _timelineView;
    NSView *volumeSlider = _volume;
    NSButton *fastBackward = [self transportButtonForAction:@selector(fastBackward:)];
    NSButton *stepBackward = [self transportButtonForAction:@selector(stepBackward:)];
    NSButton *playPause = [self transportButtonForAction:@selector(togglePlayPause:)];
    NSButton *stepForward = [self transportButtonForAction:@selector(stepForward:)];
    NSButton *fastForward = [self transportButtonForAction:@selector(fastForward:)];
    NSButton *timecodeToggle = _timecodeOverlayButton;
    NSView *colorWell = _colorWell;
    NSButton *cropToggle = [self transportButtonForAction:@selector(toggleCropRect:)];

    NSArray *candidates = [NSArray arrayWithObjects:
                           timelineView ?: [NSNull null],
                           volumeSlider ?: [NSNull null],
                           fastBackward ?: [NSNull null],
                           stepBackward ?: [NSNull null],
                           playPause ?: [NSNull null],
                           stepForward ?: [NSNull null],
                           fastForward ?: [NSNull null],
                           timecodeToggle ?: [NSNull null],
                           colorWell ?: [NSNull null],
                           cropToggle ?: [NSNull null],
                           _rawCropLeft ?: [NSNull null],
                           _rawCropTop ?: [NSNull null],
                           _rawCropRght ?: [NSNull null],
                           _rawCropBtm ?: [NSNull null],
                           _views ?: [NSNull null],
                           nil];

    for (id candidate in candidates) {
        if (![candidate isKindOfClass:[NSView class]]) {
            continue;
        }

        NSView *view = (NSView *)candidate;
        if ([view isHidden] || [view window] != _window) {
            continue;
        }
        if ([view isKindOfClass:[NSControl class]] && ![(NSControl *)view isEnabled]) {
            continue;
        }

        [focusViews addObject:view];
    }

    return focusViews;
}

- (void)rebuildTransportTimelineKeyViewLoop
{
    NSArray *focusViews = [self transportTimelineFocusOrderViews];
    if ([focusViews count] < 2) {
        return;
    }

    for (NSUInteger index = 0; index < [focusViews count]; index++) {
        NSView *currentView = [focusViews objectAtIndex:index];
        NSUInteger nextIndex = (index + 1) % [focusViews count];
        NSView *nextView = [focusViews objectAtIndex:nextIndex];
        [currentView setNextKeyView:nextView];
    }
}

- (void)layoutCompactTransportStripInView:(NSView *)transportView timelineFrame:(NSRect)timelineFrame
{
    if (transportView == nil) {
        return;
    }

    NSRect bounds = [transportView bounds];
    CGFloat stripTop = NSMinY(timelineFrame) - 3.0;
    CGFloat stripBottom = NSMinY(bounds) + 4.0;

    if (stripTop <= stripBottom) {
        return;
    }

    NSRect stripRect = NSMakeRect(NSMinX(bounds),
                                  stripBottom,
                                  NSWidth(bounds),
                                  stripTop - stripBottom);
    CGFloat controlCenterY = NSMidY(stripRect);
    CGFloat upperRowCenterY = NSMaxY(stripRect) - 15.0;
    CGFloat lowerRowCenterY = NSMinY(stripRect) + 12.0;
    CGFloat groupInset = TransportGroupInsetForWidth(NSWidth(bounds));

    NSSlider *volume = _volume;
    NSButton *fastBackward = TransportButtonForAction(transportView, @selector(fastBackward:));
    NSButton *stepBackward = TransportButtonForAction(transportView, @selector(stepBackward:));
    NSButton *playPause = TransportButtonForAction(transportView, @selector(togglePlayPause:));
    NSButton *stepForward = TransportButtonForAction(transportView, @selector(stepForward:));
    NSButton *fastForward = TransportButtonForAction(transportView, @selector(fastForward:));

    NSArray *navigationButtons = [NSArray arrayWithObjects:
                                  fastBackward ?: [NSNull null],
                                  stepBackward ?: [NSNull null],
                                  playPause ?: [NSNull null],
                                  stepForward ?: [NSNull null],
                                  fastForward ?: [NSNull null],
                                  nil];

    CGFloat leftGroupCursor = NSMinX(bounds) + groupInset;
    if (volume != nil) {
        NSRect volumeFrame = [volume frame];
        CGFloat preferredHeight = MAX(34.0, MIN(NSHeight(stripRect) - 4.0, NSHeight(volumeFrame)));
        volumeFrame.origin.x = leftGroupCursor;
        volumeFrame.origin.y = floor(controlCenterY - (preferredHeight / 2.0));
        volumeFrame.size.height = preferredHeight;
        SetTransportSubviewFrameIfNeeded(volume, volumeFrame);
        leftGroupCursor = NSMaxX(volumeFrame) + 16.0;
    }

    CGFloat navSpacing = (NSWidth(bounds) >= 1220.0) ? 8.0 : 6.0;
    for (id candidate in navigationButtons) {
        if (![candidate isKindOfClass:[NSButton class]]) {
            continue;
        }
        NSButton *button = (NSButton *)candidate;
        NSRect buttonFrame = [button frame];
        buttonFrame.origin.x = leftGroupCursor;
        buttonFrame.origin.y = floor(controlCenterY - (NSHeight(buttonFrame) / 2.0));
        SetTransportSubviewFrameIfNeeded(button, buttonFrame);
        leftGroupCursor = NSMaxX(buttonFrame) + navSpacing;
    }

    NSTextField *cropLeftLabel = TransportLabelWithTitle(transportView, @"Crop Left:");
    NSTextField *cropTopLabel = TransportLabelWithTitle(transportView, @"Crop Top:");
    NSTextField *cropRightLabel = TransportLabelWithTitle(transportView, @"Crop Right:");
    NSTextField *cropBottomLabel = TransportLabelWithTitle(transportView, @"Crop Bottom:");
    NSButton *cropToggleButton = TransportButtonForAction(transportView, @selector(toggleCropRect:));
    NSColorWell *colorWell = _colorWell;
    NSButton *timecodeToggle = _timecodeOverlayButton;

    CGFloat rightInset = groupInset;
    CGFloat cropValueWidth = MAX(MAX(NSWidth([_rawCropLeft frame]), NSWidth([_rawCropRght frame])),
                                 MAX(NSWidth([_rawCropTop frame]), NSWidth([_rawCropBtm frame])));
    cropValueWidth = MAX(36.0, cropValueWidth);
    CGFloat cropLeftLabelWidth = MAX(NSWidth([cropLeftLabel frame]), NSWidth([cropTopLabel frame]));
    CGFloat cropRightLabelWidth = MAX(NSWidth([cropRightLabel frame]), NSWidth([cropBottomLabel frame]));
    CGFloat pairSpacing = (NSWidth(bounds) >= 1220.0) ? 10.0 : 6.0;
    CGFloat labelSpacing = 4.0;

    CGFloat rightValueX = NSMaxX(bounds) - rightInset - cropValueWidth;
    CGFloat rightLabelX = rightValueX - labelSpacing - cropRightLabelWidth;
    CGFloat leftValueX = rightLabelX - pairSpacing - cropValueWidth;
    CGFloat leftLabelX = leftValueX - labelSpacing - cropLeftLabelWidth;

    NSRect cropLeftLabelFrame = [cropLeftLabel frame];
    cropLeftLabelFrame.origin.x = leftLabelX;
    cropLeftLabelFrame.origin.y = floor(upperRowCenterY - (NSHeight(cropLeftLabelFrame) / 2.0));
    SetTransportSubviewFrameIfNeeded(cropLeftLabel, cropLeftLabelFrame);

    NSRect cropTopLabelFrame = [cropTopLabel frame];
    cropTopLabelFrame.origin.x = leftLabelX;
    cropTopLabelFrame.origin.y = floor(lowerRowCenterY - (NSHeight(cropTopLabelFrame) / 2.0));
    SetTransportSubviewFrameIfNeeded(cropTopLabel, cropTopLabelFrame);

    NSRect cropRightLabelFrame = [cropRightLabel frame];
    cropRightLabelFrame.origin.x = rightLabelX;
    cropRightLabelFrame.origin.y = floor(upperRowCenterY - (NSHeight(cropRightLabelFrame) / 2.0));
    SetTransportSubviewFrameIfNeeded(cropRightLabel, cropRightLabelFrame);

    NSRect cropBottomLabelFrame = [cropBottomLabel frame];
    cropBottomLabelFrame.origin.x = rightLabelX;
    cropBottomLabelFrame.origin.y = floor(lowerRowCenterY - (NSHeight(cropBottomLabelFrame) / 2.0));
    SetTransportSubviewFrameIfNeeded(cropBottomLabel, cropBottomLabelFrame);

    NSRect rawCropLeftFrame = [_rawCropLeft frame];
    rawCropLeftFrame.origin.x = leftValueX;
    rawCropLeftFrame.origin.y = floor(upperRowCenterY - (NSHeight(rawCropLeftFrame) / 2.0));
    rawCropLeftFrame.size.width = cropValueWidth;
    SetTransportSubviewFrameIfNeeded(_rawCropLeft, rawCropLeftFrame);

    NSRect rawCropTopFrame = [_rawCropTop frame];
    rawCropTopFrame.origin.x = leftValueX;
    rawCropTopFrame.origin.y = floor(lowerRowCenterY - (NSHeight(rawCropTopFrame) / 2.0));
    rawCropTopFrame.size.width = cropValueWidth;
    SetTransportSubviewFrameIfNeeded(_rawCropTop, rawCropTopFrame);

    NSRect rawCropRightFrame = [_rawCropRght frame];
    rawCropRightFrame.origin.x = rightValueX;
    rawCropRightFrame.origin.y = floor(upperRowCenterY - (NSHeight(rawCropRightFrame) / 2.0));
    rawCropRightFrame.size.width = cropValueWidth;
    SetTransportSubviewFrameIfNeeded(_rawCropRght, rawCropRightFrame);

    NSRect rawCropBottomFrame = [_rawCropBtm frame];
    rawCropBottomFrame.origin.x = rightValueX;
    rawCropBottomFrame.origin.y = floor(lowerRowCenterY - (NSHeight(rawCropBottomFrame) / 2.0));
    rawCropBottomFrame.size.width = cropValueWidth;
    SetTransportSubviewFrameIfNeeded(_rawCropBtm, rawCropBottomFrame);

    CGFloat iconGap = 6.0;
    CGFloat iconClusterRight = leftLabelX - 10.0;
    if (timecodeToggle != nil) {
        NSRect timecodeFrame = [timecodeToggle frame];
        timecodeFrame.origin.x = floor(iconClusterRight - NSWidth(timecodeFrame));
        timecodeFrame.origin.y = floor(upperRowCenterY - (NSHeight(timecodeFrame) / 2.0));
        SetTransportSubviewFrameIfNeeded(timecodeToggle, timecodeFrame);
        iconClusterRight = NSMinX(timecodeFrame) - iconGap;
    }

    if (cropToggleButton != nil) {
        NSRect cropToggleFrame = [cropToggleButton frame];
        cropToggleFrame.origin.x = floor((timecodeToggle != nil) ? NSMinX([timecodeToggle frame]) : iconClusterRight - NSWidth(cropToggleFrame));
        cropToggleFrame.origin.y = floor(lowerRowCenterY - (NSHeight(cropToggleFrame) / 2.0));
        SetTransportSubviewFrameIfNeeded(cropToggleButton, cropToggleFrame);
        iconClusterRight = MIN(iconClusterRight, NSMinX(cropToggleFrame) - iconGap);
    }

    if (colorWell != nil) {
        NSRect colorWellFrame = [colorWell frame];
        colorWellFrame.origin.x = floor(iconClusterRight - NSWidth(colorWellFrame));
        colorWellFrame.origin.y = floor(upperRowCenterY - (NSHeight(colorWellFrame) / 2.0));
        SetTransportSubviewFrameIfNeeded(colorWell, colorWellFrame);
        iconClusterRight = NSMinX(colorWellFrame) - iconGap;
    }

    // Frame Rate / Current Size / Format label + value geometry is nib-owned.
}

- (void)createScrubberTimeLabelsIfNeeded
{
    SMTimelineLog(@"Timeline transport createScrubberTimeLabelsIfNeeded begin slider=%@ sliderFrame=%@ transportView=%@",
                  _timelineView,
          NSStringFromRect([_timelineView frame]),
          [_timelineView superview]);
    if (_timelineView == nil) {
        return;
    }

    [_timelineView ensureReadoutLabelsIfNeeded];
    SMTimelineLog(@"Timeline transport createScrubberTimeLabelsIfNeeded end sliderSuperview=%@",
          [_timelineView superview]);
}

- (void)createTimelineViewIfNeeded
{
    if (_timelineView == nil) {
        SMTimelineLog(@"Timeline transport createTimelineViewIfNeeded skipped slider=nil");
        return;
    }

    NSRect frame = [_timelineView frame];
    SMTimelineLog(@"Timeline createTimelineViewIfNeeded currentFrame=%@ superviewFrame=%@",
          NSStringFromRect(frame),
          NSStringFromRect([[_timelineView superview] frame]));
    [_timelineView setHidden:NO];
    [_timelineView setTimelineState:_timelineState];
    [[_timelineView superview] addSubview:_timelineView positioned:NSWindowAbove relativeTo:nil];
    [self enforcePlayerViewFrameLockedToTimeline];
    SMTimelineLog(@"Timeline transport createTimelineViewIfNeeded end sliderFrame=%@ sliderHidden=%d sliderSuperview=%@ timelineState=%@",
          NSStringFromRect([_timelineView frame]),
          [_timelineView isHidden],
          [_timelineView superview],
          _timelineState);
}

- (void)enforcePlayerViewFrameLockedToTimeline
{
    if (_playerView == nil || _timelineView == nil) {
        return;
    }

    NSView *transportView = [_playerView superview];
    if (transportView == nil) {
        return;
    }

    // Keep the transport/player container filling the top split pane so no stale
    // dead band remains above the player area.
    if (_topView != nil && [transportView superview] == _topView) {
        NSRect desiredTransportFrame = [_topView bounds];
        if (!NSEqualRects([transportView frame], desiredTransportFrame)) {
            [transportView setFrame:desiredTransportFrame];
        }
    }

    NSView *timelineSuperview = [_timelineView superview];
    if (timelineSuperview == nil || timelineSuperview != transportView) {
        return;
    }

    NSRect superBounds = [transportView bounds];
    NSRect timelineFrame = [_timelineView frame];
    NSRect desiredTimelineFrame = timelineFrame;
    desiredTimelineFrame.origin.x = NSMinX(superBounds);
    desiredTimelineFrame.size.width = NSWidth(superBounds);
    desiredTimelineFrame = NSIntegralRect(desiredTimelineFrame);

    if (!NSEqualRects(timelineFrame, desiredTimelineFrame)) {
        [_timelineView setFrame:desiredTimelineFrame];
        timelineFrame = desiredTimelineFrame;
    }

    [self layoutCompactTransportStripInView:transportView timelineFrame:timelineFrame];

    CGFloat playerTop = NSMaxY(superBounds);
    CGFloat playerBottom = MIN(MAX(NSMaxY(timelineFrame), NSMinY(superBounds)), playerTop);
    NSRect desiredPlayerFrame = NSMakeRect(NSMinX(superBounds),
                                           playerBottom,
                                           NSWidth(superBounds),
                                           MAX(0.0, playerTop - playerBottom));

    if (!NSEqualRects([_playerView frame], desiredPlayerFrame)) {
        [_playerView setFrame:desiredPlayerFrame];
        [_playerView setNeedsLayout:YES];
        [_playerView setNeedsDisplay:YES];
    }
}

- (NSTimeInterval)effectivePlaybackDuration
{
    NSTimeInterval duration = 0.0;

    if (_movie != nil) {
        SMGetTimeInterval([_movie duration], &duration);

        AVPlayerItem *playerItem = [[_movie player] currentItem];
        if (playerItem == nil) {
            playerItem = [_movie playerItem];
        }

        if (playerItem != nil) {
            CMTime playerItemDuration = [playerItem duration];
            if (CMTIME_IS_NUMERIC(playerItemDuration) &&
                !CMTIME_IS_INDEFINITE(playerItemDuration) &&
                CMTIME_COMPARE_INLINE(playerItemDuration, >, kCMTimeZero)) {
                duration = MAX(duration, CMTimeGetSeconds(playerItemDuration));
            }
        }
    }

    return MAX(duration, 0.0);
}

- (void)refreshTimelineDurationFromPlaybackState
{
    SMTimelineLog(@"Timeline transport refreshDuration begin duration(before)=%.3f effectiveDuration=%.3f movie=%@ playerMovie=%@",
          [_timelineState duration],
          [self effectivePlaybackDuration],
          _movie,
          [_playerView movie]);
    [_timelineState setDuration:[self effectivePlaybackDuration]];
    [_timelineView syncFromTimelineState];
    [self updateScrubberTimeLabels];
    SMTimelineLog(@"Timeline transport refreshDuration end duration(after)=%.3f currentTime=%.3f sliderFrame=%@",
          [_timelineState duration],
          [_timelineState currentTime],
          NSStringFromRect([_timelineView frame]));
}

- (void)syncTransportViewsFromTimelineState
{
    [self enforcePlayerViewFrameLockedToTimeline];
    [self rebuildTransportTimelineKeyViewLoop];
    [self updateTimelineTimecodeReadoutString];
    if (TimelineTransportVerboseRefreshLoggingEnabled()) {
        SMTimelineLog(@"Timeline transport syncViews begin slider=%@ sliderHidden=%d sliderFrame=%@ duration=%.3f currentTime=%.3f selectionStart=%.3f selectionEnd=%.3f",
                      _timelineView,
              [_timelineView isHidden],
              NSStringFromRect([_timelineView frame]),
              [_timelineState duration],
              [_timelineState currentTime],
              [_timelineState selectionStart],
              [_timelineState selectionEnd]);
    }
    [_timelineView setUsableMovie:(_hasMovie && _movie != nil)];
    [_timelineView syncFromTimelineState];
    if (TimelineTransportVerboseRefreshLoggingEnabled()) {
        SMTimelineLog(@"Timeline transport syncViews end sliderFrame=%@",
              NSStringFromRect([_timelineView frame]));
    }
}

- (void)updateScrubberTimeLabels
{
    if (_timelineView == nil) {
        return;
    }

    [self updateTimelineTimecodeReadoutString];

    BOOL hasUsableMovie = (_hasMovie && _movie != nil);
    if (TimelineTransportVerboseRefreshLoggingEnabled()) {
        SMTimelineLog(@"Timeline transport updateLabels begin hasUsableMovie=%d sliderFrame=%@ duration=%.3f currentTime=%.3f",
              hasUsableMovie,
              NSStringFromRect([_timelineView frame]),
              [_timelineState duration],
              [_timelineState currentTime]);
    }
    [_timelineView setUsableMovie:hasUsableMovie];
    if ([self isTimelineScrubbing]) {
        [_timelineView updateScrubberHeadReadoutPosition];
    } else {
        [_timelineView updateReadoutLabels];
    }
    if (TimelineTransportVerboseRefreshLoggingEnabled()) {
        SMTimelineLog(@"Timeline transport updateLabels end sliderFrame=%@",
              NSStringFromRect([_timelineView frame]));
    }
}

- (void)layoutScrubberTimeLabels
{
    SMTimelineLog(@"Timeline transport layoutLabels begin slider=%@ sliderFrame=%@ sliderSuperview=%@ rawCropTop=%@ rawCropLeft=%@ fps=%@ format=%@",
                  _timelineView,
          NSStringFromRect([_timelineView frame]),
          [_timelineView superview],
          NSStringFromRect([_rawCropTop frame]),
          NSStringFromRect([_rawCropLeft frame]),
          NSStringFromRect([_frameRate frame]),
          NSStringFromRect([_format frame]));

    if (_timelineView == nil) {
        return;
    }

    [self createTimelineViewIfNeeded];
    [self createScrubberTimeLabelsIfNeeded];
    [self enforcePlayerViewFrameLockedToTimeline];
    [_timelineView layoutReadoutLabels];
    [self rebuildTransportTimelineKeyViewLoop];
    [self updateScrubberTimeLabels];
    SMTimelineLog(@"Timeline transport layoutLabels end sliderFrame=%@",
          NSStringFromRect([_timelineView frame]));
}

- (BOOL)isTimelineScrubbing
{
    return [_timelineState isScrubbing];
}

- (SMMovie *)activeMovieForTimeline
{
    if (_movie != nil) {
        return _movie;
    }

    return [_playerView movie];
}

- (void)updateTimelineTimecodeReadoutString
{
    if (_timelineState == nil) {
        return;
    }

    SMMovie *activeMovie = [self activeMovieForTimeline];
    NSString *timecodeString = nil;
    if (_hasMovie
        && activeMovie != nil
        && [[activeMovie tracksOfMediaType:SMMediaTypeTimeCode] count] > 0) {
        timecodeString = [activeMovie currentTimeCodeString];
    }

    [_timelineState setCurrentTimecodeString:timecodeString];
}

- (void)beginTimelineScrubSession
{
    SMMovie *activeMovie = [self activeMovieForTimeline];
    if ([self isTimelineScrubbing] || activeMovie == nil) {
        SMTimelineLog(@"Timeline beginScrub skipped scrubbing=%d movie=%@", [self isTimelineScrubbing], activeMovie);
        return;
    }

    SMTimelineLog(@"Timeline beginScrub currentTime=%.3f rate=%.3f", _currentTime, [activeMovie rate]);
    [_timelineState setScrubbing:YES];
    _pendingScrubTime = _currentTime;
    _hasPendingScrubSeek = NO;
    _playbackRateBeforeScrub = [activeMovie rate];

    if (_playbackRateBeforeScrub != 0.0f) {
        [activeMovie stop];
    }

    if (_scrubSeekTimer == nil) {
        _scrubSeekTimer = [[NSTimer scheduledTimerWithTimeInterval:(1.0 / 15.0)
                                                            target:self
                                                          selector:@selector(flushPendingTimelineSeekTimer:)
                                                          userInfo:nil
                                                           repeats:YES] retain];
    }
}

- (void)endTimelineScrubSession
{
    SMMovie *activeMovie = [self activeMovieForTimeline];
    if (![self isTimelineScrubbing] || activeMovie == nil) {
        SMTimelineLog(@"Timeline endScrub skipped scrubbing=%d movie=%@", [self isTimelineScrubbing], activeMovie);
        return;
    }

    SMTimelineLog(@"Timeline endScrub currentTime=%.3f pending=%.3f pendingFlag=%d", _currentTime, _pendingScrubTime, _hasPendingScrubSeek);
    [_timelineState setScrubbing:NO];
    [_scrubSeekTimer invalidate];
    [_scrubSeekTimer release];
    _scrubSeekTimer = nil;
    _hasPendingScrubSeek = NO;
    [activeMovie setCurrentTime:SMMakeTimeWithTimeInterval(_currentTime)];

    if (_playbackRateBeforeScrub != 0.0f) {
        [activeMovie setRate:_playbackRateBeforeScrub];
    }

    _playbackRateBeforeScrub = 0.0f;
    [_playerView refreshSubtitleOverlay];
    [self updateScrubberTimeLabels];
}

- (void)queueTimelineSeekForCurrentTime
{
    SMMovie *activeMovie = [self activeMovieForTimeline];
    if (activeMovie == nil) {
        SMTimelineLog(@"Timeline queueSeek skipped movie=nil");
        return;
    }

    if ([self isTimelineScrubbing]) {
        _pendingScrubTime = _currentTime;
        SMTimelineLog(@"Timeline queueSeek scrubbing currentTime=%.3f pendingFlag=%d", _currentTime, _hasPendingScrubSeek);
        if (_hasPendingScrubSeek) {
            _hasPendingScrubSeek = YES;
        } else {
            [activeMovie setCurrentTime:SMMakeTimeWithTimeInterval(_pendingScrubTime)
                              tolerance:SMMakeTimeWithTimeInterval(0.1)];
            [_playerView refreshSubtitleOverlay];
            _hasPendingScrubSeek = YES;
        }
    } else {
        SMTimelineLog(@"Timeline queueSeek immediate currentTime=%.3f", _currentTime);
        [activeMovie setCurrentTime:SMMakeTimeWithTimeInterval(_currentTime)];
        NSTimeInterval landedTime = 0.0;
        SMGetTimeInterval([activeMovie currentTime], &landedTime);
        SMTimelineLog(@"Timeline queueSeek immediate landedTime=%.3f", landedTime);
    }
}

- (void)flushPendingTimelineSeek
{
    SMMovie *activeMovie = [self activeMovieForTimeline];
    if (![self isTimelineScrubbing] || !_hasPendingScrubSeek || activeMovie == nil) {
        SMTimelineLog(@"Timeline flushSeek skipped scrubbing=%d pendingFlag=%d movie=%@", [self isTimelineScrubbing], _hasPendingScrubSeek, activeMovie);
        return;
    }

    SMTimelineLog(@"Timeline flushSeek pendingTime=%.3f", _pendingScrubTime);
    _hasPendingScrubSeek = NO;
    [activeMovie setCurrentTime:SMMakeTimeWithTimeInterval(_pendingScrubTime)
                      tolerance:SMMakeTimeWithTimeInterval(0.1)];
    [_playerView refreshSubtitleOverlay];
}

- (void)seekTimelineImmediatelyToTime:(NSTimeInterval)currentTime
{
    SMMovie *activeMovie = [self activeMovieForTimeline];
    if (activeMovie == nil) {
        SMTimelineLog(@"Timeline immediateSeek skipped movie=nil");
        return;
    }

    if (_currentTime == currentTime) {
        return;
    }

    SMTimelineLog(@"Timeline immediateSeek old=%.3f new=%.3f", _currentTime, currentTime);
    _currentTime = currentTime;
    [_timelineState setCurrentTime:_currentTime];
    [activeMovie setCurrentTime:SMMakeTimeWithTimeInterval(_currentTime)];

    NSTimeInterval landedTime = 0.0;
    SMGetTimeInterval([activeMovie currentTime], &landedTime);
    SMTimelineLog(@"Timeline immediateSeek landedTime=%.3f", landedTime);

    [_playerView refreshSubtitleOverlay];
    [self updateScrubberTimeLabels];
    [_timelineView syncFromTimelineState];
}

- (void)updateTimelinePosition:(NSTimer *)timer
{
    #pragma unused (timer)

    NSTimeInterval currentTime = 0.0;
    SMMovie *activeMovie = [self activeMovieForTimeline];

    if (activeMovie != nil)
        SMGetTimeInterval([activeMovie currentTime], &currentTime);

    if ([self isTimelineScrubbing]) {
        return;
    }

    _updatingTimelineFromPlayback = YES;
    _currentTime = currentTime;
    [_timelineState setCurrentTime:_currentTime];
    [self syncTransportViewsFromTimelineState];
    _updatingTimelineFromPlayback = NO;
    [_playerView refreshSubtitleOverlay];
}

- (void)flushPendingTimelineSeekTimer:(NSTimer *)timer
{
    #pragma unused(timer)

    [self flushPendingTimelineSeek];
}

@end
