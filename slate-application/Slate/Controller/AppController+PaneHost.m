//
//  AppController+PaneHost.m
//  Slate
//

#import "AppController+PaneHost.h"

#import "AppController+Sidecar.h"
#import "AppController+Status.h"
#import "ChapterViewController.h"
#import "DictionaryKeys.h"
#import "PackageViewController.h"
#import "QuadrantView.h"
#import "Runtime/SlatePackageContextContract.h"
#import "Runtime/SlateRuntimeBridge.h"
#import "UtilInspectorRailCoord.h"
#import "TrackViewController.h"

static NSInteger const SMBottomPaneDefaultTag = cntrl_trak;

static BOOL SMIsBottomPaneModeTag(NSInteger tag)
{
    return (tag == cntrl_trak || tag == cntrl_pdata || tag == cntrl_chap);
}

static NSInteger StoredBottomPaneTag(NSUserDefaults *defaults)
{
    if ([defaults objectForKey:BOTTOM_PANE] == nil) {
        return SMBottomPaneDefaultTag;
    }

    NSInteger tag = [defaults integerForKey:BOTTOM_PANE];
    return SMIsBottomPaneModeTag(tag) ? tag : SMBottomPaneDefaultTag;
}

static void StoreBottomPaneTag(NSUserDefaults *defaults, NSInteger tag)
{
    [defaults setInteger:tag forKey:BOTTOM_PANE];
}

@interface AppController (PaneHostPrivate)
- (BOOL)responder:(NSResponder *)responder belongsToViewHierarchy:(NSView *)rootView;
- (void)prepareBottomPaneModeView:(NSView *)modeView;
- (void)attachBottomPaneModeControllerViewIfNeeded:(NSViewController *)controller;
- (void)registerInspectorRailAdapterController:(id)controller forTag:(NSInteger)tag;
- (void)activateInspectorRailAdapterForTag:(NSInteger)tag;
- (NSView *)bottomPaneModeViewForTag:(NSInteger)tag;
- (void)setBottomPaneVisibilityForTag:(NSInteger)tag;
- (NSDictionary *)modeSwitchContextSnapshotForTag:(NSInteger)tag;
- (NSView *)preferredModeFirstResponderViewForTag:(NSInteger)tag;
- (void)captureModeSwitchContextForTag:(NSInteger)tag;
- (void)restoreModeSwitchContextForTag:(NSInteger)tag;
@end

@implementation AppController (PaneHost)

