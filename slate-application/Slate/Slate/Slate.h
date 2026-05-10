//
//  Slate.h
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

#ifndef Slate_h
#define Slate_h

#import <Cocoa/Cocoa.h>

// Movie adapter surface.
#import "Movie/SMMovie.h"
#import "Movie/SMMovieMetadataSupport.h"
#import "Movie/SMMoviePlaybackSupport.h"

// Media adapter support.
#import "MediaSupport/SMAssetTrackSupport.h"
#import "MediaSupport/SMCropGeometry.h"
#import "MediaSupport/SMCropDetector.h"
#import "MediaSupport/SMMediaTimeSupport.h"
#import "MediaSupport/SMTimecodeSupport.h"

// Subtitle adapter support.
#import "Subtitle/SMSubtitleParsing.h"
#import "Subtitle/SMSubtitleSupport.h"

// Timeline adapter surface.
#import "Timeline/TimelineGeometry.h"
#import "Timeline/TimelineRenderer.h"
#import "Timeline/TimelineReadouts.h"
#import "Timeline/TimelineController.h"

#endif /* Slate_h */
