//
//  SlateTrackSnapshotContract.h
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

#ifndef SLATE_SLATETRACKSNAPSHOTCONTRACT_H
#define SLATE_SLATETRACKSNAPSHOTCONTRACT_H

#import <Foundation/Foundation.h>

// Plain Foundation snapshot consumed by the track UI adapter.
// No table view, controller, or movie objects belong in this contract.
static NSString * const SlateTrackSnapshotSchemaVersion1 = @"trackSnapshot.v1";

// Top-level keys.
static NSString * const SlateTrackSnapshotKeySchemaVersion = @"schemaVersion";
static NSString * const SlateTrackSnapshotKeyHasMovie = @"hasMovie";
static NSString * const SlateTrackSnapshotKeyRows = @"rows";
static NSString * const SlateTrackSnapshotKeyTrackCount = @"trackCount";
static NSString * const SlateTrackSnapshotKeyError = @"error";

// Optional structured error keys when the runtime-backed snapshot is unavailable.
static NSString * const SlateTrackSnapshotErrorKeyCode = @"code";
static NSString * const SlateTrackSnapshotErrorKeyMessage = @"message";

// Row keys shared by the table, inspector, and operator AEs.
static NSString * const SlateTrackSnapshotRowKeyRowIndex = @"rowIndex";
static NSString * const SlateTrackSnapshotRowKeyRow = @"row";
static NSString * const SlateTrackSnapshotRowKeyTrackID = @"trackID";
static NSString * const SlateTrackSnapshotRowKeyEnabled = @"enabled";
static NSString * const SlateTrackSnapshotRowKeyEnabledFlag = @"enabledFlag";
static NSString * const SlateTrackSnapshotRowKeyReferenceTrack = @"referenceTrack";
static NSString * const SlateTrackSnapshotRowKeyAudioTrack = @"audioTrack";
static NSString * const SlateTrackSnapshotRowKeyVideoTrack = @"videoTrack";
static NSString * const SlateTrackSnapshotRowKeySubtitleTrack = @"subtitleTrack";
static NSString * const SlateTrackSnapshotRowKeyClosedCaptionTrack = @"closedCaptionTrack";
static NSString * const SlateTrackSnapshotRowKeyTextTrack = @"textTrack";
static NSString * const SlateTrackSnapshotRowKeyTimecodeTrack = @"timecodeTrack";
static NSString * const SlateTrackSnapshotRowKeyTrackType = @"trackType";
static NSString * const SlateTrackSnapshotRowKeyTrackTypeColumn = @"trackTypeColumn";
static NSString * const SlateTrackSnapshotRowKeyMediaType = @"mediaType";
static NSString * const SlateTrackSnapshotRowKeyDuration = @"duration";
static NSString * const SlateTrackSnapshotRowKeyLanguage = @"language";
static NSString * const SlateTrackSnapshotRowKeyDisplayName = @"displayName";
static NSString * const SlateTrackSnapshotRowKeyFormatSummary = @"formatSummary";
static NSString * const SlateTrackSnapshotRowKeyInfo = @"info";
static NSString * const SlateTrackSnapshotRowKeyAudioGain = @"audioGain";
static NSString * const SlateTrackSnapshotRowKeyAudioChannelCount = @"audioChannelCount";
static NSString * const SlateTrackSnapshotRowKeyAudioChannelLayoutResolved = @"audioChannelLayoutResolved";
static NSString * const SlateTrackSnapshotRowKeyAudioChannelAssignmentsGeneric = @"audioChannelAssignmentsGeneric";
static NSString * const SlateTrackSnapshotRowKeyEncodedWidth = @"encodedWidth";
static NSString * const SlateTrackSnapshotRowKeyEncodedHeight = @"encodedHeight";
static NSString * const SlateTrackSnapshotRowKeyDisplayWidth = @"displayWidth";
static NSString * const SlateTrackSnapshotRowKeyDisplayHeight = @"displayHeight";
static NSString * const SlateTrackSnapshotRowKeySourcePath = @"sourcePath";
static NSString * const SlateTrackSnapshotRowKeyDetails = @"details";
static NSString * const SlateTrackSnapshotRowKeyDetailsText = @"detailsText";

// Inspector detail pair keys.
static NSString * const SlateTrackSnapshotDetailKeyKey = @"key";
static NSString * const SlateTrackSnapshotDetailKeyValue = @"value";

// Primary table column identifiers.
static NSString * const SlateTrackSnapshotColumnID = @"ID";
static NSString * const SlateTrackSnapshotColumnEnabled = @"ENABLED";
static NSString * const SlateTrackSnapshotColumnTrackType = @"TRACKTYPE";
static NSString * const SlateTrackSnapshotColumnDuration = @"DURATION";
static NSString * const SlateTrackSnapshotColumnLanguage = @"LANGUAGE";
static NSString * const SlateTrackSnapshotColumnInfo = @"INFO";

#endif
