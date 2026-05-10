//
//  SlateReviewSnapshotContract.h
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

#ifndef SLATE_SLATEREVIEWSNAPSHOTCONTRACT_H
#define SLATE_SLATEREVIEWSNAPSHOTCONTRACT_H

#import <Foundation/Foundation.h>

// Plain Foundation snapshot consumed by readiness rails, review commands,
// and operator AEs. No view, controller, movie, or package objects belong here.
static NSString * const SlateReviewSnapshotSchemaVersion1 = @"reviewSnapshot.v1";
static NSString * const SlateReviewPaneSnapshotSchemaVersion1 = @"reviewPaneSnapshot.v1";

// Top-level review snapshot keys.
static NSString * const SlateReviewSnapshotKeySchemaVersion = @"schemaVersion";
static NSString * const SlateReviewSnapshotKeyContext = @"context";
static NSString * const SlateReviewSnapshotKeyStatus = @"status";
static NSString * const SlateReviewSnapshotKeySummary = @"summary";
static NSString * const SlateReviewSnapshotKeyFindings = @"findings";
static NSString * const SlateReviewSnapshotKeyPanes = @"panes";
static NSString * const SlateReviewSnapshotKeyPaneOrder = @"paneOrder";
static NSString * const SlateReviewSnapshotKeyActivePane = @"activePane";
static NSString * const SlateReviewSnapshotKeyCurrentFindingIndex = @"currentFindingIndex";
static NSString * const SlateReviewSnapshotKeyNextFinding = @"nextFinding";
static NSString * const SlateReviewSnapshotKeyPreviousFinding = @"previousFinding";
static NSString * const SlateReviewSnapshotKeyDisplayText = @"displayText";

// Pane-level readiness snapshot keys.
static NSString * const SlateReviewPaneSnapshotKeySchemaVersion = @"schemaVersion";
static NSString * const SlateReviewPaneSnapshotKeyPane = @"pane";
static NSString * const SlateReviewPaneSnapshotKeyTitle = @"title";
static NSString * const SlateReviewPaneSnapshotKeyStatus = @"status";
static NSString * const SlateReviewPaneSnapshotKeyFindings = @"findings";
static NSString * const SlateReviewPaneSnapshotKeyFindingCount = @"findingCount";
static NSString * const SlateReviewPaneSnapshotKeyBlockers = @"blockers";
static NSString * const SlateReviewPaneSnapshotKeyWarnings = @"warnings";
static NSString * const SlateReviewPaneSnapshotKeyEmptyStatus = @"emptyStatus";
static NSString * const SlateReviewPaneSnapshotKeyEmptyMessage = @"emptyMessage";
static NSString * const SlateReviewPaneSnapshotKeyJumpLinksByFindingIdentity = @"jumpLinksByFindingIdentity";
static NSString * const SlateReviewPaneSnapshotKeyNextFinding = @"nextFinding";
static NSString * const SlateReviewPaneSnapshotKeyPreviousFinding = @"previousFinding";
static NSString * const SlateReviewPaneSnapshotKeyDisplayText = @"displayText";
static NSString * const SlateReviewPaneSnapshotKeyError = @"error";

// Optional structured error keys when the runtime-backed pane snapshot is unavailable.
static NSString * const SlateReviewPaneSnapshotErrorKeyCode = @"code";
static NSString * const SlateReviewPaneSnapshotErrorKeyMessage = @"message";

// Finding target projection keys. These decorate canonical findings when a
// runtime can resolve where an operator should land in the adapter.
static NSString * const SlateReviewFindingTargetKeyPane = @"targetPane";
static NSString * const SlateReviewFindingTargetKeyTarget = @"target";
static NSString * const SlateReviewFindingTargetKeyRowIndex = @"targetRowIndex";
static NSString * const SlateReviewFindingTargetKeyRow = @"targetRow";
static NSString * const SlateReviewFindingTargetKeyTimeSeconds = @"targetTimeSeconds";
static NSString * const SlateReviewFindingTargetKeyTimeValue = @"targetTimeValue";
static NSString * const SlateReviewFindingTargetKeyDisplayText = @"targetDisplayText";

// Canonical pane identifiers.
static NSString * const SlateReviewPaneKeyPackage = @"package";
static NSString * const SlateReviewPaneKeyTrack = @"track";
static NSString * const SlateReviewPaneKeyChapter = @"chapter";
static NSString * const SlateReviewPaneKeyTimeline = @"timeline";

// Common adapter targets.
static NSString * const SlateReviewTargetPackage = @"package";
static NSString * const SlateReviewTargetTracks = @"tracks";
static NSString * const SlateReviewTargetTracksAssetType = @"tracks-assetType";
static NSString * const SlateReviewTargetChapters = @"chapters";
static NSString * const SlateReviewTargetTimeline = @"timeline";

#endif
