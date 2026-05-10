//
//  AppController.h
//  Slate
//
//  Created by Jerry Hale on 3/20/26
//  Copyright (c) 2026 Jerry Hale All rights reserved.

NSString *BASE_URL;

#import <Carbon/Carbon.h>
#import <math.h>

#import "Movie/SMMovie.h"

#import "DictionaryKeys.h"

#import "TimelineState.h"

#import "TimelineView.h"

#import "ChapterViewController.h"
#import "TrackViewController.h"
#import "PackageViewController.h"
#import "PlayerView.h"
#import "Window.h"

#import "AppController+Private.h"

static NSString *kKeyIsOpenFile = @"IsOpenFile";
static NSString *kKeyFilePath = @"FilePath";
static NSString * const SMTimecodeOverlayDefaultsKey = @"SMTimecodeOverlayEnabled";

static NSMenu *SMOperatorFileMenu(void)
{
    NSMenuItem *fileMenuItem = [[NSApp mainMenu] itemWithTitle:@"File"];
    return [fileMenuItem submenu];
}

static NSMenuItem *SMOperatorOpenRecentMenuItem(void)
{
    return [SMOperatorFileMenu() itemWithTitle:@"Open Recent"];
}

static void SMRemoveAllMenuItemsWithTitle(NSMenu *menu, NSString *title)
{
    NSMenuItem *item = nil;
    while ((item = [menu itemWithTitle:title]) != nil) {
        [menu removeItem:item];
    }
}

static NSMenu *SMOperatorOpenRecentMenu(void)
{
    return [SMOperatorOpenRecentMenuItem() submenu];
}

static BOOL SMOperatorRecentURLIsSupported(AppController *controller, NSURL *url)
{
    if (![url isFileURL]) {
        return NO;
    }

    NSString *path = [url path];
    if ([path length] == 0) {
        return NO;
    }

    if ([controller pathLooksLikePackageInput:path]) {
        return YES;
    }

    NSString *extension = [[path pathExtension] lowercaseString];
    return ([extension isEqualToString:@"mov"] || [extension isEqualToString:@"mp4"]);
}

static NSArray *SMOperatorRecentURLs(AppController *controller)
{
    NSMutableArray *operatorURLs = [NSMutableArray array];
    for (NSURL *url in [[NSDocumentController sharedDocumentController] recentDocumentURLs]) {
        if ([url isKindOfClass:[NSURL class]] && SMOperatorRecentURLIsSupported(controller, url)) {
            [operatorURLs addObject:url];
        }
    }

    return operatorURLs;
}

static void SMRefreshOperatorOpenRecentMenu(AppController *controller)
{
    NSMenu *recentMenu = SMOperatorOpenRecentMenu();
    if (recentMenu == nil) {
        return;
    }

    while ([recentMenu numberOfItems] > 0) {
        [recentMenu removeItemAtIndex:0];
    }

    NSArray *recentURLs = SMOperatorRecentURLs(controller);
    if ([recentURLs count] == 0) {
        NSMenuItem *emptyItem = [[[NSMenuItem alloc] initWithTitle:@"No Recent Operator Inputs"
                                                            action:nil
                                                     keyEquivalent:@""] autorelease];
        [emptyItem setEnabled:NO];
        [recentMenu addItem:emptyItem];
    } else {
        for (NSURL *url in recentURLs) {
            NSString *title = [url lastPathComponent];
            if ([title length] == 0) {
                title = [url path];
            }

            NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle:title
                                                           action:@selector(openRecentOperatorInput:)
                                                    keyEquivalent:@""] autorelease];
            [item setTarget:controller];
            [item setRepresentedObject:url];
            [item setToolTip:[url path]];
            [recentMenu addItem:item];
        }
    }

    [recentMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *clearItem = [[[NSMenuItem alloc] initWithTitle:@"Clear Menu"
                                                        action:@selector(clearRecentOperatorInputs:)
                                                 keyEquivalent:@""] autorelease];
    [clearItem setTarget:controller];
    [clearItem setEnabled:([recentURLs count] > 0)];
    [recentMenu addItem:clearItem];
}

static void SMInstallOperatorOpenRecentMenu(AppController *controller)
{
    NSMenuItem *openRecentItem = SMOperatorOpenRecentMenuItem();
    if (openRecentItem == nil) {
        return;
    }

    NSMenu *recentMenu = [[[NSMenu alloc] initWithTitle:@"Open Recent"] autorelease];
    [recentMenu setDelegate:controller];
    [openRecentItem setSubmenu:recentMenu];
    SMRefreshOperatorOpenRecentMenu(controller);
}

