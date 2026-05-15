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

#if SMTimelineDebug
static void ConfigureDBUGBandLayer(CALayer *layer, NSRect rect, NSColor *borderColor)
{
    if (layer == nil) return;

    BOOL shouldHide = NSIsEmptyRect(rect);
    [layer setHidden:shouldHide];
   
    if (shouldHide) return;

    [layer setFrame:NSRectToCGRect(rect)];
    [layer setBackgroundColor:nil];
    [layer setBorderWidth:2.0];
    [layer setBorderColor:[borderColor CGColor]];
}
#endif

@interface TimelineRenderer ()
{
    CALayer *_hostLayer;
    CALayer *_backgroundLayer;
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
    CALayer *_playheadLayer;
    CALayer *_playheadStemLayer;
    CAShapeLayer *_playheadCapLayer;

#if SMTimelineDebug
    CALayer *_dbugloOuterBoundsLayer;
    CALayer *_dbugloLaneBoundsLayer;
    CALayer *_dbugloLaneRectLayer;
    CALayer *_dbugloFullHeightLaneLayer;
    CALayer *_dbugloRulerBandLayer;
    CALayer *_dbugloRulerTickLayer;
    CALayer *_dbugloRulerLabelSafeLayer;
    CALayer *_dbugloRegionBandLayer;
    CALayer *_dbugloBackgroundLayer;
 #endif
}
@end

@implementation TimelineRenderer

- (void)dealloc
{
    [_backgroundLayer removeFromSuperlayer];
    [_trackLayer removeFromSuperlayer];
    [_rulerLayer removeFromSuperlayer];
    [_rulerDividerLayer removeFromSuperlayer];
    [_rulerMajorTickLayer removeFromSuperlayer];
    [_rulerMinorTickLayer removeFromSuperlayer];
    [_rulerStripeLayer removeFromSuperlayer];
    [_gridMajorLineLayer removeFromSuperlayer];
    [_gridMinorLineLayer removeFromSuperlayer];
    [_selectionLayer removeFromSuperlayer];
    [_playheadStemLayer removeFromSuperlayer];
    [_playheadCapLayer removeFromSuperlayer];
    [_playheadLayer removeFromSuperlayer];

#if SMTimelineDebug
    [_dbugloBackgroundLayer removeFromSuperlayer];
    [_dbugloOuterBoundsLayer removeFromSuperlayer];
    [_dbugloLaneBoundsLayer removeFromSuperlayer];
    [_dbugloLaneRectLayer removeFromSuperlayer];
    [_dbugloFullHeightLaneLayer removeFromSuperlayer];
    [_dbugloRulerBandLayer removeFromSuperlayer];
    [_dbugloRulerTickLayer removeFromSuperlayer];
    [_dbugloRulerLabelSafeLayer removeFromSuperlayer];
    [_dbugloRegionBandLayer removeFromSuperlayer];
#endif

    [_backgroundLayer release];
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
    [_playheadStemLayer release];
    [_playheadCapLayer release];
    [_playheadLayer release];

#if SMTimelineDebug
    [_dbugloBackgroundLayer release];
    [_dbugloOuterBoundsLayer release];
    [_dbugloLaneBoundsLayer release];
    [_dbugloLaneRectLayer release];
    [_dbugloFullHeightLaneLayer release];
    [_dbugloRulerBandLayer release];
    [_dbugloRulerTickLayer release];
    [_dbugloRulerLabelSafeLayer release];
    [_dbugloRegionBandLayer release];
#endif

    [super dealloc];
}

- (void)attachToHostLayer:(CALayer *)hostLayer { _hostLayer = hostLayer; }
- (void)ensureLayerAttached:(CALayer *)layer
{
    if (layer == nil || _hostLayer == nil) return;

    if (layer.superlayer != _hostLayer) {
        [layer removeFromSuperlayer];
        [_hostLayer addSublayer:layer];
    }
}

