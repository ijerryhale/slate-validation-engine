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

// Fresh TTML/iTT imports use one JSON-serializable descriptor. displayItems
// contains line, begin/end (milliseconds), optional regionID/regionResolved,
// optional paragraphStyle, and optional textRuns. A run contains text and may
// carry runStyle. Paragraph and run dictionaries contain effective content
// properties keyed by TTML local name, including applicable initial values.
// TTML cue slices from the same paragraph share its one-based paragraphOrdinal
// in document order. It determines stacking order independently of cue timing.
// The importer resolves named references and content inheritance before
// emission. Relative lengths retain their units for playback measurement.
// Paragraph and span styles with enclosing backgrounds carry the ordered
// ancestorBackgrounds color strings for compositing beneath their own paint.
// A run in a bidi scope carries its ordered enclosing scopes so playback can
// shape nested embeddings, overrides and isolates while preserving cue text.
//
// ttmlLayoutInventory has schemaVersion, regions in declaration order, and an
// optional document dictionary. Document keys are the authored parameter names
// profile, cellResolution, and root styling extent. Absence means unspecified.
// Region dictionaries preserve declaration order, id and ordered styleRefs.
// Referenced, nested and inline styles are merged on each region. Active cues may include document and regionDefinition.
// None of these dictionaries contains XML nodes, fonts, colors, or view objects.

static NSString * const SMSubtitleTTMLDocumentKey = @"document";
static NSString * const SMSubtitleTTMLStyleRefsKey = @"styleRefs";
static NSString * const SMSubtitleTTMLParagraphStyleKey = @"paragraphStyle";
static NSString * const SMSubtitleTTMLRunStyleKey = @"runStyle";

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
static NSString * const SMSubtitleTTMLCueKeyParagraphOrdinal = @"paragraphOrdinal";

#endif
