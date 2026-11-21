//
//  SplitViewController.m
//  Slate
//
//  Created by Jerry Hale on 3/20/26
//  Copyright (c) 2026 Jerry Hale All rights reserved.

#import "SplitViewController.h"

static const CGFloat WorkspaceMaximumHeight = 400.0;

@implementation SplitViewController

- (void)attachToWindow:(NSWindow *)window topView:(NSView *)topView bottomView:(NSView *)bottomView
{
    NSViewController *windowContentController = [[NSViewController alloc] initWithNibName:nil bundle:nil];
    windowContentController.view = window.contentView;
    [windowContentController addChildViewController:self];

    NSViewController *playerController = [[NSViewController alloc] initWithNibName:nil bundle:nil];
    NSViewController *workspaceController = [[NSViewController alloc] initWithNibName:nil bundle:nil];
    playerController.view = topView;
    workspaceController.view = bottomView;
    [topView removeFromSuperview];
    [bottomView removeFromSuperview];
    topView.translatesAutoresizingMaskIntoConstraints = NO;
    bottomView.translatesAutoresizingMaskIntoConstraints = NO;
    bottomView.clipsToBounds = YES;

    NSSplitView *splitView = self.splitView;
    splitView.vertical = NO;
    splitView.dividerStyle = NSSplitViewDividerStylePaneSplitter;
    splitView.identifier = @"SplitView";
    splitView.frame = _splitViewHost.bounds;

    NSSplitViewItem *player = [NSSplitViewItem splitViewItemWithViewController:playerController];
    player.canCollapse = YES;
    [self addSplitViewItem:player];

    NSSplitViewItem *workspace = [NSSplitViewItem splitViewItemWithViewController:workspaceController];
    workspace.canCollapse = YES;
    workspace.maximumThickness = WorkspaceMaximumHeight;
    workspace.holdingPriority = NSLayoutPriorityDefaultLow + 1;
    workspace.collapseBehavior = NSSplitViewItemCollapseBehaviorPreferResizingSiblingsWithFixedSplitView;
    [self addSplitViewItem:workspace];
    splitView.autosaveName = @"SLATE_WORKSPACE_SPLIT_VIEW";

    NSView *splitContent = self.view;
    splitContent.translatesAutoresizingMaskIntoConstraints = NO;
    [_splitViewHost addSubview:splitContent];
    [NSLayoutConstraint activateConstraints:@[
        [splitContent.leadingAnchor constraintEqualToAnchor:_splitViewHost.leadingAnchor],
        [splitContent.trailingAnchor constraintEqualToAnchor:_splitViewHost.trailingAnchor],
        [splitContent.topAnchor constraintEqualToAnchor:_splitViewHost.topAnchor],
        [splitContent.bottomAnchor constraintEqualToAnchor:_splitViewHost.bottomAnchor]
    ]];

    window.contentViewController = windowContentController;
    [window setContentBorderThickness:NSMinY(_splitViewHost.frame) forEdge:NSMinYEdge];
    [window.contentView layoutSubtreeIfNeeded];

    [playerController release];
    [workspaceController release];
    [windowContentController release];
}

- (IBAction)toggleBtmPane:(id)sender
{
    #pragma unused (sender)
    NSSplitViewItem *workspace = self.splitViewItems.lastObject;
    workspace.collapsed = !workspace.isCollapsed;
}

@end
