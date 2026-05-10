//
//  TrackViewController.m
//  Slate
//
//  Created by Jerry Hale on 3/20/26
//  Copyright (c) 2026 Jerry Hale All rights reserved.

#import "rational.h"

#import "SBLanguages.h"
#import "DictionaryKeys.h"


#import "PlayerView.h"
#import "AppController+Private.h"
#import "AppController+Validation.h"
#import "Movie/SMMoviePlaybackSupport.h"
#import "Runtime/SlatePackageContextContract.h"
#import "Runtime/SlateRuntimeBridge.h"
#import "Runtime/SlateReviewSnapshotContract.h"
#import "Runtime/SlateTrackSnapshotContract.h"
#import "Validation/SMValidationCanonicalDictionaryKeys.h"
#import "Validation/SMValidationFindingCodes.h"

#import "TrackViewController.h"
#import "UtilLayoutMetrics.h"
#import "UtilInspectorRailContract.h"
#import "UtilReadinessRailPresenter.h"
#import "CheckBoxTableColumn.h"
#import "VertCenterTextFieldCell.h"

extern NSString * const SMTrackLanguageAttribute;

#pragma mark - Audio and Validation Helpers

// Track owns UI snapshots; movie mutation is fenced below in the command surface.
typedef NS_ENUM(NSInteger, SMTrackCommandLanguageTarget) {
    SMTrackCommandLanguageTargetAudio = 0,
    SMTrackCommandLanguageTargetVideo = 1
};

static BOOL SMIsChannelStyleTrackLabel(NSString *label)
{
    if (label.length == 0) {
        return NO;
    }

    static NSSet *channelStyleLabels = nil;
    if (channelStyleLabels == nil) {
        channelStyleLabels = [[NSSet alloc] initWithObjects:
                              @"MONO", @"L", @"R", @"C", @"LFE", @"LS", @"RS", @"LT", @"RT", @"CS",
                              nil];
    }

    NSString *normalizedLabel = [[label stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
    if ([channelStyleLabels containsObject:normalizedLabel]) {
        return YES;
    }

    return [normalizedLabel hasPrefix:@"CH"];
}

static NSString *SMTrackTypeLabelForTrack(SMTrack *track)
{
    NSString *mediaType = [track attributeForKey:SMTrackMediaTypeAttribute];

    if ([mediaType isEqualToString:SMMediaTypeVideo]) {
        return @"Video";
    }
    if ([mediaType isEqualToString:SMMediaTypeSound]) {
        return @"Audio";
    }
    if ([mediaType isEqualToString:SMMediaTypeSubtitle]) {
        return @"Subtitle";
    }
    if ([mediaType isEqualToString:SMMediaTypeClosedCaption]) {
        return @"Closed Caption";
    }
    if ([mediaType isEqualToString:SMMediaTypeText]) {
        return @"Text";
    }
    if ([mediaType isEqualToString:SMMediaTypeTimeCode]) {
        return @"Timecode";
    }

    return mediaType ?: @"";
}

static BOOL SMTrackLanguageIsUnknown(NSString *language);

static BOOL SMTrackStringHasContent(NSString *value)
{
    if (![value isKindOfClass:[NSString class]]) {
        return NO;
    }

    return [[value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] > 0;
}

static NSDictionary *SMTrackCanonicalFindingWithCode(NSArray *findings, NSString *code)
{
    for (NSDictionary *finding in findings) {
        if (![finding isKindOfClass:[NSDictionary class]]) {
            continue;
        }

        NSString *findingCode = [finding objectForKey:SMValidationFindingKeyCode];
        if (SMTrackStringHasContent(code) && [findingCode isEqualToString:code]) {
            return finding;
        }
    }

    return nil;
}

static SMMovie *SMTrackCurrentMovieFromAppController(void)
{
    AppController *appController = appcontroller();
    if (appController == nil) {
        return nil;
    }

    return [appController movie];
}

static BOOL SMTrackCodeContainsToken(NSString *code, NSString *token)
{
    return (SMTrackStringHasContent(code)
            && SMTrackStringHasContent(token)
            && [code rangeOfString:token].location != NSNotFound);
}

typedef NS_ENUM(NSInteger, SMWorkspaceWidthClass) {
    SMWorkspaceWidthClass0 = 0,
    SMWorkspaceWidthClass1 = 1,
    SMWorkspaceWidthClass2 = 2,
};

#pragma mark - Layout Constants

static const CGFloat SMTrackWorkspaceWideBreakpoint = 1280.0;
static const CGFloat SMTrackWorkspaceMediumBreakpoint = 1107.0;
static const CGFloat SMTrackWorkspaceCompactBlendEndWidth = 1040.0;

static const CGFloat SMTrackDynamicInspectorInset = 8.0;
static const CGFloat SMTrackDynamicGainLabelWidth = 32.0;
static const CGFloat SMTrackDynamicGainLabelFrameWidthDelta = 20.0;
static const CGFloat SMTrackDynamicGainLabelFrameLeftShift = 18.0;
static const CGFloat SMTrackDynamicGainSliderYOffset = 24.0;
static const CGFloat SMTrackDynamicGainSliderMinWidth = 120.0;
static const CGFloat SMTrackDynamicGainSliderMaxWidth = 188.0;
static const CGFloat SMTrackDynamicGainTickLabelWidth = 26.0;
static const CGFloat SMTrackDynamicGainMinLabelXOffset = -2.0;
static const CGFloat SMTrackDynamicGainMaxLabelRightTrim = 24.0;
static const CGFloat SMTrackDynamicGainTickLabelY = 8.0;
static const CGFloat SMTrackDynamicGainTickLabelHeight = 12.0;
static const CGFloat SMTrackDynamicGainLabelHeight = 14.0;
static const CGFloat SMTrackDynamicGainSliderHeight = 18.0;
static const CGFloat SMTrackDynamicGainContentHeight = 44.0;
static const CGFloat SMTrackDynamicTrackGainBlockWidth = 230.0;
static const CGFloat SMTrackDynamicGainClusterDropY = -4.0;
static const CGFloat SMTrackDynamicDetailsBottomGap = 10.0;
static const CGFloat SMTrackDynamicDetailsPanelDropY = 9.0;
static const CGFloat SMTrackDynamicDetailsChapterPreviewRailPadding = 8.0;
static const CGFloat SMTrackDynamicDetailsChapterPreviewRowHeight = 16.0;
static const CGFloat SMTrackDynamicDetailsChapterPreviewRowGap = 4.0;
static const CGFloat SMTrackDynamicDetailsFixedWidth = 296.0;
static const CGFloat SMTrackDynamicDetailsFixedHeightReferenceWidth = 256.0;

static const CGFloat SMTrackRailGutter = 14.0;
static const CGFloat SMTrackIDColumnFixedWidth = 28.0;            // "99" + 3px left/right padding
static const CGFloat SMTrackEnabledColumnFixedWidth = 60.0;       // "Enabled" + 3px left/right padding
static const CGFloat SMTrackTypeColumnFixedWidth = 124.0;         // "Closed Caption" rounded up + padding
static const CGFloat SMTrackDurationColumnFixedWidth = 78.0;      // "12:00:00:00" + 3px left/right padding
static const CGFloat SMTrackLanguageInfoSharedWidth = 217.0;      // (74.5 + 359.5) / 2
static const CGFloat SMTrackFlexibleColumnMinimumWidth = 1.0;
static const CGFloat SMTrackTableMinimumWidthWide = 520.0;
static const CGFloat SMTrackTableMinimumWidthCompact = 460.0;
static const CGFloat SMTrackReadinessTableMinimumWidthMedium = 420.0;
static const CGFloat SMTrackPinnedRelaxedTableMinimumWidth = 360.0;
static const CGFloat SMTrackPinnedRelaxWindowWidth = 120.0;
static const NSInteger SMTrackTableMaximumVisibleRows = 15;
static const CGFloat SMTrackTableRowHeight = 21.0;
static const CGFloat SMTrackTableIntercellVerticalSpacing = 3.0;
static const CGFloat SMTrackTableHeaderHeight = 34.0;
static const CGFloat SMTrackAdvancedGroupInsetX = 8.0;
static const CGFloat SMTrackAdvancedHeaderInsetX = 10.0;
static const CGFloat SMTrackAdvancedHeaderTopInset = 6.0;
static const CGFloat SMTrackMinimumInterColumnGap = 14.0;
static NSString * const SMTrackResizableColumnWidthsDefaultsKey = @"SMTrackResizableColumnWidths";
static NSString * const SMTrackReadinessSectionTitle = @"Readiness";
static NSString * const SMTrackReadinessStatusNoMovie = @"No movie loaded";
static NSString * const SMTrackReadinessStatusNoFindings = @"No track/role findings";
static NSString * const SMTrackReadinessEmptyMessageNoFindings = @"No track/role readiness findings.";
static NSString * const SMTrackReadinessFindingsToolTipTitle = @"Readiness findings (tracks + roles)";
static NSString * const SMTrackInspectorDetailsEmptyMessage = @"Select a track to inspect details.";
static const CGFloat SMTrackInspectorDetailsFontSize = 14.0;
static const CGFloat SMTrackInspectorCopyButtonSize = 16.0;
static const CGFloat SMTrackInspectorCopyButtonRightInset = 6.0;

static NSFont *SMTrackTableBodyFont(void)
{
    return [NSFont systemFontOfSize:12.0 weight:NSFontWeightRegular];
}

static NSFont *SMTrackTableHeaderFont(void)
{
    return [NSFont systemFontOfSize:16.0 weight:NSFontWeightSemibold];
}

static CGFloat SMTrackMaximumTableHeightForVisibleRows(void)
{
    CGFloat rowSlotHeight = SMTrackTableRowHeight + SMTrackTableIntercellVerticalSpacing;
    return SMTrackTableHeaderHeight + (rowSlotHeight * (CGFloat)SMTrackTableMaximumVisibleRows);
}

static CGFloat SMTrackFixedInspectorRailHeight(void)
{
    CGFloat designContentTopY = SlateWorkspacePrimaryPaneTableAnchorTopY()
        + SlateInspectorRailSectionHeaderHeight()
        + SlateInspectorRailSectionHeaderYOffset();
    return MAX(SlateWorkspaceMinimumContentHeight(), designContentTopY - SlateInspectorRailBottomInset());
}

static CGFloat SMTrackInspectorDetailsAlignedWidth(NSRect railBounds)
{
    #pragma unused(railBounds)
    return SMTrackDynamicDetailsFixedWidth;
}

static CGFloat SMTrackInspectorDetailsAlignedTopY(NSRect railBounds)
{
    #pragma unused(railBounds)
    CGFloat railPadding = SMTrackDynamicDetailsChapterPreviewRailPadding;
    CGFloat controlTopY = railPadding + SMTrackDynamicDetailsChapterPreviewRowHeight + 3.0;
    CGFloat previewBottomY = controlTopY + SMTrackDynamicDetailsChapterPreviewRowGap + 3.0 + SlateInspectorRailSectionGap();
    return previewBottomY + SMTrackDynamicDetailsFixedHeightReferenceWidth;
}

static NSFont *SMTrackInspectorMiniLabelFont(void)
{
    return [NSFont systemFontOfSize:12.0 weight:NSFontWeightRegular];
}

static NSImage *SMTrackInspectorCopyButtonImage(void)
{
    NSImage *image = nil;
    if ([NSImage respondsToSelector:@selector(imageWithSystemSymbolName:accessibilityDescription:)]) {
        image = [NSImage imageWithSystemSymbolName:@"doc.on.doc"
                            accessibilityDescription:@"Copy"];
    }
    if (image == nil) {
        image = [NSImage imageNamed:NSImageNameMultipleDocuments];
    }
    if (image != nil) {
        [image setTemplate:YES];
    }
    return image;
}

static SMWorkspaceWidthClass SMWorkspaceWidthClassForWidth(CGFloat workspaceWidth)
{
    if (workspaceWidth >= SMTrackWorkspaceWideBreakpoint) {
        return SMWorkspaceWidthClass2;
    }
    if (workspaceWidth >= SMTrackWorkspaceMediumBreakpoint) {
        return SMWorkspaceWidthClass1;
    }
    return SMWorkspaceWidthClass0;
}

#pragma mark - Layout Helpers

static CGFloat SMTrackCompactBlendForWidth(CGFloat workspaceWidth)
{
    const CGFloat blendStartWidth = SMTrackWorkspaceMediumBreakpoint;
    const CGFloat blendEndWidth = SMTrackWorkspaceCompactBlendEndWidth;
    if (workspaceWidth >= blendStartWidth) {
        return 0.0;
    }
    if (workspaceWidth <= blendEndWidth) {
        return 1.0;
    }
    return (blendStartWidth - workspaceWidth) / (blendStartWidth - blendEndWidth);
}

static CGFloat SMTrackLerp(CGFloat fromValue, CGFloat toValue, CGFloat t)
{
    CGFloat clamped = MIN(MAX(t, 0.0), 1.0);
    return fromValue + ((toValue - fromValue) * clamped);
}

static CGFloat SMTrackMinimumTableWidthForReadinessRail(CGFloat minimumTableWidth)
{
    // Match Chapter behavior: readiness eligibility is capped so class-2
    // doesn't hard-snap around ~1287 while still preserving fixed rail widths.
    return MIN(minimumTableWidth, SMTrackReadinessTableMinimumWidthMedium);
}

static BOOL SMTrackResolveInspectorAndReadinessRails(CGFloat workspaceWidthWithoutReadiness,
                                                     CGFloat workspaceWidthWithReadiness,
                                                     CGFloat minimumLayoutWidthForInspector,
                                                     BOOL preferReadinessRail,
                                                     BOOL *outShowReadinessRail,
                                                     CGFloat *outLayoutBandWidth)
{
    BOOL showReadinessRail = preferReadinessRail;
    CGFloat layoutBandWidth = showReadinessRail ? workspaceWidthWithReadiness : workspaceWidthWithoutReadiness;
    if (layoutBandWidth < minimumLayoutWidthForInspector && showReadinessRail) {
        showReadinessRail = NO;
        layoutBandWidth = workspaceWidthWithoutReadiness;
    }

    if (outShowReadinessRail != NULL) {
        *outShowReadinessRail = showReadinessRail;
    }
    if (outLayoutBandWidth != NULL) {
        *outLayoutBandWidth = layoutBandWidth;
    }

    return (layoutBandWidth >= minimumLayoutWidthForInspector);
}

typedef struct {
    BOOL showInspectorRail;
    BOOL showReadinessRail;
    NSRect tableFrame;
    NSRect inspectorFrame;
    NSRect readinessFrame;
} SMTrackFixedRailLayout;

static SMTrackFixedRailLayout SMTrackResolveFixedRailLayout(SMWorkspaceWidthClass widthClass,
                                                            BOOL inspectorRailPinned,
                                                            NSRect layoutBounds,
                                                            NSRect bandFrame,
                                                            CGFloat railBottomY,
                                                            CGFloat tableContentTopY,
                                                            CGFloat railContentTopY)
{
    CGFloat gutter = SMTrackRailGutter;
    CGFloat tableContentHeight = MAX(1.0, tableContentTopY - bandFrame.origin.y);
    CGFloat workspaceWidth = NSWidth(layoutBounds);
    CGFloat compactBlend = (widthClass == SMWorkspaceWidthClass2) ? 0.0 : SMTrackCompactBlendForWidth(workspaceWidth);
    CGFloat minimumTableWidth = SMTrackLerp(SMTrackTableMinimumWidthWide, SMTrackTableMinimumWidthCompact, compactBlend);
    CGFloat minimumTableWidthForRail = minimumTableWidth;
    CGFloat minimumTableWidthForReadinessRail = SMTrackMinimumTableWidthForReadinessRail(minimumTableWidth);
    CGFloat inspectorFixedWidth = SlateInspectorRailModeInspectorFixedWidth();
    CGFloat inspectorMinWidth = inspectorFixedWidth;
    CGFloat inspectorTargetWidth = inspectorFixedWidth;
    CGFloat readinessWidth = SlateInspectorRailFixedWidth();
    CGFloat readinessRightInset = SlateInspectorRailRightInset();
    CGFloat readinessBottomY = railBottomY;
    BOOL wantsReadinessRail = (widthClass != SMWorkspaceWidthClass0) || inspectorRailPinned;

    CGFloat readinessFrameX = NSMaxX(layoutBounds) - readinessRightInset - readinessWidth;
    CGFloat layoutWidthWithReadiness = readinessFrameX - gutter - bandFrame.origin.x;
    BOOL pinnedCanAffectLayout = inspectorRailPinned;
    BOOL readinessEligibleByWidth = pinnedCanAffectLayout || (NSWidth(layoutBounds) >= SlateInspectorRailTrackMinimumHostWidth());
    CGFloat strictMinimumLayoutWidthForInspector = minimumTableWidth + inspectorMinWidth + gutter;
    if (pinnedCanAffectLayout) {
        // Smoothly relax table minima in pinned mode to avoid hard snaps around
        // strict thresholds during 2 -> 1 and 1 -> 0 transitions.
        CGFloat relaxedTableMinimum = SMTrackPinnedRelaxedTableMinimumWidth;
        CGFloat relaxWindow = SMTrackPinnedRelaxWindowWidth;
        CGFloat relaxStart = strictMinimumLayoutWidthForInspector + relaxWindow;
        CGFloat relaxEnd = strictMinimumLayoutWidthForInspector - relaxWindow;
        CGFloat relaxBlend = 0.0;
        if (layoutWidthWithReadiness <= relaxEnd) {
            relaxBlend = 1.0;
        } else if (layoutWidthWithReadiness < relaxStart) {
            relaxBlend = (relaxStart - layoutWidthWithReadiness) / (relaxStart - relaxEnd);
        }
        minimumTableWidthForRail = SMTrackLerp(minimumTableWidthForRail, relaxedTableMinimum, relaxBlend);
        minimumTableWidthForReadinessRail = MIN(minimumTableWidthForReadinessRail, minimumTableWidthForRail);
    }

    CGFloat minimumLayoutWidthForInspector = minimumTableWidthForRail + inspectorMinWidth + gutter;
    CGFloat minimumLayoutWidthForReadinessRail = minimumTableWidthForReadinessRail + inspectorMinWidth + gutter;

    SMTrackFixedRailLayout layout;
    layout.showInspectorRail = NO;
    layout.showReadinessRail = NO;
    layout.tableFrame = NSMakeRect(bandFrame.origin.x,
                                   bandFrame.origin.y,
                                   MAX(0.0, bandFrame.size.width),
                                   tableContentHeight);
    layout.inspectorFrame = NSZeroRect;
    layout.readinessFrame = NSZeroRect;

    BOOL forceReadinessOnlyFromWideTightening = (widthClass == SMWorkspaceWidthClass2
                                                  && wantsReadinessRail
                                                  && (layoutWidthWithReadiness < minimumLayoutWidthForReadinessRail));
    if (forceReadinessOnlyFromWideTightening) {
        layout.showReadinessRail = YES;
        layout.tableFrame = NSMakeRect(bandFrame.origin.x,
                                       bandFrame.origin.y,
                                       MAX(0.0, readinessFrameX - gutter - bandFrame.origin.x),
                                       tableContentHeight);
        layout.readinessFrame = NSMakeRect(readinessFrameX,
                                           readinessBottomY,
                                           readinessWidth,
                                           MAX(SlateInspectorRailWarningBlockMinHeight(),
                                               railContentTopY - readinessBottomY));
        return layout;
    }

    BOOL preferReadinessRail = wantsReadinessRail
        && readinessEligibleByWidth
        && (layoutWidthWithReadiness >= minimumLayoutWidthForReadinessRail);
    BOOL showReadinessRail = NO;
    CGFloat layoutBandWidth = 0.0;
    BOOL showInspectorRail = SMTrackResolveInspectorAndReadinessRails(bandFrame.size.width,
                                                                      layoutWidthWithReadiness,
                                                                      minimumLayoutWidthForInspector,
                                                                      preferReadinessRail,
                                                                      &showReadinessRail,
                                                                      &layoutBandWidth);
    layout.showInspectorRail = showInspectorRail;
    layout.showReadinessRail = showReadinessRail;
    layout.tableFrame = NSMakeRect(bandFrame.origin.x,
                                   bandFrame.origin.y,
                                   MAX(0.0, layoutBandWidth),
                                   tableContentHeight);

    if (showInspectorRail) {
        CGFloat inspectorAvailableWidth = layoutBandWidth - minimumTableWidthForRail - gutter;
        CGFloat inspectorWidth = MIN(inspectorTargetWidth, inspectorAvailableWidth);
        inspectorWidth = MAX(inspectorMinWidth, inspectorWidth);
        CGFloat tableWidth = layoutBandWidth - inspectorWidth - gutter;
        tableWidth = MAX(minimumTableWidthForRail, tableWidth);

        layout.tableFrame.size.width = tableWidth;
        CGFloat inspectorHeight = SMTrackFixedInspectorRailHeight();
        layout.inspectorFrame = NSMakeRect(NSMaxX(layout.tableFrame) + gutter,
                                           railBottomY,
                                           inspectorWidth,
                                           inspectorHeight);
        // Keep short track lists bounded while rails absorb vertical headroom.
        layout.tableFrame.origin.y = railBottomY;
        layout.tableFrame.size.height = MAX(1.0, tableContentTopY - layout.tableFrame.origin.y);
        if (widthClass == SMWorkspaceWidthClass2) {
            CGFloat inset = MIN(SlateInspectorRailWideMiddleColumnInset(),
                                floor(MAX(0.0, layout.inspectorFrame.size.width - 120.0) * 0.5));
            if (inset > 0.0) {
                layout.inspectorFrame.origin.x += inset;
                layout.inspectorFrame.size.width -= (inset * 2.0);
            }
        }
        if (showReadinessRail) {
            CGFloat readinessHeight = MAX(SlateInspectorRailWarningBlockMinHeight(),
                                          railContentTopY - readinessBottomY);
            layout.readinessFrame = NSMakeRect(readinessFrameX,
                                               readinessBottomY,
                                               readinessWidth,
                                               readinessHeight);
        }
    }

    return layout;
}

static NSString * const SMTrackInspectorRailPinnedDefaultsKey = @"SMTrackInspectorRailPinned";
static NSString * const SMTrackDynamicSurfaceIdentifier = @"SMTrackDynamicInspectorSurface";

#pragma mark - Inspector Text Support

@interface SMTrackInspectorDetailsTextView : NSTextView
@end

@implementation SMTrackInspectorDetailsTextView

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (void)mouseDown:(NSEvent *)event
{
    [[self window] makeFirstResponder:self];
    [super mouseDown:event];
}

- (BOOL)performKeyEquivalent:(NSEvent *)event
{
    NSEventModifierFlags flags = (event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask);
    NSString *characters = [[event charactersIgnoringModifiers] lowercaseString];
    if (flags == NSEventModifierFlagCommand) {
        if ([characters isEqualToString:@"c"]) {
            NSRange selected = [self selectedRange];
            if (selected.length == 0 && [[self string] length] > 0) {
                [self setSelectedRange:NSMakeRange(0, [[self string] length])];
            }
            [self copy:nil];
            return YES;
        }
        if ([characters isEqualToString:@"a"]) {
            [self selectAll:nil];
            return YES;
        }
    }

    return [super performKeyEquivalent:event];
}

@end

static NSString *SMTrackDetailsSafeString(id value)
{
    if ([value isKindOfClass:[NSString class]]) {
        NSString *stringValue = (NSString *)value;
        return (stringValue.length > 0) ? stringValue : @"(none)";
    }
    if ([value respondsToSelector:@selector(stringValue)]) {
        NSString *stringValue = [value stringValue];
        return (stringValue.length > 0) ? stringValue : @"(none)";
    }
    return @"(none)";
}

static NSString *SlateTrackSnapshotRawString(id value)
{
    if ([value isKindOfClass:[NSString class]]) {
        return value;
    }
    if ([value respondsToSelector:@selector(stringValue)]) {
        return [value stringValue];
    }
    return @"";
}

static NSString *SlateTrackSnapshotRowString(NSDictionary *row, NSString *key)
{
    return SlateTrackSnapshotRawString([row objectForKey:key]);
}

static BOOL SlateTrackSnapshotRowBool(NSDictionary *row, NSString *key)
{
    id value = [row objectForKey:key];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO;
}

static NSInteger SlateTrackSnapshotRowInteger(NSDictionary *row, NSString *key)
{
    id value = [row objectForKey:key];
    return [value respondsToSelector:@selector(integerValue)] ? [value integerValue] : 0;
}

static void SMTrackAppendDetailsPair(NSMutableString *details, NSString *key, NSString *value)
{
    if (details == nil || key.length == 0) {
        return;
    }
    if ([details length] > 0 && ![details hasSuffix:@"\n"]) {
        [details appendString:@"\n"];
    }
    [details appendFormat:@"%@: %@", key, SMTrackDetailsSafeString(value)];
}

static NSDictionary *SMTrackDetailsPairDictionary(NSString *key, id value)
{
    if (key.length == 0) {
        return nil;
    }
    return [NSDictionary dictionaryWithObjectsAndKeys:
            key, SlateTrackSnapshotDetailKeyKey,
            SMTrackDetailsSafeString(value), SlateTrackSnapshotDetailKeyValue,
            nil];
}

static void SMTrackAppendDetailsPairToArray(NSMutableArray *pairs, NSString *key, id value)
{
    NSDictionary *pair = SMTrackDetailsPairDictionary(key, value);
    if (pair != nil) {
        [pairs addObject:pair];
    }
}

static NSString *SMTrackSizeDescription(CGFloat width, CGFloat height)
{
    if (width <= 0.0 || height <= 0.0) {
        return nil;
    }

    return [NSString stringWithFormat:@"%.0f x %.0f", width, height];
}

static NSAttributedString *SMTrackDetailsAttributedString(NSString *detailsText)
{
    NSString *resolvedText = (detailsText.length > 0) ? detailsText : SMTrackInspectorDetailsEmptyMessage;
    NSDictionary *baseAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont systemFontOfSize:SMTrackInspectorDetailsFontSize weight:NSFontWeightRegular], NSFontAttributeName,
                                    [NSColor secondaryLabelColor], NSForegroundColorAttributeName,
                                    nil];
    NSMutableAttributedString *attributed = [[[NSMutableAttributedString alloc] initWithString:resolvedText
                                                                                      attributes:baseAttributes] autorelease];

    NSDictionary *keyAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                   [NSFont systemFontOfSize:SMTrackInspectorDetailsFontSize weight:NSFontWeightSemibold], NSFontAttributeName,
                                   [NSColor labelColor], NSForegroundColorAttributeName,
                                   nil];

    NSUInteger lineStart = 0;
    while (lineStart < [resolvedText length]) {
        NSRange lineRange = [resolvedText lineRangeForRange:NSMakeRange(lineStart, 0)];
        if (lineRange.length == 0) {
            break;
        }

        NSRange textRange = lineRange;
        unichar lastChar = [resolvedText characterAtIndex:NSMaxRange(lineRange) - 1];
        if ([[NSCharacterSet newlineCharacterSet] characterIsMember:lastChar]) {
            textRange.length -= 1;
        }

        if (textRange.length > 0 && lineStart == 0) {
            NSString *lineText = [resolvedText substringWithRange:textRange];
            NSArray *segments = [lineText componentsSeparatedByString:@" | "];
            NSUInteger segmentLocation = textRange.location;

            for (NSUInteger segmentIndex = 0; segmentIndex < [segments count]; segmentIndex++) {
                NSString *segment = [segments objectAtIndex:segmentIndex];
                NSRange segmentRange = NSMakeRange(segmentLocation, [segment length]);

                NSUInteger leadingTrim = 0;
                while (leadingTrim < segmentRange.length) {
                    unichar ch = [resolvedText characterAtIndex:(segmentRange.location + leadingTrim)];
                    if (![[NSCharacterSet whitespaceCharacterSet] characterIsMember:ch]) {
                        break;
                    }
                    leadingTrim++;
                }

                NSUInteger trailingTrim = 0;
                while (trailingTrim < (segmentRange.length - leadingTrim)) {
                    NSUInteger idx = NSMaxRange(segmentRange) - 1 - trailingTrim;
                    unichar ch = [resolvedText characterAtIndex:idx];
                    if (![[NSCharacterSet whitespaceCharacterSet] characterIsMember:ch]) {
                        break;
                    }
                    trailingTrim++;
                }

                NSRange trimmedRange = NSMakeRange(segmentRange.location + leadingTrim,
                                                   segmentRange.length - leadingTrim - trailingTrim);
                if (trimmedRange.length > 0) {
                    NSRange colonRange = [resolvedText rangeOfString:@":" options:0 range:trimmedRange];
                    if (colonRange.location != NSNotFound) {
                        NSRange keyRange = NSMakeRange(trimmedRange.location,
                                                       NSMaxRange(colonRange) - trimmedRange.location);
                        [attributed addAttributes:keyAttributes range:keyRange];
                    }
                }

                segmentLocation = NSMaxRange(segmentRange);
                if (segmentIndex + 1 < [segments count]) {
                    segmentLocation += 3; // " | "
                }
            }
        }

        lineStart = NSMaxRange(lineRange);
    }

    return attributed;
}

