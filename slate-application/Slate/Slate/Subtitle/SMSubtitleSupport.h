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
#import "SMSubtitleParsing.h"

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

// Returns every active cue in source order. Each returned cue is a copy with
// line endings normalized and may include `regionDefinition` when its TTML
// region reference resolves against the supplied inventory.
NSArray *SMSyntheticSidecarDisplayItemsAtTime(NSArray *displayItems,
                                              NSDictionary *ttmlLayoutInventory,
                                              SMTime time);

typedef NS_ENUM(NSInteger, SMSubtitleVerticalAlignment) {
    SMSubtitleVerticalAlignmentBefore = 0,
    SMSubtitleVerticalAlignmentCenter = 1,
    SMSubtitleVerticalAlignmentAfter = 2
};

// Resolves percentage-only TTML region geometry into a normalized rectangle
// whose origin is top-left. Returns NO for absent, malformed, unsupported, or
// unresolved geometry. Alignment outputs default to centered when geometry
// cannot be used.
BOOL SMSubtitleTTMLResolveDisplayItem(NSDictionary *displayItem,
                                     NSRect *normalizedRect,
                                     NSTextAlignment *textAlignment,
                                     SMSubtitleVerticalAlignment *verticalAlignment);
