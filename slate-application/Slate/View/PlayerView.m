//
//  PlayerView.m
//  Slate
//
//  Created by Jerry Hale on 3/20/26
//  Copyright (c) 2026 Jerry Hale All rights reserved.

#import "DictionaryKeys.h"

#import "AppController.h"

#import "QuadrantView.h"

#import "PlayerView.h"

@implementation PlayerView

static void *PlayerItemStatusContext = &PlayerItemStatusContext;
static const CGFloat SMCropHandleHitOutset = 7.0f;
static const CGFloat SMCropEdgeHitTolerance = 10.0f;
static const CGFloat SMPlayerDisabledOverlayAlpha = 0.18f;

static void SMCropResizeRectsForRect(CGRect cropRect, CGRect *resizeRects)
{
    if (resizeRects == NULL) {
        return;
    }

    // top row
    resizeRects[0] = CGRectMake(CGRectGetMinX(cropRect), CGRectGetMinY(cropRect), WIDTH, WIDTH);
    resizeRects[1] = CGRectMake(CGRectGetMidX(cropRect) - (WIDTH / 2), CGRectGetMinY(cropRect), WIDTH, WIDTH);
    resizeRects[2] = CGRectMake(CGRectGetMaxX(cropRect) - WIDTH, CGRectGetMinY(cropRect), WIDTH, WIDTH);

    // middle row
    resizeRects[3] = CGRectMake(CGRectGetMinX(cropRect), CGRectGetMidY(cropRect) - (WIDTH / 2), WIDTH, WIDTH);
    resizeRects[4] = CGRectMake(CGRectGetMaxX(cropRect) - WIDTH, CGRectGetMidY(cropRect) - (WIDTH / 2), WIDTH, WIDTH);

    // bottom row
    resizeRects[5] = CGRectMake(CGRectGetMinX(cropRect), CGRectGetMaxY(cropRect) - WIDTH, WIDTH, WIDTH);
    resizeRects[6] = CGRectMake(CGRectGetMidX(cropRect) - (WIDTH / 2), CGRectGetMaxY(cropRect) - WIDTH, WIDTH, WIDTH);
    resizeRects[7] = CGRectMake(CGRectGetMaxX(cropRect) - WIDTH, CGRectGetMaxY(cropRect) - WIDTH, WIDTH, WIDTH);
}

static CGPoint SMCropRectCenter(CGRect rect)
{
    return CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
}

static NSInteger SMCropResizeHandleIndexForPoint(CGPoint point, CGRect cropRect)
{
    CGRect resizeRects[8];
    SMCropResizeRectsForRect(cropRect, resizeRects);

    NSInteger bestIndex = -1;
    CGFloat bestDistance = CGFLOAT_MAX;
    for (NSInteger index = 0; index < 8; index++) {
        CGRect hitRect = CGRectInset(resizeRects[index], -SMCropHandleHitOutset, -SMCropHandleHitOutset);
        if (CGRectContainsPoint(hitRect, point)) {
            CGPoint center = SMCropRectCenter(resizeRects[index]);
            CGFloat dx = point.x - center.x;
            CGFloat dy = point.y - center.y;
            CGFloat distance = (dx * dx) + (dy * dy);
            if (distance < bestDistance) {
                bestDistance = distance;
                bestIndex = index;
            }
        }
    }

    if (bestIndex > -1) {
        return bestIndex;
    }

    BOOL nearLeft = fabs(point.x - CGRectGetMinX(cropRect)) <= SMCropEdgeHitTolerance;
    BOOL nearRight = fabs(point.x - CGRectGetMaxX(cropRect)) <= SMCropEdgeHitTolerance;
    BOOL nearTop = fabs(point.y - CGRectGetMinY(cropRect)) <= SMCropEdgeHitTolerance;
    BOOL nearBottom = fabs(point.y - CGRectGetMaxY(cropRect)) <= SMCropEdgeHitTolerance;

    if (nearTop && nearLeft) {
        return 0;
    }
    if (nearTop && nearRight) {
        return 2;
    }
    if (nearBottom && nearLeft) {
        return 5;
    }
    if (nearBottom && nearRight) {
        return 7;
    }
    if (nearTop) {
        return 1;
    }
    if (nearBottom) {
        return 6;
    }
    if (nearLeft) {
        return 3;
    }
    if (nearRight) {
        return 4;
    }

    return -1;
}

static NSURL *PlayerViewDraggedMovieURL(NSPasteboard *pasteboard)
{
    NSArray *urls = [pasteboard readObjectsForClasses:[NSArray arrayWithObject:[NSURL class]] options:nil];
    NSURL *url = [urls count] > 0 ? [urls objectAtIndex:0] : nil;
    if (url == nil) {
        return nil;
    }

    return ([[url pathExtension] caseInsensitiveCompare:@"mov"] == NSOrderedSame) ? url : nil;
}

static AVPlayerLayer *SMResolvedPlayerLayerForView(AVPlayerView *playerView)
{
    @try {
        id candidate = [playerView valueForKey:@"playerLayer"];
        if ([candidate isKindOfClass:[AVPlayerLayer class]]) {
            return (AVPlayerLayer *)candidate;
        }
    } @catch (NSException *exception) {
        #pragma unused(exception)
    }

    return nil;
}

static CGRect SMOverlayRectFromCropMargins(SMCropMargins margins, CGRect displayedMovieRect, CGSize naturalSize)
{
    if (CGRectIsEmpty(displayedMovieRect) || naturalSize.width <= 0.0 || naturalSize.height <= 0.0) {
        return displayedMovieRect;
    }

    SMCropMargins clampedMargins = SMCropMarginsClamp(margins, naturalSize);
    CGFloat scaleX = CGRectGetWidth(displayedMovieRect) / naturalSize.width;
    CGFloat scaleY = CGRectGetHeight(displayedMovieRect) / naturalSize.height;

    return CGRectMake(CGRectGetMinX(displayedMovieRect) + (clampedMargins.left * scaleX),
                      CGRectGetMinY(displayedMovieRect) + (clampedMargins.top * scaleY),
                      MAX(0.0, CGRectGetWidth(displayedMovieRect) - ((clampedMargins.left + clampedMargins.right) * scaleX)),
                      MAX(0.0, CGRectGetHeight(displayedMovieRect) - ((clampedMargins.top + clampedMargins.bottom) * scaleY)));
}

