//
//  TrackViewController.h
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

@class UtilReadinessRailPresenter;

@interface TrackViewController : NSViewController <NSTableViewDelegate, NSTextViewDelegate>
{
    // Controller-owned track rows; validation reads snapshots from here.
    NSMutableArray              *_track;
    NSArray                     *_canonicalValidationFindings;

    // NIB-era controls kept as the adapter surface.
    IBOutlet NSPopUpButton  *_assetTypePopup;
    IBOutlet NSPopUpButton  *_audioLanguagePopup;
    IBOutlet NSPopUpButton  *_videoLanguagePopup;
    IBOutlet NSTableView    *_tracks;

    // Dynamic inspector rail.
    NSScrollView            *_trackInspectorDetailsScrollView;
    NSTextView              *_trackInspectorDetailsTextView;
    NSView                  *_trackInspectorSurface;
    NSSlider                *_gainSlider;
    NSTextField             *_gainLabel;
    NSTextField             *_gainMinLabel;
    NSTextField             *_gainMidLabel;
    NSTextField             *_gainMaxLabel;
    BOOL                    _gainSliderTargetsMovie;
    
    // Code-owned headers, groups, and readiness rail.
    NSTextField             *_tracksSectionLabel;
    NSTextField             *_tracksStateLabel;
    NSTextField             *_advancedSectionLabel;
    NSBox                   *_advancedGroupBox;
    UtilReadinessRailPresenter *_readinessPresenter;
    NSButton                *_trackInspectorCopyButton;
    BOOL                    _inspectorRailPinned;
}

#pragma mark - View Surface
@property (assign) NSTableView              *tracks;

#pragma mark - Package Input and Validation
-(void)assetTypeFromPackageContext:(NSDictionary *)packageContext;
-(void)applyCanonicalValidationFindings:(NSArray *)findings;
-(NSArray *)canonicalValidationFindings;
-(BOOL)hasInvalidAssetType;
-(NSArray *)validationObservedTrackRows;
-(NSInteger)selectedAssetTypeID;

#pragma mark - Track Readiness Queries
-(BOOL)hasUnknownAssetTypeSelection;
-(BOOL)hasPrimaryVideoTrack;
-(BOOL)hasPrimaryAudioTrack;
-(NSInteger)firstAudioTrackRowWithUnknownLanguage;
-(NSUInteger)unknownLanguageAudioTrackCount;
-(NSInteger)firstAudioTrackRowWithUnresolvedChannelLayout;
-(NSUInteger)unresolvedChannelLayoutAudioTrackCount;
-(NSInteger)firstAudioTrackRowWithGenericChannelAssignments;
-(NSUInteger)genericChannelAssignmentAudioTrackCount;
-(NSInteger)firstReferenceAudioTrackRowWithUnresolvedSource;
-(NSUInteger)unresolvedSourceReferenceAudioTrackCount;
-(NSInteger)firstReferenceTrackRowWithUnknownLanguage;
-(NSUInteger)unknownLanguageReferenceTrackCount;
-(NSString *)referenceTrackTypeLabelForRow:(NSInteger)row;
-(NSInteger)firstTextTrackRowWithUnknownLanguage;
-(NSInteger)firstTextTrackRowWithUnresolvedRole;
-(NSString *)textTrackRoleLabelForRow:(NSInteger)row;
-(NSUInteger)unknownLanguageTextTrackCount;
-(NSUInteger)unresolvedRoleTextTrackCount;

#pragma mark - Layout and Probe
-(void)refreshTrackData;
-(void)applyWorkspaceLayoutForWidth:(CGFloat)workspaceWidth;
- (NSArray *)trackMovieInspectorDetailRows;
- (NSDictionary *)modeSwitchContextSnapshot;
- (NSDictionary *)layoutProbeSnapshot;
- (void)restoreModeSwitchContextSnapshot:(NSDictionary *)snapshot;
- (NSView *)preferredModeFirstResponderView;

#pragma mark - Command Surface

// Fenced mutation-intent surface: editor/write actions live below the primary
// read-only inspection/validation surface.
-(void)setMovieGain:(float)value;
-(IBAction)inspectorGainSliderChanged:(id)sender;
-(IBAction)applyAudioTrackLanguage:(id)sender;
-(IBAction)applyVideoTrackLanguage:(id)sender;
-(void)restoreMovieState:(BOOL)rebuildTracks;
-(void)removeMovieReference;
-(void)createReferenceTrack:(NSArray *)items;
-(BOOL)canDeleteSelectedTrack;
-(IBAction)deleteSelectedTrack:(id)sender;

@end
