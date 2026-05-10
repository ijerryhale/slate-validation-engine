//
//  SMAssetTrackSupport.h
//  Slate
//
//  Created by Jerry Hale on 3/27/26.
//  Copyright (c) 2026 Jerry Hale. All rights reserved.
//
//  Proprietary and confidential.
//  This file is part of Slate and is not open source software.
//
//  No license is granted to copy, modify, distribute, sublicense, or use this
//  source code except under a written agreement with the copyright holder.
//  Unauthorized use, disclosure, reproduction, or distribution is prohibited.
//

#import <AVFoundation/AVFoundation.h>

@class SMTrack;

AVMutableMovieTrack *MutableMovieTrackFromSMTrack(SMTrack *qtTrack);
NSNumber *SMLanguageNumberFromAssetLanguageCode(NSString *languageCode);
NSString *AssetLanguageCodeFromQTLanguageNumber(NSNumber *languageNumber);
NSString *SMDisplayNameFromAssetTrack(AVAssetTrack *track);
NSString *SMFormatSummaryFromAssetTrack(AVAssetTrack *track);
AVAssetTrack *AssetTrackMatchingTrackID(AVAsset *asset, CMPersistentTrackID trackID, AVMediaType mediaType);
CMTimeRange SMPlayableTimeRangeForAssetTrack(AVAssetTrack *track);