- (void)stopUnsupportedStateTimer
{
    if (_unsupportedStateTimer == nil) {
        return;
    }

    [_unsupportedStateTimer invalidate];
    [_unsupportedStateTimer release];
    _unsupportedStateTimer = nil;
}

- (void)evaluateUnsupportedPlaybackState:(NSTimer *)timer
{
    #pragma unused(timer)
    AVPlayerItem *playerItem = _observedPlayerItem;
    if (playerItem == nil) {
        return;
    }

    if (playerItem.status == AVPlayerItemStatusReadyToPlay) {
        [self stopUnsupportedStateTimer];
        [self clearMessage];
        return;
    }

    AVAsset *asset = playerItem.asset;
    if ([asset isKindOfClass:[AVURLAsset class]]) {
        AVURLAsset *urlAsset = (AVURLAsset *)asset;
        [urlAsset loadValuesAsynchronouslyForKeys:[NSArray arrayWithObjects:@"playable", @"hasProtectedContent", nil]
                                 completionHandler:^{
                                     NSError *playableError = nil;
                                     NSError *protectedError = nil;
                                     AVKeyValueStatus playableStatus = [urlAsset statusOfValueForKey:@"playable" error:&playableError];
                                     AVKeyValueStatus protectedStatus = [urlAsset statusOfValueForKey:@"hasProtectedContent" error:&protectedError];
                                     BOOL unsupported = (playableStatus == AVKeyValueStatusFailed
                                                         || protectedStatus == AVKeyValueStatusFailed
                                                         || (playableStatus == AVKeyValueStatusLoaded && !urlAsset.playable)
                                                         || (protectedStatus == AVKeyValueStatusLoaded && urlAsset.hasProtectedContent));
                                     #pragma unused(playableError, protectedError)
                                     dispatch_async(dispatch_get_main_queue(), ^{
                                         if (unsupported) {
                                             [self showMessage:@"The movie format is not supported for playback."];
                                             [self stopUnsupportedStateTimer];
                                         }
                                     });
                                 }];
    } else if (playerItem.status != AVPlayerItemStatusUnknown) {
        [self showMessage:@"The movie format is not supported for playback."];
        [self stopUnsupportedStateTimer];
    }
}

- (void)stopObservingPlayerItem
{
    [self stopUnsupportedStateTimer];
    if (_observedPlayerItem == nil) {
        return;
    }

    @try {
        [_observedPlayerItem removeObserver:self forKeyPath:@"status" context:PlayerItemStatusContext];
    } @catch (NSException *exception) {
        #pragma unused(exception)
    }

    [_observedPlayerItem release];
    _observedPlayerItem = nil;
}

- (void)startObservingPlayerItem:(AVPlayerItem *)playerItem
{
    [self stopObservingPlayerItem];

    if (playerItem == nil) {
        return;
    }

    _observedPlayerItem = [playerItem retain];
    [_observedPlayerItem addObserver:self
                          forKeyPath:@"status"
                             options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew)
                             context:PlayerItemStatusContext];
    _unsupportedStateTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0
                                                               target:self
                                                             selector:@selector(evaluateUnsupportedPlaybackState:)
                                                             userInfo:nil
                                                              repeats:YES] retain];
}

- (void)updatePlayButtonTitleForRate:(float)rate
{
    [_playButton setTitle:(rate == 1.0f ? @"Pause" : @"Play")];
}

- (void)stopShuttle
{
    if (_shuttleTimer != nil) {
        [_shuttleTimer invalidate];
        [_shuttleTimer release];
        _shuttleTimer = nil;
    }

    _shuttleRate = 0.0f;
}

- (void)playMovieAtRate:(float)rate
{
    [self stopShuttle];
    [[self movie] setRate:rate];
    [self updatePlayButtonTitleForRate:rate];
}

- (void)shuttleBackwardTick:(NSTimer *)timer
{
    #pragma unused(timer)
    NSInteger stepCount = MAX(1, (NSInteger)lroundf(fabsf(_shuttleRate)));

    for (NSInteger index = 0; index < stepCount; index++) {
        [[self movie] stepBackward];
    }
}

- (void)startBackwardShuttleWithRate:(float)rate
{
    [self stopShuttle];
    _shuttleRate = rate;
    _shuttleTimer = [[NSTimer scheduledTimerWithTimeInterval:(1.0 / 30.0)
                                                      target:self
                                                    selector:@selector(shuttleBackwardTick:)
                                                    userInfo:nil
                                                     repeats:YES] retain];
    [self updatePlayButtonTitleForRate:rate];
}

- (void)ensurePlayerLayer
{
    [self setWantsLayer:YES];
    if (_backgroundLayer == nil) {
        _backgroundLayer = [[CALayer alloc] init];
        _backgroundLayer.zPosition = -1.0;
        _backgroundLayer.backgroundColor = [NSColor darkGrayColor].CGColor;
        [self.layer insertSublayer:_backgroundLayer atIndex:0];
    }
    self.videoGravity = AVLayerVideoGravityResizeAspect;
}

- (void)ensureDisabledOverlayView
{
    if (_disabledOverlayView != nil) {
        return;
    }

    NSView *containerView = self.contentOverlayView ?: self;
    _disabledOverlayView = [[NSView alloc] initWithFrame:NSZeroRect];
    _disabledOverlayView.wantsLayer = YES;
    _disabledOverlayView.layer.backgroundColor = [[NSColor colorWithCalibratedWhite:1.0
                                                                               alpha:SMPlayerDisabledOverlayAlpha] CGColor];
    _disabledOverlayView.layer.borderColor = [[NSColor colorWithCalibratedWhite:1.0 alpha:0.14] CGColor];
    _disabledOverlayView.layer.borderWidth = 1.0;
    _disabledOverlayView.hidden = YES;
    _disabledOverlayView.autoresizingMask = (NSViewWidthSizable | NSViewHeightSizable);
    _disabledOverlayView.frame = containerView.bounds;
    [containerView addSubview:_disabledOverlayView positioned:NSWindowAbove relativeTo:nil];
}

- (void)updateDisabledOverlayFrame
{
    if (_disabledOverlayView == nil) {
        return;
    }

    NSView *containerView = [_disabledOverlayView superview] ?: self.contentOverlayView ?: self;
    [_disabledOverlayView setFrame:[containerView bounds]];
    [containerView addSubview:_disabledOverlayView positioned:NSWindowAbove relativeTo:nil];
}

