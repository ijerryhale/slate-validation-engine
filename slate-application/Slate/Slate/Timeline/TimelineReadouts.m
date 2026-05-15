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

static NSFont *MonoSpacedFont(NSInteger size)
{
    NSFont *font = [NSFont monospacedSystemFontOfSize:size weight:NSFontWeightRegular];
        
    if (font == nil)
        font = [NSFont fontWithName:@"Menlo-Regular" size:size];

    return font;
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

static CGFloat StringWidth(NSString *sample, NSFont *font)
{
    NSSize textSize = [sample sizeWithAttributes:[NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName]];
    return ceil(textSize.width) + 4.0;
}

static CGFloat CurrentTimeLabelWidth(void)
{
    static CGFloat cachedWidth = 0.0;
    if (cachedWidth <= 0.0) {
        cachedWidth = StringWidth(@"88:88:88.88", MonoSpacedFont(12));
    }
    return cachedWidth;
}

static CATextLayer *CreateLabel(CGFloat fontSize)
{
    CATextLayer *label = [[CATextLayer alloc] init];
    [label setHidden:NO];
    [label setWrapped:NO];
    [label setTruncationMode:kCATruncationNone];
    
    [label setAlignmentMode:kCAAlignmentCenter];
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
    CALayer         *_hostLayer;
    CATextLayer *_timeRemainingLabel,
                            *_durationLabel,
                            *_currTimeLabel;
}
@end

@implementation TimelineReadouts

- (void)dealloc
{
    [_timeRemainingLabel removeFromSuperlayer];
    [_durationLabel removeFromSuperlayer];
    [_currTimeLabel removeFromSuperlayer];

    [_timeRemainingLabel release];
    [_durationLabel release];
    [_currTimeLabel release];

    [super dealloc];
}

- (CGFloat)gutterLabelWidth { return StringWidth(@"-88:88:88", MonoSpacedFont(16)); }
- (CGFloat)contentTopInset { return 23.0; }
- (void)attachToHostLayer:(CALayer *)hostLayer { _hostLayer = hostLayer; }

- (void)ensureLayerAttached:(CALayer *)layer
{
    if (layer == nil || _hostLayer == nil) return;

    if (layer.superlayer != _hostLayer) {
        [layer removeFromSuperlayer];
        [_hostLayer addSublayer:layer];
    }
}

- (void)ensureReadoutLayersIfNeeded
{
    if (_hostLayer == nil) return;

    if (_timeRemainingLabel == nil)
    {
        _timeRemainingLabel = CreateLabel(16);
        [_timeRemainingLabel setActions:TimelineLayerDisabledActions()];
        [_timeRemainingLabel setZPosition:20.0];
    }

    [self ensureLayerAttached:_timeRemainingLabel];

    if (_durationLabel == nil)
    {
        _durationLabel = CreateLabel(16);
        [_durationLabel setActions:TimelineLayerDisabledActions()];
        [_durationLabel setZPosition:20.0];
    }
    
    [self ensureLayerAttached:_durationLabel];

    if (_currTimeLabel == nil)
    {
        _currTimeLabel = CreateLabel( 12);
        [_currTimeLabel setActions:TimelineLayerDisabledActions()];
        [_currTimeLabel setZPosition:20.0];
    }
    
    [self ensureLayerAttached:_currTimeLabel];

    NSFont *gutterFont = MonoSpacedFont(16);
    [_timeRemainingLabel setFont:[gutterFont fontName]];
    [_timeRemainingLabel setFontSize:[gutterFont pointSize]];
    [_durationLabel setFont:[gutterFont fontName]];
    [_durationLabel setFontSize:[gutterFont pointSize]];

    [_timeRemainingLabel setAlignmentMode:kCAAlignmentCenter];
    [_durationLabel setAlignmentMode:kCAAlignmentCenter];
    [_timeRemainingLabel setForegroundColor:[[NSColor colorWithCalibratedWhite:1.0 alpha:0.92] CGColor]];
    [_durationLabel setForegroundColor:[[NSColor colorWithCalibratedWhite:1.0 alpha:0.92] CGColor]];
    [_currTimeLabel setForegroundColor:[[NSColor colorWithCalibratedWhite:1.0 alpha:0.94] CGColor]];
    [_currTimeLabel setAlignmentMode:kCAAlignmentCenter];
}

- (CGFloat)currentTimeOriginYForBounds:(NSRect)bounds layout:(TimelineLayoutSnapshot)layout headLabelHeight:(CGFloat)headLabelHeight
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

    if (_timeRemainingLabel == nil || _durationLabel == nil || _currTimeLabel == nil)
        return;
    
    NSSize gtls = [@"88:88:88" sizeWithAttributes:[NSDictionary dictionaryWithObject:MonoSpacedFont(16) forKey:NSFontAttributeName]];
  
    CGFloat gutterLabelWidth = [self gutterLabelWidth];
    CGFloat gutterWidth = (bounds.size.width - layout.rulerBandRect.size.width) / 2;

    CGFloat gutterLabelHeight = ceil(gtls.height);
    CGFloat gutterLabelY = NSMidY(layout.rulerBandRect) - (gutterLabelHeight / 2.0);

    CGFloat leftGutterX = 0.0;
    CGFloat rightGutterX = MAX(0.0, NSWidth(bounds) - gutterWidth);
  
    CGFloat leftLabelX = leftGutterX + floor((gutterWidth - gutterLabelWidth) / 2.0);
    [_timeRemainingLabel setFrame:NSRectToCGRect(NSIntegralRect(NSMakeRect(leftLabelX, gutterLabelY,
                                                                                                       gutterLabelWidth, gutterLabelHeight)))];
 
    CGFloat rightLabelX = rightGutterX + floor((gutterWidth - gutterLabelWidth) / 2.0);
    [_durationLabel setFrame:NSRectToCGRect(NSIntegralRect(NSMakeRect(rightLabelX, gutterLabelY,
                                                                                                      gutterLabelWidth, gutterLabelHeight)))];

    CGFloat currentTimeLabelWidth = CurrentTimeLabelWidth();
    
    NSSize  ctls = [@"88:88:88.88" sizeWithAttributes:[NSDictionary dictionaryWithObject:MonoSpacedFont(12) forKey:NSFontAttributeName]];
    
    CGFloat currentTimeLabelHeight = ceil(ctls.height);
    CGFloat currentTimeLabelY = [self currentTimeOriginYForBounds:bounds
                                                            layout:layout headLabelHeight:currentTimeLabelHeight];

    [_currTimeLabel setFrame:NSRectToCGRect(NSIntegralRect(NSMakeRect(MAX(0.0, floor((NSWidth(bounds) - currentTimeLabelWidth) / 2.0)), currentTimeLabelY, currentTimeLabelWidth, currentTimeLabelHeight)))];
}

