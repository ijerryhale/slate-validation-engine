//
//  UtilInspectorRailContract.h
//  Slate
//
//  Created by Jerry Hale on 4/25/26.
//  Copyright (c) 2026 Jerry Hale. All rights reserved.
//
//  Proprietary and confidential.
//  This file is part of Slate and is not open source software.
//
//  No license is granted to copy, modify, distribute, sublicense, or use this
//  source code except under a written agreement with the copyright holder.
//  Unauthorized use, disclosure, reproduction, or distribution is prohibited.
//

#ifndef UtilInspectorRailContract_h
#define UtilInspectorRailContract_h

#import <Cocoa/Cocoa.h>
#import "Validation/SMValidationCanonicalDictionaryKeys.h"

static inline CGFloat SlateInspectorRailSectionHeaderHeight(void) { return 16.0; }
static inline CGFloat SlateInspectorRailSectionHeaderYOffset(void) { return 4.0; }
static inline CGFloat SlateInspectorRailSectionGap(void) { return 6.0; }
static inline CGFloat SlateInspectorRailDisclosureRowHeight(void) { return 18.0; } // Reserved for disclosure/pin rows.
static inline CGFloat SlateInspectorRailWarningBlockMinHeight(void) { return 120.0; }
static inline CGFloat SlateInspectorRailPinControlWidth(void) { return 108.0; }
static inline CGFloat SlateInspectorRailFixedWidth(void) { return 360.0; }
static inline CGFloat SlateInspectorRailModeInspectorFixedWidth(void) { return 352.0; }
static inline CGFloat SlateInspectorRailWideMiddleColumnInset(void) { return 4.0; }
static inline CGFloat SlateInspectorRailRightInset(void) { return 14.0; }
static inline CGFloat SlateInspectorRailBottomInset(void) { return 14.0; }
static inline CGFloat SlateInspectorRailEffectiveBottomInsetForHostView(NSView *hostView)
{
    CGFloat inset = SlateInspectorRailBottomInset();
    if (hostView != nil) {
        // P/T/C mode roots can be shifted upward inside _bottomView; compensate so
        // readiness bottom padding remains visually equal to right padding.
        inset -= NSMinY([hostView frame]);
    }
    return inset;
}
static inline CGFloat SlateInspectorRailTrackMinimumHostWidth(void) { return 1120.0; }
static inline CGFloat SlateInspectorRailChapterMinimumHostWidth(void) { return 1140.0; }
static inline CGFloat SlateInspectorRailPackageMinimumHostWidth(void) { return 1220.0; }

static inline void SlateInspectorRailApplyToolGroupBoxStyle(NSBox *box)
{
    if (box == nil) {
        return;
    }

    [box setBoxType:NSBoxCustom];
    [box setBorderType:NSLineBorder];
    [box setBorderColor:[[NSColor tertiaryLabelColor] colorWithAlphaComponent:0.30]];
    [box setFillColor:[[NSColor controlBackgroundColor] colorWithAlphaComponent:0.22]];
    [box setCornerRadius:6.0];
    [box setTitlePosition:NSNoTitle];
    [box setTranslatesAutoresizingMaskIntoConstraints:YES];
    [box setAutoresizingMask:NSViewNotSizable];
}

static inline NSColor *SlateInspectorRailSectionHeaderColor(void)
{
    return [NSColor secondaryLabelColor];
}

static inline NSColor *SlateInspectorRailValueRowColor(void)
{
    return [NSColor secondaryLabelColor];
}

static inline NSColor *SlateInspectorRailStateMessageColor(void)
{
    return [NSColor secondaryLabelColor];
}

static inline NSColor *SlateInspectorRailWarningStatusColor(BOOL hasBlockers, BOOL hasWarnings)
{
    if (hasBlockers) {
        return [NSColor colorWithCalibratedRed:0.72 green:0.20 blue:0.18 alpha:1.0];
    }
    if (hasWarnings) {
        return [NSColor colorWithCalibratedRed:0.69 green:0.45 blue:0.06 alpha:1.0];
    }
    return [NSColor secondaryLabelColor];
}