- (void)updateDisabledOverlayVisibility
{
    if (_disabledOverlayView == nil) {
        return;
    }

    BOOL hasMovie = NO;
    AppController *appController = appcontroller();
    if (appController != nil) {
        hasMovie = [appController hasMovie];
    } else {
        hasMovie = (_movie != nil && [_movie URL] != nil);
    }
    [_disabledOverlayView setHidden:hasMovie];
}

- (void)ensureTimecodeOverlayView
{
    if (_timecodeOverlayView != nil) {
        return;
    }

    NSView *containerView = self.contentOverlayView ?: self;

    _timecodeOverlayView = [[NSView alloc] initWithFrame:NSZeroRect];
    _timecodeOverlayView.wantsLayer = YES;
    _timecodeOverlayView.layer.backgroundColor = nil;
    _timecodeOverlayView.hidden = YES;

    _timecodeLabel = [[NSTextField alloc] initWithFrame:NSZeroRect];
    [_timecodeLabel setBezeled:NO];
    [_timecodeLabel setBordered:NO];
    [_timecodeLabel setEditable:NO];
    [_timecodeLabel setSelectable:NO];
    [_timecodeLabel setDrawsBackground:NO];
    [_timecodeLabel setAlignment:NSTextAlignmentCenter];
    [_timecodeLabel setTextColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.8]];
    
    
    [_timecodeLabel setFont:[NSFont monospacedSystemFontOfSize:48.0 weight:NSFontWeightThin]];
    [_timecodeLabel setUsesSingleLineMode:YES];
    [_timecodeLabel setLineBreakMode:NSLineBreakByClipping];
    [_timecodeOverlayView addSubview:_timecodeLabel];
    [containerView addSubview:_timecodeOverlayView];
}

- (void)ensureSubtitleOverlayView
{
    if (_subtitleOverlayView != nil) {
        return;
    }

    NSView *containerView = self.contentOverlayView ?: self;
    _subtitleOverlayView = [[NSView alloc] initWithFrame:NSZeroRect];
    _subtitleOverlayView.wantsLayer = YES;
    _subtitleOverlayView.layer.backgroundColor = nil;
    _subtitleOverlayView.layer.cornerRadius = 0.0;
    _subtitleOverlayView.hidden = YES;

    _subtitleLabel = [[NSTextField alloc] initWithFrame:NSZeroRect];
    [_subtitleLabel setBezeled:NO];
    [_subtitleLabel setBordered:NO];
    [_subtitleLabel setEditable:NO];
    [_subtitleLabel setSelectable:NO];
    [_subtitleLabel setDrawsBackground:YES];
    [_subtitleLabel setBackgroundColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.35]];
    [_subtitleLabel setAlignment:NSTextAlignmentCenter];
    [_subtitleLabel setTextColor:[NSColor whiteColor]];
    [_subtitleLabel setFont:[NSFont systemFontOfSize:20.0 weight:NSFontWeightMedium]];
    [_subtitleLabel setLineBreakMode:NSLineBreakByWordWrapping];
    [_subtitleLabel setUsesSingleLineMode:NO];
    [_subtitleOverlayView addSubview:_subtitleLabel];
    [containerView addSubview:_subtitleOverlayView];
}

- (void)ensureMessageOverlayView
{
    if (_messageOverlayView != nil) {
        return;
    }

    NSView *containerView = self.contentOverlayView ?: self;
    _messageOverlayView = [[NSView alloc] initWithFrame:NSZeroRect];
    _messageOverlayView.wantsLayer = YES;
    _messageOverlayView.layer.backgroundColor = [[NSColor colorWithCalibratedWhite:0.0 alpha:0.55] CGColor];
    _messageOverlayView.layer.cornerRadius = 10.0;
    _messageOverlayView.hidden = YES;

    _messageLabel = [[NSTextField alloc] initWithFrame:NSZeroRect];
    [_messageLabel setBezeled:NO];
    [_messageLabel setBordered:NO];
    [_messageLabel setEditable:NO];
    [_messageLabel setSelectable:NO];
    [_messageLabel setDrawsBackground:NO];
    [_messageLabel setAlignment:NSTextAlignmentCenter];
    [_messageLabel setTextColor:[NSColor whiteColor]];
    [_messageLabel setFont:[NSFont boldSystemFontOfSize:18.0]];
    [_messageLabel setLineBreakMode:NSLineBreakByWordWrapping];
    [_messageLabel setUsesSingleLineMode:NO];
    [_messageOverlayView addSubview:_messageLabel];
    [containerView addSubview:_messageOverlayView];
}

- (void)updateTimecodeOverlayFrame
{
    if (_timecodeOverlayView == nil) {
        return;
    }

    NSRect bounds = self.bounds;
    CGFloat overlayWidth = MIN(608.0, MAX(464.0, NSWidth(bounds) * 0.656));
    overlayWidth = MIN(overlayWidth, MAX(220.0, NSWidth(bounds) - 24.0));
    CGFloat overlayHeight = 54.0;
    CGFloat bottomInset = MAX(12.0, NSHeight(bounds) * 0.04);
    if (overlayHeight + bottomInset > NSHeight(bounds)) {
        overlayHeight = MAX(24.0, NSHeight(bounds) - bottomInset);
    }
    NSRect overlayFrame = NSMakeRect(NSMidX(bounds) - (overlayWidth / 2.0),
                                     NSMinY(bounds) + bottomInset,
                                     overlayWidth,
                                     overlayHeight);
    [_timecodeOverlayView setFrame:overlayFrame];
    [_timecodeLabel setFrame:_timecodeOverlayView.bounds];
}

- (void)updateSubtitleOverlayFrame
{
    if (_subtitleOverlayView == nil) {
        return;
    }

    NSRect bounds = self.bounds;
    [_subtitleOverlayView setFrame:bounds];

    CGFloat horizontalInset = MAX(20.0, NSWidth(bounds) * 0.08);
    CGFloat subtitleHeight = MAX(48.0, NSHeight(bounds) * 0.16);
    CGFloat bottomInset = MAX(18.0, NSHeight(bounds) * 0.06);
    CGFloat maxSubtitleHeight = MAX(28.0, NSHeight(bounds) - (bottomInset * 1.5));
    subtitleHeight = MIN(subtitleHeight, maxSubtitleHeight);

    NSRect subtitleLabelFrame = NSMakeRect(horizontalInset,
                                           bottomInset,
                                           MAX(0.0, NSWidth(bounds) - (horizontalInset * 2.0)),
                                           subtitleHeight);
    [_subtitleLabel setFrame:NSIntegralRect(subtitleLabelFrame)];
}

