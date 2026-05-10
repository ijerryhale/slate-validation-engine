//
//  TimelineReadouts.m
//  Slate
//

#import "TimelineReadouts.h"
#import <QuartzCore/QuartzCore.h>

static NSString *TimelineClockReadoutString(NSTimeInterval timeInterval)
{
    long long totalSeconds = llround(MAX(timeInterval, 0.0));
    long long hours = totalSeconds / 3600;
    long long minutes = (totalSeconds % 3600) / 60;
    long long seconds = totalSeconds % 60;

    return [NSString stringWithFormat:@"%02lld:%02lld:%02lld", hours, minutes, seconds];
}

static NSString *TimelineFrameClockReadoutString(NSTimeInterval timeInterval, double frameRate)
{
    double clampedValue = MAX(timeInterval, 0.0);
    long framesPerSecond = (isfinite(frameRate) && frameRate > 0.0) ? lround(frameRate) : 30;
    framesPerSecond = MAX(framesPerSecond, 1);
    double effectiveFrameRate = (isfinite(frameRate) && frameRate > 0.0) ? frameRate : (double)framesPerSecond;
    long long totalFrames = llround(clampedValue * effectiveFrameRate);
    totalFrames = MAX(totalFrames, 0LL);

    long long wholeSeconds = totalFrames / framesPerSecond;
    long frame = (long)(totalFrames % framesPerSecond);
    long long hours = wholeSeconds / 3600;
    long long minutes = (wholeSeconds % 3600) / 60;
    long long seconds = wholeSeconds % 60;

    return [NSString stringWithFormat:@"%02lld:%02lld:%02lld.%02ld", hours, minutes, seconds, frame];
}

static NSFont *TimelineSideReadoutFont(void)
{
    NSFont *font = [NSFont monospacedSystemFontOfSize:16.0 weight:NSFontWeightRegular];
    if (font == nil) {
        font = [NSFont fontWithName:@"Menlo-Regular" size:16.0];
    }
    return font;
}

static NSFont *TimelineHeadReadoutFont(void)
{
    NSFont *font = [NSFont monospacedSystemFontOfSize:12.0 weight:NSFontWeightRegular];
    if (font == nil) {
        font = [NSFont fontWithName:@"Menlo-Regular" size:12.0];
    }
    return font;
}

static NSColor *TimelineSideReadoutTextColor(void)
{
    return [NSColor colorWithCalibratedWhite:1.0 alpha:0.92];
}

static NSColor *TimelineHeadReadoutTextColor(void)
{
    return [NSColor colorWithCalibratedWhite:1.0 alpha:0.94];
}

static NSColor *TimelineDisabledReadoutTextColor(void)
{
    return [NSColor colorWithCalibratedWhite:1.0 alpha:0.50];
}

static NSString *TimelineCATextAlignmentMode(NSTextAlignment alignment)
{
    switch (alignment) {
        case NSTextAlignmentLeft:
            return kCAAlignmentLeft;
        case NSTextAlignmentRight:
            return kCAAlignmentRight;
        default:
            return kCAAlignmentCenter;
    }
}

static NSDictionary *TimelineLayerDisabledActions(void)
{
    static NSDictionary *actions = nil;
    if (actions == nil) {
        actions = [[NSDictionary alloc] initWithObjectsAndKeys:
                   [NSNull null], @"bounds",
                   [NSNull null], @"frame",
                   [NSNull null], @"position",
                   [NSNull null], @"contents",
                   [NSNull null], @"hidden",
                   [NSNull null], @"cornerRadius",
                   [NSNull null], @"borderWidth",
                   [NSNull null], @"borderColor",
                   [NSNull null], @"backgroundColor",
                   nil];
    }
    return actions;
}

static CGFloat TimelineReadoutWidthForSample(NSString *sample, NSFont *font)
{
    NSSize textSize = [sample sizeWithAttributes:[NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName]];
    return ceil(textSize.width) + 4.0;
}

static CGFloat TimelineSideReadoutLabelWidth(void)
{
    static CGFloat cachedWidth = 0.0;
    if (cachedWidth <= 0.0) {
        cachedWidth = TimelineReadoutWidthForSample(@"-88:88:88", TimelineSideReadoutFont());
    }
    return cachedWidth;
}