static void SMInstallOperatorFileOpenItems(AppController *controller)
{
    NSMenu *fileMenu = SMOperatorFileMenu();
    if (fileMenu == nil) {
        return;
    }

    SMRemoveAllMenuItemsWithTitle(fileMenu, @"Open...");
    SMRemoveAllMenuItemsWithTitle(fileMenu, @"Open Movie...");
    SMRemoveAllMenuItemsWithTitle(fileMenu, @"Open Package...");
    SMRemoveAllMenuItemsWithTitle(fileMenu, @"Open Movie File...");
    SMRemoveAllMenuItemsWithTitle(fileMenu, @"Open Package File...");

    NSMenuItem *openRecentItem = [fileMenu itemWithTitle:@"Open Recent"];
    NSInteger insertIndex = (openRecentItem != nil) ? [fileMenu indexOfItem:openRecentItem] : 0;

    NSMenuItem *openMovieItem = [[[NSMenuItem alloc] initWithTitle:@"Open Movie..."
                                                            action:@selector(doOpen:)
                                                     keyEquivalent:@"o"] autorelease];
    [openMovieItem setTarget:controller];
    [openMovieItem setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
    [fileMenu insertItem:openMovieItem atIndex:insertIndex++];

    NSMenuItem *openPackageItem = [[[NSMenuItem alloc] initWithTitle:@"Open Package..."
                                                              action:@selector(openPackageInput:)
                                                       keyEquivalent:@"P"] autorelease];
    [openPackageItem setTarget:controller];
    [openPackageItem setKeyEquivalentModifierMask:(NSEventModifierFlagCommand | NSEventModifierFlagShift)];
    [fileMenu insertItem:openPackageItem atIndex:insertIndex];
}

AppController *appcontroller(void)
{
    id appDelegate = [NSApp delegate];
    if ([appDelegate isKindOfClass:[AppController class]]) {
        return (AppController *)appDelegate;
    }

    // Harness compatibility: allow delegate proxies that expose the core
    // AppController surface used by pane controllers.
    if ([appDelegate respondsToSelector:@selector(movie)]
        && [appDelegate respondsToSelector:@selector(hasMovie)]
        && [appDelegate respondsToSelector:@selector(movieFrameRate)]
        && [appDelegate respondsToSelector:@selector(codec:)]) {
        return (AppController *)appDelegate;
    }

    return nil;
}

static NSImage *SMCreateTimecodeButtonIconImage(BOOL active, BOOL enabled)
{
    NSSize iconSize = NSMakeSize(18.0, 18.0);
    NSImage *image = [[[NSImage alloc] initWithSize:iconSize] autorelease];
    [image lockFocus];

    NSRect bounds = NSMakeRect(0.0, 0.0, iconSize.width, iconSize.height);
    NSRect panelRect = NSInsetRect(bounds, 0.75, 1.2);
    NSBezierPath *panelPath = [NSBezierPath bezierPathWithRoundedRect:panelRect xRadius:3.0 yRadius:3.0];

    NSColor *panelTopColor = nil;
    NSColor *panelBottomColor = nil;
    NSColor *panelStrokeColor = nil;
    NSColor *glyphColor = nil;

    if (active) {
        panelTopColor = [NSColor colorWithCalibratedRed:0.995 green:0.801 blue:0.327 alpha:1.0];
        panelBottomColor = [NSColor colorWithCalibratedRed:0.872 green:0.548 blue:0.113 alpha:1.0];
        panelStrokeColor = [NSColor colorWithCalibratedRed:0.168 green:0.110 blue:0.047 alpha:0.80];
        glyphColor = [NSColor colorWithCalibratedRed:0.160 green:0.100 blue:0.043 alpha:(enabled ? 0.95 : 0.42)];
    } else {
        panelTopColor = [NSColor colorWithCalibratedWhite:0.44 alpha:(enabled ? 0.99 : 0.92)];
        panelBottomColor = [NSColor colorWithCalibratedWhite:0.29 alpha:(enabled ? 0.99 : 0.92)];
        panelStrokeColor = [NSColor colorWithCalibratedWhite:0.06 alpha:(enabled ? 0.96 : 0.86)];
        glyphColor = [NSColor colorWithCalibratedWhite:1.0 alpha:(enabled ? 0.94 : 0.82)];
    }

    NSGradient *panelGradient = [[[NSGradient alloc] initWithStartingColor:panelTopColor endingColor:panelBottomColor] autorelease];
    [panelGradient drawInBezierPath:panelPath angle:-90.0];
    [panelStrokeColor setStroke];
    [panelPath setLineWidth:1.0];
    [panelPath stroke];

    NSRect glyphRect = NSInsetRect(panelRect, 3.0, 3.6);
    [glyphColor setStroke];
    [glyphColor setFill];

    NSBezierPath *dividerPath = [NSBezierPath bezierPath];
    [dividerPath setLineWidth:1.2];
    CGFloat dividerY = floor(NSMidY(glyphRect)) + 0.5;
    [dividerPath moveToPoint:NSMakePoint(NSMinX(glyphRect), dividerY)];
    [dividerPath lineToPoint:NSMakePoint(NSMaxX(glyphRect), dividerY)];
    [dividerPath stroke];

    NSBezierPath *tickPath = [NSBezierPath bezierPath];
    [tickPath setLineWidth:1.2];
    CGFloat tickInset = 0.8;
    CGFloat topTickStart = NSMaxY(glyphRect) - 0.7;
    CGFloat topTickEnd = dividerY + 0.7;
    CGFloat bottomTickStart = dividerY - 0.7;
    CGFloat bottomTickEnd = NSMinY(glyphRect) + 0.7;

    for (NSInteger tickIndex = 0; tickIndex <= 3; tickIndex++) {
        CGFloat fraction = (CGFloat)tickIndex / 3.0;
        CGFloat tickX = NSMinX(glyphRect) + tickInset + fraction * (NSWidth(glyphRect) - (tickInset * 2.0));
        tickX = floor(tickX) + 0.5;

        [tickPath moveToPoint:NSMakePoint(tickX, topTickStart)];
        [tickPath lineToPoint:NSMakePoint(tickX, topTickEnd)];
        [tickPath moveToPoint:NSMakePoint(tickX, bottomTickStart)];
        [tickPath lineToPoint:NSMakePoint(tickX, bottomTickEnd)];
    }
    [tickPath stroke];

    CGFloat dotX = floor(NSMidX(glyphRect)) + 0.5;
    NSRect topDotRect = NSMakeRect(dotX - 0.85, dividerY + 1.1, 1.7, 1.7);
    NSRect bottomDotRect = NSMakeRect(dotX - 0.85, dividerY - 2.8, 1.7, 1.7);
    [[NSBezierPath bezierPathWithOvalInRect:topDotRect] fill];
    [[NSBezierPath bezierPathWithOvalInRect:bottomDotRect] fill];

    [image unlockFocus];
    return image;
}

static NSImage *SMTimecodeSymbolIconImage(void)
{
    static NSImage *cachedSymbolImage = nil;
    if (cachedSymbolImage != nil) {
        return cachedSymbolImage;
    }

    if (@available(macOS 11.0, *)) {
        NSArray *symbolNames = [NSArray arrayWithObjects:@"timecode", @"video.badge.waveform", @"waveform.badge.clock", nil];
        for (NSString *symbolName in symbolNames) {
            NSImage *symbol = [NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:@"Timecode overlay"];
            if (symbol == nil) {
                continue;
            }

            NSImageSymbolConfiguration *configuration = [NSImageSymbolConfiguration configurationWithPointSize:13.0
                                                                                                         weight:NSFontWeightSemibold];
            NSImage *configured = [symbol imageWithSymbolConfiguration:configuration];
            if (configured == nil) {
                configured = symbol;
            }

            cachedSymbolImage = [configured copy];
            [cachedSymbolImage setTemplate:YES];
            break;
        }
    }

    return cachedSymbolImage;
}

static NSImage *SMTimecodeButtonIconImage(BOOL active, BOOL enabled)
{
    static NSImage *cachedIcons[2][2] = { { nil, nil }, { nil, nil } };
    NSInteger activeIndex = active ? 1 : 0;
    NSInteger enabledIndex = enabled ? 1 : 0;

    NSImage *cachedImage = cachedIcons[activeIndex][enabledIndex];
    if (cachedImage != nil) {
        return cachedImage;
    }

    cachedImage = [SMCreateTimecodeButtonIconImage(active, enabled) copy];
    cachedIcons[activeIndex][enabledIndex] = cachedImage;
    return cachedImage;
}


static NSColor *StoredPlayerBackgroundColor(NSUserDefaults *defaults)
{
    id value = [defaults objectForKey:LAYER_BACK_COLOR];
    if (![value isKindOfClass:[NSDictionary class]]) return [NSColor darkGrayColor];

    NSData *colorData = [(NSDictionary *)value objectForKey:LAYER_BACK_COLOR];
    if (![colorData isKindOfClass:[NSData class]]) return  [NSColor darkGrayColor];

    id color = [NSKeyedUnarchiver unarchiveObjectWithData:colorData];
    if (![color isKindOfClass:[NSColor class]]) return  [NSColor darkGrayColor];

    return (NSColor *)color;
}

static void StorePlayerBackgroundColor(NSUserDefaults *defaults, NSColor *color)
{
    NSColor *storedColor = color ?:  [NSColor darkGrayColor];
    NSMutableDictionary *colorDict = [NSMutableDictionary dictionary];
    NSData *colorData = [NSKeyedArchiver archivedDataWithRootObject:storedColor];
    [colorDict setObject:colorData forKey:LAYER_BACK_COLOR];
    [defaults setObject:colorDict forKey:LAYER_BACK_COLOR];
}

static void LoadPlaybackStateForMovie(SMMovie *movie, void (^completion)(BOOL unsupported))
{
    NSURL *url = [movie URL];
    if (url == nil) {
        completion(YES);
        return;
    }

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    [asset loadValuesAsynchronouslyForKeys:[NSArray arrayWithObjects:@"playable", @"hasProtectedContent", nil]
                         completionHandler:^{
                             NSError *playableError = nil;
                             NSError *protectedError = nil;
                             AVKeyValueStatus playableStatus = [asset statusOfValueForKey:@"playable" error:&playableError];
                             AVKeyValueStatus protectedStatus = [asset statusOfValueForKey:@"hasProtectedContent" error:&protectedError];
                             BOOL unsupported = (playableStatus != AVKeyValueStatusLoaded
                                                 || protectedStatus != AVKeyValueStatusLoaded
                                                 || asset.hasProtectedContent
                                                 || !asset.playable);
                             #pragma unused(playableError, protectedError)
                             dispatch_async(dispatch_get_main_queue(), ^{
                                 completion(unsupported);
                             });
                         }];
}

#pragma mark - AppController 
@implementation AppController

@synthesize movie = _movie;
@synthesize movieFrameRate = _movieFrameRate;
@synthesize movieIsDirty = _movieIsDirty;
@synthesize hasMovie = _hasMovie;
@dynamic movieCurrentTime;

@synthesize playerView = _playerView;

@synthesize timelineState = _timelineState;
@synthesize bottomView = _bottomView;

@synthesize rawCropLeft = _rawCropLeft;
@synthesize rawCropTop = _rawCropTop;
@synthesize rawCropRght = _rawCropRght;
@synthesize rawCropBtm = _rawCropBtm;

@synthesize packageViewController = _packageViewController;
@synthesize chapterViewController = _chapterViewController;
@synthesize trackViewController = _trackViewController;

+(id)infoValueForKey:(NSString *)key { return [[NSBundle mainBundle] objectForInfoDictionaryKey:key]; }

static NSString *TimelinePointerString(id object)
{
    return [NSString stringWithFormat:@"%@:%p", NSStringFromClass([object class]), object];
}

static NSString *SMTransportFormatValue(NSString *format)
{
    if (![format isKindOfClass:[NSString class]]) {
        return @"Unknown format";
    }

    NSString *trimmedFormat = [format stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([trimmedFormat length] == 0) {
        return @"Unknown format";
    }

    return trimmedFormat;
}

static NSString *SMTransportFrameRateValue(double frameRate)
{
    if (!isfinite(frameRate) || frameRate <= 0.0) {
        return @"--.--- fps";
    }

    return [NSString stringWithFormat:@"%.3f fps", frameRate];
}

static NSString *SMTransportSizeValue(CGSize size)
{
    if (!isfinite(size.width) || !isfinite(size.height) || size.width <= 0.0 || size.height <= 0.0) {
        return @"-- x -- px";
    }

    return [NSString stringWithFormat:@"%.0f x %.0f px", size.width, size.height];
}

-(void)clearPlayerViewFirstResponderIfNeeded
{
    id firstResponder = [_window firstResponder];

    if (![firstResponder isKindOfClass:[NSView class]])
        return;

    NSView *firstResponderView = (NSView *)firstResponder;
    if (firstResponderView == _playerView || [firstResponderView isDescendantOf:_playerView])
        [_window makeFirstResponder:nil];
}

- (IBAction)togglePlayPause:(id)sender
{
    SMTimelineLog(@"Timeline playback appTogglePlayPause sender=%@ playerView=%@ movie=%@ hasMovie=%d currentTime=%.3f",
          sender,
          _playerView,
          _movie,
          _hasMovie,
          _currentTime);
    [_playerView togglePlayPause:sender];
}

- (IBAction)toggleTimecodeOverlay:(id)sender
{
    #pragma unused(sender)
    if (![self movieHasTimecodeTrack]) {
        _timecodeOverlayVisible = [self timecodeOverlayPreferenceEnabled];
        [self updateTimecodeOverlayButtonState];
        [_playerView refreshSubtitleOverlay];
        return;
    }

    _timecodeOverlayVisible = !_timecodeOverlayVisible;
    [self setTimecodeOverlayPreferenceEnabled:_timecodeOverlayVisible];
    [self updateTimecodeOverlayButtonState];
    [_playerView refreshSubtitleOverlay];
}

-(BOOL)subtitleVisible
{
    return _subtitleVisible;
}

-(BOOL)closedCaptionVisible
{
    return _closedCaptionVisible;
}

- (BOOL)timecodeOverlayVisible
{
    return _timecodeOverlayVisible;
}

- (BOOL)movieHasTimecodeTrack
{
    return (_movie != nil && [[_movie tracksOfMediaType:SMMediaTypeTimeCode] count] > 0);
}

- (void)updateTimecodeOverlayButtonState
{
    if (_timecodeOverlayButton == nil) {
        return;
    }

    BOOL hasTimecodeTrack = [self movieHasTimecodeTrack];
    BOOL timecodeVisible = (hasTimecodeTrack && _timecodeOverlayVisible);
    [_timecodeOverlayButton setEnabled:hasTimecodeTrack];
    [_timecodeOverlayButton setState:(timecodeVisible ? NSOnState : NSOffState)];

    NSImage *symbolIcon = SMTimecodeSymbolIconImage();
    if (symbolIcon != nil) {
        [_timecodeOverlayButton setImage:symbolIcon];
        [_timecodeOverlayButton setAlternateImage:symbolIcon];
        if ([_timecodeOverlayButton respondsToSelector:@selector(setContentTintColor:)]) {
            NSColor *tint = nil;
            if (!hasTimecodeTrack) {
                tint = [NSColor colorWithCalibratedWhite:0.72 alpha:1.0];
            } else if (timecodeVisible) {
                tint = [NSColor colorWithCalibratedRed:0.94 green:0.63 blue:0.18 alpha:1.0];
            } else {
                tint = [NSColor colorWithCalibratedWhite:0.10 alpha:1.0];
            }
            [_timecodeOverlayButton setContentTintColor:tint];
        }
    } else {
        [_timecodeOverlayButton setImage:SMTimecodeButtonIconImage(timecodeVisible, hasTimecodeTrack)];
        [_timecodeOverlayButton setAlternateImage:SMTimecodeButtonIconImage(YES, hasTimecodeTrack)];
    }

    [_timecodeOverlayButton setToolTip:(hasTimecodeTrack
                                        ? (timecodeVisible ? @"Hide timecode overlay" : @"Show timecode overlay")
                                        : @"No timecode track available in the loaded movie.")];
}

- (BOOL)timecodeOverlayPreferenceEnabled
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:SMTimecodeOverlayDefaultsKey] == nil) {
        [defaults setBool:YES forKey:SMTimecodeOverlayDefaultsKey];
    }

    return [defaults boolForKey:SMTimecodeOverlayDefaultsKey];
}