- (void)updateMessageOverlayFrame
{
    if (_messageOverlayView == nil) {
        return;
    }

    NSRect bounds = self.bounds;
    CGFloat overlayWidth = MIN(MAX(320.0, NSWidth(bounds) * 0.6), MAX(320.0, NSWidth(bounds) - 40.0));
    CGFloat overlayHeight = MIN(120.0, MAX(90.0, NSHeight(bounds) * 0.22));
    NSRect overlayFrame = NSMakeRect(NSMidX(bounds) - (overlayWidth / 2.0),
                                     NSMidY(bounds) - (overlayHeight / 2.0),
                                     overlayWidth,
                                     overlayHeight);

    [_messageOverlayView setFrame:overlayFrame];
    [_messageLabel setFrame:NSInsetRect(_messageOverlayView.bounds, 16.0, 14.0)];
}

@synthesize cropRect = _cropRect;
@synthesize cropLayer = _cropLayer;
@synthesize crop = _crop;
@synthesize movie = _movie;

- (SMMovie *)movie
{
    return _movie;
}

- (void)clearFirstResponderIfNeededForWindow:(NSWindow *)window
{
    id firstResponder = [window firstResponder];

    if (![firstResponder isKindOfClass:[NSView class]])
        return;

    NSView *firstResponderView = (NSView *)firstResponder;
    if (firstResponderView == self || [firstResponderView isDescendantOf:self])
        [window makeFirstResponder:nil];
}