static inline void SlateInspectorRailPrepareLabelBase(NSTextField *label)
{
    if (label == nil) {
        return;
    }

    [label setEditable:NO];
    [label setSelectable:NO];
    [label setBordered:NO];
    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    [label setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
}

static inline void SlateInspectorRailApplySectionHeaderStyle(NSTextField *label)
{
    if (label == nil) {
        return;
    }

    SlateInspectorRailPrepareLabelBase(label);
    [label setFont:[NSFont boldSystemFontOfSize:11.5]];
    [label setTextColor:SlateInspectorRailSectionHeaderColor()];
    [label setAlignment:NSTextAlignmentLeft];
    [label setLineBreakMode:NSLineBreakByTruncatingTail];
    [[label cell] setUsesSingleLineMode:YES];
    [[label cell] setWraps:NO];
}

static inline void SlateInspectorRailApplyValueRowStyle(NSTextField *label)
{
    if (label == nil) {
        return;
    }

    SlateInspectorRailPrepareLabelBase(label);
    [label setFont:[NSFont systemFontOfSize:11.0]];
    [label setTextColor:SlateInspectorRailValueRowColor()];
    [label setAlignment:NSTextAlignmentLeft];
    [label setLineBreakMode:NSLineBreakByTruncatingTail];
    [[label cell] setUsesSingleLineMode:YES];
    [[label cell] setWraps:NO];
}

static inline void SlateInspectorRailApplyStateMessageStyle(NSTextField *label)
{
    if (label == nil) {
        return;
    }

    SlateInspectorRailPrepareLabelBase(label);
    [label setFont:[NSFont systemFontOfSize:12.0]];
    [label setTextColor:SlateInspectorRailStateMessageColor()];
    [label setAlignment:NSTextAlignmentCenter];
    [label setLineBreakMode:NSLineBreakByWordWrapping];
    [[label cell] setUsesSingleLineMode:NO];
    [[label cell] setWraps:YES];
}

static inline void SlateInspectorRailApplyWarningStatusStyle(NSTextField *label, BOOL hasBlockers, BOOL hasWarnings)
{
    if (label == nil) {
        return;
    }

    SlateInspectorRailApplyValueRowStyle(label);
    [label setTextColor:SlateInspectorRailWarningStatusColor(hasBlockers, hasWarnings)];
}

static inline NSTextField *SlateInspectorRailCreateLabel(NSString *stringValue,
                                                           NSFont *font,
                                                           NSColor *textColor,
                                                           NSTextAlignment alignment,
                                                           BOOL multiLine)
{
    NSTextField *label = [[[NSTextField alloc] initWithFrame:NSZeroRect] autorelease];
    SlateInspectorRailPrepareLabelBase(label);
    [label setStringValue:(stringValue ?: @"")];
    [label setFont:(font ?: [NSFont systemFontOfSize:11.5])];
    [label setTextColor:(textColor ?: [NSColor secondaryLabelColor])];
    [label setAlignment:alignment];
    [label setLineBreakMode:(multiLine ? NSLineBreakByWordWrapping : NSLineBreakByTruncatingTail)];
    [[label cell] setUsesSingleLineMode:!multiLine];
    [[label cell] setWraps:multiLine];
    return label;
}

static inline CGFloat SlateInspectorRailLabelTextTopY(NSTextField *label)
{
    if (label == nil) {
        return 0.0;
    }

    NSRect frame = [label frame];
    NSFont *font = [label font];
    if (font == nil) {
        font = [NSFont systemFontOfSize:11.5];
    }
    return floor(frame.origin.y + [font ascender]);
}

static inline void SlateInspectorRailApplyWarningTextViewStyle(NSTextView *textView)
{
    if (textView == nil) {
        return;
    }

    [textView setEditable:NO];
    [textView setSelectable:YES];
    [textView setImportsGraphics:NO];
    [textView setRichText:NO];
    [textView setVerticallyResizable:YES];
    [textView setHorizontallyResizable:NO];
    [textView setFont:[NSFont systemFontOfSize:12.5]];
    [textView setTextContainerInset:NSMakeSize(6.0, 6.0)];
}

static inline void SlateInspectorRailApplyWarningScrollViewStyle(NSScrollView *scrollView)
{
    if (scrollView == nil) {
        return;
    }

    [scrollView setBorderType:NSBezelBorder];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setAutohidesScrollers:YES];
    [scrollView setDrawsBackground:NO];
    [scrollView setAutoresizingMask:(NSViewMinXMargin | NSViewHeightSizable)];
}

