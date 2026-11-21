//
//  TrackViewController.m
//  Slate
//
//  Created by Jerry Hale on 3/20/26
//  Copyright (c) 2026 Jerry Hale All rights reserved.

#import "rational.h"
#include <stdint.h>

#import "SBLanguages.h"
#import "DictionaryKeys.h"


#import "PlayerView.h"
#import "AppController+Private.h"
#import "AppController+Validation.h"
#import "Runtime/SlateAudioLayoutContract.h"
#import "../Slate/Subtitle/SMSubtitleParsing.h"
#import "Movie/SMMoviePlaybackSupport.h"
#import "Runtime/SlatePackageContextContract.h"
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

// Session rows project embedded tracks and in-memory reference tracks for display.
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

static BOOL SMTrackSessionChannelLabelIsGeneric(AudioChannelLabel label)
{
    return (label == kAudioChannelLabel_Unknown
            || label == kAudioChannelLabel_Unused
            || label == kAudioChannelLabel_Discrete
            || (label >= kAudioChannelLabel_Discrete_0 && label <= kAudioChannelLabel_Discrete_15));
}

static NSDictionary *SMTrackSessionAudioLayoutSummary(SMTrack *track)
{
    AudioChannelLayout *layout = NULL;
    UInt32 layoutSize = 0;
    if (track == nil || SMCopyTrackAudioLayout(track, &layoutSize, &layout) != noErr || layout == NULL) {
        return [NSDictionary dictionaryWithObjectsAndKeys:
                [NSNumber numberWithBool:NO], @"resolved",
                [NSNumber numberWithUnsignedInteger:0], @"channelCount",
                [NSNumber numberWithBool:NO], @"genericAssignments",
                @"Unresolved", @"summary",
                nil];
    }

    UInt32 channelCount = AudioChannelLayoutTag_GetNumberOfChannels(layout->mChannelLayoutTag);
    if (channelCount == 0) {
        channelCount = layout->mNumberChannelDescriptions;
    }
    BOOL genericAssignments = NO;
    if (layout->mChannelLayoutTag == kAudioChannelLayoutTag_UseChannelDescriptions) {
        for (UInt32 index = 0; index < layout->mNumberChannelDescriptions; index++) {
            if (SMTrackSessionChannelLabelIsGeneric(layout->mChannelDescriptions[index].mChannelLabel)) {
                genericAssignments = YES;
                break;
            }
        }
    }
    NSString *channelSummary = SMAudioChannelSummaryFromTrack([track assetTrack]);
    NSString *summary = (channelCount > 0 && channelSummary.length > 0)
        ? [NSString stringWithFormat:@"%u channels\n%@", (unsigned int)channelCount, channelSummary]
        : (channelCount > 0 ? [NSString stringWithFormat:@"%u channels", (unsigned int)channelCount] : @"Unresolved");
    free(layout);

    return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithBool:(channelCount > 0)], @"resolved",
            [NSNumber numberWithUnsignedInteger:channelCount], @"channelCount",
            [NSNumber numberWithBool:genericAssignments], @"genericAssignments",
            summary, @"summary",
            nil];
}

