//
//  PackageViewController.h
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

@class PosterArtView;
@class UtilReadinessRailPresenter;

@interface PackageViewController : NSViewController <NSTextViewDelegate>
{
    // Asset stack: fixed-position scalar fields and poster preview.
    NSTextField                 *_typeField,
                                *_name,
                                *_vendorid,
                                *_mediaType,
                                *_releaseDate,
                                *_rating,
                                *_ratingSystem;
    PosterArtView               *_posterArtView;

    // Code-owned rails; the old static NIB assumptions stop here.
    NSMutableArray              *_synopsisPanels;
    NSMutableArray              *_metadataCollectionPanels;
    NSBox                       *_metadataGroupBox;
    NSTextField                 *_metadataSectionLabel;
    UtilReadinessRailPresenter  *_readinessPresenter;

    NSArray                     *_canonicalValidationFindings;
    BOOL                        _inspectorRailPinned;
    BOOL                        _hasPackageContext;
    BOOL                        _didInitializePackageControllerData;
}

#pragma mark - Package Presentation
- (void)presentPackageSnapshot:(NSDictionary *)packageSnapshot;
- (void)clearPackagePresentation;

#pragma mark - Validation
- (void)applyCanonicalValidationFindings:(NSArray *)findings;
- (NSArray *)canonicalValidationFindings;

#pragma mark - Layout and Probe
- (void)applyWorkspaceLayoutForWidth:(CGFloat)workspaceWidth;
- (NSDictionary *)modeSwitchContextSnapshot;
- (NSDictionary *)layoutProbeSnapshot;
- (void)restoreModeSwitchContextSnapshot:(NSDictionary *)snapshot;
- (NSView *)preferredModeFirstResponderView;

@end