#pragma mark - Table and Probe Helpers

static BOOL SMTrackColumnWidthIsManagedByLayout(NSString *columnIdentifier)
{
    if (![columnIdentifier isKindOfClass:[NSString class]]) {
        return NO;
    }

    return [columnIdentifier isEqualToString:@"ID"]
        || [columnIdentifier isEqualToString:@"ENABLED"]
        || [columnIdentifier isEqualToString:@"TRACKTYPE"]
        || [columnIdentifier isEqualToString:@"DURATION"]
        || [columnIdentifier isEqualToString:@"LANGUAGE"]
        || [columnIdentifier isEqualToString:@"INFO"];
}

static BOOL SMTrackMediaTypeMatches(NSString *mediaType, NSString *expected)
{
    return ([mediaType isKindOfClass:[NSString class]]
            && [expected isKindOfClass:[NSString class]]
            && [mediaType isEqualToString:expected]);
}

static NSRect SMTrackDefaultRootFrame(void)
{
    return NSMakeRect(0.0, 0.0, 1280.0, 360.0);
}

static NSRect SMTrackDefaultScrollFrame(void)
{
    return NSMakeRect(14.0, 157.0, 732.0, 203.0);
}

static NSRect SMTrackDefaultInspectorFrame(void)
{
    return NSMakeRect(772.0, 157.0, 320.0, 140.0);
}

static NSDictionary *SMTrackScrollSnapshotForScrollView(NSScrollView *scrollView)
{
    if (scrollView == nil) {
        return nil;
    }

    NSClipView *clipView = [scrollView contentView];
    NSRect clipBounds = [clipView bounds];
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithDouble:clipBounds.origin.x], @"x",
            [NSNumber numberWithDouble:clipBounds.origin.y], @"y",
            nil];
}

static void SMTrackRestoreScrollSnapshotForScrollView(NSScrollView *scrollView, NSDictionary *snapshot)
{
    if (scrollView == nil || ![snapshot isKindOfClass:[NSDictionary class]]) {
        return;
    }

    NSNumber *xValue = [snapshot objectForKey:@"x"];
    NSNumber *yValue = [snapshot objectForKey:@"y"];
    if (![xValue isKindOfClass:[NSNumber class]] || ![yValue isKindOfClass:[NSNumber class]]) {
        return;
    }

    NSClipView *clipView = [scrollView contentView];
    NSView *documentView = [scrollView documentView];
    NSRect clipBounds = [clipView bounds];
    NSRect documentBounds = (documentView != nil) ? [documentView bounds] : NSZeroRect;
    CGFloat maxX = MAX(0.0, NSWidth(documentBounds) - NSWidth(clipBounds));
    CGFloat maxY = MAX(0.0, NSHeight(documentBounds) - NSHeight(clipBounds));
    NSPoint origin = NSMakePoint(MIN(MAX([xValue doubleValue], 0.0), maxX),
                                 MIN(MAX([yValue doubleValue], 0.0), maxY));

    [clipView scrollToPoint:origin];
    [scrollView reflectScrolledClipView:clipView];
}

static NSDictionary *SMTrackProbeRect(NSRect rect)
{
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithDouble:rect.origin.x], @"x",
            [NSNumber numberWithDouble:rect.origin.y], @"y",
            [NSNumber numberWithDouble:rect.size.width], @"w",
            [NSNumber numberWithDouble:rect.size.height], @"h",
            nil];
}

static NSString *SMTrackProbeWidthClassCode(CGFloat workspaceWidth)
{
    switch (SMWorkspaceWidthClassForWidth(workspaceWidth))
    {
        case SMWorkspaceWidthClass2:
            return @"2";
        case SMWorkspaceWidthClass1:
            return @"1";
        case SMWorkspaceWidthClass0:
        default:
            return @"0";
    }
}

#pragma mark - Focus-Safe Table

@interface SMClippedFocusTableView : NSTableView
@end

@implementation SMClippedFocusTableView

- (NSRect)smClippedFocusRect
{
    NSRect visibleRect = NSIntersectionRect(NSIntegralRect([self visibleRect]), [self bounds]);
    if (NSIsEmptyRect(visibleRect)) {
        return NSZeroRect;
    }

    NSRect insetRect = NSInsetRect(visibleRect, 1.0, 1.0);
    return NSIsEmptyRect(insetRect) ? visibleRect : insetRect;
}

- (void)drawFocusRingMask
{
    NSRect clippedRect = [self smClippedFocusRect];
    if (NSIsEmptyRect(clippedRect)) {
        return;
    }

    [[NSBezierPath bezierPathWithRect:clippedRect] fill];
}

- (NSRect)focusRingMaskBounds
{
    return [self smClippedFocusRect];
}

@end

#pragma mark - Compatibility Helpers

@implementation NSArray (misc)

///=====================
//	objectAtIndexOrNil:
///=====================

- (id)objectAtIndexOrNil:(unsigned)index
{
	if ([self count] > index)
		return [self objectAtIndex:index];
	
	return nil;
}

@end

#pragma mark - Track Row Model

@interface TrackItem : NSObject
{
    BOOL        _isreftrack;
    SMTrack     *_track;

    uint32_t    _ident;
    NSString    *_language;

    uint32_t    _timescale;
    uint32_t    _duration;
}

@property (retain) SMTrack *track;
@property(readwrite) uint32_t ident;
@property(readwrite, retain) NSString *language;
@property(readwrite) BOOL isreftrack;
@property(readwrite) uint32_t duration;

-(NSString *)timeString;

@end

@interface AudioTrackItem : TrackItem
@end

@interface SubtitleTrackItem : TrackItem
@end

@interface ClosedCaptionTrackItem : TrackItem
@end

@interface VideoTrackItem : TrackItem
{
    signed short    width,
                    height;
    float           trackWidth,
                    trackHeight;
}

@property(readwrite) signed short width;
@property(readwrite) signed short height;
@property(readwrite) float trackWidth;
@property(readwrite) float trackHeight;

@end

@implementation TrackItem

@synthesize isreftrack = _isreftrack;
@synthesize track = _track;
@synthesize ident = _ident;
@synthesize duration = _duration;

//  [NSException raise:NSInvalidArgumentException format:@"Unknown table view"];

-(id)init
{
    self = [super init];

    if (self)
    {
        _isreftrack = NO;
    }

    return (self);
}

-(void) dealloc
{
    [_language release];

    [super dealloc];
}

-(NSString *) timeString
{
    int         hour,
                minute,
                second,
                frame;
    long long   result = _duration / 1000; // second
    
    frame = (_duration % 1000) / 10;

    second = result % 60;

    result /= 60; // minute
    minute = result % 60;

    result /= 60; // hour
    hour = result % 24;

    return ([NSString stringWithFormat:@"%d:%02d:%02d:%02d", hour, minute, second, frame]);
}

-(NSString *) language { return (_language); }

-(void) setLanguage: (NSString *) newLang
{
    [_language autorelease];
    _language = [newLang retain];
}
@end

#pragma mark - Audio Track Row

@implementation AudioTrackItem

-(id) init
{
     self = [super init];
    
    if (self)
        _language = @"Unknown";

    return self;
}

@end

#pragma mark - Subtitle Track Row

@implementation SubtitleTrackItem

-(id) init
{
    self = [super init];
    
    if (self)
        _language = @"Unknown";

    return (self);
}

@end

#pragma mark - Closed Caption Track Row

@implementation ClosedCaptionTrackItem

-(id) init
{
    self = [super init];
    
    if (self)
        _language = @"Unknown";

    return (self);
}

@end

#pragma mark - Video Track Row

@implementation VideoTrackItem

@synthesize width;
@synthesize height;

@synthesize trackWidth;
@synthesize trackHeight;

-(id) init
{
    self = [super init];
    
    if (self)
        _language = @"Unknown";

    return (self);
}
@end

#pragma mark - Track Row Snapshot

@interface SMTrackRowSnapshot : NSObject
{
    SMTrack *_track;
    NSInteger _rowIndex;
    uint32_t _ident;
    BOOL _enabled;
    BOOL _referenceTrack;
    BOOL _audioTrack;
    BOOL _videoTrack;
    BOOL _subtitleTrack;
    BOOL _closedCaptionTrack;
    BOOL _textTrack;
    BOOL _timecodeTrack;
    float _audioGain;
    NSString *_language;
    NSString *_durationString;
    NSString *_mediaType;
    NSString *_displayName;
    NSString *_formatSummary;
    NSString *_trackTypeLabel;
    NSURL *_sourceURL;
    signed short _encodedWidth;
    signed short _encodedHeight;
    float _displayWidth;
    float _displayHeight;
}

@property(nonatomic, readonly, retain) SMTrack *track;
@property(nonatomic, readonly) NSInteger rowIndex;
@property(nonatomic, readonly) uint32_t ident;
@property(nonatomic, readonly, getter=isEnabled) BOOL enabled;
@property(nonatomic, readonly, getter=isReferenceTrack) BOOL referenceTrack;
@property(nonatomic, readonly, getter=isAudioTrack) BOOL audioTrack;
@property(nonatomic, readonly, getter=isVideoTrack) BOOL videoTrack;
@property(nonatomic, readonly, getter=isSubtitleTrack) BOOL subtitleTrack;
@property(nonatomic, readonly, getter=isClosedCaptionTrack) BOOL closedCaptionTrack;
@property(nonatomic, readonly, getter=isTextTrack) BOOL textTrack;
@property(nonatomic, readonly, getter=isTimecodeTrack) BOOL timecodeTrack;
@property(nonatomic, readonly) float audioGain;
@property(nonatomic, readonly, copy) NSString *language;
@property(nonatomic, readonly, copy) NSString *durationString;
@property(nonatomic, readonly, copy) NSString *mediaType;
@property(nonatomic, readonly, copy) NSString *displayName;
@property(nonatomic, readonly, copy) NSString *formatSummary;
@property(nonatomic, readonly, copy) NSString *trackTypeLabel;
@property(nonatomic, readonly, retain) NSURL *sourceURL;
@property(nonatomic, readonly) signed short encodedWidth;
@property(nonatomic, readonly) signed short encodedHeight;
@property(nonatomic, readonly) float displayWidth;
@property(nonatomic, readonly) float displayHeight;

+ (id)snapshotWithTrackItem:(TrackItem *)trackItem rowIndex:(NSInteger)rowIndex;
- (id)initWithTrackItem:(TrackItem *)trackItem rowIndex:(NSInteger)rowIndex;
- (BOOL)looksLikeAudioTrack;
- (BOOL)isPrimaryAudioTrack;
- (BOOL)isPrimaryVideoTrack;
- (BOOL)looksLikeTextTrack;
- (BOOL)hasUnknownLanguage;
- (NSString *)enabledDisplayString;
- (NSString *)trackTypeColumnDisplayName;
- (NSString *)referenceTrackTypeLabel;
- (NSString *)textTrackRoleLabel;

@end

@implementation SMTrackRowSnapshot

@synthesize track = _track;
@synthesize rowIndex = _rowIndex;
@synthesize ident = _ident;
@synthesize enabled = _enabled;
@synthesize referenceTrack = _referenceTrack;
@synthesize audioTrack = _audioTrack;
@synthesize videoTrack = _videoTrack;
@synthesize subtitleTrack = _subtitleTrack;
@synthesize closedCaptionTrack = _closedCaptionTrack;
@synthesize textTrack = _textTrack;
@synthesize timecodeTrack = _timecodeTrack;
@synthesize audioGain = _audioGain;
@synthesize language = _language;
@synthesize durationString = _durationString;
@synthesize mediaType = _mediaType;
@synthesize displayName = _displayName;
@synthesize formatSummary = _formatSummary;
@synthesize trackTypeLabel = _trackTypeLabel;
@synthesize sourceURL = _sourceURL;
@synthesize encodedWidth = _encodedWidth;
@synthesize encodedHeight = _encodedHeight;
@synthesize displayWidth = _displayWidth;
@synthesize displayHeight = _displayHeight;

+ (id)snapshotWithTrackItem:(TrackItem *)trackItem rowIndex:(NSInteger)rowIndex
{
    return [[[self alloc] initWithTrackItem:trackItem rowIndex:rowIndex] autorelease];
}

- (id)initWithTrackItem:(TrackItem *)trackItem rowIndex:(NSInteger)rowIndex
{
    self = [super init];
    if (self) {
        _track = [[trackItem track] retain];
        _rowIndex = rowIndex;
        _ident = [trackItem ident];
        _referenceTrack = [trackItem isreftrack];
        _audioTrack = [trackItem isKindOfClass:[AudioTrackItem class]];
        _videoTrack = [trackItem isKindOfClass:[VideoTrackItem class]];
        _subtitleTrack = [trackItem isKindOfClass:[SubtitleTrackItem class]];
        _closedCaptionTrack = [trackItem isKindOfClass:[ClosedCaptionTrackItem class]];

        _mediaType = [[_track attributeForKey:SMTrackMediaTypeAttribute] copy];
        _displayName = [[_track attributeForKey:SMTrackDisplayNameAttribute] copy];
        _formatSummary = [[_track attributeForKey:SMTrackFormatSummaryAttribute] copy];
        _trackTypeLabel = [SMTrackTypeLabelForTrack(_track) copy];
        _language = [[trackItem language] copy];
        _durationString = [[trackItem timeString] copy];

        id sourceURL = [_track attributeForKey:SMPlaybackSourceURLAttributeKey];
        if ([sourceURL isKindOfClass:[NSURL class]]) {
            _sourceURL = [sourceURL retain];
        }

        _textTrack = SMTrackMediaTypeMatches(_mediaType, SMMediaTypeText);
        _timecodeTrack = SMTrackMediaTypeMatches(_mediaType, SMMediaTypeTimeCode);
        _enabled = _audioTrack ? ![_track isMutedForPlayback] : [_track isEnabled];
        _audioGain = (_track != nil) ? [_track audioGain] : 0.0f;

        if (_videoTrack) {
            VideoTrackItem *videoTrackItem = (VideoTrackItem *)trackItem;
            _encodedWidth = videoTrackItem.width;
            _encodedHeight = videoTrackItem.height;
            _displayWidth = videoTrackItem.trackWidth;
            _displayHeight = videoTrackItem.trackHeight;
        }
    }
    return self;
}