- (void)setMovie:(SMMovie *)movie
{
    SMTimelineLog(@"Timeline playback playerSetMovie begin oldMovie=%@ newMovie=%@ currentPlayer=%@ currentItem=%@",
          _movie,
          movie,
          self.player,
          self.player.currentItem);
    if (_movie == movie) {
        if (movie == nil) {
            [self ensurePlayerLayer];
            [self ensureDisabledOverlayView];
            [self updateDisabledOverlayFrame];
            [self updateDisabledOverlayVisibility];
        }
        SMTimelineLog(@"Timeline playback playerSetMovie skipped sameMovie=%@", movie);
        return;
    }

    [_movie release];
    _movie = [movie retain];
    [self ensurePlayerLayer];
    [self ensureDisabledOverlayView];
    [self ensureTimecodeOverlayView];
    [self ensureSubtitleOverlayView];
    [self ensureMessageOverlayView];
    [self startObservingPlayerItem:movie.player.currentItem];
    self.player = movie.player;
    [self updateDisabledOverlayFrame];
    [self updateDisabledOverlayVisibility];
    [self updateTimecodeOverlayFrame];
    [self updateSubtitleOverlayFrame];
    [self updateMessageOverlayFrame];
    [self clearMessage];
    [self refreshSubtitleOverlay];
    SMTimelineLog(@"Timeline playback playerSetMovie end movie=%@ player=%@ currentItem=%@ rate=%.3f playButtonTitle=%@",
          _movie,
          self.player,
          self.player.currentItem,
          [_movie rate],
          [_playButton title]);
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    #pragma unused(change)
    if (context == PlayerItemStatusContext) {
        AVPlayerItem *playerItem = (AVPlayerItem *)object;
        SMTimelineLog(@"Timeline playback playerItemStatus keyPath=%@ item=%@ status=%ld error=%@ movie=%@ player=%@ rate=%.3f",
              keyPath,
              playerItem,
              (long)playerItem.status,
              playerItem.error,
              _movie,
              self.player,
              [_movie rate]);
        if (playerItem.status == AVPlayerItemStatusFailed) {
            [self showMessage:@"The movie format is not supported for playback."];
            [self stopUnsupportedStateTimer];
        } else if (playerItem.status == AVPlayerItemStatusReadyToPlay && _movie != nil) {
            [self stopUnsupportedStateTimer];
            [self clearMessage];
        }
        return;
    }

    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (NSRect)movieBounds
{
    if (!NSIsEmptyRect(self.videoBounds)) {
        return self.videoBounds;
    }
    return self.bounds;
}

- (void)setPlayerLayerBackgroundColor:(NSColor *)color
{
    [self ensurePlayerLayer];
    _backgroundLayer.backgroundColor = color.CGColor;
    self.layer.backgroundColor = color.CGColor;

    AVPlayerLayer *playerLayer = SMResolvedPlayerLayerForView(self);
    if (playerLayer != nil) {
        playerLayer.backgroundColor = color.CGColor;
    }
}

- (void)refreshSubtitleOverlay
{
    [self ensureTimecodeOverlayView];

    if (_movie == nil) {
        [_timecodeOverlayView setHidden:YES];
        [_timecodeLabel setStringValue:@""];
        [_subtitleOverlayView setHidden:YES];
        [_subtitleLabel setStringValue:@""];
        return;
    }

    if ([appcontroller() timecodeOverlayVisible] && [[_movie tracksOfMediaType:SMMediaTypeTimeCode] count] > 0) {
        NSString *timecodeString = [_movie currentTimeCodeString];
        [_timecodeLabel setStringValue:(timecodeString ?: @"--:--:--:--")];
        [_timecodeOverlayView setHidden:NO];
    } else {
        [_timecodeOverlayView setHidden:YES];
        [_timecodeLabel setStringValue:@""];
    }

    SMTime currentTime = [_movie currentTime];
    NSMutableArray *activeSubtitleLines = [NSMutableArray array];
    BOOL showSubtitles = [appcontroller() subtitleVisible];
    BOOL showClosedCaptions = [appcontroller() closedCaptionVisible];
    for (SMTrack *track in [_movie subtitleSidecarTracks]) {
        NSString *mediaType = [track attributeForKey:SMTrackMediaTypeAttribute];
        if ([mediaType isEqualToString:SMMediaTypeClosedCaption]) {
            if (!showClosedCaptions) {
                continue;
            }
        } else if (!showSubtitles) {
            continue;
        }

        if (![track isEnabled]) {
            continue;
        }
        NSString *subtitleText = [track subtitleTextAtTime:currentTime];
        if (subtitleText.length > 0) {
            [activeSubtitleLines addObject:subtitleText];
        }
    }

    if (activeSubtitleLines.count == 0) {
        [_subtitleOverlayView setHidden:YES];
        [_subtitleLabel setStringValue:@""];
        return;
    }

    NSString *subtitleText = [activeSubtitleLines componentsJoinedByString:@"\n"];
    [_subtitleLabel setStringValue:subtitleText];
    [_subtitleOverlayView setHidden:NO];
}

- (void)showMessage:(NSString *)message
{
    [self ensureMessageOverlayView];
    [self updateMessageOverlayFrame];
    [_messageLabel setStringValue:(message ?: @"")];
    [_messageOverlayView setHidden:(message.length == 0)];
}

- (void)clearMessage
{
    if (_messageOverlayView == nil) {
        return;
    }

    [_messageLabel setStringValue:@""];
    [_messageOverlayView setHidden:YES];
}

- (void)layout
{
    [super layout];
    [self updateDisabledOverlayFrame];
    [self updateDisabledOverlayVisibility];
    [self updateTimecodeOverlayFrame];
    [self updateSubtitleOverlayFrame];
    [self updateMessageOverlayFrame];

    if (_cropLayer != nil) {
        SMCropMargins currentMargins = [self sourceCropMarginsFromOverlay];
        CGSize naturalSize = NSSizeToCGSize([[[appcontroller() movie] attributeForKey:SMMovieNaturalSizeAttribute] sizeValue]);
        CGRect movieBounds = NSRectToCGRect(self.movieBounds);
        _cropLayer.frame = NSRectToCGRect(self.movieBounds);
        _cropLayer.bounds = CGRectMake(0.0, 0.0, _cropLayer.frame.size.width, _cropLayer.frame.size.height);
        _cropRect = SMOverlayRectFromCropMargins(currentMargins, movieBounds, naturalSize);
        _cropRect = [self constrainCropRect:_cropRect];
        [_cropLayer setNeedsDisplay];
    }
}

#pragma mark -
#pragma mark Player Controls

- (void)stopMovie
{
    [self stopShuttle];
    [[self movie] stop];
    [self updatePlayButtonTitleForRate:0.0f];
}

-(IBAction)setVolume:(id)sender
{
    [[self movie] setVolume:[sender floatValue]];
}

-(void)playerItemDidPlayToEndTime:(NSNotification *)notification
{
    #pragma unused (notification)
    [self stopMovie];
}

-(IBAction)togglePlayPause:(id)sender
{
    #pragma unused (sender)
    float rate = [[self movie] rate];
    SMTimelineLog(@"Timeline playback playerTogglePlayPause begin movie=%@ player=%@ currentItem=%@ itemStatus=%ld rate=%.3f shuttleTimer=%@ buttonTitle=%@",
          [self movie],
          self.player,
          self.player.currentItem,
          (long)self.player.currentItem.status,
          rate,
          _shuttleTimer,
          [_playButton title]);

    if (rate == 1.0f && _shuttleTimer == nil)
        [self stopMovie];
    else
        [self playMovieAtRate:1.0f];
    SMTimelineLog(@"Timeline playback playerTogglePlayPause end movie=%@ player=%@ currentItem=%@ itemStatus=%ld rate=%.3f buttonTitle=%@",
          [self movie],
          self.player,
          self.player.currentItem,
          (long)self.player.currentItem.status,
          [[self movie] rate],
          [_playButton title]);
}

-(IBAction)stepForward:(id)sender
{
    #pragma unused (sender)
    [self stopMovie];
    [[self movie] stepForward];
}

-(IBAction)stepBackward:(id)sender
{
    #pragma unused (sender)
    [self stopMovie];
    [[self movie] stepBackward];
}

-(IBAction)fastForward:(id)sender
{
    #pragma unused (sender)
    [self playMovieAtRate:2.0f];
}

-(IBAction)fastBackward:(id)sender
{
    #pragma unused (sender)
    AVPlayerItem *playerItem = self.movie.player.currentItem;

    if ([playerItem canPlayFastReverse]) {
        [self playMovieAtRate:-2.0f];
    } else if ([playerItem canPlayReverse]) {
        [self playMovieAtRate:-1.0f];
    } else {
        [self startBackwardShuttleWithRate:-2.0f];
    }
}

#pragma mark -
-(void)zoomToCorner:(NSNotification *)notification
{
    NSInteger lastClicked = [(NSNumber *)[[notification userInfo] objectForKey:kKeyLastClicked] integerValue];
    double  delta = [(NSNumber *)[[notification userInfo] objectForKey:kKeyScaleFactor]doubleValue];
    
    if (delta == -100)
    {
        if (_scaleFactor <= 0.0 || !isfinite(_scaleFactor)) {
            _scaleFactor = 0.0;
            return;
        }

        delta = 1.0 / _scaleFactor;
        _scaleFactor = 0;
    }
    else
        _scaleFactor = delta;

    if (delta <= 0.0 || !isfinite(delta)) {
        return;
    }
        
    CGRect  pf = NSRectToCGRect([self frame]);
    NSRect  spf = NSRectFromCGRect(CGRectApplyAffineTransform(pf, CGAffineTransformMakeScale(delta, delta)));

    if (!isfinite(spf.origin.x) || !isfinite(spf.origin.y)
        || !isfinite(spf.size.width) || !isfinite(spf.size.height)
        || spf.size.width <= 0.0 || spf.size.height <= 0.0) {
        return;
    }

    switch (lastClicked)
    {
        case 0:
        case -1:
        case -2:
        case -3:
        case -4:
        case 3:
            //  zoom to upper left (coordinate system is flipped)
            spf.origin.x = spf.origin.y = 0;
        break;
        case 1:
            //  zoom to lower left
            spf.origin.x = 0;
            spf.origin.y = pf.size.height - spf.size.height;
        break;
        case 2:
            //  zoom to lower right
            spf.origin.x = pf.size.width - spf.size.width;
            spf.origin.y = pf.size.height - spf.size.height;
        break;
        case 4:
            //  zoom to upper right
            spf.origin.x = pf.size.width - spf.size.width;
            spf.origin.y = spf.size.height - pf.size.height;
        break;
    }

    [self setFrame:spf];
    [self setNeedsDisplay:YES];
    
    if (_cropLayer)
    {
        _cropLayer.frame = NSRectToCGRect(self.movieBounds);
        _cropLayer.bounds = CGRectMake(0.0, 0.0, _cropLayer.frame.size.width, _cropLayer.frame.size.height);
        _cropRect = CGRectApplyAffineTransform(_cropRect, CGAffineTransformMakeScale(delta, delta));

        [_cropLayer setNeedsDisplay];
    }
    //  NSLog(@"frame x:%f y:%f width:%f height:%f", _cropLayer.frame.origin.x, _cropLayer.frame.origin.y, _cropLayer.frame.size.width, _cropLayer.frame.size.height);
    //  NSLog(@"scaledFrame x:%f y:%f width:%f height:%f", spf.origin.x, spf.origin.y, spf.size.width, spf.size.height);
}

- (SMCropMargins)sourceCropMarginsFromOverlay
{
    if (_cropLayer == nil) {
        return SMCropMarginsZero();
    }

    return SMCropMarginsFromOverlayRect(_cropRect,
                                           NSRectToCGRect(self.movieBounds),
                                           NSSizeToCGSize([[[appcontroller() movie] attributeForKey:SMMovieNaturalSizeAttribute] sizeValue]));
}

- (CGRect)sourceCropRectFromOverlay
{
    return SMCropRectFromMargins([self sourceCropMarginsFromOverlay], NSSizeToCGSize([[[appcontroller() movie] attributeForKey:SMMovieNaturalSizeAttribute] sizeValue]));
}

-(CGRect)constrainCropRect:(CGRect)frame
{
    if (frame.size.width < 3 * WIDTH)
    {
        frame.size.width = 3 * WIDTH;
    }
    if (frame.size.height < 3 * WIDTH)
    {
        frame.size.height = 3 * WIDTH;
    }
    
	CGRect	bounds = _cropLayer.frame;
	
	//	constrain the cropRect to the crop layer frame
    if (frame.size.height > bounds.size.height)
        frame.size.height = bounds.size.height;
    
    if (frame.size.width > bounds.size.width)
        frame.size.width = bounds.size.width;

	if (frame.origin.x < bounds.origin.x)
		frame.origin.x = bounds.origin.x;
	
	if (frame.origin.y <  bounds.origin.y)
		frame.origin.y = bounds.origin.y;

	if (frame.origin.x + frame.size.width > bounds.origin.x + bounds.size.width)
		frame.origin.x = bounds.size.width + bounds.origin.x - frame.size.width;
	
	if (frame.origin.y + frame.size.height > bounds.origin.y + bounds.size.height)
		frame.origin.y = bounds.size.height + bounds.origin.y - frame.size.height;

    return (frame);
}

//  mouse dragging cropRect
-(void)dragCropRectToPoint:(NSPoint)point
{
    [[NSCursor closedHandCursor] set];

    NSPoint delta = NSMakePoint(point.x - _cropDragStartPoint.x, point.y - _cropDragStartPoint.y);
    CGRect frame = _cropDragInitialRect;

    frame.origin.x += delta.x;
    frame.origin.y += delta.y;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _cropRect = [self constrainCropRect:frame];
    [CATransaction commit];

    //	update drag handles
    [_cropLayer setNeedsDisplay];
		
	[[NSNotificationCenter defaultCenter] postNotificationName:REFRESH_CROP_VALUES object:self];
}

//	mouse dragging of the cropRect has ended
- (void)dragCropRectEndAtPoint:(NSPoint)point
{
    [self dragCropRectToPoint:point];
    _isDraggingCropRect = NO;
    [[NSCursor openHandCursor] set];
    [[NSNotificationCenter defaultCenter] postNotificationName:REFRESH_CROP_VALUES object:self];
}

//	resize cropRect via a drag handle
- (void)resizeCropRectToPoint:(NSPoint)point
{
    double delta_x = round(point.x - _cropDragStartPoint.x);
    double delta_y = round(point.y - _cropDragStartPoint.y);
    CGRect frame = _cropDragInitialRect;

	switch (_activeResizeHandleIndex)
	{
        case 0: //	top left
            frame.origin.x += delta_x;
				frame.origin.y += delta_y;
            frame.size.width -= delta_x;
            frame.size.height -= delta_y;
			break;
        case 1: //	top middle
            frame.origin.y += delta_y;
				frame.size.height -= delta_y;
			break;
        case 2: //	top right
            frame.size.width += delta_x;
            frame.origin.y += delta_y;
				frame.size.height -= delta_y;
			break;

        case 3: //	left middle
            frame.origin.x += delta_x;
            frame.size.width -= delta_x;
		break;
        case 4: //	right middle
            frame.size.width += delta_x;
		break;

        case 5: //	bottom left
            frame.origin.x += delta_x;
            frame.size.width -= delta_x;
            frame.size.height += delta_y;
			break;
        case 6: //	bottom middle
            frame.size.height += delta_y;
			break;
        case 7: //	bottom right
            frame.size.width += delta_x;
            frame.size.height += delta_y;
			break;
        default:
		break;
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _cropRect = [self constrainCropRect:frame];
    [CATransaction commit];

    //	update resize handles
    [_cropLayer setNeedsDisplay];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:REFRESH_CROP_VALUES object:self];
}

- (void)resizeCropRectEndAtPoint:(NSPoint)point
{
    [self resizeCropRectToPoint:point];
    _isResizingCropRect = NO;
    _activeResizeHandleIndex = -1;
    [[NSNotificationCenter defaultCenter] postNotificationName:REFRESH_CROP_VALUES object:self];
}

#define PointInRect(p,r) NSPointInRect(p, NSRectFromCGRect(r))

-(void)resizeRectsForFrame:(CGRect *)resizeRects
{
    SMCropResizeRectsForRect(_cropRect, resizeRects);
}

- (NSInteger)resizeHandleIndexForPoint:(NSPoint)point
{
    return SMCropResizeHandleIndexForPoint(NSPointToCGPoint(point), _cropRect);
}

- (void)updateCursorForPoint:(NSPoint)mouse
{
    if (_cropLayer == nil) {
        [[NSCursor arrowCursor] set];
        return;
    }

    NSInteger resizeIndex = [self resizeHandleIndexForPoint:mouse];
    if (resizeIndex == -1) {
        if (PointInRect(mouse, _cropRect))
            [[NSCursor openHandCursor] set];
        else
            [[NSCursor arrowCursor] set];
        return;
    }

    switch (resizeIndex)
    {
        case 0:
        case 7:
            [_cursNorthWestSouthEast set];
            break;
        case 1:
        case 6:
            [_cursNorthSouth set];
            break;
        case 2:
        case 5:
            [_cursNorthEastSouthWest set];
            break;
        case 3:
        case 4:
            [_cursEastWest set];
            break;
        default:
            [[NSCursor arrowCursor] set];
            break;
    }
}

-(IBAction)toggleCropRect:(id)sender
{
    if ([sender intValue] == 1)
        [self createCropRect];
    else
       [self deleteCropRect]; 
}

-(void)createCropRect
{
    if (_cropLayer != nil) {
        return;
    }

    _cropLayer = [[CAShapeLayer alloc] init];

    [self setWantsLayer:YES];
    [self.layer addSublayer:_cropLayer];

    _cropLayer.delegate = self;
    _cropLayer.backgroundColor = [NSColor clearColor].CGColor;

    //	we have to do all of the size updates to the
    //  Crop Layer manually to maintain the aspect ratio
    //  on Full Screen Enter and Exit
    [_cropLayer setFillColor:[[NSColor colorWithDeviceRed:1.0 green:1.0 blue:0.8 alpha:0.4] CGColor]];
    [_cropLayer setStrokeColor:[[NSColor colorWithDeviceRed:1.0 green:0.0 blue:0.0 alpha:1.0] CGColor]];
    [_cropLayer setLineWidth:1.0f];
    [_cropLayer setLineJoin:kCALineJoinMiter];
    [_cropLayer setLineDashPattern:[NSArray arrayWithObjects:[NSNumber numberWithInt:10], [NSNumber numberWithInt:5],  nil]];

    CABasicAnimation    *ba = [CABasicAnimation  animationWithKeyPath:@"lineDashPhase"];

    [ba setFromValue:[NSNumber numberWithFloat:0.0f]];
    [ba setToValue:[NSNumber numberWithFloat:15.0f]];
    [ba setDuration:0.50f];
    [ba setRepeatCount:1e10f];

    [_cropLayer addAnimation:ba forKey:@"linePhase"];

    _cropLayer.frame = NSRectToCGRect(self.movieBounds);
    _cropLayer.bounds = CGRectMake(0.0, 0.0, _cropLayer.frame.size.width, _cropLayer.frame.size.height);
    _cropRect = _cropLayer.frame;

    [_cropLayer setNeedsDisplay];
    [[NSNotificationCenter defaultCenter] postNotificationName:REFRESH_CROP_VALUES object:self];
}

-(void)deleteCropRect
{    
    [_cropLayer removeFromSuperlayer];
    [_cropLayer release];
    _cropLayer = nil;
    _cropRect = CGRectZero;

    [[NSCursor arrowCursor] set];
    [[NSNotificationCenter defaultCenter] postNotificationName:REFRESH_CROP_VALUES object:self];
}

#pragma mark -
#pragma mark Mouse Actions
- (void)handleMouseClickWithEvent:(NSEvent *)event
{
    NSEventModifierFlags modifiers = [event modifierFlags];
    if ((modifiers & NSCommandKeyMask) != 0 && _cropLayer == nil)
    {
			[self createCropRect];
        [_crop setState:1];
    }
    else if ((modifiers & NSAlternateKeyMask) != 0)
    {
        [self deleteCropRect];
        [_crop setState:0];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:REFRESH_CROP_VALUES object:nil];
}

#pragma mark -
#pragma mark Drag & Drop
-(NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
    NSPasteboard *pboard = [sender draggingPasteboard];
    NSDragOperation sourceDragMask  = [sender draggingSourceOperationMask];

    if (PlayerViewDraggedMovieURL(pboard) != nil)
        if (sourceDragMask & NSDragOperationCopy)
            return NSDragOperationCopy;

    return (NSDragOperationNone);
}

-(BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
    NSPasteboard *pboard = [sender draggingPasteboard];
    NSURL *url = PlayerViewDraggedMovieURL(pboard);
    if (url == nil) {
        return NO;
    }

    AppController *app = appcontroller();
    [app application:nil openFile:[url path]];
    return YES;
}

#pragma mark -
#pragma mark Overrides

-(BOOL) isFlipped { return (YES); }
-(void) viewWillMoveToWindow:(NSWindow *)newWindow
{
    if (newWindow != self.window && self.window != nil)
        [self clearFirstResponderIfNeededForWindow:self.window];

    [super viewWillMoveToWindow:newWindow];
}

- (void)updateTrackingAreas
{
    [super updateTrackingAreas];

    if (_trackingArea != nil)
    {
        [self removeTrackingArea:_trackingArea];
        [_trackingArea release];
    }

    _trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds
                                                 options:(NSTrackingMouseMoved | NSTrackingActiveAlways | NSTrackingInVisibleRect | NSTrackingCursorUpdate)
                                                   owner:self
                                                userInfo:nil];
    [self addTrackingArea:_trackingArea];
}