- (void)setTimecodeOverlayPreferenceEnabled:(BOOL)enabled
{
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:SMTimecodeOverlayDefaultsKey];
}

-(NSSize)naturalSize { return ([[_movie attributeForKey:SMMovieNaturalSizeAttribute] sizeValue]); }
-(NSString *)codec:(SMMedia *)trackMedia
{
    NSString    *codec = nil;
    OSType cType = [trackMedia sampleFormatAtIndex:0];

    switch (cType)
    {
//        case kH264CodecType:
//            codec = MP42VideoFormatH264;
//        break;
//        case kMPEG4VisualCodecType:
//            codec = MP42VideoFormatMPEG4Visual;
//        break;
//        case kSorensonCodecType:
//            codec = MP42VideoFormatSorenson;
//        break;
//        case kSorenson3CodecType:
//            codec = MP42VideoFormatSorenson3;
//        break;
        case 'ap4h':
            codec = MP42VideoFormatProRes_4444;
            break;
        case 'apch':
            codec = MP42VideoFormatProRes_422HQ;
            break;
        case 'apcn':
            codec = MP42VideoFormatProRes_422SD;
            break;
        case 'apcs':
            codec = MP42VideoFormatProRes_422LT;
            break;
        case 'apco':
            codec = MP42VideoFormatProRes_422PR;
            break;
    }

    return  (codec);
}