- (void)dealloc
{
    [_track release];
    [_language release];
    [_durationString release];
    [_mediaType release];
    [_displayName release];
    [_formatSummary release];
    [_trackTypeLabel release];
    [_sourceURL release];

    [super dealloc];
}

- (BOOL)looksLikeAudioTrack
{
    return (_audioTrack || SMTrackMediaTypeMatches(_mediaType, SMMediaTypeSound));
}

- (BOOL)isPrimaryAudioTrack
{
    return ([self looksLikeAudioTrack] && !_referenceTrack);
}

- (BOOL)isPrimaryVideoTrack
{
    return (_videoTrack && !_referenceTrack);
}

- (BOOL)looksLikeTextTrack
{
    return (_subtitleTrack
            || _closedCaptionTrack
            || SMTrackMediaTypeMatches(_mediaType, SMMediaTypeText)
            || SMTrackMediaTypeMatches(_mediaType, SMMediaTypeSubtitle)
            || SMTrackMediaTypeMatches(_mediaType, SMMediaTypeClosedCaption));
}

- (BOOL)hasUnknownLanguage
{
    return SMTrackLanguageIsUnknown(_language);
}

- (NSString *)enabledDisplayString
{
    if (_audioTrack) {
        return _enabled ? @"Yes" : @"No (muted)";
    }
    return _enabled ? @"Yes" : @"No";
}

- (NSString *)trackTypeColumnDisplayName
{
    NSString *name = _displayName;
    if (_audioTrack && SMIsChannelStyleTrackLabel(name)) {
        name = _trackTypeLabel;
    }
    return name;
}

- (NSString *)referenceTrackTypeLabel
{
    if (!_referenceTrack) {
        return @"Reference track";
    }
    return (_trackTypeLabel.length > 0) ? _trackTypeLabel : @"Reference track";
}

- (NSString *)textTrackRoleLabel
{
    if (SMTrackMediaTypeMatches(_mediaType, SMMediaTypeText)) {
        return @"Text";
    }
    if (_subtitleTrack || SMTrackMediaTypeMatches(_mediaType, SMMediaTypeSubtitle)) {
        return @"Subtitle";
    }
    if (_closedCaptionTrack || SMTrackMediaTypeMatches(_mediaType, SMMediaTypeClosedCaption)) {
        return @"Closed-caption";
    }

    return @"Text track";
}

@end

#pragma mark - Private Interface

@class SMPrimaryTrackTableDataSource;

@interface TrackViewController ()
{
    BOOL _didInitializeTrackControllerData;
    SMPrimaryTrackTableDataSource *_primaryTrackTableDataSource;
    NSDictionary *_trackSnapshot;
}
- (void)initializeTrackTableDataSourcesIfNeeded;
- (void)configureTrackTableDataSources;
- (void)initializeTrackControllerDataIfNeeded;
- (void)buildTrackViewHierarchyIfNeeded;
- (NSScrollView *)newPrimaryTracksScrollView;
- (SMClippedFocusTableView *)newPrimaryTracksTableView;
- (NSTableColumn *)newPrimaryTrackColumnWithIdentifier:(NSString *)identifier
                                                  title:(NSString *)title
                                                  width:(CGFloat)width
                                               minWidth:(CGFloat)minWidth
                                               maxWidth:(CGFloat)maxWidth
                                         headerAlignment:(NSTextAlignment)headerAlignment
                                           dataAlignment:(NSTextAlignment)dataAlignment;
- (NSTextField *)newTrackInspectorMiniLabelWithString:(NSString *)stringValue;
- (NSSlider *)newTrackInspectorGainSliderWithAction:(SEL)action;
- (void)installDynamicTrackInspectorSurfaceIfNeeded;
- (void)layoutDynamicTrackInspectorSurface;
- (void)layoutDynamicTrackInspectorSurfaceForReferenceBounds:(NSRect)referenceBounds;
- (NSInteger)trackRowCount;
- (SMTrackRowSnapshot *)trackRowSnapshotAtIndex:(NSInteger)rowIndex;
- (NSArray *)trackRowSnapshots;
- (void)invalidateTrackSnapshot;
- (void)rebuildTrackSnapshot;
- (NSDictionary *)trackSnapshot;
- (NSDictionary *)trackSnapshotRowAtIndex:(NSInteger)rowIndex;
- (NSArray *)sortedTrackSnapshotRows;
- (SMTrackRowSnapshot *)selectedTrackRowSnapshot;
- (NSAttributedString *)grayString:(NSString *)string rightAlign:(BOOL)rightAlign;
- (void)updateInspectorGainControlsForSnapshot:(SMTrackRowSnapshot *)snapshot;
- (void)updateTrackInspectorDetailsText;
- (IBAction)copyTrackInspectorDetails:(id)sender;
- (NSArray *)trackInspectorDetailPairsForTrackRowSnapshot:(SMTrackRowSnapshot *)snapshot;
- (NSString *)trackInspectorDetailsStringForTrackRowSnapshot:(SMTrackRowSnapshot *)snapshot;
- (void)restorePersistedTrackColumnWidthsForTableView:(NSTableView *)tableView;
- (void)persistResizableTrackColumnWidths;
- (void)applyPrimaryTrackTableColumnWidths;
- (TrackItem *)trackCommandItemAtIndex:(NSInteger)rowIndex;
- (TrackItem *)trackCommandItemWithIdentifier:(uint32_t)trackID;
- (void)performTrackCommandRestoreMovieStateRebuildingTracks:(BOOL)rebuildTracks;
- (void)performTrackCommandRemoveMovieReference;
- (void)performTrackCommandSetMovieGain:(float)value;
- (void)performTrackCommandSetTrackGainForItem:(TrackItem *)trackItem value:(float)value;
- (void)performTrackCommandSetTrackGainForTrackID:(uint32_t)trackID value:(float)value;
- (void)performTrackCommandApplyLanguageMenuItem:(NSMenuItem *)item target:(SMTrackCommandLanguageTarget)target;
- (void)performTrackCommandToggleEnabledAtRow:(NSInteger)rowIndex;
- (BOOL)performTrackCommandCanDeleteRow:(NSInteger)rowIndex;
- (void)performTrackCommandDeleteRow:(NSInteger)rowIndex;
- (void)performTrackCommandFinishReferenceImport;
- (void)setTrackGainForTrackID:(uint32_t)trackID value:(float)value;
@end

#pragma mark - Track Table Data Sources

// Table projection reads snapshots and sends commands; it does not own mutation.
@interface SMTrackTableDataSourceBase : NSObject
{
    TrackViewController *_owner;
}
- (id)initWithOwner:(TrackViewController *)owner;
@end

@implementation SMTrackTableDataSourceBase

- (id)initWithOwner:(TrackViewController *)owner
{
    self = [super init];
    if (self) {
        _owner = owner;
    }
    return self;
}

@end

@interface SMPrimaryTrackTableDataSource : SMTrackTableDataSourceBase <NSTableViewDataSource, CheckBoxTableColumnDelegate>
- (id)dataCellForRow:(int)rowIndex forTable:(NSTableView *)tableView;
@end

@implementation SMPrimaryTrackTableDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    #pragma unused(tableView)
    return [_owner trackRowCount];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIdx
{
    #pragma unused(tableView)
    id objectValue = nil;
    NSString *colID = [tableColumn identifier];
    NSDictionary *row = [_owner trackSnapshotRowAtIndex:rowIdx];
    BOOL isreftrack = SlateTrackSnapshotRowBool(row, SlateTrackSnapshotRowKeyReferenceTrack);

    if (row == nil) return nil;

    if ([colID isEqualToString:SlateTrackSnapshotColumnEnabled])
    {
        if (SlateTrackSnapshotRowBool(row, SlateTrackSnapshotRowKeyAudioTrack))
            objectValue = [NSNumber numberWithBool:SlateTrackSnapshotRowBool(row, SlateTrackSnapshotRowKeyEnabledFlag)];
        else if (isreftrack)
            objectValue = [NSNumber numberWithBool:SlateTrackSnapshotRowBool(row, SlateTrackSnapshotRowKeyEnabledFlag)];
    }
    else if ([colID isEqualToString:SlateTrackSnapshotColumnID])
    {
        NSString *trackID = [NSString stringWithFormat:@"%ld", (long)SlateTrackSnapshotRowInteger(row, SlateTrackSnapshotRowKeyTrackID)];
        if (isreftrack)
            objectValue = [_owner grayString:trackID rightAlign:YES];
        else
            objectValue = trackID;
    }
    else if ([colID isEqualToString:SlateTrackSnapshotColumnTrackType])
    {
        NSString *name = SlateTrackSnapshotRowString(row, SlateTrackSnapshotRowKeyTrackTypeColumn);

        if (isreftrack)
            objectValue = [_owner grayString:name rightAlign:NO];
        else
            objectValue = name;
    }
    else if ([colID isEqualToString:SlateTrackSnapshotColumnInfo])
    {
        if (SlateTrackSnapshotRowBool(row, SlateTrackSnapshotRowKeyAudioTrack)
            || SlateTrackSnapshotRowBool(row, SlateTrackSnapshotRowKeyVideoTrack))
            objectValue = SlateTrackSnapshotRowString(row, SlateTrackSnapshotRowKeyInfo);
    }
    else if ([colID isEqualToString:SlateTrackSnapshotColumnDuration])
    {
        if (isreftrack)
            objectValue = [_owner grayString:SlateTrackSnapshotRowString(row, SlateTrackSnapshotRowKeyDuration) rightAlign:YES];
        else
            objectValue = SlateTrackSnapshotRowString(row, SlateTrackSnapshotRowKeyDuration);
    }
    else if ([colID isEqualToString:SlateTrackSnapshotColumnLanguage])
    {
        if (isreftrack)
            objectValue = [_owner grayString:SlateTrackSnapshotRowString(row, SlateTrackSnapshotRowKeyLanguage) rightAlign:NO];
        else
            objectValue = SlateTrackSnapshotRowString(row, SlateTrackSnapshotRowKeyLanguage);
    }

    return objectValue;
}

- (void)tableView:(NSTableView*)tableView setObjectValue:(id)value forTableColumn:(NSTableColumn*)tableColumn row:(NSInteger)rowIdx
{
    #pragma unused(tableView, value)
    NSString *colID = [tableColumn identifier];

    if ([colID isEqualToString:SlateTrackSnapshotColumnEnabled])
    {
        [_owner performTrackCommandToggleEnabledAtRow:rowIdx];
    }
}

- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)op
{
    #pragma unused(info)
    // Make drops at the end of the table go to the end.
    if (row == -1)
    {
        row = [tableView numberOfRows];
        op = NSTableViewDropAbove;
        [tableView setDropRow:row dropOperation:op];
    }

    // We don't ever want to drop onto a row, only between rows.
    if (op == NSTableViewDropOn)
        [tableView setDropRow:row + 1 dropOperation:NSTableViewDropAbove];

    return NSDragOperationCopy;
}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)dropRow dropOperation:(NSTableViewDropOperation)op
{
    #pragma unused(tableView, dropRow, op)
    NSPasteboard *pb = [info draggingPasteboard];

    #if 0
    //  log the source mask for debugging.
    NSDragOperation srcMask = [info draggingSourceOperationMask];

    NSLog(@"[info draggingSourceOperationMask] = %u = %s%s%s%s%s%s", (unsigned int)srcMask,
        (srcMask & NSDragOperationCopy) ? "Copy ":"",
        (srcMask & NSDragOperationLink) ? "Link ":"",
        (srcMask & NSDragOperationGeneric) ? "Generic ":"",
        (srcMask & NSDragOperationPrivate) ? "Private ":"",
        (srcMask & NSDragOperationMove) ? "Move ":"",
        (srcMask & NSDragOperationDelete) ? "Delete":"");
    #endif

    if ([[pb types] containsObject:NSURLPboardType])
    {
        NSArray *items = [pb readObjectsForClasses:[NSArray arrayWithObject:[NSURL class]] options:nil];
        [_owner createReferenceTrack:items];

        return YES;
    }

    return NO;
}

- (id)dataCellForRow:(int)rowIndex forTable:(NSTableView *)tableView
{
    #pragma unused(tableView)
    id dataCell = nil;
    NSDictionary *row = [_owner trackSnapshotRowAtIndex:rowIndex];

    if (SlateTrackSnapshotRowBool(row, SlateTrackSnapshotRowKeyAudioTrack)
        || SlateTrackSnapshotRowBool(row, SlateTrackSnapshotRowKeyReferenceTrack))
    {
        dataCell = [[NSButtonCell alloc] init];
        [dataCell setButtonType:NSSwitchButton];
        [dataCell setImagePosition:NSImageOverlaps];
        [dataCell setTitle:@""];
    }
    else
        dataCell = [[NSCell alloc] initTextCell:@""];

    [dataCell setControlSize:NSSmallControlSize];
    //[dataCell setAlignment:NSCenterTextAlignment];

    return dataCell;
}

@end

#pragma mark - Controller Implementation

@implementation TrackViewController

#pragma mark - Lifecycle and View Surface

@synthesize tracks = _tracks;

- (void)initializeTrackTableDataSourcesIfNeeded
{
    if (_primaryTrackTableDataSource == nil) {
        _primaryTrackTableDataSource = [[SMPrimaryTrackTableDataSource alloc] initWithOwner:self];
    }
}

- (void)configureTrackTableDataSources
{
    [self initializeTrackTableDataSourcesIfNeeded];

    if (_tracks != nil) {
        [_tracks setDataSource:_primaryTrackTableDataSource];
        [_tracks setDelegate:self];
        NSTableColumn *enabledColumn = [_tracks tableColumnWithIdentifier:@"ENABLED"];
        if ([enabledColumn respondsToSelector:@selector(setDelegate:)]) {
            [(CheckBoxTableColumn *)enabledColumn setDelegate:_primaryTrackTableDataSource];
        }
    }
}

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        [self initializeTrackControllerDataIfNeeded];
    }
    return self;
}

- (void)loadView
{
    [self buildTrackViewHierarchyIfNeeded];
    [self initializeTrackControllerDataIfNeeded];
    [self configureTrackTableDataSources];

    [self installDynamicTrackInspectorSurfaceIfNeeded];
    [self updateInspectorGainControlsForSnapshot:[self selectedTrackRowSnapshot]];
    [self applyScanabilityMetrics];
    [self applyWorkspaceLayoutForWidth:NSWidth([[self view] bounds])];
}

- (void)awakeFromNib
{
    [self initializeTrackControllerDataIfNeeded];
    [self configureTrackTableDataSources];
    [self installDynamicTrackInspectorSurfaceIfNeeded];
    [self updateInspectorGainControlsForSnapshot:[self selectedTrackRowSnapshot]];
    [self applyScanabilityMetrics];
    [self applyWorkspaceLayoutForWidth:NSWidth([[self view] bounds])];
}

#pragma mark - Table Construction

- (NSTableColumn *)newPrimaryTrackColumnWithIdentifier:(NSString *)identifier
                                                  title:(NSString *)title
                                                  width:(CGFloat)width
                                               minWidth:(CGFloat)minWidth
                                               maxWidth:(CGFloat)maxWidth
                                         headerAlignment:(NSTextAlignment)headerAlignment
                                           dataAlignment:(NSTextAlignment)dataAlignment
{
    NSTableColumn *column = [[[NSTableColumn alloc] initWithIdentifier:identifier] autorelease];
    [column setEditable:NO];
    [column setWidth:width];
    [column setMinWidth:minWidth];
    [column setMaxWidth:maxWidth];
    [column setResizingMask:(NSTableColumnUserResizingMask | NSTableColumnAutoresizingMask)];

    NSTableHeaderCell *headerCell = [column headerCell];
    [headerCell setStringValue:(title ?: @"")];
    [headerCell setControlSize:NSControlSizeRegular];
    [headerCell setAlignment:headerAlignment];
    [headerCell setLineBreakMode:NSLineBreakByTruncatingTail];

    VertCenterTextFieldCell *dataCell = [[[VertCenterTextFieldCell alloc] initTextCell:@""] autorelease];
    [dataCell setEditable:YES];
    [dataCell setSelectable:YES];
    [dataCell setAlignment:dataAlignment];
    [dataCell setLineBreakMode:NSLineBreakByTruncatingTail];
    [dataCell setFont:SMTrackTableBodyFont()];
    [column setDataCell:dataCell];

    return column;
}

- (SMClippedFocusTableView *)newPrimaryTracksTableView
{
    [self initializeTrackTableDataSourcesIfNeeded];

    SMClippedFocusTableView *tableView = [[[SMClippedFocusTableView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 730.0, 173.0)] autorelease];
    [tableView setAllowsExpansionToolTips:YES];
    [tableView setUsesAlternatingRowBackgroundColors:YES];
    [tableView setAllowsColumnSelection:NO];
    [tableView setAllowsMultipleSelection:NO];
    [tableView setAutosaveName:@"QCAPPTRACKSVIEW"];
    [tableView setRowHeight:14.0];
    [tableView setIntercellSpacing:NSMakeSize(3.0, 2.0)];
    [tableView setGridStyleMask:(NSTableViewSolidVerticalGridLineMask | NSTableViewSolidHorizontalGridLineMask)];
    [tableView setGridColor:[NSColor separatorColor]];
    [tableView setBackgroundColor:[NSColor whiteColor]];
    [tableView setColumnAutoresizingStyle:NSTableViewNoColumnAutoresizing];
    [tableView setHeaderView:[[[NSTableHeaderView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 730.0, 32.0)] autorelease]];

    NSTableColumn *idColumn = [self newPrimaryTrackColumnWithIdentifier:@"ID"
                                                                   title:@"ID"
                                                                   width:SMTrackIDColumnFixedWidth
                                                                minWidth:SMTrackIDColumnFixedWidth
                                                                maxWidth:SMTrackIDColumnFixedWidth
                                                          headerAlignment:NSTextAlignmentCenter
                                                            dataAlignment:NSTextAlignmentRight];
    [idColumn setResizingMask:NSTableColumnNoResizing];
    [tableView addTableColumn:idColumn];

    CheckBoxTableColumn *enabledColumn = [[[CheckBoxTableColumn alloc] initWithIdentifier:@"ENABLED"] autorelease];
    [enabledColumn setEditable:NO];
    [enabledColumn setWidth:SMTrackEnabledColumnFixedWidth];
    [enabledColumn setMinWidth:SMTrackEnabledColumnFixedWidth];
    [enabledColumn setMaxWidth:SMTrackEnabledColumnFixedWidth];
    [enabledColumn setResizingMask:NSTableColumnNoResizing];
    [[enabledColumn headerCell] setStringValue:@"Enabled"];
    [[enabledColumn headerCell] setControlSize:NSControlSizeRegular];
    [[enabledColumn headerCell] setAlignment:NSTextAlignmentCenter];
    [[enabledColumn headerCell] setLineBreakMode:NSLineBreakByTruncatingTail];
    [enabledColumn setDelegate:_primaryTrackTableDataSource];
    [tableView addTableColumn:enabledColumn];

    NSTableColumn *trackTypeColumn = [self newPrimaryTrackColumnWithIdentifier:@"TRACKTYPE"
                                                                          title:@"Track Type"
                                                                          width:SMTrackTypeColumnFixedWidth
                                                                       minWidth:SMTrackTypeColumnFixedWidth
                                                                       maxWidth:SMTrackTypeColumnFixedWidth
                                                                 headerAlignment:NSTextAlignmentCenter
                                                                   dataAlignment:NSTextAlignmentLeft];
    [trackTypeColumn setResizingMask:NSTableColumnNoResizing];
    [tableView addTableColumn:trackTypeColumn];

    NSTableColumn *durationColumn = [self newPrimaryTrackColumnWithIdentifier:@"DURATION"
                                                                         title:@"Duration"
                                                                         width:SMTrackDurationColumnFixedWidth
                                                                      minWidth:SMTrackDurationColumnFixedWidth
                                                                      maxWidth:SMTrackDurationColumnFixedWidth
                                                                headerAlignment:NSTextAlignmentCenter
                                                                  dataAlignment:NSTextAlignmentCenter];
    [durationColumn setResizingMask:NSTableColumnNoResizing];
    [tableView addTableColumn:durationColumn];

    NSTableColumn *languageColumn = [self newPrimaryTrackColumnWithIdentifier:@"LANGUAGE"
                                                                         title:@"Language"
                                                                         width:SMTrackLanguageInfoSharedWidth
                                                                      minWidth:SMTrackFlexibleColumnMinimumWidth
                                                                      maxWidth:FLT_MAX
                                                                headerAlignment:NSTextAlignmentCenter
                                                                  dataAlignment:NSTextAlignmentLeft];
    [languageColumn setResizingMask:NSTableColumnNoResizing];
    [tableView addTableColumn:languageColumn];

    NSTableColumn *infoColumn = [self newPrimaryTrackColumnWithIdentifier:@"INFO"
                                                                     title:@"Info"
                                                                     width:SMTrackLanguageInfoSharedWidth
                                                                  minWidth:SMTrackFlexibleColumnMinimumWidth
                                                                  maxWidth:FLT_MAX
                                                            headerAlignment:NSTextAlignmentCenter
                                                              dataAlignment:NSTextAlignmentLeft];
    [infoColumn setResizingMask:NSTableColumnNoResizing];
    [tableView addTableColumn:infoColumn];

    [self restorePersistedTrackColumnWidthsForTableView:tableView];
    [tableView setDataSource:_primaryTrackTableDataSource];
    [tableView setDelegate:self];
    return tableView;
}

#pragma mark - Table Column Widths

