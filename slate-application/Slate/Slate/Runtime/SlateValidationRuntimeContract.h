//
//  SlateValidationRuntimeContract.h
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

#ifndef SLATE_SLATEVALIDATIONRUNTIMECONTRACT_H
#define SLATE_SLATEVALIDATIONRUNTIMECONTRACT_H

#import <Foundation/Foundation.h>

// Plain Foundation payload accepted by SlateValidationRuntime. The app owns
// observed UI/movie state; the runtime owns package parsing and rule execution.
static NSString * const SlateValidationRuntimeExecutableName = @"SlateValidationRuntime";
static NSString * const SlateValidationRuntimeEnvironmentKey = @"SLATE_VALIDATION_RUNTIME_PATH";

static NSString * const SlateValidationObservedStateSchemaVersion1 = @"validationObservedState.v1";
static NSString * const SlateValidationObservedStateKeySchemaVersion = @"schemaVersion";
static NSString * const SlateValidationObservedStateKeyHasMovie = @"hasMovie";
static NSString * const SlateValidationObservedStateKeyHasObservedTrackState = @"hasObservedTrackState";
static NSString * const SlateValidationObservedStateKeyHasObservedChapterState = @"hasObservedChapterState";
static NSString * const SlateValidationObservedStateKeyObservedMoviePath = @"observedMoviePath";
static NSString * const SlateValidationObservedStateKeyObservedMovieDisplayName = @"observedMovieDisplayName";
static NSString * const SlateValidationObservedStateKeyObservedMovieNaturalWidth = @"observedMovieNaturalWidth";
static NSString * const SlateValidationObservedStateKeyObservedMovieNaturalHeight = @"observedMovieNaturalHeight";
static NSString * const SlateValidationObservedStateKeyObservedFrameRate = @"observedFrameRate";
static NSString * const SlateValidationObservedStateKeyObservedVideoTrackCount = @"observedVideoTrackCount";
static NSString * const SlateValidationObservedStateKeyObservedAudioTrackCount = @"observedAudioTrackCount";
static NSString * const SlateValidationObservedStateKeyObservedTextTrackCount = @"observedTextTrackCount";
static NSString * const SlateValidationObservedStateKeyObservedMovieTextTrackCount = @"observedMovieTextTrackCount";
static NSString * const SlateValidationObservedStateKeyObservedPlaybackOnlyTextTrackCount = @"observedPlaybackOnlyTextTrackCount";
static NSString * const SlateValidationObservedStateKeyObservedTextTrackSourcePaths = @"observedTextTrackSourcePaths";
static NSString * const SlateValidationObservedStateKeyObservedChapterRowCount = @"observedChapterRowCount";
static NSString * const SlateValidationObservedStateKeyObservedTrackRows = @"observedTrackRows";
static NSString * const SlateValidationObservedStateKeyObservedAssetTypeID = @"observedAssetTypeID";
static NSString * const SlateValidationObservedStateKeyHasObservedTimelineState = @"hasObservedTimelineState";
static NSString * const SlateValidationObservedStateKeyObservedTimelineCurrentTime = @"observedTimelineCurrentTime";
static NSString * const SlateValidationObservedStateKeyObservedTimelineDuration = @"observedTimelineDuration";
static NSString * const SlateValidationObservedStateKeyObservedTimelineSelectionStart = @"observedTimelineSelectionStart";
static NSString * const SlateValidationObservedStateKeyObservedTimelineSelectionEnd = @"observedTimelineSelectionEnd";
static NSString * const SlateValidationObservedStateKeyObservedMovieCurrentTimeValue = @"observedMovieCurrentTimeValue";
static NSString * const SlateValidationObservedStateKeyObservedMovieDurationTimeValue = @"observedMovieDurationTimeValue";
static NSString * const SlateValidationObservedStateKeyObservedMovieTimeScale = @"observedMovieTimeScale";
static NSString * const SlateValidationObservedStateKeyObservedChapterRows = @"observedChapterRows";

#endif