- (void)mouseMoved:(NSEvent *)theEvent
{
    NSPoint mouse = [self convertPoint:theEvent.locationInWindow fromView:nil];
    [self updateCursorForPoint:mouse];
}

- (void)cursorUpdate:(NSEvent *)event
{
    NSPoint mouse = [self convertPoint:event.locationInWindow fromView:nil];
    [self updateCursorForPoint:mouse];
}

- (NSView *)hitTest:(NSPoint)point
{
    NSPoint localPoint = point;
    if (self.superview != nil) {
        localPoint = [self convertPoint:point fromView:self.superview];
    }

    if (_cropLayer != nil) {
        NSInteger resizeIndex = [self resizeHandleIndexForPoint:localPoint];
        if (resizeIndex > -1 || PointInRect(localPoint, _cropRect)) {
            return self;
        }
    }

    return [super hitTest:point];
}

//  route all events to one of the Trackers.
-(BOOL) acceptsFirstMouse:(NSEvent *)theEvent
{
    #pragma unused (theEvent)
    return (YES);
}
-(void)mouseDown:(NSEvent *)event
{
    _lastDragLocation = [event locationInWindow];
    [self handleMouseClickWithEvent:event];

    if (_cropLayer == nil) {
        [super mouseDown:event];
        return;
    }

    NSPoint mouse = [self convertPoint:[event locationInWindow] fromView:nil];
    NSInteger resizeIndex = [self resizeHandleIndexForPoint:mouse];
    if (resizeIndex > -1) {
        _isResizingCropRect = YES;
        _isDraggingCropRect = NO;
        _activeResizeHandleIndex = resizeIndex;
        _cropDragStartPoint = mouse;
        _cropDragInitialRect = _cropRect;
        return;
    }

    if (NSPointInRect(mouse, NSRectFromCGRect(_cropRect))) {
        _isDraggingCropRect = YES;
        _isResizingCropRect = NO;
        _activeResizeHandleIndex = -1;
        _cropDragStartPoint = mouse;
        _cropDragInitialRect = _cropRect;
        [[NSCursor closedHandCursor] set];
        return;
    }

    [super mouseDown:event];
}

