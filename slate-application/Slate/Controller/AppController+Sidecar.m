//
//  AppController+Sidecars.m
//  Slate
//

#import "AppController+Sidecar.h"
#import "AppController+Private.h"

#import "PlayerView.h"
#import "Subtitle/SMSubtitleSupport.h"
#import "TrackViewController.h"

static NSString * const AutoloadSidecarsDefaultsKey = @"AutoloadSidecarsEnabled";

@interface AppController (SMTimecodeOverlayState)
- (void)updateTimecodeOverlayButtonState;
@end

static void SMInstallSidecarItemsInViewMenuIfNeeded(AppController *controller)
{
    NSMenuItem *viewMenuItem = [[NSApp mainMenu] itemWithTitle:@"View"];
    NSMenu *viewMenu = [viewMenuItem submenu];
    NSMenuItem *packageItem = [viewMenu itemWithTitle:@"Package"];
    if (viewMenu == nil || packageItem == nil || [viewMenu itemWithTitle:@"Show Subtitles"] != nil) {
        return;
    }

    NSInteger insertIndex = [viewMenu indexOfItem:packageItem] + 1;
    [viewMenu insertItem:[NSMenuItem separatorItem] atIndex:insertIndex++];

    NSMenuItem *showSubtitlesItem = [[[NSMenuItem alloc] initWithTitle:@"Show Subtitles"
                                                                action:@selector(toggleSubtitles:)
                                                         keyEquivalent:@""] autorelease];
    [showSubtitlesItem setTarget:controller];
    [viewMenu insertItem:showSubtitlesItem atIndex:insertIndex++];

    NSMenuItem *showClosedCaptionsItem = [[[NSMenuItem alloc] initWithTitle:@"Show Closed Captions"
                                                                     action:@selector(toggleClosedCaption:)
                                                              keyEquivalent:@""] autorelease];
    [showClosedCaptionsItem setTarget:controller];
    [viewMenu insertItem:showClosedCaptionsItem atIndex:insertIndex++];

    [viewMenu insertItem:[NSMenuItem separatorItem] atIndex:insertIndex++];

    NSMenuItem *autoloadItem = [[[NSMenuItem alloc] initWithTitle:@"Autoload Sidecars"
                                                           action:@selector(toggleSidecarAutoload:)
                                                    keyEquivalent:@""] autorelease];
    [autoloadItem setTarget:controller];
    [autoloadItem setState:[controller sidecarAutoloadEnabled] ? NSOnState : NSOffState];
    [viewMenu insertItem:autoloadItem atIndex:insertIndex];
}

@implementation AppController (Sidecars)

- (IBAction)toggleSubtitles:(id)sender
{
    #pragma unused(sender)
    if (![self movieHasSubtitleSidecarTracks]) {
        _subtitleVisible = NO;
        [_playerView refreshSubtitleOverlay];
        return;
    }

    BOOL shouldEnable = ![self hasEnabledSidecarTracksOfMediaType:nil];
    [self setEnabled:shouldEnable forSidecarTracksOfMediaType:nil];
    [self syncSidecarVisibilityState];
    [[_trackViewController tracks] reloadData];
}

- (IBAction)toggleClosedCaption:(id)sender
{
    if (![self movieHasClosedCaptionSidecarTracks]) {
        _closedCaptionVisible = NO;
        [_playerView refreshSubtitleOverlay];
        return;
    }

    BOOL shouldEnable = ![self hasEnabledSidecarTracksOfMediaType:SMMediaTypeClosedCaption];
    [self setEnabled:shouldEnable forSidecarTracksOfMediaType:SMMediaTypeClosedCaption];
    [self syncSidecarVisibilityState];
    [[_trackViewController tracks] reloadData];
}

- (BOOL)movieHasSidecarTracksOfMediaType:(NSString *)mediaType
{
    SMMovie *movie = [appcontroller() movie];
    if (movie == nil) {
        return NO;
    }

    for (SMTrack *track in [movie subtitleSidecarTracks]) {
        NSString *trackMediaType = [track attributeForKey:SMTrackMediaTypeAttribute];
        if (mediaType == nil) {
            if (![trackMediaType isEqualToString:SMMediaTypeClosedCaption]) {
                return YES;
            }
        } else if ([trackMediaType isEqualToString:mediaType]) {
            return YES;
        }
    }

    return NO;
}

