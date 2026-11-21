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
#import "SMSubtitleTTMLLayoutContract.h"

// Shared normalized subtitle cue contract. `begin` and `end` are nonnegative
// integer milliseconds describing the half-open active interval [begin, end);
// `line` uses LF (`\n`) line endings. TTML cues may also carry
// regionID/regionResolved. Timed spans split paragraph text into cue
// intervals. `textRuns` is reserved for safe inline
// formatting such as SRT bold, italic, and underline; each run has `text` and
// optional boolean traits. `line` remains the plain-text projection of runs.
static NSString * const SMSubtitleCueKeyLine = @"line";
static NSString * const SMSubtitleCueKeyBegin = @"begin";
static NSString * const SMSubtitleCueKeyEnd = @"end";
static NSString * const SMSubtitleCueKeyTextRuns = @"textRuns";
static NSString * const SMSubtitleTextRunKeyText = @"text";
static NSString * const SMSubtitleTextRunKeyBold = @"bold";
static NSString * const SMSubtitleTextRunKeyItalic = @"italic";
static NSString * const SMSubtitleTextRunKeyUnderline = @"underline";

typedef long long SMSubtitleMilliseconds;

// Parser diagnostics describe rejected cues and fatal parse failures. Fatal
// failures are also returned as NSError; recoverable warnings accompany the
// valid cues that remain.
static NSString * const SMSubtitleDiagnosticKeySeverity = @"severity";
static NSString * const SMSubtitleDiagnosticKeySourceLine = @"sourceLine";
static NSString * const SMSubtitleDiagnosticKeyCueIndex = @"cueIndex";
static NSString * const SMSubtitleDiagnosticKeyMessage = @"message";
static NSString * const SMSubtitleDiagnosticSeverityWarning = @"warning";
static NSString * const SMSubtitleDiagnosticSeverityFatal = @"fatal";
static NSString * const SMSubtitleErrorKeyDiagnostic = @"SMSubtitleDiagnostic";
static NSString * const SMSubtitleErrorKeyDiagnostics = @"SMSubtitleDiagnostics";
NSError *SMSubtitleFatalParsingError(NSInteger code, NSString *description, NSError *underlyingError);

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
// XML element names are matched by local name, independent of namespace
// prefixes. ITT paragraphs require explicit begin/end times; the first body
// div begin supplies the common timeline offset. The document frame rate
// defaults to 25 and may be adjusted by ttp:frameRateMultiplier.
BOOL SMMillisecondsForITTTimestamp(NSString *timestamp,
                                   double frameDurationInMilliseconds,
                                   SMSubtitleMilliseconds *outMilliseconds);
NSArray *SMSerializedSubtitleItemsFromITTDocument(NSXMLDocument *xmlDoc,
                                                  short *outLanguageCode,
                                                  NSError **outError,
                                                  NSArray **outDiagnostics);

// TTML parsing path, reached from TrackViewController -importTTMLSubtitleFromURL:.
// XML element names are matched by local name, independent of namespace
// prefixes. Clock, frame-clock, and offset expressions use the document's
// frameRate, frameRateMultiplier, and tickRate parameters. body/div/p begin,
// end, and dur intervals inherit through their parents; nested timed spans and
// breaks contribute to the resulting cue intervals. Parent and known media
// ends bound descendant timing. A negative media duration means unknown.
// Unsupported timeContainer values and invalid TTML timing parameters are
// reported through outError.
NSArray *SMSerializedSubtitleItemsFromTTMLDocument(NSXMLDocument *xmlDoc,
                                                   short *outLanguageCode,
                                                   SMSubtitleMilliseconds mediaDurationMilliseconds,
                                                   NSError **outError,
                                                   NSArray **outDiagnostics);
// Returns ttmlLayoutInventory.v1 when an ITT/TTML head/layout is present; otherwise nil.
NSDictionary *SMSerializedTTMLLayoutInventoryFromDocument(NSXMLDocument *xmlDoc);
// Returns the first matching declaration, preserving the inventory's source order.
NSDictionary *SMSubtitleTTMLRegionDefinitionForID(NSString *regionID, NSDictionary *inventory);

