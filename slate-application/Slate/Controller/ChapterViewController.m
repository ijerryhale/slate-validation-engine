//
//  ChapterViewController.m
//  Slate
//
//  Created by Jerry Hale on 3/20/26
//  Copyright (c) 2026 Jerry Hale All rights reserved.

#import "DictionaryKeys.h"

#import "MediaSupport/SMCropDetector.h"
#import "AppController.h"
#import "AppController+Status.h"
#import "AppController+Validation.h"
#import "AppController+Package.h"
#import "Validation/SMValidationCanonicalDictionaryKeys.h"
#import "Validation/SMValidationFindingCodes.h"
#import "Runtime/SlateChapterSnapshotContract.h"
#import "Runtime/SlateReviewSnapshotContract.h"
#import "Runtime/SlateRuntimeBridge.h"

#import "QuadrantView.h"

#import "PlayerView.h"

#import "ChapterViewController.h"
#import "UtilLayoutMetrics.h"
#import "UtilInspectorRailContract.h"
#import "UtilReadinessRailPresenter.h"
#import "VertCenterTextFieldCell.h"

#pragma mark - Local Types and Keys

// The live table consumes runtime snapshot rows; local row dictionaries remain for older mutation commands.
typedef NS_ENUM(NSInteger, SMChapterCropMode) {
    SMChapterCropModeManual = 0,
    SMChapterCropModeConservativeAuto = 1,
    SMChapterCropModeNone = 2,
};

static NSString * const SMChapterResolvedImageFilePathKey = @"__resolvedImageFilePath";
static NSString * const SMChapterOwnsImageFileKey = @"__ownsImageFile";
static NSString * const SMChapterImageStatusKey = @"__imageStatus";

static BOOL SMChapterStringHasContent(NSString *value)
{
    if (![value isKindOfClass:[NSString class]]) {
        return NO;
    }

    return [[value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] > 0;
}

static NSString *SlateChapterSnapshotRawString(id value)
{
    if ([value isKindOfClass:[NSString class]]) {
        return value;
    }
    if ([value respondsToSelector:@selector(stringValue)]) {
        return [value stringValue];
    }
    return @"";
}

static NSString *SlateChapterSnapshotSafeString(id value)
{
    NSString *stringValue = SlateChapterSnapshotRawString(value);
    return ([stringValue length] > 0) ? stringValue : @"(none)";
}

static NSString *SlateChapterSnapshotRowString(NSDictionary *row, NSString *key)
{
    return SlateChapterSnapshotRawString([row objectForKey:key]);
}

static BOOL SlateChapterSnapshotRowBool(NSDictionary *row, NSString *key)
{
    id value = [row objectForKey:key];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO;
}

static NSImage *SMChapterImageScaledToWidth(NSImage *image, CGFloat width)
{
    if (image == nil || width <= 0.0 || [image size].height <= 0.0) {
        return nil;
    }

    NSSize oldSize = [image size];
    CGFloat ratio = oldSize.width / oldSize.height;
    NSSize size = NSMakeSize(width, width / ratio);
    if (fmod(round(size.height), 2.0) == 1.0) {
        size.height = round(size.height) + 1.0;
    }

    NSImage *resizedImage = [[NSImage alloc] initWithSize:size];
    [resizedImage lockFocus];
    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
    [image drawInRect:NSMakeRect(0.0, 0.0, size.width, size.height)
             fromRect:NSMakeRect(0.0, 0.0, oldSize.width, oldSize.height)
            operation:NSCompositeSourceOver
             fraction:1.0];
    [resizedImage unlockFocus];

    return [resizedImage autorelease];
}

static NSImage *SMChapterRescaledImage(NSImage *image, NSString **scaleString)
{
    CGFloat scaledWidth = 640.0;
    NSString *label = @"SD NTSC 4x3 scaled to 640";

    if ([image size].width < 660.0) {
        /* default */
    } else if ([image size].width < 874.0 && [image size].width > 800.0) {
        scaledWidth = 854.0;
        label = @"SD NTSC 16x9 1.78 scaled to 854";
    } else if ([image size].width < 801.0 && [image size].width > 770.0) {
        scaledWidth = 796.0;
        label = @"SD NTSC 16x9 1.78 scaled to 796";
    } else if ([image size].width < 771.0 && [image size].width > 700.0) {
        scaledWidth = 768.0;
        label = @"SD PAL 16x9 1.33  scaled to 768";
    } else if ([image size].width < 971.0 && [image size].width > 900.0) {
        scaledWidth = 956.0;
        label = @"SD PAL 16x9 1.66  scaled to 956";
    } else if ([image size].width < 1044.0 && [image size].width > 970.0) {
        scaledWidth = 1024.0;
        label = @"SD PAL 16x9 1.78 scaled to 1024";
    } else if ([image size].width < 1940.0 && [image size].width > 1820.0) {
        scaledWidth = 1920.0;
        label = @"HD 1.78 scaled to 1920";
    } else if ([image size].width < 1821.0 && [image size].width > 1460.0) {
        scaledWidth = 1792.0;
        label = @"HD 1.66 scaled to 1792";
    } else if ([image size].width < 1461.0 && [image size].width > 1390.0) {
        scaledWidth = 1440.0;
        label = @"HD 1.33 scaled to 1440";
    }

    if (scaleString != NULL) {
        *scaleString = label;
    }

    return SMChapterImageScaledToWidth(image, scaledWidth);
}

static NSImage *SMChapterImageFromRect(NSImage *image, CGRect rect)
{
    if (image == nil || rect.size.width <= 0.0 || rect.size.height <= 0.0) {
        return nil;
    }

    NSSize size = NSMakeSize(rect.size.width, rect.size.height);
    NSAffineTransform *transform = [NSAffineTransform transform];
    [transform translateXBy:-rect.origin.x yBy:-rect.origin.y];

    NSImage *canvas = [[NSImage alloc] initWithSize:[transform transformSize:size]];
    [canvas lockFocus];
    [transform concat];

    NSImageRep *rep = [image bestRepresentationForDevice:nil];
    [rep drawAtPoint:NSZeroPoint];
    [canvas unlockFocus];

    return [canvas autorelease];
}

static long long SlateChapterSnapshotRowLongLong(NSDictionary *row, NSString *key)
{
    id value = [row objectForKey:key];
    return [value respondsToSelector:@selector(longLongValue)] ? [value longLongValue] : 0;
}

static NSDictionary *SMChapterCanonicalFindingWithCode(NSArray *findings, NSString *code)
{
    for (NSDictionary *finding in findings) {
        if (![finding isKindOfClass:[NSDictionary class]]) {
            continue;
        }

        NSString *findingCode = [finding objectForKey:SMValidationFindingKeyCode];
        if (SMChapterStringHasContent(code) && [findingCode isEqualToString:code]) {
            return finding;
        }
    }

    return nil;
}

static NSDictionary *SMChapterDetailsPairDictionary(NSString *key, id value)
{
    if (key.length == 0) {
        return nil;
    }
    return [NSDictionary dictionaryWithObjectsAndKeys:
            key, SlateChapterSnapshotDetailKeyKey,
            SlateChapterSnapshotSafeString(value), SlateChapterSnapshotDetailKeyValue,
            nil];
}

static void SMChapterAppendDetailsPairToArray(NSMutableArray *pairs, NSString *key, id value)
{
    NSDictionary *pair = SMChapterDetailsPairDictionary(key, value);
    if (pair != nil) {
        [pairs addObject:pair];
    }
}

static void SMChapterAppendDetailsPair(NSMutableString *details, NSString *key, id value)
{
    if (details == nil || key.length == 0) {
        return;
    }
    if ([details length] > 0 && ![details hasSuffix:@"\n"]) {
        [details appendString:@"\n"];
    }
    [details appendFormat:@"%@: %@", key, SlateChapterSnapshotSafeString(value)];
}

static NSInteger SMChapterRowIndexFromFindingScope(NSString *scope)
{
    return SlateInspectorRailRowIndexFromScope(scope,
                                                 [NSArray arrayWithObject:SMValidationScopeChapterRowPrefix]);
}

typedef NS_ENUM(NSInteger, SMWorkspaceWidthClass) {
    SMWorkspaceWidthClass0 = 0,
    SMWorkspaceWidthClass1 = 1,
    SMWorkspaceWidthClass2 = 2,
};

#pragma mark - Layout Constants

static const CGFloat SMChapterWorkspaceWideBreakpoint = 1280.0;
static const CGFloat SMChapterWorkspaceMediumBreakpoint = 1107.0;
static const CGFloat SMChapterWorkspaceCompactBlendEndWidth = 1040.0;
static const CGFloat SMChapterResponsiveWorkspaceMinimumWidth = 600.0;
static const CGFloat SMChapterCompactTableMinimumWidth = 430.0;
static const CGFloat SMChapterReadinessRailTableMinimumWidth = 420.0;
static const CGFloat SMChapterPinnedRelaxedTableMinimumWidth = 360.0;
static const CGFloat SMChapterPinnedRelaxWindowWidth = 120.0;
static const CGFloat SMChapterTableMinimumWidthWide = 520.0;
static const CGFloat SMChapterInspectorRailMinimumPadding = 6.0;
static const CGFloat SMChapterInspectorRowHeight = 16.0;
static const CGFloat SMChapterInspectorRowGap = 4.0;
static const CGFloat SMChapterInspectorPopupWidthWide = 116.0;
static const CGFloat SMChapterInspectorPopupWidthCompact = 102.0;
static const CGFloat SMChapterInspectorCropPopupMinimumWidth = 96.0;
static const CGFloat SMChapterInspectorPreviewFixedSideLength = 256.0;
static const CGFloat SMChapterTitleColumnMinimumWidth = 118.0;
static const CGFloat SMChapterFixedHeaderColumnHorizontalPadding = 6.0; // 3px left + 3px right
static const CGFloat SMChapterTimeColumnCropTransferWidth = 4.0;
static const CGFloat SMChapterCropColumnBaseWidth = 106.0;

static const CGFloat SMChapterTableEmptyStateInset = 18.0;
static const CGFloat SMChapterTableEmptyStateHeight = 40.0;

static const CGFloat SMChapterInspectorGroupInsetX = 8.0;
static const CGFloat SMChapterInspectorGroupHeaderInsetX = 10.0;
static const CGFloat SMChapterInspectorGroupHeaderTopInset = 6.0;
static const CGFloat SMChapterMinimumInterColumnGap = 14.0;
static const NSInteger SMChapterTableMaximumVisibleRows = 12;
static const CGFloat SMChapterTableRowHeight = 28.0;
static const CGFloat SMChapterTableIntercellVerticalSpacing = 4.0;
static const CGFloat SMChapterTableHeaderHeight = 34.0;

static NSString * const SMChapterReadinessStatusNoPackageLoaded = @"No package loaded";
static NSString * const SMChapterReadinessFindingsToolTipTitle = @"Readiness findings (chapters)";
static NSString * const SMChapterReadinessStatusNoFindings = @"No chapter findings";
static NSString * const SMChapterReadinessEmptyMessageNoFindings = @"No chapter readiness findings.";
static NSString * const SMChapterTableNoRowsMessage = @"No chapter rows are declared in this package.";
static NSString * const SMChapterSectionTitleReadiness = @"Readiness";
static NSString * const SMChapterResizableColumnWidthsDefaultsKey = @"SMChapterResizableColumnWidths";
static NSString * const SMChapterJumpBlockedStatusFormat = @"Chapter row %ld %@ marker %@ exceeds movie duration %@. Jump blocked.";

static BOOL SMChapterColumnWidthIsLocked(NSString *columnIdentifier)
{
    if (![columnIdentifier isKindOfClass:[NSString class]]) {
        return NO;
    }

    return [columnIdentifier isEqualToString:KEY_CHAPTITLE]
        || [columnIdentifier isEqualToString:KEY_MEDIA_CHAPSMPTE]
        || [columnIdentifier isEqualToString:KEY_MEDIA_IMGSMPTE]
        || [columnIdentifier isEqualToString:KEY_ABS_CHAPSMPTE]
        || [columnIdentifier isEqualToString:KEY_ABS_IMGSMPTE]
        || [columnIdentifier isEqualToString:KEY_CROP]
        || [columnIdentifier isEqualToString:KEY_IMAGEFILEPATH];
}

static NSFont *SMChapterTableBodyFont(void)
{
    return [NSFont systemFontOfSize:12.0 weight:NSFontWeightRegular];
}

static NSFont *SMChapterTableHeaderFont(void)
{
    return [NSFont systemFontOfSize:16.0 weight:NSFontWeightSemibold];
}

static CGFloat SMChapterMaximumTableHeightForVisibleRows(void)
{
    CGFloat rowSlotHeight = SMChapterTableRowHeight + SMChapterTableIntercellVerticalSpacing;
    return SMChapterTableHeaderHeight + (rowSlotHeight * (CGFloat)SMChapterTableMaximumVisibleRows);
}

static CGFloat SMChapterFixedInspectorRailHeight(void)
{
    CGFloat designContentTopY = SlateWorkspacePrimaryPaneTableAnchorTopY()
        + SlateInspectorRailSectionHeaderHeight()
        + SlateInspectorRailSectionHeaderYOffset();
    return MAX(SlateWorkspaceMinimumContentHeight(), designContentTopY - SlateInspectorRailBottomInset());
}

static SMWorkspaceWidthClass SMWorkspaceWidthClassForWidth(CGFloat workspaceWidth)
{
    if (workspaceWidth >= SMChapterWorkspaceWideBreakpoint) {
        return SMWorkspaceWidthClass2;
    }
    if (workspaceWidth >= SMChapterWorkspaceMediumBreakpoint) {
        return SMWorkspaceWidthClass1;
    }
    return SMWorkspaceWidthClass0;
}

static NSString * const SMChapterInspectorRailPinnedDefaultsKey = @"SMChapterInspectorRailPinned";
static void *SMChapterHasMovieKVOContext = &SMChapterHasMovieKVOContext;

static CGFloat SMChapterWorkspaceOuterPadding(void) { return 10.0; }
static CGFloat SMChapterWorkspaceGutter(void) { return 14.0; }
static NSRect SMChapterDefaultRootFrame(void) { return NSMakeRect(0.0, 0.0, 1280.0, 360.0); }
static NSRect SMChapterDefaultTableScrollFrame(void) { return NSMakeRect(14.0, 14.0, 881.0, 346.0); }
static NSRect SMChapterDefaultQuadrantFrame(void) { return NSMakeRect(960.0, 128.0, 256.0, 255.0); }
static NSRect SMChapterDefaultLeadoutSecondsFrame(void) { return NSMakeRect(1255.0, 62.0, 16.0, 16.0); }
static NSRect SMChapterDefaultChapterCountLabelFrame(void) { return NSMakeRect(1151.0, 48.0, 103.0, 11.0); }
static NSRect SMChapterDefaultChapterCountFrame(void) { return NSMakeRect(1242.0, 231.0, 20.0, 16.0); }
static NSRect SMChapterDefaultJumpToImageTimeFrame(void) { return NSMakeRect(1092.0, 18.0, 142.0, 18.0); }
static NSRect SMChapterDefaultCropModePopupFrame(void) { return NSMakeRect(992.0, 80.0, 116.0, 15.0); }

#pragma mark - Layout Helpers

static CGFloat SMChapterLerp(CGFloat fromValue, CGFloat toValue, CGFloat t)
{
    CGFloat clamped = MIN(MAX(t, 0.0), 1.0);
    return fromValue + ((toValue - fromValue) * clamped);
}

static CGFloat SMChapterCompactBlendForWidth(CGFloat workspaceWidth)
{
    const CGFloat blendStartWidth = SMChapterWorkspaceMediumBreakpoint;
    const CGFloat blendEndWidth = SMChapterWorkspaceCompactBlendEndWidth;
    if (workspaceWidth >= blendStartWidth) {
        return 0.0;
    }
    if (workspaceWidth <= blendEndWidth) {
        return 1.0;
    }
    return (blendStartWidth - workspaceWidth) / (blendStartWidth - blendEndWidth);
}

static CGFloat SMChapterFixedWidthForHeaderTitle(NSString *title)
{
    NSFont *headerFont = SMChapterTableHeaderFont();
    CGFloat textWidth = ceil([title sizeWithAttributes:[NSDictionary dictionaryWithObject:headerFont
                                                                                    forKey:NSFontAttributeName]].width);
    return MAX(1.0, textWidth + SMChapterFixedHeaderColumnHorizontalPadding);
}

static BOOL SMChapterResolveInspectorAndReadinessRails(CGFloat workspaceWidthWithoutReadiness,
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
} SMChapterFixedRailLayout;

static SMChapterFixedRailLayout SMChapterResolveFixedRailLayout(SMWorkspaceWidthClass widthClass,
                                                                BOOL inspectorRailPinned,
                                                                CGFloat compactFiveColumnWidth,
                                                                NSRect layoutBounds,
                                                                CGFloat tableStartX,
                                                                CGFloat workspaceBottomY,
                                                                CGFloat workspaceWidthValue,
                                                                CGFloat tableContentTopY,
                                                                CGFloat railContentTopY)
{
    CGFloat gutter = SMChapterWorkspaceGutter();
    CGFloat compactBlend = (widthClass == SMWorkspaceWidthClass2) ? 0.0 : SMChapterCompactBlendForWidth(NSWidth(layoutBounds));
    CGFloat compactTableMinimum = MAX(SMChapterCompactTableMinimumWidth, compactFiveColumnWidth);
    CGFloat minimumTableWidth = SMChapterLerp(SMChapterTableMinimumWidthWide, compactTableMinimum, compactBlend);
    CGFloat minimumTableWidthForRail = minimumTableWidth;
    CGFloat minimumTableWidthForReadinessRail = MIN(minimumTableWidth, SMChapterReadinessRailTableMinimumWidth);
    CGFloat inspectorFixedWidth = SlateInspectorRailModeInspectorFixedWidth();
    CGFloat inspectorMinWidth = inspectorFixedWidth;
    CGFloat inspectorTargetWidth = inspectorFixedWidth;
    CGFloat readinessWidth = SlateInspectorRailFixedWidth();
    CGFloat readinessRightInset = SlateInspectorRailRightInset();
    CGFloat railBottomY = workspaceBottomY;
    CGFloat readinessBottomY = railBottomY;
    BOOL wantsReadinessRail = (widthClass != SMWorkspaceWidthClass0) || inspectorRailPinned;

    CGFloat readinessFrameX = NSMaxX(layoutBounds) - readinessRightInset - readinessWidth;
    CGFloat layoutWidthWithReadiness = readinessFrameX - gutter - tableStartX;
    BOOL pinnedCanAffectLayout = inspectorRailPinned && (widthClass != SMWorkspaceWidthClass2);
    BOOL readinessEligibleByWidth = pinnedCanAffectLayout || (NSWidth(layoutBounds) >= SlateInspectorRailChapterMinimumHostWidth());
    CGFloat strictMinimumLayoutWidthForInspector = minimumTableWidth + inspectorMinWidth + gutter;
    if (pinnedCanAffectLayout) {
        // Smoothly relax table minima in pinned mode to avoid a hard snap around
        // the strict threshold while preserving readiness as width tightens.
        CGFloat relaxedTableMinimum = SMChapterPinnedRelaxedTableMinimumWidth;
        CGFloat relaxWindow = SMChapterPinnedRelaxWindowWidth;
        CGFloat relaxStart = strictMinimumLayoutWidthForInspector + relaxWindow;
        CGFloat relaxEnd = strictMinimumLayoutWidthForInspector - relaxWindow;
        CGFloat relaxBlend = 0.0;
        if (layoutWidthWithReadiness <= relaxEnd) {
            relaxBlend = 1.0;
        } else if (layoutWidthWithReadiness < relaxStart) {
            relaxBlend = (relaxStart - layoutWidthWithReadiness) / (relaxStart - relaxEnd);
        }
        minimumTableWidthForRail = SMChapterLerp(minimumTableWidthForRail, relaxedTableMinimum, relaxBlend);
        minimumTableWidthForReadinessRail = MIN(minimumTableWidthForReadinessRail, minimumTableWidthForRail);
    }

    CGFloat minimumLayoutWidthForInspector = minimumTableWidthForRail + inspectorMinWidth + gutter;
    CGFloat minimumLayoutWidthForReadinessRail = minimumTableWidthForReadinessRail + inspectorMinWidth + gutter;
    BOOL preferReadinessRail = wantsReadinessRail
        && readinessEligibleByWidth
        && (layoutWidthWithReadiness >= minimumLayoutWidthForReadinessRail);
    BOOL showReadinessRail = NO;
    CGFloat layoutBandWidth = 0.0;
    BOOL showInspectorRail = SMChapterResolveInspectorAndReadinessRails(workspaceWidthValue,
                                                                        layoutWidthWithReadiness,
                                                                        minimumLayoutWidthForInspector,
                                                                        preferReadinessRail,
                                                                        &showReadinessRail,
                                                                        &layoutBandWidth);

    SMChapterFixedRailLayout layout;
    layout.showInspectorRail = showInspectorRail;
    layout.showReadinessRail = showReadinessRail;
    layout.tableFrame = NSMakeRect(tableStartX,
                                   workspaceBottomY,
                                   MAX(0.0, layoutBandWidth),
                                   MAX(SlateWorkspaceMinimumContentHeight(), tableContentTopY - workspaceBottomY));
    layout.inspectorFrame = NSZeroRect;
    layout.readinessFrame = NSZeroRect;

    if (showInspectorRail) {
        CGFloat inspectorAvailableWidth = layoutBandWidth - minimumTableWidthForRail - gutter;
        CGFloat inspectorWidth = MIN(inspectorTargetWidth, inspectorAvailableWidth);
        inspectorWidth = MAX(inspectorMinWidth, inspectorWidth);
        CGFloat tableWidth = layoutBandWidth - inspectorWidth - gutter;
        tableWidth = MAX(minimumTableWidthForRail, tableWidth);

        layout.tableFrame.size.width = tableWidth;
        CGFloat inspectorHeight = SMChapterFixedInspectorRailHeight();
        layout.inspectorFrame = NSMakeRect(NSMaxX(layout.tableFrame) + gutter,
                                           railBottomY,
                                           inspectorWidth,
                                           inspectorHeight);
        // Keep short chapter lists bounded while rails absorb vertical headroom.
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

#pragma mark - Snapshot Helpers

static NSDictionary *SMChapterScrollSnapshotForScrollView(NSScrollView *scrollView)
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

static void SMChapterRestoreScrollSnapshotForScrollView(NSScrollView *scrollView, NSDictionary *snapshot)
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

static NSDictionary *SMChapterProbeRect(NSRect rect)
{
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithDouble:rect.origin.x], @"x",
            [NSNumber numberWithDouble:rect.origin.y], @"y",
            [NSNumber numberWithDouble:rect.size.width], @"w",
            [NSNumber numberWithDouble:rect.size.height], @"h",
            nil];
}

static NSString *SMChapterProbeWidthClassCode(CGFloat workspaceWidth)
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

@interface SMChapterClippedFocusTableView : NSTableView
@end

@implementation SMChapterClippedFocusTableView

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

#pragma mark - Private Interface

@interface ChapterViewController ()
{
    NSDictionary *_chapterSnapshot;
}
- (void)buildChapterViewHierarchyIfNeeded;
- (void)initializeChapterControllerDataIfNeeded;
- (void)applyPersistedChapterControlValues;
- (void)updateChapterControlEnabledStates;
- (BOOL)isQuadrantViewEnabledForCurrentContext;
- (void)updateQuadrantViewForCurrentContext;
- (NSScrollView *)newPrimaryChapterScrollView;
- (SMChapterClippedFocusTableView *)newPrimaryChapterTableView;
- (NSTableColumn *)newPrimaryChapterTextColumnWithIdentifier:(NSString *)identifier
                                                        title:(NSString *)title
                                                        width:(CGFloat)width
                                                     minWidth:(CGFloat)minWidth
                                                     maxWidth:(CGFloat)maxWidth
                                                dataAlignment:(NSTextAlignment)dataAlignment
                                                     editable:(BOOL)editable;
- (NSTableColumn *)newPrimaryChapterImageColumnWithIdentifier:(NSString *)identifier
                                                        title:(NSString *)title
                                                        width:(CGFloat)width
                                                     minWidth:(CGFloat)minWidth
                                                     maxWidth:(CGFloat)maxWidth;
- (NSTextField *)newMiniStaticLabelWithTitle:(NSString *)title
                                        frame:(NSRect)frame
                                     alignment:(NSTextAlignment)alignment
                                     textColor:(NSColor *)textColor;
- (NSTextField *)newMiniEditableFieldWithFrame:(NSRect)frame;
- (NSButton *)newMiniCheckboxWithTitle:(NSString *)title frame:(NSRect)frame;
- (NSPopUpButton *)newChapterCropModePopupWithFrame:(NSRect)frame;
- (QuadrantView *)newPrimaryChapterQuadrantView;
- (void)startObservingAppHasMovieIfNeeded;
- (void)stopObservingAppHasMovieIfNeeded;
- (void)restorePersistedChapterColumnWidthsForTableView:(NSTableView *)tableView;
- (void)persistResizableChapterColumnWidths;
- (void)applyPrimaryChapterTableColumnWidthsForWidthClass:(SMWorkspaceWidthClass)widthClass;
- (BOOL)shouldJumpToImageTimeForChapterSelection;
- (void)invalidateChapterSnapshot;
- (void)rebuildChapterSnapshot;
- (NSDictionary *)chapterSnapshot;
- (NSArray *)chapterSnapshotRows;
- (NSInteger)chapterSnapshotRowCount;
- (NSDictionary *)chapterSnapshotRowAtIndex:(NSInteger)rowIndex;
- (NSArray *)chapterInspectorDetailsForSnapshotRow:(NSDictionary *)snapshotRow;
- (NSString *)chapterInspectorDetailsTextForSnapshotRow:(NSDictionary *)snapshotRow;
- (NSImage *)chapterImageForSnapshotRow:(NSDictionary *)snapshotRow;
- (NSString *)chapterImageStatusForSnapshotRow:(NSDictionary *)snapshotRow;
- (BOOL)showChapterCropRectStatusForSnapshotRow:(NSDictionary *)snapshotRow;
@end

@implementation ChapterViewController

#pragma mark - Lifecycle and View Surface

@synthesize playerView = _playerView;

- (void)syncQuadrantBackgroundToPlayerView
{
    if (_quadrantView == nil) {
        return;
    }

    NSColor *backgroundColor = nil;
    if (_playerView != nil) {
        CGColorRef playerBackgroundCGColor = _playerView.layer.backgroundColor;
        if (playerBackgroundCGColor != NULL) {
            backgroundColor = [NSColor colorWithCGColor:playerBackgroundCGColor];
        }
    }

    if (backgroundColor == nil) {
        backgroundColor = [NSColor darkGrayColor];
    }

    [_quadrantView setBackgroundColor:backgroundColor];
    [_quadrantView setNeedsDisplay:YES];
}

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        [self initializeChapterControllerDataIfNeeded];
    }
    return self;
}

