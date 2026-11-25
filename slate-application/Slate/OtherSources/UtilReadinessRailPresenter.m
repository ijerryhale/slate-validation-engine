//
//  UtilReadinessRailPresenter.m
//  Slate
//
//  Copyright (c) 2026 Jerry Hale. All rights reserved.
//

#import "UtilReadinessRailPresenter.h"
#import "UtilInspectorRailContract.h"
#import "Runtime/SlateReviewSnapshotContract.h"
#import "Runtime/SlateRuntimeBridge.h"

static NSString * const SlateReadinessRailTitle = @"Readiness";

@implementation UtilReadinessRailPresenter

@synthesize sectionLabel = _sectionLabel;
@synthesize scrollView = _scrollView;
@synthesize pinButton = _pinButton;
@synthesize pinned = _pinned;

- (id)initWithFindingsToolTipTitle:(NSString *)findingsToolTipTitle
                   pinDefaultsKey:(NSString *)pinDefaultsKey
                            owner:(id<SMInspectorRailModeAdapter, NSTextViewDelegate>)owner
{
    self = [super init];
    if (self != nil) {
        _findingsToolTipTitle = [(findingsToolTipTitle ?: @"Readiness findings") copy];
        _pinDefaultsKey = [pinDefaultsKey copy];
        _pinned = [[NSUserDefaults standardUserDefaults] boolForKey:_pinDefaultsKey];
        _owner = owner;
    }
    return self;
}

- (void)dealloc
{
    [_sectionLabel release];
    [_statusLabel release];
    [_scrollView release];
    [_textView release];
    [_pinButton release];
    [_findingsToolTipTitle release];
    [_pinDefaultsKey release];
    [_projectionRequest release];
    [super dealloc];
}

- (NSTextField *)newSectionLabelWithString:(NSString *)stringValue
{
    NSTextField *label = SlateInspectorRailCreateLabel((stringValue ?: @""),
                                                       [NSFont boldSystemFontOfSize:11.5],
                                                       SlateInspectorRailSectionHeaderColor(),
                                                       NSTextAlignmentLeft,
                                                       NO);
    SlateInspectorRailApplySectionHeaderStyle(label);
    return [label retain];
}

- (void)ensureViewsInSuperview:(NSView *)superview
{
    if (superview == nil) {
        return;
    }

    if (_sectionLabel == nil) {
        _sectionLabel = [self newSectionLabelWithString:SlateReadinessRailTitle];
    }
    if ([_sectionLabel superview] == nil) {
        [superview addSubview:_sectionLabel];
    }

    if (_statusLabel == nil) {
        _statusLabel = [self newSectionLabelWithString:@""];
        SlateInspectorRailApplyWarningStatusStyle(_statusLabel, NO, NO);
    }
    if ([_statusLabel superview] == nil) {
        [superview addSubview:_statusLabel];
    }

    if (_textView == nil) {
        _textView = [[NSTextView alloc] initWithFrame:NSZeroRect];
        SlateInspectorRailApplyWarningTextViewStyle(_textView);
        SlateInspectorRailApplyReadinessLinkStyle(_textView);
        [_textView setDelegate:_owner];
    }

    if (_scrollView == nil) {
        _scrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
        SlateInspectorRailApplyWarningScrollViewStyle(_scrollView);
        [_scrollView setDocumentView:_textView];
    }
    if ([_scrollView superview] == nil) {
        [superview addSubview:_scrollView];
    }

    if (_pinButton == nil) {
        _pinButton = [SlateInspectorRailCreatePinButton(self, @selector(pinButtonChanged:)) retain];
        [_pinButton setState:_pinned ? NSControlStateValueOn : NSControlStateValueOff];
    }
    if (_pinButton != nil && [_pinButton superview] == nil) {
        [superview addSubview:_pinButton];
    }
}

- (void)pinButtonChanged:(NSButton *)sender
{
    BOOL pinned = ([sender state] == NSControlStateValueOn);
    if (_pinned == pinned) {
        return;
    }
    _pinned = pinned;
    [[NSUserDefaults standardUserDefaults] setBool:pinned forKey:_pinDefaultsKey];
    [_owner applyWorkspaceLayoutForWidth:NSWidth([[_pinButton superview] bounds])];
}

- (void)restoreSubviewOrderWithOverlays:(NSArray<NSView *> *)overlays
{
    NSView *superview = [_sectionLabel superview];
    if (superview == nil) {
        return;
    }

    NSMutableArray *orderedViews = [NSMutableArray arrayWithObjects:_sectionLabel, _statusLabel, _scrollView, nil];
    [orderedViews addObjectsFromArray:overlays];
    [orderedViews addObject:_pinButton];

    NSArray *subviews = [superview subviews];
    NSUInteger previousIndex = NSNotFound;
    BOOL needsReorder = NO;
    for (NSView *view in orderedViews) {
        NSUInteger index = [subviews indexOfObjectIdenticalTo:view];
        if (index == NSNotFound) {
            return;
        }
        if (previousIndex != NSNotFound && index <= previousIndex) {
            needsReorder = YES;
        }
        previousIndex = index;
    }
    if (needsReorder || previousIndex != [subviews count] - 1) {
        for (NSView *view in orderedViews) {
            [superview addSubview:view positioned:NSWindowAbove relativeTo:nil];
        }
    }
}

