//
//  AppController+Timeline.m
//  Slate
//

#import "AppController+Timeline.h"
#import "AppController+Focus.h"

#import "PlayerView.h"
#import "TimelineState.h"
#import "TimelineView.h"
#import "SMMovie.h"

static BOOL TimelineVerboseRefreshLoggingEnabled(void)
{
    return NO;
}

@interface AppController (TimelinePrivate)
- (void)updateTimelineTimecodeReadoutString;
@end

@implementation AppController (Timeline)

- (void)createScrubberTimeLabelsIfNeeded
{
    SMTimelineLog(@"Timeline createScrubberTimeLabelsIfNeeded begin slider=%@ sliderFrame=%@ containerView=%@",
                  _timelineView,
          NSStringFromRect([_timelineView frame]),
          [_timelineView superview]);
    if (_timelineView == nil) {
        return;
    }

    [_timelineView ensureReadoutLabelsIfNeeded];
    SMTimelineLog(@"Timeline createScrubberTimeLabelsIfNeeded end sliderSuperview=%@",
          [_timelineView superview]);
}

- (void)createTimelineViewIfNeeded
{
    if (_timelineView == nil) {
        SMTimelineLog(@"Timeline createTimelineViewIfNeeded skipped slider=nil");
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
    SMTimelineLog(@"Timeline createTimelineViewIfNeeded end sliderFrame=%@ sliderHidden=%d sliderSuperview=%@ timelineState=%@",
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

    NSView *playerContainerView = [_playerView superview];
    if (playerContainerView == nil) {
        return;
    }

    // Keep the player container filling the top split pane so no stale dead band
    // remains above the player area.
    if (_topView != nil && [playerContainerView superview] == _topView) {
        NSRect desiredContainerFrame = [_topView bounds];
        if (!NSEqualRects([playerContainerView frame], desiredContainerFrame)) {
            [playerContainerView setFrame:desiredContainerFrame];
        }
    }

    NSView *timelineSuperview = [_timelineView superview];
    if (timelineSuperview == nil || timelineSuperview != playerContainerView) {
        return;
    }

    NSRect superBounds = [playerContainerView bounds];
    NSRect timelineFrame = [_timelineView frame];

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
    SMTimelineLog(@"Timeline refreshDuration begin duration(before)=%.3f effectiveDuration=%.3f movie=%@ playerMovie=%@",
          [_timelineState duration],
          [self effectivePlaybackDuration],
          _movie,
          [_playerView movie]);
    [_timelineState setDuration:[self effectivePlaybackDuration]];
    [_timelineView syncFromTimelineState];
    [self updateScrubberTimeLabels];
    SMTimelineLog(@"Timeline refreshDuration end duration(after)=%.3f currentTime=%.3f sliderFrame=%@",
          [_timelineState duration],
          [_timelineState currentTime],
          NSStringFromRect([_timelineView frame]));
}

- (void)syncTimelinePresentationFromState
{
    [self enforcePlayerViewFrameLockedToTimeline];
    [self updateTimelineTimecodeReadoutString];
    if (TimelineVerboseRefreshLoggingEnabled()) {
        SMTimelineLog(@"Timeline syncViews begin slider=%@ sliderHidden=%d sliderFrame=%@ duration=%.3f currentTime=%.3f selectionStart=%.3f selectionEnd=%.3f",
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
    if (TimelineVerboseRefreshLoggingEnabled()) {
        SMTimelineLog(@"Timeline syncViews end sliderFrame=%@",
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
    if (TimelineVerboseRefreshLoggingEnabled()) {
        SMTimelineLog(@"Timeline updateLabels begin hasUsableMovie=%d sliderFrame=%@ duration=%.3f currentTime=%.3f",
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
    if (TimelineVerboseRefreshLoggingEnabled()) {
        SMTimelineLog(@"Timeline updateLabels end sliderFrame=%@",
              NSStringFromRect([_timelineView frame]));
    }
}

- (void)layoutScrubberTimeLabels
{
    SMTimelineLog(@"Timeline layoutLabels begin slider=%@ sliderFrame=%@ sliderSuperview=%@ rawCropTop=%@ rawCropLeft=%@ fps=%@ format=%@",
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
    SMTimelineLog(@"Timeline layoutLabels end sliderFrame=%@",
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
    [self syncTimelinePresentationFromState];
    _updatingTimelineFromPlayback = NO;
    [_playerView refreshSubtitleOverlay];
}

- (void)flushPendingTimelineSeekTimer:(NSTimer *)timer
{
    #pragma unused(timer)

    [self flushPendingTimelineSeek];
}

@end