- (void)ensurePassiveLayersIfNeeded
{
    if (_hostLayer == nil) return;

    if (_backgroundLayer == nil)
    {
        _backgroundLayer = [[CALayer alloc] init];
        _backgroundLayer.opacity = 1.0f;
        _backgroundLayer.zPosition = -0.1f;
        _backgroundLayer.actions = TimelineLayerDisabledActions();
    }
    
    [self ensureLayerAttached:_backgroundLayer];

    if (_trackLayer == nil)
    {
        _trackLayer = [[CAGradientLayer alloc] init];
        _trackLayer.opacity = 1.0f;
        _trackLayer.zPosition = 0.0f;
        _trackLayer.actions = TimelineLayerDisabledActions();
    }
    
    [self ensureLayerAttached:_trackLayer];

    if (_rulerLayer == nil)
    {
        _rulerLayer = [[CALayer alloc] init];
        _rulerLayer.opacity = 1.0f;
        _rulerLayer.zPosition = 0.5f;
        _rulerLayer.actions = TimelineLayerDisabledActions();
    }
    
    [self ensureLayerAttached:_rulerLayer];

    if (_rulerDividerLayer == nil)
    {
        _rulerDividerLayer = [[CALayer alloc] init];
        _rulerDividerLayer.opacity = 1.0f;
        _rulerDividerLayer.zPosition = 0.75f;
        _rulerDividerLayer.actions = TimelineLayerDisabledActions();
    }
    
    [self ensureLayerAttached:_rulerDividerLayer];

    if (_rulerMajorTickLayer == nil)
    {
        _rulerMajorTickLayer = [[CAShapeLayer alloc] init];
        _rulerMajorTickLayer.zPosition = 0.8f;
        _rulerMajorTickLayer.actions = TimelineLayerDisabledActions();
        _rulerMajorTickLayer.fillColor = nil;
    }
    
    [self ensureLayerAttached:_rulerMajorTickLayer];

    if (_rulerMinorTickLayer == nil)
    {
        _rulerMinorTickLayer = [[CAShapeLayer alloc] init];
        _rulerMinorTickLayer.zPosition = 0.79f;
        _rulerMinorTickLayer.actions = TimelineLayerDisabledActions();
        _rulerMinorTickLayer.fillColor = nil;
    }
    
    [self ensureLayerAttached:_rulerMinorTickLayer];

    if (_rulerStripeLayer == nil)
    {
        _rulerStripeLayer = [[CAShapeLayer alloc] init];
        _rulerStripeLayer.zPosition = 0.795f;
        _rulerStripeLayer.actions = TimelineLayerDisabledActions();
        _rulerStripeLayer.fillColor = nil;
    }
    
    [self ensureLayerAttached:_rulerStripeLayer];

    if (_gridMajorLineLayer == nil)
    {
        _gridMajorLineLayer = [[CAShapeLayer alloc] init];
        _gridMajorLineLayer.zPosition = 0.35f;
        _gridMajorLineLayer.actions = TimelineLayerDisabledActions();
        _gridMajorLineLayer.fillColor = nil;
    }

    [self ensureLayerAttached:_gridMajorLineLayer];

    if (_gridMinorLineLayer == nil)
    {
        _gridMinorLineLayer = [[CAShapeLayer alloc] init];
        _gridMinorLineLayer.zPosition = 0.34f;
        _gridMinorLineLayer.actions = TimelineLayerDisabledActions();
        _gridMinorLineLayer.fillColor = nil;
    }

    [self ensureLayerAttached:_gridMinorLineLayer];

    if (_rulerLabelLayers == nil)
        _rulerLabelLayers = [[NSMutableArray alloc] init];

    while ([_rulerLabelLayers count] < TimelineRulerMaximumMajorTickCount())
    {
        CATextLayer *majorTickLabel = [[CATextLayer alloc] init];
        majorTickLabel.zPosition = 0.85f;
        majorTickLabel.actions = TimelineLayerDisabledActions();
        majorTickLabel.alignmentMode = kCAAlignmentLeft;
        majorTickLabel.fontSize = 14.0f;
        majorTickLabel. foregroundColor = [[NSColor colorWithWhite:1.0 alpha:0.6 ]CGColor];
        majorTickLabel.contentsScale = [[NSScreen mainScreen] backingScaleFactor];
        [_rulerLabelLayers addObject:majorTickLabel];
        [self ensureLayerAttached:majorTickLabel];
        [majorTickLabel release];
    }

    if (_selectionLayer == nil)
    {
        _selectionLayer = [[CALayer alloc] init];
        _selectionLayer.opacity = 1.0f;
        _selectionLayer.zPosition = 1.0f;
        _selectionLayer.actions = TimelineLayerDisabledActions();
    }
    
    [self ensureLayerAttached:_selectionLayer];

#if SMTimelineDebug
    if (_dbugloBackgroundLayer == nil) {
        _dbugloBackgroundLayer = [[CALayer alloc] init];
        _dbugloBackgroundLayer.actions = TimelineLayerDisabledActions();
        _dbugloBackgroundLayer.zPosition = 5.9f;
    }
    [self ensureLayerAttached:_dbugloBackgroundLayer];

    if (_dbugloOuterBoundsLayer == nil) {
        _dbugloOuterBoundsLayer = [[CALayer alloc] init];
        _dbugloOuterBoundsLayer.actions = TimelineLayerDisabledActions();
        _dbugloOuterBoundsLayer.zPosition = 6.0f;
    }
    [self ensureLayerAttached:_dbugloOuterBoundsLayer];

    if (_dbugloLaneBoundsLayer == nil) {
        _dbugloLaneBoundsLayer = [[CALayer alloc] init];
        _dbugloLaneBoundsLayer.actions = TimelineLayerDisabledActions();
        _dbugloLaneBoundsLayer.zPosition = 6.1f;
    }
    [self ensureLayerAttached:_dbugloLaneBoundsLayer];

    if (_dbugloLaneRectLayer == nil) {
        _dbugloLaneRectLayer = [[CALayer alloc] init];
        _dbugloLaneRectLayer.actions = TimelineLayerDisabledActions();
        _dbugloLaneRectLayer.zPosition = 6.8f;
    }
    [self ensureLayerAttached:_dbugloLaneRectLayer];

    if (_dbugloFullHeightLaneLayer == nil) {
        _dbugloFullHeightLaneLayer = [[CALayer alloc] init];
        _dbugloFullHeightLaneLayer.actions = TimelineLayerDisabledActions();
        _dbugloFullHeightLaneLayer.zPosition = 6.2f;
    }
    [self ensureLayerAttached:_dbugloFullHeightLaneLayer];

    if (_dbugloRulerBandLayer == nil) {
        _dbugloRulerBandLayer = [[CALayer alloc] init];
        _dbugloRulerBandLayer.actions = TimelineLayerDisabledActions();
        _dbugloRulerBandLayer.zPosition = 6.3f;
    }
    [self ensureLayerAttached:_dbugloRulerBandLayer];

    if (_dbugloRulerTickLayer == nil) {
        _dbugloRulerTickLayer = [[CALayer alloc] init];
        _dbugloRulerTickLayer.actions = TimelineLayerDisabledActions();
        _dbugloRulerTickLayer.zPosition = 6.4f;
    }
    [self ensureLayerAttached:_dbugloRulerTickLayer];

    if (_dbugloRulerLabelSafeLayer == nil) {
        _dbugloRulerLabelSafeLayer = [[CALayer alloc] init];
        _dbugloRulerLabelSafeLayer.actions = TimelineLayerDisabledActions();
        _dbugloRulerLabelSafeLayer.zPosition = 6.5f;
    }
    [self ensureLayerAttached:_dbugloRulerLabelSafeLayer];

    if (_dbugloRegionBandLayer == nil) {
        _dbugloRegionBandLayer = [[CALayer alloc] init];
        _dbugloRegionBandLayer.actions = TimelineLayerDisabledActions();
        _dbugloRegionBandLayer.zPosition = 6.6f;
    }
    [self ensureLayerAttached:_dbugloRegionBandLayer];
#endif
}