-(NSTimeInterval)movieCurrentTime
{
    return (_currentTime);
}

-(void)setMovieCurrentTime:(NSTimeInterval)currentTime
{
                                    if (_currentTime != currentTime)
                                        {
                                        //  sets the movie’s current time setting to time.
                            SMTimelineLog(@"Timeline setMovieCurrentTime old=%.3f new=%.3f updatingFromPlayback=%d scrubbing=%d", _currentTime, currentTime, _updatingTimelineFromPlayback, [self isTimelineScrubbing]);
                            _currentTime = currentTime;
                            [_timelineState setCurrentTime:_currentTime];
                            if (!_updatingTimelineFromPlayback) {
                                [self queueTimelineSeekForCurrentTime];
                            }
            if (![self isTimelineScrubbing]) {
                [_playerView refreshSubtitleOverlay];
            }
            [self updateScrubberTimeLabels];
    }
}

-(void)movieLoadStateDidChange:(NSNotification *)notification
{
    #pragma unused(notification)
    SMTimelineLog(@"Timeline movieLoadStateDidChange begin movie=%@ playerView=%@ sliderFrame=%@ sliderHidden=%d windowVisible=%d duration(before)=%.3f currentTime(before)=%.3f",
          TimelinePointerString(_movie),
          TimelinePointerString(_playerView),
          NSStringFromRect([_timelineView frame]),
          [_timelineView isHidden],
          [_window isVisible],
          [_timelineState duration],
          [_timelineState currentTime]);
    if (SMMovieLoadStateComplete == [[_movie attributeForKey:SMMovieLoadStateAttribute] longValue])
    {
            [_movie setMovieAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:SMMovieEditableAttribute]];

        if ([_playerView movie] != nil)
        {
            [self clearPlayerViewFirstResponderIfNeeded];
            SMTimelineLog(@"Timeline movieLoadStateDidChange clearing preexisting playerView=%@ appMovie=%@", _playerView, _movie);
            [_playerView setMovie:nil];
            [self setMovieIsDirty:NO];
        }

            _movieFrameRate = 0.0;
            NSArray     *videoTracks = [_movie tracksOfMediaType: SMMediaTypeVideo];
            NSString    *formatSummary = nil;

            if (videoTracks.count)
            {
                SMTrack *videoTrack = (SMTrack *)[videoTracks objectAtIndex:0];
                SMMedia *trackMedia = [videoTrack media];

                formatSummary = [videoTrack attributeForKey:SMTrackFormatSummaryAttribute];
                if ([formatSummary length] == 0)
                    formatSummary = [self codec:trackMedia];

                if ([trackMedia hasCharacteristic:SMMediaCharacteristicHasVideoFrameRate])
                {
                    _movieFrameRate = [(NSNumber *)[trackMedia attributeForKey:SMMediaSampleCountAttribute] doubleValue];
                }
            }
            
        [_trackViewController refreshTrackData];
        [self syncSidecarVisibilityState];
        [_trackViewController.tracks selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
        [self refreshValidationViewAdapters];

        // set the movie into the view
        SMTimelineLog(@"Timeline movieLoadStateDidChange attaching playerView appMovie=%@ playerView=%@", _movie, _playerView);
        [_playerView setMovie:_movie];
        SMTimelineLog(@"Timeline movieLoadStateDidChange attached playerView appMovie=%@ playerView=%@", _movie, _playerView);
        if (_packageContext != nil && _chapterViewController != nil) {
            [self refreshPackageAdaptersFromCurrentContext];
            [self refreshValidationViewAdapters];
        }
            [_timelineState resetForDuration:[self effectivePlaybackDuration]];
            [_timelineState setFrameRate:_movieFrameRate];
            [self syncTransportViewsFromTimelineState];
            
            _currentTime = 0.0;
            [self layoutScrubberTimeLabels];

            if (_timelineTimer == nil)
                _timelineTimer = [[NSTimer scheduledTimerWithTimeInterval:(1.0 / 30.0) target:self selector:@selector(updateTimelinePosition:) userInfo:nil repeats:YES] retain];

        [self updateTimecodeOverlayButtonState];
        [_window setTitle:[_movie attributeForKey:SMMovieDisplayNameAttribute]];

            // Reset window state for the newly loaded movie.
            //  NSSize  naturalSize = [[[appcontroller() movie] attributeForKey:SMMovieNaturalSizeAttribute] sizeValue];
            [_format setStringValue:SMTransportFormatValue(formatSummary)];
            [_frameRate setStringValue:SMTransportFrameRateValue(_movieFrameRate)];
            [_currentSize setStringValue:SMTransportSizeValue(NSRectToCGRect(_playerView.movieBounds).size)];
            
            // Volume is pushed manually to avoid observer issues during window teardown.
            [_volume setFloatValue:[_movie volume]];
            
        [self autoloadReferenceSidecarsIfNeeded];
        SMMovie *loadedMovie = [_movie retain];
        LoadPlaybackStateForMovie(loadedMovie, ^(BOOL unsupported) {
            if (_movie != loadedMovie) {
                [loadedMovie release];
                return;
            }

                if (unsupported) {
                    [self clearPlayerViewFirstResponderIfNeeded];
                    SMTimelineLog(@"Timeline movieLoadStateDidChange unsupported clearing playerView appMovie=%@ playerView=%@", _movie, _playerView);
                    [_playerView setMovie:nil];
                    SMTimelineLog(@"Timeline movieLoadStateDidChange unsupported cleared playerView appMovie=%@ playerView=%@", _movie, _playerView);
                    [_playerView showMessage:@"The movie format is not supported for playback."];
        _currentTime = 0.0;
                    _movieFrameRate = 0.0;
                    [_timelineState resetForDuration:0.0];
                    [self syncTransportViewsFromTimelineState];
                    [self updateTimecodeOverlayButtonState];
                    [_format setStringValue:@"Unsupported for playback"];
                    [_frameRate setStringValue:SMTransportFrameRateValue(0.0)];
                    [_currentSize setStringValue:SMTransportSizeValue(CGSizeZero)];
                    [self setHasMovie:NO];
                    [self refreshBottomPaneStatusGuidance];
                }

            [loadedMovie release];
        });
    }
    SMTimelineLog(@"Timeline movieLoadStateDidChange end movie=%@ playerView=%@ sliderFrame=%@ sliderHidden=%d duration(after)=%.3f currentTime(after)=%.3f",
          TimelinePointerString(_movie),
          TimelinePointerString(_playerView),
          NSStringFromRect([_timelineView frame]),
          [_timelineView isHidden],
          [_timelineState duration],
          [_timelineState currentTime]);
}

