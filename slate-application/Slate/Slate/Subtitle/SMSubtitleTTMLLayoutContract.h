//
//  SMSubtitleTTMLLayoutContract.h
//  Slate
//
//  Copyright (c) 2026 Jerry Hale. All rights reserved.
//
//  Proprietary and confidential. This file is part of Slate and is not open
//  source software. No license is granted to copy, modify, distribute,
//  sublicense, or use this source code except under a written agreement with
//  the copyright holder. Unauthorized use, disclosure, reproduction, or
//  distribution is prohibited.
//

#ifndef SLATE_SMSUBTITLETTMLLAYOUTCONTRACT_H
#define SLATE_SMSUBTITLETTMLLAYOUTCONTRACT_H

#import <Foundation/Foundation.h>

// TTML and ITT sidecar descriptor payload contract. Existing displayItems
// remain an array of cue dictionaries with line, begin, and end. Cues may also
// have regionID and regionResolved when the nearest explicit region on <p>,
// <div>, or <body> names a region. A <p> reference overrides its ancestors.
// regionID is the source reference, not a resolved region object;
// regionResolved reports whether that ID matches a declaration in the
// document's inventory. Both fields are absent when none of those elements
// has a region attribute. The track descriptor may carry a separate
// ttmlLayoutInventory:
//
// {
//   "displayItems": [
//     {"line": "Hello", "begin": 0, "end": 1200,
//      "regionID": "lower", "regionResolved": true}
//   ],
//   "ttmlLayoutInventory": {
//     "schemaVersion": "ttmlLayoutInventory.v1",
//     "regions": [
//       {
//         "id": "lower",
//         "origin": "10% 75%",
//         "extent": "80% 20%",
//         "displayAlign": "after",
//         "textAlign": "center"
//       }
//     ]
//   }
// }
//
// Region geometry and alignment values are the source XML attribute strings.
// Consumers must not assume that units have been converted or normalized.
// The active-cue projection may add a resolved regionDefinition to a returned
// cue copy; it does not mutate displayItems or the source inventory.
// A region dictionary includes id when the source declares xml:id; it may omit
// id if the source region has none. Optional region properties are omitted
// when absent. Region declarations retain document order, including repeated
// IDs. A cue without regionID has no explicit region reference; this contract
// does not synthesize a default region or define rendering behavior.

static NSString * const SMSubtitleTTMLLayoutInventoryDescriptorKey = @"ttmlLayoutInventory";
static NSString * const SMSubtitleTTMLLayoutInventorySchemaVersion1 = @"ttmlLayoutInventory.v1";

static NSString * const SMSubtitleTTMLLayoutInventoryKeySchemaVersion = @"schemaVersion";
static NSString * const SMSubtitleTTMLLayoutInventoryKeyRegions = @"regions";

static NSString * const SMSubtitleTTMLRegionKeyID = @"id";
static NSString * const SMSubtitleTTMLRegionKeyOrigin = @"origin";
static NSString * const SMSubtitleTTMLRegionKeyExtent = @"extent";
static NSString * const SMSubtitleTTMLRegionKeyDisplayAlign = @"displayAlign";
static NSString * const SMSubtitleTTMLRegionKeyTextAlign = @"textAlign";

static NSString * const SMSubtitleTTMLCueKeyRegionID = @"regionID";
static NSString * const SMSubtitleTTMLCueKeyRegionResolved = @"regionResolved";
static NSString * const SMSubtitleTTMLCueKeyRegionDefinition = @"regionDefinition";

#endif
