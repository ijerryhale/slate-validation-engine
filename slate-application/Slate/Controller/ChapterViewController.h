//
//  ChapterViewController.h
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

@class PlayerView;
@class QuadrantView;
@class UtilReadinessRailPresenter;

@interface ChapterViewController : NSViewController <NSTableViewDataSource, NSTableViewDelegate, NSTextViewDelegate>
{
    // Live movie surface.
    PlayerView                  *_playerView;
    IBOutlet NSTableView        *_tableView;
    IBOutlet QuadrantView       *_quadrantView;

    // Local mutation state for older chapter authoring commands.
    NSMutableArray              *_rowArray;
    NSArray                     *_canonicalValidationFindings;

    // Inspector controls and code-owned rails.
    IBOutlet NSButton           *_jumpToImgTC;
    IBOutlet NSTextField        *_leadoutSecs;
    IBOutlet NSTextField        *_chapterCnt;
    IBOutlet NSPopUpButton      *_cropModePopup;
    NSTextField                 *_chapterCountLabel;
    NSTextField                 *_tableSectionLabel;
    NSTextField                 *_inspectorSectionLabel;
    NSTextField                 *_advancedSectionLabel;
    UtilReadinessRailPresenter  *_readinessPresenter;
    NSBox                       *_inspectorGroupBox;
    NSTextField                 *_tableEmptyStateLabel;
    NSTextField                 *_inspectorEmptyStateLabel;
    NSTextField                 *_leadoutLabel;

    BOOL                        _hasPackageContext;
    BOOL                        _inspectorRailPinned;
    BOOL                        _isObservingHasMovie;
    BOOL                        _suppressChapterSelectionJump;
}

#pragma mark - Data
#pragma mark - View Surface
@property (nonatomic, assign) PlayerView   *playerView;

#pragma mark - Validation
-(BOOL)hasInvalidImageFlags;
-(NSInteger)firstInvalidImageRowIndex;
-(void)applyCanonicalValidationFindings:(NSArray *)findings;
-(NSArray *)canonicalValidationFindings;
-(NSArray *)validationObservedChapterRows;

#pragma mark - Package Input
-(void)applyChapterSnapshot:(NSDictionary *)chapterSnapshot;
-(NSArray *)chapterInspectorDetailRows;

#pragma mark - Chapter Commands
-(IBAction)deleteAllChapters:(id)sender;
//  -(IBAction)deleteChapter:(id)sender;
//  (IBAction)addChapter:(id)sender;
//  -(IBAction)addChapters:(id)sender;

-(IBAction)grabChapterImage:(id)sender;
-(IBAction)adjMediaChapterTime:(id)sender;

-(IBAction)reloadTableSelection:(id)sender;
-(IBAction)updateChapterCropMode:(id)sender;

#pragma mark - Layout and Probe
-(void)applyWorkspaceLayoutForWidth:(CGFloat)workspaceWidth;
- (NSDictionary *)modeSwitchContextSnapshot;
- (NSDictionary *)layoutProbeSnapshot;
- (void)restoreModeSwitchContextSnapshot:(NSDictionary *)snapshot;
- (NSView *)preferredModeFirstResponderView;
- (void)syncQuadrantBackgroundToPlayerView;

@end
