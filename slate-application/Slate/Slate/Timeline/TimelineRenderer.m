//
//  TimelineRenderer.m
//  Slate
//

#import "TimelineRenderer.h"
#import <QuartzCore/QuartzCore.h>

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

static NSString *TimelineRulerLabelString(NSTimeInterval time)
{
    NSInteger roundedTime = (NSInteger)llround(MAX(time, 0.0));
    return [NSString stringWithFormat:@"%ld", (long)roundedTime];
}

#if SMTimelineDebug
static NSColor *TimelineDebugOuterBoundsColor(void) { return [NSColor magentaColor]; }
static NSColor *TimelineDebugLaneBoundsColor(void) { return [NSColor cyanColor]; }
static NSColor *TimelineDebugFullHeightLaneColor(void) { return [NSColor greenColor]; }
static NSColor *TimelineDebugRulerBandColor(void) { return [NSColor redColor]; }
static NSColor *TimelineDebugRulerTickColor(void) { return [NSColor yellowColor]; }
static NSColor *TimelineDebugRulerLabelSafeColor(void) { return [NSColor purpleColor]; }
static NSColor *TimelineDebugBottomRangeBandColor(void) { return [NSColor systemPinkColor]; }
static NSColor *TimelineDebugLaneCoreColor(void) { return [NSColor blueColor]; }

static void TimelineConfigureDebugBackdropLayer(CALayer *layer, NSRect rect)
{
    if (layer == nil) {
        return;
    }

    BOOL shouldHide = NSIsEmptyRect(rect);
    [layer setHidden:shouldHide];
    if (shouldHide) {
        return;
    }

    [layer setFrame:NSRectToCGRect(rect)];
    [layer setBackgroundColor:[[NSColor blackColor] CGColor]];
    [layer setBorderWidth:0.0];
    [layer setBorderColor:nil];
}

static void TimelineConfigureDebugBandLayer(CALayer *layer,
                                            NSRect rect,
                                            NSColor *borderColor)
{
    if (layer == nil) {
        return;
    }

    BOOL shouldHide = NSIsEmptyRect(rect);
    [layer setHidden:shouldHide];
    if (shouldHide) {
        return;
    }

    [layer setFrame:NSRectToCGRect(rect)];
    [layer setBackgroundColor:nil];
    [layer setBorderWidth:2.0];
    [layer setBorderColor:[borderColor CGColor]];
}
#endif

@interface TimelineRenderer ()
{
    CALayer *_hostLayer;
    CALayer *_backdropLayer;
    CALayer *_trackLayer;
    CALayer *_rulerLayer;
    CALayer *_rulerDividerLayer;
    CAShapeLayer *_rulerMajorTickLayer;
    CAShapeLayer *_rulerMinorTickLayer;
    CAShapeLayer *_rulerStripeLayer;
    CAShapeLayer *_gridMajorLineLayer;
    CAShapeLayer *_gridMinorLineLayer;
    NSMutableArray *_rulerLabelLayers;
    CALayer *_selectionLayer;
    CALayer *_inactiveOverlayLayer;
    CALayer *_playheadLayer;
    CALayer *_playheadStemLayer;
    CAShapeLayer *_playheadCapLayer;

#if SMTimelineDebug
    CALayer *_debugOuterBoundsLayer;
    CALayer *_debugLaneBoundsLayer;
    CALayer *_debugLaneCoreLayer;
    CALayer *_debugFullHeightLaneLayer;
    CALayer *_debugRulerBandLayer;
    CALayer *_debugRulerTickLayer;
    CALayer *_debugRulerLabelSafeLayer;
    CALayer *_debugBottomRangeBandLayer;
    CALayer *_debugBackdropLayer;
#endif
}
@end

@implementation TimelineRenderer