- (void)setPlayerView:(PlayerView *)playerView
{
    _playerView = playerView;
    [self syncQuadrantBackgroundToPlayerView];
    [self updateChapterControlEnabledStates];
}

- (void)loadView
{
    [self buildChapterViewHierarchyIfNeeded];
    [self initializeChapterControllerDataIfNeeded];
    [self applyChapterScanabilityMetrics];
    [self updateChapterReadinessPanelPresentation];
    [self applyWorkspaceLayoutForWidth:NSWidth([[self view] bounds])];
}

#pragma mark - View Construction

- (NSTextField *)newMiniStaticLabelWithTitle:(NSString *)title
                                        frame:(NSRect)frame
                                     alignment:(NSTextAlignment)alignment
                                     textColor:(NSColor *)textColor
{
    NSTextField *label = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [label setStringValue:(title ?: @"")];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setBordered:NO];
    [label setDrawsBackground:NO];
    [label setAlignment:alignment];
    [label setLineBreakMode:NSLineBreakByClipping];
    [label setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin | NSViewMaxYMargin)];
    [label setControlSize:NSMiniControlSize];
    [label setFont:[NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSMiniControlSize]]];
    [label setTextColor:(textColor ?: [NSColor controlTextColor])];
    return label;
}

- (NSTextField *)newMiniEditableFieldWithFrame:(NSRect)frame
{
    NSTextField *field = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [field setEditable:YES];
    [field setSelectable:YES];
    [field setBordered:YES];
    [field setBezeled:YES];
    [field setDrawsBackground:YES];
    [field setControlSize:NSMiniControlSize];
    [field setFont:[NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSMiniControlSize]]];
    [field setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin | NSViewMaxYMargin)];
    return field;
}

- (NSButton *)newMiniCheckboxWithTitle:(NSString *)title frame:(NSRect)frame
{
    NSButton *button = [[[NSButton alloc] initWithFrame:frame] autorelease];
    [button setButtonType:NSSwitchButton];
    [button setAllowsMixedState:NO];
    [button setTitle:(title ?: @"")];
    [button setAlignment:NSTextAlignmentLeft];
    [button setImagePosition:NSImageLeft];
    [button setControlSize:NSMiniControlSize];
    [button setState:NSControlStateValueOn];
    [button setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin | NSViewMaxYMargin)];
    return button;
}

- (NSPopUpButton *)newChapterCropModePopupWithFrame:(NSRect)frame
{
    NSPopUpButton *popup = [[[NSPopUpButton alloc] initWithFrame:frame pullsDown:YES] autorelease];
    [popup setControlSize:NSMiniControlSize];
    [popup setAutoenablesItems:NO];
    [[popup cell] setBezelStyle:NSRoundedBezelStyle];
    [[popup cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    [[popup cell] setFont:[NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSMiniControlSize]]];
    [popup setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin | NSViewMaxYMargin)];

    [popup addItemWithTitle:@"Crop Mode..."];
    [[popup itemAtIndex:0] setTag:-1];
    [[popup itemAtIndex:0] setEnabled:NO];
    [popup addItemWithTitle:@"Manual"];
    [[popup itemAtIndex:1] setTag:SMChapterCropModeManual];
    [popup addItemWithTitle:@"Conservative Auto"];
    [[popup itemAtIndex:2] setTag:SMChapterCropModeConservativeAuto];
    [popup addItemWithTitle:@"None"];
    [[popup itemAtIndex:3] setTag:SMChapterCropModeNone];

    [popup setTarget:self];
    [popup setAction:@selector(updateChapterCropMode:)];
    return popup;
}

- (NSTableColumn *)newPrimaryChapterTextColumnWithIdentifier:(NSString *)identifier
                                                        title:(NSString *)title
                                                        width:(CGFloat)width
                                                     minWidth:(CGFloat)minWidth
                                                     maxWidth:(CGFloat)maxWidth
                                                dataAlignment:(NSTextAlignment)dataAlignment
                                                     editable:(BOOL)editable
{
    NSTableColumn *column = [[[NSTableColumn alloc] initWithIdentifier:identifier] autorelease];
    [column setEditable:NO];
    [column setWidth:width];
    [column setMinWidth:minWidth];
    [column setMaxWidth:maxWidth];
    [column setResizingMask:NSTableColumnNoResizing];

    NSTableHeaderCell *headerCell = [column headerCell];
    [headerCell setStringValue:(title ?: @"")];
    [headerCell setControlSize:NSControlSizeRegular];
    [headerCell setAlignment:NSTextAlignmentCenter];
    [headerCell setLineBreakMode:NSLineBreakByTruncatingTail];

    VertCenterTextFieldCell *dataCell = [[[VertCenterTextFieldCell alloc] initTextCell:@""] autorelease];
    [dataCell setControlSize:NSSmallControlSize];
    [dataCell setSelectable:YES];
    [dataCell setEditable:editable];
    [dataCell setLineBreakMode:NSLineBreakByTruncatingTail];
    [dataCell setAlignment:dataAlignment];
    [dataCell setFont:SMChapterTableBodyFont()];
    [column setDataCell:dataCell];

    return column;
}

- (NSTableColumn *)newPrimaryChapterImageColumnWithIdentifier:(NSString *)identifier
                                                        title:(NSString *)title
                                                        width:(CGFloat)width
                                                     minWidth:(CGFloat)minWidth
                                                     maxWidth:(CGFloat)maxWidth
{
    NSTableColumn *column = [[[NSTableColumn alloc] initWithIdentifier:identifier] autorelease];
    [column setEditable:NO];
    [column setWidth:width];
    [column setMinWidth:minWidth];
    [column setMaxWidth:maxWidth];
    [column setResizingMask:NSTableColumnNoResizing];

    NSTableHeaderCell *headerCell = [column headerCell];
    [headerCell setStringValue:(title ?: @"")];
    [headerCell setControlSize:NSControlSizeRegular];
    [headerCell setAlignment:NSTextAlignmentCenter];
    [headerCell setLineBreakMode:NSLineBreakByTruncatingTail];

    NSImageCell *dataCell = [[[NSImageCell alloc] init] autorelease];
    [dataCell setControlSize:NSSmallControlSize];
    [dataCell setRefusesFirstResponder:YES];
    [dataCell setAlignment:NSTextAlignmentLeft];
    [dataCell setImageScaling:NSImageScaleProportionallyUpOrDown];
    [column setDataCell:dataCell];
    return column;
}

