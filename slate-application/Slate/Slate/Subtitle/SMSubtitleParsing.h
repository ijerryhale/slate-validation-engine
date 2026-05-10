//
//  SMSubtitleParsing.h
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

#import <Cocoa/Cocoa.h>

// Pure subtitle-file parsing helpers for synthetic sidecar display.
//
// Controller entry points that reach this layer:
// TrackViewController
// - importITTSubtitleFromURL:
// - importTTMLSubtitleFromURL:
// - importSRTSubtitleFromURL:
// - importSCCSubtitleFromURL:
//
// Those controller wrappers call SMMovie's addSidecar...SubtitleTrackFromURL: methods,
// which use these helpers to normalize ITT/TTML/SRT/SCC content into cue payload arrays.

// ITT parsing path, reached from TrackViewController -importITTSubtitleFromURL:.
unsigned SMMillisecondsForITTTimestamp(NSString *timestamp, NSUInteger frameRateMultiplier, float frameDurationInMilliseconds);
NSArray *SMChildStringsForXMLNode(NSXMLNode *node);
NSArray *SMSerializedSubtitleItemsFromITTDocument(NSXMLDocument *xmlDoc, short *outLanguageCode);

// TTML parsing path, reached from TrackViewController -importTTMLSubtitleFromURL:.
NSArray *SMSerializedSubtitleItemsFromTTMLDocument(NSXMLDocument *xmlDoc, short *outLanguageCode);

// SRT parsing path, reached from TrackViewController -importSRTSubtitleFromURL:.
unsigned SMMillisecondsForSRTTimestamp(NSString *timestamp);
NSArray *SMSerializedSubtitleItemsFromSRTString(NSString *contents);

// SCC parsing path, reached from TrackViewController -importSCCSubtitleFromURL:.
unsigned SMMillisecondsForSCCTimestamp(NSString *timestamp);
NSString *SMDecodedTextForSCCPayload(NSString *payload);
NSArray *SMSerializedSubtitleItemsFromSCCString(NSString *contents);