- (void)dealloc
{
    [_backdropLayer removeFromSuperlayer];
    [_trackLayer removeFromSuperlayer];
    [_rulerLayer removeFromSuperlayer];
    [_rulerDividerLayer removeFromSuperlayer];
    [_rulerMajorTickLayer removeFromSuperlayer];
    [_rulerMinorTickLayer removeFromSuperlayer];
    [_rulerStripeLayer removeFromSuperlayer];
    [_gridMajorLineLayer removeFromSuperlayer];
    [_gridMinorLineLayer removeFromSuperlayer];
    [_selectionLayer removeFromSuperlayer];
    [_inactiveOverlayLayer removeFromSuperlayer];
    [_playheadStemLayer removeFromSuperlayer];
    [_playheadCapLayer removeFromSuperlayer];
    [_playheadLayer removeFromSuperlayer];

#if SMTimelineDebug
    [_debugBackdropLayer removeFromSuperlayer];
    [_debugOuterBoundsLayer removeFromSuperlayer];
    [_debugLaneBoundsLayer removeFromSuperlayer];
    [_debugLaneCoreLayer removeFromSuperlayer];
    [_debugFullHeightLaneLayer removeFromSuperlayer];
    [_debugRulerBandLayer removeFromSuperlayer];
    [_debugRulerTickLayer removeFromSuperlayer];
    [_debugRulerLabelSafeLayer removeFromSuperlayer];
    [_debugBottomRangeBandLayer removeFromSuperlayer];
#endif

    [_backdropLayer release];
    [_trackLayer release];
    [_rulerLayer release];
    [_rulerDividerLayer release];
    [_rulerMajorTickLayer release];
    [_rulerMinorTickLayer release];
    [_rulerStripeLayer release];
    [_gridMajorLineLayer release];
    [_gridMinorLineLayer release];
    [_rulerLabelLayers release];
    [_selectionLayer release];
    [_inactiveOverlayLayer release];
    [_playheadStemLayer release];
    [_playheadCapLayer release];
    [_playheadLayer release];

#if SMTimelineDebug
    [_debugBackdropLayer release];
    [_debugOuterBoundsLayer release];
    [_debugLaneBoundsLayer release];
    [_debugLaneCoreLayer release];
    [_debugFullHeightLaneLayer release];
    [_debugRulerBandLayer release];
    [_debugRulerTickLayer release];
    [_debugRulerLabelSafeLayer release];
    [_debugBottomRangeBandLayer release];
#endif

    [super dealloc];
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

- (void)ensurePassiveLayersIfNeeded
{
    if (_hostLayer == nil) {
        return;
    }

    if (_backdropLayer == nil) {
        _backdropLayer = [[CALayer alloc] init];
        _backdropLayer.opacity = 1.0f;
        _backdropLayer.zPosition = -0.1f;
        _backdropLayer.actions = TimelineLayerDisabledActions();
    }
    [self ensureLayerAttached:_backdropLayer];

    if (_trackLayer == nil) {
        _trackLayer = [[CAGradientLayer alloc] init];
        _trackLayer.opacity = 1.0f;
        _trackLayer.zPosition = 0.0f;
        _trackLayer.actions = TimelineLayerDisabledActions();
    }
    [self ensureLayerAttached:_trackLayer];

    if (_rulerLayer == nil) {
        _rulerLayer = [[CALayer alloc] init];
        _rulerLayer.opacity = 1.0f;
        _rulerLayer.zPosition = 0.5f;
        _rulerLayer.actions = TimelineLayerDisabledActions();
    }
    [self ensureLayerAttached:_rulerLayer];

    if (_rulerDividerLayer == nil) {
        _rulerDividerLayer = [[CALayer alloc] init];
        _rulerDividerLayer.opacity = 1.0f;
        _rulerDividerLayer.zPosition = 0.75f;
        _rulerDividerLayer.actions = TimelineLayerDisabledActions();
    }
    [self ensureLayerAttached:_rulerDividerLayer];

    if (_rulerMajorTickLayer == nil) {
        _rulerMajorTickLayer = [[CAShapeLayer alloc] init];
        _rulerMajorTickLayer.zPosition = 0.8f;
        _rulerMajorTickLayer.actions = TimelineLayerDisabledActions();
        _rulerMajorTickLayer.fillColor = nil;
    }
    [self ensureLayerAttached:_rulerMajorTickLayer];

    if (_rulerMinorTickLayer == nil) {
        _rulerMinorTickLayer = [[CAShapeLayer alloc] init];
        _rulerMinorTickLayer.zPosition = 0.79f;
        _rulerMinorTickLayer.actions = TimelineLayerDisabledActions();
        _rulerMinorTickLayer.fillColor = nil;
    }
    [self ensureLayerAttached:_rulerMinorTickLayer];

    if (_rulerStripeLayer == nil) {
        _rulerStripeLayer = [[CAShapeLayer alloc] init];
        _rulerStripeLayer.zPosition = 0.795f;
        _rulerStripeLayer.actions = TimelineLayerDisabledActions();
        _rulerStripeLayer.fillColor = nil;
    }
    [self ensureLayerAttached:_rulerStripeLayer];

    if (_gridMajorLineLayer == nil) {
        _gridMajorLineLayer = [[CAShapeLayer alloc] init];
        _gridMajorLineLayer.zPosition = 0.35f;
        _gridMajorLineLayer.actions = TimelineLayerDisabledActions();
        _gridMajorLineLayer.fillColor = nil;
    }
    [self ensureLayerAttached:_gridMajorLineLayer];

    if (_gridMinorLineLayer == nil) {
        _gridMinorLineLayer = [[CAShapeLayer alloc] init];
        _gridMinorLineLayer.zPosition = 0.34f;
        _gridMinorLineLayer.actions = TimelineLayerDisabledActions();
        _gridMinorLineLayer.fillColor = nil;
    }
    [self ensureLayerAttached:_gridMinorLineLayer];

    if (_rulerLabelLayers == nil) {
        _rulerLabelLayers = [[NSMutableArray alloc] init];
    }

    while ([_rulerLabelLayers count] < TimelineRulerMaximumMajorTickCount()) {
        CATextLayer *labelLayer = [[CATextLayer alloc] init];
        labelLayer.zPosition = 0.85f;
        labelLayer.actions = TimelineLayerDisabledActions();
        labelLayer.alignmentMode = kCAAlignmentLeft;
        labelLayer.truncationMode = kCATruncationEnd;
        labelLayer.fontSize = 13.0f;
        labelLayer.contentsScale = [[NSScreen mainScreen] backingScaleFactor];
        [_rulerLabelLayers addObject:labelLayer];
        [self ensureLayerAttached:labelLayer];
        [labelLayer release];
    }

    if (_selectionLayer == nil) {
        _selectionLayer = [[CALayer alloc] init];
        _selectionLayer.opacity = 1.0f;
        _selectionLayer.zPosition = 1.0f;
        _selectionLayer.actions = TimelineLayerDisabledActions();
    }
    [self ensureLayerAttached:_selectionLayer];

    if (_inactiveOverlayLayer == nil) {
        _inactiveOverlayLayer = [[CALayer alloc] init];
        _inactiveOverlayLayer.opacity = 1.0f;
        _inactiveOverlayLayer.zPosition = 1.6f;
        _inactiveOverlayLayer.actions = TimelineLayerDisabledActions();
    }
    [self ensureLayerAttached:_inactiveOverlayLayer];

#if SMTimelineDebug
    if (_debugBackdropLayer == nil) {
        _debugBackdropLayer = [[CALayer alloc] init];
        _debugBackdropLayer.actions = TimelineLayerDisabledActions();
        _debugBackdropLayer.zPosition = 5.9f;
    }
    [self ensureLayerAttached:_debugBackdropLayer];

    if (_debugOuterBoundsLayer == nil) {
        _debugOuterBoundsLayer = [[CALayer alloc] init];
        _debugOuterBoundsLayer.actions = TimelineLayerDisabledActions();
        _debugOuterBoundsLayer.zPosition = 6.0f;
    }
    [self ensureLayerAttached:_debugOuterBoundsLayer];

    if (_debugLaneBoundsLayer == nil) {
        _debugLaneBoundsLayer = [[CALayer alloc] init];
        _debugLaneBoundsLayer.actions = TimelineLayerDisabledActions();
        _debugLaneBoundsLayer.zPosition = 6.1f;
    }
    [self ensureLayerAttached:_debugLaneBoundsLayer];

    if (_debugLaneCoreLayer == nil) {
        _debugLaneCoreLayer = [[CALayer alloc] init];
        _debugLaneCoreLayer.actions = TimelineLayerDisabledActions();
        _debugLaneCoreLayer.zPosition = 6.8f;
    }
    [self ensureLayerAttached:_debugLaneCoreLayer];

    if (_debugFullHeightLaneLayer == nil) {
        _debugFullHeightLaneLayer = [[CALayer alloc] init];
        _debugFullHeightLaneLayer.actions = TimelineLayerDisabledActions();
        _debugFullHeightLaneLayer.zPosition = 6.2f;
    }
    [self ensureLayerAttached:_debugFullHeightLaneLayer];

    if (_debugRulerBandLayer == nil) {
        _debugRulerBandLayer = [[CALayer alloc] init];
        _debugRulerBandLayer.actions = TimelineLayerDisabledActions();
        _debugRulerBandLayer.zPosition = 6.3f;
    }
    [self ensureLayerAttached:_debugRulerBandLayer];

    if (_debugRulerTickLayer == nil) {
        _debugRulerTickLayer = [[CALayer alloc] init];
        _debugRulerTickLayer.actions = TimelineLayerDisabledActions();
        _debugRulerTickLayer.zPosition = 6.4f;
    }
    [self ensureLayerAttached:_debugRulerTickLayer];

    if (_debugRulerLabelSafeLayer == nil) {
        _debugRulerLabelSafeLayer = [[CALayer alloc] init];
        _debugRulerLabelSafeLayer.actions = TimelineLayerDisabledActions();
        _debugRulerLabelSafeLayer.zPosition = 6.5f;
    }
    [self ensureLayerAttached:_debugRulerLabelSafeLayer];

    if (_debugBottomRangeBandLayer == nil) {
        _debugBottomRangeBandLayer = [[CALayer alloc] init];
        _debugBottomRangeBandLayer.actions = TimelineLayerDisabledActions();
        _debugBottomRangeBandLayer.zPosition = 6.6f;
    }
    [self ensureLayerAttached:_debugBottomRangeBandLayer];
#endif
}

- (void)ensureActiveLayersIfNeeded
{
    if (_hostLayer == nil) {
        return;
    }

    if (_playheadLayer == nil) {
        _playheadLayer = [[CALayer alloc] init];
        _playheadLayer.zPosition = 2.0f;
        _playheadLayer.actions = TimelineLayerDisabledActions();
    }
    [self ensureLayerAttached:_playheadLayer];

    if (_playheadStemLayer == nil) {
        _playheadStemLayer = [[CALayer alloc] init];
        _playheadStemLayer.actions = TimelineLayerDisabledActions();
        _playheadStemLayer.zPosition = 3.1f;
    }
    [self ensureLayerAttached:_playheadStemLayer];

    if (_playheadCapLayer == nil) {
        _playheadCapLayer = [[CAShapeLayer alloc] init];
        _playheadCapLayer.actions = TimelineLayerDisabledActions();
        _playheadCapLayer.zPosition = 3.0f;
    }
    [self ensureLayerAttached:_playheadCapLayer];
}

- (void)updatePassiveLayersForBounds:(NSRect)bounds
                              layout:(TimelineLayoutSnapshot)layout
                          usableMovie:(BOOL)usableMovie
{
    [self ensurePassiveLayersIfNeeded];

    if (_hostLayer == nil
        || _backdropLayer == nil
        || _trackLayer == nil
        || _rulerLayer == nil
        || _rulerDividerLayer == nil
        || _rulerMajorTickLayer == nil
        || _rulerMinorTickLayer == nil
        || _rulerStripeLayer == nil
        || _gridMajorLineLayer == nil
        || _gridMinorLineLayer == nil
        || _rulerLabelLayers == nil
        || _selectionLayer == nil
        || _inactiveOverlayLayer == nil) {
        return;
    }

    NSRect fullHeightLaneRect = layout.fullHeightLaneRect;
    NSRect rulerBandRect = layout.rulerBandRect;
    NSRect tickRect = layout.rulerTickRect;
    NSRect labelSafeRect = layout.rulerLabelSafeRect;
    NSRect stripeRect = NSInsetRect(labelSafeRect, -2.0, 0.0);
    NSRect gridRect = layout.laneRect;
    NSRect selectionRect = TimelineBottomRangeSelectionRectForLayout(layout);
    NSColor *backdropColor = usableMovie
        ? [NSColor colorWithCalibratedWhite:0.14 alpha:1.0]
        : [NSColor colorWithCalibratedWhite:0.12 alpha:1.0];
    NSColor *laneTopColor = usableMovie
        ? [NSColor colorWithCalibratedWhite:0.23 alpha:1.0]
        : [NSColor colorWithCalibratedWhite:0.19 alpha:1.0];
    NSColor *laneBottomColor = usableMovie
        ? [NSColor colorWithCalibratedWhite:0.16 alpha:1.0]
        : [NSColor colorWithCalibratedWhite:0.14 alpha:1.0];
    NSColor *trackBorderColor = usableMovie
        ? [NSColor colorWithCalibratedWhite:0.03 alpha:0.95]
        : [NSColor colorWithCalibratedWhite:0.03 alpha:0.72];
    NSColor *rulerColor = usableMovie
        ? [NSColor colorWithCalibratedWhite:0.21 alpha:1.0]
        : [NSColor colorWithCalibratedWhite:0.18 alpha:1.0];
    NSColor *dividerColor = usableMovie
        ? [NSColor colorWithCalibratedWhite:0.0 alpha:0.58]
        : [NSColor colorWithCalibratedWhite:0.0 alpha:0.36];
    NSColor *majorTickColor = [[NSColor colorWithCalibratedWhite:0.86 alpha:(usableMovie ? 0.82 : 0.50)] retain];
    NSColor *minorTickColor = [[NSColor colorWithCalibratedWhite:0.84 alpha:(usableMovie ? 0.36 : 0.20)] retain];
    NSColor *stripeColor = [[NSColor colorWithCalibratedWhite:0.10 alpha:(usableMovie ? 0.36 : 0.20)] retain];
    NSColor *gridMajorColor = [[NSColor colorWithCalibratedWhite:0.58 alpha:(usableMovie ? 0.44 : 0.24)] retain];
    NSColor *gridMinorColor = [[NSColor colorWithCalibratedWhite:0.90 alpha:(usableMovie ? 0.08 : 0.04)] retain];
    NSColor *labelColor = [[NSColor colorWithCalibratedWhite:0.96 alpha:0.96] retain];
    NSColor *bottomSelectionColor = [[NSColor colorWithCalibratedRed:0.88 green:0.74 blue:0.25 alpha:0.35] retain];
    NSUInteger majorTickCount = TimelineRulerAdaptiveMajorTickCount(layout);
    NSUInteger minorTicksPerMajorInterval = TimelineRulerAdaptiveMinorTickCount(layout, majorTickCount);
    NSRect dividerRect = NSMakeRect(NSMinX(rulerBandRect),
                                    NSMinY(rulerBandRect),
                                    NSWidth(rulerBandRect),
                                    1.0);
    CGMutablePathRef majorTickPath = CGPathCreateMutable();
    CGMutablePathRef minorTickPath = CGPathCreateMutable();
    CGMutablePathRef stripePath = CGPathCreateMutable();
    CGMutablePathRef gridMajorPath = CGPathCreateMutable();
    CGMutablePathRef gridMinorPath = CGPathCreateMutable();
    BOOL drawMinorGridToBottom = NO;
    CGFloat majorTickTop = NSMaxY(rulerBandRect) - 0.5;
    CGFloat majorTickBottom = NSMinY(rulerBandRect) + 0.5;
    CGFloat majorContinuationTop = majorTickBottom;
    CGFloat majorContinuationBottom = NSMinY(fullHeightLaneRect) + 0.5;
    BOOL drawMajorContinuation = (majorContinuationTop > majorContinuationBottom);
    CGFloat minorTickBottom = NSMinY(tickRect) + 0.5;
    CGFloat minorTickRangeHeight = MAX((NSMaxY(tickRect) - 0.5) - minorTickBottom, 1.0);
    CGFloat minorTickHeight = MIN(minorTickRangeHeight - 1.0, MAX(6.0, floor(minorTickRangeHeight * 0.58)));
    CGFloat minorTickTop = minorTickBottom + minorTickHeight;

    for (NSUInteger tickIndex = 0; tickIndex < majorTickCount; tickIndex++) {
        NSTimeInterval tickTime = TimelineRulerMajorTickTime(layout, tickIndex, majorTickCount);
        CGFloat tickX = TimelineXPositionForTime(tickTime, layout);
        CGPathMoveToPoint(majorTickPath, NULL, tickX, majorTickTop);
        CGPathAddLineToPoint(majorTickPath, NULL, tickX, majorTickBottom);
        if (drawMajorContinuation) {
            CGPathMoveToPoint(gridMajorPath, NULL, tickX, majorContinuationTop);
            CGPathAddLineToPoint(gridMajorPath, NULL, tickX, majorContinuationBottom);
        }

        if (tickIndex + 1 < majorTickCount) {
            NSTimeInterval nextTickTime = TimelineRulerMajorTickTime(layout, tickIndex + 1, majorTickCount);
            for (NSUInteger minorIndex = 1; minorIndex <= minorTicksPerMajorInterval; minorIndex++) {
                CGFloat fraction = (CGFloat)minorIndex / (CGFloat)(minorTicksPerMajorInterval + 1);
                NSTimeInterval minorTickTime = tickTime + ((nextTickTime - tickTime) * fraction);
                CGFloat minorTickX = TimelineXPositionForTime(minorTickTime, layout);
                CGPathMoveToPoint(minorTickPath, NULL, minorTickX, minorTickTop);
                CGPathAddLineToPoint(minorTickPath, NULL, minorTickX, minorTickBottom);
                if (drawMinorGridToBottom) {
                    CGPathMoveToPoint(gridMinorPath, NULL, minorTickX, NSMinY(gridRect));
                    CGPathAddLineToPoint(gridMinorPath, NULL, minorTickX, NSMaxY(gridRect));
                }
            }
        }
    }

    if (!NSIsEmptyRect(stripeRect)) {
        CGFloat stripeSpacing = 11.0;
        CGFloat stripeRun = NSHeight(stripeRect);
        for (CGFloat stripeX = NSMinX(stripeRect) - stripeRun; stripeX <= NSMaxX(stripeRect) + stripeRun; stripeX += stripeSpacing) {
            CGPathMoveToPoint(stripePath, NULL, stripeX, NSMinY(stripeRect));
            CGPathAddLineToPoint(stripePath, NULL, stripeX + stripeRun, NSMaxY(stripeRect));
        }
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    _backdropLayer.hidden = NO;
    _backdropLayer.frame = NSRectToCGRect(bounds);
    _backdropLayer.backgroundColor = [backdropColor CGColor];

    _trackLayer.frame = NSRectToCGRect(fullHeightLaneRect);
    _trackLayer.cornerRadius = TimelineLaneCornerRadius();
    _trackLayer.borderWidth = 1.0;
    _trackLayer.borderColor = [trackBorderColor CGColor];
    if ([_trackLayer isKindOfClass:[CAGradientLayer class]]) {
        CAGradientLayer *gradientLayer = (CAGradientLayer *)_trackLayer;
        gradientLayer.startPoint = CGPointMake(0.5, 1.0);
        gradientLayer.endPoint = CGPointMake(0.5, 0.0);
        gradientLayer.colors = [NSArray arrayWithObjects:(id)[laneTopColor CGColor], (id)[laneBottomColor CGColor], nil];
    } else {
        _trackLayer.backgroundColor = [laneBottomColor CGColor];
    }

    _rulerLayer.hidden = NSIsEmptyRect(rulerBandRect);
    _rulerLayer.frame = NSRectToCGRect(rulerBandRect);
    _rulerLayer.backgroundColor = [rulerColor CGColor];

    _rulerDividerLayer.hidden = NSIsEmptyRect(rulerBandRect);
    _rulerDividerLayer.frame = NSRectToCGRect(dividerRect);
    _rulerDividerLayer.backgroundColor = [dividerColor CGColor];

    _rulerMajorTickLayer.hidden = NSIsEmptyRect(rulerBandRect);
    _rulerMajorTickLayer.frame = NSRectToCGRect(bounds);
    _rulerMajorTickLayer.path = majorTickPath;
    _rulerMajorTickLayer.strokeColor = [majorTickColor CGColor];
    _rulerMajorTickLayer.lineWidth = 1.1;

    _rulerMinorTickLayer.hidden = NSIsEmptyRect(rulerBandRect);
    _rulerMinorTickLayer.frame = NSRectToCGRect(bounds);
    _rulerMinorTickLayer.path = minorTickPath;
    _rulerMinorTickLayer.strokeColor = [minorTickColor CGColor];
    _rulerMinorTickLayer.lineWidth = 1.0;

    _rulerStripeLayer.hidden = NSIsEmptyRect(stripeRect);
    _rulerStripeLayer.frame = NSRectToCGRect(bounds);
    _rulerStripeLayer.path = stripePath;
    _rulerStripeLayer.strokeColor = [stripeColor CGColor];
    _rulerStripeLayer.lineWidth = 1.0;

    _gridMajorLineLayer.hidden = (NSIsEmptyRect(fullHeightLaneRect) || !drawMajorContinuation);
    _gridMajorLineLayer.frame = NSRectToCGRect(bounds);
    _gridMajorLineLayer.path = gridMajorPath;
    _gridMajorLineLayer.strokeColor = [gridMajorColor CGColor];
    _gridMajorLineLayer.lineWidth = 1.0;

    _gridMinorLineLayer.hidden = (NSIsEmptyRect(gridRect) || !drawMinorGridToBottom);
    _gridMinorLineLayer.frame = NSRectToCGRect(bounds);
    _gridMinorLineLayer.path = gridMinorPath;
    _gridMinorLineLayer.strokeColor = [gridMinorColor CGColor];
    _gridMinorLineLayer.lineWidth = 1.0;

    for (NSUInteger tickIndex = 0; tickIndex < [_rulerLabelLayers count]; tickIndex++) {
        CATextLayer *labelLayer = [_rulerLabelLayers objectAtIndex:tickIndex];
        [self ensureLayerAttached:labelLayer];
        BOOL shouldHideLabel = (!usableMovie
                                || tickIndex >= majorTickCount
                                || tickIndex + 1 >= majorTickCount
                                || NSIsEmptyRect(rulerBandRect));
        [labelLayer setHidden:shouldHideLabel];
        if (shouldHideLabel) {
            continue;
        }

        NSTimeInterval tickTime = TimelineRulerMajorTickTime(layout, tickIndex, majorTickCount);
        CGFloat tickX = TimelineXPositionForTime(tickTime, layout);
        CGFloat labelX = tickX + 6.0;
        CGFloat maxLabelX = NSMaxX(labelSafeRect) - TimelineRulerLabelWidth();
        labelX = MIN(labelX, maxLabelX);
        labelX = MAX(labelX, NSMinX(labelSafeRect));
        NSRect labelRect = NSMakeRect(labelX,
                                      NSMidY(labelSafeRect) - (TimelineRulerLabelHeight() / 2.0),
                                      TimelineRulerLabelWidth(),
                                      TimelineRulerLabelHeight());
        [labelLayer setFrame:NSRectToCGRect(labelRect)];
        [labelLayer setForegroundColor:[labelColor CGColor]];
        [labelLayer setShadowOpacity:0.35f];
        [labelLayer setShadowRadius:1.0f];
        [labelLayer setShadowOffset:CGSizeMake(0.0, -1.0)];
        [labelLayer setString:TimelineRulerLabelString(tickTime)];
    }

    _selectionLayer.hidden = (!usableMovie || NSWidth(selectionRect) <= 0.0);
    _selectionLayer.frame = NSRectToCGRect(selectionRect);
    _selectionLayer.cornerRadius = 0.0;
    _selectionLayer.backgroundColor = [bottomSelectionColor CGColor];

    _inactiveOverlayLayer.hidden = usableMovie;
    _inactiveOverlayLayer.frame = NSRectToCGRect(bounds);
    _inactiveOverlayLayer.backgroundColor = [[NSColor colorWithCalibratedWhite:0.0 alpha:0.24] CGColor];

#if SMTimelineDebug
//    TimelineConfigureDebugBackdropLayer(_debugBackdropLayer, bounds);
//    TimelineConfigureDebugBandLayer(_debugOuterBoundsLayer, layout.outerBounds, TimelineDebugOuterBoundsColor());
//    TimelineConfigureDebugBandLayer(_debugLaneBoundsLayer, layout.laneBounds, TimelineDebugLaneBoundsColor());
//    TimelineConfigureDebugBandLayer(_debugLaneCoreLayer, layout.laneRect, TimelineDebugLaneCoreColor());
//    TimelineConfigureDebugBandLayer(_debugFullHeightLaneLayer, layout.fullHeightLaneRect, TimelineDebugFullHeightLaneColor());
//    TimelineConfigureDebugBandLayer(_debugRulerLabelSafeLayer, labelSafeRect, TimelineDebugRulerLabelSafeColor());
    TimelineConfigureDebugBandLayer(_debugRulerBandLayer, rulerBandRect, TimelineDebugRulerBandColor());
//    TimelineConfigureDebugBandLayer(_debugRulerTickLayer, tickRect, TimelineDebugRulerTickColor());
//    TimelineConfigureDebugBandLayer(_debugBottomRangeBandLayer, layout.bottomRangeBandRect, TimelineDebugBottomRangeBandColor());
#endif

    [CATransaction commit];

    CGPathRelease(majorTickPath);
    CGPathRelease(minorTickPath);
    CGPathRelease(stripePath);
    CGPathRelease(gridMajorPath);
    CGPathRelease(gridMinorPath);
    [majorTickColor release];
    [minorTickColor release];
    [stripeColor release];
    [gridMajorColor release];
    [gridMinorColor release];
    [labelColor release];
    [bottomSelectionColor release];
}

- (void)updatePlayheadLayersForLayout:(TimelineLayoutSnapshot)layout
                      playheadDragging:(BOOL)playheadDragging
                           usableMovie:(BOOL)usableMovie
{
    [self ensureActiveLayersIfNeeded];

    if (_playheadLayer == nil || _playheadStemLayer == nil || _playheadCapLayer == nil) {
        return;
    }

    NSRect visualRect = TimelinePlayheadVisualRect(layout);
    BOOL shouldHide = (!usableMovie || NSIsEmptyRect(visualRect));
    NSColor *stemColor = playheadDragging
        ? [NSColor colorWithCalibratedRed:0.98 green:0.05 blue:0.03 alpha:0.82]
        : [NSColor colorWithCalibratedRed:0.92 green:0.03 blue:0.02 alpha:0.68];
    NSColor *capColor = [NSColor grayColor];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [_playheadLayer setHidden:shouldHide];
    if (shouldHide) {
        [_playheadStemLayer setHidden:YES];
        [_playheadCapLayer setHidden:YES];
        [_playheadCapLayer setPath:nil];
        [CATransaction commit];
        return;
    }

    NSRect capRect = TimelinePlayheadCapRect(layout);
    NSRect stemRect = TimelinePlayheadStemRect(layout);
    CGPathRef capPath = TimelineCreatePlayheadCapPath(NSMakeRect(0.0, 0.0, NSWidth(capRect), NSHeight(capRect)));
    [_playheadLayer setFrame:NSRectToCGRect(visualRect)];
    [_playheadLayer setBackgroundColor:nil];
    [_playheadLayer setBorderWidth:0.0];
    [_playheadLayer setBorderColor:nil];
    [_playheadStemLayer setHidden:NSIsEmptyRect(stemRect)];
    [_playheadStemLayer setZPosition:3.1f];
    [_playheadStemLayer setFrame:NSRectToCGRect(stemRect)];
    [_playheadStemLayer setBackgroundColor:[stemColor CGColor]];
    [_playheadCapLayer setHidden:NSIsEmptyRect(capRect)];
    [_playheadCapLayer setZPosition:3.0f];
    [_playheadCapLayer setFrame:NSRectToCGRect(capRect)];
    [_playheadCapLayer setFillColor:[capColor CGColor]];
    [_playheadCapLayer setOpacity:1.0f];
    [_playheadCapLayer setLineWidth:1.0];
    [_playheadCapLayer setStrokeColor:[[NSColor colorWithCalibratedWhite:0.0 alpha:0.35] CGColor]];
    [_playheadCapLayer setPath:capPath];
    [_playheadCapLayer setLineJoin:kCALineJoinRound];
    [CATransaction commit];
    if (capPath != NULL) {
        CGPathRelease(capPath);
    }
}

- (NSString *)playheadLayerDebugString
{
    NSString *playheadFrame = (_playheadLayer != nil) ? NSStringFromRect(NSRectFromCGRect(_playheadLayer.frame)) : @"(nil)";
    NSString *stemFrame = (_playheadStemLayer != nil) ? NSStringFromRect(NSRectFromCGRect(_playheadStemLayer.frame)) : @"(nil)";
    NSString *capFrame = (_playheadCapLayer != nil) ? NSStringFromRect(NSRectFromCGRect(_playheadCapLayer.frame)) : @"(nil)";
    return [NSString stringWithFormat:@"playheadHidden=%d playheadFrame=%@ stemHidden=%d stemFrame=%@ capHidden=%d capFrame=%@",
            (_playheadLayer != nil ? _playheadLayer.hidden : YES),
            playheadFrame,
            (_playheadStemLayer != nil ? _playheadStemLayer.hidden : YES),
            stemFrame,
            (_playheadCapLayer != nil ? _playheadCapLayer.hidden : YES),
            capFrame];
}

@end
