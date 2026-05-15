//
//  SlateTimelineSnapshotContract.h
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

#ifndef SLATE_SLATETIMELINESNAPSHOTCONTRACT_H
#define SLATE_SLATETIMELINESNAPSHOTCONTRACT_H

#import <Foundation/Foundation.h>

// Plain Foundation timeline snapshot consumed by TimelineView and operator
// probes. AppKit layers stay in the adapter; math and readouts live here.
static NSString * const SlateTimelineSnapshotSchemaVersion1 = @"timelineSnapshot.v1";

static NSString * const SlateTimelineSnapshotKeySchemaVersion = @"schemaVersion";
static NSString * const SlateTimelineSnapshotKeyBounds = @"bounds";
static NSString * const SlateTimelineSnapshotKeyUsableMovie = @"usableMovie";
static NSString * const SlateTimelineSnapshotKeyState = @"state";
static NSString * const SlateTimelineSnapshotKeyLayout = @"layout";
static NSString * const SlateTimelineSnapshotKeyReadouts = @"readouts";
static NSString * const SlateTimelineSnapshotKeyTicks = @"ticks";
static NSString * const SlateTimelineSnapshotKeyPlayhead = @"playhead";
static NSString * const SlateTimelineSnapshotKeySelection = @"selection";

static NSString * const SlateTimelineSnapshotStateKeyDuration = @"duration";
static NSString * const SlateTimelineSnapshotStateKeyCurrentTime = @"currentTime";
static NSString * const SlateTimelineSnapshotStateKeyFrameRate = @"frameRate";
static NSString * const SlateTimelineSnapshotStateKeySelectionStart = @"selectionStart";
static NSString * const SlateTimelineSnapshotStateKeySelectionEnd = @"selectionEnd";
static NSString * const SlateTimelineSnapshotStateKeyCurrentTimecodeString = @"currentTimecodeString";
static NSString * const SlateTimelineSnapshotStateKeyCollapsedSelection = @"collapsedSelection";

static NSString * const SlateTimelineSnapshotLayoutKeyOuterBounds = @"outerBounds";
static NSString * const SlateTimelineSnapshotLayoutKeyLaneBounds = @"laneBounds";
static NSString * const SlateTimelineSnapshotLayoutKeyBodyLaneRect = @"bodyLaneRect";
static NSString * const SlateTimelineSnapshotLayoutKeyFullHeightLaneRect = @"fullHeightLaneRect";
static NSString * const SlateTimelineSnapshotLayoutKeyRulerBandRect = @"rulerBandRect";
static NSString * const SlateTimelineSnapshotLayoutKeyRulerTickRect = @"rulerTickRect";
static NSString * const SlateTimelineSnapshotLayoutKeyRulerLabelSafeRect = @"rulerLabelSafeRect";
static NSString * const SlateTimelineSnapshotLayoutKeyRegionBandRect = @"regionBandRect";
static NSString * const SlateTimelineSnapshotLayoutKeyLaneRect = @"laneRect";
static NSString * const SlateTimelineSnapshotLayoutKeyLaneHitRect = @"laneHitRect";

static NSString * const SlateTimelineSnapshotPlayheadKeyCenterX = @"centerX";
static NSString * const SlateTimelineSnapshotPlayheadKeyCapRect = @"capRect";
static NSString * const SlateTimelineSnapshotPlayheadKeyStemRect = @"stemRect";
static NSString * const SlateTimelineSnapshotPlayheadKeyVisualRect = @"visualRect";
static NSString * const SlateTimelineSnapshotPlayheadKeyHitRect = @"hitRect";

static NSString * const SlateTimelineSnapshotSelectionKeyRegionRect = @"regionRect";

static NSString * const SlateTimelineSnapshotReadoutKeyRemaining = @"remaining";
static NSString * const SlateTimelineSnapshotReadoutKeyDuration = @"duration";
static NSString * const SlateTimelineSnapshotReadoutKeyHead = @"head";

static NSString * const SlateTimelineSnapshotTicksKeyMajorCount = @"majorCount";
static NSString * const SlateTimelineSnapshotTicksKeyMinorPerMajorInterval = @"minorPerMajorInterval";
static NSString * const SlateTimelineSnapshotTicksKeyMajorTicks = @"majorTicks";
static NSString * const SlateTimelineSnapshotTicksKeyMinorTicks = @"minorTicks";
static NSString * const SlateTimelineSnapshotTickKeyIndex = @"index";
static NSString * const SlateTimelineSnapshotTickKeyMajorIndex = @"majorIndex";
static NSString * const SlateTimelineSnapshotTickKeyTime = @"time";
static NSString * const SlateTimelineSnapshotTickKeyX = @"x";
static NSString * const SlateTimelineSnapshotTickKeyLabel = @"label";

static NSString * const SlateTimelineSnapshotRectKeyX = @"x";
static NSString * const SlateTimelineSnapshotRectKeyY = @"y";
static NSString * const SlateTimelineSnapshotRectKeyWidth = @"width";
static NSString * const SlateTimelineSnapshotRectKeyHeight = @"height";

#endif
