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

// Returns cues active on [begin, end) in displayItems order. Each returned cue is a
// copy with line endings normalized and may include `regionDefinition` when
// its TTML region reference resolves against the supplied inventory. The
// cue keys and optional text-run/layout metadata are defined by
// SMSubtitleParsing.h and SMSubtitleTTMLLayoutContract.h.
NSArray *SMSyntheticSidecarDisplayItemsAtTime(NSArray *displayItems,
                                              NSDictionary *ttmlLayoutInventory,
                                              SMTime time);

typedef NS_ENUM(NSInteger, SMSubtitleBlockAlignment) {
    SMSubtitleBlockAlignmentBefore = 0,
    SMSubtitleBlockAlignmentCenter = 1,
    SMSubtitleBlockAlignmentAfter = 2
};

typedef struct {
    NSRect regionRect;
    NSRect contentRect;
    BOOL overflowVisible;
    NSInteger columnProgression; // 0 for horizontal lines, -1 for leftward columns, +1 for rightward.
    NSTextAlignment textAlignment;
    SMSubtitleBlockAlignment blockAlignment;
} SMSubtitleTTMLGeometry;

// Both rectangles use the supplied video rectangle's coordinate system.
// Returns NO with empty boxes and centered alignment for fallback placement.
BOOL SMSubtitleTTMLResolveDisplayItem(NSDictionary *displayItem, NSRect video, BOOL flipped,
                                      SMSubtitleTTMLGeometry *geometry);

@interface SMSubtitleBackgroundFill : NSObject
- (void)drawInContext:(CGContextRef)context;
@end

// Returns nil for display items outside the TTML text contract.
NSAttributedString *SMSubtitleTTMLText(NSDictionary *item, NSSize videoSize, SMSubtitleTTMLGeometry geometry);

// Shapes the complete block at its final inline extent, before the view clips it.
@interface SMSubtitleTextLayout : NSObject
- (instancetype)initWithText:(NSAttributedString *)text contentSize:(NSSize)size;
@property (nonatomic, readonly) CGFloat blockExtent;
- (NSRect)blockInFlippedRect:(NSRect)content alignment:(SMSubtitleBlockAlignment)alignment;
- (void)drawInFlippedContext:(CGContextRef)context;
@end

typedef NS_ENUM(NSUInteger, SMSubtitleRenderMode) {
    SMSubtitleRenderModeTextField,
    SMSubtitleRenderModeMeasured,
    SMSubtitleRenderModeCEA608,
};

@interface SMSubtitleRenderEntry : NSObject
@property (nonatomic, readonly) NSString *key;
@property (nonatomic, readonly) NSAttributedString *text;
@property (nonatomic, readonly) NSRect contentRect;
@property (nonatomic, readonly) NSRect clipRect;
@property (nonatomic, readonly) SMSubtitleRenderMode mode;
@property (nonatomic, readonly) SMSubtitleBlockAlignment blockAlignment;
@property (nonatomic, readonly) CGFloat captionFontSize;
@end

// Applies the same AppKit cell settings for measurement and drawing.
void SMConfigureSubtitleTextFieldCell(NSTextFieldCell *cell, SMSubtitleRenderEntry *entry);

// All rectangles and background fills use the supplied video's coordinates.
@interface SMSubtitleOverlayComposition : NSObject
- (instancetype)initWithVideoRect:(NSRect)videoRect flipped:(BOOL)flipped;
- (void)addActiveItems:(NSArray<NSDictionary *> *)items forSidecarID:(NSUInteger)sidecarID layoutInventory:(NSDictionary *)inventory;
@property (nonatomic, readonly) NSArray<SMSubtitleRenderEntry *> *entries;
@property (nonatomic, readonly) NSArray<SMSubtitleBackgroundFill *> *backgroundFills;
@end

SMSubtitleOverlayComposition *SMComposeSubtitleOverlay(NSArray<SMTrack *> *sidecars, SMTime time,
                                                       NSRect videoRect, BOOL flipped,
                                                       BOOL showSubtitles, BOOL showClosedCaptions);

// Use one cache for the current movie. Returns YES when the overlay needs to
// apply a new composition.
@interface SMSubtitleOverlayCache : NSObject
@property (nonatomic, readonly) SMSubtitleOverlayComposition *composition;
- (BOOL)updateWithSidecars:(NSArray<SMTrack *> *)sidecars time:(SMTime)time
                videoRect:(NSRect)videoRect flipped:(BOOL)flipped
            showSubtitles:(BOOL)showSubtitles showClosedCaptions:(BOOL)showClosedCaptions;
@end