static inline NSString *SlateInspectorRailCopyHintTooltip(NSString *baseTooltip)
{
    NSString *copyHint = @"Copy hint: select text/rows and press Command-C where supported.";
    if (baseTooltip == nil || [baseTooltip length] == 0) {
        return copyHint;
    }
    return [NSString stringWithFormat:@"%@\n\n%@", baseTooltip, copyHint];
}

static inline void SlateInspectorRailApplyCopyHintToView(NSView *view, NSString *baseTooltip)
{
    if (view == nil) {
        return;
    }

    [view setToolTip:SlateInspectorRailCopyHintTooltip(baseTooltip)];
}

static inline NSButton *SlateInspectorRailCreatePinButton(id target, SEL action)
{
    NSButton *button = [[[NSButton alloc] initWithFrame:NSZeroRect] autorelease];
    [button setButtonType:NSSwitchButton];
    [button setTitle:@"Pin inspector"];
    [button setState:NSOffState];
    [button setControlSize:NSSmallControlSize];
    [button setFont:[NSFont systemFontOfSize:11.0]];
    [button setTarget:target];
    [button setAction:action];
    [button setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [button setToolTip:@"Keeps inspector content visible at narrow widths when space allows."];
    return button;
}

static inline BOOL SlateInspectorRailStringHasContent(NSString *value)
{
    if (![value isKindOfClass:[NSString class]]) {
        return NO;
    }

    return [[value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] > 0;
}

static inline NSString *SlateInspectorRailFindingIdentity(NSDictionary *finding)
{
    if (![finding isKindOfClass:[NSDictionary class]]) {
        return @"";
    }

    NSString *code = [finding objectForKey:SMValidationFindingKeyCode];
    NSString *scope = [finding objectForKey:SMValidationFindingKeyScope];
    NSString *severity = [finding objectForKey:SMValidationFindingKeySeverity];
    NSString *category = [finding objectForKey:SMValidationFindingKeyCategory];

    return [NSString stringWithFormat:@"%@|%@|%@|%@",
            SlateInspectorRailStringHasContent(code) ? code : @"",
            SlateInspectorRailStringHasContent(scope) ? scope : @"",
            SlateInspectorRailStringHasContent(severity) ? severity : @"",
            SlateInspectorRailStringHasContent(category) ? category : @""];
}

static inline NSString *SlateInspectorRailSeverityLabelForCode(NSString *severityCode)
{
    return [[severityCode lowercaseString] isEqualToString:SMValidationSeverityCodeBlocker] ? @"Blocker" : @"Warning";
}

static inline NSDictionary *SlateInspectorRailCanonicalizeFindingDictionary(NSDictionary *finding)
{
    if (![finding isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSString *code = [finding objectForKey:SMValidationFindingKeyCode];
    NSString *severity = [finding objectForKey:SMValidationFindingKeySeverity];
    NSString *category = [finding objectForKey:SMValidationFindingKeyCategory];
    NSString *scope = [finding objectForKey:SMValidationFindingKeyScope];
    NSString *title = [finding objectForKey:SMValidationFindingKeyTitle];
    NSString *evidence = [finding objectForKey:SMValidationFindingKeyEvidence];

    NSMutableDictionary *canonical = [NSMutableDictionary dictionaryWithCapacity:6];
    [canonical setObject:(SlateInspectorRailStringHasContent(code) ? code : SMValidationFallbackFindingCode)
                  forKey:SMValidationFindingKeyCode];
    [canonical setObject:(SlateInspectorRailStringHasContent(severity) ? [severity lowercaseString] : SMValidationSeverityCodeWarning)
                  forKey:SMValidationFindingKeySeverity];
    [canonical setObject:(SlateInspectorRailStringHasContent(category) ? [category lowercaseString] : SMValidationCategoryCodePackage)
                  forKey:SMValidationFindingKeyCategory];
    [canonical setObject:(SlateInspectorRailStringHasContent(scope) ? scope : SMValidationFallbackFindingScope)
                  forKey:SMValidationFindingKeyScope];
    [canonical setObject:(SlateInspectorRailStringHasContent(title) ? title : SMValidationFallbackFindingTitle)
                  forKey:SMValidationFindingKeyTitle];
    [canonical setObject:(SlateInspectorRailStringHasContent(evidence) ? evidence : SMValidationFallbackFindingEvidence)
                  forKey:SMValidationFindingKeyEvidence];
    return canonical;
}

static inline NSArray *SlateInspectorRailCanonicalFindingsArray(NSArray *findings)
{
    if (![findings isKindOfClass:[NSArray class]] || [findings count] == 0) {
        return [NSArray array];
    }

    NSMutableArray *canonicalFindings = [NSMutableArray arrayWithCapacity:[findings count]];
    for (id finding in findings) {
        NSDictionary *canonicalFinding = SlateInspectorRailCanonicalizeFindingDictionary(finding);
        if (canonicalFinding != nil) {
            [canonicalFindings addObject:canonicalFinding];
        }
    }

    return canonicalFindings;
}

static inline NSString *SlateInspectorRailFindingsSummaryToolTip(NSArray *findings,
                                                                   NSString *headerLine)
{
    NSArray *canonicalFindings = SlateInspectorRailCanonicalFindingsArray(findings);
    if ([canonicalFindings count] == 0) {
        return @"";
    }

    NSMutableArray *lines = [NSMutableArray array];
    [lines addObject:(SlateInspectorRailStringHasContent(headerLine) ? headerLine : @"Readiness findings")];
    NSUInteger maxLines = MIN((NSUInteger)6, [canonicalFindings count]);
    for (NSUInteger index = 0; index < maxLines; index++) {
        NSDictionary *finding = [canonicalFindings objectAtIndex:index];
        NSString *title = [finding objectForKey:SMValidationFindingKeyTitle];
        NSString *evidence = [finding objectForKey:SMValidationFindingKeyEvidence];
        NSString *severity = SlateInspectorRailSeverityLabelForCode([finding objectForKey:SMValidationFindingKeySeverity]);
        [lines addObject:[NSString stringWithFormat:@"- %@: %@", severity, (title ?: SMValidationFallbackFindingTitle)]];
        if (SlateInspectorRailStringHasContent(evidence)) {
            [lines addObject:[NSString stringWithFormat:@"  %@", evidence]];
        }
    }

    if ([canonicalFindings count] > maxLines) {
        NSUInteger remaining = [canonicalFindings count] - maxLines;
        [lines addObject:[NSString stringWithFormat:@"- %lu more finding%@ not shown",
                          (unsigned long)remaining,
                          (remaining == 1 ? @"" : @"s")]];
    }

    return [lines componentsJoinedByString:@"\n"];
}

static inline NSInteger SlateInspectorRailRowIndexFromScope(NSString *scope,
                                                              NSArray *rowScopePrefixes)
{
    if (!SlateInspectorRailStringHasContent(scope)
        || ![rowScopePrefixes isKindOfClass:[NSArray class]]
        || [rowScopePrefixes count] == 0) {
        return NSNotFound;
    }

    for (NSString *prefix in rowScopePrefixes) {
        if (!SlateInspectorRailStringHasContent(prefix)) {
            continue;
        }

        NSString *scopedPrefix = [prefix hasSuffix:@":"] ? prefix : [prefix stringByAppendingString:@":"];
        if (![scope hasPrefix:scopedPrefix]) {
            continue;
        }

        NSString *suffix = [scope substringFromIndex:[scopedPrefix length]];
        NSScanner *scanner = [NSScanner scannerWithString:suffix];
        NSInteger oneBasedIndex = NSNotFound;
        if (![scanner scanInteger:&oneBasedIndex] || ![scanner isAtEnd] || oneBasedIndex <= 0) {
            continue;
        }
        return oneBasedIndex - 1;
    }

    return NSNotFound;
}

static inline void SlateInspectorRailSplitFindingsBySeverity(NSArray *findings,
                                                               NSMutableArray **outBlockers,
                                                               NSMutableArray **outWarnings)
{
    NSMutableArray *blockers = [NSMutableArray array];
    NSMutableArray *warnings = [NSMutableArray array];

    for (NSDictionary *finding in findings) {
        if (![finding isKindOfClass:[NSDictionary class]]) {
            continue;
        }

        NSString *severity = [[finding objectForKey:SMValidationFindingKeySeverity] lowercaseString];
        if ([severity isEqualToString:SMValidationSeverityCodeBlocker]) {
            [blockers addObject:finding];
        } else {
            [warnings addObject:finding];
        }
    }

    if (outBlockers != NULL) {
        *outBlockers = blockers;
    }
    if (outWarnings != NULL) {
        *outWarnings = warnings;
    }
}

static inline NSString *SlateInspectorRailReadinessStatusText(NSArray *findings,
                                                                NSString *emptyStatus)
{
    NSMutableArray *blockers = nil;
    NSMutableArray *warnings = nil;
    SlateInspectorRailSplitFindingsBySeverity(findings, &blockers, &warnings);
    NSUInteger blockerCount = [blockers count];
    NSUInteger warningCount = [warnings count];
    NSUInteger totalCount = blockerCount + warningCount;
    if (totalCount == 0) {
        return (emptyStatus ?: @"No findings");
    }

    return [NSString stringWithFormat:@"%lu finding%@ (%lu blocker%@, %lu warning%@)",
            (unsigned long)totalCount,
            totalCount == 1 ? @"" : @"s",
            (unsigned long)blockerCount,
            blockerCount == 1 ? @"" : @"s",
            (unsigned long)warningCount,
            warningCount == 1 ? @"" : @"s"];
}

static inline NSInteger SlateInspectorRailRowIndexFromEvidence(NSString *evidence)
{
    if (!SlateInspectorRailStringHasContent(evidence)) {
        return NSNotFound;
    }

    NSRange rowRange = [evidence rangeOfString:@"row " options:NSCaseInsensitiveSearch];
    if (rowRange.location == NSNotFound) {
        return NSNotFound;
    }

    NSString *suffix = [evidence substringFromIndex:(rowRange.location + rowRange.length)];
    NSScanner *scanner = [NSScanner scannerWithString:suffix];
    NSInteger rowNumber = NSNotFound;
    if (![scanner scanInteger:&rowNumber] || rowNumber <= 0) {
        return NSNotFound;
    }

    return rowNumber - 1;
}

static inline NSString *SlateInspectorRailJumpLink(NSString *target, NSInteger rowIndex)
{
    if (!SlateInspectorRailStringHasContent(target)) {
        return nil;
    }

    if (rowIndex == NSNotFound || rowIndex < 0) {
        return [NSString stringWithFormat:@"slate-readiness://%@", target];
    }

    return [NSString stringWithFormat:@"slate-readiness://%@/%ld", target, (long)rowIndex + 1];
}

static inline NSString *SlateInspectorRailJumpTargetFromLink(id link, NSInteger *outRowIndex)
{
    if (outRowIndex != NULL) {
        *outRowIndex = NSNotFound;
    }

    NSString *linkString = nil;
    if ([link isKindOfClass:[NSString class]]) {
        linkString = (NSString *)link;
    } else if ([link isKindOfClass:[NSURL class]]) {
        linkString = [(NSURL *)link absoluteString];
    }

    if (!SlateInspectorRailStringHasContent(linkString)) {
        return nil;
    }

    NSURL *url = [NSURL URLWithString:linkString];
    if (url == nil || ![[[url scheme] lowercaseString] isEqualToString:@"slate-readiness"]) {
        return nil;
    }

    NSString *target = [url host];
    if (!SlateInspectorRailStringHasContent(target)) {
        return nil;
    }

    NSArray *pathComponents = [url pathComponents];
    if (outRowIndex != NULL && [pathComponents count] >= 2) {
        NSInteger oneBasedRow = [[pathComponents objectAtIndex:1] integerValue];
        if (oneBasedRow > 0) {
            *outRowIndex = oneBasedRow - 1;
        }
    }

    return target;
}

static inline void SlateInspectorRailApplyReadinessLinkStyle(NSTextView *textView)
{
    if (textView == nil) {
        return;
    }

    NSDictionary *linkAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSColor systemBlueColor], NSForegroundColorAttributeName,
                                    [NSNumber numberWithInteger:NSUnderlineStyleSingle], NSUnderlineStyleAttributeName,
                                    nil];
    [textView setLinkTextAttributes:linkAttributes];
}

static inline NSAttributedString *SlateInspectorRailReadinessAttributedText(NSArray *findings,
                                                                               NSString *emptyMessage,
                                                                               NSDictionary *jumpLinkByFindingIdentity)
{
    NSMutableAttributedString *composed = [[[NSMutableAttributedString alloc] init] autorelease];
    NSMutableArray *blockers = nil;
    NSMutableArray *warnings = nil;
    SlateInspectorRailSplitFindingsBySeverity(findings, &blockers, &warnings);

    NSDictionary *headingAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                       [NSFont boldSystemFontOfSize:11.5], NSFontAttributeName,
                                       [NSColor secondaryLabelColor], NSForegroundColorAttributeName,
                                       nil];
    NSDictionary *titleAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSFont systemFontOfSize:12.0], NSFontAttributeName,
                                     [NSColor labelColor], NSForegroundColorAttributeName,
                                     nil];
    NSDictionary *evidenceAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSFont systemFontOfSize:11.5], NSFontAttributeName,
                                        [NSColor secondaryLabelColor], NSForegroundColorAttributeName,
                                        nil];

    if ([blockers count] == 0 && [warnings count] == 0) {
        NSString *message = SlateInspectorRailStringHasContent(emptyMessage) ? emptyMessage : @"No readiness findings.";
        [composed appendAttributedString:[[[NSAttributedString alloc] initWithString:message
                                                                           attributes:evidenceAttributes] autorelease]];
        return composed;
    }

    NSArray *sections = [NSArray arrayWithObjects:
                         [NSDictionary dictionaryWithObjectsAndKeys:@"Blockers", @"title", blockers, @"findings", nil],
                         [NSDictionary dictionaryWithObjectsAndKeys:@"Warnings", @"title", warnings, @"findings", nil],
                         nil];

    BOOL isFirstSection = YES;
    for (NSDictionary *section in sections) {
        NSArray *sectionFindings = [section objectForKey:@"findings"];
        if (![sectionFindings isKindOfClass:[NSArray class]] || [sectionFindings count] == 0) {
            continue;
        }

        if (!isFirstSection) {
            [composed appendAttributedString:[[[NSAttributedString alloc] initWithString:@"\n"
                                                                               attributes:evidenceAttributes] autorelease]];
        }
        isFirstSection = NO;

        NSString *headerLine = [NSString stringWithFormat:@"%@ (%lu)\n",
                                [section objectForKey:@"title"],
                                (unsigned long)[sectionFindings count]];
        [composed appendAttributedString:[[[NSAttributedString alloc] initWithString:headerLine
                                                                           attributes:headingAttributes] autorelease]];

        for (NSDictionary *finding in sectionFindings) {
            NSString *title = [finding objectForKey:SMValidationFindingKeyTitle];
            NSString *evidence = [finding objectForKey:SMValidationFindingKeyEvidence];
            NSString *displayTitle = SlateInspectorRailStringHasContent(title) ? title : @"Readiness finding";
            NSString *bulletLine = [NSString stringWithFormat:@"- %@\n", displayTitle];

            NSMutableDictionary *bulletAttributes = [NSMutableDictionary dictionaryWithDictionary:titleAttributes];
            NSString *jumpLink = [jumpLinkByFindingIdentity objectForKey:SlateInspectorRailFindingIdentity(finding)];
            if (SlateInspectorRailStringHasContent(jumpLink)) {
                [bulletAttributes setObject:jumpLink forKey:NSLinkAttributeName];
                [bulletAttributes setObject:[NSColor systemBlueColor] forKey:NSForegroundColorAttributeName];
            }
            [composed appendAttributedString:[[[NSAttributedString alloc] initWithString:bulletLine
                                                                               attributes:bulletAttributes] autorelease]];

            if (SlateInspectorRailStringHasContent(evidence)) {
                NSString *evidenceLine = [NSString stringWithFormat:@"  %@\n", evidence];
                [composed appendAttributedString:[[[NSAttributedString alloc] initWithString:evidenceLine
                                                                                   attributes:evidenceAttributes] autorelease]];
            }
        }
    }

    return composed;
}

static inline void SlateInspectorRailSetReadinessText(NSTextView *textView,
                                                        NSAttributedString *attributedText)
{
    if (textView == nil) {
        return;
    }

    NSAttributedString *text = attributedText;
    if (text == nil) {
        text = [[[NSAttributedString alloc] initWithString:@""] autorelease];
    }

    [[textView textStorage] setAttributedString:text];
    [textView setSelectedRange:NSMakeRange(0, 0)];
}

#endif /* UtilInspectorRailContract_h */
