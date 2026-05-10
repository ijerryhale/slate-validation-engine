//
//  SMMovieMetadataSupport.h
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

#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>

NSString *SMTrackDisplayNameFromMetadata(AVAssetTrack *assetTrack);
void SMSetTrackDisplayNameMetadata(AVMutableMovieTrack *track, NSString *value);
NSString *SMSerializedEditedChannelLayoutFromMetadata(AVAssetTrack *assetTrack);
void SMSetSerializedEditedChannelLayoutMetadata(AVMutableMovieTrack *track, NSString *value);
NSNumber *SMTrackGainFromMetadata(AVAssetTrack *assetTrack);
void SMSetTrackGainMetadata(AVMutableMovieTrack *track, NSNumber *value);
NSNumber *SMMovieGainFromMetadata(AVMutableMovie *movie);
void SMSetMovieGainMetadata(AVMutableMovie *movie, NSNumber *value);
float SMEffectiveMovieGain(NSMutableDictionary *movieAttributes, AVMutableMovie *movie);