- (void)prepareBottomPaneModeView:(NSView *)modeView
{
    if (modeView == nil || _bottomView == nil) {
        return;
    }

    [modeView setTranslatesAutoresizingMaskIntoConstraints:YES];
    [modeView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    NSRect modeFrame = [_bottomView bounds];
    [modeView setFrame:modeFrame];
    [modeView setHidden:YES];
}

- (void)attachBottomPaneModeControllerViewIfNeeded:(NSViewController *)controller
{
    if (controller == nil || _bottomView == nil) {
        return;
    }

    NSView *modeView = [controller view];
    [self prepareBottomPaneModeView:modeView];
    if ([modeView superview] != _bottomView) {
        [_bottomView addSubview:modeView];
    }
}

- (void)registerInspectorRailAdapterController:(id)controller forTag:(NSInteger)tag
{
    if (_inspectorRailHostCoordinator == nil) {
        _inspectorRailHostCoordinator = [[UtilInspectorRailCoord alloc] init];
    }
    [_inspectorRailHostCoordinator registerAdapter:(id<SMInspectorRailModeAdapter>)controller forTag:tag];
}

- (void)activateInspectorRailAdapterForTag:(NSInteger)tag
{
    if (_inspectorRailHostCoordinator == nil) {
        _inspectorRailHostCoordinator = [[UtilInspectorRailCoord alloc] init];
    }
    [_inspectorRailHostCoordinator setActiveTag:tag];
}

- (TrackViewController *)ensureTrackViewControllerLoaded
{
    if (_trackViewController == nil) {
        _trackViewController = [[TrackViewController alloc] init];
        [self attachBottomPaneModeControllerViewIfNeeded:_trackViewController];
        [self registerInspectorRailAdapterController:_trackViewController forTag:cntrl_trak];
        [_trackViewController assetTypeFromPackageContext:_packageContext];

        if (_movie != nil) {
            [_trackViewController refreshTrackData];
            [self syncSidecarVisibilityState];
            [_trackViewController.tracks registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, nil]];
            if ([[_trackViewController tracks] numberOfRows] > 0) {
                [_trackViewController.tracks selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
            }
        }
    }

    return _trackViewController;
}

- (PackageViewController *)ensurePackageViewControllerLoaded
{
    if (_packageViewController == nil) {
        _packageViewController = [[PackageViewController alloc] init];
        [self attachBottomPaneModeControllerViewIfNeeded:_packageViewController];
        [self registerInspectorRailAdapterController:_packageViewController forTag:cntrl_pdata];
        if (_packageContext != nil) {
            [_packageViewController presentPackageSnapshot:[_packageContext objectForKey:SlatePackageContextKeyPackageSnapshot]];
            [_packageViewController.view setNeedsDisplay:YES];
        }
    }

    return _packageViewController;
}

- (ChapterViewController *)ensureChapterViewControllerLoaded
{
    if (_chapterViewController == nil) {
        _chapterViewController = [[ChapterViewController alloc] init];
        [self attachBottomPaneModeControllerViewIfNeeded:_chapterViewController];
        [self registerInspectorRailAdapterController:_chapterViewController forTag:cntrl_chap];
        [_chapterViewController setPlayerView:_playerView];
        NSDictionary *chapterSnapshot = [SlateRuntimeBridge chapterSnapshotForPackagePath:_packagePath
                                                                                 movie:_movie
                                                                            hasPackage:(_packageContext != nil)];
        [_chapterViewController applyChapterSnapshot:chapterSnapshot];
    }

    return _chapterViewController;
}

- (id)ensureBottomPaneControllerForTag:(NSInteger)tag
{
    switch (tag)
    {
        case cntrl_trak:
            return [self ensureTrackViewControllerLoaded];
        case cntrl_pdata:
            return [self ensurePackageViewControllerLoaded];
        case cntrl_chap:
            return [self ensureChapterViewControllerLoaded];
        default:
            break;
    }

    return nil;
}

- (IBAction)selectBottomPane:(id)sender
{
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    NSInteger tag;

    if (sender == nil)
    {
        tag = StoredBottomPaneTag(prefs);
        StoreBottomPaneTag(prefs, tag);

        [_views setState:NSOnState atRow:0 column:tag];
    }
    else
    {
        tag = [sender tag];

        if ([sender isKindOfClass:[NSMatrix class]]) {
            tag = [sender selectedColumn];
        } else {
            [_views setState:NSOnState atRow:0 column:tag];
        }

        StoreBottomPaneTag(prefs, tag);
    }

    if (!SMIsBottomPaneModeTag(tag)) {
        tag = SMBottomPaneDefaultTag;
        StoreBottomPaneTag(prefs, tag);
        if (_views != nil) {
            [_views setState:NSOnState atRow:0 column:tag];
        }
    }

    NSInteger previousTag = _currentTag;
    BOOL didSwitchMode = (previousTag != tag);
    if (didSwitchMode) {
        [self captureModeSwitchContextForTag:previousTag];
        [self setBottomPaneVisibilityForTag:tag];
        _currentTag = tag;
    }

    [self activateInspectorRailAdapterForTag:tag];
    [self applyModeWorkspaceResponsiveLayout];
    if (didSwitchMode) {
        [self restoreModeSwitchContextForTag:tag];
    }
    [self refreshBottomPaneStatusGuidance];
}

- (CGFloat)currentWorkspaceResponsiveWidth
{
    NSView *workspaceView = _bottomView;
    if (workspaceView == nil) {
        return NSWidth([_window contentLayoutRect]);
    }

    return NSWidth([workspaceView bounds]);
}

- (NSView *)bottomPaneModeViewForTag:(NSInteger)tag
{
    switch (tag)
    {
        case cntrl_trak:
            return [_trackViewController view];
        case cntrl_pdata:
            return [_packageViewController view];
        case cntrl_chap:
            return [_chapterViewController view];
        default:
            break;
    }

    return nil;
}

- (void)setBottomPaneVisibilityForTag:(NSInteger)tag
{
    [self ensureBottomPaneControllerForTag:tag];

    if (_trackViewController != nil) {
        [[_trackViewController view] setHidden:(tag != cntrl_trak)];
    }
    if (_packageViewController != nil) {
        [[_packageViewController view] setHidden:(tag != cntrl_pdata)];
    }
    if (_chapterViewController != nil) {
        [[_chapterViewController view] setHidden:(tag != cntrl_chap)];
    }
}

- (NSDictionary *)modeSwitchContextSnapshotForTag:(NSInteger)tag
{
    switch (tag)
    {
        case cntrl_trak:
            return [_trackViewController modeSwitchContextSnapshot];
        case cntrl_pdata:
            return [_packageViewController modeSwitchContextSnapshot];
        case cntrl_chap:
            return [_chapterViewController modeSwitchContextSnapshot];
        default:
            break;
    }

    return nil;
}

- (NSView *)preferredModeFirstResponderViewForTag:(NSInteger)tag
{
    switch (tag)
    {
        case cntrl_trak:
            return [_trackViewController preferredModeFirstResponderView];
        case cntrl_pdata:
            return [_packageViewController preferredModeFirstResponderView];
        case cntrl_chap:
            return [_chapterViewController preferredModeFirstResponderView];
        default:
            break;
    }

    return nil;
}

- (BOOL)responder:(NSResponder *)responder belongsToViewHierarchy:(NSView *)rootView
{
    if (responder == nil || rootView == nil) {
        return NO;
    }

    if ([responder isKindOfClass:[NSView class]]) {
        return [(NSView *)responder isDescendantOf:rootView];
    }

    if ([responder isKindOfClass:[NSText class]]) {
        id delegate = [(NSText *)responder delegate];
        if ([delegate isKindOfClass:[NSView class]]) {
            return [(NSView *)delegate isDescendantOf:rootView];
        }
    }

    return NO;
}

- (void)captureModeSwitchContextForTag:(NSInteger)tag
{
    if (!SMIsBottomPaneModeTag(tag) || _modeSwitchContextByTag == nil) {
        return;
    }

    NSDictionary *snapshot = [self modeSwitchContextSnapshotForTag:tag];
    NSMutableDictionary *storedSnapshot = [snapshot isKindOfClass:[NSDictionary class]]
        ? [NSMutableDictionary dictionaryWithDictionary:snapshot]
        : [NSMutableDictionary dictionary];

    NSResponder *firstResponder = [_window firstResponder];
    NSView *modeView = [self bottomPaneModeViewForTag:tag];
    BOOL modeOwnsFirstResponder = [self responder:firstResponder belongsToViewHierarchy:modeView];
    [storedSnapshot setObject:[NSNumber numberWithBool:modeOwnsFirstResponder]
                       forKey:@"restoreFirstResponder"];

    [_modeSwitchContextByTag setObject:storedSnapshot
                                forKey:[NSNumber numberWithInteger:tag]];
}

- (void)restoreModeSwitchContextForTag:(NSInteger)tag
{
    if (!SMIsBottomPaneModeTag(tag) || _modeSwitchContextByTag == nil) {
        return;
    }

    NSDictionary *snapshot = [_modeSwitchContextByTag objectForKey:[NSNumber numberWithInteger:tag]];
    if ([snapshot isKindOfClass:[NSDictionary class]]) {
        switch (tag)
        {
            case cntrl_trak:
                [_trackViewController restoreModeSwitchContextSnapshot:snapshot];
                break;
            case cntrl_pdata:
                [_packageViewController restoreModeSwitchContextSnapshot:snapshot];
                break;
            case cntrl_chap:
                [_chapterViewController restoreModeSwitchContextSnapshot:snapshot];
                break;
            default:
                break;
        }
    }

    BOOL shouldRestoreResponder = [[snapshot objectForKey:@"restoreFirstResponder"] boolValue];
    if (!shouldRestoreResponder) {
        return;
    }

    NSView *preferredResponder = [self preferredModeFirstResponderViewForTag:tag];
    if (preferredResponder != nil && [preferredResponder window] == _window) {
        [_window makeFirstResponder:preferredResponder];
    }
}

- (void)applyModeWorkspaceResponsiveLayout
{
    CGFloat workspaceWidth = [self currentWorkspaceResponsiveWidth];
    if (_inspectorRailHostCoordinator == nil) {
        _inspectorRailHostCoordinator = [[UtilInspectorRailCoord alloc] init];
    }
    [_inspectorRailHostCoordinator applyWorkspaceWidth:workspaceWidth];
}

@end