- (void)restorePersistedTrackColumnWidthsForTableView:(NSTableView *)tableView
{
    if (tableView == nil) {
        return;
    }

    NSDictionary *widthByColumn = [[NSUserDefaults standardUserDefaults] objectForKey:SMTrackResizableColumnWidthsDefaultsKey];
    if (![widthByColumn isKindOfClass:[NSDictionary class]]) {
        return;
    }

    for (NSTableColumn *column in [tableView tableColumns]) {
        NSString *columnID = [column identifier];
        if (SMTrackColumnWidthIsManagedByLayout(columnID)) {
            continue;
        }

        NSNumber *storedWidth = [widthByColumn objectForKey:columnID];
        if (![storedWidth isKindOfClass:[NSNumber class]]) {
            continue;
        }

        CGFloat clampedWidth = [storedWidth doubleValue];
        clampedWidth = MAX([column minWidth], MIN([column maxWidth], clampedWidth));
        [column setWidth:clampedWidth];
    }
}

- (void)persistResizableTrackColumnWidths
{
    if (_tracks == nil) {
        return;
    }

    NSMutableDictionary *widthByColumn = [NSMutableDictionary dictionary];
    for (NSTableColumn *column in [_tracks tableColumns]) {
        NSString *columnID = [column identifier];
        if (SMTrackColumnWidthIsManagedByLayout(columnID)) {
            continue;
        }

        [widthByColumn setObject:[NSNumber numberWithDouble:[column width]]
                          forKey:columnID];
    }

    [[NSUserDefaults standardUserDefaults] setObject:widthByColumn
                                              forKey:SMTrackResizableColumnWidthsDefaultsKey];
}

- (void)applyPrimaryTrackTableColumnWidths
{
    if (_tracks == nil) {
        return;
    }

    NSTableColumn *languageColumn = [_tracks tableColumnWithIdentifier:@"LANGUAGE"];
    NSTableColumn *infoColumn = [_tracks tableColumnWithIdentifier:@"INFO"];
    if (languageColumn == nil || infoColumn == nil) {
        return;
    }

    NSScrollView *scrollView = [_tracks enclosingScrollView];
    CGFloat availableWidth = (scrollView != nil) ? NSWidth([[scrollView contentView] bounds]) : NSWidth([_tracks bounds]);
    if (availableWidth <= 0.0 && scrollView != nil) {
        availableWidth = NSWidth([scrollView bounds]);
    }
    if (availableWidth <= 0.0) {
        return;
    }

    NSArray *fixedColumnIdentifiers = [NSArray arrayWithObjects:@"ID", @"ENABLED", @"TRACKTYPE", @"DURATION", nil];
    CGFloat fixedColumnWidth = 0.0;
    for (NSString *columnIdentifier in fixedColumnIdentifiers) {
        NSTableColumn *column = [_tracks tableColumnWithIdentifier:columnIdentifier];
        if (column != nil && ![column isHidden]) {
            fixedColumnWidth += [column width];
        }
    }

    NSUInteger visibleColumnCount = 0;
    for (NSTableColumn *column in [_tracks tableColumns]) {
        if (![column isHidden]) {
            visibleColumnCount++;
        }
    }

    CGFloat intercolumnSpacingWidth = (visibleColumnCount > 1)
        ? ([_tracks intercellSpacing].width * (CGFloat)(visibleColumnCount - 1))
        : 0.0;
    CGFloat flexibleWidth = MAX(SMTrackFlexibleColumnMinimumWidth * 2.0,
                                availableWidth - fixedColumnWidth - intercolumnSpacingWidth);
    CGFloat languageWidth = floor(flexibleWidth * 0.5);
    CGFloat infoWidth = flexibleWidth - languageWidth;

    [languageColumn setMinWidth:SMTrackFlexibleColumnMinimumWidth];
    [languageColumn setMaxWidth:FLT_MAX];
    [languageColumn setWidth:languageWidth];
    [infoColumn setMinWidth:SMTrackFlexibleColumnMinimumWidth];
    [infoColumn setMaxWidth:FLT_MAX];
    [infoColumn setWidth:infoWidth];

    NSRect tableFrame = [_tracks frame];
    tableFrame.size.width = fixedColumnWidth + intercolumnSpacingWidth + languageWidth + infoWidth;
    [_tracks setFrame:tableFrame];
}

#pragma mark - Root View Assembly

- (NSScrollView *)newPrimaryTracksScrollView
{
    NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:SMTrackDefaultScrollFrame()] autorelease];
    [scrollView setBorderType:NSLineBorder];
    [scrollView setAutohidesScrollers:YES];
    [scrollView setHasHorizontalScroller:NO];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setHorizontalLineScroll:16.0];
    [scrollView setHorizontalPageScroll:10.0];
    [scrollView setVerticalLineScroll:16.0];
    [scrollView setVerticalPageScroll:10.0];
    [scrollView setUsesPredominantAxisScrolling:NO];
    [scrollView setAutoresizingMask:(NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin | NSViewMaxYMargin)];
    [scrollView setFocusRingType:NSFocusRingTypeNone];
    return scrollView;
}

- (void)buildTrackViewHierarchyIfNeeded
{
    if ([self isViewLoaded] && _tracks != nil) {
        return;
    }

    NSView *rootView = [[[NSView alloc] initWithFrame:SMTrackDefaultRootFrame()] autorelease];
    [rootView setHidden:YES];
    [rootView setWantsLayer:YES];
    [rootView setFocusRingType:NSFocusRingTypeNone];
    [rootView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];

    NSScrollView *tracksScrollView = [self newPrimaryTracksScrollView];
    _tracks = [self newPrimaryTracksTableView];
    [tracksScrollView setDocumentView:_tracks];
    [tracksScrollView setVerticalLineScroll:[_tracks rowHeight]];
    [rootView addSubview:tracksScrollView];

    [self setView:rootView];
}

#pragma mark - Controller State

- (void)initializeTrackControllerDataIfNeeded
{
    if (_didInitializeTrackControllerData) {
        return;
    }

    _didInitializeTrackControllerData = YES;

    NSArray         *assetTypes = [AppController infoValueForKey:KEY_ASSET_TYPE];
    NSDictionary    *dict = nil;
    NSString        *value = nil;

    for (int i = 0; i < [assetTypes count]; i++)
    {
        dict = [assetTypes objectAtIndex:i];
        value = [dict objectForKey:KEY_NAME];
        [_assetTypePopup addItemWithTitle:value];
    }

    for (int i = 0; i < [assetTypes count]; i++)
    {
        dict = [assetTypes objectAtIndex:i];
        value = [dict objectForKey:KEY_ID];

        NSMenuItem  *item = [_assetTypePopup itemAtIndex:i];
        [item setTag:[value intValue]];
    }

    _track = [[[NSMutableArray alloc] init] retain];
    _inspectorRailPinned = [[NSUserDefaults standardUserDefaults] boolForKey:SMTrackInspectorRailPinnedDefaultsKey];

    NSString *error = nil;
    NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0;
    NSString *path = [[NSBundle mainBundle] pathForResource:@"language" ofType:@"plist"];
    NSArray *languageNameArray = [NSPropertyListSerialization propertyListFromData:[NSData dataWithContentsOfFile:path]
                                                                  mutabilityOption:NSPropertyListImmutable
                                                                            format:&format
                                                                  errorDescription:&error];
    for (int i = 0; i < [languageNameArray count]; i++)
    {
        NSDictionary *lang = [languageNameArray objectAtIndex:i];
        NSString *title = [lang objectForKey:@"LANGUAGE"];
        NSInteger index = [[lang objectForKey:@"INDEX"] integerValue];

        [_audioLanguagePopup addItemWithTitle:title];
        [_videoLanguagePopup addItemWithTitle:title];

        NSMenuItem *item = [_audioLanguagePopup itemAtIndex:i];
        [item setTag:index];

        item = [_videoLanguagePopup itemAtIndex:i];
        [item setTag:index];
    }

    [self configureTrackTableDataSources];
}

#pragma mark - Validation

- (void)applyCanonicalValidationFindings:(NSArray *)findings
{
    NSArray *canonicalFindings = SlateInspectorRailCanonicalFindingsArray(findings);
    [_canonicalValidationFindings release];
    _canonicalValidationFindings = [canonicalFindings copy];

    NSString *toolTip = SlateInspectorRailFindingsSummaryToolTip(_canonicalValidationFindings,
                                                                   SMTrackReadinessFindingsToolTipTitle);
    NSString *copyHintToolTip = SlateInspectorRailCopyHintTooltip(toolTip);
    [_tracks setToolTip:copyHintToolTip];
    [_trackInspectorDetailsTextView setToolTip:copyHintToolTip];
    [_trackInspectorDetailsScrollView setToolTip:copyHintToolTip];
    [_assetTypePopup setToolTip:toolTip];
    [self updateTrackReadinessPanelPresentation];
}

- (NSArray *)canonicalValidationFindings
{
    return (_canonicalValidationFindings ?: [NSArray array]);
}

- (void)refreshValidationAdaptersAfterMutation
{
    [appcontroller() refreshValidationViewAdapters];
}

#pragma mark - Scanability

- (void)applyScanabilityMetricsToTableView:(NSTableView *)tableView
                                 rowHeight:(CGFloat)rowHeight
                        intercellVSpacing:(CGFloat)verticalSpacing
{
    if (tableView == nil) {
        return;
    }

    [tableView setRowHeight:rowHeight];
    NSSize intercellSpacing = [tableView intercellSpacing];
    intercellSpacing.height = verticalSpacing;
    [tableView setIntercellSpacing:intercellSpacing];
    [tableView setUsesAlternatingRowBackgroundColors:YES];

    NSFont *headerFont = SMTrackTableHeaderFont();
    for (NSTableColumn *column in [tableView tableColumns]) {
        [[column headerCell] setFont:headerFont];
        [[column headerCell] setControlSize:NSControlSizeRegular];
    }
    NSTableHeaderView *headerView = [tableView headerView];
    if (headerView != nil) {
        NSRect headerFrame = [headerView frame];
        headerFrame.size.height = SMTrackTableHeaderHeight;
        [headerView setFrame:headerFrame];
    }

    [tableView setFocusRingType:NSFocusRingTypeDefault];
    NSScrollView *scrollView = [tableView enclosingScrollView];
    [scrollView setFocusRingType:NSFocusRingTypeNone];
    [scrollView setVerticalLineScroll:rowHeight];
}

- (void)applyScanabilityMetrics
{
    [self applyScanabilityMetricsToTableView:_tracks
                                   rowHeight:SMTrackTableRowHeight
                          intercellVSpacing:SMTrackTableIntercellVerticalSpacing];

    [_assetTypePopup setControlSize:NSSmallControlSize];
    [_audioLanguagePopup setControlSize:NSSmallControlSize];
    [_videoLanguagePopup setControlSize:NSSmallControlSize];
}

#pragma mark - Inspector Surface

- (NSTextField *)newTrackInspectorMiniLabelWithString:(NSString *)stringValue
{
    NSTextField *label = [[[NSTextField alloc] initWithFrame:NSZeroRect] autorelease];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setBordered:NO];
    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    [label setStringValue:(stringValue ?: @"")];
    [label setFont:SMTrackInspectorMiniLabelFont()];
    [label setTextColor:[NSColor secondaryLabelColor]];
    [label setLineBreakMode:NSLineBreakByTruncatingTail];
    [[label cell] setUsesSingleLineMode:YES];
    [[label cell] setWraps:NO];
    return label;
}

- (NSSlider *)newTrackInspectorGainSliderWithAction:(SEL)action
{
    NSSlider *slider = [[[NSSlider alloc] initWithFrame:NSZeroRect] autorelease];
    [slider setControlSize:NSSmallControlSize];
    [slider setMinValue:0.0];
    [slider setMaxValue:2.0];
    [slider setDoubleValue:1.0];
    [slider setNumberOfTickMarks:3];
    [slider setAllowsTickMarkValuesOnly:NO];
    [slider setContinuous:YES];
    [slider setTarget:self];
    [slider setAction:action];
    return slider;
}

- (void)installDynamicTrackInspectorSurfaceIfNeeded
{
    if (_trackInspectorSurface != nil && [[_trackInspectorSurface identifier] isEqualToString:SMTrackDynamicSurfaceIdentifier]) {
        return;
    }

    if (_trackInspectorSurface != nil) {
        [_trackInspectorSurface removeFromSuperview];
        _trackInspectorSurface = nil;
    }

    NSRect inspectorFrame = SMTrackDefaultInspectorFrame();

    _gainSlider = nil;
    _gainLabel = nil;
    _gainMinLabel = nil;
    _gainMidLabel = nil;
    _gainMaxLabel = nil;
    _trackInspectorDetailsScrollView = nil;
    _trackInspectorDetailsTextView = nil;

    NSView *surfaceView = [[[NSView alloc] initWithFrame:inspectorFrame] autorelease];
    [surfaceView setIdentifier:SMTrackDynamicSurfaceIdentifier];
    [surfaceView setAutoresizingMask:NSViewNotSizable];
    [[self view] addSubview:surfaceView];
    _trackInspectorSurface = surfaceView;

    _gainLabel = [self newTrackInspectorMiniLabelWithString:@"Gain:"];
    [_gainLabel setFont:[NSFont systemFontOfSize:[NSFont systemFontSize] weight:NSFontWeightRegular]];
    [_gainLabel setAlignment:NSTextAlignmentRight];
    [[_gainLabel cell] setAlignment:NSTextAlignmentRight];
    _gainSlider = [self newTrackInspectorGainSliderWithAction:@selector(inspectorGainSliderChanged:)];
    _gainMinLabel = [self newTrackInspectorMiniLabelWithString:@"0.0"];
    _gainMidLabel = [self newTrackInspectorMiniLabelWithString:@"1.0"];
    _gainMaxLabel = [self newTrackInspectorMiniLabelWithString:@"2.0"];
    [surfaceView addSubview:_gainLabel];
    [surfaceView addSubview:_gainSlider];
    [surfaceView addSubview:_gainMinLabel];
    [surfaceView addSubview:_gainMidLabel];
    [surfaceView addSubview:_gainMaxLabel];

    NSScrollView *detailsScrollView = [[[NSScrollView alloc] initWithFrame:NSZeroRect] autorelease];
    [detailsScrollView setHasVerticalScroller:YES];
    [detailsScrollView setAutohidesScrollers:YES];
    [detailsScrollView setBorderType:NSBezelBorder];
    [detailsScrollView setDrawsBackground:NO];
    [detailsScrollView setAutoresizingMask:NSViewNotSizable];
    [detailsScrollView setVerticalLineScroll:20.0];

    NSTextView *detailsTextView = [[[SMTrackInspectorDetailsTextView alloc] initWithFrame:NSZeroRect] autorelease];
    [detailsTextView setEditable:NO];
    [detailsTextView setSelectable:YES];
    [detailsTextView setFieldEditor:NO];
    [detailsTextView setRichText:NO];
    [detailsTextView setImportsGraphics:NO];
    [detailsTextView setUsesFontPanel:NO];
    [detailsTextView setUsesFindPanel:NO];
    [detailsTextView setAllowsUndo:NO];
    [detailsTextView setHorizontallyResizable:NO];
    [detailsTextView setVerticallyResizable:YES];
    [detailsTextView setAutomaticQuoteSubstitutionEnabled:NO];
    [detailsTextView setAutomaticDashSubstitutionEnabled:NO];
    [detailsTextView setAutomaticTextReplacementEnabled:NO];
    [detailsTextView setAutomaticDataDetectionEnabled:NO];
    [detailsTextView setFont:[NSFont systemFontOfSize:SMTrackInspectorDetailsFontSize weight:NSFontWeightRegular]];
    [detailsTextView setTextColor:[NSColor textColor]];
    [detailsTextView setDrawsBackground:YES];
    [detailsTextView setBackgroundColor:[NSColor whiteColor]];
    [detailsTextView setString:SMTrackInspectorDetailsEmptyMessage];
    [detailsTextView setAutoresizingMask:NSViewWidthSizable];
    [detailsTextView setDelegate:self];
    [detailsScrollView setDocumentView:detailsTextView];
    [surfaceView addSubview:detailsScrollView];
    _trackInspectorDetailsTextView = detailsTextView;
    _trackInspectorDetailsScrollView = detailsScrollView;

    _gainSliderTargetsMovie = YES;

    [self layoutDynamicTrackInspectorSurface];
    [self updateInspectorGainControlsForSnapshot:[self selectedTrackRowSnapshot]];
}

- (void)layoutDynamicTrackInspectorSurface
{
    if (_trackInspectorSurface == nil) {
        return;
    }

    [self layoutDynamicTrackInspectorSurfaceForReferenceBounds:[_trackInspectorSurface bounds]];
}

- (void)layoutDynamicTrackInspectorSurfaceForReferenceBounds:(NSRect)referenceBounds
{
    if (_trackInspectorSurface == nil || ![[_trackInspectorSurface identifier] isEqualToString:SMTrackDynamicSurfaceIdentifier]) {
        return;
    }

    NSView *trackView = _trackInspectorSurface;
    NSScrollView *detailsScrollView = _trackInspectorDetailsScrollView;
    CGFloat trackInset = SMTrackDynamicInspectorInset;
    CGFloat trackLabelWidth = SMTrackDynamicGainLabelWidth;
    CGFloat contentBottomY = trackInset + SMTrackDynamicGainContentHeight + SMTrackDynamicDetailsBottomGap;
    CGFloat contentTopY = NSHeight([trackView bounds]) - trackInset;
    CGFloat gainBlockBaseY = trackInset + SMTrackDynamicGainClusterDropY;
    CGFloat trackSliderY = gainBlockBaseY + SMTrackDynamicGainSliderYOffset;
    CGFloat trackLabelY = trackSliderY + floor((SMTrackDynamicGainSliderHeight - SMTrackDynamicGainLabelHeight) * 0.5) + 2.0;
    CGFloat trackSliderWidth = MIN(SMTrackDynamicGainSliderMaxWidth,
                                   MAX(SMTrackDynamicGainSliderMinWidth,
                                       MIN(SMTrackDynamicTrackGainBlockWidth, NSWidth([trackView bounds]) - (trackInset * 2.0)) - trackLabelWidth - 2.0));
    CGFloat gainVisualWidth = trackLabelWidth + trackSliderWidth;
    CGFloat gainBlockX = floor((NSWidth([trackView bounds]) - gainVisualWidth) * 0.5);
    gainBlockX = MAX(trackInset, gainBlockX);
    gainBlockX = MIN(gainBlockX, NSWidth([trackView bounds]) - trackInset - gainVisualWidth);
    CGFloat trackSliderX = gainBlockX + trackLabelWidth;

    [_gainLabel setFrame:NSMakeRect(MAX(0.0, gainBlockX - 4.0 - SMTrackDynamicGainLabelFrameLeftShift),
                                    trackLabelY,
                                    trackLabelWidth + SMTrackDynamicGainLabelFrameWidthDelta,
                                    SMTrackDynamicGainLabelHeight)];
    [_gainSlider setFrame:NSMakeRect(trackSliderX, trackSliderY, trackSliderWidth, SMTrackDynamicGainSliderHeight)];
    [_gainMinLabel setFrame:NSMakeRect(trackSliderX + SMTrackDynamicGainMinLabelXOffset,
                                       gainBlockBaseY + SMTrackDynamicGainTickLabelY,
                                       SMTrackDynamicGainTickLabelWidth,
                                       SMTrackDynamicGainTickLabelHeight)];
    [_gainMidLabel setFrame:NSMakeRect(trackSliderX + ((trackSliderWidth - SMTrackDynamicGainTickLabelWidth) * 0.5),
                                       gainBlockBaseY + SMTrackDynamicGainTickLabelY,
                                       SMTrackDynamicGainTickLabelWidth,
                                       SMTrackDynamicGainTickLabelHeight)];
    [_gainMaxLabel setFrame:NSMakeRect(trackSliderX + trackSliderWidth - SMTrackDynamicGainMaxLabelRightTrim,
                                       gainBlockBaseY + SMTrackDynamicGainTickLabelY,
                                       SMTrackDynamicGainTickLabelWidth,
                                       SMTrackDynamicGainTickLabelHeight)];

    [detailsScrollView setHidden:NO];
    CGFloat detailsBottomY = contentBottomY - SMTrackDynamicDetailsPanelDropY;
    CGFloat detailsTopY = MIN(contentTopY,
                              MAX(detailsBottomY + 1.0,
                                  SMTrackInspectorDetailsAlignedTopY(referenceBounds)));
    CGFloat detailsWidth = MIN(MAX(1.0, NSWidth([trackView bounds]) - (trackInset * 2.0)),
                               SMTrackInspectorDetailsAlignedWidth(referenceBounds));
    CGFloat detailsX = floor((NSWidth([trackView bounds]) - detailsWidth) * 0.5);
    [detailsScrollView setFrame:NSMakeRect(detailsX,
                                           detailsBottomY,
                                           detailsWidth,
                                           MAX(1.0, detailsTopY - detailsBottomY))];
    [self updateInspectorGainControlsForSnapshot:[self selectedTrackRowSnapshot]];
    [self updateTrackInspectorDetailsText];
}

#pragma mark - Readiness Rail

- (NSTextField *)newTrackOverlayLabelWithString:(NSString *)stringValue
{
    NSTextField *label = SlateInspectorRailCreateLabel(stringValue,
                                                         [NSFont boldSystemFontOfSize:11.5],
                                                         SlateInspectorRailSectionHeaderColor(),
                                                         NSTextAlignmentLeft,
                                                         NO);
    SlateInspectorRailApplySectionHeaderStyle(label);
    return label;
}

- (NSTextField *)newTrackStateLabel
{
    NSTextField *label = SlateInspectorRailCreateLabel(@"",
                                                         [NSFont systemFontOfSize:12.0],
                                                         SlateInspectorRailStateMessageColor(),
                                                         NSTextAlignmentCenter,
                                                         YES);
    SlateInspectorRailApplyStateMessageStyle(label);
    [label setHidden:YES];
    [label setAutoresizingMask:(NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin | NSViewMaxYMargin)];
    return label;
}

