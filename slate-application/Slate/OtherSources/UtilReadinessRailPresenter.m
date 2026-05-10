//
//  UtilReadinessRailPresenter.m
//  Slate
//
//  Copyright (c) 2026 Jerry Hale. All rights reserved.
//

#import "UtilReadinessRailPresenter.h"
#import "UtilInspectorRailContract.h"
#import "Runtime/SlateReviewSnapshotContract.h"

@implementation UtilReadinessRailPresenter

@synthesize sectionLabel = _sectionLabel;
@synthesize statusLabel = _statusLabel;
@synthesize scrollView = _scrollView;
@synthesize textView = _textView;
@synthesize pinButton = _pinButton;

- (id)initWithSectionTitle:(NSString *)sectionTitle
      findingsToolTipTitle:(NSString *)findingsToolTipTitle
                 pinTarget:(id)pinTarget
                 pinAction:(SEL)pinAction
          textViewDelegate:(id<NSTextViewDelegate>)textViewDelegate
{
    self = [super init];
    if (self != nil) {
        _sectionTitle = [(sectionTitle ?: @"Readiness") copy];
        _findingsToolTipTitle = [(findingsToolTipTitle ?: @"Readiness findings") copy];
        _canonicalFindings = [[NSArray alloc] init];
        _jumpLinkByFindingIdentity = [[NSDictionary alloc] init];
        _pinTarget = pinTarget;
        _pinAction = pinAction;
        _textViewDelegate = textViewDelegate;
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
    [_sectionTitle release];
    [_findingsToolTipTitle release];
    [_canonicalFindings release];
    [_jumpLinkByFindingIdentity release];
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
        _sectionLabel = [self newSectionLabelWithString:_sectionTitle];
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
        [_textView setDelegate:_textViewDelegate];
    }

    if (_scrollView == nil) {
        _scrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
        SlateInspectorRailApplyWarningScrollViewStyle(_scrollView);
        [_scrollView setDocumentView:_textView];
    }
    if ([_scrollView superview] == nil) {
        [superview addSubview:_scrollView];
    }

    if (_pinButton == nil && _pinTarget != nil && _pinAction != NULL) {
        _pinButton = [SlateInspectorRailCreatePinButton(_pinTarget, _pinAction) retain];
    }
    if (_pinButton != nil && [_pinButton superview] == nil) {
        [superview addSubview:_pinButton];
    }
}

- (void)setPinTarget:(id)target action:(SEL)action
{
    _pinTarget = target;
    _pinAction = action;

    if (_pinButton != nil) {
        [_pinButton setTarget:_pinTarget];
        [_pinButton setAction:_pinAction];
        [[_pinButton cell] setTarget:_pinTarget];
        [[_pinButton cell] setAction:_pinAction];
    }
}

- (void)setPinState:(BOOL)pinned
{
    [_pinButton setState:(pinned ? NSOnState : NSOffState)];
}

- (void)setTextViewDelegate:(id<NSTextViewDelegate>)delegate
{
    _textViewDelegate = delegate;
    [_textView setDelegate:_textViewDelegate];
}

- (void)setSectionTitle:(NSString *)sectionTitle
{
    NSString *resolvedTitle = SlateInspectorRailStringHasContent(sectionTitle) ? sectionTitle : @"Readiness";
    if ([_sectionTitle isEqualToString:resolvedTitle]) {
        return;
    }

    [_sectionTitle release];
    _sectionTitle = [resolvedTitle copy];
    [_sectionLabel setStringValue:_sectionTitle];
}

- (void)updateCopyHints
{
    NSString *toolTip = SlateInspectorRailFindingsSummaryToolTip(_canonicalFindings, _findingsToolTipTitle);
    [_statusLabel setToolTip:toolTip];
    [_sectionLabel setToolTip:toolTip];
    SlateInspectorRailApplyCopyHintToView(_scrollView, toolTip);
    SlateInspectorRailApplyCopyHintToView(_textView, toolTip);
}