- (BOOL)track:(SMTrack *)track matchesSidecarMediaType:(NSString *)mediaType
{
    NSString *trackMediaType = [track attributeForKey:SMTrackMediaTypeAttribute];
    if (mediaType == nil) {
        return ![trackMediaType isEqualToString:SMMediaTypeClosedCaption];
    }

    return [trackMediaType isEqualToString:mediaType];
}

- (BOOL)hasEnabledSidecarTracksOfMediaType:(NSString *)mediaType
{
    SMMovie *movie = [appcontroller() movie];
    if (movie == nil) {
        return NO;
    }

    for (SMTrack *track in [movie subtitleSidecarTracks]) {
        if ([self track:track matchesSidecarMediaType:mediaType] && [track isEnabled]) {
            return YES;
        }
    }

    return NO;
}

- (void)setEnabled:(BOOL)enabled forSidecarTracksOfMediaType:(NSString *)mediaType
{
    SMMovie *movie = [appcontroller() movie];
    if (movie == nil) {
        return;
    }

    for (SMTrack *track in [movie subtitleSidecarTracks]) {
        if ([self track:track matchesSidecarMediaType:mediaType]) {
            [track setEnabled:enabled];
        }
    }
}

- (BOOL)movieHasSubtitleSidecarTracks
{
    return [self movieHasSidecarTracksOfMediaType:nil];
}

- (BOOL)movieHasClosedCaptionSidecarTracks
{
    return [self movieHasSidecarTracksOfMediaType:SMMediaTypeClosedCaption];
}

- (void)syncSidecarVisibilityState
{
    BOOL hasSubtitleTracks = [self movieHasSubtitleSidecarTracks];
    BOOL hasClosedCaptionTracks = [self movieHasClosedCaptionSidecarTracks];

    _subtitleVisible = hasSubtitleTracks && [self hasEnabledSidecarTracksOfMediaType:nil];
    _closedCaptionVisible = hasClosedCaptionTracks && [self hasEnabledSidecarTracksOfMediaType:SMMediaTypeClosedCaption];

    [self updateTimecodeOverlayButtonState];
    [_playerView refreshSubtitleOverlay];
}