- (void)restoreTrackReadinessSubviewOrderIfNeeded
{
    NSView *containerView = [self view];
    if (containerView == nil || _advancedSectionLabel == nil) {
        return;
    }

    NSMutableArray *orderedViews = [NSMutableArray arrayWithCapacity:6];
    NSView *readinessSectionLabel = [_readinessPresenter sectionLabel];
    NSView *readinessStatusLabel = [_readinessPresenter statusLabel];
    NSView *inspectorPinButton = [_readinessPresenter pinButton];
    NSView *readinessScrollView = [_readinessPresenter scrollView];
    if (readinessSectionLabel != nil) {
        [orderedViews addObject:readinessSectionLabel];
    }
    [orderedViews addObject:_advancedSectionLabel];
    if (readinessStatusLabel != nil) {
        [orderedViews addObject:readinessStatusLabel];
    }
    if (readinessScrollView != nil) {
        [orderedViews addObject:readinessScrollView];
    }
    if (_trackInspectorCopyButton != nil) {
        [orderedViews addObject:_trackInspectorCopyButton];
    }
    if (inspectorPinButton != nil) {
        [orderedViews addObject:inspectorPinButton];
    }
    if ([orderedViews count] != 6) {
        return;
    }

    NSArray *subviews = [containerView subviews];
    NSUInteger previousIndex = NSNotFound;
    BOOL needsReorder = NO;
    for (NSView *view in orderedViews) {
        if ([view superview] != containerView) {
            return;
        }
        NSUInteger index = [subviews indexOfObjectIdenticalTo:view];
        if (index == NSNotFound) {
            return;
        }
        if (previousIndex != NSNotFound && index <= previousIndex) {
            needsReorder = YES;
            break;
        }
        previousIndex = index;
    }
    if (!needsReorder
        && [subviews indexOfObjectIdenticalTo:[orderedViews lastObject]] != ([subviews count] - 1)) {
        needsReorder = YES;
    }
    if (!needsReorder) {
        return;
    }

    for (NSView *view in orderedViews) {
        [view removeFromSuperview];
        [containerView addSubview:view];
    }
}

- (void)ensureTrackLayoutSupplementaryViews
{
    [self installDynamicTrackInspectorSurfaceIfNeeded];

    if (_advancedGroupBox == nil) {
        _advancedGroupBox = [[NSBox alloc] initWithFrame:NSZeroRect];
        SlateInspectorRailApplyToolGroupBoxStyle(_advancedGroupBox);
        [_advancedGroupBox setHidden:YES];
        [[self view] addSubview:_advancedGroupBox positioned:NSWindowBelow relativeTo:nil];
    }

    if (_tracksStateLabel == nil) {
        _tracksStateLabel = [[self newTrackStateLabel] retain];
        [[self view] addSubview:_tracksStateLabel];
    }

    if (_trackInspectorCopyButton == nil) {
        _trackInspectorCopyButton = [[NSButton alloc] initWithFrame:NSZeroRect];
        [_trackInspectorCopyButton setButtonType:NSButtonTypeMomentaryPushIn];
        [_trackInspectorCopyButton setBordered:NO];
        [_trackInspectorCopyButton setImage:SMTrackInspectorCopyButtonImage()];
        [_trackInspectorCopyButton setImagePosition:NSImageOnly];
        [_trackInspectorCopyButton setImageScaling:NSImageScaleProportionallyDown];
        [_trackInspectorCopyButton setToolTip:@"Copy"];
        [_trackInspectorCopyButton setTarget:self];
        [_trackInspectorCopyButton setAction:@selector(copyTrackInspectorDetails:)];
        [_trackInspectorCopyButton setHidden:YES];
        [[self view] addSubview:_trackInspectorCopyButton];
    }

    if (_advancedSectionLabel == nil) {
        _advancedSectionLabel = [[self newTrackOverlayLabelWithString:@"Track + Movie Inspector"] retain];
        [[self view] addSubview:_advancedSectionLabel];
    }

    if (_readinessPresenter == nil) {
        _readinessPresenter = [[UtilReadinessRailPresenter alloc] initWithSectionTitle:SMTrackReadinessSectionTitle
                                                                  findingsToolTipTitle:SMTrackReadinessFindingsToolTipTitle
                                                                             pinTarget:self
                                                                             pinAction:@selector(toggleInspectorRailPinned:)
                                                                      textViewDelegate:(id<NSTextViewDelegate>)self];
    }
    [_readinessPresenter ensureViewsInSuperview:[self view]];
    [_readinessPresenter setPinState:_inspectorRailPinned];
    [self restoreTrackReadinessSubviewOrderIfNeeded];
}

- (NSInteger)trackRowIndexForReadinessFinding:(NSDictionary *)finding
{
    if (![finding isKindOfClass:[NSDictionary class]]) {
        return NSNotFound;
    }

    NSInteger rowIndex = SlateInspectorRailRowIndexFromScope([finding objectForKey:SMValidationFindingKeyScope],
                                                               [NSArray arrayWithObjects:@"track-row", @"row", nil]);
    if (rowIndex != NSNotFound) {
        return rowIndex;
    }

    NSString *code = [[finding objectForKey:SMValidationFindingKeyCode] lowercaseString];
    if (SMTrackCodeContainsToken(code, @"audio_track_language")) {
        return [self firstAudioTrackRowWithUnknownLanguage];
    }
    if (SMTrackCodeContainsToken(code, @"audio_track_layout")) {
        return [self firstAudioTrackRowWithUnresolvedChannelLayout];
    }
    if (SMTrackCodeContainsToken(code, @"audio_channel_assignments_are_generic")
        || SMTrackCodeContainsToken(code, @"generic_channel")) {
        return [self firstAudioTrackRowWithGenericChannelAssignments];
    }
    if (SMTrackCodeContainsToken(code, @"text_track_language")) {
        return [self firstTextTrackRowWithUnknownLanguage];
    }
    if (SMTrackCodeContainsToken(code, @"text_track_role")) {
        return [self firstTextTrackRowWithUnresolvedRole];
    }
    if (SMTrackCodeContainsToken(code, @"reference_audio_source")) {
        return [self firstReferenceAudioTrackRowWithUnresolvedSource];
    }
    if (SMTrackCodeContainsToken(code, @"reference_track_language")) {
        return [self firstReferenceTrackRowWithUnknownLanguage];
    }

    return NSNotFound;
}

- (NSString *)trackReadinessJumpTargetForFinding:(NSDictionary *)finding rowIndex:(NSInteger *)outRowIndex
{
    NSInteger rowIndex = [self trackRowIndexForReadinessFinding:finding];
    if (outRowIndex != NULL) {
        *outRowIndex = rowIndex;
    }

    NSString *code = [finding objectForKey:SMValidationFindingKeyCode];
    if (SMTrackStringHasContent(code) && [code isEqualToString:SMValidationFindingCodeTracksAssetTypeIsUnknown]) {
        return @"tracks-assetType";
    }

    return @"tracks";
}

- (NSDictionary *)trackReadinessJumpLinksByFindingIdentity
{
    NSMutableDictionary *jumpLinkByFindingIdentity = [NSMutableDictionary dictionary];
    for (NSDictionary *finding in [self canonicalValidationFindings]) {
        if (![finding isKindOfClass:[NSDictionary class]]) {
            continue;
        }

        NSInteger rowIndex = NSNotFound;
        NSString *target = [self trackReadinessJumpTargetForFinding:finding rowIndex:&rowIndex];
        NSString *jumpLink = SlateInspectorRailJumpLink(target, rowIndex);
        if (SMTrackStringHasContent(jumpLink)) {
            [jumpLinkByFindingIdentity setObject:jumpLink
                                          forKey:SlateInspectorRailFindingIdentity(finding)];
        }
    }

    return jumpLinkByFindingIdentity;
}

- (void)updateTrackReadinessPanelPresentation
{
    [self ensureTrackLayoutSupplementaryViews];
    SMMovie *currentMovie = SMTrackCurrentMovieFromAppController();

    NSString *emptyStatus = (currentMovie == nil) ? SMTrackReadinessStatusNoMovie : SMTrackReadinessStatusNoFindings;
    NSString *emptyMessage = (currentMovie == nil) ? @"" : SMTrackReadinessEmptyMessageNoFindings;
    NSDictionary *jumpLinkByFindingIdentity = [self trackReadinessJumpLinksByFindingIdentity];
    NSDictionary *reviewPaneSnapshot = [SlateRuntimeBridge reviewPaneSnapshotWithPaneKey:SlateReviewPaneKeyTrack
                                                                                title:SMTrackReadinessSectionTitle
                                                                             findings:[self canonicalValidationFindings]
                                                                          emptyStatus:emptyStatus
                                                                         emptyMessage:emptyMessage
                                                           jumpLinksByFindingIdentity:jumpLinkByFindingIdentity];
    [_readinessPresenter updateWithReviewPaneSnapshot:reviewPaneSnapshot];
}

- (BOOL)textView:(NSTextView *)textView clickedOnLink:(id)link atIndex:(NSUInteger)charIndex
{
    #pragma unused(charIndex)
    if (![_readinessPresenter ownsTextView:textView]) {
        return NO;
    }

    NSInteger rowIndex = NSNotFound;
    NSString *target = SlateInspectorRailJumpTargetFromLink(link, &rowIndex);
    if (!SMTrackStringHasContent(target)) {
        return NO;
    }

    if ([target isEqualToString:@"tracks-assetType"]) {
        [[[self view] window] makeFirstResponder:_assetTypePopup];
        return YES;
    }

    if ([target isEqualToString:@"tracks"]) {
        NSInteger rowCount = [_tracks numberOfRows];
        if (rowCount > 0) {
            NSInteger boundedRow = rowIndex;
            if (boundedRow == NSNotFound || boundedRow < 0 || boundedRow >= rowCount) {
                boundedRow = 0;
            }
            [_tracks selectRowIndexes:[NSIndexSet indexSetWithIndex:boundedRow] byExtendingSelection:NO];
            [_tracks scrollRowToVisible:boundedRow];
            [[[self view] window] makeFirstResponder:_tracks];
        }
        return YES;
    }

    return NO;
}

#pragma mark - Rail Layout Helpers

- (void)hideTrackReadinessRail
{
    [_readinessPresenter applySectionFrame:NSZeroRect
                               statusFrame:NSZeroRect
                               scrollFrame:NSZeroRect
                                  pinFrame:NSZeroRect
                                pinVisible:NO];
    [_readinessPresenter setRailHidden:YES];
}

- (void)applyTrackReadinessRailFrame:(NSRect)readinessFrame
                 readinessTopYAnchor:(CGFloat)readinessTopYAnchor
                  sectionLabelHeight:(CGFloat)sectionLabelHeight
                          sectionGap:(CGFloat)sectionGap
{
    CGFloat readinessStatusHeight = SlateInspectorRailDisclosureRowHeight();
    CGFloat readinessTopY = readinessTopYAnchor;
    CGFloat readinessStatusY = readinessTopY - readinessStatusHeight - 2.0;
    CGFloat readinessScrollBottomY = NSMinY(readinessFrame);
    CGFloat readinessScrollHeight = (readinessStatusY - sectionGap) - readinessScrollBottomY;
    readinessScrollHeight = MAX(SlateInspectorRailWarningBlockMinHeight(), readinessScrollHeight);
    readinessScrollHeight = MIN(readinessScrollHeight, NSHeight(readinessFrame));
    readinessScrollHeight = MAX(0.0, readinessScrollHeight);

    NSRect readinessSectionFrame = NSMakeRect(readinessFrame.origin.x,
                                              readinessTopY + SlateInspectorRailSectionHeaderYOffset(),
                                              readinessFrame.size.width,
                                              sectionLabelHeight);
    NSRect readinessStatusFrame = NSMakeRect(readinessFrame.origin.x,
                                             readinessStatusY,
                                             readinessFrame.size.width,
                                             readinessStatusHeight);
    NSRect readinessScrollFrame = NSMakeRect(readinessFrame.origin.x,
                                            readinessScrollBottomY,
                                            readinessFrame.size.width,
                                            readinessScrollHeight);
    NSRect pinFrame = NSMakeRect(NSMaxX(readinessFrame) - SlateInspectorRailPinControlWidth(),
                                 NSMinY(readinessSectionFrame),
                                 SlateInspectorRailPinControlWidth(),
                                 SlateInspectorRailDisclosureRowHeight());
    [_readinessPresenter applySectionFrame:readinessSectionFrame
                               statusFrame:readinessStatusFrame
                               scrollFrame:readinessScrollFrame
                                  pinFrame:pinFrame
                                pinVisible:YES];
    [self updateTrackReadinessPanelPresentation];
    [self restoreTrackReadinessSubviewOrderIfNeeded];
}

- (void)applyTrackInspectorRailFrame:(NSRect)inspectorFrame
                         layoutBounds:(NSRect)layoutBounds
                               gutter:(CGFloat)gutter
                     readinessBottomY:(CGFloat)readinessBottomY
                   sectionLabelHeight:(CGFloat)sectionLabelHeight
                    showReadinessRail:(BOOL)showReadinessRail
{
    [_trackInspectorSurface setHidden:NO];
    [_advancedSectionLabel setHidden:NO];

    CGFloat advancedGroupInsetX = SMTrackAdvancedGroupInsetX;
    advancedGroupInsetX = MIN(advancedGroupInsetX,
                              MAX(0.0, gutter - SMTrackMinimumInterColumnGap));
    CGFloat advancedHeaderInsetX = SMTrackAdvancedHeaderInsetX;
    CGFloat advancedHeaderTopInset = SMTrackAdvancedHeaderTopInset;
    // Keep T + M fixed-height; readiness absorbs vertical headroom.
    CGFloat advancedGroupTopY = NSMaxY(inspectorFrame);
    CGFloat advancedGroupBottomY = readinessBottomY;
    NSRect advancedContentFrame = inspectorFrame;
    if (advancedGroupTopY > advancedGroupBottomY) {
        NSRect advancedGroupFrame = NSMakeRect(inspectorFrame.origin.x - advancedGroupInsetX,
                                               advancedGroupBottomY,
                                               inspectorFrame.size.width + (advancedGroupInsetX * 2.0),
                                               advancedGroupTopY - advancedGroupBottomY);
        if (!showReadinessRail) {
            // Keep the rightmost active rail edge on the shared inset contract
            // when readiness drops in class-1 layouts, while preserving left
            // alignment with the table/inspector gutter.
            CGFloat desiredRightEdge = NSMaxX(layoutBounds) - SlateInspectorRailRightInset();
            advancedGroupFrame.size.width = MAX(1.0, desiredRightEdge - NSMinX(advancedGroupFrame));
        }
        [_advancedGroupBox setFrame:advancedGroupFrame];
        [_advancedGroupBox setHidden:NO];
        advancedContentFrame = advancedGroupFrame;
        [_advancedSectionLabel setFrame:NSMakeRect(NSMinX(advancedGroupFrame) + advancedHeaderInsetX,
                                                   NSMaxY(advancedGroupFrame) - sectionLabelHeight - advancedHeaderTopInset,
                                                   MAX(1.0, NSWidth(advancedGroupFrame) - advancedHeaderInsetX - 8.0),
                                                   sectionLabelHeight)];
    } else {
        [_advancedGroupBox setHidden:YES];
        [_advancedSectionLabel setFrame:NSMakeRect(inspectorFrame.origin.x,
                                                   NSMaxY(advancedContentFrame) + SlateInspectorRailSectionHeaderYOffset(),
                                                   inspectorFrame.size.width,
                                                   sectionLabelHeight)];
    }

    [_trackInspectorSurface setFrame:advancedContentFrame];
    [self layoutDynamicTrackInspectorSurfaceForReferenceBounds:NSMakeRect(0.0,
                                                                          0.0,
                                                                          NSWidth(inspectorFrame),
                                                                          NSHeight(inspectorFrame))];

    NSRect advancedHeaderFrame = [_advancedSectionLabel frame];
    NSRect copyButtonAnchorFrame = [_advancedGroupBox isHidden] ? inspectorFrame : [_advancedGroupBox frame];
    [_trackInspectorCopyButton setHidden:NO];
    [_trackInspectorCopyButton setFrame:NSMakeRect(NSMaxX(copyButtonAnchorFrame) - SMTrackInspectorCopyButtonSize - SMTrackInspectorCopyButtonRightInset,
                                                   floor(NSMinY(advancedHeaderFrame) + ((NSHeight(advancedHeaderFrame) - SMTrackInspectorCopyButtonSize) * 0.5)),
                                                   SMTrackInspectorCopyButtonSize,
                                                   SMTrackInspectorCopyButtonSize)];
    [[self view] addSubview:_trackInspectorCopyButton positioned:NSWindowAbove relativeTo:nil];
}

- (void)applyTrackTwoPaneLayoutForWidthClass:(SMWorkspaceWidthClass)widthClass
{
    [self ensureTrackLayoutSupplementaryViews];

    NSScrollView *tracksScrollView = [_tracks enclosingScrollView];
    if (tracksScrollView == nil || _trackInspectorSurface == nil) {
        [_tracksSectionLabel setHidden:YES];
        [_tracksStateLabel setHidden:YES];
        [_advancedSectionLabel setHidden:YES];
        [_trackInspectorCopyButton setHidden:YES];
        [self hideTrackReadinessRail];
        [_advancedGroupBox setHidden:YES];
        return;
    }

    NSRect viewBounds = [[self view] bounds];
    NSRect defaultRootFrame = SMTrackDefaultRootFrame();
    NSRect layoutBounds = SlateWorkspaceCenteredContentEnvelope(viewBounds,
                                                                NSWidth(defaultRootFrame),
                                                                NSHeight(defaultRootFrame),
                                                                SlateWorkspaceHorizontalExpansionAllowance(),
                                                                SlateWorkspaceVerticalExpansionAllowance());
    CGFloat leadingInset = SlateWorkspacePrimaryPaneTableAnchorX();
    // Keep right-edge choreography deterministic across 2 -> 1 breaks: always
    // honor the shared rail inset contract rather than drifting with live frames.
    CGFloat trailingInset = MAX(SlateWorkspaceTrailingInsetMinimum(), SlateInspectorRailRightInset());
    CGFloat railBottomY = NSMinY(layoutBounds) + SlateInspectorRailEffectiveBottomInsetForHostView([self view]);
    CGFloat sectionLabelHeight = SlateInspectorRailSectionHeaderHeight();
    CGFloat sectionGap = SlateInspectorRailSectionGap();
    CGFloat designContentTopY = SlateWorkspacePrimaryPaneTableAnchorTopY()
        + sectionLabelHeight
        + SlateInspectorRailSectionHeaderYOffset();
    CGFloat railContentTopY = NSMaxY(layoutBounds) - (NSHeight(defaultRootFrame) - designContentTopY);
    CGFloat verticalGrowth = MAX(0.0, NSHeight(layoutBounds) - NSHeight(defaultRootFrame));
    CGFloat desiredTableContentTopY = NSMinY(layoutBounds) + designContentTopY + verticalGrowth;
    CGFloat maxTableContentTopY = railBottomY + SMTrackMaximumTableHeightForVisibleRows();
    CGFloat tableContentTopY = MIN(MIN(desiredTableContentTopY, maxTableContentTopY),
                                   railContentTopY);
    CGFloat readinessTopYAnchor = railContentTopY
        - sectionLabelHeight
        - SlateInspectorRailSectionHeaderYOffset();
    CGFloat bandWidth = MAX(320.0, NSWidth(layoutBounds) - leadingInset - trailingInset);
    NSRect bandFrame = NSMakeRect(NSMinX(layoutBounds) + leadingInset,
                                  railBottomY,
                                  bandWidth,
                                  MAX(1.0, tableContentTopY - railBottomY));
    CGFloat tableContentHeight = MAX(1.0, tableContentTopY - bandFrame.origin.y);
    CGFloat gutter = SMTrackRailGutter;
    CGFloat workspaceWidth = NSWidth(layoutBounds);
    BOOL forceTableOnlyRail = (widthClass == SMWorkspaceWidthClass0 && !_inspectorRailPinned);
    if (forceTableOnlyRail) {
        NSRect tableFrame = NSMakeRect(bandFrame.origin.x,
                                       bandFrame.origin.y,
                                       MAX(0.0, bandFrame.size.width),
                                       tableContentHeight);
        [tracksScrollView setFrame:tableFrame];

        [_trackInspectorSurface setHidden:YES];
        [_advancedSectionLabel setHidden:YES];
        [_trackInspectorCopyButton setHidden:YES];
        [_advancedGroupBox setHidden:YES];
        [self hideTrackReadinessRail];

        [self updateTrackStateLabelPresentation];
        return;
    }

    BOOL forceReadinessOnlyRail = ((widthClass == SMWorkspaceWidthClass0) && _inspectorRailPinned)
        || (widthClass == SMWorkspaceWidthClass1)
        || ((widthClass == SMWorkspaceWidthClass2)
            && (workspaceWidth <= SlateWorkspaceRailBreakWidthClass2To1()));
    if (forceReadinessOnlyRail) {
        CGFloat readinessWidth = SlateInspectorRailFixedWidth();
        CGFloat readinessRightInset = SlateInspectorRailRightInset();
        CGFloat readinessBottomY = railBottomY;
        CGFloat readinessFrameX = NSMaxX(layoutBounds) - readinessRightInset - readinessWidth;
        NSRect tableFrame = NSMakeRect(bandFrame.origin.x,
                                       bandFrame.origin.y,
                                       MAX(0.0, readinessFrameX - gutter - bandFrame.origin.x),
                                       tableContentHeight);
        NSRect readinessFrame = NSMakeRect(readinessFrameX,
                                           readinessBottomY,
                                           readinessWidth,
                                           MAX(SlateInspectorRailWarningBlockMinHeight(),
                                               railContentTopY - readinessBottomY));
        [tracksScrollView setFrame:tableFrame];

        [_trackInspectorSurface setHidden:YES];
        [_advancedSectionLabel setHidden:YES];
        [_trackInspectorCopyButton setHidden:YES];
        [_advancedGroupBox setHidden:YES];

        [self applyTrackReadinessRailFrame:readinessFrame
                       readinessTopYAnchor:readinessTopYAnchor
                        sectionLabelHeight:sectionLabelHeight
                                sectionGap:sectionGap];

        [self updateTrackStateLabelPresentation];
        return;
    }
    CGFloat readinessBottomY = railBottomY;
    SMTrackFixedRailLayout fixedLayout = SMTrackResolveFixedRailLayout(widthClass,
                                                                       _inspectorRailPinned,
                                                                       layoutBounds,
                                                                       bandFrame,
                                                                       railBottomY,
                                                                       tableContentTopY,
                                                                       railContentTopY);
    [tracksScrollView setFrame:fixedLayout.tableFrame];

    if (!fixedLayout.showInspectorRail) {
        [_trackInspectorSurface setHidden:YES];
        [_advancedSectionLabel setHidden:YES];
        [_trackInspectorCopyButton setHidden:YES];
        [_advancedGroupBox setHidden:YES];
        if (fixedLayout.showReadinessRail) {
            [self applyTrackReadinessRailFrame:fixedLayout.readinessFrame
                           readinessTopYAnchor:readinessTopYAnchor
                            sectionLabelHeight:sectionLabelHeight
                                    sectionGap:sectionGap];
        } else {
            [self hideTrackReadinessRail];
        }
        [self updateTrackStateLabelPresentation];
        return;
    }

    [self applyTrackInspectorRailFrame:fixedLayout.inspectorFrame
                          layoutBounds:layoutBounds
                                gutter:gutter
                      readinessBottomY:readinessBottomY
                    sectionLabelHeight:sectionLabelHeight
                     showReadinessRail:fixedLayout.showReadinessRail];

    if (fixedLayout.showReadinessRail) {
        [self applyTrackReadinessRailFrame:fixedLayout.readinessFrame
                       readinessTopYAnchor:readinessTopYAnchor
                        sectionLabelHeight:sectionLabelHeight
                                sectionGap:sectionGap];
    } else {
        [self hideTrackReadinessRail];
    }

    if (fixedLayout.showReadinessRail && [_readinessPresenter pinButton] != nil) {
        // Keep pin above rail labels/scroll content so clicks are never swallowed.
        [[self view] addSubview:[_readinessPresenter pinButton] positioned:NSWindowAbove relativeTo:nil];
    }
    [self restoreTrackReadinessSubviewOrderIfNeeded];

    [self updateTrackStateLabelPresentation];
}