- (IBAction)addReferenceTrack:(id)sender
{
    #pragma unused(sender)
    [self ensureTrackViewControllerLoaded];
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];

    [openPanel setCanChooseFiles:YES];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setAllowsOtherFileTypes:NO];
    [openPanel setAllowedFileTypes:[NSArray arrayWithObjects:@"scc", @"itt", @"srt", @"ttml", @"dfxp", @"mov", @"wav", @"aif", @"aiff", @"m4a", @"mp3", @"caf", nil]];
    [openPanel setAllowsMultipleSelection:YES];
    [openPanel beginSheetModalForWindow:_window completionHandler:^(NSInteger result)
    {
        if (result != NSOKButton)
            return;

        [_trackViewController createReferenceTrack:openPanel.URLs];
    }];
}

- (IBAction)deleteTrack:(id)sender
{
    [self ensureTrackViewControllerLoaded];
    [_trackViewController deleteSelectedTrack:sender];
    [self refreshValidationViewAdapters];
}

-(IBAction)setBackgroundColor:(id)sender
{
    NSColorWell *cw = (NSColorWell *)sender;

    [_playerView setPlayerLayerBackgroundColor:[cw color]];
    if (_chapterViewController != nil) {
        [_chapterViewController syncQuadrantBackgroundToPlayerView];
    }

    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    StorePlayerBackgroundColor(prefs, [cw color]);
}

-(void)updateCurrentSize
{
    [_currentSize setStringValue:SMTransportSizeValue(NSRectToCGRect(_playerView.movieBounds).size)];
}

//  don't delete, used to edit crop rect values
#if 0
-(NSString *)undoActionNameForCell:(NSTextField *)field
{
    //  returns the string we want to be displayed
    //  in the "Undo"/"Redo" menu item (under Edit->)
    if (field == _rawCropBtm)
        return (@"Crop Bottom Value");
    else if (field == _rawCropLeft)
        return (@"Crop Left Value");
    else if (field == _rawCropTop)
        return (@"Crop Top Value");
    else if (field == _rawCropRght)
        return (@"Crop Right Value");

    return (@"Crop Value");
}

-(void)applyCellUndo:(NSArray *)undoInfo
{
    //    apply the specified undo, and register another undo,
    //    which will have the effect of resetting us to the
    //    current state (ie. redo the undo)
    NSCell      *affectedCell = [undoInfo objectAtIndex:0];
    NSString     *newString = [undoInfo objectAtIndex:1];
    
//    [[self undoManager] registerUndoWithTarget:self selector:@selector(applyCellUndo:)
//                        object:[NSArray arrayWithObjects:affectedCell, [affectedCell stringValue], nil]];

    [affectedCell setStringValue:newString];
}


-(void)controlTextDidChange:(NSNotification *)notif
{
    //  take a snapshot of the cell being edited so
    //  we'll know if it has actually changed when
    //  controlTextDidEndEditing: is received.
    NSText  *fieldEditor = [[notif userInfo] objectForKey: @"NSFieldEditor"];
    
    _initEditString = [[fieldEditor string] copy];
    _valueHasChanged = YES;
}

-(void)controlTextDidEndEditing:(NSNotification *)notif
{
    NSText        *fieldEditor = [[notif userInfo] objectForKey: @"NSFieldEditor"];
    NSString    *endEditString = [fieldEditor string];
    NSTextField    *field = (NSTextField *)[notif object];

    if ([field doubleValue] < 0)
        return;
    else if (!_playerView.cropLayer)
        return;
    else if (_valueHasChanged == NO)
        return;
    
    _valueHasChanged = NO;

    //  just in case, do some sanity checks.
    if (!_initEditString)
        _initEditString = @"";

    if (!endEditString)
        endEditString = @"";
    
    if (_initEditString != endEditString && ![endEditString isEqualToString:_initEditString])
    {
//        NSCell  *editedCell = [[notif object] selectedCell];
//        NSArray *undoInfo = [NSArray arrayWithObjects: editedCell, _initEditString, nil];
        
//        [[self undoManager] registerUndoWithTarget:self selector:@selector(applyCellUndo:) object:undoInfo];
//        [[self undoManager] setActionName:[self undoActionNameForCell:field]];
    }

    if ([field stringValue] == nil || [[field stringValue]isEqualToString:@""])
        return;

    NSSize  naturalSize = [[[appcontroller() movie] attributeForKey:SMMovieNaturalSizeAttribute] sizeValue];
    
    CGRect    bounds = NSRectToCGRect(_playerView.movieBounds);
    SMCropMargins margins = SMCropMarginsMake([_rawCropLeft floatValue],
                                                   [_rawCropTop floatValue],
                                                   [_rawCropRght floatValue],
                                                   [_rawCropBtm floatValue]);
    CGRect sourceCropRect = SMCropRectFromMargins(margins, NSSizeToCGSize(naturalSize));
    CGRect cropRect = CGRectApplyAffineTransform(sourceCropRect,
                                       CGAffineTransformMakeScale(bounds.size.width / naturalSize.width,
                                                                  bounds.size.height / naturalSize.height));
    //  translate to Movie 0, 0
    cropRect.origin.x += bounds.origin.x;
    cropRect.origin.y += bounds.origin.y;

        [_playerView setCropRect:cropRect];
        [_playerView.cropLayer setNeedsDisplay];
    [self showChapterCropRectStatusWithTop:margins.top
                                      left:margins.left
                                    bottom:margins.bottom
                                     right:margins.right
                                   context:nil
                                    suffix:nil
                                   persist:NO];

    _initEditString = nil;
}
#endif

