//
//  SMSubtitleSupport.h
//  Slate
//
//  Created by Jerry Hale on 3/21/26.
//  Copyright (c) 2026 Jerry Hale. All rights reserved.
//
//  Proprietary and confidential.
//  This file is part of Slate and is not open source software.
//
//  No license is granted to copy, modify, distribute, sublicense, or use this
//  source code except under a written agreement with the copyright holder.
//  Unauthorized use, disclosure, reproduction, or distribution is prohibited.
//

#import "Movie/SMMovie.h"

// Synthetic sidecar display runtime helpers.
//
// Controller entry points that reach this layer:
// TrackViewController
// - importITTSubtitleFromURL:
// - importTTMLSubtitleFromURL:
// - importSRTSubtitleFromURL:
// - importSCCSubtitleFromURL:
// - reloadData
//
// AppController
// - movieHasSidecarTracksOfMediaType:
// - hasEnabledSidecarTracksOfMediaType:
// - setEnabled:forSidecarTracksOfMediaType:
//
// Controllers still talk to SMMovie / SMTrack. This support layer owns the
// descriptors used to build synthetic sidecar display rows.

// Reached indirectly from controller import wrappers and subtitle-row reloads through SMMovie.
NSDictionary *SMSyntheticSidecarDisplayTrackRepresentationFromDescriptor(NSDictionary *descriptor, SMTime fallbackDuration);

// Reached indirectly when controller-visible subtitle tracks are rendered/queried by time.
NSString *SMSyntheticSidecarDisplayTextAtTime(NSArray *displayItems, SMTime time);