#pragma mark - Pinning and Workspace Layout

- (void)setInspectorRailPinned:(BOOL)pinned
{
    if (_inspectorRailPinned == pinned) {
        return;
    }

    _inspectorRailPinned = pinned;
    [_readinessPresenter setPinState:pinned];
    [[NSUserDefaults standardUserDefaults] setBool:pinned forKey:SMTrackInspectorRailPinnedDefaultsKey];
}

- (IBAction)toggleInspectorRailPinned:(id)sender
{
    BOOL pinned = !_inspectorRailPinned;
    if ([sender isKindOfClass:[NSButton class]]) {
        NSInteger senderState = [(NSButton *)sender state];
        if (senderState == NSOnState || senderState == NSOffState) {
            BOOL requestedPinned = (senderState == NSOnState);
            if (requestedPinned != _inspectorRailPinned) {
                pinned = requestedPinned;
            }
        }
    }
    [self setInspectorRailPinned:pinned];
    [self applyWorkspaceLayoutForWidth:NSWidth([[self view] bounds])];
}

- (void)applyWorkspaceLayoutForWidth:(CGFloat)workspaceWidth
{
    SMWorkspaceWidthClass widthClass = SMWorkspaceWidthClassForWidth(workspaceWidth);

    [self applyTrackTwoPaneLayoutForWidthClass:widthClass];
    [self applyPrimaryTrackTableColumnWidths];

    [[_tracks headerView] setNeedsDisplay:YES];
}

- (void)tableViewColumnDidResize:(NSNotification *)notification
{
    if ([notification object] != _tracks) {
        return;
    }

    [self persistResizableTrackColumnWidths];
}

- (void)updateTrackStateLabelPresentation
{
    [self ensureTrackLayoutSupplementaryViews];
    [_tracksStateLabel setHidden:YES];
}

#pragma mark - Mode Switch and Probe

- (NSDictionary *)modeSwitchContextSnapshot
{
    NSMutableDictionary *snapshot = [NSMutableDictionary dictionary];
    [snapshot setObject:[NSNumber numberWithInteger:[_tracks selectedRow]]
                 forKey:@"tracksSelectedRow"];

    NSDictionary *tracksScrollSnapshot = SMTrackScrollSnapshotForScrollView([_tracks enclosingScrollView]);
    if (tracksScrollSnapshot != nil) {
        [snapshot setObject:tracksScrollSnapshot forKey:@"tracksScroll"];
    }

    NSDictionary *readinessScrollSnapshot = SMTrackScrollSnapshotForScrollView([_readinessPresenter scrollView]);
    if (readinessScrollSnapshot != nil) {
        [snapshot setObject:readinessScrollSnapshot forKey:@"readinessScroll"];
    }

    return snapshot;
}

- (NSDictionary *)layoutProbeSnapshot
{
    NSView *rootView = [self view];
    NSRect rootBounds = (rootView != nil) ? [rootView bounds] : NSZeroRect;
    NSScrollView *tracksScrollView = [_tracks enclosingScrollView];
    NSScrollView *readinessScrollView = [_readinessPresenter scrollView];
    NSTextField *readinessSectionLabel = [_readinessPresenter sectionLabel];
    NSButton *inspectorPinButton = [_readinessPresenter pinButton];
    NSRect tableFrame = (tracksScrollView != nil) ? [tracksScrollView frame] : NSZeroRect;
    NSRect inspectorFrame = (_trackInspectorSurface != nil) ? [_trackInspectorSurface frame] : NSZeroRect;
    NSRect inspectorGroupFrame = (_advancedGroupBox != nil) ? [_advancedGroupBox frame] : NSZeroRect;
    NSRect readinessFrame = (readinessScrollView != nil) ? [readinessScrollView frame] : NSZeroRect;
    NSRect readinessLabelFrame = (readinessSectionLabel != nil) ? [readinessSectionLabel frame] : NSZeroRect;
    NSRect pinFrame = (inspectorPinButton != nil) ? [inspectorPinButton frame] : NSZeroRect;

    BOOL inspectorVisible = (_trackInspectorSurface != nil && ![_trackInspectorSurface isHidden] && NSWidth(inspectorFrame) > 0.0)
        || (_advancedGroupBox != nil && ![_advancedGroupBox isHidden] && NSWidth(inspectorGroupFrame) > 0.0);
    BOOL readinessVisible = (readinessScrollView != nil && ![readinessScrollView isHidden] && NSWidth(readinessFrame) > 0.0);
    BOOL pinVisible = (inspectorPinButton != nil && ![inspectorPinButton isHidden]);
    CGFloat rootMaxX = NSMaxX(rootBounds);

    NSMutableDictionary *layoutProbe = [NSMutableDictionary dictionary];
    [layoutProbe setObject:SMTrackProbeRect(rootBounds) forKey:@"rootBounds"];
    [layoutProbe setObject:[NSNumber numberWithDouble:NSWidth(rootBounds)] forKey:@"workspaceWidth"];
    [layoutProbe setObject:SMTrackProbeWidthClassCode(NSWidth(rootBounds)) forKey:@"workspaceWidthClass"];
    [layoutProbe setObject:[NSNumber numberWithBool:inspectorVisible] forKey:@"showInspectorRail"];
    [layoutProbe setObject:[NSNumber numberWithBool:readinessVisible] forKey:@"showReadinessRail"];
    [layoutProbe setObject:[NSNumber numberWithBool:pinVisible] forKey:@"pinVisible"];
    [layoutProbe setObject:[NSNumber numberWithBool:_inspectorRailPinned] forKey:@"pinState"];
    [layoutProbe setObject:SMTrackProbeRect(tableFrame) forKey:@"tableFrame"];
    [layoutProbe setObject:SMTrackProbeRect(inspectorFrame) forKey:@"inspectorFrame"];
    [layoutProbe setObject:SMTrackProbeRect(inspectorGroupFrame) forKey:@"inspectorGroupFrame"];
    [layoutProbe setObject:SMTrackProbeRect(readinessFrame) forKey:@"readinessFrame"];
    [layoutProbe setObject:SMTrackProbeRect(readinessLabelFrame) forKey:@"readinessLabelFrame"];
    [layoutProbe setObject:SMTrackProbeRect(pinFrame) forKey:@"pinFrame"];

    if (inspectorVisible && NSWidth(tableFrame) > 0.0) {
        [layoutProbe setObject:[NSNumber numberWithDouble:(NSMinX(inspectorGroupFrame) - NSMaxX(tableFrame))]
                        forKey:@"gapTableToInspector"];
        [layoutProbe setObject:[NSNumber numberWithDouble:(rootMaxX - NSMaxX(inspectorGroupFrame))]
                        forKey:@"rightInsetInspector"];
    }
    if (inspectorVisible && readinessVisible) {
        [layoutProbe setObject:[NSNumber numberWithDouble:(NSMinX(readinessFrame) - NSMaxX(inspectorGroupFrame))]
                        forKey:@"gapInspectorToReadiness"];
    }
    if (readinessVisible) {
        [layoutProbe setObject:[NSNumber numberWithDouble:(rootMaxX - NSMaxX(readinessFrame))]
                        forKey:@"rightInsetReadiness"];
    }
    if (pinVisible && readinessSectionLabel != nil) {
        [layoutProbe setObject:[NSNumber numberWithDouble:(NSMinY(pinFrame) - NSMinY(readinessLabelFrame))]
                        forKey:@"pinLabelDeltaY"];
    }

    return layoutProbe;
}