#pragma mark - Overrides
-(void)awakeFromNib
{    
    SMTimelineLog(@"Timeline startup awakeFromNib begin slider=%@ playerView=%@ window=%@ sliderFrame=%@ sliderSuperview=%@",
          TimelinePointerString(_timelineView),
          TimelinePointerString(_playerView),
          TimelinePointerString(_window),
          NSStringFromRect([_timelineView frame]),
          TimelinePointerString([_timelineView superview]));
   //    _valueHasChanged = NO;
    _updatingTimelineFromPlayback = NO;
    _hasPendingScrubSeek = NO;
    _pendingScrubTime = 0.0;
    _playbackRateBeforeScrub = 0.0f;
    _movieFrameRate = 0.0;
    _subtitleVisible = NO;
    _closedCaptionVisible = NO;
    _timecodeOverlayVisible = [self timecodeOverlayPreferenceEnabled];
    _timelineState = [[TimelineState alloc] init];
    _timelineBaseY = NSMinY([_timelineView frame]);
    [self updateTimecodeOverlayButtonState];

    [_timelineState resetForDuration:0.0];
    [self createTimelineViewIfNeeded];
    [self syncTransportViewsFromTimelineState];
    [self createScrubberTimeLabelsIfNeeded];
    [self layoutScrubberTimeLabels];
    [_format setStringValue:@"No movie loaded"];
    [_frameRate setStringValue:SMTransportFrameRateValue(0.0)];
    [_currentSize setStringValue:SMTransportSizeValue(CGSizeZero)];

    [self clearPlayerViewFirstResponderIfNeeded];
    [_playerView setMovie:nil];
    [_playerView setVideoGravity:AVLayerVideoGravityResizeAspect];

        NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
        NSColor *c = StoredPlayerBackgroundColor(prefs);
        StorePlayerBackgroundColor(prefs, c);

    [_colorWell setColor:c];
    [_playerView setPlayerLayerBackgroundColor:c];
    
    [_topView setWantsLayer:YES];
    _topView.layer.backgroundColor = [[NSColor quinaryLabelColor] CGColor];
      [_bottomView setWantsLayer:YES];
    _bottomView.layer.backgroundColor = [[NSColor quinaryLabelColor] CGColor];
    
    _currentTag = -1;
    _modeSwitchContextByTag = [[NSMutableDictionary alloc] init];
    [self closePackageContextResettingUIState];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshCropValues:) name:REFRESH_CROP_VALUES object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(movieLoadStateDidChange:) name:@"SMMovieLoadStateDidChangeNotification" object:nil];

    [self createTrackMenuIfNeeded];
    [self createValidationMenuIfNeeded];
    SMInstallOperatorFileOpenItems(self);
    SMInstallOperatorOpenRecentMenu(self);
    [self installSlateAppleEventHandlers];
    
    [self selectBottomPane:nil];
    [self applyModeWorkspaceResponsiveLayout];
    SMTimelineLog(@"Timeline startup awakeFromNib end slider=%@ playerView=%@ windowVisible=%d sliderFrame=%@ sliderHidden=%d btmViewFrame=%@",
          TimelinePointerString(_timelineView),
          TimelinePointerString(_playerView),
          [_window isVisible],
          NSStringFromRect([_timelineView frame]),
          [_timelineView isHidden],
          NSStringFromRect([_bottomView frame]));
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:REFRESH_CROP_VALUES object:nil];
    
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowWillEnterFullScreenNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidExitFullScreenNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"SMMovieLoadStateDidChangeNotification" object:nil];
    [self removeSlateAppleEventHandlers];
    [_scrubSeekTimer invalidate];

    [_packageContext release];
    [_packagePath release];
    if (_movie) [_movie release];
    [_timelineState release];

    [_modeSwitchContextByTag release];
    [_inspectorRailHostCoordinator release];
 
			[super dealloc];
}

-(void)alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    #pragma unused(alert)
    NSDictionary    *dict = (NSDictionary *)contextInfo;
    
    BOOL    isOpenFile = [(NSNumber *)[dict objectForKey:kKeyIsOpenFile]boolValue];

    [[alert window] orderOut:nil];

    if (NSAlertDefaultReturn == returnCode)
    {
        if (![self saveCurrentMovieRebuildingTracks:NO]) {
            [dict release];
            return;
        }
    }
    
    if (isOpenFile)
        [self doOpen:nil];
    else
    {
        NSString *path = (NSString *)[dict objectForKey:kKeyFilePath];
        if ([self pathLooksLikePackageInput:path]) {
            [self openPackageContextFromURL:[NSURL fileURLWithPath:path] presentErrors:YES];
        } else {
            [self openMovie:path];
        }
    }
    
    [dict release];
}

-(IBAction)doOpen:(id)sender
{
    #pragma unused(sender)
	if (_movie && _movieIsDirty)
    {
		NSAlert *alert = [NSAlert alertWithMessageText:@"Do you want to Save the Movie?"
                                         defaultButton:@"Save"
                                       alternateButton:@"Don't Save"
                                           otherButton:nil
                             informativeTextWithFormat:@"You have modified the Movie File, update the Movie to save these changes."];

		[alert beginSheetModalForWindow:_window
                          modalDelegate:self
                         didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:)
                            contextInfo:[[NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:YES], kKeyIsOpenFile, nil]retain]];
	}
    else
    {
        NSOpenPanel *openPanel = [NSOpenPanel openPanel];

        [openPanel setAllowedFileTypes:[NSArray arrayWithObjects:@"mp4", @"mov", @"MP4", @"MOV", nil]];
        NSInteger result = [openPanel runModal];
        if (result != NSOKButton) {
            return;
        }

        NSURL *url = [[openPanel URLs] firstObject];
        if (url == nil) {
            NSAlert *alert = [[[NSAlert alloc] init] autorelease];
            [alert addButtonWithTitle:@"OK"];
            [alert setMessageText:@"Open failed"];
            [alert setInformativeText:@"No movie file was selected."];
            [alert runModal];
            return;
        }

        [self openMovie:[url path]];
    }
}