- (void)ensureActiveLayersIfNeeded
{
    if (_hostLayer == nil) return;

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
        || _backgroundLayer == nil
        || _trackLayer == nil
        || _rulerLayer == nil
        || _rulerDividerLayer == nil
        || _rulerMajorTickLayer == nil
        || _rulerMinorTickLayer == nil
        || _rulerStripeLayer == nil
        || _gridMajorLineLayer == nil
        || _gridMinorLineLayer == nil
        || _rulerLabelLayers == nil
        || _selectionLayer == nil)
            return;

    NSRect fullHeightLaneRect = layout.fullHeightLaneRect;
    NSRect rulerBandRect = layout.rulerBandRect;
    NSRect tickRect = layout.rulerTickRect;
    NSRect labelSafeRect = layout.rulerLabelSafeRect;
    NSRect stripeRect = NSInsetRect(labelSafeRect, -2.0, 0.0);
    NSRect gridRect = layout.laneRect;
    NSRect selectionRect = TimelineRegionRectForLayout(layout);
    
    NSColor *backgroundColor = usableMovie
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

    CGFloat majorTickTop = NSMaxY(rulerBandRect) - 0.5;
    CGFloat majorTickBottom = NSMinY(rulerBandRect) + 0.5;
    CGFloat majorContinuationTop = majorTickBottom;
    CGFloat majorContinuationBottom = NSMinY(fullHeightLaneRect) + 0.5;
    BOOL drawMajorContinuation = (majorContinuationTop > majorContinuationBottom);
    CGFloat minorTickBottom = NSMinY(tickRect) + 0.5;
    CGFloat minorTickRangeHeight = MAX((NSMaxY(tickRect) - 0.5) - minorTickBottom, 1.0);
    CGFloat minorTickHeight = MIN(minorTickRangeHeight - 1.0, MAX(6.0, floor(minorTickRangeHeight * 0.58)));
    CGFloat minorTickTop = minorTickBottom + minorTickHeight;

    for (NSUInteger tickIndex = 0; tickIndex < majorTickCount; tickIndex++)
    {
        NSTimeInterval tickTime = TimelineRulerMajorTickTime(layout, tickIndex, majorTickCount);
        CGFloat tickX = TimelineXPositionForTime(tickTime, layout);
        CGPathMoveToPoint(majorTickPath, NULL, tickX, majorTickTop);
        CGPathAddLineToPoint(majorTickPath, NULL, tickX, majorTickBottom);
      
        if (drawMajorContinuation)
        {
            CGPathMoveToPoint(gridMajorPath, NULL, tickX, majorContinuationTop);
            CGPathAddLineToPoint(gridMajorPath, NULL, tickX, majorContinuationBottom);
        }

        if (tickIndex + 1 < majorTickCount)
        {
            NSTimeInterval nextTickTime = TimelineRulerMajorTickTime(layout, tickIndex + 1, majorTickCount);
            for (NSUInteger minorIndex = 1; minorIndex <= minorTicksPerMajorInterval; minorIndex++) {
                CGFloat fraction = (CGFloat)minorIndex / (CGFloat)(minorTicksPerMajorInterval + 1);
                NSTimeInterval minorTickTime = tickTime + ((nextTickTime - tickTime) * fraction);
                CGFloat minorTickX = TimelineXPositionForTime(minorTickTime, layout);
                CGPathMoveToPoint(minorTickPath, NULL, minorTickX, minorTickTop);
                CGPathAddLineToPoint(minorTickPath, NULL, minorTickX, minorTickBottom);
            }
        }
    }

    if (!NSIsEmptyRect(stripeRect))
    {
        CGFloat stripeSpacing = 11.0;
        CGFloat stripeRun = NSHeight(stripeRect);
        
        for (CGFloat stripeX = NSMinX(stripeRect) - stripeRun; stripeX <= NSMaxX(stripeRect) + stripeRun; stripeX += stripeSpacing)
        {
            CGPathMoveToPoint(stripePath, NULL, stripeX, NSMinY(stripeRect));
            CGPathAddLineToPoint(stripePath, NULL, stripeX + stripeRun, NSMaxY(stripeRect));
        }
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    _backgroundLayer.hidden = NO;
    _backgroundLayer.frame = NSRectToCGRect(bounds);
    _backgroundLayer.backgroundColor = [backgroundColor CGColor];

    _trackLayer.frame = NSRectToCGRect(fullHeightLaneRect);
    _trackLayer.cornerRadius = TimelineLaneCornerRadius();
    _trackLayer.borderWidth = 1.0;
    _trackLayer.borderColor = [trackBorderColor CGColor];
    
    CAGradientLayer *gradientLayer = (CAGradientLayer *)_trackLayer;
    gradientLayer.startPoint = CGPointMake(0.5, 1.0);
    gradientLayer.endPoint = CGPointMake(0.5, 0.0);
    gradientLayer.colors = [NSArray arrayWithObjects:(id)[laneTopColor CGColor], (id)[laneBottomColor CGColor], nil];

    _rulerLayer.hidden = NSIsEmptyRect(rulerBandRect);
    _rulerLayer.frame = NSRectToCGRect(rulerBandRect);
    _rulerLayer.backgroundColor = [rulerColor CGColor];

    _rulerDividerLayer.hidden = NSIsEmptyRect(rulerBandRect);
    _rulerDividerLayer.frame = NSRectToCGRect(dividerRect);
    _rulerDividerLayer.backgroundColor = [dividerColor CGColor];

    _rulerMajorTickLayer.hidden = NSIsEmptyRect(rulerBandRect);
    _rulerMajorTickLayer.frame = NSRectToCGRect(bounds);
    _rulerMajorTickLayer.path = majorTickPath;
    _rulerMajorTickLayer.strokeColor = [[NSColor colorWithCalibratedWhite:0.86 alpha:(usableMovie ? 0.82 : 0.50)] CGColor];
    _rulerMajorTickLayer.lineWidth = 1.1;

    _rulerMinorTickLayer.hidden = NSIsEmptyRect(rulerBandRect);
    _rulerMinorTickLayer.frame = NSRectToCGRect(bounds);
    _rulerMinorTickLayer.path = minorTickPath;
    _rulerMinorTickLayer.strokeColor = [[NSColor colorWithCalibratedWhite:0.84 alpha:(usableMovie ? 0.36 : 0.20)]  CGColor];
    _rulerMinorTickLayer.lineWidth = 1.0;

    _rulerStripeLayer.hidden = NSIsEmptyRect(stripeRect);
    _rulerStripeLayer.frame = NSRectToCGRect(bounds);
    _rulerStripeLayer.path = stripePath;
    _rulerStripeLayer.strokeColor = [[NSColor colorWithCalibratedWhite:0.10 alpha:(usableMovie ? 0.36 : 0.20)]  CGColor];
    _rulerStripeLayer.lineWidth = 1.0;

    _gridMajorLineLayer.hidden = (NSIsEmptyRect(fullHeightLaneRect) || !drawMajorContinuation);
    _gridMajorLineLayer.frame = NSRectToCGRect(bounds);
    _gridMajorLineLayer.path = gridMajorPath;
    _gridMajorLineLayer.strokeColor = [[NSColor colorWithCalibratedWhite:0.58 alpha:(usableMovie ? 0.44 : 0.24)] CGColor];
    _gridMajorLineLayer.lineWidth = 1.0;

    _gridMinorLineLayer.hidden = NSIsEmptyRect(gridRect);
    _gridMinorLineLayer.frame = NSRectToCGRect(bounds);
    _gridMinorLineLayer.path = gridMinorPath;
    _gridMinorLineLayer.strokeColor = [[NSColor colorWithCalibratedWhite:0.90 alpha:(usableMovie ? 0.08 : 0.04)]  CGColor];
    _gridMinorLineLayer.lineWidth = 1.0;

    for (NSUInteger tickIndex = 0;tickIndex < [_rulerLabelLayers count];tickIndex++)
    {
        CATextLayer *majorTickLabel = [_rulerLabelLayers objectAtIndex:tickIndex];
        [self ensureLayerAttached:majorTickLabel];
        BOOL shouldHideLabel = (!usableMovie
                                || tickIndex >= majorTickCount
                                || tickIndex + 1 >= majorTickCount
                                || NSIsEmptyRect(rulerBandRect));
        [majorTickLabel setHidden:shouldHideLabel];
       
        if (shouldHideLabel)
            continue;

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
        [majorTickLabel setFrame:NSRectToCGRect(labelRect)];
        [majorTickLabel setForegroundColor:[[NSColor colorWithCalibratedWhite:0.96 alpha:0.96]  CGColor]];
        [majorTickLabel setShadowOpacity:0.35f];
        [majorTickLabel setShadowRadius:1.0f];
        [majorTickLabel setShadowOffset:CGSizeMake(0.0, -1.0)];

        NSInteger hours = (NSInteger)(tickTime / 3600.0);
        NSInteger minutes = (NSInteger)((tickTime / 60.0)) % 60;
        NSInteger seconds = (NSInteger)tickTime % 60;

        [majorTickLabel setString:[NSString stringWithFormat:@"%02ld:%02ld:%02ld",
                                    (long)hours, (long)minutes, (long)seconds]];
    }

    _selectionLayer.hidden = (!usableMovie || NSWidth(selectionRect) <= 0.0);
    _selectionLayer.frame = NSRectToCGRect(selectionRect);
    _selectionLayer.cornerRadius = 0.0;
    _selectionLayer.backgroundColor = [[NSColor colorWithCalibratedRed:0.88 green:0.74 blue:0.25 alpha:0.35] CGColor];

#if SMTimelineDebug
    [_dbugloBackgroundLayer setFrame:NSRectToCGRect(bounds)];
    [_dbugloBackgroundLayer setBackgroundColor:[[NSColor blackColor] CGColor]];
    
    ConfigureDBUGBandLayer(_dbugloOuterBoundsLayer, layout.outerBounds, [NSColor magentaColor]);
    ConfigureDBUGBandLayer(_dbugloLaneBoundsLayer, layout.laneBounds, [NSColor cyanColor]);
    ConfigureDBUGBandLayer(_dbugloLaneRectLayer, layout.laneRect, [NSColor blueColor]);
    ConfigureDBUGBandLayer(_dbugloFullHeightLaneLayer, layout.fullHeightLaneRect, [NSColor greenColor]);
    ConfigureDBUGBandLayer(_dbugloRulerLabelSafeLayer, labelSafeRect, [NSColor purpleColor]);
    ConfigureDBUGBandLayer(_dbugloRulerBandLayer, rulerBandRect, [NSColor redColor]);
    ConfigureDBUGBandLayer(_dbugloRulerTickLayer, tickRect, [NSColor yellowColor]);
    ConfigureDBUGBandLayer(_dbugloRegionBandLayer, layout.regionBandRect, [NSColor systemPinkColor]);
#endif

    [CATransaction commit];

    CGPathRelease(majorTickPath);
    CGPathRelease(minorTickPath);
    CGPathRelease(stripePath);
    CGPathRelease(gridMajorPath);
    CGPathRelease(gridMinorPath);
}

- (void)updatePlayheadLayersForLayout:(TimelineLayoutSnapshot)layout
                      playheadDragging:(BOOL)playheadDragging
                           usableMovie:(BOOL)usableMovie
{
    [self ensureActiveLayersIfNeeded];

    if (_playheadLayer == nil || _playheadStemLayer == nil || _playheadCapLayer == nil)
        return;

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