- (void)createTrackMenuIfNeeded
{
    NSMenu *mainMenu = [NSApp mainMenu];
    if (mainMenu == nil) {
        return;
    }

    NSMenuItem *legacySubtitlesItem = [mainMenu itemWithTitle:@"Subtitles"];
    if (legacySubtitlesItem != nil) {
        [mainMenu removeItem:legacySubtitlesItem];
    }

    NSMenuItem *trackMenuItem = [mainMenu itemWithTitle:@"Track"];
    NSMenu *trackMenu = [trackMenuItem submenu];
    if (trackMenuItem == nil) {
        trackMenuItem = [[[NSMenuItem alloc] initWithTitle:@"Track" action:nil keyEquivalent:@""] autorelease];
        trackMenu = [[[NSMenu alloc] initWithTitle:@"Track"] autorelease];
        [trackMenuItem setSubmenu:trackMenu];

        NSInteger insertIndex = [mainMenu numberOfItems];
        NSMenuItem *windowItem = [mainMenu itemWithTitle:@"Window"];
        if (windowItem != nil) {
            insertIndex = [mainMenu indexOfItem:windowItem];
        }

        [mainMenu insertItem:trackMenuItem atIndex:insertIndex];
    }

    if ([trackMenu itemWithTitle:@"Add Reference Track..."] == nil) {
        NSMenuItem *addReferenceTrackItem = [[[NSMenuItem alloc] initWithTitle:@"Add Reference Track..."
                                                                        action:@selector(addReferenceTrack:)
                                                                 keyEquivalent:@""] autorelease];
        [addReferenceTrackItem setTarget:self];
        [trackMenu addItem:addReferenceTrackItem];
    }

    NSMenuItem *deleteTrackItem = [trackMenu itemWithTitle:@"Delete Reference Track"];
    if (deleteTrackItem == nil) {
        deleteTrackItem = [[[NSMenuItem alloc] initWithTitle:@"Delete Reference Track"
                                                      action:@selector(deleteTrack:)
                                               keyEquivalent:@"d"] autorelease];
        [deleteTrackItem setTarget:self];
        [deleteTrackItem setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
        [trackMenu addItem:deleteTrackItem];
    }

    SMInstallSidecarItemsInViewMenuIfNeeded(self);
}

- (void)createValidationMenuIfNeeded
{
    NSMenu *mainMenu = [NSApp mainMenu];
    if (mainMenu == nil || [mainMenu itemWithTitle:@"Validation"] != nil) {
        return;
    }

    NSMenuItem *validationMenuItem = [[[NSMenuItem alloc] initWithTitle:@"Validation" action:nil keyEquivalent:@""] autorelease];
    NSMenu *validationMenu = [[[NSMenu alloc] initWithTitle:@"Validation"] autorelease];
    [validationMenuItem setSubmenu:validationMenu];

    NSMenuItem *showPackageSummaryItem = [[[NSMenuItem alloc] initWithTitle:@"Show Package Summary"
                                                                     action:@selector(showPackageSummary:)
                                                              keyEquivalent:@"p"] autorelease];
    [showPackageSummaryItem setTarget:self];
    [showPackageSummaryItem setKeyEquivalentModifierMask:(NSEventModifierFlagCommand | NSEventModifierFlagOption)];
    [validationMenu addItem:showPackageSummaryItem];

    NSMenuItem *showReadinessItem = [[[NSMenuItem alloc] initWithTitle:@"Show Readiness Report"
                                                                action:@selector(showValidationReadiness:)
                                                         keyEquivalent:@"r"] autorelease];
    [showReadinessItem setTarget:self];
    [showReadinessItem setKeyEquivalentModifierMask:(NSEventModifierFlagCommand | NSEventModifierFlagOption)];
    [validationMenu addItem:showReadinessItem];

    NSInteger insertIndex = [mainMenu numberOfItems];
    NSMenuItem *windowItem = [mainMenu itemWithTitle:@"Window"];
    if (windowItem != nil) {
        insertIndex = [mainMenu indexOfItem:windowItem];
    }

    [mainMenu insertItem:validationMenuItem atIndex:insertIndex];
}

- (BOOL)sidecarAutoloadEnabled
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:AutoloadSidecarsDefaultsKey] == nil) {
        [defaults setBool:YES forKey:AutoloadSidecarsDefaultsKey];
    }

    return [defaults boolForKey:AutoloadSidecarsDefaultsKey];
}

- (IBAction)toggleSidecarAutoload:(id)sender
{
    BOOL enabled = ![self sidecarAutoloadEnabled];
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:AutoloadSidecarsDefaultsKey];

    if ([sender isKindOfClass:[NSMenuItem class]]) {
        [(NSMenuItem *)sender setState:enabled ? NSOnState : NSOffState];
    }
}

- (void)autoloadReferenceSidecarsIfNeeded
{
    if (_movie == nil || _autoloadedSidecarMovie == _movie) {
        return;
    }

    if (![self sidecarAutoloadEnabled]) {
        _autoloadedSidecarMovie = _movie;
        return;
    }

    NSURL *movieURL = [_movie URL];
    NSString *moviePath = [movieURL path];
    if (moviePath.length == 0) {
        _autoloadedSidecarMovie = _movie;
        return;
    }

    NSString *basePath = [moviePath stringByDeletingPathExtension];
    NSArray *supportedExtensions = [NSArray arrayWithObjects:@"itt", @"srt", @"scc", @"ttml", @"dfxp", nil];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSMutableArray *sidecarURLs = [NSMutableArray array];

    for (NSString *extension in supportedExtensions) {
        NSString *sidecarPath = [basePath stringByAppendingPathExtension:extension];
        if ([fileManager fileExistsAtPath:sidecarPath]) {
            NSURL *sidecarURL = [NSURL fileURLWithPath:sidecarPath];
            if (![_movie hasSubtitleSidecarTrackForSourceURL:sidecarURL]) {
                [sidecarURLs addObject:sidecarURL];
            }
        }
    }

    _autoloadedSidecarMovie = _movie;

    if (sidecarURLs.count > 0) {
        [self ensureTrackViewControllerLoaded];
        [_trackViewController createReferenceTrack:sidecarURLs];
    }
}

@end