static CGFloat TimelineHeadReadoutLabelWidth(void)
{
    static CGFloat cachedWidth = 0.0;
    if (cachedWidth <= 0.0) {
        cachedWidth = TimelineReadoutWidthForSample(@"88:88:88.88", TimelineHeadReadoutFont());
    }
    return cachedWidth;
}

static CGFloat TimelineSideReadoutLabelHeight(void)
{
    static CGFloat cachedHeight = 0.0;
    if (cachedHeight <= 0.0) {
        NSFont *font = TimelineSideReadoutFont();
        NSSize textSize = [@"88:88:88" sizeWithAttributes:[NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName]];
        cachedHeight = ceil(textSize.height);
    }
    return cachedHeight;
}

static CGFloat TimelineHeadReadoutLabelHeight(void)
{
    static CGFloat cachedHeight = 0.0;
    if (cachedHeight <= 0.0) {
        NSFont *font = TimelineHeadReadoutFont();
        NSSize textSize = [@"88:88:88.88" sizeWithAttributes:[NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName]];
        cachedHeight = ceil(textSize.height);
    }
    return cachedHeight;
}

static CATextLayer *TimelineCreateReadoutLabel(NSTextAlignment alignment, CGFloat fontSize)
{
    CATextLayer *label = [[CATextLayer alloc] init];
    [label setHidden:NO];
    [label setWrapped:NO];
    [label setTruncationMode:kCATruncationNone];
    [label setAlignmentMode:TimelineCATextAlignmentMode(alignment)];
    [label setFontSize:fontSize];
    [label setForegroundColor:[[NSColor controlTextColor] CGColor]];
    CGFloat scale = [[NSScreen mainScreen] backingScaleFactor];
    if (scale <= 0.0) {
        scale = 2.0;
    }
    [label setContentsScale:scale];
    return label;
}

@interface TimelineReadouts ()
{
    CALayer *_hostLayer;
    CATextLayer *_movieTimeRemainingLabel;
    CATextLayer *_movieDurationLabel;
    CATextLayer *_scrubberHeadTimeLabel;
}
@end

@implementation TimelineReadouts

- (void)dealloc
{
    [_movieTimeRemainingLabel removeFromSuperlayer];
    [_movieDurationLabel removeFromSuperlayer];
    [_scrubberHeadTimeLabel removeFromSuperlayer];

    [_movieTimeRemainingLabel release];
    [_movieDurationLabel release];
    [_scrubberHeadTimeLabel release];

    [super dealloc];
}

- (CGFloat)sideReadoutLabelWidth
{
    return TimelineSideReadoutLabelWidth();
}

- (CGFloat)contentTopInset
{
    return 23.0;
}

- (void)attachToHostLayer:(CALayer *)hostLayer
{
    _hostLayer = hostLayer;
}

- (void)ensureLayerAttached:(CALayer *)layer
{
    if (layer == nil || _hostLayer == nil) {
        return;
    }

    if (layer.superlayer != _hostLayer) {
        [layer removeFromSuperlayer];
        [_hostLayer addSublayer:layer];
    }
}