- (void)renderReviewPaneSnapshot:(NSDictionary *)snapshot
{
    if (![snapshot isKindOfClass:[NSDictionary class]]) {
        snapshot = @{SlateReviewPaneSnapshotKeyEmptyStatus: @"No findings", SlateReviewPaneSnapshotKeyEmptyMessage: @""};
    }
    NSArray *findings = [snapshot objectForKey:SlateReviewPaneSnapshotKeyFindings];
    NSArray *canonicalFindings = SlateInspectorRailCanonicalFindingsArray(findings);
    NSString *emptyStatus = [snapshot objectForKey:SlateReviewPaneSnapshotKeyEmptyStatus];
    NSString *emptyMessage = [snapshot objectForKey:SlateReviewPaneSnapshotKeyEmptyMessage];
    NSDictionary *jumpLinks = [snapshot objectForKey:SlateReviewPaneSnapshotKeyJumpLinksByFindingIdentity];
    if (![jumpLinks isKindOfClass:[NSDictionary class]]) {
        jumpLinks = nil;
    }

    NSMutableArray *blockers = nil;
    NSMutableArray *warnings = nil;
    SlateInspectorRailSplitFindingsBySeverity(canonicalFindings, &blockers, &warnings);
    SlateInspectorRailApplyWarningStatusStyle(_statusLabel, [blockers count] > 0, [warnings count] > 0);
    [_statusLabel setStringValue:SlateInspectorRailReadinessStatusText(canonicalFindings, emptyStatus)];

    NSAttributedString *readinessText = SlateInspectorRailReadinessAttributedText(canonicalFindings, emptyMessage, jumpLinks);
    SlateInspectorRailSetReadinessText(_textView, readinessText);

    NSString *toolTip = SlateInspectorRailFindingsSummaryToolTip(canonicalFindings, _findingsToolTipTitle);
    [_statusLabel setToolTip:toolTip];
    [_sectionLabel setToolTip:toolTip];
    SlateInspectorRailApplyCopyHintToView(_scrollView, toolTip);
    SlateInspectorRailApplyCopyHintToView(_textView, toolTip);
}

- (void)projectReadinessRail
{
    if (_projectionRunning) {
        return;
    }
    _projectionRunning = YES;
    NSDictionary *request = _projectionRequest;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            NSDictionary *snapshot = [SlateRuntimeBridge reviewPaneSnapshotWithPaneKey:request[@"pane"]
                                                                                 title:SlateReadinessRailTitle
                                                                              findings:request[@"findings"]
                                                                           emptyStatus:request[@"emptyStatus"]
                                                                          emptyMessage:request[@"emptyMessage"]
                                                            jumpLinksByFindingIdentity:request[@"jumpLinks"]];
            dispatch_async(dispatch_get_main_queue(), ^{
                _projectionRunning = NO;
                if ([_projectionRequest isEqualToDictionary:request]) {
                    [self renderReviewPaneSnapshot:snapshot];
                } else {
                    [self projectReadinessRail];
                }
            });
        }
    });
}

- (void)presentFindings:(NSArray *)findings
                paneKey:(NSString *)paneKey
            emptyStatus:(NSString *)emptyStatus
           emptyMessage:(NSString *)emptyMessage
     jumpLinkForFinding:(NSString *(^)(NSDictionary *finding))jumpLinkForFinding
{
    NSMutableDictionary *jumpLinks = [NSMutableDictionary dictionary];
    for (NSDictionary *finding in findings) {
        if (![finding isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSString *link = jumpLinkForFinding(finding);
        if (SlateInspectorRailStringHasContent(link)) {
            [jumpLinks setObject:link forKey:SlateInspectorRailFindingIdentity(finding)];
        }
    }

    NSDictionary *request = @{
        @"pane": paneKey,
        @"findings": findings ?: @[],
        @"emptyStatus": emptyStatus ?: @"",
        @"emptyMessage": emptyMessage ?: @"",
        @"jumpLinks": jumpLinks,
    };
    if ([_projectionRequest isEqualToDictionary:request]) {
        return;
    }
    [_projectionRequest release];
    _projectionRequest = [request retain];
    [self renderReviewPaneSnapshot:@{SlateReviewPaneSnapshotKeyEmptyStatus: @"Checking readiness…"}];
    [self projectReadinessRail];
}

- (void)hideRail
{
    [_sectionLabel setHidden:YES];
    [_statusLabel setHidden:YES];
    [_scrollView setHidden:YES];
    [_pinButton setHidden:YES];
}

- (void)layoutRailAtX:(CGFloat)x topY:(CGFloat)topY bottomY:(CGFloat)bottomY
{
    CGFloat width = SlateInspectorRailFixedWidth();
    CGFloat titleHeight = SlateInspectorRailSectionHeaderHeight();
    CGFloat rowHeight = SlateInspectorRailDisclosureRowHeight();
    CGFloat titleY = topY - titleHeight;
    CGFloat statusY = titleY - SlateInspectorRailSectionHeaderYOffset() - rowHeight - 2.0;
    CGFloat scrollHeight = SlateInspectorRailReadinessScrollHeight(statusY, bottomY);
    CGFloat pinWidth = SlateInspectorRailPinControlWidth();

    [_sectionLabel setFrame:NSMakeRect(x, titleY, width, titleHeight)];
    [_statusLabel setFrame:NSMakeRect(x, statusY, width, rowHeight)];
    [_scrollView setFrame:NSMakeRect(x, bottomY, width, scrollHeight)];
    [_pinButton setFrame:NSMakeRect(x + width - pinWidth, titleY, pinWidth, rowHeight)];

    [_sectionLabel setHidden:NO];
    [_statusLabel setHidden:NO];
    [_scrollView setHidden:NO];
    [_pinButton setHidden:NO];
}

- (BOOL)ownsTextView:(NSTextView *)textView
{
    return (textView != nil && textView == _textView);
}

@end
