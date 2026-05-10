//
//  TimelineState.m
//  Slate
//

#import "TimelineState.h"

static NSTimeInterval TimelineClampTime(NSTimeInterval value, NSTimeInterval duration)
{
    NSTimeInterval clampedDuration = MAX(duration, 0.0);
    return MIN(MAX(value, 0.0), clampedDuration);
}

static double TimelineSafeFrameRate(double frameRate)
{
    if (!isfinite(frameRate) || frameRate <= 0.0) {
        return 0.0;
    }

    return frameRate;
}

@implementation TimelineState

@synthesize scrubbing = _scrubbing;
@synthesize currentTimecodeString = _currentTimecodeString;

- (void)dealloc
{
    [_currentTimecodeString release];
    [super dealloc];
}

- (instancetype)init
{
    self = [super init];

    if (self) {
        [self resetForDuration:0.0];
    }

    return self;
}

- (NSTimeInterval)currentTime
{
    return _currentTime;
}

- (void)setCurrentTime:(NSTimeInterval)currentTime
{
    _currentTime = TimelineClampTime(currentTime, _duration);
}

- (NSTimeInterval)duration
{
    return _duration;
}

- (void)setDuration:(NSTimeInterval)duration
{
    _duration = MAX(duration, 0.0);
    _currentTime = TimelineClampTime(_currentTime, _duration);
    _selectionStart = TimelineClampTime(_selectionStart, _duration);
    _selectionEnd = TimelineClampTime(_selectionEnd, _duration);

    if (_selectionStart > _selectionEnd) {
        _selectionEnd = _selectionStart;
    }
}

- (NSTimeInterval)selectionStart
{
    return _selectionStart;
}

- (void)setSelectionStart:(NSTimeInterval)selectionStart
{
    _selectionStart = MIN(TimelineClampTime(selectionStart, _duration), _selectionEnd);
}

- (NSTimeInterval)selectionEnd
{
    return _selectionEnd;
}

- (void)setSelectionEnd:(NSTimeInterval)selectionEnd
{
    _selectionEnd = MAX(TimelineClampTime(selectionEnd, _duration), _selectionStart);
}

- (double)frameRate
{
    return _frameRate;
}

- (void)setFrameRate:(double)frameRate
{
    _frameRate = TimelineSafeFrameRate(frameRate);
}

- (void)resetForDuration:(NSTimeInterval)duration
{
    self.duration = duration;
    self.currentTime = 0.0;
    self.selectionStart = 0.0;
    self.selectionEnd = 0.0;
    self.currentTimecodeString = nil;
    self.frameRate = 0.0;
    self.scrubbing = NO;
}

@end