- (void)ensureReadoutLayersIfNeeded
{
    if (_hostLayer == nil) {
        return;
    }

    if (_movieTimeRemainingLabel == nil) {
        _movieTimeRemainingLabel = TimelineCreateReadoutLabel(NSTextAlignmentCenter, [TimelineSideReadoutFont() pointSize]);
        [_movieTimeRemainingLabel setActions:TimelineLayerDisabledActions()];
        [_movieTimeRemainingLabel setZPosition:20.0];
    }
    [self ensureLayerAttached:_movieTimeRemainingLabel];

    if (_movieDurationLabel == nil) {
        _movieDurationLabel = TimelineCreateReadoutLabel(NSTextAlignmentCenter, [TimelineSideReadoutFont() pointSize]);
        [_movieDurationLabel setActions:TimelineLayerDisabledActions()];
        [_movieDurationLabel setZPosition:20.0];
    }
    [self ensureLayerAttached:_movieDurationLabel];

    if (_scrubberHeadTimeLabel == nil) {
        _scrubberHeadTimeLabel = TimelineCreateReadoutLabel(NSTextAlignmentCenter, [TimelineHeadReadoutFont() pointSize]);
        [_scrubberHeadTimeLabel setActions:TimelineLayerDisabledActions()];
        [_scrubberHeadTimeLabel setZPosition:20.0];
    }
    [self ensureLayerAttached:_scrubberHeadTimeLabel];

    NSFont *sideFont = TimelineSideReadoutFont();
    NSFont *headFont = TimelineHeadReadoutFont();
    // Keep elapsed and duration exactly matched in font + size.
    [_movieTimeRemainingLabel setFont:[sideFont fontName]];
    [_movieTimeRemainingLabel setFontSize:[sideFont pointSize]];
    [_movieDurationLabel setFont:[sideFont fontName]];
    [_movieDurationLabel setFontSize:[sideFont pointSize]];
    // Keep current-time at its existing size while using monospaced font.
    [_scrubberHeadTimeLabel setFont:[headFont fontName]];
    [_scrubberHeadTimeLabel setFontSize:[headFont pointSize]];

    [_movieTimeRemainingLabel setAlignmentMode:kCAAlignmentCenter];
    [_movieDurationLabel setAlignmentMode:kCAAlignmentCenter];
    [_movieTimeRemainingLabel setForegroundColor:[TimelineSideReadoutTextColor() CGColor]];
    [_movieDurationLabel setForegroundColor:[TimelineSideReadoutTextColor() CGColor]];
    [_scrubberHeadTimeLabel setForegroundColor:[TimelineHeadReadoutTextColor() CGColor]];
    [_scrubberHeadTimeLabel setAlignmentMode:kCAAlignmentCenter];
}

- (CGFloat)sideReadoutOriginYForLayout:(TimelineLayoutSnapshot)layout sideLabelHeight:(CGFloat)sideLabelHeight
{
    if (NSIsEmptyRect(layout.rulerBandRect)) {
        return 0.0;
    }

    CGFloat centeredY = NSMidY(layout.rulerBandRect) - (sideLabelHeight / 2.0);
    return floor(centeredY);
}

- (CGFloat)headReadoutOriginYForBounds:(NSRect)bounds layout:(TimelineLayoutSnapshot)layout headLabelHeight:(CGFloat)headLabelHeight
{
    if (NSIsEmptyRect(bounds)) {
        return 0.0;
    }

    CGFloat timelineTop = NSMaxY(bounds);
    CGFloat rulerTop = NSMaxY(layout.rulerBandRect);
    if (NSIsEmptyRect(layout.rulerBandRect)) {
        rulerTop = timelineTop;
    }
    CGFloat centerY = (timelineTop + rulerTop) / 2.0;
    CGFloat y = centerY - (headLabelHeight / 2.0);
    CGFloat minY = NSMinY(bounds);
    CGFloat maxY = NSMaxY(bounds) - headLabelHeight;
    return floor(MIN(MAX(y, minY), maxY));
}

- (void)layoutReadoutLayersForBounds:(NSRect)bounds layout:(TimelineLayoutSnapshot)layout
{
    [self ensureReadoutLayersIfNeeded];
    if (_movieTimeRemainingLabel == nil || _movieDurationLabel == nil || _scrubberHeadTimeLabel == nil) {
        return;
    }

    CGFloat leftLabelWidth = TimelineSideReadoutLabelWidth();
    CGFloat rightLabelWidth = TimelineSideReadoutLabelWidth();
    CGFloat headLabelWidth = TimelineHeadReadoutLabelWidth();
    CGFloat sideLabelHeight = TimelineSideReadoutLabelHeight();
    CGFloat headLabelHeight = TimelineHeadReadoutLabelHeight();
    CGFloat gutterWidth = TimelineSideReadoutLabelWidth();
    CGFloat leftGutterX = 0.0;
    CGFloat rightGutterX = MAX(0.0, NSWidth(bounds) - gutterWidth);
    CGFloat sideLabelY = [self sideReadoutOriginYForLayout:layout sideLabelHeight:sideLabelHeight];
    CGFloat headLabelY = [self headReadoutOriginYForBounds:bounds layout:layout headLabelHeight:headLabelHeight];
    CGFloat leftLabelX = leftGutterX + floor((gutterWidth - leftLabelWidth) / 2.0);
    CGFloat rightLabelX = rightGutterX + floor((gutterWidth - rightLabelWidth) / 2.0);

    [_movieTimeRemainingLabel setFrame:NSRectToCGRect(NSIntegralRect(NSMakeRect(leftLabelX,
                                                                                 sideLabelY,
                                                                                 leftLabelWidth,
                                                                                 sideLabelHeight)))];
    [_movieDurationLabel setFrame:NSRectToCGRect(NSIntegralRect(NSMakeRect(rightLabelX,
                                                                            sideLabelY,
                                                                            rightLabelWidth,
                                                                            sideLabelHeight)))];
    [_scrubberHeadTimeLabel setFrame:NSRectToCGRect(NSIntegralRect(NSMakeRect(MAX(0.0, floor((NSWidth(bounds) - headLabelWidth) / 2.0)),
                                                                               headLabelY,
                                                                               headLabelWidth,
                                                                               headLabelHeight)))];
}

