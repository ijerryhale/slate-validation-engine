//
//  SplitViewController.m
//  Slate
//
//  Created by Jerry Hale on 3/20/26
//  Copyright (c) 2026 Jerry Hale All rights reserved.


#import "DictionaryKeys.h"

#import "AppController.h"
#import "PlayerView.h"

#import "SplitView.h"

#import "SplitViewController.h"

static NSString * const SplitViewDividerPositionDefaultsKey = @"SplitViewDividerPosition";

// Item 55 window-shell regions:
// - status/footer lives outside the split view and is kept as a fixed reserved band.
// - the top split region is transport strip + player band.
// - the bottom split region is the mode workspace.
static CGFloat SMWindowShellStatusFooterHeight(void) { return 29.0; }
static CGFloat SMWindowShellTransportStripHeight(void) { return 173.0; }
static CGFloat SMWindowShellPlayerBandMinHeight(void) { return 140.0; }
static CGFloat SMWindowShellPlayerBandDefaultHeight(void) { return 310.0; }
static CGFloat SMWindowShellPlayerBandMaxHeight(void) { return 320.0; }
static CGFloat SMWindowShellWorkspaceMinHeight(void) { return 260.0; }
static CGFloat SMWindowShellAbsoluteMinimumTopRegionHeight(void) { return 220.0; }
static NSLayoutPriority SMWindowShellTopRegionHoldingPriority(void) { return 600.0; }
static NSLayoutPriority SMWindowShellWorkspaceHoldingPriority(void) { return 250.0; }

static CGFloat SMWindowShellTopRegionMinHeight(void)
{
    return SMWindowShellTransportStripHeight() + SMWindowShellPlayerBandMinHeight();
}

static CGFloat SMWindowShellTopRegionPreferredHeight(void)
{
    return SMWindowShellTransportStripHeight() + SMWindowShellPlayerBandDefaultHeight();
}

static CGFloat SMWindowShellTopRegionMaxHeight(void)
{
    return SMWindowShellTransportStripHeight() + SMWindowShellPlayerBandMaxHeight();
}

@implementation SplitViewController

- (void)applyHoldingPriorities
{
    if ([[_splitView subviews] count] >= 2) {
        [_splitView setHoldingPriority:SMWindowShellTopRegionHoldingPriority() forSubviewAtIndex:0];
        [_splitView setHoldingPriority:SMWindowShellWorkspaceHoldingPriority() forSubviewAtIndex:1];
    }
}

- (CGFloat)clampedDividerPositionForSplitHeight:(CGFloat)splitHeight proposedPosition:(CGFloat)proposedPosition
{
    CGFloat dividerThickness = [_splitView dividerThickness];
    CGFloat topRegionMin = SMWindowShellTopRegionMinHeight();
    CGFloat topRegionMax = SMWindowShellTopRegionMaxHeight();
    CGFloat topRegionMaxFromWorkspaceMinimum = splitHeight - dividerThickness - SMWindowShellWorkspaceMinHeight();

    topRegionMin = MAX(SMWindowShellAbsoluteMinimumTopRegionHeight(), topRegionMin);
    topRegionMax = MIN(topRegionMax, topRegionMaxFromWorkspaceMinimum);
    topRegionMax = MAX(topRegionMin, topRegionMax);

    return MIN(MAX(proposedPosition, topRegionMin), topRegionMax);
}

- (CGFloat)storedOrPreferredDividerPosition
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:SplitViewDividerPositionDefaultsKey] != nil) {
        CGFloat storedPosition = [defaults doubleForKey:SplitViewDividerPositionDefaultsKey];
        if (storedPosition > 0.0) {
            return storedPosition;
        }
    }

    return SMWindowShellTopRegionPreferredHeight();
}

- (void)persistCurrentDividerPosition:(CGFloat)position
{
    if (position <= 0.0) {
        return;
    }
    _position = position;
    [[NSUserDefaults standardUserDefaults] setDouble:_position forKey:SplitViewDividerPositionDefaultsKey];
}

- (void)applyClampedDividerPositionForCurrentSplitBoundsWithProposedPosition:(CGFloat)proposedPosition
{
    CGFloat splitHeight = NSHeight([_splitView bounds]);
    CGFloat clampedPosition = [self clampedDividerPositionForSplitHeight:splitHeight proposedPosition:proposedPosition];
    CGFloat existingPosition = [_splitView positionForDividerAtIndex:0];

    if (fabs(existingPosition - clampedPosition) > 0.5) {
        [_splitView setPosition:clampedPosition ofDividerAtIndex:0];
    }

    [self persistCurrentDividerPosition:[_splitView positionForDividerAtIndex:0]];
}