- (SMChapterClippedFocusTableView *)newPrimaryChapterTableView
{
    SMChapterClippedFocusTableView *tableView = [[[SMChapterClippedFocusTableView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 879.0, 316.0)] autorelease];
    [tableView setAllowsExpansionToolTips:YES];
    [tableView setColumnAutoresizingStyle:NSTableViewNoColumnAutoresizing];
    [tableView setUsesAlternatingRowBackgroundColors:YES];
    [tableView setAllowsColumnSelection:YES];
    [tableView setAllowsMultipleSelection:NO];
    [tableView setAutosaveName:@"SLATE_CHAPTER_VIEW"];
    [tableView setRowHeight:24.0];
    [tableView setRowSizeStyle:NSTableViewRowSizeStyleLarge];
    [tableView setIntercellSpacing:NSMakeSize(3.0, 0.0)];
    [tableView setBackgroundColor:[NSColor whiteColor]];
    [tableView setGridStyleMask:(NSTableViewSolidVerticalGridLineMask | NSTableViewSolidHorizontalGridLineMask)];
    [tableView setGridColor:[NSColor separatorColor]];
    [tableView setHeaderView:[[[NSTableHeaderView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 879.0, 32.0)] autorelease]];
    [tableView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

    CGFloat defaultImageColumnWidth = 106.0;
    CGFloat imageHeaderWidth = ceil([@"Image" sizeWithAttributes:[NSDictionary dictionaryWithObject:SMChapterTableHeaderFont()
                                                                                               forKey:NSFontAttributeName]].width) + 10.0;
    CGFloat imageColumnWidth = MAX(1.0, imageHeaderWidth);
    CGFloat titleColumnWidth = SMChapterTitleColumnMinimumWidth + MAX(0.0, defaultImageColumnWidth - imageColumnWidth);

    NSTableColumn *titleColumn = [self newPrimaryChapterTextColumnWithIdentifier:KEY_CHAPTITLE
                                                                           title:@"Title"
                                                                           width:titleColumnWidth
                                                                        minWidth:SMChapterTitleColumnMinimumWidth
                                                                        maxWidth:FLT_MAX
                                                                   dataAlignment:NSTextAlignmentLeft
                                                                        editable:NO];
    [titleColumn setResizingMask:NSTableColumnNoResizing];
    [tableView addTableColumn:titleColumn];
    CGFloat mediaChapterTimeWidth = MAX(1.0, SMChapterFixedWidthForHeaderTitle(@"Media Chapter Time") - SMChapterTimeColumnCropTransferWidth);
    NSTableColumn *mediaChapterTimeColumn = [self newPrimaryChapterTextColumnWithIdentifier:KEY_MEDIA_CHAPSMPTE
                                                                                        title:@"Media Chapter Time"
                                                                                        width:mediaChapterTimeWidth
                                                                                     minWidth:mediaChapterTimeWidth
                                                                                     maxWidth:mediaChapterTimeWidth
                                                                                dataAlignment:NSTextAlignmentCenter
                                                                                     editable:NO];
    [mediaChapterTimeColumn setResizingMask:NSTableColumnNoResizing];
    [tableView addTableColumn:mediaChapterTimeColumn];

    CGFloat mediaImageTimeWidth = MAX(1.0, SMChapterFixedWidthForHeaderTitle(@"Media Image Time") - SMChapterTimeColumnCropTransferWidth);
    NSTableColumn *mediaImageTimeColumn = [self newPrimaryChapterTextColumnWithIdentifier:KEY_MEDIA_IMGSMPTE
                                                                                      title:@"Media Image Time"
                                                                                      width:mediaImageTimeWidth
                                                                                   minWidth:mediaImageTimeWidth
                                                                                   maxWidth:mediaImageTimeWidth
                                                                              dataAlignment:NSTextAlignmentCenter
                                                                                   editable:NO];
    [mediaImageTimeColumn setResizingMask:NSTableColumnNoResizing];
    [tableView addTableColumn:mediaImageTimeColumn];

    CGFloat absChapterTimeWidth = MAX(1.0, SMChapterFixedWidthForHeaderTitle(@"Abs. Chapter Time") - SMChapterTimeColumnCropTransferWidth);
    NSTableColumn *absChapterTimeColumn = [self newPrimaryChapterTextColumnWithIdentifier:KEY_ABS_CHAPSMPTE
                                                                                      title:@"Abs. Chapter Time"
                                                                                      width:absChapterTimeWidth
                                                                                   minWidth:absChapterTimeWidth
                                                                                   maxWidth:absChapterTimeWidth
                                                                              dataAlignment:NSTextAlignmentCenter
                                                                                   editable:YES];
    [absChapterTimeColumn setResizingMask:NSTableColumnNoResizing];
    [tableView addTableColumn:absChapterTimeColumn];

    CGFloat absImageTimeWidth = MAX(1.0, SMChapterFixedWidthForHeaderTitle(@"Abs. Image Time") - SMChapterTimeColumnCropTransferWidth);
    NSTableColumn *absImageTimeColumn = [self newPrimaryChapterTextColumnWithIdentifier:KEY_ABS_IMGSMPTE
                                                                                    title:@"Abs. Image Time"
                                                                                    width:absImageTimeWidth
                                                                                 minWidth:absImageTimeWidth
                                                                                 maxWidth:absImageTimeWidth
                                                                            dataAlignment:NSTextAlignmentCenter
                                                                                 editable:YES];
    [absImageTimeColumn setResizingMask:NSTableColumnNoResizing];
    [tableView addTableColumn:absImageTimeColumn];
    CGFloat cropColumnWidth = SMChapterCropColumnBaseWidth + (SMChapterTimeColumnCropTransferWidth * 4.0);
    [tableView addTableColumn:[self newPrimaryChapterTextColumnWithIdentifier:KEY_CROP
                                                                         title:@"Crop Values"
                                                                         width:cropColumnWidth
                                                                      minWidth:cropColumnWidth
                                                                      maxWidth:cropColumnWidth
                                                                 dataAlignment:NSTextAlignmentLeft
                                                                      editable:YES]];
    [[tableView tableColumnWithIdentifier:KEY_CROP] setResizingMask:NSTableColumnNoResizing];
    NSTableColumn *imageColumn = [self newPrimaryChapterImageColumnWithIdentifier:KEY_IMAGEFILEPATH
                                                                            title:@"Image"
                                                                            width:imageColumnWidth
                                                                         minWidth:imageColumnWidth
                                                                         maxWidth:imageColumnWidth];
    [imageColumn setResizingMask:NSTableColumnNoResizing];
    [tableView addTableColumn:imageColumn];

    [self restorePersistedChapterColumnWidthsForTableView:tableView];
    [tableView setDelegate:self];
    [tableView setDataSource:self];
    return tableView;
}

#pragma mark - Table Column Widths

- (void)restorePersistedChapterColumnWidthsForTableView:(NSTableView *)tableView
{
    if (tableView == nil) {
        return;
    }

    NSDictionary *widthByColumn = [[NSUserDefaults standardUserDefaults] objectForKey:SMChapterResizableColumnWidthsDefaultsKey];
    if (![widthByColumn isKindOfClass:[NSDictionary class]]) {
        return;
    }

    for (NSTableColumn *column in [tableView tableColumns]) {
        NSString *columnID = [column identifier];
        if (SMChapterColumnWidthIsLocked(columnID)) {
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

- (void)persistResizableChapterColumnWidths
{
    if (_tableView == nil) {
        return;
    }

    NSMutableDictionary *widthByColumn = [NSMutableDictionary dictionary];
    for (NSTableColumn *column in [_tableView tableColumns]) {
        NSString *columnID = [column identifier];
        if (SMChapterColumnWidthIsLocked(columnID)) {
            continue;
        }

        [widthByColumn setObject:[NSNumber numberWithDouble:[column width]]
                          forKey:columnID];
    }

    [[NSUserDefaults standardUserDefaults] setObject:widthByColumn
                                              forKey:SMChapterResizableColumnWidthsDefaultsKey];
}

- (void)applyPrimaryChapterTableColumnWidthsForWidthClass:(SMWorkspaceWidthClass)widthClass
{
    if (_tableView == nil) {
        return;
    }

    NSTableColumn *titleColumn = [_tableView tableColumnWithIdentifier:KEY_CHAPTITLE];
    if (titleColumn == nil) {
        return;
    }
    NSTableColumn *imageColumn = [_tableView tableColumnWithIdentifier:KEY_IMAGEFILEPATH];
    NSScrollView *scrollView = [_tableView enclosingScrollView];
    CGFloat availableWidth = (scrollView != nil) ? NSWidth([[scrollView contentView] bounds]) : NSWidth([_tableView bounds]);
    if (availableWidth <= 0.0 && scrollView != nil) {
        availableWidth = NSWidth([scrollView bounds]);
    }
    if (availableWidth <= 0.0) {
        return;
    }

    NSArray *fixedColumnIdentifiersBeforeImage = [NSArray arrayWithObjects:
                                                  KEY_MEDIA_CHAPSMPTE,
                                                  KEY_MEDIA_IMGSMPTE,
                                                  KEY_ABS_CHAPSMPTE,
                                                  KEY_ABS_IMGSMPTE,
                                                  KEY_CROP,
                                                  nil];
    CGFloat fixedColumnWidthBeforeImage = 0.0;
    for (NSString *columnIdentifier in fixedColumnIdentifiersBeforeImage) {
        NSTableColumn *column = [_tableView tableColumnWithIdentifier:columnIdentifier];
        if (column == nil) {
            continue;
        }
        fixedColumnWidthBeforeImage += [column width];
    }

    CGFloat imageColumnWidth = (imageColumn != nil) ? [imageColumn width] : 0.0;
    NSUInteger columnCountBeforeImage = 1 + [fixedColumnIdentifiersBeforeImage count];
    CGFloat intercolumnSpacingBeforeImage = (columnCountBeforeImage > 1)
        ? ([_tableView intercellSpacing].width * (CGFloat)(columnCountBeforeImage - 1))
        : 0.0;
    NSUInteger visibleColumnCount = columnCountBeforeImage + ((imageColumn != nil) ? 1 : 0);
    CGFloat intercolumnSpacingWidth = (visibleColumnCount > 1)
        ? ([_tableView intercellSpacing].width * (CGFloat)(visibleColumnCount - 1))
        : 0.0;
    CGFloat titleWidthForVisibleImage = availableWidth - fixedColumnWidthBeforeImage - imageColumnWidth - intercolumnSpacingWidth;
    // Class 0 keeps Image in the table document but just beyond the initial clip.
    CGFloat titleWidthForScrolledImage = availableWidth - fixedColumnWidthBeforeImage - intercolumnSpacingBeforeImage;
    CGFloat targetTitleWidth = ((widthClass == SMWorkspaceWidthClass0) && imageColumn != nil)
        ? titleWidthForScrolledImage
        : titleWidthForVisibleImage;
    CGFloat titleWidth = MAX(SMChapterTitleColumnMinimumWidth, targetTitleWidth);

    [titleColumn setMinWidth:SMChapterTitleColumnMinimumWidth];
    [titleColumn setMaxWidth:FLT_MAX];
    [titleColumn setWidth:titleWidth];

    NSRect tableFrame = [_tableView frame];
    tableFrame.size.width = fixedColumnWidthBeforeImage + imageColumnWidth + intercolumnSpacingWidth + titleWidth;
    [_tableView setFrame:tableFrame];
}

#pragma mark - Root View Assembly

- (NSScrollView *)newPrimaryChapterScrollView
{
    NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:SMChapterDefaultTableScrollFrame()] autorelease];
    [scrollView setBorderType:NSLineBorder];
    [scrollView setAutohidesScrollers:YES];
    [scrollView setHasHorizontalScroller:YES];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setHorizontalLineScroll:24.0];
    [scrollView setHorizontalPageScroll:10.0];
    [scrollView setVerticalLineScroll:24.0];
    [scrollView setVerticalPageScroll:10.0];
    [scrollView setUsesPredominantAxisScrolling:NO];
    [scrollView setAutoresizingMask:(NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin | NSViewMaxYMargin)];
    return scrollView;
}

- (QuadrantView *)newPrimaryChapterQuadrantView
{
    QuadrantView *quadrantView = [[[QuadrantView alloc] initWithFrame:SMChapterDefaultQuadrantFrame()] autorelease];
    [quadrantView setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [quadrantView setWantsLayer:YES];
    [quadrantView setBackgroundColor:[NSColor blackColor]];
    [quadrantView layer].masksToBounds = YES;

    NSImageView *quad0 = [[[NSImageView alloc] initWithFrame:NSMakeRect(6.0, 130.0, 120.0, 120.0)] autorelease];
    NSImageView *quad1 = [[[NSImageView alloc] initWithFrame:NSMakeRect(131.0, 130.0, 120.0, 120.0)] autorelease];
    NSImageView *quad2 = [[[NSImageView alloc] initWithFrame:NSMakeRect(5.0, 5.0, 120.0, 120.0)] autorelease];
    NSImageView *quad3 = [[[NSImageView alloc] initWithFrame:NSMakeRect(129.0, 5.0, 120.0, 120.0)] autorelease];

    [quad0 setAutoresizingMask:(NSViewMaxXMargin | NSViewMinYMargin)];
    [quad1 setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [quad2 setAutoresizingMask:(NSViewMaxXMargin | NSViewMaxYMargin)];
    [quad3 setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];

    NSArray *quadViews = [NSArray arrayWithObjects:quad0, quad1, quad2, quad3, nil];
    NSArray *alignments = [NSArray arrayWithObjects:
                           [NSNumber numberWithInteger:NSImageAlignTopLeft],
                           [NSNumber numberWithInteger:NSImageAlignTopRight],
                           [NSNumber numberWithInteger:NSImageAlignBottomLeft],
                           [NSNumber numberWithInteger:NSImageAlignBottomRight],
                           nil];
    for (NSUInteger index = 0; index < [quadViews count]; index++) {
        NSImageView *imageView = [quadViews objectAtIndex:index];
        [imageView setWantsLayer:YES];
        [imageView layer].masksToBounds = YES;
        [imageView setImageScaling:NSImageScaleNone];
        [imageView setImageAlignment:[[alignments objectAtIndex:index] integerValue]];
        [quadrantView addSubview:imageView];
    }

    [quadrantView setValue:quad0 forKey:@"_quad0"];
    [quadrantView setValue:quad1 forKey:@"_quad1"];
    [quadrantView setValue:quad2 forKey:@"_quad2"];
    [quadrantView setValue:quad3 forKey:@"_quad3"];
    return quadrantView;
}

- (void)buildChapterViewHierarchyIfNeeded
{
    if ([self isViewLoaded] && _tableView != nil && _quadrantView != nil) {
        return;
    }

    NSView *rootView = [[[NSView alloc] initWithFrame:SMChapterDefaultRootFrame()] autorelease];
    [rootView setHidden:YES];
    [rootView setWantsLayer:YES];
    [rootView setFocusRingType:NSFocusRingTypeNone];
    [rootView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];

    NSScrollView *tableScrollView = [self newPrimaryChapterScrollView];
    _tableView = [self newPrimaryChapterTableView];
    [tableScrollView setDocumentView:_tableView];
    [tableScrollView setVerticalLineScroll:[_tableView rowHeight]];
    [rootView addSubview:tableScrollView];

    _quadrantView = [self newPrimaryChapterQuadrantView];
    [rootView addSubview:_quadrantView];

    _leadoutSecs = [self newMiniEditableFieldWithFrame:SMChapterDefaultLeadoutSecondsFrame()];
    [rootView addSubview:_leadoutSecs];

    _chapterCountLabel = [self newMiniStaticLabelWithTitle:@"Number of Chapters:"
                                                     frame:SMChapterDefaultChapterCountLabelFrame()
                                                  alignment:NSTextAlignmentRight
                                                  textColor:[NSColor controlTextColor]];
    [rootView addSubview:_chapterCountLabel];

    _chapterCnt = [self newMiniEditableFieldWithFrame:SMChapterDefaultChapterCountFrame()];
    [rootView addSubview:_chapterCnt];

    _jumpToImgTC = [self newMiniCheckboxWithTitle:@"Jump To Media Image Time"
                                            frame:SMChapterDefaultJumpToImageTimeFrame()];
    [rootView addSubview:_jumpToImgTC];

    _cropModePopup = [self newChapterCropModePopupWithFrame:SMChapterDefaultCropModePopupFrame()];
    [rootView addSubview:_cropModePopup];

    [self setView:rootView];
}

#pragma mark - Controller State and Observation

- (void)initializeChapterControllerDataIfNeeded
{
    if (_rowArray != nil) {
        [self applyPersistedChapterControlValues];
        [self startObservingAppHasMovieIfNeeded];
        [self updateChapterControlEnabledStates];
        return;
    }

    _rowArray = [[NSMutableArray alloc] init];
    _inspectorRailPinned = [[NSUserDefaults standardUserDefaults] boolForKey:SMChapterInspectorRailPinnedDefaultsKey];

    [self applyPersistedChapterControlValues];
    [self startObservingAppHasMovieIfNeeded];
    [self updateChapterControlEnabledStates];
}

- (void)applyPersistedChapterControlValues
{
    NSInteger leadout = [[AppController infoValueForKey:KEY_CHAPTER_LEADOUT] integerValue];
    NSInteger chapterCount = [[AppController infoValueForKey:KEY_CHAPTER_COUNT] integerValue];

    if (_leadoutSecs != nil) {
        [_leadoutSecs setIntegerValue:leadout];
    }
    if (_chapterCnt != nil) {
        [_chapterCnt setIntegerValue:chapterCount];
    }
    if (_cropModePopup != nil) {
        [_cropModePopup selectItemWithTag:SMChapterCropModeManual];
    }
}

- (void)updateChapterControlEnabledStates
{
    BOOL hasMovie = [appcontroller() hasMovie];
    BOOL jumpEnabledForCurrentContext = [self isQuadrantViewEnabledForCurrentContext];

    [_leadoutSecs setEnabled:hasMovie];
    [_chapterCnt setEnabled:hasMovie];
    [_cropModePopup setEnabled:hasMovie];
    [_jumpToImgTC setEnabled:jumpEnabledForCurrentContext];
    if (!jumpEnabledForCurrentContext && _jumpToImgTC != nil && [_jumpToImgTC state] != NSControlStateValueOff) {
        [_jumpToImgTC setState:NSControlStateValueOff];
    }

    [self updateQuadrantViewForCurrentContext];
}

- (BOOL)isQuadrantViewEnabledForCurrentContext
{
    AppController *appController = appcontroller();
    if (appController == nil || ![appController hasMovie] || !_hasPackageContext) {
        return NO;
    }

    SMMovie *movie = _playerView.movie;
    if (movie == nil) {
        return NO;
    }

    NSURL *movieURL = [movie URL];
    NSString *moviePath = [movieURL path];
    if (!SMChapterStringHasContent(moviePath)) {
        return NO;
    }

    return [appController shouldRetainPackageContextWhenOpeningMoviePath:moviePath];
}

- (void)updateQuadrantViewForCurrentContext
{
    if (_quadrantView == nil) {
        return;
    }

    BOOL quadrantEnabled = [self isQuadrantViewEnabledForCurrentContext];
    if (quadrantEnabled) {
        [self syncQuadrantBackgroundToPlayerView];
        [_quadrantView setDisabledAppearanceEnabled:NO];
        return;
    }

    [_quadrantView setLastClickedImg:0];
    [_quadrantView setBackgroundColor:[NSColor blackColor]];
    [_quadrantView setDisabledAppearanceEnabled:YES];
    [_quadrantView setNeedsDisplay:YES];
}

- (BOOL)canJumpToChapterMarkerTime:(long long)targetTime
                        markerLabel:(NSString *)markerLabel
                           rowIndex:(NSInteger)rowIndex
{
    SMMovie *movie = _playerView.movie;
    if (movie == nil) {
        return NO;
    }

    long long durationTime = [movie durationTimeValue];
    if (durationTime <= 0) {
        return NO;
    }

    if (targetTime < 0 || targetTime > durationTime) {
        NSString *markerTimecode = [self getTimeCodeStringForTimeValue:MAX(0LL, targetTime)];
        NSString *durationTimecode = [self getTimeCodeStringForTimeValue:durationTime];
        NSString *status = [NSString stringWithFormat:SMChapterJumpBlockedStatusFormat,
                            (long)rowIndex + 1,
                            (SMChapterStringHasContent(markerLabel) ? markerLabel : @"chapter"),
                            (markerTimecode ?: @""),
                            (durationTimecode ?: @"")];
        [appcontroller() showStatusMessage:status persist:NO];
        return NO;
    }

    return YES;
}

- (void)startObservingAppHasMovieIfNeeded
{
    if (_isObservingHasMovie) {
        return;
    }

    AppController *appDelegate = appcontroller();
    if (appDelegate == nil) {
        return;
    }

    @try {
        [appDelegate addObserver:self
                      forKeyPath:@"hasMovie"
                         options:NSKeyValueObservingOptionInitial
                         context:SMChapterHasMovieKVOContext];
        _isObservingHasMovie = YES;
    } @catch (NSException *exception) {
        #pragma unused(exception)
        _isObservingHasMovie = NO;
    }
}

- (void)stopObservingAppHasMovieIfNeeded
{
    if (!_isObservingHasMovie) {
        return;
    }

    AppController *appDelegate = appcontroller();
    @try {
        [appDelegate removeObserver:self forKeyPath:@"hasMovie" context:SMChapterHasMovieKVOContext];
    } @catch (NSException *exception) {
        #pragma unused(exception)
    }
    _isObservingHasMovie = NO;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    #pragma unused(object, change)
    if (context == SMChapterHasMovieKVOContext && [keyPath isEqualToString:@"hasMovie"]) {
        [self updateChapterControlEnabledStates];
        return;
    }

    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

#pragma mark - Validation

- (void)applyCanonicalValidationFindings:(NSArray *)findings
{
    NSArray *canonicalFindings = SlateInspectorRailCanonicalFindingsArray(findings);
    [_canonicalValidationFindings release];
    _canonicalValidationFindings = [canonicalFindings copy];

    NSString *toolTip = SlateInspectorRailFindingsSummaryToolTip(_canonicalValidationFindings,
                                                                   SMChapterReadinessFindingsToolTipTitle);
    [_tableView setToolTip:SlateInspectorRailCopyHintTooltip(toolTip)];
    [self updateChapterReadinessPanelPresentation];
}

- (NSArray *)canonicalValidationFindings
{
    return (_canonicalValidationFindings ?: [NSArray array]);
}

- (void)refreshValidationAdaptersAfterMutation
{
    [appcontroller() refreshValidationViewAdapters];
}

- (BOOL)shouldJumpToImageTimeForChapterSelection
{
    return (!_suppressChapterSelectionJump
            && _jumpToImgTC != nil
            && [_jumpToImgTC isEnabled]
            && ([_jumpToImgTC state] == NSControlStateValueOn));
}

#pragma mark - Scanability

- (void)applyChapterScanabilityMetrics
{
    if (_tableView != nil) {
        [_tableView setRowHeight:SMChapterTableRowHeight];
        NSSize intercellSpacing = [_tableView intercellSpacing];
        intercellSpacing.height = SMChapterTableIntercellVerticalSpacing;
        [_tableView setIntercellSpacing:intercellSpacing];
        [_tableView setUsesAlternatingRowBackgroundColors:YES];

        NSFont *headerFont = SMChapterTableHeaderFont();
        for (NSTableColumn *column in [_tableView tableColumns]) {
            [[column headerCell] setFont:headerFont];
            [[column headerCell] setControlSize:NSControlSizeRegular];
        }
        NSTableHeaderView *headerView = [_tableView headerView];
        if (headerView != nil) {
            NSRect headerFrame = [headerView frame];
            headerFrame.size.height = SMChapterTableHeaderHeight;
            [headerView setFrame:headerFrame];
        }

        [_tableView setFocusRingType:NSFocusRingTypeDefault];
        NSScrollView *tableScrollView = [_tableView enclosingScrollView];
        [tableScrollView setFocusRingType:NSFocusRingTypeNone];
        [tableScrollView setVerticalLineScroll:[_tableView rowHeight]];
    }

    [_cropModePopup setControlSize:NSSmallControlSize];
    [self updateChapterControlEnabledStates];
}

#pragma mark - Readiness Rail

- (NSTextField *)newChapterOverlayLabelWithString:(NSString *)stringValue
                                              font:(NSFont *)font
                                         textColor:(NSColor *)textColor
                                         alignment:(NSTextAlignment)alignment
                                         multiLine:(BOOL)multiLine
{
    return SlateInspectorRailCreateLabel(stringValue,
                                           font,
                                           textColor,
                                           alignment,
                                           multiLine);
}

- (void)restoreChapterReadinessSubviewOrderIfNeeded
{
    NSView *containerView = [self view];
    if (containerView == nil) {
        return;
    }

    NSMutableArray *orderedViews = [NSMutableArray arrayWithCapacity:7];
    NSView *readinessSectionLabel = [_readinessPresenter sectionLabel];
    NSView *readinessStatusLabel = [_readinessPresenter statusLabel];
    NSView *readinessScrollView = [_readinessPresenter scrollView];
    NSView *inspectorPinButton = [_readinessPresenter pinButton];
    if (readinessSectionLabel != nil) {
        [orderedViews addObject:readinessSectionLabel];
    }
    if (readinessStatusLabel != nil) {
        [orderedViews addObject:readinessStatusLabel];
    }
    if (readinessScrollView != nil) {
        [orderedViews addObject:readinessScrollView];
    }
    if (_leadoutLabel != nil) {
        [orderedViews addObject:_leadoutLabel];
    }
    if (_tableEmptyStateLabel != nil) {
        [orderedViews addObject:_tableEmptyStateLabel];
    }
    if (_inspectorEmptyStateLabel != nil) {
        [orderedViews addObject:_inspectorEmptyStateLabel];
    }
    if (inspectorPinButton != nil) {
        [orderedViews addObject:inspectorPinButton];
    }
    if ([orderedViews count] != 7) {
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

- (void)ensureChapterLayoutSupplementaryViews
{
    if (_inspectorGroupBox == nil) {
        _inspectorGroupBox = [[NSBox alloc] initWithFrame:NSZeroRect];
        SlateInspectorRailApplyToolGroupBoxStyle(_inspectorGroupBox);
        [_inspectorGroupBox setHidden:YES];
        [[self view] addSubview:_inspectorGroupBox positioned:NSWindowBelow relativeTo:nil];
    }

    if (_inspectorSectionLabel == nil) {
        _inspectorSectionLabel = [[self newChapterOverlayLabelWithString:@"Crop + Image Inspector"
                                                                    font:[NSFont boldSystemFontOfSize:11.5]
                                                               textColor:[NSColor secondaryLabelColor]
                                                               alignment:NSTextAlignmentLeft
                                                             multiLine:NO] retain];
        SlateInspectorRailApplySectionHeaderStyle(_inspectorSectionLabel);
        [[self view] addSubview:_inspectorSectionLabel];
    }

    if (_readinessPresenter == nil) {
        _readinessPresenter = [[UtilReadinessRailPresenter alloc] initWithSectionTitle:SMChapterSectionTitleReadiness
                                                                 findingsToolTipTitle:SMChapterReadinessFindingsToolTipTitle
                                                                            pinTarget:self
                                                                            pinAction:@selector(toggleInspectorRailPinned:)
                                                                     textViewDelegate:(id<NSTextViewDelegate>)self];
    }
    [_readinessPresenter ensureViewsInSuperview:[self view]];
    [_readinessPresenter setPinState:_inspectorRailPinned];

    if (_leadoutLabel == nil) {
        _leadoutLabel = [[self newChapterOverlayLabelWithString:@"Leadout (secs):"
                                                           font:[NSFont systemFontOfSize:10.5]
                                                      textColor:[NSColor secondaryLabelColor]
                                                      alignment:NSTextAlignmentLeft
                                                    multiLine:NO] retain];
        SlateInspectorRailApplyValueRowStyle(_leadoutLabel);
        [_leadoutLabel setFont:[NSFont systemFontOfSize:10.5]];
        [[self view] addSubview:_leadoutLabel];
    }

    if (_tableEmptyStateLabel == nil) {
        _tableEmptyStateLabel = [[self newChapterOverlayLabelWithString:@""
                                                                   font:[NSFont systemFontOfSize:12.0]
                                                              textColor:[NSColor secondaryLabelColor]
                                                              alignment:NSTextAlignmentCenter
                                                            multiLine:YES] retain];
        SlateInspectorRailApplyStateMessageStyle(_tableEmptyStateLabel);
        [_tableEmptyStateLabel setHidden:YES];
        [[self view] addSubview:_tableEmptyStateLabel];
    }

    if (_inspectorEmptyStateLabel == nil) {
        _inspectorEmptyStateLabel = [[self newChapterOverlayLabelWithString:@""
                                                                       font:[NSFont systemFontOfSize:11.5]
                                                                  textColor:[NSColor secondaryLabelColor]
                                                                  alignment:NSTextAlignmentCenter
                                                                multiLine:YES] retain];
        SlateInspectorRailApplyStateMessageStyle(_inspectorEmptyStateLabel);
        [_inspectorEmptyStateLabel setFont:[NSFont systemFontOfSize:11.5]];
        [_inspectorEmptyStateLabel setAutoresizingMask:NSViewNotSizable];
        [_inspectorEmptyStateLabel setHidden:YES];
        [[self view] addSubview:_inspectorEmptyStateLabel];
    }

    [self restoreChapterReadinessSubviewOrderIfNeeded];
}

- (void)setInspectorRailPinned:(BOOL)pinned
{
    if (_inspectorRailPinned == pinned) {
        return;
    }

    _inspectorRailPinned = pinned;
    [_readinessPresenter setPinState:pinned];
    [[NSUserDefaults standardUserDefaults] setBool:pinned forKey:SMChapterInspectorRailPinnedDefaultsKey];
}

- (IBAction)toggleInspectorRailPinned:(id)sender
{
    BOOL pinned = ([(NSButton *)sender state] == NSOnState);
    [self setInspectorRailPinned:pinned];
    [self applyWorkspaceLayoutForWidth:NSWidth([[self view] bounds])];
}

- (NSInteger)chapterRowIndexForReadinessFinding:(NSDictionary *)finding
{
    if (![finding isKindOfClass:[NSDictionary class]]) {
        return NSNotFound;
    }

    NSInteger rowIndex = SMChapterRowIndexFromFindingScope([finding objectForKey:SMValidationFindingKeyScope]);
    if (rowIndex != NSNotFound) {
        return rowIndex;
    }

    NSString *code = [finding objectForKey:SMValidationFindingKeyCode];
    if (SMChapterStringHasContent(code) && [code isEqualToString:SMValidationFindingCodeChaptersChapterImageIsNotMarkedValid]) {
        return [self firstInvalidImageRowIndex];
    }

    return NSNotFound;
}

- (NSDictionary *)chapterReadinessJumpLinksByFindingIdentity
{
    NSMutableDictionary *jumpLinkByFindingIdentity = [NSMutableDictionary dictionary];
    for (NSDictionary *finding in [self canonicalValidationFindings]) {
        if (![finding isKindOfClass:[NSDictionary class]]) {
            continue;
        }

        NSInteger rowIndex = [self chapterRowIndexForReadinessFinding:finding];
        NSString *jumpLink = SlateInspectorRailJumpLink(@"chapters", rowIndex);
        if (SMChapterStringHasContent(jumpLink)) {
            [jumpLinkByFindingIdentity setObject:jumpLink
                                          forKey:SlateInspectorRailFindingIdentity(finding)];
        }
    }

    return jumpLinkByFindingIdentity;
}

- (void)updateChapterReadinessPanelPresentation
{
    [self ensureChapterLayoutSupplementaryViews];

    NSString *emptyStatus = _hasPackageContext ? SMChapterReadinessStatusNoFindings : SMChapterReadinessStatusNoPackageLoaded;
    NSString *emptyMessage = _hasPackageContext ? SMChapterReadinessEmptyMessageNoFindings : @"";
    NSDictionary *jumpLinkByFindingIdentity = [self chapterReadinessJumpLinksByFindingIdentity];
    NSDictionary *reviewPaneSnapshot = [SlateRuntimeBridge reviewPaneSnapshotWithPaneKey:SlateReviewPaneKeyChapter
                                                                                title:SMChapterSectionTitleReadiness
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
    if (![target isEqualToString:@"chapters"]) {
        return NO;
    }

    NSInteger rowCount = [_tableView numberOfRows];
    if (rowCount > 0) {
        NSInteger boundedRow = rowIndex;
        if (boundedRow == NSNotFound || boundedRow < 0 || boundedRow >= rowCount) {
            boundedRow = [self firstInvalidImageRowIndex];
            if (boundedRow == NSNotFound || boundedRow < 0 || boundedRow >= rowCount) {
                boundedRow = 0;
            }
        }
        _suppressChapterSelectionJump = YES;
        @try {
            [_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:boundedRow] byExtendingSelection:NO];
        } @finally {
            _suppressChapterSelectionJump = NO;
        }
        [_tableView scrollRowToVisible:boundedRow];
        [[[self view] window] makeFirstResponder:_tableView];
    }

    return YES;
}

#pragma mark - Rail Layout Helpers

- (void)setChapterPanelView:(NSView *)view frame:(NSRect)frame hidden:(BOOL)hidden
{
    if (view == nil) {
        return;
    }

    [view setHidden:hidden];
    [view setFrame:frame];
}

- (void)hideChapterCreationControls
{
    [self setChapterPanelView:_leadoutLabel frame:NSZeroRect hidden:YES];
    [self setChapterPanelView:_leadoutSecs frame:SMChapterDefaultLeadoutSecondsFrame() hidden:YES];
    [self setChapterPanelView:_chapterCountLabel frame:SMChapterDefaultChapterCountLabelFrame() hidden:YES];
    [self setChapterPanelView:_chapterCnt frame:SMChapterDefaultChapterCountFrame() hidden:YES];
}

- (void)hideChapterInspectorControls
{
    [self hideChapterCreationControls];
    [self setChapterPanelView:_jumpToImgTC frame:SMChapterDefaultJumpToImageTimeFrame() hidden:YES];
    [self setChapterPanelView:_cropModePopup frame:SMChapterDefaultCropModePopupFrame() hidden:YES];
}

- (void)hideChapterInspectorRail
{
    [self setChapterPanelView:_inspectorSectionLabel frame:NSZeroRect hidden:YES];
    [self setChapterPanelView:_inspectorGroupBox frame:NSZeroRect hidden:YES];
    [self hideChapterInspectorControls];
    [self setChapterPanelView:_quadrantView frame:SMChapterDefaultQuadrantFrame() hidden:YES];
}

- (void)hideChapterReadinessRail
{
    [_readinessPresenter applySectionFrame:NSZeroRect
                               statusFrame:NSZeroRect
                               scrollFrame:NSZeroRect
                                  pinFrame:NSZeroRect
                                pinVisible:YES];
    [_readinessPresenter setRailHidden:YES];
}

- (void)hideChapterInspectorEmptyState
{
    [_inspectorEmptyStateLabel setStringValue:@""];
    [_inspectorEmptyStateLabel setAutoresizingMask:NSViewNotSizable];
    [self setChapterPanelView:_inspectorEmptyStateLabel frame:NSZeroRect hidden:YES];
}

- (void)applyChapterReadinessRailFrame:(NSRect)readinessFrame
                    readinessTopYAnchor:(CGFloat)readinessTopYAnchor
                     sectionLabelHeight:(CGFloat)sectionLabelHeight
                             sectionGap:(CGFloat)sectionGap
{
    CGFloat readinessStatusHeight = SlateInspectorRailDisclosureRowHeight();
    CGFloat readinessTopY = readinessTopYAnchor;
    CGFloat readinessStatusY = readinessTopY - readinessStatusHeight - 2.0;
    CGFloat readinessPanelBottomY = NSMinY(readinessFrame);
    CGFloat readinessScrollHeight = (readinessStatusY - sectionGap) - readinessPanelBottomY;
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
                                            readinessPanelBottomY,
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
    [self updateChapterReadinessPanelPresentation];
}

- (void)applyChapterInspectorRailFrame:(NSRect)inspectorFrame
                          layoutBounds:(NSRect)layoutBounds
                                gutter:(CGFloat)gutter
                       readinessBottomY:(CGFloat)readinessBottomY
                           contentTopY:(CGFloat)contentTopY
                     sectionLabelHeight:(CGFloat)sectionLabelHeight
                             widthClass:(SMWorkspaceWidthClass)widthClass
                      showReadinessRail:(BOOL)showReadinessRail
{
    [_inspectorSectionLabel setHidden:NO];
    CGFloat inspectorContentTopY = MIN(contentTopY, NSMaxY(inspectorFrame));
    [_inspectorSectionLabel setFrame:NSMakeRect(inspectorFrame.origin.x,
                                                inspectorContentTopY + SlateInspectorRailSectionHeaderYOffset(),
                                                inspectorFrame.size.width,
                                                sectionLabelHeight)];

    CGFloat inspectorGroupInsetX = SMChapterInspectorGroupInsetX;
    inspectorGroupInsetX = MIN(inspectorGroupInsetX,
                               MAX(0.0, gutter - SMChapterMinimumInterColumnGap));
    CGFloat inspectorHeaderInsetX = SMChapterInspectorGroupHeaderInsetX;
    CGFloat inspectorHeaderTopInset = SMChapterInspectorGroupHeaderTopInset;
    // Keep C + I fixed-height; readiness absorbs vertical headroom.
    CGFloat inspectorGroupTopY = NSMaxY(inspectorFrame);
    CGFloat inspectorGroupBottomY = readinessBottomY;
    NSRect inspectorGroupFrame = NSZeroRect;
    if (inspectorGroupTopY > inspectorGroupBottomY) {
        inspectorGroupFrame = NSMakeRect(inspectorFrame.origin.x - inspectorGroupInsetX,
                                         inspectorGroupBottomY,
                                         inspectorFrame.size.width + (inspectorGroupInsetX * 2.0),
                                         inspectorGroupTopY - inspectorGroupBottomY);
        if (!showReadinessRail) {
            // Keep the rightmost active rail edge on the shared inset contract
            // when readiness drops in class-1 layouts, while preserving left
            // alignment with the table/inspector gutter.
            CGFloat desiredRightEdge = NSMaxX(layoutBounds) - SlateInspectorRailRightInset();
            inspectorGroupFrame.size.width = MAX(1.0, desiredRightEdge - NSMinX(inspectorGroupFrame));
        }
        [_inspectorGroupBox setFrame:inspectorGroupFrame];
        [_inspectorGroupBox setHidden:NO];
        [_inspectorSectionLabel setFrame:NSMakeRect(NSMinX(inspectorGroupFrame) + inspectorHeaderInsetX,
                                                    NSMaxY(inspectorGroupFrame) - sectionLabelHeight - inspectorHeaderTopInset,
                                                    MAX(1.0, NSWidth(inspectorGroupFrame) - inspectorHeaderInsetX - 8.0),
                                                    sectionLabelHeight)];
    } else {
        [self setChapterPanelView:_inspectorGroupBox frame:NSZeroRect hidden:YES];
    }

    [self layoutChapterInspectorControlsInRailFrame:inspectorFrame
                                        contentTopY:inspectorContentTopY
                               inspectorGroupFrame:inspectorGroupFrame
                                         widthClass:widthClass];
}

- (CGFloat)visibleTableWidthForColumnIdentifiers:(NSArray *)identifiers
{
    if (![identifiers isKindOfClass:[NSArray class]] || [identifiers count] == 0) {
        return 0.0;
    }

    CGFloat width = 0.0;
    NSUInteger visibleColumnCount = 0;
    for (NSString *identifier in identifiers) {
        NSTableColumn *column = [_tableView tableColumnWithIdentifier:identifier];
        if (column == nil || [column isHidden]) {
            continue;
        }

        width += [identifier isEqualToString:KEY_CHAPTITLE] ? [column minWidth] : [column width];
        visibleColumnCount++;
    }

    if (visibleColumnCount > 1) {
        width += ([[_tableView headerView] bounds].size.width >= 0.0
                  ? [_tableView intercellSpacing].width * (visibleColumnCount - 1)
                  : 0.0);
    }

    // Include table border slop so the next hidden column does not peek.
    return ceil(width + 2.0);
}

- (void)layoutChapterInspectorControlsInRailFrame:(NSRect)railFrame
                                       contentTopY:(CGFloat)contentTopY
                              inspectorGroupFrame:(NSRect)inspectorGroupFrame
                                        widthClass:(SMWorkspaceWidthClass)widthClass
{
    CGFloat sectionGap = SlateInspectorRailSectionGap();
    CGFloat compactPadding = SMChapterWorkspaceOuterPadding() - 2.0;
    CGFloat railPadding = MAX(SMChapterInspectorRailMinimumPadding, compactPadding);
    CGFloat rowHeight = SMChapterInspectorRowHeight;
    CGFloat rowGap = SMChapterInspectorRowGap;
    BOOL useWideInspectorMetrics = (NSWidth(railFrame) >= 320.0) || (widthClass == SMWorkspaceWidthClass2);
    CGFloat popupWidth = useWideInspectorMetrics ? SMChapterInspectorPopupWidthWide : SMChapterInspectorPopupWidthCompact;

    CGFloat innerX = railFrame.origin.x + railPadding;
    CGFloat innerWidth = MAX(160.0, railFrame.size.width - (railPadding * 2.0));
    CGFloat controlY = railFrame.origin.y + railPadding;
    CGFloat controlInsetX = 12.0;
    CGFloat leftControlX = railFrame.origin.x + controlInsetX;
    CGFloat rightControlX = NSMaxX(railFrame) - controlInsetX;

    NSRect jumpFrame = [_jumpToImgTC frame];
    jumpFrame.origin.x = leftControlX;
    jumpFrame.origin.y = controlY;
    jumpFrame.size.width = MIN(innerWidth, 240.0);

    CGFloat popupMaxWidth = MAX(SMChapterInspectorCropPopupMinimumWidth, rightControlX - leftControlX);
    popupWidth = MIN(popupWidth, popupMaxWidth);
    CGFloat popupX = rightControlX - popupWidth;
    CGFloat availableJumpWidth = MAX(72.0, popupX - leftControlX - SMChapterWorkspaceGutter());
    jumpFrame.size.width = MIN(jumpFrame.size.width, availableJumpWidth);

    // Chapter creation controls are intentionally hidden in inspection-first mode.
    [self hideChapterCreationControls];

    [self setChapterPanelView:_jumpToImgTC frame:jumpFrame hidden:NO];
    NSRect cropPopupFrame = NSMakeRect(popupX, controlY, popupWidth, rowHeight + 3.0);
    [self setChapterPanelView:_cropModePopup frame:cropPopupFrame hidden:NO];
    controlY = MAX(NSMaxY(jumpFrame), NSMaxY(cropPopupFrame)) + rowGap + 3.0;

    CGFloat previewBottomY = controlY + sectionGap;
    CGFloat previewCenterX = (NSWidth(inspectorGroupFrame) > 0.0)
        ? NSMidX(inspectorGroupFrame)
        : (innerX + (innerWidth / 2.0));
    NSRect quadrantFrame = NSMakeRect(floor(previewCenterX - (SMChapterInspectorPreviewFixedSideLength / 2.0)),
                                      previewBottomY,
                                      SMChapterInspectorPreviewFixedSideLength,
                                      SMChapterInspectorPreviewFixedSideLength);
    [self setChapterPanelView:_quadrantView frame:quadrantFrame hidden:NO];
}

- (void)updateChapterEmptyStatePresentation
{
    [self ensureChapterLayoutSupplementaryViews];

    NSScrollView *tableScrollView = [_tableView enclosingScrollView];
    if (tableScrollView == nil || _quadrantView == nil) {
        return;
    }

    NSInteger rowCount = [self chapterSnapshotRowCount];
    BOOL hasRows = rowCount > 0;

    NSString *tableMessage = @"";
    if (!hasRows) {
        tableMessage = _hasPackageContext
            ? SMChapterTableNoRowsMessage
            : @"";
    }
    BOOL showTableMessage = SMChapterStringHasContent(tableMessage) && !hasRows;
    [_tableEmptyStateLabel setStringValue:showTableMessage ? tableMessage : @""];
    [_tableEmptyStateLabel setHidden:!showTableMessage];

    NSRect tableFrame = [tableScrollView frame];
    NSRect tableEmptyFrame = NSInsetRect(tableFrame, SMChapterTableEmptyStateInset, SMChapterTableEmptyStateInset);
    tableEmptyFrame.origin.y = tableFrame.origin.y + floor((tableFrame.size.height - SMChapterTableEmptyStateHeight) / 2.0);
    tableEmptyFrame.size.height = SMChapterTableEmptyStateHeight;
    [_tableEmptyStateLabel setFrame:tableEmptyFrame];

    // Keep C + I visually quiet; left table + right readiness already convey state.
    [self hideChapterInspectorEmptyState];
    BOOL inspectorRailVisible = (_inspectorSectionLabel != nil && ![_inspectorSectionLabel isHidden]);
    if (!inspectorRailVisible) {
        [self hideChapterInspectorEmptyState];
        [self setChapterPanelView:_quadrantView frame:SMChapterDefaultQuadrantFrame() hidden:YES];
        return;
    }

    [_quadrantView setHidden:NO];
}

#pragma mark - Workspace Layout

// Width class drives the rail choreography; table columns stay boring.
- (void)applyWorkspaceLayoutForWidth:(CGFloat)workspaceWidth
{
    [self ensureChapterLayoutSupplementaryViews];
    [self updateChapterControlEnabledStates];

    SMWorkspaceWidthClass widthClass = SMWorkspaceWidthClassForWidth(workspaceWidth);

    NSScrollView *tableScrollView = [_tableView enclosingScrollView];
    CGFloat compactFiveColumnWidth = [self visibleTableWidthForColumnIdentifiers:[NSArray arrayWithObjects:
                                                                                  @"chapterTitle",
                                                                                  @"mediaChapterTimecode",
                                                                                  @"mediaImageTimecode",
                                                                                  @"chapterTimecode",
                                                                                  @"imageTimecode",
                                                                                  nil]];
    if (tableScrollView != nil && _quadrantView != nil) {
        NSRect viewBounds = [[self view] bounds];
        NSRect defaultRootFrame = SMChapterDefaultRootFrame();
        NSRect layoutBounds = SlateWorkspaceCenteredContentEnvelope(viewBounds,
                                                                    NSWidth(defaultRootFrame),
                                                                    NSHeight(defaultRootFrame),
                                                                    SlateWorkspaceHorizontalExpansionAllowance(),
                                                                    SlateWorkspaceVerticalExpansionAllowance());
        CGFloat leadingInset = SlateWorkspacePrimaryPaneTableAnchorX();
        // Keep right-edge choreography deterministic across 2 -> 1 breaks: always
        // honor the shared rail inset contract rather than drifting with captured
        // default frames.
        CGFloat trailingInset = MAX(SlateWorkspaceTrailingInsetMinimum(), SlateInspectorRailRightInset());
        CGFloat tableStartX = NSMinX(layoutBounds) + leadingInset;
        CGFloat workspaceBottomY = NSMinY(layoutBounds) + SlateInspectorRailEffectiveBottomInsetForHostView([self view]);
        CGFloat workspaceWidthForLayout = NSWidth(layoutBounds);
        CGFloat workspaceWidthValue = MAX(SMChapterResponsiveWorkspaceMinimumWidth, workspaceWidthForLayout - leadingInset - trailingInset);
        workspaceWidthValue = MIN(workspaceWidthValue, workspaceWidthForLayout - leadingInset - SMChapterWorkspaceOuterPadding());

        CGFloat sectionLabelHeight = SlateInspectorRailSectionHeaderHeight();
        CGFloat sectionGap = SlateInspectorRailSectionGap();
        CGFloat designContentTopY = SlateWorkspacePrimaryPaneTableAnchorTopY()
            + sectionLabelHeight
            + SlateInspectorRailSectionHeaderYOffset();
        CGFloat railContentTopY = NSMaxY(layoutBounds) - (NSHeight(defaultRootFrame) - designContentTopY);
        CGFloat verticalGrowth = MAX(0.0, NSHeight(layoutBounds) - NSHeight(defaultRootFrame));
        CGFloat desiredTableContentTopY = NSMinY(layoutBounds) + designContentTopY + verticalGrowth;
        CGFloat maxTableContentTopY = workspaceBottomY + SMChapterMaximumTableHeightForVisibleRows();
        CGFloat tableContentTopY = MIN(MIN(desiredTableContentTopY, maxTableContentTopY),
                                       railContentTopY);
        CGFloat readinessTopYAnchor = railContentTopY
            - sectionLabelHeight
            - SlateInspectorRailSectionHeaderYOffset();
        BOOL forceTableOnlyRail = (widthClass == SMWorkspaceWidthClass0 && !_inspectorRailPinned);
        if (forceTableOnlyRail) {
            CGFloat tableRightInset = MAX(SlateWorkspaceTrailingInsetMinimum(), SlateInspectorRailRightInset());
            NSRect tableFrame = NSMakeRect(tableStartX,
                                           workspaceBottomY,
                                           MAX(0.0, (NSMaxX(layoutBounds) - tableRightInset) - tableStartX),
                                           MAX(SlateWorkspaceMinimumContentHeight(), tableContentTopY - workspaceBottomY));
            [tableScrollView setFrame:tableFrame];
            [self applyPrimaryChapterTableColumnWidthsForWidthClass:widthClass];

            [self hideChapterInspectorRail];
            [self hideChapterInspectorEmptyState];
            [self hideChapterReadinessRail];

            [[_tableView headerView] setNeedsDisplay:YES];
            [self updateChapterEmptyStatePresentation];
            return;
        }
        BOOL forceReadinessOnlyRail = ((widthClass == SMWorkspaceWidthClass0) && _inspectorRailPinned)
            || (widthClass == SMWorkspaceWidthClass1)
            || ((widthClass == SMWorkspaceWidthClass2)
                && (workspaceWidthForLayout <= SlateWorkspaceRailBreakWidthClass2To1()));
        if (forceReadinessOnlyRail) {
            CGFloat gutter = SMChapterWorkspaceGutter();
            CGFloat readinessWidth = SlateInspectorRailFixedWidth();
            CGFloat readinessRightInset = SlateInspectorRailRightInset();
            CGFloat readinessBottomY = workspaceBottomY;
            CGFloat readinessFrameX = NSMaxX(layoutBounds) - readinessRightInset - readinessWidth;
            NSRect tableFrame = NSMakeRect(tableStartX,
                                           workspaceBottomY,
                                           MAX(0.0, readinessFrameX - gutter - tableStartX),
                                           MAX(SlateWorkspaceMinimumContentHeight(), tableContentTopY - workspaceBottomY));
            NSRect readinessFrame = NSMakeRect(readinessFrameX,
                                               readinessBottomY,
                                               readinessWidth,
                                               MAX(SlateInspectorRailWarningBlockMinHeight(),
                                                   railContentTopY - readinessBottomY));
            [tableScrollView setFrame:tableFrame];
            [self applyPrimaryChapterTableColumnWidthsForWidthClass:widthClass];

            [self hideChapterInspectorRail];
            [self hideChapterInspectorEmptyState];

            [self applyChapterReadinessRailFrame:readinessFrame
                              readinessTopYAnchor:readinessTopYAnchor
                               sectionLabelHeight:sectionLabelHeight
                                       sectionGap:sectionGap];

            [[_tableView headerView] setNeedsDisplay:YES];
            [self updateChapterEmptyStatePresentation];
            return;
        }

        CGFloat gutter = SMChapterWorkspaceGutter();
        CGFloat readinessBottomY = workspaceBottomY;
        SMChapterFixedRailLayout fixedLayout = SMChapterResolveFixedRailLayout(widthClass,
                                                                               _inspectorRailPinned,
                                                                               compactFiveColumnWidth,
                                                                               layoutBounds,
                                                                               tableStartX,
                                                                               workspaceBottomY,
                                                                               workspaceWidthValue,
                                                                               tableContentTopY,
                                                                               railContentTopY);
        [tableScrollView setFrame:fixedLayout.tableFrame];
        [self applyPrimaryChapterTableColumnWidthsForWidthClass:widthClass];

        if (!fixedLayout.showInspectorRail) {
            [self hideChapterInspectorRail];
            [self hideChapterReadinessRail];
            [self hideChapterInspectorEmptyState];
        } else {
            [self applyChapterInspectorRailFrame:fixedLayout.inspectorFrame
                                    layoutBounds:layoutBounds
                                          gutter:gutter
                                  readinessBottomY:readinessBottomY
                                     contentTopY:railContentTopY
                               sectionLabelHeight:sectionLabelHeight
                                       widthClass:widthClass
                                showReadinessRail:fixedLayout.showReadinessRail];

            if (fixedLayout.showReadinessRail) {
                [self applyChapterReadinessRailFrame:fixedLayout.readinessFrame
                                  readinessTopYAnchor:readinessTopYAnchor
                                   sectionLabelHeight:sectionLabelHeight
                                           sectionGap:sectionGap];
            } else {
                [self hideChapterReadinessRail];
            }

        }
    } else {
        [self hideChapterInspectorRail];
        [self hideChapterReadinessRail];
    }

    [self applyPrimaryChapterTableColumnWidthsForWidthClass:widthClass];
    [[_tableView headerView] setNeedsDisplay:YES];
    [self updateChapterEmptyStatePresentation];
}

#pragma mark - Mode Switch and Probe

- (NSDictionary *)modeSwitchContextSnapshot
{
    NSMutableDictionary *snapshot = [NSMutableDictionary dictionary];
    [snapshot setObject:[NSNumber numberWithInteger:[_tableView selectedRow]]
                 forKey:@"selectedRow"];
    [snapshot setObject:[NSNumber numberWithInteger:[_cropModePopup selectedTag]]
                 forKey:@"cropModeTag"];

    NSDictionary *tableScrollSnapshot = SMChapterScrollSnapshotForScrollView([_tableView enclosingScrollView]);
    if (tableScrollSnapshot != nil) {
        [snapshot setObject:tableScrollSnapshot forKey:@"tableScroll"];
    }

    NSDictionary *readinessScrollSnapshot = SMChapterScrollSnapshotForScrollView([_readinessPresenter scrollView]);
    if (readinessScrollSnapshot != nil) {
        [snapshot setObject:readinessScrollSnapshot forKey:@"readinessScroll"];
    }

    return snapshot;
}

- (NSDictionary *)layoutProbeSnapshot
{
    NSView *rootView = [self view];
    NSRect rootBounds = (rootView != nil) ? [rootView bounds] : NSZeroRect;
    NSScrollView *tableScrollView = [_tableView enclosingScrollView];
    NSRect tableFrame = (tableScrollView != nil) ? [tableScrollView frame] : NSZeroRect;
    NSRect inspectorFrame = (_quadrantView != nil) ? [_quadrantView frame] : NSZeroRect;
    NSRect inspectorGroupFrame = (_inspectorGroupBox != nil) ? [_inspectorGroupBox frame] : NSZeroRect;
    NSScrollView *readinessScrollView = [_readinessPresenter scrollView];
    NSTextField *readinessSectionLabel = [_readinessPresenter sectionLabel];
    NSButton *inspectorPinButton = [_readinessPresenter pinButton];
    NSRect readinessFrame = (readinessScrollView != nil) ? [readinessScrollView frame] : NSZeroRect;
    NSRect readinessLabelFrame = (readinessSectionLabel != nil) ? [readinessSectionLabel frame] : NSZeroRect;
    NSRect pinFrame = (inspectorPinButton != nil) ? [inspectorPinButton frame] : NSZeroRect;

    BOOL inspectorVisible = (_quadrantView != nil && ![_quadrantView isHidden] && NSWidth(inspectorFrame) > 0.0)
        || (_inspectorGroupBox != nil && ![_inspectorGroupBox isHidden] && NSWidth(inspectorGroupFrame) > 0.0);
    BOOL readinessVisible = (readinessScrollView != nil && ![readinessScrollView isHidden] && NSWidth(readinessFrame) > 0.0);
    BOOL pinVisible = (inspectorPinButton != nil && ![inspectorPinButton isHidden]);
    CGFloat rootMaxX = NSMaxX(rootBounds);

    NSMutableDictionary *layoutProbe = [NSMutableDictionary dictionary];
    [layoutProbe setObject:SMChapterProbeRect(rootBounds) forKey:@"rootBounds"];
    [layoutProbe setObject:[NSNumber numberWithDouble:NSWidth(rootBounds)] forKey:@"workspaceWidth"];
    [layoutProbe setObject:SMChapterProbeWidthClassCode(NSWidth(rootBounds)) forKey:@"workspaceWidthClass"];
    [layoutProbe setObject:[NSNumber numberWithBool:inspectorVisible] forKey:@"showInspectorRail"];
    [layoutProbe setObject:[NSNumber numberWithBool:readinessVisible] forKey:@"showReadinessRail"];
    [layoutProbe setObject:[NSNumber numberWithBool:pinVisible] forKey:@"pinVisible"];
    [layoutProbe setObject:[NSNumber numberWithBool:_inspectorRailPinned] forKey:@"pinState"];
    [layoutProbe setObject:SMChapterProbeRect(tableFrame) forKey:@"tableFrame"];
    [layoutProbe setObject:SMChapterProbeRect(inspectorFrame) forKey:@"inspectorFrame"];
    [layoutProbe setObject:SMChapterProbeRect(inspectorGroupFrame) forKey:@"inspectorGroupFrame"];
    [layoutProbe setObject:SMChapterProbeRect(readinessFrame) forKey:@"readinessFrame"];
    [layoutProbe setObject:SMChapterProbeRect(readinessLabelFrame) forKey:@"readinessLabelFrame"];
    [layoutProbe setObject:SMChapterProbeRect(pinFrame) forKey:@"pinFrame"];

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

    NSNumber *cropModeTagValue = [snapshot objectForKey:@"cropModeTag"];
    if ([cropModeTagValue isKindOfClass:[NSNumber class]] && _cropModePopup != nil) {
        NSInteger tagValue = [cropModeTagValue integerValue];
        NSMenuItem *targetItem = [[_cropModePopup menu] itemWithTag:tagValue];
        if (targetItem != nil) {
            [_cropModePopup selectItem:targetItem];
            [self updateChapterCropMode:nil];
        }
    }

    NSInteger rowCount = [self chapterSnapshotRowCount];
    NSNumber *selectedRowValue = [snapshot objectForKey:@"selectedRow"];
    if ([selectedRowValue isKindOfClass:[NSNumber class]]) {
        NSInteger selectedRow = [selectedRowValue integerValue];
        _suppressChapterSelectionJump = YES;
        @try {
            if (selectedRow >= 0 && selectedRow < rowCount) {
                if ([_tableView selectedRow] != selectedRow) {
                    [_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
                }
            } else if (selectedRow < 0 && [_tableView selectedRow] != -1) {
                [_tableView deselectAll:nil];
            }
        } @finally {
            _suppressChapterSelectionJump = NO;
        }
    }

    NSDictionary *tableScrollSnapshot = [snapshot objectForKey:@"tableScroll"];
    SMChapterRestoreScrollSnapshotForScrollView([_tableView enclosingScrollView], tableScrollSnapshot);
    NSDictionary *readinessScrollSnapshot = [snapshot objectForKey:@"readinessScroll"];
    SMChapterRestoreScrollSnapshotForScrollView([_readinessPresenter scrollView], readinessScrollSnapshot);
    [self updateChapterEmptyStatePresentation];
}

- (NSView *)preferredModeFirstResponderView
{
    return _tableView;
}

#pragma mark - Chapter Snapshots

- (void)invalidateChapterSnapshot
{
    [_chapterSnapshot release];
    _chapterSnapshot = nil;
}

- (void)rebuildChapterSnapshot
{
    AppController *appController = appcontroller();
    NSString *packagePath = [appController respondsToSelector:@selector(currentPackagePath)]
        ? [appController currentPackagePath]
        : nil;
    NSDictionary *snapshot = [SlateRuntimeBridge chapterSnapshotForPackagePath:packagePath
                                                                         movie:_playerView.movie
                                                                    hasPackage:_hasPackageContext];
    [_chapterSnapshot release];
    _chapterSnapshot = [snapshot retain];
}

- (NSDictionary *)chapterSnapshot
{
    if (_chapterSnapshot == nil) {
        [self rebuildChapterSnapshot];
    }
    return _chapterSnapshot;
}

- (NSArray *)chapterSnapshotRows
{
    NSArray *rows = [[self chapterSnapshot] objectForKey:SlateChapterSnapshotKeyRows];
    return [rows isKindOfClass:[NSArray class]] ? rows : [NSArray array];
}

- (NSInteger)chapterSnapshotRowCount
{
    return (NSInteger)[[self chapterSnapshotRows] count];
}

- (NSDictionary *)chapterSnapshotRowAtIndex:(NSInteger)rowIndex
{
    NSArray *rows = [self chapterSnapshotRows];
    if (rowIndex < 0
        || rowIndex >= (NSInteger)[rows count]) {
        return nil;
    }

    NSDictionary *row = [rows objectAtIndex:rowIndex];
    return [row isKindOfClass:[NSDictionary class]] ? row : nil;
}

- (NSArray *)chapterInspectorDetailsForSnapshotRow:(NSDictionary *)snapshotRow
{
    if (![snapshotRow isKindOfClass:[NSDictionary class]]) {
        return [NSArray array];
    }

    NSMutableArray *pairs = [NSMutableArray array];
    SMChapterAppendDetailsPairToArray(pairs, @"Title", [snapshotRow objectForKey:SlateChapterSnapshotRowKeyTitle]);
    SMChapterAppendDetailsPairToArray(pairs, @"Media Chapter Time", [snapshotRow objectForKey:SlateChapterSnapshotRowKeyMediaChapterTimecode]);
    SMChapterAppendDetailsPairToArray(pairs, @"Media Image Time", [snapshotRow objectForKey:SlateChapterSnapshotRowKeyMediaImageTimecode]);
    SMChapterAppendDetailsPairToArray(pairs, @"Abs. Chapter Time", [snapshotRow objectForKey:SlateChapterSnapshotRowKeyAbsoluteChapterTimecode]);
    SMChapterAppendDetailsPairToArray(pairs, @"Abs. Image Time", [snapshotRow objectForKey:SlateChapterSnapshotRowKeyAbsoluteImageTimecode]);
    SMChapterAppendDetailsPairToArray(pairs, @"Chapter Time Value", [snapshotRow objectForKey:SlateChapterSnapshotRowKeyChapterTimeValue]);
    SMChapterAppendDetailsPairToArray(pairs, @"Image Time Value", [snapshotRow objectForKey:SlateChapterSnapshotRowKeyImageTimeValue]);
    SMChapterAppendDetailsPairToArray(pairs, @"Crop Values", [snapshotRow objectForKey:SlateChapterSnapshotRowKeyCropDisplay]);
    SMChapterAppendDetailsPairToArray(pairs, @"Image Valid", SlateChapterSnapshotRowBool(snapshotRow, SlateChapterSnapshotRowKeyImageValid) ? @"Yes" : @"No");
    SMChapterAppendDetailsPairToArray(pairs, @"Declared Image Path", [snapshotRow objectForKey:SlateChapterSnapshotRowKeyDeclaredImagePath]);
    SMChapterAppendDetailsPairToArray(pairs, @"Resolved Image Path", [snapshotRow objectForKey:SlateChapterSnapshotRowKeyResolvedImagePath]);
    SMChapterAppendDetailsPairToArray(pairs, @"Image Status", [snapshotRow objectForKey:SlateChapterSnapshotRowKeyImageStatus]);
    return pairs;
}

- (NSString *)chapterInspectorDetailsTextForSnapshotRow:(NSDictionary *)snapshotRow
{
    if (![snapshotRow isKindOfClass:[NSDictionary class]]) {
        return @"";
    }

    NSMutableString *details = [NSMutableString stringWithFormat:@"Row: %@ | Chapter ID: %@ | Title: %@\n\n",
                                SlateChapterSnapshotSafeString([snapshotRow objectForKey:SlateChapterSnapshotRowKeyRow]),
                                SlateChapterSnapshotSafeString([snapshotRow objectForKey:SlateChapterSnapshotRowKeyChapterID]),
                                SlateChapterSnapshotSafeString([snapshotRow objectForKey:SlateChapterSnapshotRowKeyTitle])];

    NSArray *pairs = [snapshotRow objectForKey:SlateChapterSnapshotRowKeyDetails];
    if (![pairs isKindOfClass:[NSArray class]]) {
        pairs = [self chapterInspectorDetailsForSnapshotRow:snapshotRow];
    }
    for (NSDictionary *pair in pairs) {
        if (![pair isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        SMChapterAppendDetailsPair(details,
                                   [pair objectForKey:SlateChapterSnapshotDetailKeyKey],
                                   [pair objectForKey:SlateChapterSnapshotDetailKeyValue]);
    }

    return details;
}

- (NSArray *)chapterInspectorDetailRows
{
    return [self chapterSnapshotRows];
}

- (NSArray *)validationObservedChapterRows
{
    return [NSArray arrayWithArray:[self chapterSnapshotRows]];
}

- (NSImage *)chapterImageForSnapshotRow:(NSDictionary *)snapshotRow
{
    NSString *resolvedPath = [snapshotRow objectForKey:SlateChapterSnapshotRowKeyResolvedImagePath];
    if (!SMChapterStringHasContent(resolvedPath)) {
        resolvedPath = [snapshotRow objectForKey:SlateChapterSnapshotRowKeyDeclaredImagePath];
    }

    if (!SMChapterStringHasContent(resolvedPath)) {
        return nil;
    }

    return [[[NSImage alloc] initWithContentsOfFile:resolvedPath] autorelease];
}

- (NSString *)chapterImageStatusForSnapshotRow:(NSDictionary *)snapshotRow
{
    NSString *status = [snapshotRow objectForKey:SlateChapterSnapshotRowKeyImageStatus];
    return SMChapterStringHasContent(status) ? status : @"";
}

- (BOOL)showChapterCropRectStatusForSnapshotRow:(NSDictionary *)snapshotRow
{
    CGFloat top = [[snapshotRow objectForKey:SlateChapterSnapshotRowKeyCropTop] doubleValue];
    CGFloat left = [[snapshotRow objectForKey:SlateChapterSnapshotRowKeyCropLeft] doubleValue];
    CGFloat bottom = [[snapshotRow objectForKey:SlateChapterSnapshotRowKeyCropBottom] doubleValue];
    CGFloat right = [[snapshotRow objectForKey:SlateChapterSnapshotRowKeyCropRight] doubleValue];

    if (!SMChapterStringHasContent([snapshotRow objectForKey:SlateChapterSnapshotRowKeyCropTop])
        || !SMChapterStringHasContent([snapshotRow objectForKey:SlateChapterSnapshotRowKeyCropLeft])
        || !SMChapterStringHasContent([snapshotRow objectForKey:SlateChapterSnapshotRowKeyCropBottom])
        || !SMChapterStringHasContent([snapshotRow objectForKey:SlateChapterSnapshotRowKeyCropRight])) {
        return NO;
    }

    [appcontroller() showChapterCropRectStatusWithTop:top
                                                 left:left
                                               bottom:bottom
                                                right:right
                                              context:nil
                                               suffix:nil
                                              persist:NO];
    return YES;
}

#pragma mark - Chapter Data and Images

- (SMChapterCropMode)selectedChapterCropMode
{
    if (_cropModePopup == nil) {
        return SMChapterCropModeManual;
    }

    NSInteger selectedTag = [_cropModePopup selectedTag];
    if (selectedTag < SMChapterCropModeManual || selectedTag > SMChapterCropModeNone) {
        return SMChapterCropModeManual;
    }

    return (SMChapterCropMode)selectedTag;
}

- (NSArray *)cropDetectionSampleImagesForMovie:(SMMovie *)movie
                                     timeValue:(long long)timeValue
{
    if (movie == nil) {
        return [NSArray array];
    }

    long long originalTimeValue = [movie currentTimeValue];
    NSMutableArray *images = [NSMutableArray array];
    NSInteger offsets[] = { -12, -6, 0, 6, 12 };
    NSUInteger offsetCount = sizeof(offsets) / sizeof(offsets[0]);

    for (NSUInteger index = 0; index < offsetCount; index++) {
        [movie setCurrentTimeValue:(timeValue + offsets[index])];
        NSImage *image = [movie currentFrameImage];
        if (image != nil) {
            [images addObject:image];
        }
    }

    [movie setCurrentTimeValue:originalTimeValue];
    return images;
}

- (void)applyChapterSnapshot:(NSDictionary *)chapterSnapshot
{
    [_rowArray removeAllObjects];
    _hasPackageContext = ([[chapterSnapshot objectForKey:SlateChapterSnapshotKeyHasPackage] boolValue]
                          && [[chapterSnapshot objectForKey:SlateChapterSnapshotKeySchemaVersion] isEqualToString:SlateChapterSnapshotSchemaVersion1]);
    [_quadrantView setImage:nil];
    [self updateChapterControlEnabledStates];

    [_chapterSnapshot release];
    _chapterSnapshot = [chapterSnapshot retain];
    [_tableView reloadData];
    if ([self chapterSnapshotRowCount] > 0) {
        _suppressChapterSelectionJump = YES;
        @try {
            [_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
        } @finally {
            _suppressChapterSelectionJump = NO;
        }
    }
    [self updateChapterEmptyStatePresentation];
    [self updateChapterReadinessPanelPresentation];
}

#pragma mark - Chapter Commands


-(IBAction)deleteAllChapters:(id)sender
{
    #pragma unused (sender)
    NSError         *error;
    NSFileManager   *fm = [NSFileManager defaultManager];

    for (int i = 0;i < [_rowArray count];i++)
    {
        NSDictionary *rowDict = [_rowArray objectAtIndex:i];
        if ([[rowDict objectForKey:SMChapterOwnsImageFileKey] boolValue]) {
            [fm removeItemAtPath:[rowDict objectForKey:KEY_IMAGEFILEPATH] error:&error];
        }
    }

    [_rowArray removeAllObjects];
    [_quadrantView setImage:nil];
    [self invalidateChapterSnapshot];
    [_tableView reloadData];
    [self updateChapterEmptyStatePresentation];
    [self refreshValidationAdaptersAfterMutation];
}
#if 0
-(IBAction)deleteChapter:(id)sender
{
    #pragma unused (sender)
    NSInteger   rowIdx = [_tableView selectedRow];
    NSInteger   rowCnt = [_tableView numberOfRows];

    if (rowIdx == -1 && rowCnt == 1)
        rowIdx = 0;

    if (rowIdx > -1)
    {
        NSError         *error;
        NSFileManager   *fm = [NSFileManager defaultManager];

        NSMutableDictionary *rowDict = [_rowArray objectAtIndex:rowIdx];
        NSString            *oldPath = [rowDict objectForKey:KEY_IMAGEFILEPATH];

        if ([[rowDict objectForKey:SMChapterOwnsImageFileKey] boolValue]) {
            [fm removeItemAtPath:oldPath error:&error];
        }

        [_rowArray removeObjectAtIndex:rowIdx];

        //  reorder the chapters by chapter time value
        NSArray *sortedArray = [self sortRowData];

        [_rowArray removeAllObjects];
        [_rowArray addObjectsFromArray:sortedArray];

        for (int i = 0;i < [_rowArray count];i++)
        {
            rowDict = [_rowArray objectAtIndex:i];

            NSString    *newChapTitle = [NSString stringWithFormat:@"Chapter %i", i + 1];
            NSString    *oldChapTitle = [rowDict objectForKey:KEY_CHAPTITLE];

            if ([oldChapTitle compare:newChapTitle] != NSOrderedSame)
            {
                [rowDict setValue:[NSString stringWithFormat:@"%i", i + 1] forKey:KEY_ID];
                [rowDict setValue:newChapTitle forKey:KEY_CHAPTITLE];

                oldPath = [rowDict objectForKey:KEY_IMAGEFILEPATH];

                NSString    *newPath = [[oldPath stringByDeletingLastPathComponent]stringByAppendingString:[NSString stringWithFormat:@"/CHAPTER_%i.jpg", i + 1]];

                if ([[rowDict objectForKey:SMChapterOwnsImageFileKey] boolValue]) {
                    [fm moveItemAtPath:oldPath toPath:newPath error:&error];
                    [rowDict setValue:newPath forKey:KEY_IMAGEFILEPATH];
                    [rowDict setValue:newPath forKey:SMChapterResolvedImageFilePathKey];
                }
            }
        }

        if (rowCnt == 1)
            [_deleteChapter setEnabled:NO];

        [_tableView reloadData];
    }
}
#endif

-(NSArray *)sortRowData
{
    return ([_rowArray sortedArrayUsingComparator:^NSComparisonResult(id a, id b)
                            {
                                NSDictionary *aa = (NSDictionary *)a;
                                NSDictionary *bb = (NSDictionary *)b;

                                NSString    *aas = [aa valueForKey:KEY_CHAPTIME];
                                NSString    *bbs = [bb valueForKey:KEY_CHAPTIME];

                                long long aatime = [aas longLongValue];
                                long long bbtime = [bbs longLongValue];

                                if (aatime < bbtime)
                                    return (NSOrderedAscending);
                                else if (aatime > bbtime)
                                    return (NSOrderedDescending);
                                return (NSOrderedSame);
                            }]);
}

- (NSInteger)firstInvalidImageRowIndex
{
    NSDictionary *finding = SMChapterCanonicalFindingWithCode([self canonicalValidationFindings],
                                                               SMValidationFindingCodeChaptersChapterImageIsNotMarkedValid);
    if (finding != nil) {
        NSInteger canonicalRowIndex = SMChapterRowIndexFromFindingScope([finding objectForKey:SMValidationFindingKeyScope]);
        if (canonicalRowIndex != NSNotFound) {
            return canonicalRowIndex;
        }
    }

    NSArray *snapshotRows = [self chapterSnapshotRows];
    for (NSInteger index = 0; index < (NSInteger)[snapshotRows count]; index++) {
        NSDictionary *snapshotRow = [snapshotRows objectAtIndex:index];
        if (![snapshotRow isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        if (!SlateChapterSnapshotRowBool(snapshotRow, SlateChapterSnapshotRowKeyImageValid)) {
            return index;
        }
    }

    return NSNotFound;
}

-(BOOL)hasInvalidImageFlags
{
    NSDictionary *finding = SMChapterCanonicalFindingWithCode([self canonicalValidationFindings],
                                                               SMValidationFindingCodeChaptersChapterImageIsNotMarkedValid);
    if (finding == nil) {
        return NO;
    }

    NSInteger invalidRowIndex = [self firstInvalidImageRowIndex];
    NSString *title = [finding objectForKey:SMValidationFindingKeyTitle];
    NSString *evidence = [finding objectForKey:SMValidationFindingKeyEvidence];
    NSString *fallbackEvidence = (invalidRowIndex == NSNotFound)
        ? @"Readiness blocker active (code: chapters.chapter_image_is_not_marked_valid)."
        : [NSString stringWithFormat:@"Readiness blocker active (code: chapters.chapter_image_is_not_marked_valid) at chapter row %ld.", (long)invalidRowIndex + 1];

    NSAlert *alert = [[[NSAlert alloc] init] autorelease];

    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:(SMChapterStringHasContent(title) ? title : @"Chapter image readiness blocker")];
    [alert setInformativeText:(SMChapterStringHasContent(evidence) ? evidence : fallbackEvidence)];
    [alert setAlertStyle:NSCriticalAlertStyle];

    [alert beginSheetModalForWindow:[[self view]window] modalDelegate:self didEndSelector:nil contextInfo:nil];
    return YES;
}

-(IBAction)adjMediaChapterTime:(id)sender
{
    #pragma unused (sender)
    NSInteger   rowIdx = [_tableView selectedRow];

    if (rowIdx > -1)
    {
        NSAlert             *alert;
        NSMutableDictionary *dict;
        long long           timeOffset;
        long long           timeValue = [_playerView.movie currentTimeValue];
        NSString            *timeCode = [self getTimeCodeStringForTimeValue:timeValue];

        if (rowIdx > 0) //  can't move time to before previous Media Image Time
        {
            dict = [_rowArray objectAtIndex:rowIdx - 1];
            timeOffset = SlateChapterSnapshotRowLongLong(dict, KEY_IMAGETIME);

            if (timeValue < timeOffset)
            {
                alert = [[[NSAlert alloc] init] autorelease];

                [alert addButtonWithTitle:@"OK"];
                [alert setMessageText:@"Media Chapter Time is before Previous Media Image Time"];
                [alert setInformativeText:[NSString stringWithFormat:@"Previous Chapter Image Exists at %@", [self getTimeCodeStringForTimeValue:timeOffset]]];
                [alert setAlertStyle:NSCriticalAlertStyle];

                [alert beginSheetModalForWindow:[[self view]window] modalDelegate:self didEndSelector:nil contextInfo:nil];

                return;
            }
        }

        dict = [_rowArray objectAtIndex:rowIdx];
        timeOffset = SlateChapterSnapshotRowLongLong(dict, KEY_IMAGETIME);

        if (timeValue > timeOffset) //  can't move
        {
            alert = [[[NSAlert alloc] init] autorelease];

            [alert addButtonWithTitle:@"OK"];
            [alert setMessageText:@"Media Chapter Time is after Current Media Image Time"];
            [alert setInformativeText:[NSString stringWithFormat:@"Chapter Image exists at Media Image Time %@", [self getTimeCodeStringForTimeValue:timeOffset]]];
            [alert setAlertStyle:NSCriticalAlertStyle];

            [alert beginSheetModalForWindow:[[self view]window] modalDelegate:self didEndSelector:nil contextInfo:nil];

            return;
        }

        [dict setValue:timeCode forKey:KEY_MEDIA_CHAPSMPTE];
        [dict setValue:[NSString stringWithFormat:@"%lld", timeValue] forKey:KEY_CHAPTIME];

        [self invalidateChapterSnapshot];
        [_tableView reloadData];
        [self refreshValidationAdaptersAfterMutation];
    }
}

#if 0
-(IBAction)addChapter:(id)sender
{
    #pragma unused (sender)
    [_imageOffset becomeFirstResponder];

    SMMovie     *movie = _playerView.movie;
    long long   timeValue = [movie currentTimeValue];
    long        timeScale = [movie timeScale];

    NSString    *timeCode = [self getTimeCodeStringForTimeValue:timeValue];
    SMTime      currentTime = [movie currentTime];

    NSMutableDictionary *rowDict;

    for (int i = 0;i < [_rowArray count];i++)
    {
        rowDict = [_rowArray objectAtIndex:i];

        if (timeValue == SlateChapterSnapshotRowLongLong(rowDict, KEY_CHAPTIME))
        {
            NSAlert *alert = [[[NSAlert alloc] init] autorelease];

            [alert addButtonWithTitle:@"OK"];
            [alert setMessageText:@"Non Unique Timecode Value"];
            [alert setInformativeText:[NSString stringWithFormat:@"Chapter Exists At %@", timeCode]];
            [alert setAlertStyle:NSCriticalAlertStyle];

            [alert beginSheetModalForWindow:[[self view]window] modalDelegate:self didEndSelector:nil contextInfo:nil];

            return;
        }
    }

    rowDict = [NSMutableDictionary dictionary];
    [rowDict setValue:[NSNumber numberWithBool:NO] forKey:KEY_ISVALIDIMG];

    //	in movies.json
    [rowDict setValue:[NSString stringWithFormat:@"%i", 1000] forKey:KEY_ID];
    [rowDict setValue:[NSString stringWithFormat:@"Chapter %i", 1000] forKey:KEY_CHAPTITLE];

    [rowDict setValue:timeCode forKey:KEY_MEDIA_CHAPSMPTE];
    [rowDict setValue:[NSString stringWithFormat:@"%lld", timeValue] forKey:KEY_CHAPTIME];

    [rowDict setValue:@"0" forKey:KEY_IMAGETIME];

    double  frameRate = [appcontroller() movieFrameRate];

    [self createImageForRowIdx:1000 rowDict:rowDict timeValue:timeValue + (round(frameRate) * (timeScale / frameRate) * [_imageOffset integerValue])];

    [_rowArray addObject:rowDict];

    //  reorder the chapters by chapter time value
    NSArray *sortedArray = [self sortRowData];

    [_rowArray removeAllObjects];
    [_rowArray addObjectsFromArray:sortedArray];

    for (int i = [_rowArray count] - 1;i > -1;i--)
    {
        rowDict = [_rowArray objectAtIndex:i];

        NSString    *newChapTitle = [NSString stringWithFormat:@"Chapter %i", i + 1];
        NSString    *oldChapTitle = [rowDict objectForKey:KEY_CHAPTITLE];

        if ([oldChapTitle compare:newChapTitle] != NSOrderedSame)
        {
            [rowDict setValue:[NSString stringWithFormat:@"%i", i + 1] forKey:KEY_ID];
            [rowDict setValue:newChapTitle forKey:KEY_CHAPTITLE];

            NSError     *error;
            NSString    *oldPath = [rowDict objectForKey:KEY_IMAGEFILEPATH];

            NSString    *basePath = [oldPath stringByDeletingLastPathComponent];
            NSString    *newPath = [basePath stringByAppendingFormat:@"/CHAPTER_%i.jpg", i + 1];

            [[NSFileManager defaultManager] removeItemAtPath:newPath error:&error];
            [[NSFileManager defaultManager] moveItemAtPath:oldPath toPath:newPath error:&error];

            [rowDict setValue:newPath forKey:KEY_IMAGEFILEPATH];
        }
    }

    [_deleteChapter setEnabled:YES];
    [_tableView reloadData];

    [movie setCurrentTime:currentTime];
}

-(IBAction)addChapters:(id)sender
{
    #pragma unused (sender)
    [_imageOffset becomeFirstResponder];

    dispatch_async(dispatch_get_main_queue(), ^ {

    int	leadinSecs = 0;
    int	leadoutSecs = [_leadoutSecs intValue];
	int	chapCnt = [_chapterCnt intValue];

    if (chapCnt < 1)
        return;

    [self deleteAllChapters:nil];
    [_deleteChapter setEnabled:YES];

    SMMovie     *movie = _playerView.movie;
    long long   timeValue = [movie durationTimeValue];
    long        timeScale = [movie timeScale];

    //  subtract chapter offset
    long long	totalSecs = (timeValue / timeScale) - leadinSecs - leadoutSecs;

    if (totalSecs - 1 < leadinSecs - leadoutSecs)
    {
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];

        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Movie duration is too short to create Chapters"];
        [alert setInformativeText:@"The Movie must be at least eight minutes in length"];
        [alert setAlertStyle:NSCriticalAlertStyle];

        [alert beginSheetModalForWindow:[[self view]window] modalDelegate:self didEndSelector:nil contextInfo:nil];

        return;
    }

	long long	incCnt = 0; //(totalSecs * timeScale) / chapCnt;
    SMTime      currentTime = [movie currentTime];

    for (int i = 0;i < chapCnt;i++)
	{
        NSMutableDictionary *rowDict = [NSMutableDictionary dictionary];

        [rowDict setValue:[NSNumber numberWithBool:NO] forKey:KEY_ISVALIDIMG];

		//	in movies.json
		[rowDict setValue:[NSString stringWithFormat:@"%i", i + 1] forKey:KEY_ID];
        [rowDict setValue:[NSString stringWithFormat:@"Chapter %i", i + 1] forKey:KEY_CHAPTITLE];

        [rowDict setValue:[self getTimeCodeStringForTimeValue:incCnt] forKey:KEY_MEDIA_CHAPSMPTE];
        [rowDict setValue:[NSString stringWithFormat:@"%lld", incCnt] forKey:KEY_CHAPTIME];

        [rowDict setValue:[NSString stringWithFormat:@"%lld", incCnt] forKey:KEY_IMAGETIME];
        //  [rowDict setValue:@"No Crop Value Set" forKey:KEY_CROP];

        double  frameRate = [appcontroller() movieFrameRate];
        [self createImageForRowIdx:i + 1 rowDict:rowDict timeValue:incCnt + (round(frameRate) * (timeScale / frameRate) * [_imageOffset integerValue])];

        [_rowArray addObject:rowDict];

		incCnt += (totalSecs * timeScale) / chapCnt;
    }

    [_tableView reloadData];

    [movie setCurrentTime:currentTime];

    });
}
#endif

-(IBAction)reloadTableSelection:(id)sender
{
    #pragma unused (sender)
    NSNotification *notification = [NSNotification notificationWithName:NSTableViewSelectionDidChangeNotification object:_tableView];
    [self tableViewSelectionDidChange:notification]; }

#pragma mark - Table View

// Delegate hook for custom NSTableColumn cells.
-(id)dataCellForRow:(NSInteger)rowIndex forTable:(NSTableView*)t
{
    #pragma unused (rowIndex, t)
    id dataCell = [[NSButtonCell alloc] init];

    [dataCell setButtonType:NSSwitchButton];
    [dataCell setImagePosition:NSImageOverlaps];
    [dataCell setTitle:@""];

    [dataCell setControlSize:NSSmallControlSize];

	return (dataCell);
}

-(void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	#pragma unused(aNotification)
    NSInteger   rowIdx = [_tableView selectedRow];

    if (rowIdx > -1)
    {
        NSDictionary    *snapshotRow = [self chapterSnapshotRowAtIndex:rowIdx];
        NSImage         *image = [self chapterImageForSnapshotRow:snapshotRow];

        NSString        *imageStatus = [self chapterImageStatusForSnapshotRow:snapshotRow];
        long long imageTime = SlateChapterSnapshotRowLongLong(snapshotRow, SlateChapterSnapshotRowKeyImageTimeValue);
        BOOL jumpToImageTime = [self shouldJumpToImageTimeForChapterSelection];
        if (jumpToImageTime) {
            long long targetTime = imageTime;
            NSString *targetLabel = @"image-time";
            if ([self canJumpToChapterMarkerTime:targetTime markerLabel:targetLabel rowIndex:rowIdx]) {
                [_playerView.movie setCurrentTimeValue:targetTime];
            }
        }

        [_quadrantView setImage:image];
        if (image == nil && SMChapterStringHasContent(imageStatus)) {
            [appcontroller() showStatusMessage:imageStatus persist:NO];
        } else if (image != nil) {
            [self showChapterCropRectStatusForSnapshotRow:snapshotRow];
        }
    }
    else
    {
        [_quadrantView setImage:nil];
    }

    [self updateChapterEmptyStatePresentation];
}

- (void)tableViewColumnDidResize:(NSNotification *)notification
{
    if ([notification object] != _tableView) {
        return;
    }

    [self persistResizableChapterColumnWidths];
}

-(NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    #pragma unused(aTableView)
    return [self chapterSnapshotRowCount];
}

-(id)tableView:(NSTableView *)t objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIdx
{
    #pragma unused(t)
    id              objectValue = nil;
    NSString        *colID = [tableColumn identifier];
	NSDictionary    *snapshotRow = [self chapterSnapshotRowAtIndex:rowIdx];

    if (snapshotRow == nil) return nil;

	if ([colID isEqualToString:SlateChapterSnapshotColumnTitle])
		objectValue = SlateChapterSnapshotRowString(snapshotRow, SlateChapterSnapshotRowKeyTitle);
    else if ([colID isEqualToString:SlateChapterSnapshotColumnMediaChapterTimecode])
        objectValue = SlateChapterSnapshotRowString(snapshotRow, SlateChapterSnapshotRowKeyMediaChapterTimecode);
    else if ([colID isEqualToString:SlateChapterSnapshotColumnMediaImageTimecode])
        objectValue = SlateChapterSnapshotRowString(snapshotRow, SlateChapterSnapshotRowKeyMediaImageTimecode);
    else if ([colID isEqualToString:SlateChapterSnapshotColumnAbsoluteChapterTimecode])
        objectValue = SlateChapterSnapshotRowString(snapshotRow, SlateChapterSnapshotRowKeyAbsoluteChapterTimecode);
    else if ([colID isEqualToString:SlateChapterSnapshotColumnAbsoluteImageTimecode])
        objectValue = SlateChapterSnapshotRowString(snapshotRow, SlateChapterSnapshotRowKeyAbsoluteImageTimecode);
    else if ([colID isEqualToString:SlateChapterSnapshotColumnCrop])
        objectValue = SlateChapterSnapshotRowString(snapshotRow, SlateChapterSnapshotRowKeyCropDisplay);
    else if ([colID isEqualToString:SlateChapterSnapshotColumnImageFilePath])
        objectValue = [self chapterImageForSnapshotRow:snapshotRow];
    else if ([colID isEqualToString:SlateChapterSnapshotColumnImageValid])
        objectValue = [NSNumber numberWithBool:SlateChapterSnapshotRowBool(snapshotRow, SlateChapterSnapshotRowKeyImageValid)];

    return (objectValue);
}

#pragma mark - Image Capture

-(NSString *)getLocalImageFullPath:(NSInteger)rowIdx
{
    NSFileManager       *fm = [NSFileManager defaultManager];
    NSString            *title = [[_playerView.movie attributeForKey:SMMovieDisplayNameAttribute]stringByDeletingPathExtension];
    NSURL               *dirPath =
    [[[fm URLsForDirectory:NSPicturesDirectory inDomains:NSUserDomainMask] objectAtIndex:0] URLByAppendingPathComponent:title];

    if (![fm fileExistsAtPath:[dirPath path]])
    {
        NSError *error = nil;
        [[NSFileManager defaultManager]
                   createDirectoryAtPath:[dirPath path] withIntermediateDirectories:NO attributes:nil error:&error];
    }
    return ([NSString stringWithFormat:@"%@/CHAPTER_%ld.jpg", [dirPath path], (long)rowIdx]);
}

-(void)createImageForRowIdx:(NSInteger)rowIdx rowDict:(NSMutableDictionary *)rowDict timeValue:(long long)timeValue
{
    [_playerView.movie setCurrentTimeValue:timeValue];

    [rowDict setValue:[NSNumber numberWithBool:NO] forKey:KEY_ISVALIDIMG];
    [rowDict setValue:[self getTimeCodeStringForTimeValue:timeValue] forKey:KEY_MEDIA_IMGSMPTE];
    [rowDict setValue:[NSString stringWithFormat:@"%lld", timeValue] forKey:KEY_IMAGETIME];

    NSSize  naturalSize = [[[appcontroller() movie] attributeForKey:SMMovieNaturalSizeAttribute] sizeValue];
    SMMovie *movie = [appcontroller() movie];
    SMCropMargins margins = SMCropMarginsZero();
    NSString *cropModeLabel = @"Manual";
    SMChapterCropMode cropMode = [self selectedChapterCropMode];

    if (cropMode == SMChapterCropModeManual && _playerView.cropLayer) {
        margins = SMCropMarginsSnapToEven([_playerView sourceCropMarginsFromOverlay], NSSizeToCGSize(naturalSize));
    } else if (cropMode == SMChapterCropModeConservativeAuto) {
        NSArray *sampleImages = [self cropDetectionSampleImagesForMovie:movie timeValue:timeValue];
        SMCropDetectionResult detection = SMCropDetectorConservativeBlackBorderDetectionForImagesDefault(sampleImages,
                                                                                                               NSSizeToCGSize(naturalSize));
        if (detection.hasDetection) {
            margins = detection.margins;
            cropModeLabel = [NSString stringWithFormat:@"Conservative Auto %.0f%%", detection.confidence * 100.0f];
        } else {
            cropModeLabel = @"Conservative Auto 0%";
        }
    } else if (cropMode == SMChapterCropModeNone) {
        cropModeLabel = @"None";
    }

    [movie setCurrentTimeValue:timeValue];

    CGRect cropRect = SMCropRectFromMargins(margins, NSSizeToCGSize(naturalSize));
    CGRect statusRect = CGRectMake(margins.left, margins.top, margins.right, margins.bottom);

    [rowDict setValue:[NSString stringWithFormat:@"%.0f", statusRect.origin.x] forKey:KEY_CROPLEFT];
    [rowDict setValue:[NSString stringWithFormat:@"%.0f", statusRect.origin.y] forKey:KEY_CROPTOP];
    [rowDict setValue:[NSString stringWithFormat:@"%.0f", statusRect.size.width] forKey:KEY_CROPRIGHT];
    [rowDict setValue:[NSString stringWithFormat:@"%.0f", statusRect.size.height] forKey:KEY_CROPBTM];

    NSImage *normalizedImage = SMCropDetectorResizedImage([movie currentFrameImage], naturalSize);
    NSImage *cropped = SMChapterImageFromRect(normalizedImage, cropRect);

    NSString *scaleString = nil;
    NSImage *scaled = SMChapterRescaledImage(cropped, &scaleString);

    NSBitmapImageRep    *bmp = [[NSBitmapImageRep alloc]initWithData:[scaled TIFFRepresentation]];
    [scaled addRepresentation:bmp];

    NSData      *data = [bmp representationUsingType:NSJPEGFileType properties:@{}];
    NSString    *path = [self getLocalImageFullPath:rowIdx];

    [rowDict setValue:path forKey:KEY_IMAGEFILEPATH];
    [rowDict setValue:path forKey:SMChapterResolvedImageFilePathKey];
    [rowDict setValue:[NSNumber numberWithBool:YES] forKey:SMChapterOwnsImageFileKey];
    [rowDict setValue:@"Declared chapter image path status: exists" forKey:SMChapterImageStatusKey];
    [data writeToFile:path atomically:YES];

    [appcontroller() showChapterCropRectStatusWithTop:statusRect.origin.y
                                                   left:statusRect.origin.x
                                                 bottom:statusRect.size.height
                                                  right:statusRect.size.width
                                                context:[NSString stringWithFormat:@"%@ chapter crop rect", cropModeLabel]
                                                suffix:scaleString
                                                persist:NO];

    [self invalidateChapterSnapshot];
    [_tableView reloadData];
    [self refreshValidationAdaptersAfterMutation];
}

-(IBAction)grabChapterImage:(id)sender
{
    #pragma unused (sender)
    [self becomeFirstResponder];

    if ([_tableView selectedRow] > -1)
    {
        BOOL                isLessThanNextRow = YES;
        long long           thisTimeValue = [_playerView.movie currentTimeValue];
        NSInteger           thisRowIdx = [_tableView selectedRow];
        NSMutableDictionary *thisRowDict = [_rowArray objectAtIndex:thisRowIdx];

        if ([_rowArray count] > thisRowIdx + 1)
        {
            NSDictionary    *nextRowDict = [_rowArray objectAtIndex:thisRowIdx + 1];
            long long       nextTimeValue = SlateChapterSnapshotRowLongLong(nextRowDict, KEY_CHAPTIME);

            if (thisTimeValue >= nextTimeValue)
                isLessThanNextRow = NO;
        }

        if (thisTimeValue >= SlateChapterSnapshotRowLongLong(thisRowDict, KEY_CHAPTIME) && isLessThanNextRow)
        {
            [self createImageForRowIdx:thisRowIdx + 1 rowDict:thisRowDict timeValue:thisTimeValue];

            if (_quadrantView)
                [_quadrantView setImage:[self chapterImageForSnapshotRow:[self chapterSnapshotRowAtIndex:thisRowIdx]]];
        }
        else
        {
            NSAlert *alert = [[[NSAlert alloc] init] autorelease];

            [alert addButtonWithTitle:@"OK"];

            if (isLessThanNextRow)
            {
                [alert setMessageText:@"Image Time Before Current Chapter Time"];
                [appcontroller() showStatusMessage:@"Can't grab image for this Chapter before this Chapter's start time" persist:NO];
            }
            else
            {
                [alert setMessageText:@"Image Time After Next Chapter Time"];
                [appcontroller() showStatusMessage:@"Can't grab image for this Chapter after next Chapter's start time" persist:NO];
            }

            [alert setAlertStyle:NSCriticalAlertStyle];

            [alert beginSheetModalForWindow:[[self view]window] modalDelegate:self didEndSelector:nil contextInfo:nil];
        }
    }
    else
        [appcontroller() showStatusMessage:@"No Chapter Selected" persist:NO];
}

-(IBAction)updateChapterCropMode:(id)sender
{
    #pragma unused(sender)
}

#pragma mark - Timecode Utilities

-(NSString *)getTimeCodeStringForTimeValue:(long long)timeValue
{
    return [_playerView.movie timeCodeStringForTimeValue:timeValue];
}

#pragma mark - NIB Compatibility and Teardown

-(void)awakeFromNib
{
    [self initializeChapterControllerDataIfNeeded];
    [self applyChapterScanabilityMetrics];
    [self updateChapterReadinessPanelPresentation];
    [self applyWorkspaceLayoutForWidth:NSWidth([[self view] bounds])];
    [super awakeFromNib];
}

-(void) dealloc
{
    [self stopObservingAppHasMovieIfNeeded];

    [_tableSectionLabel release];
    [_inspectorSectionLabel release];
    [_advancedSectionLabel release];
    [_readinessPresenter release];
    [_inspectorGroupBox release];
    [_tableEmptyStateLabel release];
    [_inspectorEmptyStateLabel release];
    [_leadoutLabel release];
    [_canonicalValidationFindings release];
    [_chapterSnapshot release];
	[_rowArray release];

    [super dealloc];
}

@end