// SRT timestamps require numeric HH:MM:SS fractions (comma or period; one to
// three fractional digits), with minutes/seconds in range. Cue intervals are
// clipped to the media duration when it is known: cues extending past the end
// are shortened, and cues beginning at/after the end are skipped with a
// warning. A negative media duration means unknown.
// Recognized <b>/<i>/<u> markup is represented as text-run traits, not HTML;
// malformed tag-like text and literal angle text remain ordinary text.
// Malformed cues produce warnings while valid neighboring cues are retained;
// a document with no valid in-range cues returns a fatal NSError.
// SRT parsing path, reached from TrackViewController -importSRTSubtitleFromURL:.
BOOL SMMillisecondsForSRTTimestamp(NSString *timestamp, SMSubtitleMilliseconds *outMilliseconds);
NSArray *SMSerializedSubtitleItemsFromSRTString(NSString *contents,
                                                SMSubtitleMilliseconds mediaDurationMilliseconds,
                                                NSError **outError,
                                                NSArray **outDiagnostics);

// SCC timecodes identify 30-frame addresses at 1000/1001 seconds per frame;
// `:` denotes non-drop and `;` denotes drop-frame addressing. Each 16-bit word
// in a record advances one frame. Channels are numbered 1 through 4.
// SCC parsing path, reached from TrackViewController -importSCCSubtitleFromURL:.
BOOL SMMillisecondsForSCCTimestamp(NSString *timestamp, SMSubtitleMilliseconds *outMilliseconds);

// Ordered CEA-608 events decoded from Scenarist SCC records. Each event stores
// time (milliseconds), type, parity-stripped firstByte/secondByte, sourceLine,
// and the active channel.
static NSString * const SMSubtitleSCCEventKeyTime = @"time";
static NSString * const SMSubtitleSCCEventKeyType = @"type";
static NSString * const SMSubtitleSCCEventKeyFirstByte = @"firstByte";
static NSString * const SMSubtitleSCCEventKeySecondByte = @"secondByte";
static NSString * const SMSubtitleSCCEventKeyChannel = @"channel";
static NSString * const SMSubtitleSCCEventKeySourceLine = @"sourceLine";
static NSString * const SMSubtitleSCCCueKeyRow = @"cea608Row";
static NSString * const SMSubtitleSCCCueKeyColumn = @"cea608Column";
static NSString * const SMSubtitleSCCCueKeyGridRows = @"cea608GridRows";
static NSString * const SMSubtitleSCCCueKeyGridColumns = @"cea608GridColumns";
// Numeric channel attached to each synthetic SCC sidecar track descriptor.
static NSString * const SMSubtitleSCCTrackDescriptorKeyChannel = @"subtitleChannel";
static NSString * const SMSubtitleSCCEventTypeCharacter = @"character";
static NSString * const SMSubtitleSCCEventTypeControl = @"control";
static NSString * const SMSubtitleSCCEventTypeSpecialCharacter = @"specialCharacter";
static NSString * const SMSubtitleSCCEventTypeExtendedCharacter = @"extendedCharacter";
static NSString * const SMSubtitleSCCEventTypePadding = @"padding";
static NSString * const SMSubtitleSCCDiagnosticKeyLine = SMSubtitleDiagnosticKeySourceLine;
static NSString * const SMSubtitleSCCDiagnosticKeyMessage = SMSubtitleDiagnosticKeyMessage;

NSArray *SMDecodedSCCEventsFromString(NSString *contents, NSArray **outDiagnostics);
// Returns a numeric-channel-keyed dictionary whose values are time-ordered
// cue arrays. Cues retain CEA-608 row/column and grid-size metadata for display.
NSDictionary *SMSubtitleSCCCueItemsByChannelFromString(NSString *contents,
                                                       SMSubtitleMilliseconds mediaDurationMilliseconds,
                                                       NSArray **outDiagnostics);
