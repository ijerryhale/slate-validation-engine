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

@interface UtilReadinessRailPresenter : NSObject
{
    NSTextField *_sectionLabel;
    NSTextField *_statusLabel;
    NSScrollView *_scrollView;
    NSTextView *_textView;
    NSButton *_pinButton;

    NSString *_sectionTitle;
    NSString *_findingsToolTipTitle;
    NSArray *_canonicalFindings;
    NSDictionary *_jumpLinkByFindingIdentity;

    id _pinTarget;
    SEL _pinAction;
    id<NSTextViewDelegate> _textViewDelegate;
}

@property (readonly) NSTextField *sectionLabel;
@property (readonly) NSTextField *statusLabel;
@property (readonly) NSScrollView *scrollView;
@property (readonly) NSTextView *textView;
@property (readonly) NSButton *pinButton;

- (id)initWithSectionTitle:(NSString *)sectionTitle
      findingsToolTipTitle:(NSString *)findingsToolTipTitle
                 pinTarget:(id)pinTarget
                 pinAction:(SEL)pinAction
          textViewDelegate:(id<NSTextViewDelegate>)textViewDelegate;

- (void)ensureViewsInSuperview:(NSView *)superview;
- (void)setPinTarget:(id)target action:(SEL)action;
- (void)setPinState:(BOOL)pinned;
- (void)setTextViewDelegate:(id<NSTextViewDelegate>)delegate;
- (void)setSectionTitle:(NSString *)sectionTitle;

- (void)updateWithFindings:(NSArray *)findings
               emptyStatus:(NSString *)emptyStatus
              emptyMessage:(NSString *)emptyMessage
jumpLinksByFindingIdentity:(NSDictionary *)jumpLinkByFindingIdentity;
- (void)updateWithReviewPaneSnapshot:(NSDictionary *)reviewPaneSnapshot;

- (void)setRailHidden:(BOOL)hidden;
- (void)applySectionFrame:(NSRect)sectionFrame
              statusFrame:(NSRect)statusFrame
              scrollFrame:(NSRect)scrollFrame
                 pinFrame:(NSRect)pinFrame
               pinVisible:(BOOL)pinVisible;

- (BOOL)ownsTextView:(NSTextView *)textView;

@end