-(void)openMovie:(NSString *)path
{
    SMTimelineLog(@"Timeline openMovie begin path=%@ hasMovie=%d movie=%@ playerView=%@ slider=%@ sliderFrame=%@ sliderHidden=%d windowVisible=%d",
          path,
          _hasMovie,
          TimelinePointerString(_movie),
          TimelinePointerString(_playerView),
          TimelinePointerString(_timelineView),
          NSStringFromRect([_timelineView frame]),
          [_timelineView isHidden],
          [_window isVisible]);

    BOOL retainedPackageContextForOpenedMovie = [self shouldRetainPackageContextWhenOpeningMoviePath:path];
    if (retainedPackageContextForOpenedMovie) {
        [self showStatusMessage:@"Package retained: opened movie matches declared primary video path."
                        persist:NO];
    } else {
        [self closePackageContextResettingUIState];
        [_chapterViewController deleteAllChapters:nil];
    }
    [_trackViewController removeMovieReference];

    if (_movie)
    {
        [_playerView stopMovie];
        SMTimelineLog(@"Timeline openMovie clearing existing appMovie=%@ playerView=%@", _movie, _playerView);
        [_movie release];
        _movie = nil;
    }

    [self updateTimecodeOverlayButtonState];

    if (_timelineTimer)
    {
        [_timelineTimer invalidate];
        [_timelineTimer release];
        _timelineTimer = nil;
    }

    _currentTime = 0.0;
    _movieFrameRate = 0.0;
    [_timelineState resetForDuration:0.0];
    SMTimelineLog(@"Timeline openMovie afterReset currentTime=%.3f duration=%.3f selectionStart=%.3f selectionEnd=%.3f",
          _currentTime,
          [_timelineState duration],
          [_timelineState selectionStart],
          [_timelineState selectionEnd]);
    [self syncTransportViewsFromTimelineState];
    [_format setStringValue:@"No movie loaded"];
    [_frameRate setStringValue:SMTransportFrameRateValue(0.0)];
    [_currentSize setStringValue:SMTransportSizeValue(CGSizeZero)];

    [self clearPlayerViewFirstResponderIfNeeded];
    SMTimelineLog(@"Timeline openMovie clearing playerView movie before load playerView=%@", _playerView);
    [_playerView setMovie:nil];
    [_playerView clearMessage];
    [self refreshValidationViewAdapters];

    NSError *error = nil;

    _autoloadedSidecarMovie = nil;
    _movie = [SMMovie movieWithFile:path error:&error];
    SMTimelineLog(@"Timeline openMovie created appMovie=%@ path=%@", _movie, path);

    if (_movie != nil && error == nil)
    {
        [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[NSURL fileURLWithPath:path]];

        if (!_hasMovie) //  this should only be false once, when the app is first opened
            [_trackViewController.tracks registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, nil]];

        [self  setHasMovie:YES];
        [self refreshBottomPaneStatusGuidance];
        [_movie retain];
        SMTimelineLog(@"Timeline openMovie postingLoadState path=%@ movie=%@ playerView=%@ sliderFrame=%@ sliderHidden=%d",
              path,
              TimelinePointerString(_movie),
              TimelinePointerString(_playerView),
              NSStringFromRect([_timelineView frame]),
              [_timelineView isHidden]);
        [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:@"SMMovieLoadStateDidChangeNotification" object:nil]];
    }
    else
    {
        [_format setStringValue:@"No movie loaded"];
        [_frameRate setStringValue:SMTransportFrameRateValue(0.0)];
        [_currentSize setStringValue:SMTransportSizeValue(CGSizeZero)];
        if (error == nil) {
            error = [NSError errorWithDomain:NSCocoaErrorDomain
                                        code:NSFileReadUnknownError
                                    userInfo:[NSDictionary dictionaryWithObject:@"The movie could not be opened."
                                                                         forKey:NSLocalizedDescriptionKey]];
        }
        NSAlert *alert = [NSAlert alertWithError:error];

        [alert runModal];
    }
}

#pragma mark - Application Delegate
-(NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    #pragma unused(sender)
	if ([_window isVisible])
		[_window performClose:nil];
    
    return (NSTerminateNow);
}

-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    #pragma unused(sender)
    return (YES);
}

-(BOOL)application:(NSApplication *)sender openFile:(NSString *)filename
{
    #pragma unused (sender)
    SMTimelineLog(@"Timeline startup openFile begin filename=%@ windowVisible=%d slider=%@ sliderFrame=%@ sliderHidden=%d playerView=%@ movie=%@ timelineState=%@",
          filename,
          [_window isVisible],
          TimelinePointerString(_timelineView),
          NSStringFromRect([_timelineView frame]),
          [_timelineView isHidden],
          TimelinePointerString(_playerView),
          TimelinePointerString(_movie),
          TimelinePointerString(_timelineState));
    // load the file
	if (_movie && _movieIsDirty)
    {
		NSAlert *alert = [NSAlert alertWithMessageText:@"Do you want to Save the File?"
                                         defaultButton:@"Save"
                                       alternateButton:@"Don't Save"
                                           otherButton:nil
                             informativeTextWithFormat:@"You have modified the current File, click the Save button to save these changes."];

		[alert beginSheetModalForWindow:_window
                          modalDelegate:self
                         didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:)
                            contextInfo:[[NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:NO], kKeyIsOpenFile,
                                        filename, kKeyFilePath,
                                        nil]retain]];
    }
    else
    {
        if ([self pathLooksLikePackageInput:filename]) {
            [self openPackageContextFromURL:[NSURL fileURLWithPath:filename] presentErrors:YES];
        } else {
            [self openMovie:filename];
        }
    }

    SMTimelineLog(@"Timeline startup openFile end filename=%@ windowVisible=%d sliderFrame=%@ sliderHidden=%d movie=%@ playerView=%@",
          filename,
          [_window isVisible],
          NSStringFromRect([_timelineView frame]),
          [_timelineView isHidden],
          TimelinePointerString(_movie),
          TimelinePointerString(_playerView));

    return (YES);
}

-(void)applicationDidFinishLaunching:(NSNotification *)notif
{
    #pragma unused (notif)
    #if 0
        BASE_URL = @"http://localhost/jsonserver/";
    #else
        BASE_URL = [AppController infoValueForKey:KEY_BASE_URL];
    #endif
    SMTimelineLog(@"Timeline startup didFinishLaunching windowVisible=%d slider=%@ sliderFrame=%@ sliderHidden=%d playerView=%@ movie=%@",
          [_window isVisible],
          TimelinePointerString(_timelineView),
          NSStringFromRect([_timelineView frame]),
          [_timelineView isHidden],
          TimelinePointerString(_playerView),
          TimelinePointerString(_movie));
}

- (IBAction)openRecentOperatorInput:(id)sender
{
    NSURL *url = nil;
    if ([sender respondsToSelector:@selector(representedObject)]) {
        id representedObject = [sender representedObject];
        if ([representedObject isKindOfClass:[NSURL class]]) {
            url = (NSURL *)representedObject;
        }
    }

    NSString *path = [url path];
    if ([path length] == 0) {
        return;
    }

    [self application:NSApp openFile:path];
}

- (IBAction)clearRecentOperatorInputs:(id)sender
{
    [[NSDocumentController sharedDocumentController] clearRecentDocuments:sender];
    SMRefreshOperatorOpenRecentMenu(self);
}

- (void)menuNeedsUpdate:(NSMenu *)menu
{
    if (menu == SMOperatorOpenRecentMenu()) {
        SMRefreshOperatorOpenRecentMenu(self);
    }
}

#pragma mark - NSWindowDelegate
#pragma mark Saves File
-(BOOL)windowShouldClose:(id)sender
{
    #pragma unused(sender)
    if (_movie && _movieIsDirty)
    {   
        NSAlert *alert = [NSAlert alertWithMessageText:@"Do you want to save the File before you Quit?"
                                         defaultButton:@"Save"
                                       alternateButton:@"Don't Save"
                                           otherButton:nil
                             informativeTextWithFormat:@""];
        
        if ([alert runModal] == NSAlertDefaultReturn)
        {
            if (![self saveCurrentMovieRebuildingTracks:NO]) {
                return (NO);
            }
        }
    }
    
    return (YES);
}

-(void)windowWillClose:(NSNotification *)notif
{
    #pragma unused (notif)
    [self clearPlayerViewFirstResponderIfNeeded];

    if (_timelineTimer)
    {
        [_timelineTimer invalidate];
        [_timelineTimer release];
    }
}