- (void)updateWithFindings:(NSArray *)findings
               emptyStatus:(NSString *)emptyStatus
              emptyMessage:(NSString *)emptyMessage
jumpLinksByFindingIdentity:(NSDictionary *)jumpLinkByFindingIdentity
{
    NSArray *canonicalFindings = SlateInspectorRailCanonicalFindingsArray(findings);
    [_canonicalFindings release];
    _canonicalFindings = [canonicalFindings retain];

    NSDictionary *resolvedJumpLinks = [jumpLinkByFindingIdentity isKindOfClass:[NSDictionary class]]
        ? jumpLinkByFindingIdentity
        : [NSDictionary dictionary];
    [_jumpLinkByFindingIdentity release];
    _jumpLinkByFindingIdentity = [resolvedJumpLinks retain];

    NSMutableArray *blockers = nil;
    NSMutableArray *warnings = nil;
    SlateInspectorRailSplitFindingsBySeverity(_canonicalFindings, &blockers, &warnings);
    SlateInspectorRailApplyWarningStatusStyle(_statusLabel, [blockers count] > 0, [warnings count] > 0);
    [_statusLabel setStringValue:SlateInspectorRailReadinessStatusText(_canonicalFindings, emptyStatus)];

    NSAttributedString *readinessText = SlateInspectorRailReadinessAttributedText(_canonicalFindings,
                                                                                 emptyMessage,
                                                                                 _jumpLinkByFindingIdentity);
    SlateInspectorRailSetReadinessText(_textView, readinessText);
    [self updateCopyHints];
}

- (void)updateWithReviewPaneSnapshot:(NSDictionary *)reviewPaneSnapshot
{
    if (![reviewPaneSnapshot isKindOfClass:[NSDictionary class]]) {
        [self updateWithFindings:[NSArray array]
                      emptyStatus:@"No findings"
                     emptyMessage:@""
       jumpLinksByFindingIdentity:[NSDictionary dictionary]];
        return;
    }

    NSArray *findings = [reviewPaneSnapshot objectForKey:SlateReviewPaneSnapshotKeyFindings];
    NSString *emptyStatus = [reviewPaneSnapshot objectForKey:SlateReviewPaneSnapshotKeyEmptyStatus];
    NSString *emptyMessage = [reviewPaneSnapshot objectForKey:SlateReviewPaneSnapshotKeyEmptyMessage];
    NSDictionary *jumpLinks = [reviewPaneSnapshot objectForKey:SlateReviewPaneSnapshotKeyJumpLinksByFindingIdentity];
    [self updateWithFindings:findings
                 emptyStatus:emptyStatus
                emptyMessage:emptyMessage
  jumpLinksByFindingIdentity:jumpLinks];
}

- (void)setRailHidden:(BOOL)hidden
{
    [_sectionLabel setHidden:hidden];
    [_statusLabel setHidden:hidden];
    [_scrollView setHidden:hidden];
    [_pinButton setHidden:hidden];
}

- (void)applySectionFrame:(NSRect)sectionFrame
              statusFrame:(NSRect)statusFrame
              scrollFrame:(NSRect)scrollFrame
                 pinFrame:(NSRect)pinFrame
               pinVisible:(BOOL)pinVisible
{
    [_sectionLabel setHidden:NO];
    [_statusLabel setHidden:NO];
    [_scrollView setHidden:NO];
    [_sectionLabel setFrame:sectionFrame];
    [_statusLabel setFrame:statusFrame];
    [_scrollView setFrame:scrollFrame];

    if (_pinButton != nil) {
        [_pinButton setHidden:!pinVisible];
        if (pinVisible) {
            [_pinButton setFrame:pinFrame];
        }
    }
}

- (BOOL)ownsTextView:(NSTextView *)textView
{
    return (textView != nil && textView == _textView);
}

@end
