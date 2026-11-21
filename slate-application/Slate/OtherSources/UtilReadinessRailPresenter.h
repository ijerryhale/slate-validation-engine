//
//  UtilReadinessRailPresenter.h
//  Slate
//
//  Created by Jerry Hale on 5/6/26.
//  Copyright (c) 2026 Jerry Hale. All rights reserved.
//
//  Proprietary and confidential.
//  This file is part of Slate and is not open source software.
//
//  No license is granted to copy, modify, distribute, sublicense, or use this
//  source code except under a written agreement with the copyright holder.
//  Unauthorized use, disclosure, reproduction, or distribution is prohibited.
//

#import <Cocoa/Cocoa.h>
#import "UtilInspectorRailCoord.h"

@interface UtilReadinessRailPresenter : NSObject
{
    NSTextField *_sectionLabel;
    NSTextField *_statusLabel;
    NSScrollView *_scrollView;
    NSTextView *_textView;
    NSButton *_pinButton;

    NSString *_findingsToolTipTitle;
    NSString *_pinDefaultsKey;
    id<SMInspectorRailModeAdapter, NSTextViewDelegate> _owner;
    BOOL _pinned;
}

@property (readonly) NSTextField *sectionLabel;
@property (readonly) NSScrollView *scrollView;
@property (readonly) NSButton *pinButton;
@property (readonly, getter=isPinned) BOOL pinned;

- (id)initWithFindingsToolTipTitle:(NSString *)findingsToolTipTitle
                   pinDefaultsKey:(NSString *)pinDefaultsKey
                            owner:(id<SMInspectorRailModeAdapter, NSTextViewDelegate>)owner;

- (void)ensureViewsInSuperview:(NSView *)superview;
- (void)restoreSubviewOrderWithOverlays:(NSArray<NSView *> *)overlays;

- (void)presentFindings:(NSArray *)findings
                paneKey:(NSString *)paneKey
            emptyStatus:(NSString *)emptyStatus
           emptyMessage:(NSString *)emptyMessage
     jumpLinkForFinding:(NSString *(^)(NSDictionary *finding))jumpLinkForFinding;

- (void)hideRail;
- (void)layoutRailAtX:(CGFloat)x topY:(CGFloat)topY bottomY:(CGFloat)bottomY;

- (BOOL)ownsTextView:(NSTextView *)textView;

@end