-(void)windowDidResize:(NSNotification *)notification
{
    #pragma unused (notification)
    SMTimelineLog(@"Timeline startup windowDidResize windowFrame=%@ sliderFrame(before)=%@ sliderHidden=%d",
          NSStringFromRect([_window frame]),
          NSStringFromRect([_timelineView frame]),
          [_timelineView isHidden]);
    [self layoutScrubberTimeLabels];
    [self applyModeWorkspaceResponsiveLayout];
    [self updateCurrentSize];
    [self refreshCropValues:nil];
    SMTimelineLog(@"Timeline startup windowDidResize end sliderFrame(after)=%@ duration=%.3f currentTime=%.3f",
          NSStringFromRect([_timelineView frame]),
          [_timelineState duration],
          [_timelineState currentTime]);
}

#pragma mark - FULL SCREEN STUFF
+ (NSArray *)restorableStateKeyPaths { return [[NSResponder restorableStateKeyPaths] arrayByAddingObject:@"_frameForNonFullScreenMode"]; }
-(NSSize)window:(NSWindow *)window willUseFullScreenContentSize:(NSSize)proposedSize
{
    #pragma unused (window)
return (NSMakeSize(proposedSize.width, proposedSize.height)); }

-(NSApplicationPresentationOptions)window:(NSWindow *)window willUseFullScreenPresentationOptions:(NSApplicationPresentationOptions)proposedOptions
{
    #pragma unused (window, proposedOptions)
    // customize our appearance when entering full screen:
    // we don't want the dock to appear but we want the menubar to hide/show automatically
    return (NSApplicationPresentationFullScreen |       // support full screen for this window (required)
            NSApplicationPresentationHideDock |         // completely hide the dock
            NSApplicationPresentationAutoHideMenuBar);  // yes we want the menu bar to show/hide
}

- (void)refreshFullscreenLayoutForWindow:(NSWindow *)window
{
    #pragma unused(window)
    [self updateCurrentSize];
    [_playerView setNeedsLayout:YES];
    [_playerView layoutSubtreeIfNeeded];
    [_playerView refreshSubtitleOverlay];
    [self syncTransportViewsFromTimelineState];
}

- (void)windowWillEnterFullScreen:(NSNotification *)notification
{
    NSWindow *window = [notification object];
    _frameForNonFullScreenMode = [window frame];
    [_window invalidateRestorableState];
    [self refreshFullscreenLayoutForWindow:window];
}

- (void)windowDidEnterFullScreen:(NSNotification *)notification
{
    [self refreshFullscreenLayoutForWindow:[notification object]];
}

- (void)windowWillExitFullScreen:(NSNotification *)notification
{
    [self refreshFullscreenLayoutForWindow:[notification object]];
}

- (void)windowDidExitFullScreen:(NSNotification *)notification
{
    [self refreshFullscreenLayoutForWindow:[notification object]];
}

-(BOOL)validateMenuItem:(NSMenuItem *)item
{
    if ([item action] == @selector(doSave:))
    {
        return (_movie != nil && _movieIsDirty);
    }

    if ([item action] == @selector(saveDocumentAs:))
    {
        return (_movie != nil);
    }

    if ([item action] == @selector(toggleClosedCaption:))
    {
        BOOL hasClosedCaptionTracks = [self movieHasClosedCaptionSidecarTracks];
        [item setState:(hasClosedCaptionTracks && _closedCaptionVisible) ? NSOnState : NSOffState];
        return (_movie != nil && hasClosedCaptionTracks);
    }

    if ([item action] == @selector(toggleSubtitles:))
    {
        BOOL hasSubtitleTracks = [self movieHasSubtitleSidecarTracks];
        [item setState:(hasSubtitleTracks && _subtitleVisible) ? NSOnState : NSOffState];
        return (_movie != nil && hasSubtitleTracks);
    }

    if ([item action] == @selector(toggleSidecarAutoload:))
    {
        [item setState:[self sidecarAutoloadEnabled] ? NSOnState : NSOffState];
        return YES;
    }

    if ([item action] == @selector(deleteTrack:))
    {
        return (_movie != nil && [_trackViewController canDeleteSelectedTrack]);
    }

    if ([item action] == @selector(showValidationReadiness:))
    {
        return (_movie != nil || _packageContext != nil);
    }

    if ([item action] == @selector(showPackageSummary:))
    {
        return (_packageContext != nil);
    }

    if ([item action] == @selector(openRecentOperatorInput:))
    {
        id representedObject = [item representedObject];
        return ([representedObject isKindOfClass:[NSURL class]]
                && SMOperatorRecentURLIsSupported(self, representedObject));
    }

    if ([item action] == @selector(clearRecentOperatorInputs:))
    {
        return ([[[NSDocumentController sharedDocumentController] recentDocumentURLs] count] > 0);
    }

    return YES;
}

@end

#if 0

NSString *filePath = @"/Users/local-administrator/Desktop/subtitle_files/test.scc";

if (filePath && [[NSFileManager defaultManager] fileExistsAtPath:filePath])
{
    NSError     *err = nil;
    
    SMMovie     *mainMovie = [[SMMovie movieWithFile:filePath error:&err] retain];
    
    [mainMovie setMovieAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:SMMovieEditableAttribute]];

    if (mainMovie == nil) return;
    
    for (SMTrack *track in [mainMovie tracks])
    {
        NSString    *mediaType = [track attributeForKey:SMTrackMediaTypeAttribute];
        
        Track       qtcTrack = [track quickTimeTrack];
        Media       media = GetTrackMedia(qtcTrack);
        
        if ([mediaType isEqualToString:SMMediaTypeVideo])   //  video
        {
            NSLog(@"SMMediaTypeVideo");
        }
        else if ([mediaType isEqualToString:SMMediaTypeText])   //  video
        {
            
            NSLog(@"SMMediaTypeText");
        }
        else if ([mediaType isEqualToString:SMMediaTypeSubtitle])   //  video
        {
            
            NSLog(@"SMMediaTypeSubtitle");
        }
        else if ([mediaType isEqualToString:SMMediaTypeClosedCaption])   //  video
        {
            
            NSLog(@"SMMediaTypeClosedCaption");
            
            SMTimeRange videoRange = SMMakeTimeRange(SMZeroTime, [mainMovie duration]);
            
            [_movie insertSegmentOfTrack:track timeRange:videoRange atTime:SMZeroTime];
            [_movie updateMovieFile];
            
            [mainMovie release];
        }
    }
}
#endif

//-(void)sizeWindowToMov
//{   
//    //  key monitor frame size
//	NSRect  e = [[NSScreen mainScreen] frame];
//
//    int     dest_height = (int)e.size.height - 46;
//	int     dest_width = (int)e.size.width;
//
//	float	source_width = _naturalSize.width;
//	float	source_height = _naturalSize.height;
//
//	float	scale = dest_height / source_height;
//
//	if (dest_width / source_width < dest_height / source_height)
//		scale = dest_width / source_width;
//
//    NSRect  windowSize = _window.frame;
//
//    windowSize.size.width = (int)(source_width * scale);
//    windowSize.size.height = (int)(source_height * scale);
//
//    NSWindow  *w = (NSWindow *)_window;
//    NSRect    wndFrame = [w frameRectForContentRect:windowSize];
//
//	[w setFrame:wndFrame display:NO animate:NO];
////	[w setAspectRatio:_naturalSize];
//}