- (void)restoreModeSwitchContextSnapshot:(NSDictionary *)snapshot
{
    if (![snapshot isKindOfClass:[NSDictionary class]]) {
        return;
    }

    NSInteger rowCount = [_track count];
    NSNumber *selectedRowValue = [snapshot objectForKey:@"tracksSelectedRow"];
    if ([selectedRowValue isKindOfClass:[NSNumber class]]) {
        NSInteger selectedRow = [selectedRowValue integerValue];
        if (selectedRow >= 0 && selectedRow < rowCount) {
            if ([_tracks selectedRow] != selectedRow) {
                [_tracks selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
            }
        } else if (selectedRow < 0 && [_tracks selectedRow] != -1) {
            [_tracks deselectAll:nil];
        }
    }

    NSDictionary *tracksScrollSnapshot = [snapshot objectForKey:@"tracksScroll"];
    SMTrackRestoreScrollSnapshotForScrollView([_tracks enclosingScrollView], tracksScrollSnapshot);

    NSDictionary *readinessScrollSnapshot = [snapshot objectForKey:@"readinessScroll"];
    SMTrackRestoreScrollSnapshotForScrollView([_readinessPresenter scrollView], readinessScrollSnapshot);

    [self tableViewSelectionDidChange:[NSNotification notificationWithName:NSTableViewSelectionDidChangeNotification
                                                                    object:_tracks]];
}

- (NSInteger)trackRowCount
{
    NSArray *rows = [[self trackSnapshot] objectForKey:SlateTrackSnapshotKeyRows];
    NSInteger modelRowCount = [_track count];
    if ([rows isKindOfClass:[NSArray class]]) {
        return MAX((NSInteger)[rows count], modelRowCount);
    }
    return modelRowCount;
}

- (NSView *)preferredModeFirstResponderView
{
    return _tracks;
}

#pragma mark - Row Snapshots

- (SMTrackRowSnapshot *)trackRowSnapshotAtIndex:(NSInteger)rowIndex
{
    if (rowIndex < 0 || rowIndex >= (NSInteger)[_track count]) {
        return nil;
    }

    TrackItem *trackItem = [_track objectAtIndex:rowIndex];
    return [SMTrackRowSnapshot snapshotWithTrackItem:trackItem rowIndex:rowIndex];
}

- (NSArray *)trackRowSnapshots
{
    NSMutableArray *snapshots = [NSMutableArray arrayWithCapacity:[_track count]];
    for (NSInteger rowIndex = 0; rowIndex < (NSInteger)[_track count]; rowIndex++) {
        SMTrackRowSnapshot *snapshot = [self trackRowSnapshotAtIndex:rowIndex];
        if (snapshot != nil) {
            [snapshots addObject:snapshot];
        }
    }

    return snapshots;
}

- (void)invalidateTrackSnapshot
{
    [_trackSnapshot release];
    _trackSnapshot = nil;
}

- (void)rebuildTrackSnapshot
{
    SMMovie *movie = SMTrackCurrentMovieFromAppController();
    NSDictionary *snapshot = [SlateRuntimeBridge trackSnapshotForMovie:movie
                                                               hasMovie:(movie != nil)];
    [_trackSnapshot release];
    _trackSnapshot = [snapshot retain];
}

- (NSDictionary *)trackSnapshot
{
    if (_trackSnapshot == nil) {
        [self rebuildTrackSnapshot];
    }
    return _trackSnapshot;
}

- (NSArray *)validationObservedTrackRows
{
    NSArray *rows = [[self trackSnapshot] objectForKey:SlateTrackSnapshotKeyRows];
    return [rows isKindOfClass:[NSArray class]] ? rows : [NSArray array];
}

- (NSInteger)selectedAssetTypeID
{
    if (_assetTypePopup == nil || [_assetTypePopup indexOfSelectedItem] == 0) {
        return 0;
    }
    return [_assetTypePopup selectedTag];
}

- (NSDictionary *)trackSnapshotRowAtIndex:(NSInteger)rowIndex
{
    NSArray *rows = [[self trackSnapshot] objectForKey:SlateTrackSnapshotKeyRows];
    if (![rows isKindOfClass:[NSArray class]]
        || rowIndex < 0
        || rowIndex >= (NSInteger)[rows count]) {
        return nil;
    }

    NSDictionary *row = [rows objectAtIndex:rowIndex];
    return [row isKindOfClass:[NSDictionary class]] ? row : nil;
}

- (NSArray *)sortedTrackSnapshotRows
{
    NSArray *rows = [[self trackSnapshot] objectForKey:SlateTrackSnapshotKeyRows];
    if (![rows isKindOfClass:[NSArray class]]) {
        return [NSArray array];
    }

    NSMutableArray *sortedRows = [NSMutableArray arrayWithArray:rows];
    NSSortDescriptor *trackIDSort = [[[NSSortDescriptor alloc] initWithKey:SlateTrackSnapshotRowKeyTrackID ascending:YES] autorelease];
    NSSortDescriptor *rowSort = [[[NSSortDescriptor alloc] initWithKey:SlateTrackSnapshotRowKeyRow ascending:YES] autorelease];
    [sortedRows sortUsingDescriptors:[NSArray arrayWithObjects:trackIDSort, rowSort, nil]];

    return sortedRows;
}

- (NSArray *)trackMovieInspectorDetailRows
{
    NSMutableArray *rows = [NSMutableArray arrayWithCapacity:[_track count]];

    for (NSDictionary *snapshotRow in [self sortedTrackSnapshotRows]) {
        NSMutableDictionary *row = [NSMutableDictionary dictionary];
        [row setObject:[snapshotRow objectForKey:SlateTrackSnapshotRowKeyRowIndex] forKey:@"rowIndex"];
        [row setObject:[snapshotRow objectForKey:SlateTrackSnapshotRowKeyRow] forKey:@"row"];
        [row setObject:[snapshotRow objectForKey:SlateTrackSnapshotRowKeyTrackID] forKey:@"trackID"];
        [row setObject:SlateTrackSnapshotRowString(snapshotRow, SlateTrackSnapshotRowKeyTrackType) forKey:@"trackType"];
        [row setObject:SlateTrackSnapshotRowString(snapshotRow, SlateTrackSnapshotRowKeyMediaType) forKey:@"mediaType"];
        [row setObject:SlateTrackSnapshotRowString(snapshotRow, SlateTrackSnapshotRowKeyEnabled) forKey:@"enabled"];
        [row setObject:[snapshotRow objectForKey:SlateTrackSnapshotRowKeyReferenceTrack] forKey:@"referenceTrack"];
        [row setObject:SlateTrackSnapshotRowString(snapshotRow, SlateTrackSnapshotRowKeyDuration) forKey:@"duration"];
        [row setObject:SlateTrackSnapshotRowString(snapshotRow, SlateTrackSnapshotRowKeyLanguage) forKey:@"language"];
        [row setObject:SlateTrackSnapshotRowString(snapshotRow, SlateTrackSnapshotRowKeyDisplayName) forKey:@"displayName"];
        [row setObject:SlateTrackSnapshotRowString(snapshotRow, SlateTrackSnapshotRowKeyFormatSummary) forKey:@"formatSummary"];
        [row setObject:([[snapshotRow objectForKey:SlateTrackSnapshotRowKeyDetails] isKindOfClass:[NSArray class]] ? [snapshotRow objectForKey:SlateTrackSnapshotRowKeyDetails] : [NSArray array]) forKey:@"details"];
        [row setObject:SlateTrackSnapshotRowString(snapshotRow, SlateTrackSnapshotRowKeyDetailsText) forKey:@"detailsText"];

        NSString *sourcePath = [snapshotRow objectForKey:SlateTrackSnapshotRowKeySourcePath];
        if ([sourcePath isKindOfClass:[NSString class]] && [sourcePath length] > 0) {
            [row setObject:sourcePath forKey:@"sourcePath"];
        }

        [rows addObject:row];
    }

    return rows;
}

- (SMTrackRowSnapshot *)selectedTrackRowSnapshot
{
    return [self trackRowSnapshotAtIndex:[_tracks selectedRow]];
}

#pragma mark - Inspector Details

-(void)updateInspectorGainControlsForSnapshot:(SMTrackRowSnapshot *)snapshot
{
    BOOL isAudioTrack = [snapshot isAudioTrack];
    BOOL isVideoTrack = (snapshot == nil || [snapshot isVideoTrack]);
    BOOL showsGain = (isAudioTrack || isVideoTrack);
    _gainSliderTargetsMovie = !isAudioTrack;

    [_gainSlider setHidden:!showsGain];
    [_gainSlider setEnabled:showsGain];
    [_gainLabel setHidden:!showsGain];
    [_gainMinLabel setHidden:!showsGain];
    [_gainMidLabel setHidden:!showsGain];
    [_gainMaxLabel setHidden:!showsGain];

    if (!showsGain) {
        return;
    }

    if (isAudioTrack) {
        [_gainSlider setFloatValue:[snapshot audioGain]];
        return;
    }

    SMMovie *movie = SMTrackCurrentMovieFromAppController();
    [_gainSlider setFloatValue:(movie != nil ? [movie audioGain] : 1.0)];
}

- (NSArray *)trackInspectorDetailPairsForTrackRowSnapshot:(SMTrackRowSnapshot *)snapshot
{
    if (snapshot == nil) {
        return [NSArray array];
    }

    NSMutableArray *pairs = [NSMutableArray array];
    SMTrack *track = [snapshot track];
    NSString *mediaType = [snapshot mediaType];
    NSString *displayName = [snapshot displayName];
    NSString *formatSummary = [snapshot formatSummary];
    NSURL *sourceURL = [snapshot sourceURL];
    BOOL isAudioTrack = [snapshot isAudioTrack];
    BOOL isVideoTrack = [snapshot isVideoTrack];
    BOOL isTimecodeTrack = [snapshot isTimecodeTrack];
    BOOL isSubtitleTrack = [snapshot isSubtitleTrack] || SMTrackMediaTypeMatches(mediaType, SMMediaTypeSubtitle);
    BOOL isClosedCaptionTrack = [snapshot isClosedCaptionTrack] || SMTrackMediaTypeMatches(mediaType, SMMediaTypeClosedCaption);
    BOOL isTextTrack = [snapshot isTextTrack];
    NSString *enabledString = [snapshot enabledDisplayString];

    if (isAudioTrack && track != nil) {
        SMTrackAppendDetailsPairToArray(pairs, @"Enabled", enabledString);
        SMTrackAppendDetailsPairToArray(pairs, @"Reference Track", [snapshot isReferenceTrack] ? @"Yes" : @"No");
        SMTrackAppendDetailsPairToArray(pairs, @"Duration", [snapshot durationString]);
        SMTrackAppendDetailsPairToArray(pairs, @"Language", [snapshot language]);
        SMTrackAppendDetailsPairToArray(pairs, @"Display Name", displayName);
        SMTrackAppendDetailsPairToArray(pairs, @"Format Summary", formatSummary);
        SMTrackAppendDetailsPairToArray(pairs, @"Audio Gain", [NSString stringWithFormat:@"%.2f", [snapshot audioGain]]);
        SMTrackAppendDetailsPairToArray(pairs, @"Channel Layout", @"Runtime unavailable");
    }
    else if (isTimecodeTrack) {
        SMTrackAppendDetailsPairToArray(pairs, @"Enabled", enabledString);
        SMTrackAppendDetailsPairToArray(pairs, @"Reference Track", [snapshot isReferenceTrack] ? @"Yes" : @"No");
        SMTrackAppendDetailsPairToArray(pairs, @"Duration", [snapshot durationString]);
        SMTrackAppendDetailsPairToArray(pairs, @"Language", [snapshot language]);
        SMTrackAppendDetailsPairToArray(pairs, @"Role", @"Timecode");
        SMTrackAppendDetailsPairToArray(pairs, @"Display Name", displayName);
        SMTrackAppendDetailsPairToArray(pairs, @"Format Summary", formatSummary);
    }
    else if (isVideoTrack) {
        SMTrackAppendDetailsPairToArray(pairs, @"Enabled", enabledString);
        SMTrackAppendDetailsPairToArray(pairs, @"Reference Track", [snapshot isReferenceTrack] ? @"Yes" : @"No");
        SMTrackAppendDetailsPairToArray(pairs, @"Duration", [snapshot durationString]);
        SMTrackAppendDetailsPairToArray(pairs, @"Display Name", displayName);

        NSString *encodedSize = SMTrackSizeDescription((CGFloat)[snapshot encodedWidth], (CGFloat)[snapshot encodedHeight]);
        if (encodedSize.length > 0) {
            SMTrackAppendDetailsPairToArray(pairs, @"Encoded Size", encodedSize);
        }

        NSString *displaySize = SMTrackSizeDescription((CGFloat)[snapshot displayWidth], (CGFloat)[snapshot displayHeight]);
        if (displaySize.length > 0) {
            SMTrackAppendDetailsPairToArray(pairs, @"Display Size", displaySize);
        }

        for (NSDictionary *pair in [track videoInspectorDetailPairs]) {
            if (![pair isKindOfClass:[NSDictionary class]]) {
                continue;
            }

            SMTrackAppendDetailsPairToArray(pairs,
                                            [pair objectForKey:@"key"],
                                            [pair objectForKey:@"value"]);
        }

        SMTrackAppendDetailsPairToArray(pairs, @"Format Summary", formatSummary);
    }
    else if (isSubtitleTrack || isClosedCaptionTrack || isTextTrack) {
        SMTrackAppendDetailsPairToArray(pairs, @"Enabled", enabledString);
        SMTrackAppendDetailsPairToArray(pairs, @"Reference Track", [snapshot isReferenceTrack] ? @"Yes" : @"No");
        SMTrackAppendDetailsPairToArray(pairs, @"Duration", [snapshot durationString]);
        SMTrackAppendDetailsPairToArray(pairs, @"Language", [snapshot language]);
        SMTrackAppendDetailsPairToArray(pairs, @"Role", [snapshot textTrackRoleLabel]);
        SMTrackAppendDetailsPairToArray(pairs, @"Display Name", displayName);
        SMTrackAppendDetailsPairToArray(pairs, @"Format Summary", formatSummary);
    }
    else {
        SMTrackAppendDetailsPairToArray(pairs, @"Enabled", enabledString);
        SMTrackAppendDetailsPairToArray(pairs, @"Reference Track", [snapshot isReferenceTrack] ? @"Yes" : @"No");
        SMTrackAppendDetailsPairToArray(pairs, @"Duration", [snapshot durationString]);
        SMTrackAppendDetailsPairToArray(pairs, @"Language", [snapshot language]);
        SMTrackAppendDetailsPairToArray(pairs, @"Display Name", displayName);
        SMTrackAppendDetailsPairToArray(pairs, @"Format Summary", formatSummary);
    }

    SMTrackAppendDetailsPairToArray(pairs, @"Media Type", mediaType);
    if ([sourceURL isKindOfClass:[NSURL class]] && [sourceURL isFileURL]) {
        SMTrackAppendDetailsPairToArray(pairs, @"Source Path", [sourceURL path]);
    }

    return pairs;
}

- (NSString *)trackInspectorDetailsStringForTrackRowSnapshot:(SMTrackRowSnapshot *)snapshot
{
    if (snapshot == nil) {
        return SMTrackInspectorDetailsEmptyMessage;
    }

    SMTrack *track = [snapshot track];
    NSString *trackType = (track != nil) ? [snapshot trackTypeLabel] : @"(none)";
    NSMutableString *details = [NSMutableString stringWithFormat:@"Row: %ld | Track ID: %d | Track Type: %@\n\n",
                                (long)[snapshot rowIndex] + 1,
                                [snapshot ident],
                                SMTrackDetailsSafeString(trackType)];

    for (NSDictionary *pair in [self trackInspectorDetailPairsForTrackRowSnapshot:snapshot]) {
        if (![pair isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        SMTrackAppendDetailsPair(details,
                                 [pair objectForKey:SlateTrackSnapshotDetailKeyKey],
                                 [pair objectForKey:SlateTrackSnapshotDetailKeyValue]);
    }

    return details;
}

- (void)updateTrackInspectorDetailsText
{
    if (_trackInspectorDetailsTextView == nil) {
        return;
    }
    NSString *detailsText = SlateTrackSnapshotRowString([self trackSnapshotRowAtIndex:[_tracks selectedRow]],
                                                     SlateTrackSnapshotRowKeyDetailsText);
    if (![detailsText isKindOfClass:[NSString class]] || [detailsText length] == 0) {
        detailsText = SMTrackInspectorDetailsEmptyMessage;
    }
    if ([detailsText isEqualToString:[_trackInspectorDetailsTextView string]]) {
        return;
    }
    NSAttributedString *detailsAttributed = SMTrackDetailsAttributedString(detailsText);
    [[_trackInspectorDetailsTextView textStorage] setAttributedString:detailsAttributed];
}

- (IBAction)copyTrackInspectorDetails:(id)sender
{
    #pragma unused(sender)
    NSString *detailsText = nil;

    if (_trackInspectorDetailsTextView != nil) {
        NSString *textViewContents = [_trackInspectorDetailsTextView string];
        NSRange selectedRange = [_trackInspectorDetailsTextView selectedRange];
        if ([textViewContents isKindOfClass:[NSString class]]
            && selectedRange.length > 0
            && NSMaxRange(selectedRange) <= [textViewContents length]) {
            detailsText = [textViewContents substringWithRange:selectedRange];
        } else {
            detailsText = textViewContents;
        }
    }

    if (!SMTrackStringHasContent(detailsText)) {
        detailsText = SlateTrackSnapshotRowString([self trackSnapshotRowAtIndex:[_tracks selectedRow]],
                                               SlateTrackSnapshotRowKeyDetailsText);
    }

    if (!SMTrackStringHasContent(detailsText)) {
        return;
    }

    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [pasteboard setString:detailsText forType:NSPasteboardTypeString];
    [appcontroller() showStatusMessage:@"Copied track inspector details." persist:NO];
}

#pragma mark - Package Input

-(void)reloadTracksTableSelectingFirstRowIfNeeded
{
    [self invalidateTrackSnapshot];
    [_tracks reloadData];
    [self updateTrackStateLabelPresentation];

    NSInteger rowCount = [_track count];
    if (rowCount <= 0)
    {
        [self updateInspectorGainControlsForSnapshot:nil];
        [self updateTrackInspectorDetailsText];
        return;
    }

    NSInteger selectedRow = [_tracks selectedRow];
    if (selectedRow < 0 || selectedRow >= rowCount)
    {
        NSIndexSet *firstRowIndexSet = [NSIndexSet indexSetWithIndex:0];
        [_tracks selectRowIndexes:firstRowIndexSet byExtendingSelection:NO];
        [_tracks scrollRowToVisible:0];

        if ([_tracks window] != nil)
            [[_tracks window] makeFirstResponder:_tracks];
    }

    [self updateTrackInspectorDetailsText];
}

-(void)assetTypeFromPackageContext:(NSDictionary *)packageContext
{
    NSDictionary *primaryAsset = [packageContext objectForKey:SlatePackageContextKeyPrimaryAsset];
    if (![primaryAsset isKindOfClass:[NSDictionary class]]) {
        [_assetTypePopup selectItemWithTag:0];
        return;
    }

    NSString *assetType = [primaryAsset objectForKey:SlatePackageContextPrimaryAssetKeyAssetTypeID];
    if (assetType == nil) {
        [_assetTypePopup selectItemWithTag:0];
        return;
    }

    NSInteger selectedTag = [assetType integerValue];
    BOOL foundMatch = NO;

    for (NSDictionary *dict in [AppController infoValueForKey:KEY_ASSET_TYPE])
    {
        if ([[dict objectForKey:KEY_ID] integerValue] == selectedTag) {
            foundMatch = YES;
            break;
        }
    }

    [_assetTypePopup selectItemWithTag:(foundMatch ? selectedTag : 0)];
}

- (BOOL)hasUnknownAssetTypeSelection
{
    return (_assetTypePopup.indexOfSelectedItem == 0);
}

- (BOOL)hasPrimaryVideoTrack
{
    for (SMTrackRowSnapshot *snapshot in [self trackRowSnapshots])
        if ([snapshot isPrimaryVideoTrack])
            return YES;

    return NO;
}

- (BOOL)hasPrimaryAudioTrack
{
    for (SMTrackRowSnapshot *snapshot in [self trackRowSnapshots])
        if ([snapshot isAudioTrack] && ![snapshot isReferenceTrack])
            return YES;

    return NO;
}

#pragma mark - Readiness Query Helpers

static BOOL SMTrackLanguageIsUnknown(NSString *language)
{
    if (language == nil) {
        return YES;
    }

    NSString *normalizedLanguage = [[language stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    return ([normalizedLanguage length] == 0
            || [normalizedLanguage isEqualToString:@"unknown"]
            || [normalizedLanguage isEqualToString:@"und"]);
}

static BOOL SMReferenceAudioTrackSnapshotHasResolvableSource(SMTrackRowSnapshot *snapshot)
{
    if (snapshot == nil || ![snapshot isReferenceTrack] || ![snapshot looksLikeAudioTrack]) {
        return YES;
    }

    NSURL *sourceURL = [snapshot sourceURL];
    if (![sourceURL isKindOfClass:[NSURL class]] || ![sourceURL isFileURL]) {
        return NO;
    }

    NSString *sourcePath = [sourceURL path];
    if (sourcePath.length == 0) {
        return NO;
    }

    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:sourcePath isDirectory:&isDirectory]) {
        return NO;
    }

    return !isDirectory;
}

#pragma mark - Readiness Queries

- (NSInteger)firstAudioTrackRowWithUnknownLanguage
{
    for (SMTrackRowSnapshot *snapshot in [self trackRowSnapshots]) {
        if (![snapshot isPrimaryAudioTrack]) {
            continue;
        }

        if ([snapshot hasUnknownLanguage]) {
            return [snapshot rowIndex];
        }
    }

    return NSNotFound;
}

- (NSUInteger)unknownLanguageAudioTrackCount
{
    NSUInteger count = 0;
    for (SMTrackRowSnapshot *snapshot in [self trackRowSnapshots]) {
        if (![snapshot isPrimaryAudioTrack]) {
            continue;
        }

        if ([snapshot hasUnknownLanguage]) {
            count++;
        }
    }
    return count;
}

- (NSInteger)firstAudioTrackRowWithUnresolvedChannelLayout
{
    for (NSDictionary *row in [[self trackSnapshot] objectForKey:SlateTrackSnapshotKeyRows]) {
        if (![row isKindOfClass:[NSDictionary class]]
            || !SlateTrackSnapshotRowBool(row, SlateTrackSnapshotRowKeyAudioTrack)
            || SlateTrackSnapshotRowBool(row, SlateTrackSnapshotRowKeyReferenceTrack)) {
            continue;
        }

        if (!SlateTrackSnapshotRowBool(row, SlateTrackSnapshotRowKeyAudioChannelLayoutResolved)
            || SlateTrackSnapshotRowInteger(row, SlateTrackSnapshotRowKeyAudioChannelCount) <= 0) {
            return SlateTrackSnapshotRowInteger(row, SlateTrackSnapshotRowKeyRowIndex);
        }
    }

    return NSNotFound;
}

- (NSUInteger)unresolvedChannelLayoutAudioTrackCount
{
    NSUInteger count = 0;
    for (NSDictionary *row in [[self trackSnapshot] objectForKey:SlateTrackSnapshotKeyRows]) {
        if (![row isKindOfClass:[NSDictionary class]]
            || !SlateTrackSnapshotRowBool(row, SlateTrackSnapshotRowKeyAudioTrack)
            || SlateTrackSnapshotRowBool(row, SlateTrackSnapshotRowKeyReferenceTrack)) {
            continue;
        }

        if (!SlateTrackSnapshotRowBool(row, SlateTrackSnapshotRowKeyAudioChannelLayoutResolved)
            || SlateTrackSnapshotRowInteger(row, SlateTrackSnapshotRowKeyAudioChannelCount) <= 0) {
            count++;
        }
    }

    return count;
}

- (NSInteger)firstAudioTrackRowWithGenericChannelAssignments
{
    for (NSDictionary *row in [[self trackSnapshot] objectForKey:SlateTrackSnapshotKeyRows]) {
        if (![row isKindOfClass:[NSDictionary class]]
            || !SlateTrackSnapshotRowBool(row, SlateTrackSnapshotRowKeyAudioTrack)
            || SlateTrackSnapshotRowBool(row, SlateTrackSnapshotRowKeyReferenceTrack)) {
            continue;
        }

        if (SlateTrackSnapshotRowBool(row, SlateTrackSnapshotRowKeyAudioChannelAssignmentsGeneric)) {
            return SlateTrackSnapshotRowInteger(row, SlateTrackSnapshotRowKeyRowIndex);
        }
    }

    return NSNotFound;
}

- (NSUInteger)genericChannelAssignmentAudioTrackCount
{
    NSUInteger count = 0;
    for (NSDictionary *row in [[self trackSnapshot] objectForKey:SlateTrackSnapshotKeyRows]) {
        if (![row isKindOfClass:[NSDictionary class]]
            || !SlateTrackSnapshotRowBool(row, SlateTrackSnapshotRowKeyAudioTrack)
            || SlateTrackSnapshotRowBool(row, SlateTrackSnapshotRowKeyReferenceTrack)) {
            continue;
        }

        if (SlateTrackSnapshotRowBool(row, SlateTrackSnapshotRowKeyAudioChannelAssignmentsGeneric)) {
            count++;
        }
    }

    return count;
}

- (NSInteger)firstReferenceAudioTrackRowWithUnresolvedSource
{
    for (SMTrackRowSnapshot *snapshot in [self trackRowSnapshots]) {
        if (![snapshot isReferenceTrack] || ![snapshot looksLikeAudioTrack]) {
            continue;
        }

        if (!SMReferenceAudioTrackSnapshotHasResolvableSource(snapshot)) {
            return [snapshot rowIndex];
        }
    }

    return NSNotFound;
}

- (NSUInteger)unresolvedSourceReferenceAudioTrackCount
{
    NSUInteger count = 0;
    for (SMTrackRowSnapshot *snapshot in [self trackRowSnapshots]) {
        if (![snapshot isReferenceTrack] || ![snapshot looksLikeAudioTrack]) {
            continue;
        }

        if (!SMReferenceAudioTrackSnapshotHasResolvableSource(snapshot)) {
            count++;
        }
    }

    return count;
}

- (NSInteger)firstReferenceTrackRowWithUnknownLanguage
{
    for (SMTrackRowSnapshot *snapshot in [self trackRowSnapshots]) {
        if (![snapshot isReferenceTrack]) {
            continue;
        }
        if (![snapshot looksLikeAudioTrack] && ![snapshot looksLikeTextTrack]) {
            continue;
        }

        if ([snapshot hasUnknownLanguage]) {
            return [snapshot rowIndex];
        }
    }

    return NSNotFound;
}

- (NSUInteger)unknownLanguageReferenceTrackCount
{
    NSUInteger count = 0;
    for (SMTrackRowSnapshot *snapshot in [self trackRowSnapshots]) {
        if (![snapshot isReferenceTrack]) {
            continue;
        }
        if (![snapshot looksLikeAudioTrack] && ![snapshot looksLikeTextTrack]) {
            continue;
        }

        if ([snapshot hasUnknownLanguage]) {
            count++;
        }
    }
    return count;
}

- (NSString *)referenceTrackTypeLabelForRow:(NSInteger)row
{
    return [[self trackRowSnapshotAtIndex:row] referenceTrackTypeLabel] ?: @"Reference track";
}

- (NSInteger)firstTextTrackRowWithUnknownLanguage
{
    for (SMTrackRowSnapshot *snapshot in [self trackRowSnapshots]) {
        if ([snapshot isReferenceTrack] || ![snapshot looksLikeTextTrack]) {
            continue;
        }

        if ([[snapshot language] isEqualToString:@"Unknown"]) {
            return [snapshot rowIndex];
        }
    }

    return NSNotFound;
}

- (NSUInteger)unknownLanguageTextTrackCount
{
    NSUInteger count = 0;
    for (SMTrackRowSnapshot *snapshot in [self trackRowSnapshots]) {
        if ([snapshot isReferenceTrack] || ![snapshot looksLikeTextTrack]) {
            continue;
        }
        if ([[snapshot language] isEqualToString:@"Unknown"]) {
            count++;
        }
    }
    return count;
}

- (NSInteger)firstTextTrackRowWithUnresolvedRole
{
    for (SMTrackRowSnapshot *snapshot in [self trackRowSnapshots]) {
        if (![snapshot isReferenceTrack] && SMTrackMediaTypeMatches([snapshot mediaType], SMMediaTypeText)) {
            return [snapshot rowIndex];
        }
    }

    return NSNotFound;
}

- (NSUInteger)unresolvedRoleTextTrackCount
{
    NSUInteger count = 0;
    for (SMTrackRowSnapshot *snapshot in [self trackRowSnapshots]) {
        if (![snapshot isReferenceTrack] && SMTrackMediaTypeMatches([snapshot mediaType], SMMediaTypeText)) {
            count++;
        }
    }
    return count;
}

- (NSString *)textTrackRoleLabelForRow:(NSInteger)row
{
    return [[self trackRowSnapshotAtIndex:row] textTrackRoleLabel] ?: @"Text track";
}

-(BOOL)hasInvalidAssetType
{
    NSDictionary *finding = SMTrackCanonicalFindingWithCode([self canonicalValidationFindings],
                                                             SMValidationFindingCodeTracksAssetTypeIsUnknown);
    if (finding == nil) {
        return NO;
    }

    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    NSString *title = [finding objectForKey:SMValidationFindingKeyTitle];
    NSString *evidence = [finding objectForKey:SMValidationFindingKeyEvidence];

    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:(SMTrackStringHasContent(title) ? title : @"Asset type readiness blocker")];
    [alert setInformativeText:(SMTrackStringHasContent(evidence) ? evidence : @"Readiness blocker active (code: tracks.asset_type_is_unknown).")];
    [alert setAlertStyle:NSCriticalAlertStyle];

    [alert beginSheetModalForWindow:[[self view]window] modalDelegate:self didEndSelector:nil contextInfo:nil];
    return YES;
}


#pragma mark - Track Model Loading

-(TrackItem *)createAudioTrackItem:(SMTrack *)track
{
    #pragma unused (track)
    AudioTrackItem    *t = [[AudioTrackItem alloc] init];
    #if 0
        OSStatus    err = noErr;
        //  get the sample description
        SampleDescriptionHandle desc = (SampleDescriptionHandle)NewHandle(0);
        
        GetMediaSampleDescription(media, 1, desc);			

        ByteCount               channelLayoutSize;
        AudioChannelLayout      *channelLayout = NULL;
        SoundDescriptionHandle  sndDesc = (SoundDescriptionHandle) desc;

        err = QTSoundDescriptionGetPropertyInfo(sndDesc, kQTPropertyClass_SoundDescription,
                                                kQTSoundDescriptionPropertyID_AudioChannelLayout,
                                                NULL, &channelLayoutSize, NULL);
        require_noerr(err, bail);

        channelLayout = (AudioChannelLayout*)malloc(channelLayoutSize);

        err = QTSoundDescriptionGetProperty(sndDesc, kQTPropertyClass_SoundDescription,
                                            kQTSoundDescriptionPropertyID_AudioChannelLayout,
                                            channelLayoutSize, channelLayout, NULL);
        require_noerr(err, bail);

        UInt32 channelNumber = AudioChannelLayoutTag_GetNumberOfChannels(channelLayout->mChannelLayoutTag);
        if (!channelNumber)
            channelNumber = channelLayout->mNumberChannelDescriptions;

        [(AudioTrackItem *)newTrack setChannelLayoutTag: channelLayout->mChannelLayoutTag];

        bail:
        if (err)
        {
            NSLog(@"Error: unable to read the sound description, guessing 1 channel");
            channelNumber = 1;
        }

        [(AudioTrackItem *)newTrack setChannels: channelNumber];

        if (channelLayout) free(channelLayout);
    #endif
    
    return (t);
}

-(TrackItem *)createVideoTrackItem:(SMTrack *)track
{
    VideoTrackItem    *t = [[VideoTrackItem alloc] init];

    NSSize cleanDimension = [track apertureModeDimensionsForMode:SMMovieApertureModeClean];
    NSSize encodedDimension = [track apertureModeDimensionsForMode:SMMovieApertureModeEncodedPixels];

    [t setTrackWidth: cleanDimension.width];
    [t setTrackHeight: cleanDimension.height];
    [t setWidth: encodedDimension.width];
    [t setHeight: encodedDimension.height];

    return(t);
}

-(void)appendReferenceTrackItemForTrack:(SMTrack *)track
                           trackClass:(Class)trackClass
                  fallbackFormatSummary:(NSString *)fallbackFormatSummary
{
    NSURL *sourceURL = [track attributeForKey:@"__playbackSourceURL"];
    BOOL shouldLogReferenceTrack = [[[[sourceURL pathExtension] lowercaseString] ?: @"" lowercaseString] isEqualToString:@"mp3"];
    NSUInteger priorTrackCount = [_track count];

    TrackItem *newTrack = [[trackClass alloc] init];
    if (newTrack == nil)
        return;

    NSString *formatSummary = [track attributeForKey:SMTrackFormatSummaryAttribute];
    if (formatSummary == nil || formatSummary.length == 0)
        formatSummary = fallbackFormatSummary;

    newTrack.isreftrack = YES;
    newTrack.track = track;
    newTrack.ident = [[track attributeForKey:SMTrackIDAttribute] unsignedIntValue];
    newTrack.language = [self langForTrack:track];
    if ([newTrack isKindOfClass:[AudioTrackItem class]] &&
        [newTrack.language isEqualToString:@"Unknown"]) {
        newTrack.language = @"N/A";
    }

    SMTime trackDuration = [[[track media] attributeForKey:SMMediaDurationAttribute] SMTimeValue];
    newTrack.duration = (trackDuration.timeScale != 0) ? ((double)trackDuration.timeValue / (double)trackDuration.timeScale) * 1000.0 : 0;

    [_track addObject:newTrack];
    if (shouldLogReferenceTrack) {
        NSLog(@"Reference UI append %@ priorTrackCount=%lu newTrackCount=%lu ident=%ld format=%@", [sourceURL lastPathComponent], (unsigned long)priorTrackCount, (unsigned long)[_track count], (long)newTrack.ident, formatSummary);
    }
    [newTrack release];
}

-(void)refreshTrackData
{
    SMMovie *movie = [appcontroller() movie];
    
    //  kImageCodecSettingsFieldCount
    //  kVideoColorInfoImageDescriptionExtensionType
    for (SMTrack *track in [movie tracks])
    {
        NSString    *mediaType = [track attributeForKey:SMTrackMediaTypeAttribute];
        TrackItem     *newTrack = nil;
        NSString    *lang =[self langForTrack:track];
        
        if ([mediaType isEqualToString:SMMediaTypeVideo])   //  video
        {
            if ([_videoLanguagePopup indexOfItemWithTitle:lang])
                [_videoLanguagePopup selectItemWithTitle:lang];

            newTrack = [self createVideoTrackItem:track];
        }
        else if ([mediaType isEqualToString:SMMediaTypeSound])  //  audio
        {
            if ([_audioLanguagePopup indexOfItemWithTitle:lang])
                [_audioLanguagePopup selectItemWithTitle:lang];

            //  k24bitFormat
            newTrack = [self createAudioTrackItem:track];
        }
        else if ([mediaType isEqualToString:SMMediaTypeClosedCaption])  //  closed caption
            newTrack = [[ClosedCaptionTrackItem alloc] init];
        else if ([mediaType isEqualToString:SMMediaTypeSubtitle])       //  subtitle
            newTrack = [[SubtitleTrackItem alloc] init];
        else
            newTrack = [[TrackItem alloc] init];
        
        if (newTrack)
        {
            newTrack.track = track;
            newTrack.ident = [[track attributeForKey:SMTrackIDAttribute] unsignedIntValue];
            newTrack.language = [self langForTrack:track];

            SMTime duration = [[[track media] attributeForKey:SMMediaDurationAttribute] SMTimeValue];
            newTrack.duration = (duration.timeScale != 0) ? ((double)duration.timeValue / (double)duration.timeScale) * 1000.0 : 0;

            [_track addObject:newTrack];

            [newTrack release];
        }
    }

    for (SMTrack *track in [movie subtitleSidecarTracks])
    {
        NSString *mediaType = [track attributeForKey:SMTrackMediaTypeAttribute];
        Class trackClass = [mediaType isEqualToString:SMMediaTypeClosedCaption]
            ? [ClosedCaptionTrackItem class]
            : ([mediaType isEqualToString:SMMediaTypeSubtitle] ? [SubtitleTrackItem class] : [TrackItem class]);
        [self appendReferenceTrackItemForTrack:track trackClass:trackClass fallbackFormatSummary:nil];
    }
    
    [self reloadTracksTableSelectingFirstRowIfNeeded];
}

-(IBAction)launchJES:(id)sender
{
    #pragma unused (sender)
    
    [[NSWorkspace sharedWorkspace] launchAppWithBundleIdentifier:@"nl.jes.extensifier"
        options:0
        additionalEventParamDescriptor:nil
        launchIdentifier:NULL];
    
}

-(NSString *)langForTrack: (SMTrack *)track
{
    long        data = [[track attributeForKey:SMTrackLanguageAttribute] longValue];
    char        code[4];
    iso639_lang_t *languageInfo = lang_for_qtcode(data);
    NSString    *language = (languageInfo != NULL && languageInfo->eng_name != NULL) ? [NSString stringWithUTF8String:languageInfo->eng_name] : @"Unknown";

    if ([language isEqualToString:@"Unknown"])
    {
        code[0] = ((data & 0x7c00) >> 10) + 0x60;
        code[1] = ((data & 0x03e0) >>  5) + 0x60;
        code[2] = ((data & 0x001f)      ) + 0x60;
        code[3] = '\0';

        iso639_lang_t *codeInfo = lang_for_code2(code);
        if (codeInfo != NULL && codeInfo->eng_name != NULL)
            language = [NSString stringWithFormat:@"%s", codeInfo->eng_name];
    }

    return (language);
}

#pragma mark - Reference Subtitle Imports

// Live controller path: file selection stays here; synthetic sidecar display parsing now lives in SMMovie.
- (void)importITTSubtitleFromURL:(NSURL *)url
{
    NSError *error = nil;
    SMTrack *track = [[appcontroller() movie] addSidecarITTSubtitleTrackFromURL:url error:&error];
    if (track != nil) {
        [self appendReferenceTrackItemForTrack:track trackClass:[SubtitleTrackItem class] fallbackFormatSummary:@"ITT Subtitle"];
    }
}

// Live controller path: file selection stays here; synthetic sidecar display parsing now lives in SMMovie.
- (void)importSRTSubtitleFromURL:(NSURL *)url
{
    NSError *error = nil;
    SMTrack *track = [[appcontroller() movie] addSidecarSRTSubtitleTrackFromURL:url error:&error];
    if (track != nil) {
        [self appendReferenceTrackItemForTrack:track trackClass:[SubtitleTrackItem class] fallbackFormatSummary:@"SRT Subtitle"];
    }
}

// Live controller path: file selection stays here; synthetic sidecar display parsing now lives in SMMovie.
- (void)importTTMLSubtitleFromURL:(NSURL *)url
{
    NSError *error = nil;
    SMTrack *track = [[appcontroller() movie] addSidecarTTMLSubtitleTrackFromURL:url error:&error];
    if (track != nil) {
        [self appendReferenceTrackItemForTrack:track trackClass:[SubtitleTrackItem class] fallbackFormatSummary:@"TTML Subtitle"];
    }
}

// Live controller path: file selection stays here; synthetic sidecar display parsing now lives in SMMovie.
- (void)importSCCSubtitleFromURL:(NSURL *)url
{
    NSError *error = nil;
    SMTrack *track = [[appcontroller() movie] addSidecarSCCSubtitleTrackFromURL:url error:&error];
    if (track != nil) {
        [self appendReferenceTrackItemForTrack:track trackClass:[ClosedCaptionTrackItem class] fallbackFormatSummary:@"SCC Closed Caption"];
    }
}

#pragma mark - NSTableView Delegate
-(void)tableViewSelectionDidChange:(NSNotification *)notif
{
	NSTableView *tableView = [notif object];
    
    NSInteger rowIdx = [tableView selectedRow];

    if (rowIdx < 0)
    {
        [self updateInspectorGainControlsForSnapshot:nil];
        [self updateTrackInspectorDetailsText];
        return;
    }
    else if ([tableView isEqual:_tracks])
    {
        [self updateInspectorGainControlsForSnapshot:[self trackRowSnapshotAtIndex:rowIdx]];
        [self updateTrackInspectorDetailsText];
    }
}

- (NSAttributedString *)grayString:(NSString *)string rightAlign:(BOOL)rightAlign
{
    NSMutableParagraphStyle * ps = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [ps setHeadIndent: -10.0];
    [ps setAlignment: rightAlign ? NSRightTextAlignment : NSLeftTextAlignment];
    
    return [[NSAttributedString alloc]initWithString:string attributes:[NSDictionary dictionaryWithObjectsAndKeys:
                       [NSFont systemFontOfSize:11.0], NSFontAttributeName,
                       ps, NSParagraphStyleAttributeName,
                       [NSColor grayColor], NSForegroundColorAttributeName,
                       nil]];
}

#pragma mark - Track Command Surface

// All live writes pass through here; table/view code calls commands.
- (TrackItem *)trackCommandItemAtIndex:(NSInteger)rowIndex
{
    if (rowIndex < 0 || rowIndex >= (NSInteger)[_track count]) {
        return nil;
    }

    return [_track objectAtIndex:rowIndex];
}

- (TrackItem *)trackCommandItemWithIdentifier:(uint32_t)trackID
{
    for (TrackItem *trackItem in _track) {
        if ([trackItem ident] == trackID) {
            return trackItem;
        }
    }

    return nil;
}

- (void)performTrackCommandRestoreMovieStateRebuildingTracks:(BOOL)rebuildTracks
{
    SMMovie *movie = [appcontroller() movie];

    [movie gotoBeginning];

    for (SMTrackRowSnapshot *snapshot in [self trackRowSnapshots]) {
        if ([snapshot isReferenceTrack] && [snapshot isAudioTrack]) {
            [movie removeTrack:[snapshot track]];
        }
    }

    NSArray *trackArray = [movie tracksOfMediaType:SMMediaTypeSound];
    for (int i = 0; i < trackArray.count; i++) {
        [[trackArray objectAtIndex:i] setEnabled:YES];
    }

    if (rebuildTracks) {
        [_track removeAllObjects];
        [self refreshTrackData];
    } else {
        [self invalidateTrackSnapshot];
    }
    [self refreshValidationAdaptersAfterMutation];
}

- (void)performTrackCommandRemoveMovieReference
{
    [_track removeAllObjects];

    [self invalidateTrackSnapshot];
    [_tracks reloadData];
    [_tracks deselectAll:nil];

    [self refreshValidationAdaptersAfterMutation];
}

- (void)performTrackCommandSetMovieGain:(float)value
{
    SMMovie *movie = [appcontroller() movie];
    if (movie != nil) {
        [movie setAudioGain:value];
    }
    [_gainSlider setFloatValue:value];
}

- (void)performTrackCommandSetTrackGainForItem:(TrackItem *)trackItem value:(float)value
{
    if (trackItem == nil) {
        return;
    }
    [[trackItem track] setAudioGain:value];
    [_gainSlider setFloatValue:value];
    [self invalidateTrackSnapshot];
    [self updateTrackInspectorDetailsText];
}

- (void)performTrackCommandSetTrackGainForTrackID:(uint32_t)trackID value:(float)value
{
    [self performTrackCommandSetTrackGainForItem:[self trackCommandItemWithIdentifier:trackID] value:value];
}

- (void)performTrackCommandApplyLanguageMenuItem:(NSMenuItem *)item target:(SMTrackCommandLanguageTarget)target
{
    if (item == nil) {
        return;
    }

    SMMovie *movie = [appcontroller() movie];
    for (SMTrack *track in [movie tracks]) {
        NSString *mediaType = [track attributeForKey:SMTrackMediaTypeAttribute];
        BOOL shouldApplyToMovieTrack = NO;
        if (target == SMTrackCommandLanguageTargetAudio) {
            shouldApplyToMovieTrack = [mediaType isEqualToString:SMMediaTypeSound];
        } else {
            shouldApplyToMovieTrack = ([mediaType isEqualToString:SMMediaTypeVideo]
                                       || [mediaType isEqualToString:SMMediaTypeTimeCode]);
        }

        if (shouldApplyToMovieTrack) {
            [track setAttribute:[NSNumber numberWithInteger:[item tag]] forKey:SMTrackLanguageAttribute];
        }
    }

    for (SMTrackRowSnapshot *snapshot in [self trackRowSnapshots]) {
        BOOL shouldApplyToRow = (target == SMTrackCommandLanguageTargetAudio)
            ? [snapshot isAudioTrack]
            : ![snapshot isAudioTrack];
        if (shouldApplyToRow) {
            [[self trackCommandItemAtIndex:[snapshot rowIndex]] setLanguage:[item title]];
        }
    }

    [self invalidateTrackSnapshot];
    [_tracks reloadData];
    [self refreshValidationAdaptersAfterMutation];
}

- (void)performTrackCommandToggleEnabledAtRow:(NSInteger)rowIndex
{
    TrackItem *trackItem = [self trackCommandItemAtIndex:rowIndex];
    SMTrackRowSnapshot *snapshot = [self trackRowSnapshotAtIndex:rowIndex];
    if (trackItem == nil || snapshot == nil) {
        return;
    }

    if ([snapshot isAudioTrack]) {
        [[trackItem track] setMutedForPlayback:![[trackItem track] isMutedForPlayback]];
    } else {
        if (![snapshot isSubtitleTrack] && ![snapshot isClosedCaptionTrack]) {
            PlayerView *playerView = [appcontroller() playerView];
            [playerView stopMovie];
        }

        [[trackItem track] setEnabled:![[trackItem track] isEnabled]];
    }

    [appcontroller() syncSidecarVisibilityState];
    [[appcontroller() playerView] refreshSubtitleOverlay];
    [self invalidateTrackSnapshot];
    [_tracks reloadData];
    [self refreshValidationAdaptersAfterMutation];
}

- (BOOL)performTrackCommandCanDeleteRow:(NSInteger)rowIndex
{
    return ([self trackCommandItemAtIndex:rowIndex] != nil);
}

- (void)performTrackCommandDeleteRow:(NSInteger)rowIndex
{
    TrackItem *trackItem = [self trackCommandItemAtIndex:rowIndex];
    if (trackItem == nil) {
        return;
    }

    [[appcontroller() movie] removeTrack:[trackItem track]];
    [_track removeObjectAtIndex:rowIndex];
    [self reloadTracksTableSelectingFirstRowIfNeeded];
    [appcontroller() refreshTimelineDurationFromPlaybackState];
    [appcontroller() syncSidecarVisibilityState];
    [[appcontroller() playerView] refreshSubtitleOverlay];
    [self refreshValidationAdaptersAfterMutation];
}

- (void)performTrackCommandFinishReferenceImport
{
    [self invalidateTrackSnapshot];
    [_tracks reloadData];
    NSLog(@"Reference UI postReload modelTrackCount=%lu tableRowCount=%ld", (unsigned long)[_track count], (long)[_tracks numberOfRows]);
    [appcontroller() refreshTimelineDurationFromPlaybackState];
    [appcontroller() syncSidecarVisibilityState];
    [[appcontroller() playerView] refreshSubtitleOverlay];
    [self refreshValidationAdaptersAfterMutation];
}

-(void)restoreMovieState:(BOOL)rebuildTracks
{
    [self performTrackCommandRestoreMovieStateRebuildingTracks:rebuildTracks];
}

-(void)removeMovieReference
{
    [self performTrackCommandRemoveMovieReference];
}

-(void)setMovieGain:(float)value
{
    [self performTrackCommandSetMovieGain:value];
}

-(void)setTrackGain:(TrackItem *)t value:(float)value
{
    [self performTrackCommandSetTrackGainForItem:t value:value];
}

-(void)setTrackGainForTrackID:(uint32_t)trackID value:(float)value
{
    [self performTrackCommandSetTrackGainForTrackID:trackID value:value];
}

-(IBAction)inspectorGainSliderChanged:(id)sender
{
    float value = [_gainSlider floatValue];
    if (_gainSliderTargetsMovie) {
        [[[[self view] undoManager] prepareWithInvocationTarget:self] setMovieGain:value];
        [self setMovieGain:[sender floatValue]];
        return;
    }

    SMTrackRowSnapshot *snapshot = [self selectedTrackRowSnapshot];
    if (snapshot == nil) {
        return;
    }
    uint32_t trackID = [snapshot ident];
    [[[[self view] undoManager] prepareWithInvocationTarget:self] setTrackGainForTrackID:trackID value:value];
    [self setTrackGainForTrackID:trackID value:[sender floatValue]];
}

-(IBAction)applyAudioTrackLanguage:(id)sender
{
    #pragma unused (sender)
    [self performTrackCommandApplyLanguageMenuItem:[_audioLanguagePopup selectedItem]
                                            target:SMTrackCommandLanguageTargetAudio];
}

-(IBAction)applyVideoTrackLanguage:(id)sender
{
    #pragma unused (sender)
    [self performTrackCommandApplyLanguageMenuItem:[_videoLanguagePopup selectedItem]
                                            target:SMTrackCommandLanguageTargetVideo];
}

-(void)addReferenceAudioTrack:(SMTrack *)referenceTrack fallbackFormatSummary:(NSString *)fallbackFormatSummary
{
    NSURL *sourceURL = [referenceTrack attributeForKey:@"__playbackSourceURL"];
    if ([[[[sourceURL pathExtension] lowercaseString] ?: @"" lowercaseString] isEqualToString:@"mp3"]) {
        NSLog(@"Reference UI addReferenceAudioTrack %@ beforeAppendTrackCount=%lu", [sourceURL lastPathComponent], (unsigned long)[_track count]);
    }
    [self appendReferenceTrackItemForTrack:referenceTrack
                              trackClass:[AudioTrackItem class]
                     fallbackFormatSummary:fallbackFormatSummary];
}

-(BOOL)canDeleteSelectedTrack
{
    return [self performTrackCommandCanDeleteRow:[_tracks selectedRow]];
}

-(IBAction)deleteSelectedTrack:(id)sender
{
    #pragma unused(sender)
    [self performTrackCommandDeleteRow:[_tracks selectedRow]];
}

-(void)importReferenceAudioTracksFromMovieURL:(NSURL *)url
{
    SMMovie *movie = [appcontroller() movie];
    NSError *error = nil;
    for (SMTrack *track in [movie addPlaybackReferenceAudioTracksFromURL:url error:&error])
        [self addReferenceAudioTrack:track fallbackFormatSummary:@"MOV Audio"];
}

-(void)importReferenceAudioTracksFromAssetURL:(NSURL *)url pathExtension:(NSString *)pathExtension
{
    SMMovie *movie = [appcontroller() movie];
    NSString *fallbackFormatSummary = [[pathExtension uppercaseString] stringByAppendingString:@" Audio"];
    NSArray *importedTracks = [movie addPlaybackReferenceAudioTracksFromURL:url error:nil];
    if ([pathExtension isEqualToString:@"mp3"]) {
        NSLog(@"Reference UI import %@ importedTrackCount=%lu preLoopTrackCount=%lu", [url lastPathComponent], (unsigned long)importedTracks.count, (unsigned long)[_track count]);
    }
    for (SMTrack *referenceTrack in importedTracks)
        [self addReferenceAudioTrack:referenceTrack fallbackFormatSummary:fallbackFormatSummary];
}

-(void)createReferenceTrack:(NSArray *)items
{
    dispatch_async(dispatch_get_main_queue(), ^ {
    NSUInteger priorTrackCount = [_track count];
    for (NSURL *url in items)
    {
        @try
        {
            NSString *pathExtension = [[url pathExtension] lowercaseString];
            if ([pathExtension isEqualToString:@"mov"])
            {
                [self importReferenceAudioTracksFromMovieURL:url];
            }
            else if ([pathExtension isEqualToString:@"wav"]
                     || [pathExtension isEqualToString:@"aif"]
                     || [pathExtension isEqualToString:@"aiff"]
                     || [pathExtension isEqualToString:@"m4a"]
                     || [pathExtension isEqualToString:@"mp3"]
                     || [pathExtension isEqualToString:@"caf"])
            {
                [self importReferenceAudioTracksFromAssetURL:url pathExtension:pathExtension];
            }
            else if ([pathExtension isEqualToString:@"scc"])
            {
                [self importSCCSubtitleFromURL:url];
            }
            else if ([pathExtension isEqualToString:@"itt"])
            {
                [self importITTSubtitleFromURL:url];
            }
            else if ([pathExtension isEqualToString:@"srt"])
            {
                [self importSRTSubtitleFromURL:url];
            }
            else if ([pathExtension isEqualToString:@"ttml"] || [pathExtension isEqualToString:@"dfxp"])
            {
                [self importTTMLSubtitleFromURL:url];
            }
        }
        @catch (NSException *exception)
        {
            NSLog(@"Ignoring reference import %@ after exception during import: %@", [url lastPathComponent], exception);
        }
    }
    
    [self performTrackCommandFinishReferenceImport];
    if ([_track count] > priorTrackCount) {
        NSInteger rowToSelect = (NSInteger)priorTrackCount;
        if (rowToSelect >= 0 && rowToSelect < [_tracks numberOfRows]) {
            [_tracks selectRowIndexes:[NSIndexSet indexSetWithIndex:rowToSelect] byExtendingSelection:NO];
            [_tracks scrollRowToVisible:rowToSelect];
            [self tableViewSelectionDidChange:[NSNotification notificationWithName:NSTableViewSelectionDidChangeNotification
                                                                            object:_tracks]];
        }
        NSUInteger addedCount = [_track count] - priorTrackCount;
        [appcontroller() showStatusMessage:[NSString stringWithFormat:@"Added %lu reference track%@.",
                                            (unsigned long)addedCount,
                                            addedCount == 1 ? @"" : @"s"]
                                    persist:NO];
    } else if ([items count] > 0) {
        [appcontroller() showStatusMessage:@"No reference tracks were added." persist:NO];
    }
     });
}

#pragma mark - Teardown

-(void)dealloc
{
    NSLog(@"TrackViewController dealloc");

    [_primaryTrackTableDataSource release];
    [_trackSnapshot release];

    [_canonicalValidationFindings release];
    [_tracksSectionLabel release];
    [_tracksStateLabel release];
    [_advancedSectionLabel release];
    [_advancedGroupBox release];
    [_readinessPresenter release];
    [_trackInspectorCopyButton release];

    [_track release];
    
    [super dealloc];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}
@end