- (void)awakeFromNib
{
    NSWindow *window = [_splitView window];
    if (window != nil) {
        [window setContentBorderThickness:SMWindowShellStatusFooterHeight() forEdge:NSMinYEdge];
    }
    [self applyHoldingPriorities];
    [self applyClampedDividerPositionForCurrentSplitBoundsWithProposedPosition:[self storedOrPreferredDividerPosition]];
}

#pragma mark -- Collapse View

-(IBAction)toggleBtmPane:(id)sender;
{
    #pragma unused (sender)
    NSView *bottom = [[_splitView subviews] objectAtIndex:1];
    BOOL bottomHidden = [bottom isHidden];
    BOOL bottomCollapsed = [_splitView isSubviewCollapsed:bottom] || NSHeight([bottom frame]) == 0.0;

    if (bottomHidden || bottomCollapsed) {
        [bottom setHidden:NO];
        CGFloat proposedPosition = (_position > 0.0) ? _position : [self storedOrPreferredDividerPosition];
        [self applyClampedDividerPositionForCurrentSplitBoundsWithProposedPosition:proposedPosition];
        [_splitView adjustSubviews];
    } else {
        [self persistCurrentDividerPosition:[_splitView positionForDividerAtIndex:0]];
        [bottom setHidden:NO];
        [_splitView setPosition:[_splitView maxPossiblePositionOfDividerAtIndex:0] ofDividerAtIndex:0 animate:NO];
        [_splitView adjustSubviews];
    }

    AppController *delegate = (AppController *)[[_splitView window] delegate];
    [delegate updateCurrentSize];
    [_splitView setNeedsDisplay:YES];
    [_splitView displayIfNeeded];
}

-(BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview
{
    return (subview == [[splitView subviews] objectAtIndex:1]);
}

-(BOOL)splitView:(NSSplitView *)splitView shouldCollapseSubview:(NSView *)subview forDoubleClickOnDividerAt:(NSInteger)dividerIndex
{
    #pragma unused (dividerIndex)
    return (subview == [[splitView subviews] objectAtIndex:1]);
}

-(BOOL)splitView:(NSSplitView *)splitView shouldHideDividerAtIndex:(NSInteger)dividerIndex
{
    #pragma unused (splitView, dividerIndex)
    return (NO);
}

-(void)splitViewDidResizeSubviews:(NSNotification *)notification
{
    #pragma unused (notification)
    NSView *top = [[_splitView subviews] objectAtIndex:0];
    NSView *bottom = [[_splitView subviews] objectAtIndex:1];
    BOOL bottomCollapsed = [_splitView isSubviewCollapsed:bottom] || NSHeight([bottom frame]) == 0.0;
    if ([bottom isHidden]) {
        [top setFrameSize:NSMakeSize(NSWidth([top frame]), NSHeight([_splitView bounds]))];
    } else if (!bottomCollapsed) {
        CGFloat proposedPosition = [_splitView positionForDividerAtIndex:0];
        [self applyClampedDividerPositionForCurrentSplitBoundsWithProposedPosition:proposedPosition];
    }
    AppController *delegate = (AppController *)[[_splitView window] delegate];
    [delegate updateCurrentSize];
}

-(void)splitViewWillResizeSubviews:(NSNotification *)notification
{
    AppController *delegate = (AppController *)[[_splitView window] delegate];
    [delegate windowDidResize:notification];
}

-(BOOL)splitView:(NSSplitView *)splitView shouldAdjustSizeOfSubview:(NSView *)subview
{
    #pragma unused (splitView)
    NSView *top = [[_splitView subviews] objectAtIndex:0];
    NSView *bottom = [[_splitView subviews] objectAtIndex:1];
    if ([bottom isHidden]) {
        return (subview == top);
    }
    if (subview == top) {
        return NO;
    }
    if (subview == bottom) {
        return YES;
    }
    return YES;
}

-(CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex
{
    #pragma unused (proposedMinimumPosition, dividerIndex)
    CGFloat splitHeight = NSHeight([splitView bounds]);
    CGFloat desiredMinimum = [self clampedDividerPositionForSplitHeight:splitHeight proposedPosition:SMWindowShellTopRegionMinHeight()];
    return desiredMinimum;
}

-(CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex
{
    #pragma unused (dividerIndex)
    CGFloat splitHeight = NSHeight([splitView bounds]);
    CGFloat desiredMaximum = [self clampedDividerPositionForSplitHeight:splitHeight proposedPosition:SMWindowShellTopRegionMaxHeight()];
    CGFloat currentPosition = [(SplitView *)splitView positionForDividerAtIndex:0];

    // Preserve the current divider hit point while restoring from a collapsed state.
    // Without this, AppKit may clamp immediately to desiredMaximum and the divider
    // jumps away from the mouse on first click/drag.
    CGFloat effectiveMaximum = MAX(desiredMaximum, currentPosition);
    return MIN(proposedMaximumPosition, effectiveMaximum);
}
@end