- (void)updateReadoutValuesForLayout:(TimelineLayoutSnapshot)layout bounds:(NSRect)bounds usableMovie:(BOOL)usableMovie currentTimecodeString:(NSString *)currentTimecodeString
{
    [self ensureReadoutLayersIfNeeded];

    if (_timeRemainingLabel == nil || _durationLabel == nil || _currTimeLabel == nil)
        return;

    [_timeRemainingLabel setHidden:NO];
    [_durationLabel setHidden:NO];
    [_currTimeLabel setHidden:!usableMovie];
    [_timeRemainingLabel setForegroundColor:[(usableMovie ? [NSColor colorWithCalibratedWhite:1.0 alpha:0.92] : [NSColor colorWithCalibratedWhite:1.0 alpha:0.50]) CGColor]];
    [_durationLabel setForegroundColor:[(usableMovie ? [NSColor colorWithCalibratedWhite:1.0 alpha:0.92] : [NSColor colorWithCalibratedWhite:1.0 alpha:0.50]) CGColor]];
    [_currTimeLabel setForegroundColor:[(usableMovie ? [NSColor colorWithCalibratedWhite:1.0 alpha:0.94] : [NSColor colorWithCalibratedWhite:1.0 alpha:0.50]) CGColor]];

    NSTimeInterval duration = MAX(layout.duration, 0.0);
    NSTimeInterval currentTime = MIN(MAX(layout.currentTime, 0.0), duration);
    NSTimeInterval remainingTime = MAX(duration - currentTime, 0.0);

    if (!usableMovie)
    {
        [_timeRemainingLabel setString:@"-00:00:00"];
        [_durationLabel setString:@"00:00:00"];
        [_currTimeLabel setString:@""];
    }
    else
    {
        [_timeRemainingLabel setString:[NSString stringWithFormat:@"-%@", TimelineClockReadoutString(remainingTime)]];
        [_durationLabel setString:TimelineClockReadoutString(duration)];
        NSString *headReadout = ([currentTimecodeString length] > 0)
            ? currentTimecodeString
            : TimelineFrameClockReadoutString(currentTime, layout.frameRate);
        [_currTimeLabel setString:headReadout];
    }

    [self updateCurrentTimePositionForBounds:bounds
                                      layout:layout
                              playheadCenterX:TimelinePlayheadCenterX(layout)];
}

- (void)updateCurrentTimePositionForBounds:(NSRect)bounds layout:(TimelineLayoutSnapshot)layout playheadCenterX:(CGFloat)playheadCenterX
{
    [self ensureReadoutLayersIfNeeded];

    if (_currTimeLabel == nil) return;

    CGFloat currentTimeLabelWidth = CurrentTimeLabelWidth();
          
    NSSize textSize = [@"88:88:88.88" sizeWithAttributes:[NSDictionary dictionaryWithObject:MonoSpacedFont(12) forKey:NSFontAttributeName]];
    CGFloat currentTimeLabelHeight = ceil(textSize.height);
    
    CGFloat minHeadX = 0.0;
    CGFloat maxHeadX = MAX(0.0, NSWidth(bounds) - currentTimeLabelWidth);
    CGFloat headOriginX = MIN(MAX(playheadCenterX - (currentTimeLabelWidth / 2.0), minHeadX), maxHeadX);
    CGFloat headOriginY = [self currentTimeOriginYForBounds:bounds layout:layout headLabelHeight:currentTimeLabelHeight];

    [_currTimeLabel setFrame:NSRectToCGRect(NSIntegralRect(NSMakeRect(headOriginX, headOriginY,
                                                                      currentTimeLabelWidth, currentTimeLabelHeight)))];
}

@end