-(void)mouseDragged:(NSEvent *)event
{
    NSEventModifierFlags modifiers = [event modifierFlags];
    BOOL wantsInspectionPan = ((modifiers & NSShiftKeyMask) != 0)
        && ((modifiers & NSAlternateKeyMask) != 0)
        && (_scaleFactor > 1.0)
        && !_isResizingCropRect
        && !_isDraggingCropRect;

    if (wantsInspectionPan)
    {
        NSPoint newDragLocation = [event locationInWindow];
        NSPoint thisOrigin = [self frame].origin;
        
        thisOrigin.x += (-_lastDragLocation.x + newDragLocation.x);
        thisOrigin.y -= (-_lastDragLocation.y + newDragLocation.y);

        [self setFrameOrigin:thisOrigin];
        _lastDragLocation = newDragLocation;
    }
    else
    {
        NSPoint mouse = [self convertPoint:[event locationInWindow] fromView:nil];
        if (_isResizingCropRect) {
            [self resizeCropRectToPoint:mouse];
        } else if (_isDraggingCropRect) {
            [self dragCropRectToPoint:mouse];
        } else {
            [super mouseDragged:event];
        }
    }
}

-(void)mouseUp:(NSEvent *)event
{
    NSPoint mouse = [self convertPoint:[event locationInWindow] fromView:nil];
    if (_isResizingCropRect) {
        [self resizeCropRectEndAtPoint:mouse];
    } else if (_isDraggingCropRect) {
        [self dragCropRectEndAtPoint:mouse];
    } else {
        [super mouseUp:event];
    }

    _isDraggingCropRect = NO;
    _isResizingCropRect = NO;
    _activeResizeHandleIndex = -1;
    [self updateCursorForPoint:mouse];
}