static NSString *SMTrackSessionIdentity(SMTrack *track, NSURL *movieURL, BOOL referenceTrack, NSUInteger rowIndex)
{
    NSURL *sourceURL = [track attributeForKey:SMPlaybackSourceURLAttributeKey];
    if (![sourceURL isFileURL] || sourceURL.path.length == 0) {
        sourceURL = referenceTrack ? nil : movieURL;
    }

    NSString *scope = referenceTrack ? @"reference" : @"embedded";
    NSString *path = ([sourceURL isFileURL] && sourceURL.path.length > 0) ? sourceURL.path : @"session";
    NSString *mediaType = [track attributeForKey:SMTrackMediaTypeAttribute] ?: @"unknown";
    NSNumber *trackID = [track attributeForKey:SMTrackIDAttribute];
    if (![path isEqualToString:@"session"]) {
        NSString *rowIdentity = (trackID != nil)
            ? [trackID stringValue]
            : [NSString stringWithFormat:@"row-%lu", (unsigned long)rowIndex];
        return [NSString stringWithFormat:@"%@:%@:%@:%@", scope, path, mediaType, rowIdentity];
    }

    return [NSString stringWithFormat:@"%@:%@:%lu", scope, mediaType, (unsigned long)rowIndex];
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

static NSString * const SMReferenceImportOutcomeKindKey = @"kind";
static NSString * const SMReferenceImportOutcomeTrackCountKey = @"trackCount";
static NSString * const SMReferenceImportOutcomeRejectedCueCountKey = @"rejectedCueCount";
static NSString * const SMReferenceImportOutcomeReasonKey = @"reason";
static NSString * const SMReferenceImportOutcomeSuccess = @"success";
static NSString * const SMReferenceImportOutcomePartial = @"partial";
static NSString * const SMReferenceImportOutcomeFailure = @"failure";
static NSString * const SMReferenceImportOutcomeDuplicate = @"duplicate";
static NSUInteger const SMReferenceImportStatusMaximumLength = 108;

static NSString *SMCompactReferenceImportStatusMessage(NSString *message)
{
    NSString *normalized = [message stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    normalized = [normalized stringByReplacingOccurrencesOfString:@"\r" withString:@" "];
    normalized = [normalized stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (normalized.length <= SMReferenceImportStatusMaximumLength) {
        return normalized;
    }

    NSUInteger prefixLength = SMReferenceImportStatusMaximumLength - 1;
    NSRange prefixRange = NSMakeRange(0, prefixLength);
    NSRange lastSpace = [normalized rangeOfString:@" " options:NSBackwardsSearch range:prefixRange];
    if (lastSpace.location != NSNotFound && lastSpace.location >= prefixLength - 16) {
        prefixLength = lastSpace.location;
    }
    return [[normalized substringToIndex:prefixLength] stringByAppendingString:@"…"];
}

static NSDictionary *SMReferenceImportOutcome(NSString *kind,
                                               NSUInteger trackCount,
                                               NSUInteger rejectedCueCount,
                                               NSString *reason)
{
    NSMutableDictionary *outcome = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                    (kind ?: SMReferenceImportOutcomeFailure), SMReferenceImportOutcomeKindKey,
                                    [NSNumber numberWithUnsignedInteger:trackCount], SMReferenceImportOutcomeTrackCountKey,
                                    [NSNumber numberWithUnsignedInteger:rejectedCueCount], SMReferenceImportOutcomeRejectedCueCountKey,
                                    nil];
    if (reason.length > 0) {
        [outcome setObject:reason forKey:SMReferenceImportOutcomeReasonKey];
    }
    return [NSDictionary dictionaryWithDictionary:outcome];
}

static NSUInteger SMRejectedSubtitleCueCount(NSArray *diagnostics)
{
    NSMutableSet *cueIndexes = [NSMutableSet set];
    NSUInteger diagnosticsWithoutCueIndex = 0;
    for (NSDictionary *diagnostic in diagnostics) {
        if (![[diagnostic objectForKey:SMSubtitleDiagnosticKeySeverity] isEqualToString:SMSubtitleDiagnosticSeverityWarning]) {
            continue;
        }
        id cueIndex = [diagnostic objectForKey:SMSubtitleDiagnosticKeyCueIndex];
        if (cueIndex != nil) {
            [cueIndexes addObject:cueIndex];
        } else {
            diagnosticsWithoutCueIndex++;
        }
    }
    return cueIndexes.count + diagnosticsWithoutCueIndex;
}

static NSString *SMSubtitleDiagnosticMessage(NSDictionary *diagnostic)
{
    NSString *message = [diagnostic objectForKey:SMSubtitleDiagnosticKeyMessage];
    NSNumber *sourceLine = [diagnostic objectForKey:SMSubtitleDiagnosticKeySourceLine];
    if (message.length == 0) {
        return nil;
    }
    if (sourceLine != nil) {
        return [NSString stringWithFormat:@"Line %@: %@", sourceLine, message];
    }
    return message;
}

static NSString *SMReferenceImportFailureReason(NSError *error, NSArray *diagnostics)
{
    NSDictionary *diagnostic = [[error.userInfo objectForKey:SMSubtitleErrorKeyDiagnostic] isKindOfClass:[NSDictionary class]]
        ? [error.userInfo objectForKey:SMSubtitleErrorKeyDiagnostic]
        : nil;
    if (diagnostic == nil) {
        NSArray *errorDiagnostics = [error.userInfo objectForKey:SMSubtitleErrorKeyDiagnostics];
        if ([errorDiagnostics isKindOfClass:[NSArray class]]) {
            diagnostic = [errorDiagnostics firstObject];
        }
    }
    if (diagnostic == nil) {
        diagnostic = [diagnostics firstObject];
    }

    NSString *diagnosticMessage = SMSubtitleDiagnosticMessage(diagnostic);
    if (error != nil && error.localizedDescription.length > 0) {
        return error.localizedDescription;
    }
    if (diagnosticMessage.length > 0) {
        return diagnosticMessage;
    }
    return @"The file did not produce any displayable tracks.";
}

static BOOL SMReferenceTrackHasSourceURL(SMTrack *track, NSURL *url)
{
    NSURL *sourceURL = [track attributeForKey:SMPlaybackSourceURLAttributeKey];
    NSURL *standardizedSourceURL = [sourceURL isFileURL] ? [sourceURL URLByStandardizingPath] : sourceURL;
    NSURL *standardizedURL = [url isFileURL] ? [url URLByStandardizingPath] : url;
    return (standardizedSourceURL != nil && [standardizedSourceURL isEqual:standardizedURL]);
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

#pragma mark - Layout Constants


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

static const CGFloat SMTrackIDColumnFixedWidth = 28.0;            // "99" + 3px left/right padding
static const CGFloat SMTrackEnabledColumnFixedWidth = 60.0;       // "Enabled" + 3px left/right padding
static const CGFloat SMTrackTypeColumnFixedWidth = 124.0;         // "Closed Caption" rounded up + padding
static const CGFloat SMTrackDurationColumnFixedWidth = 78.0;      // "12:00:00:00" + 3px left/right padding
static const CGFloat SMTrackLanguageInfoSharedWidth = 217.0;      // (74.5 + 359.5) / 2
static const CGFloat SMTrackFlexibleColumnMinimumWidth = 1.0;
static const NSInteger SMTrackTableMaximumVisibleRows = 15;
static const CGFloat SMTrackTableRowHeight = 21.0;
static const CGFloat SMTrackTableIntercellVerticalSpacing = 3.0;
static const CGFloat SMTrackTableHeaderHeight = 34.0;
static const CGFloat SMTrackAdvancedHeaderInsetX = 10.0;
static const CGFloat SMTrackAdvancedHeaderTopInset = 6.0;
static NSString * const SMTrackResizableColumnWidthsDefaultsKey = @"SMTrackResizableColumnWidths";
static NSString * const SMTrackReadinessStatusNoMovie = @"No movie loaded";
static NSString * const SMTrackReadinessStatusNoFindings = @"No track/role findings";
static NSString * const SMTrackReadinessEmptyMessageNoFindings = @"No track/role readiness findings.";
static NSString * const SMTrackReadinessFindingsToolTipTitle = @"Readiness findings (tracks + roles)";
static NSString * const SMTrackInspectorDetailsEmptyMessage = @"Select a track to inspect details.";
static const CGFloat SMTrackInspectorDetailsFontSize = 14.0;
static const CGFloat SMTrackInspectorCopyButtonSize = 16.0;
static const CGFloat SMTrackInspectorCopyButtonRightInset = 6.0;

static NSFont *SMTrackTableBodyFont(NSFontWeight weight)
{
    return [NSFont systemFontOfSize:12.0 weight:weight];
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

static CGFloat SMTrackInspectorDetailsAlignedTopY(void)
{
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

static NSFontWeight SMTrackTableFontWeightForRow(NSDictionary *row)
{
    return SlateTrackSnapshotRowBool(row, SlateTrackSnapshotRowKeyFakeTrack) ? NSFontWeightRegular : NSFontWeightMedium;
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
    NSString    *_sessionIdentity;

    uint32_t    _ident;
    NSString    *_language;

    uint32_t    _timescale;
    uint32_t    _duration;
}

@property (retain) SMTrack *track;
@property (copy) NSString *sessionIdentity;
@property(readwrite) uint32_t ident;
@property(readwrite, retain) NSString *language;
@property(readwrite) BOOL isreftrack;
@property(readwrite) uint32_t duration;

-(NSString *)timeString;
- (BOOL)isFakeTrack;

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
@synthesize sessionIdentity = _sessionIdentity;
@synthesize ident = _ident;
@synthesize duration = _duration;

//  [NSException raise:NSInvalidArgumentException format:@"Unknown table view"];

-(id)init
{
    self = [super init];

    if (self)
    {
        _isreftrack = NO;
        _sessionIdentity = [[[NSUUID UUID] UUIDString] copy];
    }

    return (self);
}

-(void) dealloc
{
    [_sessionIdentity release];
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

- (BOOL)isFakeTrack
{
    return (_track != nil && [_track assetTrack] == nil);
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

#pragma mark - Track Session Row

@interface SMTrackSessionRow : NSObject
{
    SMTrack *_track;
    NSInteger _rowIndex;
    NSString *_sessionIdentity;
    uint32_t _ident;
    BOOL _enabled;
    BOOL _referenceTrack;
    BOOL _fakeTrack;
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
@property(nonatomic, readonly, copy) NSString *sessionIdentity;
@property(nonatomic, readonly) uint32_t ident;
@property(nonatomic, readonly, getter=isEnabled) BOOL enabled;
@property(nonatomic, readonly, getter=isReferenceTrack) BOOL referenceTrack;
@property(nonatomic, readonly, getter=isFakeTrack) BOOL fakeTrack;
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

+ (id)rowWithTrackItem:(TrackItem *)trackItem rowIndex:(NSInteger)rowIndex;
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

@implementation SMTrackSessionRow

@synthesize track = _track;
@synthesize rowIndex = _rowIndex;
@synthesize sessionIdentity = _sessionIdentity;
@synthesize ident = _ident;
@synthesize enabled = _enabled;
@synthesize referenceTrack = _referenceTrack;
@synthesize fakeTrack = _fakeTrack;
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

+ (id)rowWithTrackItem:(TrackItem *)trackItem rowIndex:(NSInteger)rowIndex
{
    return [[[self alloc] initWithTrackItem:trackItem rowIndex:rowIndex] autorelease];
}

- (id)initWithTrackItem:(TrackItem *)trackItem rowIndex:(NSInteger)rowIndex
{
    self = [super init];
    if (self) {
        _track = [[trackItem track] retain];
        _rowIndex = rowIndex;
        _sessionIdentity = [[trackItem sessionIdentity] copy];
        _ident = [trackItem ident];
        _referenceTrack = [trackItem isreftrack];
        _fakeTrack = [trackItem isFakeTrack];
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
    [_sessionIdentity release];
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

@interface TrackViewController () <SMInspectorRailModeAdapter>
{
    BOOL _didInitializeTrackControllerData;
    SMPrimaryTrackTableDataSource *_primaryTrackTableDataSource;
    NSDictionary *_sessionRowProjection;
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
- (NSInteger)trackRowCount;
- (SMTrackSessionRow *)sessionTrackRowAtIndex:(NSInteger)rowIndex;
- (NSArray *)sessionTrackRows;
- (void)invalidateSessionRowProjection;
- (void)rebuildSessionRowProjection;
- (NSDictionary *)sessionRowProjection;
- (NSDictionary *)sessionRowDictionaryAtIndex:(NSInteger)rowIndex;
- (NSArray *)sessionRowDictionaries;
- (NSDictionary *)dictionaryForSessionRow:(SMTrackSessionRow *)sessionRow;
- (SMTrackSessionRow *)selectedSessionTrackRow;
- (NSAttributedString *)grayString:(NSString *)string rightAlign:(BOOL)rightAlign fontWeight:(NSFontWeight)fontWeight;
- (void)updateInspectorGainControlsForSessionRow:(SMTrackSessionRow *)snapshot;
- (void)updateTrackInspectorDetailsText;
- (IBAction)copyTrackInspectorDetails:(id)sender;
- (NSArray *)sessionTrackDetailPairs:(SMTrackSessionRow *)snapshot;
- (NSString *)sessionTrackDetailsString:(SMTrackSessionRow *)snapshot;
- (void)restorePersistedTrackColumnWidthsForTableView:(NSTableView *)tableView;
- (void)persistResizableTrackColumnWidths;
- (void)applyPrimaryTrackTableColumnWidths;
- (TrackItem *)trackCommandItemAtIndex:(NSInteger)rowIndex;
- (TrackItem *)trackCommandItemWithSessionIdentity:(NSString *)sessionIdentity;
- (void)performTrackCommandRestoreMovieStateRebuildingTracks:(BOOL)rebuildTracks;
- (void)performTrackCommandRemoveMovieReference;
- (void)performTrackCommandSetMovieGain:(float)value;
- (void)performTrackCommandSetTrackGainForItem:(TrackItem *)trackItem value:(float)value;
- (void)performTrackCommandSetTrackGainForSessionIdentity:(NSString *)sessionIdentity value:(float)value;
- (void)performTrackCommandApplyLanguageMenuItem:(NSMenuItem *)item target:(SMTrackCommandLanguageTarget)target;
- (void)performTrackCommandToggleEnabledAtRow:(NSInteger)rowIndex;
- (BOOL)performTrackCommandCanDeleteRow:(NSInteger)rowIndex;
- (void)performTrackCommandDeleteRow:(NSInteger)rowIndex;
- (void)renumberReferenceTrackDisplayIDs;
- (void)performTrackCommandFinishReferenceImport;
- (NSDictionary *)importSubtitleFromURL:(NSURL *)url importer:(SMTrack *(^)(NSError **error, NSArray **diagnostics))importer;
- (NSDictionary *)importITTSubtitleFromURL:(NSURL *)url;
- (NSDictionary *)importSRTSubtitleFromURL:(NSURL *)url;
- (NSDictionary *)importTTMLSubtitleFromURL:(NSURL *)url;
- (NSDictionary *)importSCCSubtitleFromURL:(NSURL *)url;
- (NSArray *)importReferenceAudioTracksFromMovieURL:(NSURL *)url error:(NSError **)error;
- (NSArray *)importReferenceAudioTracksFromAssetURL:(NSURL *)url pathExtension:(NSString *)pathExtension error:(NSError **)error;
- (void)setTrackGainForSessionIdentity:(NSString *)sessionIdentity value:(float)value;
@end

#pragma mark - Track Table Data Sources

// Table rows come from the session projection; table actions dispatch controller commands.
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
    NSDictionary *row = [_owner sessionRowDictionaryAtIndex:rowIdx];
    BOOL isreftrack = SlateTrackSnapshotRowBool(row, SlateTrackSnapshotRowKeyReferenceTrack);

    if (row == nil) return nil;
    NSFontWeight fontWeight = SMTrackTableFontWeightForRow(row);

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
            objectValue = [_owner grayString:trackID rightAlign:YES fontWeight:fontWeight];
        else
            objectValue = trackID;
    }
    else if ([colID isEqualToString:SlateTrackSnapshotColumnTrackType])
    {
        NSString *name = SlateTrackSnapshotRowString(row, SlateTrackSnapshotRowKeyTrackTypeColumn);

        if (isreftrack)
            objectValue = [_owner grayString:name rightAlign:NO fontWeight:fontWeight];
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
            objectValue = [_owner grayString:SlateTrackSnapshotRowString(row, SlateTrackSnapshotRowKeyDuration) rightAlign:YES fontWeight:fontWeight];
        else
            objectValue = SlateTrackSnapshotRowString(row, SlateTrackSnapshotRowKeyDuration);
    }
    else if ([colID isEqualToString:SlateTrackSnapshotColumnLanguage])
    {
        if (isreftrack)
            objectValue = [_owner grayString:SlateTrackSnapshotRowString(row, SlateTrackSnapshotRowKeyLanguage) rightAlign:NO fontWeight:fontWeight];
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
    NSDictionary *row = [_owner sessionRowDictionaryAtIndex:rowIndex];

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
    [self updateInspectorGainControlsForSessionRow:[self selectedSessionTrackRow]];
    [self applyScanabilityMetrics];
    [self updateTrackReadinessPanelPresentation];
    [self applyWorkspaceLayoutForWidth:NSWidth([[self view] bounds])];
}

- (void)awakeFromNib
{
    [self initializeTrackControllerDataIfNeeded];
    [self configureTrackTableDataSources];
    [self installDynamicTrackInspectorSurfaceIfNeeded];
    [self updateInspectorGainControlsForSessionRow:[self selectedSessionTrackRow]];
    [self applyScanabilityMetrics];
    [self updateTrackReadinessPanelPresentation];
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
    [dataCell setFont:SMTrackTableBodyFont(NSFontWeightRegular)];
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

    _sessionTrackItems = [[[NSMutableArray alloc] init] retain];

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
    [self updateInspectorGainControlsForSessionRow:[self selectedSessionTrackRow]];
}

- (void)layoutDynamicTrackInspectorSurface
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
                                  SMTrackInspectorDetailsAlignedTopY()));
    CGFloat detailsWidth = MIN(MAX(1.0, NSWidth([trackView bounds]) - (trackInset * 2.0)),
                               SMTrackDynamicDetailsFixedWidth);
    CGFloat detailsX = floor((NSWidth([trackView bounds]) - detailsWidth) * 0.5);
    [detailsScrollView setFrame:NSMakeRect(detailsX,
                                           detailsBottomY,
                                           detailsWidth,
                                           MAX(1.0, detailsTopY - detailsBottomY))];
    [self updateInspectorGainControlsForSessionRow:[self selectedSessionTrackRow]];
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

- (void)ensureTrackLayoutSupplementaryViews
{
    [self installDynamicTrackInspectorSurfaceIfNeeded];

    if (_advancedGroupBox == nil) {
        _advancedGroupBox = [[NSBox alloc] initWithFrame:NSZeroRect];
        SlateInspectorRailApplyToolGroupBoxStyle(_advancedGroupBox);
        [_advancedGroupBox setHidden:YES];
        [[self view] addSubview:_advancedGroupBox positioned:NSWindowBelow relativeTo:nil];
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
        _readinessPresenter = [[UtilReadinessRailPresenter alloc] initWithFindingsToolTipTitle:SMTrackReadinessFindingsToolTipTitle
                                                                  pinDefaultsKey:SMTrackInspectorRailPinnedDefaultsKey
                                                                           owner:self];
    }
    [_readinessPresenter ensureViewsInSuperview:[self view]];
    [_readinessPresenter restoreSubviewOrderWithOverlays:@[_advancedSectionLabel, _trackInspectorCopyButton]];
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

- (void)updateTrackReadinessPanelPresentation
{
    [self ensureTrackLayoutSupplementaryViews];
    SMMovie *currentMovie = SMTrackCurrentMovieFromAppController();

    NSString *emptyStatus = (currentMovie == nil) ? SMTrackReadinessStatusNoMovie : SMTrackReadinessStatusNoFindings;
    NSString *emptyMessage = (currentMovie == nil) ? @"" : SMTrackReadinessEmptyMessageNoFindings;
    [_readinessPresenter presentFindings:[self canonicalValidationFindings]
                                 paneKey:SlateReviewPaneKeyTrack
                             emptyStatus:emptyStatus
                            emptyMessage:emptyMessage
                      jumpLinkForFinding:^NSString *(NSDictionary *finding) {
        NSInteger rowIndex = NSNotFound;
        NSString *target = [self trackReadinessJumpTargetForFinding:finding rowIndex:&rowIndex];
        return SlateInspectorRailJumpLink(target, rowIndex);
    }];
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

- (void)applyTrackInspectorRailFrame:(NSRect)advancedGroupFrame
                  sectionLabelHeight:(CGFloat)sectionLabelHeight
{
    [_trackInspectorSurface setHidden:NO];
    [_advancedSectionLabel setHidden:NO];

    CGFloat advancedHeaderInsetX = SMTrackAdvancedHeaderInsetX;
    CGFloat advancedHeaderTopInset = SMTrackAdvancedHeaderTopInset;
    [_advancedGroupBox setFrame:advancedGroupFrame];
    [_advancedGroupBox setHidden:NO];
    [_advancedSectionLabel setFrame:NSMakeRect(NSMinX(advancedGroupFrame) + advancedHeaderInsetX,
                                               NSMaxY(advancedGroupFrame) - sectionLabelHeight - advancedHeaderTopInset,
                                               MAX(1.0, NSWidth(advancedGroupFrame) - advancedHeaderInsetX - 8.0),
                                               sectionLabelHeight)];

    [_trackInspectorSurface setFrame:advancedGroupFrame];
    [self layoutDynamicTrackInspectorSurface];

    NSRect advancedHeaderFrame = [_advancedSectionLabel frame];
    [_trackInspectorCopyButton setHidden:NO];
    [_trackInspectorCopyButton setFrame:NSMakeRect(NSMaxX(advancedGroupFrame) - SMTrackInspectorCopyButtonSize - SMTrackInspectorCopyButtonRightInset,
                                                   floor(NSMinY(advancedHeaderFrame) + ((NSHeight(advancedHeaderFrame) - SMTrackInspectorCopyButtonSize) * 0.5)),
                                                   SMTrackInspectorCopyButtonSize,
                                                   SMTrackInspectorCopyButtonSize)];
}

- (void)applyTrackTwoPaneLayoutForWidthClass:(SMWorkspaceWidthClass)widthClass
{
    [self ensureTrackLayoutSupplementaryViews];

    NSScrollView *tracksScrollView = [_tracks enclosingScrollView];
    if (tracksScrollView == nil || _trackInspectorSurface == nil) {
        [_advancedSectionLabel setHidden:YES];
        [_trackInspectorCopyButton setHidden:YES];
        [_readinessPresenter hideRail];
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
    CGFloat tableStartX = NSMinX(layoutBounds) + SlateWorkspacePrimaryPaneTableAnchorX();
    CGFloat railBottomY = NSMinY(layoutBounds) + SlateInspectorRailEffectiveBottomInsetForHostView([self view]);
    CGFloat sectionLabelHeight = SlateInspectorRailSectionHeaderHeight();
    CGFloat designContentTopY = SlateWorkspacePrimaryPaneTableAnchorTopY()
        + sectionLabelHeight
        + SlateInspectorRailSectionHeaderYOffset();
    CGFloat railContentTopY = NSMaxY(layoutBounds) - (NSHeight(defaultRootFrame) - designContentTopY);
    CGFloat maxTableContentTopY = railBottomY + SMTrackMaximumTableHeightForVisibleRows();
    CGFloat tableContentTopY = MIN(maxTableContentTopY, railContentTopY);
    CGFloat tableWidth = MAX(320.0, NSMaxX(layoutBounds) - SlateInspectorRailRightInset() - tableStartX);
    NSRect tableFrame = NSMakeRect(tableStartX,
                                   railBottomY,
                                   tableWidth,
                                   MAX(1.0, tableContentTopY - railBottomY));
    SlateInspectorRailTableLayout layout = SlateInspectorRailLayoutForTable(layoutBounds, tableFrame, widthClass,
                                                                            [_readinessPresenter isPinned]);
    [tracksScrollView setFrame:layout.tableFrame];

    if (layout.showInspector) {
        [self applyTrackInspectorRailFrame:layout.inspectorFrame sectionLabelHeight:sectionLabelHeight];
    } else {
        [_trackInspectorSurface setHidden:YES];
        [_advancedSectionLabel setHidden:YES];
        [_trackInspectorCopyButton setHidden:YES];
        [_advancedGroupBox setHidden:YES];
    }

    if (layout.showReadiness) {
        [_readinessPresenter layoutRailAtX:layout.readinessX
                                     topY:railContentTopY
                                  bottomY:railBottomY];
    } else {
        [_readinessPresenter hideRail];
    }
}

#pragma mark - Workspace Layout

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
    [layoutProbe setObject:[NSNumber numberWithBool:[_readinessPresenter isPinned]] forKey:@"pinState"];
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

    NSInteger rowCount = [_sessionTrackItems count];
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
    return (NSInteger)[_sessionTrackItems count];
}

- (NSView *)preferredModeFirstResponderView
{
    return _tracks;
}

#pragma mark - Session Row Projection

- (SMTrackSessionRow *)sessionTrackRowAtIndex:(NSInteger)rowIndex
{
    if (rowIndex < 0 || rowIndex >= (NSInteger)[_sessionTrackItems count]) {
        return nil;
    }

    TrackItem *trackItem = [_sessionTrackItems objectAtIndex:rowIndex];
    return [SMTrackSessionRow rowWithTrackItem:trackItem rowIndex:rowIndex];
}

- (NSArray *)sessionTrackRows
{
    NSMutableArray *rows = [NSMutableArray arrayWithCapacity:[_sessionTrackItems count]];
    for (NSInteger rowIndex = 0; rowIndex < (NSInteger)[_sessionTrackItems count]; rowIndex++) {
        SMTrackSessionRow *sessionRow = [self sessionTrackRowAtIndex:rowIndex];
        if (sessionRow != nil) {
            [rows addObject:sessionRow];
        }
    }

    return rows;
}

- (void)invalidateSessionRowProjection
{
    [_sessionRowProjection release];
    _sessionRowProjection = nil;
}

- (void)rebuildSessionRowProjection
{
    NSMutableArray *rows = [NSMutableArray arrayWithCapacity:[_sessionTrackItems count]];
    for (SMTrackSessionRow *sessionRow in [self sessionTrackRows]) {
        NSDictionary *row = [self dictionaryForSessionRow:sessionRow];
        if (row != nil) {
            [rows addObject:row];
        }
    }
    NSDictionary *projection = [NSDictionary dictionaryWithObjectsAndKeys:
                              SlateTrackSnapshotSchemaVersion1, SlateTrackSnapshotKeySchemaVersion,
                              [NSNumber numberWithBool:(SMTrackCurrentMovieFromAppController() != nil)], SlateTrackSnapshotKeyHasMovie,
                              rows, SlateTrackSnapshotKeyRows,
                              [NSNumber numberWithUnsignedInteger:rows.count], SlateTrackSnapshotKeyTrackCount,
                              nil];
    [_sessionRowProjection release];
    _sessionRowProjection = [projection retain];
}

- (NSDictionary *)dictionaryForSessionRow:(SMTrackSessionRow *)sessionRow
{
    if (sessionRow == nil) {
        return nil;
    }

    NSMutableDictionary *row = [NSMutableDictionary dictionary];
    NSString *language = [sessionRow language] ?: @"Unknown";
    NSString *trackTypeLabel = [sessionRow trackTypeLabel] ?: @"";
    NSString *trackTypeColumn = [sessionRow trackTypeColumnDisplayName] ?: @"";
    NSString *displayName = [sessionRow displayName] ?: @"";
    NSString *formatSummary = [sessionRow formatSummary] ?: @"";
    NSString *duration = [sessionRow durationString] ?: @"0:00:00:00";
    NSString *enabledString = [sessionRow enabledDisplayString] ?: @"No";
    BOOL audioTrack = [sessionRow isAudioTrack] || SMTrackMediaTypeMatches([sessionRow mediaType], SMMediaTypeSound);
    BOOL videoTrack = [sessionRow isVideoTrack] || SMTrackMediaTypeMatches([sessionRow mediaType], SMMediaTypeVideo);

    [row setObject:[NSNumber numberWithInteger:[sessionRow rowIndex]] forKey:SlateTrackSnapshotRowKeyRowIndex];
    [row setObject:[NSNumber numberWithInteger:([sessionRow rowIndex] + 1)] forKey:SlateTrackSnapshotRowKeyRow];
    [row setObject:[NSNumber numberWithUnsignedInt:[sessionRow ident]] forKey:SlateTrackSnapshotRowKeyTrackID];
    [row setObject:([sessionRow sessionIdentity] ?: @"") forKey:SlateTrackSnapshotRowKeySessionIdentity];
    [row setObject:enabledString forKey:SlateTrackSnapshotRowKeyEnabled];
    [row setObject:[NSNumber numberWithBool:[sessionRow isEnabled]] forKey:SlateTrackSnapshotRowKeyEnabledFlag];
    [row setObject:[NSNumber numberWithBool:[sessionRow isReferenceTrack]] forKey:SlateTrackSnapshotRowKeyReferenceTrack];
    [row setObject:[NSNumber numberWithBool:[sessionRow isFakeTrack]] forKey:SlateTrackSnapshotRowKeyFakeTrack];
    [row setObject:[NSNumber numberWithBool:audioTrack] forKey:SlateTrackSnapshotRowKeyAudioTrack];
    [row setObject:[NSNumber numberWithBool:videoTrack] forKey:SlateTrackSnapshotRowKeyVideoTrack];
    [row setObject:[NSNumber numberWithBool:[sessionRow isSubtitleTrack]] forKey:SlateTrackSnapshotRowKeySubtitleTrack];
    [row setObject:[NSNumber numberWithBool:[sessionRow isClosedCaptionTrack]] forKey:SlateTrackSnapshotRowKeyClosedCaptionTrack];
    [row setObject:[NSNumber numberWithBool:[sessionRow isTextTrack]] forKey:SlateTrackSnapshotRowKeyTextTrack];
    [row setObject:[NSNumber numberWithBool:[sessionRow isTimecodeTrack]] forKey:SlateTrackSnapshotRowKeyTimecodeTrack];
    [row setObject:(trackTypeLabel.length > 0 ? trackTypeLabel : @"(none)") forKey:SlateTrackSnapshotRowKeyTrackType];
    [row setObject:trackTypeColumn forKey:SlateTrackSnapshotRowKeyTrackTypeColumn];
    [row setObject:([sessionRow mediaType] ?: @"") forKey:SlateTrackSnapshotRowKeyMediaType];
    [row setObject:duration forKey:SlateTrackSnapshotRowKeyDuration];
    [row setObject:language forKey:SlateTrackSnapshotRowKeyLanguage];
    [row setObject:(displayName.length > 0 ? displayName : @"(none)") forKey:SlateTrackSnapshotRowKeyDisplayName];
    [row setObject:(formatSummary.length > 0 ? formatSummary : @"(none)") forKey:SlateTrackSnapshotRowKeyFormatSummary];
    [row setObject:((audioTrack || videoTrack) ? formatSummary : @"") forKey:SlateTrackSnapshotRowKeyInfo];
    [row setObject:[NSNumber numberWithFloat:[sessionRow audioGain]] forKey:SlateTrackSnapshotRowKeyAudioGain];
    [row setObject:[NSNumber numberWithShort:[sessionRow encodedWidth]] forKey:SlateTrackSnapshotRowKeyEncodedWidth];
    [row setObject:[NSNumber numberWithShort:[sessionRow encodedHeight]] forKey:SlateTrackSnapshotRowKeyEncodedHeight];
    [row setObject:[NSNumber numberWithFloat:[sessionRow displayWidth]] forKey:SlateTrackSnapshotRowKeyDisplayWidth];
    [row setObject:[NSNumber numberWithFloat:[sessionRow displayHeight]] forKey:SlateTrackSnapshotRowKeyDisplayHeight];
    [row setObject:[self sessionTrackDetailPairs:sessionRow] forKey:SlateTrackSnapshotRowKeyDetails];
    [row setObject:[self sessionTrackDetailsString:sessionRow] forKey:SlateTrackSnapshotRowKeyDetailsText];

    if (audioTrack) {
        NSDictionary *layout = SMTrackSessionAudioLayoutSummary([sessionRow track]);
        [row setObject:[layout objectForKey:@"channelCount"] forKey:SlateTrackSnapshotRowKeyAudioChannelCount];
        [row setObject:[layout objectForKey:@"resolved"] forKey:SlateTrackSnapshotRowKeyAudioChannelLayoutResolved];
        [row setObject:[layout objectForKey:@"genericAssignments"] forKey:SlateTrackSnapshotRowKeyAudioChannelAssignmentsGeneric];
    }

    NSURL *sourceURL = [sessionRow sourceURL];
    if (sourceURL.isFileURL && sourceURL.path.length > 0) {
        [row setObject:sourceURL.path forKey:SlateTrackSnapshotRowKeySourcePath];
    }

    return row;
}

- (NSDictionary *)sessionRowProjection
{
    if (_sessionRowProjection == nil) {
        [self rebuildSessionRowProjection];
    }
    return _sessionRowProjection;
}

- (NSArray *)validationObservedTrackRows
{
    NSArray *rows = [[self sessionRowProjection] objectForKey:SlateTrackSnapshotKeyRows];
    return [rows isKindOfClass:[NSArray class]] ? rows : [NSArray array];
}

- (NSInteger)selectedAssetTypeID
{
    if (_assetTypePopup == nil || [_assetTypePopup indexOfSelectedItem] == 0) {
        return 0;
    }
    return [_assetTypePopup selectedTag];
}

- (NSDictionary *)sessionRowDictionaryAtIndex:(NSInteger)rowIndex
{
    NSArray *rows = [[self sessionRowProjection] objectForKey:SlateTrackSnapshotKeyRows];
    if (![rows isKindOfClass:[NSArray class]]
        || rowIndex < 0
        || rowIndex >= (NSInteger)[rows count]) {
        return nil;
    }

    NSDictionary *row = [rows objectAtIndex:rowIndex];
    return [row isKindOfClass:[NSDictionary class]] ? row : nil;
}

- (NSArray *)sessionRowDictionaries
{
    NSArray *rows = [[self sessionRowProjection] objectForKey:SlateTrackSnapshotKeyRows];
    return [rows isKindOfClass:[NSArray class]] ? rows : [NSArray array];
}

- (NSArray *)trackMovieInspectorDetailRows
{
    NSMutableArray *rows = [NSMutableArray arrayWithCapacity:[_sessionTrackItems count]];

    for (NSDictionary *sessionRow in [self sessionRowDictionaries]) {
        NSMutableDictionary *row = [NSMutableDictionary dictionary];
        [row setObject:[sessionRow objectForKey:SlateTrackSnapshotRowKeyRowIndex] forKey:@"rowIndex"];
        [row setObject:[sessionRow objectForKey:SlateTrackSnapshotRowKeyRow] forKey:@"row"];
        [row setObject:[sessionRow objectForKey:SlateTrackSnapshotRowKeyTrackID] forKey:@"trackID"];
        [row setObject:([sessionRow objectForKey:SlateTrackSnapshotRowKeySessionIdentity] ?: @"") forKey:@"sessionIdentity"];
        [row setObject:SlateTrackSnapshotRowString(sessionRow, SlateTrackSnapshotRowKeyTrackType) forKey:@"trackType"];
        [row setObject:SlateTrackSnapshotRowString(sessionRow, SlateTrackSnapshotRowKeyMediaType) forKey:@"mediaType"];
        [row setObject:SlateTrackSnapshotRowString(sessionRow, SlateTrackSnapshotRowKeyEnabled) forKey:@"enabled"];
        [row setObject:[sessionRow objectForKey:SlateTrackSnapshotRowKeyReferenceTrack] forKey:@"referenceTrack"];
        [row setObject:[sessionRow objectForKey:SlateTrackSnapshotRowKeyFakeTrack] forKey:@"fakeTrack"];
        [row setObject:SlateTrackSnapshotRowString(sessionRow, SlateTrackSnapshotRowKeyDuration) forKey:@"duration"];
        [row setObject:SlateTrackSnapshotRowString(sessionRow, SlateTrackSnapshotRowKeyLanguage) forKey:@"language"];
        [row setObject:SlateTrackSnapshotRowString(sessionRow, SlateTrackSnapshotRowKeyDisplayName) forKey:@"displayName"];
        [row setObject:SlateTrackSnapshotRowString(sessionRow, SlateTrackSnapshotRowKeyFormatSummary) forKey:@"formatSummary"];
        [row setObject:([[sessionRow objectForKey:SlateTrackSnapshotRowKeyDetails] isKindOfClass:[NSArray class]] ? [sessionRow objectForKey:SlateTrackSnapshotRowKeyDetails] : [NSArray array]) forKey:@"details"];
        [row setObject:SlateTrackSnapshotRowString(sessionRow, SlateTrackSnapshotRowKeyDetailsText) forKey:@"detailsText"];

        NSString *sourcePath = [sessionRow objectForKey:SlateTrackSnapshotRowKeySourcePath];
        if ([sourcePath isKindOfClass:[NSString class]] && [sourcePath length] > 0) {
            [row setObject:sourcePath forKey:@"sourcePath"];
        }

        [rows addObject:row];
    }

    return rows;
}

- (SMTrackSessionRow *)selectedSessionTrackRow
{
    return [self sessionTrackRowAtIndex:[_tracks selectedRow]];
}

#pragma mark - Inspector Details

-(void)updateInspectorGainControlsForSessionRow:(SMTrackSessionRow *)snapshot
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

- (NSArray *)sessionTrackDetailPairs:(SMTrackSessionRow *)snapshot
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
        NSDictionary *layout = SMTrackSessionAudioLayoutSummary(track);
        SMTrackAppendDetailsPairToArray(pairs, @"Channel Layout", [layout objectForKey:@"summary"]);
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

- (NSString *)sessionTrackDetailsString:(SMTrackSessionRow *)snapshot
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

    for (NSDictionary *pair in [self sessionTrackDetailPairs:snapshot]) {
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
    NSString *detailsText = SlateTrackSnapshotRowString([self sessionRowDictionaryAtIndex:[_tracks selectedRow]],
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
        detailsText = SlateTrackSnapshotRowString([self sessionRowDictionaryAtIndex:[_tracks selectedRow]],
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
    [self invalidateSessionRowProjection];
    [_tracks reloadData];

    NSInteger rowCount = [_sessionTrackItems count];
    if (rowCount <= 0)
    {
        [self updateInspectorGainControlsForSessionRow:nil];
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
    for (SMTrackSessionRow *snapshot in [self sessionTrackRows])
        if ([snapshot isPrimaryVideoTrack])
            return YES;

    return NO;
}

- (BOOL)hasPrimaryAudioTrack
{
    for (SMTrackSessionRow *snapshot in [self sessionTrackRows])
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

static BOOL SMReferenceAudioTrackSnapshotHasResolvableSource(SMTrackSessionRow *snapshot)
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
    for (SMTrackSessionRow *snapshot in [self sessionTrackRows]) {
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
    for (SMTrackSessionRow *snapshot in [self sessionTrackRows]) {
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
    for (NSDictionary *row in [[self sessionRowProjection] objectForKey:SlateTrackSnapshotKeyRows]) {
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
    for (NSDictionary *row in [[self sessionRowProjection] objectForKey:SlateTrackSnapshotKeyRows]) {
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
    for (NSDictionary *row in [[self sessionRowProjection] objectForKey:SlateTrackSnapshotKeyRows]) {
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
    for (NSDictionary *row in [[self sessionRowProjection] objectForKey:SlateTrackSnapshotKeyRows]) {
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
    for (SMTrackSessionRow *snapshot in [self sessionTrackRows]) {
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
    for (SMTrackSessionRow *snapshot in [self sessionTrackRows]) {
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
    for (SMTrackSessionRow *snapshot in [self sessionTrackRows]) {
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
    for (SMTrackSessionRow *snapshot in [self sessionTrackRows]) {
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
    return [[self sessionTrackRowAtIndex:row] referenceTrackTypeLabel] ?: @"Reference track";
}

- (NSInteger)firstTextTrackRowWithUnknownLanguage
{
    for (SMTrackSessionRow *snapshot in [self sessionTrackRows]) {
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
    for (SMTrackSessionRow *snapshot in [self sessionTrackRows]) {
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
    for (SMTrackSessionRow *snapshot in [self sessionTrackRows]) {
        if (![snapshot isReferenceTrack] && SMTrackMediaTypeMatches([snapshot mediaType], SMMediaTypeText)) {
            return [snapshot rowIndex];
        }
    }

    return NSNotFound;
}

- (NSUInteger)unresolvedRoleTextTrackCount
{
    NSUInteger count = 0;
    for (SMTrackSessionRow *snapshot in [self sessionTrackRows]) {
        if (![snapshot isReferenceTrack] && SMTrackMediaTypeMatches([snapshot mediaType], SMMediaTypeText)) {
            count++;
        }
    }
    return count;
}

- (NSString *)textTrackRoleLabelForRow:(NSInteger)row
{
    return [[self sessionTrackRowAtIndex:row] textTrackRoleLabel] ?: @"Text track";
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
{
    TrackItem *newTrack = [[trackClass alloc] init];
    if (newTrack == nil)
        return;

    newTrack.isreftrack = YES;
    newTrack.track = track;
    newTrack.sessionIdentity = SMTrackSessionIdentity(track, nil, YES, [_sessionTrackItems count]);
    newTrack.language = [self langForTrack:track];
    if ([newTrack isKindOfClass:[AudioTrackItem class]] &&
        [newTrack.language isEqualToString:@"Unknown"]) {
        newTrack.language = @"N/A";
    }

    SMTime trackDuration = [[[track media] attributeForKey:SMMediaDurationAttribute] SMTimeValue];
    newTrack.duration = (trackDuration.timeScale != 0) ? ((double)trackDuration.timeValue / (double)trackDuration.timeScale) * 1000.0 : 0;

    [_sessionTrackItems addObject:newTrack];
    [self renumberReferenceTrackDisplayIDs];
    [newTrack release];
}

- (void)renumberReferenceTrackDisplayIDs
{
    uint32_t highestEmbeddedTrackID = 0;
    for (TrackItem *trackItem in _sessionTrackItems) {
        if (![trackItem isreftrack] && [trackItem ident] > highestEmbeddedTrackID) {
            highestEmbeddedTrackID = [trackItem ident];
        }
    }

    uint64_t nextDisplayID = (uint64_t)highestEmbeddedTrackID + 1;
    for (TrackItem *trackItem in _sessionTrackItems) {
        if (![trackItem isreftrack]) {
            continue;
        }
        if (nextDisplayID > UINT32_MAX) {
            return;
        }
        [trackItem setIdent:(uint32_t)nextDisplayID++];
    }
}

-(void)refreshTrackData
{
    SMMovie *movie = [appcontroller() movie];
    [_sessionTrackItems removeAllObjects];
    
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
            newTrack.sessionIdentity = SMTrackSessionIdentity(track, [movie URL], NO, [_sessionTrackItems count]);
            newTrack.language = [self langForTrack:track];

            SMTime duration = [[[track media] attributeForKey:SMMediaDurationAttribute] SMTimeValue];
            newTrack.duration = (duration.timeScale != 0) ? ((double)duration.timeValue / (double)duration.timeScale) * 1000.0 : 0;

            [_sessionTrackItems addObject:newTrack];

            [newTrack release];
        }
    }

    for (SMTrack *track in [movie sessionReferenceTracks])
    {
        NSString *mediaType = [track attributeForKey:SMTrackMediaTypeAttribute];
        Class trackClass = [mediaType isEqualToString:SMMediaTypeSound]
            ? [AudioTrackItem class]
            : ([mediaType isEqualToString:SMMediaTypeClosedCaption]
               ? [ClosedCaptionTrackItem class]
               : ([mediaType isEqualToString:SMMediaTypeSubtitle] ? [SubtitleTrackItem class] : [TrackItem class]));
        [self appendReferenceTrackItemForTrack:track trackClass:trackClass];
    }
    
    [self reloadTracksTableSelectingFirstRowIfNeeded];
    [self updateTrackReadinessPanelPresentation];
}

- (void)refreshSessionTrackRows
{
    [self refreshTrackData];
    [self refreshValidationAdaptersAfterMutation];
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
- (NSDictionary *)importSubtitleFromURL:(NSURL *)url importer:(SMTrack *(^)(NSError **error, NSArray **diagnostics))importer
{
    SMMovie *movie = [appcontroller() movie];
    if ([movie hasSubtitleSidecarTrackForSourceURL:url]) {
        return SMReferenceImportOutcome(SMReferenceImportOutcomeDuplicate, 0, 0, nil);
    }

    NSError *error = nil;
    NSArray *diagnostics = nil;
    NSUInteger priorTrackCount = [[movie subtitleSidecarTracks] count];
    SMTrack *track = importer(&error, &diagnostics);
    NSUInteger trackCount = [[movie subtitleSidecarTracks] count] - priorTrackCount;
    if (error != nil || track == nil || trackCount == 0) {
        if ([movie hasSubtitleSidecarTrackForSourceURL:url] && trackCount == 0) {
            return SMReferenceImportOutcome(SMReferenceImportOutcomeDuplicate, 0, 0, nil);
        }
        return SMReferenceImportOutcome(SMReferenceImportOutcomeFailure,
                                        trackCount,
                                        0,
                                        SMReferenceImportFailureReason(error, diagnostics));
    }

    NSUInteger rejectedCueCount = SMRejectedSubtitleCueCount(diagnostics);
    if (rejectedCueCount > 0) {
        NSString *warning = SMSubtitleDiagnosticMessage([diagnostics firstObject]);
        return SMReferenceImportOutcome(SMReferenceImportOutcomePartial, trackCount, rejectedCueCount, warning);
    }
    return SMReferenceImportOutcome(SMReferenceImportOutcomeSuccess, trackCount, 0, nil);
}

- (NSDictionary *)importITTSubtitleFromURL:(NSURL *)url
{
    SMMovie *movie = [appcontroller() movie];
    return [self importSubtitleFromURL:url importer:^SMTrack *(NSError **error, NSArray **diagnostics) {
        return [movie addSidecarITTSubtitleTrackFromURL:url error:error diagnostics:diagnostics];
    }];
}

- (NSDictionary *)importSRTSubtitleFromURL:(NSURL *)url
{
    SMMovie *movie = [appcontroller() movie];
    return [self importSubtitleFromURL:url importer:^SMTrack *(NSError **error, NSArray **diagnostics) {
        return [movie addSidecarSRTSubtitleTrackFromURL:url error:error diagnostics:diagnostics];
    }];
}

- (NSDictionary *)importTTMLSubtitleFromURL:(NSURL *)url
{
    SMMovie *movie = [appcontroller() movie];
    return [self importSubtitleFromURL:url importer:^SMTrack *(NSError **error, NSArray **diagnostics) {
        return [movie addSidecarTTMLSubtitleTrackFromURL:url error:error diagnostics:diagnostics];
    }];
}

- (NSDictionary *)importSCCSubtitleFromURL:(NSURL *)url
{
    SMMovie *movie = [appcontroller() movie];
    return [self importSubtitleFromURL:url importer:^SMTrack *(NSError **error, NSArray **diagnostics) {
        return [movie addSidecarSCCSubtitleTrackFromURL:url error:error diagnostics:diagnostics];
    }];
}

#pragma mark - NSTableView Delegate
-(void)tableViewSelectionDidChange:(NSNotification *)notif
{
	NSTableView *tableView = [notif object];
    
    NSInteger rowIdx = [tableView selectedRow];

    if (rowIdx < 0)
    {
        [self updateInspectorGainControlsForSessionRow:nil];
        [self updateTrackInspectorDetailsText];
        return;
    }
    else if ([tableView isEqual:_tracks])
    {
        [self updateInspectorGainControlsForSessionRow:[self sessionTrackRowAtIndex:rowIdx]];
        [self updateTrackInspectorDetailsText];
    }
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
    #pragma unused(tableView, tableColumn)
    if ([cell isKindOfClass:[VertCenterTextFieldCell class]]) {
        NSDictionary *row = [self sessionRowDictionaryAtIndex:rowIndex];
        [cell setFont:SMTrackTableBodyFont(SMTrackTableFontWeightForRow(row))];
    }
}

- (NSAttributedString *)grayString:(NSString *)string rightAlign:(BOOL)rightAlign fontWeight:(NSFontWeight)fontWeight
{
    NSMutableParagraphStyle * ps = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [ps setHeadIndent: -10.0];
    [ps setAlignment: rightAlign ? NSRightTextAlignment : NSLeftTextAlignment];
    
    return [[NSAttributedString alloc]initWithString:string attributes:[NSDictionary dictionaryWithObjectsAndKeys:
                       [NSFont systemFontOfSize:11.0 weight:fontWeight], NSFontAttributeName,
                       ps, NSParagraphStyleAttributeName,
                       [NSColor grayColor], NSForegroundColorAttributeName,
                       nil]];
}

#pragma mark - Track Command Surface

// All live writes pass through here; table/view code calls commands.
- (TrackItem *)trackCommandItemAtIndex:(NSInteger)rowIndex
{
    if (rowIndex < 0 || rowIndex >= (NSInteger)[_sessionTrackItems count]) {
        return nil;
    }

    return [_sessionTrackItems objectAtIndex:rowIndex];
}

- (TrackItem *)trackCommandItemWithSessionIdentity:(NSString *)sessionIdentity
{
    for (TrackItem *trackItem in _sessionTrackItems) {
        if ([[trackItem sessionIdentity] isEqualToString:sessionIdentity]) {
            return trackItem;
        }
    }

    return nil;
}

- (void)performTrackCommandRestoreMovieStateRebuildingTracks:(BOOL)rebuildTracks
{
    SMMovie *movie = [appcontroller() movie];

    [movie gotoBeginning];

    for (SMTrackSessionRow *snapshot in [self sessionTrackRows]) {
        if ([snapshot isReferenceTrack] && [snapshot isAudioTrack]) {
            [movie removeTrack:[snapshot track]];
        }
    }

    NSArray *trackArray = [movie tracksOfMediaType:SMMediaTypeSound];
    for (int i = 0; i < trackArray.count; i++) {
        [[trackArray objectAtIndex:i] setEnabled:YES];
    }

    if (rebuildTracks) {
        [_sessionTrackItems removeAllObjects];
        [self refreshTrackData];
    } else {
        [self invalidateSessionRowProjection];
    }
    [self refreshValidationAdaptersAfterMutation];
}

- (void)performTrackCommandRemoveMovieReference
{
    [_sessionTrackItems removeAllObjects];

    [self invalidateSessionRowProjection];
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
    [self invalidateSessionRowProjection];
    [self updateTrackInspectorDetailsText];
}

- (void)performTrackCommandSetTrackGainForSessionIdentity:(NSString *)sessionIdentity value:(float)value
{
    [self performTrackCommandSetTrackGainForItem:[self trackCommandItemWithSessionIdentity:sessionIdentity] value:value];
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

    for (SMTrackSessionRow *snapshot in [self sessionTrackRows]) {
        BOOL shouldApplyToRow = (target == SMTrackCommandLanguageTargetAudio)
            ? [snapshot isAudioTrack]
            : ![snapshot isAudioTrack];
        if (shouldApplyToRow) {
            [[self trackCommandItemAtIndex:[snapshot rowIndex]] setLanguage:[item title]];
        }
    }

    [self invalidateSessionRowProjection];
    [_tracks reloadData];
    [self refreshValidationAdaptersAfterMutation];
}

- (void)performTrackCommandToggleEnabledAtRow:(NSInteger)rowIndex
{
    TrackItem *trackItem = [self trackCommandItemAtIndex:rowIndex];
    SMTrackSessionRow *snapshot = [self sessionTrackRowAtIndex:rowIndex];
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
    [self invalidateSessionRowProjection];
    [_tracks reloadData];
    [self refreshValidationAdaptersAfterMutation];
}

- (BOOL)performTrackCommandCanDeleteRow:(NSInteger)rowIndex
{
    SMTrackSessionRow *snapshot = [self sessionTrackRowAtIndex:rowIndex];
    return (snapshot != nil && ([snapshot isFakeTrack] || [snapshot isReferenceTrack]));
}

- (void)performTrackCommandDeleteRow:(NSInteger)rowIndex
{
    TrackItem *trackItem = [self trackCommandItemAtIndex:rowIndex];
    if (trackItem == nil || ![self performTrackCommandCanDeleteRow:rowIndex]) {
        return;
    }

    // SMMovie removes fake sidecars from their in-memory descriptors and
    // imported reference tracks from the session collection. Embedded movie
    // tracks are rejected above and never reach its movie-track removal path.
    [[appcontroller() movie] removeTrack:[trackItem track]];
    [self refreshTrackData];
    [appcontroller() refreshTimelineDurationFromPlaybackState];
    [appcontroller() syncSidecarVisibilityState];
    [[appcontroller() playerView] refreshSubtitleOverlay];
    [self refreshValidationAdaptersAfterMutation];
}

- (void)performTrackCommandFinishReferenceImport
{
    [self refreshTrackData];
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

-(void)setTrackGainForSessionIdentity:(NSString *)sessionIdentity value:(float)value
{
    [self performTrackCommandSetTrackGainForSessionIdentity:sessionIdentity value:value];
}

-(IBAction)inspectorGainSliderChanged:(id)sender
{
    float value = [_gainSlider floatValue];
    if (_gainSliderTargetsMovie) {
        [[[[self view] undoManager] prepareWithInvocationTarget:self] setMovieGain:value];
        [self setMovieGain:[sender floatValue]];
        return;
    }

    SMTrackSessionRow *snapshot = [self selectedSessionTrackRow];
    if (snapshot == nil) {
        return;
    }
    NSString *sessionIdentity = [snapshot sessionIdentity];
    [[[[self view] undoManager] prepareWithInvocationTarget:self] setTrackGainForSessionIdentity:sessionIdentity value:value];
    [self setTrackGainForSessionIdentity:sessionIdentity value:[sender floatValue]];
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

-(void)applyReferenceAudioFallbackFormat:(NSString *)fallbackFormatSummary toTrack:(SMTrack *)referenceTrack
{
    NSString *formatSummary = [referenceTrack attributeForKey:SMTrackFormatSummaryAttribute];
    if ((formatSummary == nil || formatSummary.length == 0) && fallbackFormatSummary.length > 0) {
        [referenceTrack setAttribute:fallbackFormatSummary forKey:SMTrackFormatSummaryAttribute];
    }
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

-(NSArray *)importReferenceAudioTracksFromMovieURL:(NSURL *)url error:(NSError **)error
{
    SMMovie *movie = [appcontroller() movie];
    NSArray *tracks = [movie addPlaybackReferenceAudioTracksFromURL:url error:error];
    for (SMTrack *track in tracks)
        [self applyReferenceAudioFallbackFormat:@"MOV Audio" toTrack:track];
    return tracks;
}

-(NSArray *)importReferenceAudioTracksFromAssetURL:(NSURL *)url pathExtension:(NSString *)pathExtension error:(NSError **)error
{
    SMMovie *movie = [appcontroller() movie];
    NSString *fallbackFormatSummary = [[pathExtension uppercaseString] stringByAppendingString:@" Audio"];
    NSArray *importedTracks = [movie addPlaybackReferenceAudioTracksFromURL:url error:error];
    for (SMTrack *referenceTrack in importedTracks)
        [self applyReferenceAudioFallbackFormat:fallbackFormatSummary toTrack:referenceTrack];
    return importedTracks;
}

-(void)createReferenceTrack:(NSArray *)items
{
    dispatch_async(dispatch_get_main_queue(), ^ {
    NSUInteger priorTrackCount = [_sessionTrackItems count];
    NSMutableArray *importOutcomes = [NSMutableArray array];
    SMMovie *movie = [appcontroller() movie];
    for (NSURL *url in items)
    {
        NSString *pathExtension = [[url pathExtension] lowercaseString];
        BOOL isMovieAudio = [pathExtension isEqualToString:@"mov"];
        BOOL isStandaloneAudio = ([pathExtension isEqualToString:@"wav"]
                                  || [pathExtension isEqualToString:@"aif"]
                                  || [pathExtension isEqualToString:@"aiff"]
                                  || [pathExtension isEqualToString:@"m4a"]
                                  || [pathExtension isEqualToString:@"mp3"]
                                  || [pathExtension isEqualToString:@"caf"]);
        BOOL isSubtitle = ([pathExtension isEqualToString:@"scc"]
                           || [pathExtension isEqualToString:@"itt"]
                           || [pathExtension isEqualToString:@"srt"]
                           || [pathExtension isEqualToString:@"ttml"]
                           || [pathExtension isEqualToString:@"dfxp"]);
        if (!isMovieAudio && !isStandaloneAudio && !isSubtitle) {
            continue;
        }

        @try
        {
            NSDictionary *outcome = nil;
            if (isMovieAudio || isStandaloneAudio)
            {
                NSError *error = nil;
                NSArray *tracks = isMovieAudio
                    ? [self importReferenceAudioTracksFromMovieURL:url error:&error]
                    : [self importReferenceAudioTracksFromAssetURL:url pathExtension:pathExtension error:&error];
                if (tracks.count > 0) {
                    outcome = SMReferenceImportOutcome(SMReferenceImportOutcomeSuccess, tracks.count, 0, nil);
                } else {
                    BOOL alreadyPresent = NO;
                    for (SMTrack *existingTrack in [movie sessionReferenceTracks]) {
                        if (SMReferenceTrackHasSourceURL(existingTrack, url)) {
                            alreadyPresent = YES;
                            break;
                        }
                    }
                    if (alreadyPresent) {
                        outcome = SMReferenceImportOutcome(SMReferenceImportOutcomeDuplicate, 0, 0, nil);
                    } else if (error != nil) {
                        outcome = SMReferenceImportOutcome(SMReferenceImportOutcomeFailure,
                                                           0,
                                                           0,
                                                           error.localizedDescription ?: @"The audio file could not be imported.");
                    } else {
                        outcome = SMReferenceImportOutcome(SMReferenceImportOutcomeFailure,
                                                           0,
                                                           0,
                                                           isMovieAudio ? @"No audio tracks were found in the movie." : @"The audio file did not produce a reference track.");
                    }
                }
            }
            else if ([pathExtension isEqualToString:@"scc"])
            {
                outcome = [self importSCCSubtitleFromURL:url];
            }
            else if ([pathExtension isEqualToString:@"itt"])
            {
                outcome = [self importITTSubtitleFromURL:url];
            }
            else if ([pathExtension isEqualToString:@"srt"])
            {
                outcome = [self importSRTSubtitleFromURL:url];
            }
            else
            {
                outcome = [self importTTMLSubtitleFromURL:url];
            }

            NSMutableDictionary *outcomeWithURL = [NSMutableDictionary dictionaryWithDictionary:outcome ?: SMReferenceImportOutcome(SMReferenceImportOutcomeFailure, 0, 0, @"The file could not be imported.")];
            [outcomeWithURL setObject:url forKey:@"url"];
            [importOutcomes addObject:outcomeWithURL];
        }
        @catch (NSException *exception)
        {
            NSLog(@"Ignoring reference import %@ after exception during import: %@", [url lastPathComponent], exception);
            NSMutableDictionary *outcomeWithURL = [NSMutableDictionary dictionaryWithDictionary:
                                                   SMReferenceImportOutcome(SMReferenceImportOutcomeFailure,
                                                                            0,
                                                                            0,
                                                                            exception.reason ?: @"An unexpected error interrupted the import.")];
            [outcomeWithURL setObject:url forKey:@"url"];
            [importOutcomes addObject:outcomeWithURL];
        }
    }
    
    [self performTrackCommandFinishReferenceImport];
    NSUInteger addedTrackCount = [_sessionTrackItems count] > priorTrackCount
        ? [_sessionTrackItems count] - priorTrackCount
        : 0;
    if (addedTrackCount > 0) {
        NSInteger rowToSelect = (NSInteger)priorTrackCount;
        if (rowToSelect >= 0 && rowToSelect < [_tracks numberOfRows]) {
            [_tracks selectRowIndexes:[NSIndexSet indexSetWithIndex:rowToSelect] byExtendingSelection:NO];
            [_tracks scrollRowToVisible:rowToSelect];
            [self tableViewSelectionDidChange:[NSNotification notificationWithName:NSTableViewSelectionDidChangeNotification
                                                                            object:_tracks]];
        }
    }

    if (importOutcomes.count == 1) {
        NSDictionary *outcome = [importOutcomes objectAtIndex:0];
        NSString *kind = [outcome objectForKey:SMReferenceImportOutcomeKindKey];
        NSURL *url = [outcome objectForKey:@"url"];
        NSString *fileName = url.lastPathComponent ?: @"selected file";
        NSUInteger trackCount = [[outcome objectForKey:SMReferenceImportOutcomeTrackCountKey] unsignedIntegerValue];
        NSUInteger rejectedCueCount = [[outcome objectForKey:SMReferenceImportOutcomeRejectedCueCountKey] unsignedIntegerValue];
        NSString *reason = [outcome objectForKey:SMReferenceImportOutcomeReasonKey];

        if ([kind isEqualToString:SMReferenceImportOutcomeSuccess]) {
            [appcontroller() showStatusMessage:SMCompactReferenceImportStatusMessage(
                                                [NSString stringWithFormat:@"Added %lu track%@.",
                                                 (unsigned long)trackCount,
                                                 trackCount == 1 ? @"" : @"s"])
                                        persist:NO];
        } else if ([kind isEqualToString:SMReferenceImportOutcomePartial]) {
            NSString *message = [NSString stringWithFormat:@"%@: +%lu track%@; %lu cue%@ skipped.",
                                 fileName,
                                 (unsigned long)trackCount,
                                 trackCount == 1 ? @"" : @"s",
                                 (unsigned long)rejectedCueCount,
                                 rejectedCueCount == 1 ? @"" : @"s"];
            if (reason.length > 0) {
                message = [message stringByAppendingFormat:@" %@", reason];
            }
            [appcontroller() showStatusMessage:SMCompactReferenceImportStatusMessage(message) persist:NO];
        } else if ([kind isEqualToString:SMReferenceImportOutcomeDuplicate]) {
            [appcontroller() showStatusMessage:SMCompactReferenceImportStatusMessage(
                                                [NSString stringWithFormat:@"Already present: %@", fileName])
                                        persist:NO];
        } else {
            [appcontroller() showStatusMessage:SMCompactReferenceImportStatusMessage(
                                                [NSString stringWithFormat:@"%@: %@",
                                                 fileName,
                                                 reason ?: @"Import failed."])
                                        persist:NO];
        }
    } else if (importOutcomes.count > 1) {
        NSUInteger successCount = 0;
        NSUInteger partialCount = 0;
        NSUInteger failureCount = 0;
        NSUInteger duplicateCount = 0;
        NSUInteger rejectedCueCount = 0;
        NSDictionary *firstFailure = nil;
        for (NSDictionary *outcome in importOutcomes) {
            NSString *kind = [outcome objectForKey:SMReferenceImportOutcomeKindKey];
            rejectedCueCount += [[outcome objectForKey:SMReferenceImportOutcomeRejectedCueCountKey] unsignedIntegerValue];
            if ([kind isEqualToString:SMReferenceImportOutcomeSuccess]) {
                successCount++;
            } else if ([kind isEqualToString:SMReferenceImportOutcomePartial]) {
                partialCount++;
            } else if ([kind isEqualToString:SMReferenceImportOutcomeDuplicate]) {
                duplicateCount++;
            } else {
                failureCount++;
                if (firstFailure == nil) {
                    firstFailure = outcome;
                }
            }
        }

        NSString *message = [NSString stringWithFormat:@"%lu ok, %lu partial, %lu failed, %lu duplicate; %lu track%@, %lu cue%@ skipped.",
                             (unsigned long)successCount,
                             (unsigned long)partialCount,
                             (unsigned long)failureCount,
                             (unsigned long)duplicateCount,
                             (unsigned long)addedTrackCount,
                             addedTrackCount == 1 ? @"" : @"s",
                             (unsigned long)rejectedCueCount,
                             rejectedCueCount == 1 ? @"" : @"s"];
        if (firstFailure != nil) {
            NSURL *url = [firstFailure objectForKey:@"url"];
            NSString *fileName = url.lastPathComponent ?: @"selected file";
            NSString *reason = [firstFailure objectForKey:SMReferenceImportOutcomeReasonKey] ?: @"The file could not be imported.";
            message = [message stringByAppendingFormat:@" First: %@: %@", fileName, reason];
        }
        [appcontroller() showStatusMessage:SMCompactReferenceImportStatusMessage(message) persist:NO];
    } else if (items.count > 0 && addedTrackCount == 0) {
        [appcontroller() showStatusMessage:@"No reference tracks were added." persist:NO];
    } else if (addedTrackCount > 0) {
        [appcontroller() showStatusMessage:[NSString stringWithFormat:@"Added %lu reference track%@.",
                                            (unsigned long)addedTrackCount,
                                            addedTrackCount == 1 ? @"" : @"s"]
                                    persist:NO];
    }
     });
}

#pragma mark - Teardown

-(void)dealloc
{
    NSLog(@"TrackViewController dealloc");

    [_primaryTrackTableDataSource release];
    [_sessionRowProjection release];

    [_canonicalValidationFindings release];
    [_advancedSectionLabel release];
    [_advancedGroupBox release];
    [_readinessPresenter release];
    [_trackInspectorCopyButton release];

    [_sessionTrackItems release];
    
    [super dealloc];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}
@end