- (void)updateReadoutValuesForLayout:(TimelineLayoutSnapshot)layout bounds:(NSRect)bounds usableMovie:(BOOL)usableMovie currentTimecodeString:(NSString *)currentTimecodeString
{
    [self ensureReadoutLayersIfNeeded];
    if (_movieTimeRemainingLabel == nil || _movieDurationLabel == nil || _scrubberHeadTimeLabel == nil) {
        return;
    }

    [_movieTimeRemainingLabel setHidden:NO];
    [_movieDurationLabel setHidden:NO];
    [_scrubberHeadTimeLabel setHidden:!usableMovie];
    [_movieTimeRemainingLabel setForegroundColor:[(usableMovie ? TimelineSideReadoutTextColor() : TimelineDisabledReadoutTextColor()) CGColor]];
    [_movieDurationLabel setForegroundColor:[(usableMovie ? TimelineSideReadoutTextColor() : TimelineDisabledReadoutTextColor()) CGColor]];
    [_scrubberHeadTimeLabel setForegroundColor:[(usableMovie ? TimelineHeadReadoutTextColor() : TimelineDisabledReadoutTextColor()) CGColor]];

    NSTimeInterval duration = MAX(layout.duration, 0.0);
    NSTimeInterval currentTime = MIN(MAX(layout.currentTime, 0.0), duration);
    NSTimeInterval remainingTime = MAX(duration - currentTime, 0.0);

    if (!usableMovie) {
        [_movieTimeRemainingLabel setString:@"-00:00:00"];
        [_movieDurationLabel setString:@"00:00:00"];
        [_scrubberHeadTimeLabel setString:@""];
    } else {
        [_movieTimeRemainingLabel setString:[NSString stringWithFormat:@"-%@", TimelineClockReadoutString(remainingTime)]];
        [_movieDurationLabel setString:TimelineClockReadoutString(duration)];
        NSString *headReadout = ([currentTimecodeString length] > 0)
            ? currentTimecodeString
            : TimelineFrameClockReadoutString(currentTime, layout.frameRate);
        [_scrubberHeadTimeLabel setString:headReadout];
    }

    [self updateHeadReadoutPositionForBounds:bounds
                                      layout:layout
                              playheadCenterX:(TimelinePlayheadCenterX(layout) + TimelinePlayheadCenterXOffset())];
}

- (void)updateHeadReadoutPositionForBounds:(NSRect)bounds layout:(TimelineLayoutSnapshot)layout playheadCenterX:(CGFloat)playheadCenterX
{
    [self ensureReadoutLayersIfNeeded];
    if (_scrubberHeadTimeLabel == nil) {
        return;
    }

    CGFloat headLabelWidth = TimelineHeadReadoutLabelWidth();
    CGFloat headLabelHeight = TimelineHeadReadoutLabelHeight();
    CGFloat minHeadX = 0.0;
    CGFloat maxHeadX = MAX(0.0, NSWidth(bounds) - headLabelWidth);
    CGFloat headOriginX = MIN(MAX(playheadCenterX - (headLabelWidth / 2.0), minHeadX), maxHeadX);
    CGFloat headOriginY = [self headReadoutOriginYForBounds:bounds layout:layout headLabelHeight:headLabelHeight];

    [_scrubberHeadTimeLabel setFrame:NSRectToCGRect(NSIntegralRect(NSMakeRect(headOriginX,
                                                                               headOriginY,
                                                                               headLabelWidth,
                                                                               headLabelHeight)))];
}

@end