-(BOOL)acceptsFirstResponder { return (YES); }

-(void)drawLayer:(CALayer *)layer inContext:(CGContextRef)context
{
    if (layer == _cropLayer)
    {
        CGRect localCropRect = CGRectOffset(_cropRect,
                                            -CGRectGetMinX(_cropLayer.frame),
                                            -CGRectGetMinY(_cropLayer.frame));
        CGMutablePathRef cropPath = CGPathCreateMutable();
        CGPathAddRect(cropPath, NULL, localCropRect);
        [_cropLayer setPath:cropPath];
        CGPathRelease(cropPath);

        CGRect resizeRects[8];
        SMCropResizeRectsForRect(localCropRect, resizeRects);

        CGContextSetRGBStrokeColor(context, 1, 0, 0, 1);
        CGContextStrokeRectWithWidth(context, resizeRects[0], 1.0);
        CGContextStrokeRectWithWidth(context, resizeRects[1], 1.0);
        CGContextStrokeRectWithWidth(context, resizeRects[2], 1.0);
        CGContextStrokeRectWithWidth(context, resizeRects[3], 1.0);
        CGContextStrokeRectWithWidth(context, resizeRects[4], 1.0);
        CGContextStrokeRectWithWidth(context, resizeRects[5], 1.0);
        CGContextStrokeRectWithWidth(context, resizeRects[6], 1.0);
        CGContextStrokeRectWithWidth(context, resizeRects[7], 1.0);
    }
}

-(void)awakeFromNib
{
    [super awakeFromNib];
    [self registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, NSURLPboardType, nil]];

    self.controlsStyle = AVPlayerViewControlsStyleNone;
    [self ensurePlayerLayer];
    [self ensureDisabledOverlayView];
    [self updateDisabledOverlayFrame];
    [self updateDisabledOverlayVisibility];
    
    _cropLayer = nil;

    _cursEastWest = [[NSCursor alloc]initWithImage:[NSImage imageNamed:@"eastwest.png"] hotSpot:NSMakePoint(8, 0)];
    _cursNorthEastSouthWest = [[NSCursor alloc]initWithImage:[NSImage imageNamed:@"northeastsouthwest.png"] hotSpot:NSMakePoint(8, 0)];
    _cursNorthSouth = [[NSCursor alloc]initWithImage:[NSImage imageNamed:@"northsouth.png"] hotSpot:NSMakePoint(8, 0)];
    _cursNorthWestSouthEast = [[NSCursor alloc]initWithImage:[NSImage imageNamed:@"northwestsoutheast.png"] hotSpot:NSMakePoint(8, 0)];
    
    _shuttleTimer = nil;
    _shuttleRate = 0.0f;
    _activeResizeHandleIndex = -1;
    _isDraggingCropRect = NO;
    _isResizingCropRect = NO;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidPlayToEndTime:) name:SMMovieDidEndNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(zoomToCorner:) name:ZOOM_TO_CORNER object:nil];
}

-(void)dealloc
{
    [self.movie setRate:0];
    [self stopUnsupportedStateTimer];
    [self stopObservingPlayerItem];
    [_timecodeLabel release];
    [_timecodeOverlayView release];
    [_disabledOverlayView release];
    
    [_cursNorthSouth release];
    [_cursEastWest release];
    [_cursNorthWestSouthEast release];
    [_cursNorthEastSouthWest release];

    [self stopShuttle];
    if (_trackingArea != nil)
    {
        [self removeTrackingArea:_trackingArea];
        [_trackingArea release];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SMMovieDidEndNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ZOOM_TO_CORNER object:nil];

    [super dealloc];
}

@end
