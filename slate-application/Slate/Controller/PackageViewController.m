//
//  PackageViewController.m
//  Slate
//
//  Created by Jerry Hale on 3/20/26
//  Copyright (c) 2026 Jerry Hale All rights reserved.


#import "PosterArtView.h"
#import "Runtime/SlatePackageSnapshotContract.h"
#import "Runtime/SlateReviewSnapshotContract.h"
#import "Runtime/SlateRuntimeBridge.h"
#import "Validation/SMValidationCanonicalDictionaryKeys.h"
#import "UtilInspectorRailContract.h"
#import "UtilLayoutMetrics.h"
#import "UtilReadinessRailPresenter.h"

#import "PackageViewController.h"
#include <math.h>

#pragma mark - Local Helpers

// Thin adapter: package dictionaries come in, fixed rails go out.
static BOOL SMPackStringHasContent(NSString *value)
{
    if (![value isKindOfClass:[NSString class]]) {
        return NO;
    }

    return [[value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] > 0;
}

static NSDictionary *SMPackageDictionaryValue(id value)
{
    return [value isKindOfClass:[NSDictionary class]] ? value : [NSDictionary dictionary];
}

static NSString *SlatePackageSnapshotStringForKey(NSDictionary *dictionary, NSString *key)
{
    id value = [dictionary objectForKey:key];
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

static BOOL SMPackageCodeContainsToken(NSString *code, NSString *token)
{
    return (SMPackStringHasContent(code)
            && SMPackStringHasContent(token)
            && [code rangeOfString:token].location != NSNotFound);
}

static NSString *SMPackageReadinessJumpTargetForFinding(NSDictionary *finding)
{
    if (![finding isKindOfClass:[NSDictionary class]]) {
        return SlatePackageSnapshotTargetType;
    }

    NSString *scope = [[finding objectForKey:SMValidationFindingKeyScope] lowercaseString];
    if ([scope hasPrefix:@"platform-row:"]) {
        return SlatePackageSnapshotTargetPlatforms;
    }
    if ([scope hasPrefix:@"locale-row:"]) {
        return SlatePackageSnapshotTargetLocales;
    }
    if ([scope hasPrefix:@"chapter-row:"]) {
        return SlatePackageSnapshotTargetChapters;
    }
    if ([scope hasPrefix:@"genre-row:"]) {
        return SlatePackageSnapshotTargetGenres;
    }

    NSString *code = [[finding objectForKey:SMValidationFindingKeyCode] lowercaseString];
    if (SMPackageCodeContainsToken(code, @"short_synopsis")) {
        return SlatePackageSnapshotTargetSynopsisShort;
    }
    if (SMPackageCodeContainsToken(code, @"long_synopsis")) {
        return SlatePackageSnapshotTargetSynopsisLong;
    }
    if (SMPackageCodeContainsToken(code, @"poster_art")) {
        return SlatePackageSnapshotTargetPoster;
    }
    if (SMPackageCodeContainsToken(code, @"vendor")) {
        return SlatePackageSnapshotTargetVendor;
    }
    if (SMPackageCodeContainsToken(code, @"media_type")) {
        return SlatePackageSnapshotTargetMediaType;
    }
    if (SMPackageCodeContainsToken(code, @"release") || SMPackageCodeContainsToken(code, @"theatrical")) {
        return SlatePackageSnapshotTargetReleaseDate;
    }
    if (SMPackageCodeContainsToken(code, @"rating_system")) {
        return SlatePackageSnapshotTargetRatingSystem;
    }
    if (SMPackageCodeContainsToken(code, @"rating")) {
        return SlatePackageSnapshotTargetRating;
    }
    if (SMPackageCodeContainsToken(code, @"chapter")) {
        return SlatePackageSnapshotTargetChapters;
    }
    if (SMPackageCodeContainsToken(code, @"locale") || SMPackageCodeContainsToken(code, @"language")) {
        return SlatePackageSnapshotTargetLocales;
    }
    if (SMPackageCodeContainsToken(code, @"platform")) {
        return SlatePackageSnapshotTargetPlatforms;
    }
    if (SMPackageCodeContainsToken(code, @"genre")) {
        return SlatePackageSnapshotTargetGenres;
    }
    if (SMPackageCodeContainsToken(code, @"cast")) {
        return SlatePackageSnapshotTargetCast;
    }
    if (SMPackageCodeContainsToken(code, @"crew") || SMPackageCodeContainsToken(code, @"production_company")) {
        return SlatePackageSnapshotTargetCrew;
    }
    if (SMPackageCodeContainsToken(code, @"name") || SMPackageCodeContainsToken(code, @"title")) {
        return SlatePackageSnapshotTargetName;
    }
    if (SMPackageCodeContainsToken(code, @"type")) {
        return SlatePackageSnapshotTargetType;
    }

    return SlatePackageSnapshotTargetType;
}

typedef NS_ENUM(NSInteger, SMPackageRailMode) {
    SMPackageRailModeCompact = 0,
    SMPackageRailModeExpanded = 1,
};

#pragma mark - Layout Constants

static const CGFloat SMPackageWorkspaceExpandedBreakpoint = 900.0;

static const CGFloat SMPackageSynopsisScrollStep = 10.0;
static const CGFloat SMPackagePanelLabelFontSize = 12.0;

static const CGFloat SMPackageScalarLabelX = 10.0;
static const CGFloat SMPackageScalarLabelWidth = 94.0;
static const CGFloat SMPackageScalarLabelHeight = 15.0;
static const CGFloat SMPackageScalarValueX = 104.0;
static const CGFloat SMPackageScalarValueWidth = 161.0;
static const CGFloat SMPackageScalarValueHeight = 17.0;
static const CGFloat SMPackageScalarValueCenterX = SMPackageScalarValueX + (SMPackageScalarValueWidth * 0.5);
static const CGFloat SMPackageTypeLabelY = 305.0;
static const CGFloat SMPackageTypeValueY = 307.0;
static const CGFloat SMPackageNameLabelY = 281.0;
static const CGFloat SMPackageNameValueY = 283.0;
static const CGFloat SMPackageVendorLabelY = 257.0;
static const CGFloat SMPackageVendorValueY = 259.0;
static const CGFloat SMPackageMediaTypeLabelY = 233.0;
static const CGFloat SMPackageMediaTypeValueY = 235.0;
static const CGFloat SMPackageReleaseDateLabelY = 208.0;
static const CGFloat SMPackageReleaseDateValueY = 210.0;
static const CGFloat SMPackageRatingSystemLabelY = 184.0;
static const CGFloat SMPackageRatingSystemValueY = 186.0;
static const CGFloat SMPackageRatingLabelY = 160.0;
static const CGFloat SMPackageRatingValueY = 162.0;
static const CGFloat SMPackagePosterArtLabelWidth = 61.0;
static const CGFloat SMPackagePosterArtViewWidth = 96.0;
static const CGFloat SMPackagePosterArtViewHeight = 96.0;
static const CGFloat SMPackagePosterArtLabelY = 125.0;
static const CGFloat SMPackagePosterArtViewY = 21.0;
static const CGFloat SMPackageAssetStackDownshift = 6.0;

static const CGFloat SMPackageMiddleRailExtraGap = 4.0;
static const CGFloat SMPackageCompactPinnedContentRailMinimumWidth = 480.0;
static const CGFloat SMPackageContentRailMinimumWidth = 520.0;
static const CGFloat SMPackageMetadataPanelLabelHeight = 16.0;
static const CGFloat SMPackageMetadataPanelLabelGap = 4.0;
static const CGFloat SMPackageMetadataMatrixVerticalInset = 5.0;
static const CGFloat SMPackageMetadataMinimumWidth = 220.0;
static const CGFloat SMPackageMetadataSingleColumnThreshold = 170.0;
static const CGFloat SMPackageMetadataColumnMinimumWidth = 160.0;
static const CGFloat SMPackageSynopsisInterRowGapMinimum = 8.0;
static const CGFloat SMPackageSynopsisMinimumWidth = 150.0;
static const CGFloat SMPackageLongSynopsisExtraDrop = 10.0;
static const CGFloat SMPackageReadinessTextRatio = 0.68;
static const CGFloat SMPackageMetadataGroupHeaderInsetX = 10.0;
static const CGFloat SMPackageMetadataGroupHeaderTopInset = 6.0;

static NSString * const SMPackageSectionTitleMetadata = @"Metadata";
static NSString * const SMPackageSectionTitleReadiness = @"Readiness";
static NSString * const SMPackageReadinessStatusNoPackageLoaded = @"No package loaded";
static NSString * const SMPackageReadinessStatusNoFindings = @"No package/metadata findings";
static NSString * const SMPackageReadinessEmptyMessageNoFindings = @"No package/metadata readiness findings.";
static NSString * const SMPackageReadinessFindingsToolTipTitle = @"Readiness findings (package + metadata)";

static SMPackageRailMode SMPackageRailModeForWidth(CGFloat workspaceWidth)
{
    if (workspaceWidth >= SMPackageWorkspaceExpandedBreakpoint) {
        return SMPackageRailModeExpanded;
    }
    return SMPackageRailModeCompact;
}

static NSString * const SMPackageInspectorRailPinnedDefaultsKey = @"SMPackageInspectorRailPinned";
static NSString * const SMPackageMetadataPanelKeyTarget = @"target";
static NSString * const SMPackageMetadataPanelKeySnapshot = @"snapshot";
static NSString * const SMPackageMetadataPanelKeyTextView = @"textView";
static NSString * const SMPackageMetadataPanelKeyScrollView = @"scrollView";
static NSString * const SMPackageMetadataPanelKeyLabel = @"label";
static NSString * const SMPackageMetadataPanelKeyLabelText = @"labelText";
static NSString * const SMPackageSynopsisPanelKeyLabel = @"label";
static NSString * const SMPackageSynopsisPanelKeyLabelFrame = @"labelFrame";
static NSString * const SMPackageSynopsisPanelKeyScrollFrame = @"scrollFrame";

static CGFloat SMPackageResponsiveOuterMargin(void) { return 16.0; }
static CGFloat SMPackageResponsiveColumnGap(void) { return 10.0; }
static CGFloat SMPackageSynopsisStackXOffset(void) { return -10.0; }
static CGFloat SMPackageMetadataMatrixXOffset(void) { return -3.0; }
static NSRect SMPackageDefaultRootFrame(void) { return NSMakeRect(0.0, 0.0, 1280.0, 360.0); }

#pragma mark - Panel Specs

static NSArray *SMPackageSynopsisPanelSpecs(void)
{
    static NSArray *specs = nil;
    if (specs == nil) {
        specs = [[NSArray alloc] initWithObjects:
                 [NSDictionary dictionaryWithObjectsAndKeys:
                  SlatePackageSnapshotTargetSynopsisShort, SMPackageMetadataPanelKeyTarget,
                  @"shortSynopsisScroll", SMPackageMetadataPanelKeySnapshot,
                  @"Short Synopsis:", SMPackageSynopsisPanelKeyLabel,
                  NSStringFromRect(NSMakeRect(268.0, 308.0, 120.0, 15.0)), SMPackageSynopsisPanelKeyLabelFrame,
                  NSStringFromRect(NSMakeRect(270.0, 173.0, 153.0, 130.0)), SMPackageSynopsisPanelKeyScrollFrame,
                  nil],
                 [NSDictionary dictionaryWithObjectsAndKeys:
                  SlatePackageSnapshotTargetSynopsisLong, SMPackageMetadataPanelKeyTarget,
                  @"longSynopsisScroll", SMPackageMetadataPanelKeySnapshot,
                  @"Long Synopsis:", SMPackageSynopsisPanelKeyLabel,
                  NSStringFromRect(NSMakeRect(268.0, 155.0, 120.0, 15.0)), SMPackageSynopsisPanelKeyLabelFrame,
                  NSStringFromRect(NSMakeRect(270.0, 17.0, 151.0, 130.0)), SMPackageSynopsisPanelKeyScrollFrame,
                  nil],
                 nil];
    }
    return specs;
}

static NSArray *SMPackageMetadataPanelSpecs(void)
{
    static NSArray *specs = nil;
    if (specs == nil) {
        specs = [[NSArray alloc] initWithObjects:
                 [NSDictionary dictionaryWithObjectsAndKeys:SlatePackageSnapshotTargetLocales, SMPackageMetadataPanelKeyTarget, @"localeScroll", SMPackageMetadataPanelKeySnapshot, @"Locale", SMPackageMetadataPanelKeyLabelText, nil],
                 [NSDictionary dictionaryWithObjectsAndKeys:SlatePackageSnapshotTargetChapters, SMPackageMetadataPanelKeyTarget, @"chapterScroll", SMPackageMetadataPanelKeySnapshot, @"Chapter", SMPackageMetadataPanelKeyLabelText, nil],
                 [NSDictionary dictionaryWithObjectsAndKeys:SlatePackageSnapshotTargetPlatforms, SMPackageMetadataPanelKeyTarget, @"platformScroll", SMPackageMetadataPanelKeySnapshot, @"Platform", SMPackageMetadataPanelKeyLabelText, nil],
                 [NSDictionary dictionaryWithObjectsAndKeys:SlatePackageSnapshotTargetGenres, SMPackageMetadataPanelKeyTarget, @"genreScroll", SMPackageMetadataPanelKeySnapshot, @"Genre", SMPackageMetadataPanelKeyLabelText, nil],
                 [NSDictionary dictionaryWithObjectsAndKeys:SlatePackageSnapshotTargetCast, SMPackageMetadataPanelKeyTarget, @"castScroll", SMPackageMetadataPanelKeySnapshot, @"Cast", SMPackageMetadataPanelKeyLabelText, nil],
                 [NSDictionary dictionaryWithObjectsAndKeys:SlatePackageSnapshotTargetCrew, SMPackageMetadataPanelKeyTarget, @"crewScroll", SMPackageMetadataPanelKeySnapshot, @"Crew", SMPackageMetadataPanelKeyLabelText, nil],
                 nil];
    }
    return specs;
}

static NSDictionary *SMPackageSynopsisSpecForTarget(NSString *target)
{
    if (![target isKindOfClass:[NSString class]]) {
        return nil;
    }

    for (NSDictionary *spec in SMPackageSynopsisPanelSpecs()) {
        NSString *specTarget = [spec objectForKey:SMPackageMetadataPanelKeyTarget];
        if ([specTarget isEqualToString:target]) {
            return spec;
        }
    }

    return nil;
}

#pragma mark - Snapshot Helpers

static NSDictionary *SMPackageScrollSnapshotForScrollView(NSScrollView *scrollView)
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

static void SMPackageRestoreScrollSnapshotForScrollView(NSScrollView *scrollView, NSDictionary *snapshot)
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

static NSDictionary *SMPackageProbeRect(NSRect rect)
{
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithDouble:rect.origin.x], @"x",
            [NSNumber numberWithDouble:rect.origin.y], @"y",
            [NSNumber numberWithDouble:rect.size.width], @"w",
            [NSNumber numberWithDouble:rect.size.height], @"h",
            nil];
}

static NSString *SMPackageProbeRailModeCode(CGFloat workspaceWidth)
{
    switch (SMPackageRailModeForWidth(workspaceWidth))
    {
        case SMPackageRailModeExpanded:
            return @"1";
        case SMPackageRailModeCompact:
        default:
            return @"0";
    }
}

static NSString *SMPackageProbeRailModeName(CGFloat workspaceWidth)
{
    return (SMPackageRailModeForWidth(workspaceWidth) == SMPackageRailModeExpanded) ? @"expanded" : @"compact";
}

#pragma mark - Private Interface

@interface PackageViewController ()
- (void)buildPackageViewHierarchyIfNeeded;
- (void)initializePackageControllerDataIfNeeded;
- (NSTextField *)newPackageScalarLabelWithTitle:(NSString *)title frame:(NSRect)frame;
- (NSTextField *)newPackageScalarValueFieldWithFrame:(NSRect)frame;
- (PosterArtView *)newPackagePosterArtViewWithFrame:(NSRect)frame;
- (NSTextField *)packageStaticLabelWithExactTitle:(NSString *)title;
- (void)alignPosterArtLaneToScalarValueCenter;
- (void)alignPosterArtLaneBottomToLongSynopsisFrame:(NSRect)longSynopsisFrame;
- (void)positionPackageScalarLabelWithTitle:(NSString *)title baselineY:(CGFloat)baselineY verticalOffset:(CGFloat)verticalOffset;
- (void)positionPackageScalarValueField:(NSTextField *)field baselineY:(CGFloat)baselineY verticalOffset:(CGFloat)verticalOffset;
- (void)applyAssetStackHorizontalOffset:(CGFloat)horizontalOffset;
- (void)applyAssetStackVerticalOffset:(CGFloat)verticalOffset;
@end

@implementation PackageViewController

#pragma mark - Lifecycle and Root View

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        [self initializePackageControllerDataIfNeeded];
    }
    return self;
}

- (void)loadView
{
    [self buildPackageViewHierarchyIfNeeded];
    [self initializePackageControllerDataIfNeeded];
    [self ensureCodeOwnedSynopsisViews];
    [self ensureCodeOwnedMetadataCollectionViews];
    [self applyPackageScanabilityMetrics];
    [self alignPosterArtLaneToScalarValueCenter];
    [self updateReadinessPanelPresentation];
    [self applyWorkspaceLayoutForWidth:NSWidth([[self view] bounds])];
}

- (void)initializePackageControllerDataIfNeeded
{
    if (_didInitializePackageControllerData) {
        return;
    }

    _inspectorRailPinned = [[NSUserDefaults standardUserDefaults] boolForKey:SMPackageInspectorRailPinnedDefaultsKey];
    _hasPackageContext = NO;
    _didInitializePackageControllerData = YES;
}

#pragma mark - Asset Stack

- (NSTextField *)newPackageScalarLabelWithTitle:(NSString *)title frame:(NSRect)frame
{
    NSTextField *label = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [label setEditable:NO];
    [label setBordered:NO];
    [label setDrawsBackground:NO];
    [label setSelectable:NO];
    [label setBezeled:NO];
    [label setFocusRingType:NSFocusRingTypeNone];
    [label setAlignment:NSTextAlignmentRight];
    [label setFont:[NSFont systemFontOfSize:[NSFont systemFontSize]]];
    [label setTextColor:[NSColor controlTextColor]];
    [label setEnabled:NO];
    [label setLineBreakMode:NSLineBreakByClipping];
    [label setStringValue:(title ?: @"")];
    [label setTranslatesAutoresizingMaskIntoConstraints:YES];
    [label setAutoresizingMask:NSViewNotSizable];
    return label;
}

- (NSTextField *)newPackageScalarValueFieldWithFrame:(NSRect)frame
{
    NSTextField *field = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [field setEditable:YES];
    [field setSelectable:YES];
    [field setBordered:YES];
    [field setBezeled:YES];
    [field setDrawsBackground:YES];
    [field setAlignment:NSTextAlignmentLeft];
    [field setFocusRingType:NSFocusRingTypeNone];
    [field setFont:[NSFont systemFontOfSize:[NSFont systemFontSize]]];
    [field setTextColor:[NSColor controlTextColor]];
    [field setBackgroundColor:[NSColor textBackgroundColor]];
    [field setTranslatesAutoresizingMaskIntoConstraints:YES];
    [field setAutoresizingMask:NSViewNotSizable];
    return field;
}

- (PosterArtView *)newPackagePosterArtViewWithFrame:(NSRect)frame
{
    PosterArtView *posterView = [[[PosterArtView alloc] initWithFrame:frame] autorelease];
    [posterView setImageScaling:NSImageScaleProportionallyDown];
    [posterView setImageAlignment:NSImageAlignLeft];
    [posterView setEditable:NO];
    [posterView setTranslatesAutoresizingMaskIntoConstraints:YES];
    [posterView setAutoresizingMask:NSViewNotSizable];
    [posterView setWantsLayer:YES];
    [[posterView layer] setBorderWidth:1.0];
    [[posterView layer] setBorderColor:[[NSColor separatorColor] CGColor]];
    [posterView initWindowCnt];
    return posterView;
}

- (void)buildPackageViewHierarchyIfNeeded
{
    if ([self isViewLoaded] && _typeField != nil && _posterArtView != nil) {
        return;
    }

    NSView *rootView = [[[NSView alloc] initWithFrame:SMPackageDefaultRootFrame()] autorelease];
    [rootView setHidden:YES];
    [rootView setWantsLayer:YES];
    [rootView setFocusRingType:NSFocusRingTypeNone];
    [rootView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];

    [rootView addSubview:[self newPackageScalarLabelWithTitle:@"Type:"
                                                        frame:NSMakeRect(SMPackageScalarLabelX, SMPackageTypeLabelY, SMPackageScalarLabelWidth, SMPackageScalarLabelHeight)]];
    _typeField = [self newPackageScalarValueFieldWithFrame:NSMakeRect(SMPackageScalarValueX, SMPackageTypeValueY, SMPackageScalarValueWidth, SMPackageScalarValueHeight)];
    [rootView addSubview:_typeField];

    [rootView addSubview:[self newPackageScalarLabelWithTitle:@"Name:"
                                                        frame:NSMakeRect(SMPackageScalarLabelX, SMPackageNameLabelY, SMPackageScalarLabelWidth, SMPackageScalarLabelHeight)]];
    _name = [self newPackageScalarValueFieldWithFrame:NSMakeRect(SMPackageScalarValueX, SMPackageNameValueY, SMPackageScalarValueWidth, SMPackageScalarValueHeight)];
    [rootView addSubview:_name];

    [rootView addSubview:[self newPackageScalarLabelWithTitle:@"Vendor ID:"
                                                        frame:NSMakeRect(SMPackageScalarLabelX, SMPackageVendorLabelY, SMPackageScalarLabelWidth, SMPackageScalarLabelHeight)]];
    _vendorid = [self newPackageScalarValueFieldWithFrame:NSMakeRect(SMPackageScalarValueX, SMPackageVendorValueY, SMPackageScalarValueWidth, SMPackageScalarValueHeight)];
    [rootView addSubview:_vendorid];

    [rootView addSubview:[self newPackageScalarLabelWithTitle:@"Media Type:"
                                                        frame:NSMakeRect(SMPackageScalarLabelX, SMPackageMediaTypeLabelY, SMPackageScalarLabelWidth, SMPackageScalarLabelHeight)]];
    _mediaType = [self newPackageScalarValueFieldWithFrame:NSMakeRect(SMPackageScalarValueX, SMPackageMediaTypeValueY, SMPackageScalarValueWidth, SMPackageScalarValueHeight)];
    [rootView addSubview:_mediaType];

    [rootView addSubview:[self newPackageScalarLabelWithTitle:@"Release Date:"
                                                        frame:NSMakeRect(SMPackageScalarLabelX, SMPackageReleaseDateLabelY, SMPackageScalarLabelWidth, SMPackageScalarLabelHeight)]];
    _releaseDate = [self newPackageScalarValueFieldWithFrame:NSMakeRect(SMPackageScalarValueX, SMPackageReleaseDateValueY, SMPackageScalarValueWidth, SMPackageScalarValueHeight)];
    [rootView addSubview:_releaseDate];

    [rootView addSubview:[self newPackageScalarLabelWithTitle:@"Rating System:"
                                                        frame:NSMakeRect(SMPackageScalarLabelX, SMPackageRatingSystemLabelY, SMPackageScalarLabelWidth, SMPackageScalarLabelHeight)]];
    _ratingSystem = [self newPackageScalarValueFieldWithFrame:NSMakeRect(SMPackageScalarValueX, SMPackageRatingSystemValueY, SMPackageScalarValueWidth, SMPackageScalarValueHeight)];
    [rootView addSubview:_ratingSystem];

    [rootView addSubview:[self newPackageScalarLabelWithTitle:@"Rating:"
                                                        frame:NSMakeRect(SMPackageScalarLabelX, SMPackageRatingLabelY, SMPackageScalarLabelWidth, SMPackageScalarLabelHeight)]];
    _rating = [self newPackageScalarValueFieldWithFrame:NSMakeRect(SMPackageScalarValueX, SMPackageRatingValueY, SMPackageScalarValueWidth, SMPackageScalarValueHeight)];
    [rootView addSubview:_rating];

    [rootView addSubview:[self newPackageScalarLabelWithTitle:@"Poster Art:"
                                                        frame:NSMakeRect(floor(SMPackageScalarValueCenterX - (SMPackagePosterArtLabelWidth * 0.5)),
                                                                         SMPackagePosterArtLabelY,
                                                                         SMPackagePosterArtLabelWidth,
                                                                         SMPackageScalarLabelHeight)]];
    _posterArtView = [self newPackagePosterArtViewWithFrame:NSMakeRect(floor(SMPackageScalarValueCenterX - (SMPackagePosterArtViewWidth * 0.5)),
                                                                       SMPackagePosterArtViewY,
                                                                       SMPackagePosterArtViewWidth,
                                                                       SMPackagePosterArtViewHeight)];
    [rootView addSubview:_posterArtView];

    [self setView:rootView];
}

#pragma mark - Validation

- (void)applyCanonicalValidationFindings:(NSArray *)findings
{
    NSArray *canonicalFindings = SlateInspectorRailCanonicalFindingsArray(findings);
    [_canonicalValidationFindings release];
    _canonicalValidationFindings = [canonicalFindings copy];

    NSString *toolTip = SlateInspectorRailFindingsSummaryToolTip(_canonicalValidationFindings,
                                                                   SMPackageReadinessFindingsToolTipTitle);
    [_typeField setToolTip:toolTip];
    [_name setToolTip:toolTip];
    [_vendorid setToolTip:toolTip];
    [_mediaType setToolTip:toolTip];
    [_releaseDate setToolTip:toolTip];
    [_rating setToolTip:toolTip];
    [_ratingSystem setToolTip:toolTip];
    NSString *copyHintToolTip = SlateInspectorRailCopyHintTooltip(toolTip);
    for (NSDictionary *panel in [self synopsisPanels]) {
        NSTextView *textView = [panel objectForKey:SMPackageMetadataPanelKeyTextView];
        if ([textView isKindOfClass:[NSTextView class]]) {
            [textView setToolTip:copyHintToolTip];
        }
    }
    for (NSDictionary *panel in [self metadataCollectionPanels]) {
        NSTextView *textView = [panel objectForKey:SMPackageMetadataPanelKeyTextView];
        if ([textView isKindOfClass:[NSTextView class]]) {
            [textView setToolTip:copyHintToolTip];
        }
    }
    [_posterArtView setToolTip:toolTip];
    [self updateReadinessPanelPresentation];
}

- (NSArray *)canonicalValidationFindings
{
    return (_canonicalValidationFindings ?: [NSArray array]);
}

#pragma mark - Scanability

- (void)applyPackageTextViewScanabilityMetrics:(NSTextView *)textView
{
    if (textView == nil) {
        return;
    }

    [textView setFont:[NSFont systemFontOfSize:12.5]];
    [textView setTextContainerInset:NSMakeSize(6.0, 6.0)];
}

- (void)applyPackageValueFieldScanabilityMetrics:(NSTextField *)field
{
    if (field == nil) {
        return;
    }

    [field setFont:[NSFont systemFontOfSize:12.5]];
}

- (void)applyPackageLabelScanabilityMetricsInView:(NSView *)view
{
    for (NSView *subview in [view subviews]) {
        if ([subview isKindOfClass:[NSTextField class]]) {
            NSTextField *labelField = (NSTextField *)subview;
            BOOL looksLikeStaticLabel = (![labelField isEditable]
                                         && ![labelField isBordered]
                                         && ![labelField drawsBackground]);
            if (looksLikeStaticLabel) {
                [labelField setFont:[NSFont boldSystemFontOfSize:11.5]];
            }
        }

        [self applyPackageLabelScanabilityMetricsInView:subview];
    }
}

- (void)applyPackageScanabilityMetrics
{
    [self applyPackageValueFieldScanabilityMetrics:_typeField];
    [self applyPackageValueFieldScanabilityMetrics:_name];
    [self applyPackageValueFieldScanabilityMetrics:_vendorid];
    [self applyPackageValueFieldScanabilityMetrics:_mediaType];
    [self applyPackageValueFieldScanabilityMetrics:_releaseDate];
    [self applyPackageValueFieldScanabilityMetrics:_rating];
    [self applyPackageValueFieldScanabilityMetrics:_ratingSystem];

    for (NSDictionary *panel in [self synopsisPanels]) {
        NSTextView *textView = [panel objectForKey:SMPackageMetadataPanelKeyTextView];
        if ([textView isKindOfClass:[NSTextView class]]) {
            [self applyPackageTextViewScanabilityMetrics:textView];
        }
    }
    for (NSDictionary *panel in [self metadataCollectionPanels]) {
        NSTextView *textView = [panel objectForKey:SMPackageMetadataPanelKeyTextView];
        if ([textView isKindOfClass:[NSTextView class]]) {
            [self applyPackageTextViewScanabilityMetrics:textView];
        }
    }

    [self applyPackageLabelScanabilityMetricsInView:[self view]];
    [self alignPosterArtLaneToScalarValueCenter];
}

#pragma mark - Asset Stack Alignment

- (NSTextField *)packageStaticLabelWithExactTitle:(NSString *)title
{
    if (![title isKindOfClass:[NSString class]] || [title length] == 0 || [self view] == nil) {
        return nil;
    }

    for (NSView *subview in [[self view] subviews]) {
        if (![subview isKindOfClass:[NSTextField class]]) {
            continue;
        }
        NSTextField *label = (NSTextField *)subview;
        BOOL looksLikeStaticLabel = (![label isEditable]
                                     && ![label isBordered]
                                     && ![label drawsBackground]);
        if (!looksLikeStaticLabel) {
            continue;
        }
        if ([[label stringValue] isEqualToString:title]) {
            return label;
        }
    }

    return nil;
}

- (void)alignPosterArtLaneToScalarValueCenter
{
    if ([self view] == nil || _posterArtView == nil) {
        return;
    }

    NSTextField *posterArtLabel = [self packageStaticLabelWithExactTitle:@"Poster Art:"];
    if (posterArtLabel == nil) {
        posterArtLabel = [self packageStaticLabelWithExactTitle:@"Poster Art"];
    }

    CGFloat centerX = SMPackageScalarValueCenterX;
    if (_ratingSystem != nil) {
        centerX = NSMidX([_ratingSystem frame]);
    }

    NSRect posterViewFrame = [_posterArtView frame];
    posterViewFrame.origin.x = centerX - (NSWidth(posterViewFrame) * 0.5);
    [_posterArtView setFrame:posterViewFrame];

    if (posterArtLabel != nil) {
        NSRect posterLabelFrame = [posterArtLabel frame];
        posterLabelFrame.origin.x = centerX - (NSWidth(posterLabelFrame) * 0.5);
        [posterArtLabel setFrame:posterLabelFrame];
    }
}

- (void)alignPosterArtLaneBottomToLongSynopsisFrame:(NSRect)longSynopsisFrame
{
    if (_posterArtView == nil || NSHeight(longSynopsisFrame) <= 0.0) {
        return;
    }

    NSTextField *posterArtLabel = [self packageStaticLabelWithExactTitle:@"Poster Art:"];
    if (posterArtLabel == nil) {
        posterArtLabel = [self packageStaticLabelWithExactTitle:@"Poster Art"];
    }

    NSRect posterFrame = [_posterArtView frame];
    CGFloat deltaY = floor(NSMinY(longSynopsisFrame)) - NSMinY(posterFrame);
    posterFrame.origin.y = floor(NSMinY(longSynopsisFrame));
    [_posterArtView setFrame:posterFrame];

    if (posterArtLabel != nil) {
        NSRect posterLabelFrame = [posterArtLabel frame];
        posterLabelFrame.origin.y = floor(NSMinY(posterLabelFrame) + deltaY);
        [posterArtLabel setFrame:posterLabelFrame];
    }
}

- (void)positionPackageScalarLabelWithTitle:(NSString *)title baselineY:(CGFloat)baselineY verticalOffset:(CGFloat)verticalOffset
{
    NSTextField *label = [self packageStaticLabelWithExactTitle:title];
    if (label == nil) {
        return;
    }

    NSRect frame = [label frame];
    frame.origin.y = floor(baselineY + verticalOffset);
    [label setFrame:frame];
}

- (void)positionPackageScalarValueField:(NSTextField *)field baselineY:(CGFloat)baselineY verticalOffset:(CGFloat)verticalOffset
{
    if (field == nil) {
        return;
    }

    NSRect frame = [field frame];
    frame.origin.y = floor(baselineY + verticalOffset);
    [field setFrame:frame];
}

- (void)positionPackageScalarLabelWithTitle:(NSString *)title baselineX:(CGFloat)baselineX horizontalOffset:(CGFloat)horizontalOffset
{
    NSTextField *label = [self packageStaticLabelWithExactTitle:title];
    if (label == nil) {
        return;
    }

    NSRect frame = [label frame];
    frame.origin.x = floor(baselineX + horizontalOffset);
    [label setFrame:frame];
}

- (void)positionPackageScalarValueField:(NSTextField *)field baselineX:(CGFloat)baselineX horizontalOffset:(CGFloat)horizontalOffset
{
    if (field == nil) {
        return;
    }

    NSRect frame = [field frame];
    frame.origin.x = floor(baselineX + horizontalOffset);
    [field setFrame:frame];
}

- (void)applyAssetStackHorizontalOffset:(CGFloat)horizontalOffset
{
    [self positionPackageScalarLabelWithTitle:@"Type:" baselineX:SMPackageScalarLabelX horizontalOffset:horizontalOffset];
    [self positionPackageScalarValueField:_typeField baselineX:SMPackageScalarValueX horizontalOffset:horizontalOffset];

    [self positionPackageScalarLabelWithTitle:@"Name:" baselineX:SMPackageScalarLabelX horizontalOffset:horizontalOffset];
    [self positionPackageScalarValueField:_name baselineX:SMPackageScalarValueX horizontalOffset:horizontalOffset];

    [self positionPackageScalarLabelWithTitle:@"Vendor ID:" baselineX:SMPackageScalarLabelX horizontalOffset:horizontalOffset];
    [self positionPackageScalarValueField:_vendorid baselineX:SMPackageScalarValueX horizontalOffset:horizontalOffset];

    [self positionPackageScalarLabelWithTitle:@"Media Type:" baselineX:SMPackageScalarLabelX horizontalOffset:horizontalOffset];
    [self positionPackageScalarValueField:_mediaType baselineX:SMPackageScalarValueX horizontalOffset:horizontalOffset];

    [self positionPackageScalarLabelWithTitle:@"Release Date:" baselineX:SMPackageScalarLabelX horizontalOffset:horizontalOffset];
    [self positionPackageScalarValueField:_releaseDate baselineX:SMPackageScalarValueX horizontalOffset:horizontalOffset];

    [self positionPackageScalarLabelWithTitle:@"Rating System:" baselineX:SMPackageScalarLabelX horizontalOffset:horizontalOffset];
    [self positionPackageScalarValueField:_ratingSystem baselineX:SMPackageScalarValueX horizontalOffset:horizontalOffset];

    [self positionPackageScalarLabelWithTitle:@"Rating:" baselineX:SMPackageScalarLabelX horizontalOffset:horizontalOffset];
    [self positionPackageScalarValueField:_rating baselineX:SMPackageScalarValueX horizontalOffset:horizontalOffset];

    [self alignPosterArtLaneToScalarValueCenter];
}

- (void)applyAssetStackVerticalOffset:(CGFloat)verticalOffset
{
    [self positionPackageScalarLabelWithTitle:@"Type:" baselineY:SMPackageTypeLabelY verticalOffset:verticalOffset];
    [self positionPackageScalarValueField:_typeField baselineY:SMPackageTypeValueY verticalOffset:verticalOffset];

    [self positionPackageScalarLabelWithTitle:@"Name:" baselineY:SMPackageNameLabelY verticalOffset:verticalOffset];
    [self positionPackageScalarValueField:_name baselineY:SMPackageNameValueY verticalOffset:verticalOffset];

    [self positionPackageScalarLabelWithTitle:@"Vendor ID:" baselineY:SMPackageVendorLabelY verticalOffset:verticalOffset];
    [self positionPackageScalarValueField:_vendorid baselineY:SMPackageVendorValueY verticalOffset:verticalOffset];

    [self positionPackageScalarLabelWithTitle:@"Media Type:" baselineY:SMPackageMediaTypeLabelY verticalOffset:verticalOffset];
    [self positionPackageScalarValueField:_mediaType baselineY:SMPackageMediaTypeValueY verticalOffset:verticalOffset];

    [self positionPackageScalarLabelWithTitle:@"Release Date:" baselineY:SMPackageReleaseDateLabelY verticalOffset:verticalOffset];
    [self positionPackageScalarValueField:_releaseDate baselineY:SMPackageReleaseDateValueY verticalOffset:verticalOffset];

    [self positionPackageScalarLabelWithTitle:@"Rating System:" baselineY:SMPackageRatingSystemLabelY verticalOffset:verticalOffset];
    [self positionPackageScalarValueField:_ratingSystem baselineY:SMPackageRatingSystemValueY verticalOffset:verticalOffset];

    [self positionPackageScalarLabelWithTitle:@"Rating:" baselineY:SMPackageRatingLabelY verticalOffset:verticalOffset];
    [self positionPackageScalarValueField:_rating baselineY:SMPackageRatingValueY verticalOffset:verticalOffset];

    [self positionPackageScalarLabelWithTitle:@"Poster Art:" baselineY:SMPackagePosterArtLabelY verticalOffset:verticalOffset];
    if (_posterArtView != nil) {
        NSRect posterFrame = [_posterArtView frame];
        posterFrame.origin.y = floor(SMPackagePosterArtViewY + verticalOffset);
        [_posterArtView setFrame:posterFrame];
    }
}

#pragma mark - Synopsis Rail

- (NSArray *)synopsisPanels
{
    return (_synopsisPanels ?: [NSArray array]);
}

- (NSDictionary *)synopsisPanelForTarget:(NSString *)target
{
    if (!SMPackStringHasContent(target)) {
        return nil;
    }

    for (NSDictionary *panel in [self synopsisPanels]) {
        NSString *panelTarget = [panel objectForKey:SMPackageMetadataPanelKeyTarget];
        if ([panelTarget isEqualToString:target]) {
            return panel;
        }
    }

    return nil;
}

- (NSTextView *)synopsisTextViewForTarget:(NSString *)target
{
    NSDictionary *panel = [self synopsisPanelForTarget:target];
    NSTextView *textView = [panel objectForKey:SMPackageMetadataPanelKeyTextView];
    return [textView isKindOfClass:[NSTextView class]] ? textView : nil;
}

- (NSScrollView *)synopsisScrollViewForTarget:(NSString *)target
{
    NSDictionary *panel = [self synopsisPanelForTarget:target];
    NSScrollView *scrollView = [panel objectForKey:SMPackageMetadataPanelKeyScrollView];
    return [scrollView isKindOfClass:[NSScrollView class]] ? scrollView : nil;
}

- (NSTextField *)synopsisLabelForTarget:(NSString *)target
{
    NSDictionary *panel = [self synopsisPanelForTarget:target];
    NSTextField *label = [panel objectForKey:SMPackageSynopsisPanelKeyLabel];
    return [label isKindOfClass:[NSTextField class]] ? label : nil;
}

- (NSArray *)synopsisScrollViews
{
    NSMutableArray *scrollViews = [NSMutableArray array];
    for (NSDictionary *panel in [self synopsisPanels]) {
        NSScrollView *scrollView = [panel objectForKey:SMPackageMetadataPanelKeyScrollView];
        if ([scrollView isKindOfClass:[NSScrollView class]]) {
            [scrollViews addObject:scrollView];
        }
    }

    return scrollViews;
}

- (NSArray *)synopsisLabels
{
    NSMutableArray *labels = [NSMutableArray array];
    for (NSDictionary *panel in [self synopsisPanels]) {
        NSTextField *label = [panel objectForKey:SMPackageSynopsisPanelKeyLabel];
        if ([label isKindOfClass:[NSTextField class]]) {
            [labels addObject:label];
        }
    }

    return labels;
}

- (void)removeSynopsisPanelsFromHierarchy
{
    for (NSDictionary *panel in [self synopsisPanels]) {
        NSTextField *label = [panel objectForKey:SMPackageSynopsisPanelKeyLabel];
        if ([label isKindOfClass:[NSTextField class]]) {
            [label removeFromSuperview];
        }

        NSScrollView *scrollView = [panel objectForKey:SMPackageMetadataPanelKeyScrollView];
        if (![scrollView isKindOfClass:[NSScrollView class]]) {
            continue;
        }
        [scrollView setDocumentView:nil];
        [scrollView removeFromSuperview];
    }

    [_synopsisPanels release];
    _synopsisPanels = nil;
}

- (NSTextField *)newSynopsisLabelWithTitle:(NSString *)title frame:(NSRect)frame
{
    NSTextField *label = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [label setEditable:NO];
    [label setBordered:NO];
    [label setDrawsBackground:NO];
    [label setSelectable:NO];
    [label setBezeled:NO];
    [label setFocusRingType:NSFocusRingTypeNone];
    [label setAlignment:NSTextAlignmentLeft];
    [label setFont:[NSFont systemFontOfSize:SMPackagePanelLabelFontSize]];
    [label setTextColor:[NSColor controlTextColor]];
    [label setStringValue:(title ?: @"")];
    [label setTranslatesAutoresizingMaskIntoConstraints:YES];
    [label setAutoresizingMask:NSViewNotSizable];
    return label;
}

- (void)configurePackageTextPanelScrollView:(NSScrollView *)scrollView
{
    if (scrollView == nil) {
        return;
    }

    [scrollView setBorderType:NSLineBorder];
    [scrollView setHorizontalLineScroll:SMPackageSynopsisScrollStep];
    [scrollView setHorizontalPageScroll:SMPackageSynopsisScrollStep];
    [scrollView setVerticalLineScroll:SMPackageSynopsisScrollStep];
    [scrollView setVerticalPageScroll:SMPackageSynopsisScrollStep];
    [scrollView setHasHorizontalScroller:NO];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setTranslatesAutoresizingMaskIntoConstraints:YES];
    [scrollView setAutoresizingMask:NSViewNotSizable];
    [scrollView setDrawsBackground:YES];
    [scrollView setBackgroundColor:[NSColor textBackgroundColor]];
    [[scrollView contentView] setDrawsBackground:YES];
}

- (NSDictionary *)newSynopsisPanelWithSpec:(NSDictionary *)spec
{
    NSString *target = [spec objectForKey:SMPackageMetadataPanelKeyTarget];
    NSString *snapshotKey = [spec objectForKey:SMPackageMetadataPanelKeySnapshot];
    NSString *labelTitle = [spec objectForKey:SMPackageSynopsisPanelKeyLabel];
    NSRect labelFrame = NSRectFromString([spec objectForKey:SMPackageSynopsisPanelKeyLabelFrame]);
    NSRect scrollFrame = NSRectFromString([spec objectForKey:SMPackageSynopsisPanelKeyScrollFrame]);
    if (!SMPackStringHasContent(target) || !SMPackStringHasContent(snapshotKey)) {
        return nil;
    }

    NSTextField *label = [self newSynopsisLabelWithTitle:labelTitle frame:labelFrame];
    [[self view] addSubview:label];

    NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:scrollFrame] autorelease];
    [self configurePackageTextPanelScrollView:scrollView];

    NSTextView *textView = [self newMetadataCollectionTextView];
    [scrollView setDocumentView:textView];
    [[self view] addSubview:scrollView];

    return [NSDictionary dictionaryWithObjectsAndKeys:
            target, SMPackageMetadataPanelKeyTarget,
            snapshotKey, SMPackageMetadataPanelKeySnapshot,
            textView, SMPackageMetadataPanelKeyTextView,
            scrollView, SMPackageMetadataPanelKeyScrollView,
            label, SMPackageSynopsisPanelKeyLabel,
            nil];
}

- (void)ensureCodeOwnedSynopsisViews
{
    NSView *containerView = [self view];
    if (containerView == nil) {
        return;
    }

    NSArray *specs = SMPackageSynopsisPanelSpecs();
    NSArray *existingPanels = [self synopsisPanels];
    BOOL alreadyAttached = YES;
    if ([existingPanels count] != [specs count]) {
        alreadyAttached = NO;
    }

    for (NSDictionary *panel in existingPanels) {
        NSTextField *label = [panel objectForKey:SMPackageSynopsisPanelKeyLabel];
        NSTextView *textView = [panel objectForKey:SMPackageMetadataPanelKeyTextView];
        NSScrollView *scrollView = [panel objectForKey:SMPackageMetadataPanelKeyScrollView];
        if (![label isKindOfClass:[NSTextField class]]
            || ![textView isKindOfClass:[NSTextView class]]
            || ![scrollView isKindOfClass:[NSScrollView class]]) {
            alreadyAttached = NO;
            break;
        }

        if ([label superview] != containerView
            || [textView enclosingScrollView] != scrollView
            || [scrollView superview] != containerView) {
            alreadyAttached = NO;
            break;
        }
    }

    if (alreadyAttached) {
        return;
    }

    [self removeSynopsisPanelsFromHierarchy];
    _synopsisPanels = [[NSMutableArray alloc] initWithCapacity:[specs count]];

    for (NSDictionary *spec in specs) {
        NSDictionary *panel = [self newSynopsisPanelWithSpec:spec];
        if (panel != nil) {
            [_synopsisPanels addObject:panel];
        }
    }
}

#pragma mark - Metadata Rail

- (NSArray *)metadataCollectionPanels
{
    return (_metadataCollectionPanels ?: [NSArray array]);
}

- (NSDictionary *)metadataCollectionPanelForTarget:(NSString *)target
{
    if (!SMPackStringHasContent(target)) {
        return nil;
    }

    for (NSDictionary *panel in [self metadataCollectionPanels]) {
        NSString *panelTarget = [panel objectForKey:SMPackageMetadataPanelKeyTarget];
        if ([panelTarget isEqualToString:target]) {
            return panel;
        }
    }

    return nil;
}

- (NSTextView *)metadataTextViewForTarget:(NSString *)target
{
    NSDictionary *panel = [self metadataCollectionPanelForTarget:target];
    NSTextView *textView = [panel objectForKey:SMPackageMetadataPanelKeyTextView];
    return [textView isKindOfClass:[NSTextView class]] ? textView : nil;
}

- (NSArray *)metadataCollectionScrollViews
{
    NSMutableArray *scrollViews = [NSMutableArray array];
    for (NSDictionary *panel in [self metadataCollectionPanels]) {
        NSScrollView *scrollView = [panel objectForKey:SMPackageMetadataPanelKeyScrollView];
        if ([scrollView isKindOfClass:[NSScrollView class]]) {
            [scrollViews addObject:scrollView];
        }
    }

    return scrollViews;
}

- (NSArray *)metadataCollectionLabels
{
    NSMutableArray *labels = [NSMutableArray array];
    for (NSDictionary *panel in [self metadataCollectionPanels]) {
        NSTextField *label = [panel objectForKey:SMPackageMetadataPanelKeyLabel];
        if ([label isKindOfClass:[NSTextField class]]) {
            [labels addObject:label];
        }
    }

    return labels;
}

- (void)removeMetadataCollectionPanelsFromHierarchy
{
    for (NSDictionary *panel in [self metadataCollectionPanels]) {
        NSTextField *label = [panel objectForKey:SMPackageMetadataPanelKeyLabel];
        if ([label isKindOfClass:[NSTextField class]]) {
            [label removeFromSuperview];
        }

        NSScrollView *scrollView = [panel objectForKey:SMPackageMetadataPanelKeyScrollView];
        if (![scrollView isKindOfClass:[NSScrollView class]]) {
            continue;
        }
        [scrollView setDocumentView:nil];
        [scrollView removeFromSuperview];
    }

    [_metadataCollectionPanels release];
    _metadataCollectionPanels = nil;
}

- (NSTextView *)newMetadataCollectionTextView
{
    NSTextView *textView = [[[NSTextView alloc] initWithFrame:NSZeroRect] autorelease];
    [textView setEditable:NO];
    [textView setSelectable:YES];
    [textView setImportsGraphics:NO];
    [textView setRichText:NO];
    [textView setVerticallyResizable:YES];
    [textView setHorizontallyResizable:NO];
    [textView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [textView setString:@""];
    [textView setDelegate:(id<NSTextViewDelegate>)self];
    [textView setTextColor:[NSColor textColor]];
    [textView setDrawsBackground:YES];
    [textView setBackgroundColor:[NSColor textBackgroundColor]];

    NSTextContainer *textContainer = [textView textContainer];
    if (textContainer != nil) {
        [textContainer setContainerSize:NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX)];
        [textContainer setWidthTracksTextView:YES];
    }

    [self applyPackageTextViewScanabilityMetrics:textView];
    return textView;
}

- (NSTextField *)newMetadataCollectionLabelWithTitle:(NSString *)title
{
    NSTextField *label = [[[NSTextField alloc] initWithFrame:NSZeroRect] autorelease];
    [label setEditable:NO];
    [label setBordered:NO];
    [label setDrawsBackground:NO];
    [label setSelectable:NO];
    [label setBezeled:NO];
    [label setFocusRingType:NSFocusRingTypeNone];
    [label setAlignment:NSTextAlignmentLeft];
    [label setFont:[NSFont systemFontOfSize:11.5]];
    [label setTextColor:[NSColor secondaryLabelColor]];
    [label setStringValue:(SMPackStringHasContent(title) ? title : @"")];
    [label setTranslatesAutoresizingMaskIntoConstraints:YES];
    [label setAutoresizingMask:NSViewNotSizable];
    return label;
}

- (NSDictionary *)newMetadataCollectionPanelWithSpec:(NSDictionary *)spec
{
    NSString *target = [spec objectForKey:SMPackageMetadataPanelKeyTarget];
    NSString *snapshotKey = [spec objectForKey:SMPackageMetadataPanelKeySnapshot];
    NSString *labelTitle = [spec objectForKey:SMPackageMetadataPanelKeyLabelText];
    if (!SMPackStringHasContent(target) || !SMPackStringHasContent(snapshotKey)) {
        return nil;
    }

    NSTextField *label = [self newMetadataCollectionLabelWithTitle:labelTitle];
    [[self view] addSubview:label];

    NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:NSZeroRect] autorelease];
    [self configurePackageTextPanelScrollView:scrollView];

    NSTextView *textView = [self newMetadataCollectionTextView];
    [scrollView setDocumentView:textView];
    [[self view] addSubview:scrollView];

    return [NSDictionary dictionaryWithObjectsAndKeys:
            target, SMPackageMetadataPanelKeyTarget,
            snapshotKey, SMPackageMetadataPanelKeySnapshot,
            textView, SMPackageMetadataPanelKeyTextView,
            scrollView, SMPackageMetadataPanelKeyScrollView,
            label, SMPackageMetadataPanelKeyLabel,
            nil];
}

- (void)ensureCodeOwnedMetadataCollectionViews
{
    NSView *containerView = [self view];
    if (containerView == nil) {
        return;
    }

    NSArray *specs = SMPackageMetadataPanelSpecs();
    NSArray *existingPanels = [self metadataCollectionPanels];
    BOOL alreadyAttached = YES;
    if ([existingPanels count] != [specs count]) {
        alreadyAttached = NO;
    }

    for (NSDictionary *panel in existingPanels) {
        NSTextField *label = [panel objectForKey:SMPackageMetadataPanelKeyLabel];
        NSTextView *textView = [panel objectForKey:SMPackageMetadataPanelKeyTextView];
        NSScrollView *scrollView = [panel objectForKey:SMPackageMetadataPanelKeyScrollView];
        if (![label isKindOfClass:[NSTextField class]]
            || ![textView isKindOfClass:[NSTextView class]]
            || ![scrollView isKindOfClass:[NSScrollView class]]) {
            alreadyAttached = NO;
            break;
        }

        if ([label superview] != containerView
            || [textView enclosingScrollView] != scrollView
            || [scrollView superview] != containerView) {
            alreadyAttached = NO;
            break;
        }
    }

    if (alreadyAttached) {
        return;
    }

    [self removeMetadataCollectionPanelsFromHierarchy];
    _metadataCollectionPanels = [[NSMutableArray alloc] initWithCapacity:[specs count]];

    for (NSDictionary *spec in specs) {
        NSDictionary *panel = [self newMetadataCollectionPanelWithSpec:spec];
        if (panel != nil) {
            [_metadataCollectionPanels addObject:panel];
        }
    }
}

#pragma mark - Readiness Rail

- (NSTextField *)newPackageSectionLabelWithString:(NSString *)stringValue
                                              font:(NSFont *)font
                                         textColor:(NSColor *)textColor
{
    return SlateInspectorRailCreateLabel(stringValue,
                                           font,
                                           textColor,
                                           NSTextAlignmentLeft,
                                           NO);
}

- (void)restorePackageReadinessSubviewOrderIfNeeded
{
    NSView *containerView = [self view];
    if (containerView == nil) {
        return;
    }

    NSMutableArray *orderedViews = [NSMutableArray arrayWithCapacity:4];
    NSView *readinessSectionLabel = [_readinessPresenter sectionLabel];
    NSView *readinessStatusLabel = [_readinessPresenter statusLabel];
    NSView *inspectorPinButton = [_readinessPresenter pinButton];
    NSView *readinessScrollView = [_readinessPresenter scrollView];
    if (readinessSectionLabel != nil) {
        [orderedViews addObject:readinessSectionLabel];
    }
    if (readinessStatusLabel != nil) {
        [orderedViews addObject:readinessStatusLabel];
    }
    if (inspectorPinButton != nil) {
        [orderedViews addObject:inspectorPinButton];
    }
    if (readinessScrollView != nil) {
        [orderedViews addObject:readinessScrollView];
    }
    if ([orderedViews count] != 4) {
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

- (void)ensurePackageSectionedFlowViews
{
    if (_metadataGroupBox == nil) {
        _metadataGroupBox = [[NSBox alloc] initWithFrame:NSZeroRect];
        [_metadataGroupBox setBoxType:NSBoxCustom];
        [_metadataGroupBox setBorderType:NSLineBorder];
        [_metadataGroupBox setBorderColor:[[NSColor secondaryLabelColor] colorWithAlphaComponent:0.33]];
        [_metadataGroupBox setFillColor:[[NSColor textBackgroundColor] colorWithAlphaComponent:0.35]];
        [_metadataGroupBox setCornerRadius:6.0];
        [_metadataGroupBox setTitlePosition:NSNoTitle];
        [_metadataGroupBox setTranslatesAutoresizingMaskIntoConstraints:YES];
        [_metadataGroupBox setAutoresizingMask:NSViewNotSizable];
        [[self view] addSubview:_metadataGroupBox positioned:NSWindowBelow relativeTo:nil];
    }

    if (_metadataSectionLabel == nil) {
        _metadataSectionLabel = [[self newPackageSectionLabelWithString:SMPackageSectionTitleMetadata
                                                                   font:[NSFont boldSystemFontOfSize:11.5]
                                                              textColor:[NSColor secondaryLabelColor]] retain];
        SlateInspectorRailApplySectionHeaderStyle(_metadataSectionLabel);
        [[self view] addSubview:_metadataSectionLabel];
    }

    if (_readinessPresenter == nil) {
        _readinessPresenter = [[UtilReadinessRailPresenter alloc] initWithSectionTitle:SMPackageSectionTitleReadiness
                                                                  findingsToolTipTitle:SMPackageReadinessFindingsToolTipTitle
                                                                             pinTarget:self
                                                                             pinAction:@selector(toggleInspectorRailPinned:)
                                                                      textViewDelegate:(id<NSTextViewDelegate>)self];
    }
    [_readinessPresenter ensureViewsInSuperview:[self view]];
    [_readinessPresenter setPinState:_inspectorRailPinned];
    [self restorePackageReadinessSubviewOrderIfNeeded];
}

#pragma mark - Pinning and Jump Targets

- (void)setInspectorRailPinned:(BOOL)pinned
{
    if (_inspectorRailPinned == pinned) {
        return;
    }

    _inspectorRailPinned = pinned;
    [_readinessPresenter setPinState:pinned];
    [[NSUserDefaults standardUserDefaults] setBool:pinned forKey:SMPackageInspectorRailPinnedDefaultsKey];
}

- (IBAction)toggleInspectorRailPinned:(id)sender
{
    BOOL pinned = ([(NSButton *)sender state] == NSOnState);
    [self setInspectorRailPinned:pinned];
    [self applyWorkspaceLayoutForWidth:NSWidth([[self view] bounds])];
}

- (NSDictionary *)packageReadinessJumpLinksByFindingIdentity
{
    NSMutableDictionary *jumpLinkByFindingIdentity = [NSMutableDictionary dictionary];
    for (NSDictionary *finding in [self canonicalValidationFindings]) {
        if (![finding isKindOfClass:[NSDictionary class]]) {
            continue;
        }

        NSString *target = SMPackageReadinessJumpTargetForFinding(finding);
        NSString *jumpLink = SlateInspectorRailJumpLink(target, NSNotFound);
        if (SMPackStringHasContent(jumpLink)) {
            [jumpLinkByFindingIdentity setObject:jumpLink
                                          forKey:SlateInspectorRailFindingIdentity(finding)];
        }
    }

    return jumpLinkByFindingIdentity;
}

- (void)focusPackageReadinessTarget:(NSString *)target
{
    if (!SMPackStringHasContent(target)) {
        return;
    }

    NSResponder *targetResponder = nil;
    if ([target isEqualToString:SlatePackageSnapshotTargetType]) {
        targetResponder = _typeField;
    } else if ([target isEqualToString:SlatePackageSnapshotTargetName]) {
        targetResponder = _name;
    } else if ([target isEqualToString:SlatePackageSnapshotTargetVendor]) {
        targetResponder = _vendorid;
    } else if ([target isEqualToString:SlatePackageSnapshotTargetMediaType]) {
        targetResponder = _mediaType;
    } else if ([target isEqualToString:SlatePackageSnapshotTargetReleaseDate]) {
        targetResponder = _releaseDate;
    } else if ([target isEqualToString:SlatePackageSnapshotTargetRating]) {
        targetResponder = _rating;
    } else if ([target isEqualToString:SlatePackageSnapshotTargetRatingSystem]) {
        targetResponder = _ratingSystem;
    } else if ([target isEqualToString:SlatePackageSnapshotTargetSynopsisShort]) {
        targetResponder = [self synopsisTextViewForTarget:target];
    } else if ([target isEqualToString:SlatePackageSnapshotTargetSynopsisLong]) {
        targetResponder = [self synopsisTextViewForTarget:target];
    } else if ([target isEqualToString:SlatePackageSnapshotTargetPoster]) {
        targetResponder = _posterArtView;
    } else {
        NSTextView *metadataTextView = [self metadataTextViewForTarget:target];
        if (metadataTextView != nil) {
            targetResponder = metadataTextView;
        }
    }

    if (targetResponder != nil) {
        NSView *targetView = [targetResponder isKindOfClass:[NSView class]] ? (NSView *)targetResponder : nil;
        if (targetView != nil) {
            NSRect targetRect = [targetView convertRect:[targetView bounds] toView:[self view]];
            [[self view] scrollRectToVisible:targetRect];
        }
        [[[self view] window] makeFirstResponder:targetResponder];
    }
}

- (BOOL)textView:(NSTextView *)textView clickedOnLink:(id)link atIndex:(NSUInteger)charIndex
{
    #pragma unused(charIndex)
    if (![_readinessPresenter ownsTextView:textView]) {
        return NO;
    }

    NSInteger rowIndex = NSNotFound;
    NSString *target = SlateInspectorRailJumpTargetFromLink(link, &rowIndex);
    #pragma unused(rowIndex)
    if (!SMPackStringHasContent(target)) {
        return NO;
    }

    [self focusPackageReadinessTarget:target];
    return YES;
}

- (void)updateReadinessPanelPresentation
{
    [self ensurePackageSectionedFlowViews];
    NSString *emptyStatus = _hasPackageContext ? SMPackageReadinessStatusNoFindings : SMPackageReadinessStatusNoPackageLoaded;
    NSString *emptyMessage = _hasPackageContext ? SMPackageReadinessEmptyMessageNoFindings : @"";
    NSDictionary *jumpLinkByFindingIdentity = [self packageReadinessJumpLinksByFindingIdentity];
    NSDictionary *reviewPaneSnapshot = [SlateRuntimeBridge reviewPaneSnapshotWithPaneKey:SlateReviewPaneKeyPackage
                                                                                title:SMPackageSectionTitleReadiness
                                                                             findings:[self canonicalValidationFindings]
                                                                          emptyStatus:emptyStatus
                                                                         emptyMessage:emptyMessage
                                                           jumpLinksByFindingIdentity:jumpLinkByFindingIdentity];
    [_readinessPresenter updateWithReviewPaneSnapshot:reviewPaneSnapshot];
}

#pragma mark - NIB Compatibility

-(void)awakeFromNib
{
    [self initializePackageControllerDataIfNeeded];
    [[self view] setTranslatesAutoresizingMaskIntoConstraints:YES];
    [[self view] setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [[self view] setAutoresizesSubviews:YES];
    [self ensureCodeOwnedSynopsisViews];
    [self ensureCodeOwnedMetadataCollectionViews];
    [self applyPackageScanabilityMetrics];
    [self updateReadinessPanelPresentation];
    [self applyWorkspaceLayoutForWidth:NSWidth([[self view] bounds])];
    [super awakeFromNib];
}

-(BOOL)textView:(NSTextView *)aTextView doCommandBySelector:(SEL)aSelector
{
    if (aSelector == @selector(insertTab:))
    {
        [[aTextView window] selectNextKeyView:nil];
        
        return (YES);
    }

    return (NO);
}

#pragma mark - Package Presentation

- (void)presentPackageSnapshot:(NSDictionary *)packageSnapshot
{
    if (![packageSnapshot isKindOfClass:[NSDictionary class]]) {
        [self clearPackagePresentation];
        return;
    }

    _hasPackageContext = YES;

    NSDictionary *assetStack = SMPackageDictionaryValue([packageSnapshot objectForKey:SlatePackageSnapshotKeyAssetStack]);
    NSDictionary *synopsis = SMPackageDictionaryValue([packageSnapshot objectForKey:SlatePackageSnapshotKeySynopsis]);
    NSDictionary *metadataCollections = SMPackageDictionaryValue([packageSnapshot objectForKey:SlatePackageSnapshotKeyMetadataCollections]);
    NSDictionary *posterArt = SMPackageDictionaryValue([packageSnapshot objectForKey:SlatePackageSnapshotKeyPosterArt]);

    [_typeField setStringValue:SlatePackageSnapshotStringForKey(assetStack, SlatePackageSnapshotAssetKeyType)];
    [_name setStringValue:SlatePackageSnapshotStringForKey(assetStack, SlatePackageSnapshotAssetKeyName)];
    [_vendorid setStringValue:SlatePackageSnapshotStringForKey(assetStack, SlatePackageSnapshotAssetKeyVendorID)];
    [_mediaType setStringValue:SlatePackageSnapshotStringForKey(assetStack, SlatePackageSnapshotAssetKeyMediaType)];
    [_releaseDate setStringValue:SlatePackageSnapshotStringForKey(assetStack, SlatePackageSnapshotAssetKeyReleaseDate)];
    [_ratingSystem setStringValue:SlatePackageSnapshotStringForKey(assetStack, SlatePackageSnapshotAssetKeyRatingSystem)];
    [_rating setStringValue:SlatePackageSnapshotStringForKey(assetStack, SlatePackageSnapshotAssetKeyRating)];

    [[self synopsisTextViewForTarget:SlatePackageSnapshotTargetSynopsisShort] setString:SlatePackageSnapshotStringForKey(synopsis, SlatePackageSnapshotSynopsisKeyShort)];
    [[self synopsisTextViewForTarget:SlatePackageSnapshotTargetSynopsisLong] setString:SlatePackageSnapshotStringForKey(synopsis, SlatePackageSnapshotSynopsisKeyLong)];

    for (NSDictionary *panel in [self metadataCollectionPanels]) {
        NSString *target = [panel objectForKey:SMPackageMetadataPanelKeyTarget];
        NSTextView *textView = [panel objectForKey:SMPackageMetadataPanelKeyTextView];
        if (!SMPackStringHasContent(target) || ![textView isKindOfClass:[NSTextView class]]) {
            continue;
        }

        NSDictionary *collection = SMPackageDictionaryValue([metadataCollections objectForKey:target]);
        [textView setString:SlatePackageSnapshotStringForKey(collection, SlatePackageSnapshotCollectionKeyDisplayText)];
    }
     
    NSString *resolvedPosterPath = SlatePackageSnapshotStringForKey(posterArt, SlatePackageSnapshotPosterKeyResolvedPath);
    NSImage *posterImage = (SMPackStringHasContent(resolvedPosterPath) && [[NSFileManager defaultManager] fileExistsAtPath:resolvedPosterPath])
        ? [[[NSImage alloc] initWithContentsOfFile:resolvedPosterPath] autorelease]
        : nil;

    [_posterArtView setImage:posterImage];
    [self updateReadinessPanelPresentation];
}

- (void)clearPackagePresentation
{
    _hasPackageContext = NO;

    [_typeField setStringValue:@""];
    [[self synopsisTextViewForTarget:SlatePackageSnapshotTargetSynopsisShort] setString:@""];
    [[self synopsisTextViewForTarget:SlatePackageSnapshotTargetSynopsisLong] setString:@""];
    [_name setStringValue:@""];
    [_releaseDate setStringValue:@""];
    [_vendorid setStringValue:@""];
    [_mediaType setStringValue:@""];
    [_ratingSystem setStringValue:@""];
    [_rating setStringValue:@""];

    for (NSDictionary *panel in [self metadataCollectionPanels]) {
        NSTextView *textView = [panel objectForKey:SMPackageMetadataPanelKeyTextView];
        if ([textView isKindOfClass:[NSTextView class]]) {
            [textView setString:@""];
        }
    }
    [_posterArtView setImage:nil];
    [self updateReadinessPanelPresentation];
}

- (NSScrollView *)scrollViewForPackageTextView:(NSTextView *)textView
{
    return [textView enclosingScrollView];
}

#pragma mark - Layout

- (void)applyPackagePanelsForRailMode:(SMPackageRailMode)railMode
{
    [self ensurePackageSectionedFlowViews];

    NSScrollView *shortSynopsisScroll = [self synopsisScrollViewForTarget:SlatePackageSnapshotTargetSynopsisShort];
    NSScrollView *longSynopsisScroll = [self synopsisScrollViewForTarget:SlatePackageSnapshotTargetSynopsisLong];
    NSTextField *shortSynopsisLabel = [self synopsisLabelForTarget:SlatePackageSnapshotTargetSynopsisShort];
    NSTextField *longSynopsisLabel = [self synopsisLabelForTarget:SlatePackageSnapshotTargetSynopsisLong];
    NSArray *metadataPanels = [self metadataCollectionScrollViews];
    NSArray *metadataLabels = [self metadataCollectionLabels];
    NSTextField *readinessSectionLabel = [_readinessPresenter sectionLabel];
    NSTextField *readinessStatusLabel = [_readinessPresenter statusLabel];
    NSScrollView *readinessScrollView = [_readinessPresenter scrollView];
    NSUInteger metadataPanelCount = [metadataPanels count];
    if (metadataPanelCount != [SMPackageMetadataPanelSpecs() count] ||
        [metadataLabels count] != metadataPanelCount ||
        shortSynopsisScroll == nil || longSynopsisScroll == nil ||
        shortSynopsisLabel == nil || longSynopsisLabel == nil ||
        _metadataSectionLabel == nil || readinessSectionLabel == nil ||
        readinessStatusLabel == nil || readinessScrollView == nil) {
        [_metadataGroupBox setHidden:YES];
        [_readinessPresenter setRailHidden:YES];
        return;
    }

    NSRect viewBounds = [[self view] bounds];
    NSRect defaultRootFrame = SMPackageDefaultRootFrame();
    NSRect layoutBounds = SlateWorkspaceCenteredContentEnvelope(viewBounds,
                                                                NSWidth(defaultRootFrame),
                                                                NSHeight(defaultRootFrame),
                                                                SlateWorkspaceHorizontalExpansionAllowance(),
                                                                SlateWorkspaceVerticalExpansionAllowance());
    CGFloat outerMargin = SMPackageResponsiveOuterMargin();
    CGFloat gap = SMPackageResponsiveColumnGap();
    CGFloat metadataInteriorInset = gap;
    CGFloat middleRailGap = gap + SMPackageMiddleRailExtraGap;
    CGFloat workspaceWidthForLayout = NSWidth(layoutBounds);
    CGFloat fixedRailWidth = SlateInspectorRailFixedWidth();
    CGFloat readinessRightInset = SlateInspectorRailRightInset();
    CGFloat readinessBottomInset = SlateInspectorRailEffectiveBottomInsetForHostView([self view]);
    CGFloat rightRailX = NSMaxX(layoutBounds) - readinessRightInset - fixedRailWidth;
    CGFloat contentRailLeftX = NSMinX(layoutBounds) + outerMargin;
    CGFloat contentRailRightXWithReadiness = rightRailX - middleRailGap;
    BOOL compactRailMode = (railMode == SMPackageRailModeCompact);
    CGFloat minimumContentRailWidth = compactRailMode
        ? SMPackageCompactPinnedContentRailMinimumWidth
        : SMPackageContentRailMinimumWidth;
    BOOL readinessAllowedByMode = !compactRailMode || _inspectorRailPinned;
    BOOL readinessAllowedByWidth = _inspectorRailPinned || (workspaceWidthForLayout >= SlateInspectorRailPackageMinimumHostWidth());
    BOOL showReadinessRail = (readinessAllowedByMode
                              && readinessAllowedByWidth
                              && ((contentRailRightXWithReadiness - contentRailLeftX) >= minimumContentRailWidth));
    CGFloat railWidth = showReadinessRail ? fixedRailWidth : 0.0;
    CGFloat contentRailRightX = showReadinessRail ? contentRailRightXWithReadiness : (NSMaxX(layoutBounds) - outerMargin);

    NSRect shortSynopsisFrame = [shortSynopsisScroll frame];
    NSRect longSynopsisFrame = [longSynopsisScroll frame];
    NSRect shortSynopsisLabelFrame = [shortSynopsisLabel frame];
    NSRect longSynopsisLabelFrame = [longSynopsisLabel frame];
    NSDictionary *shortSynopsisSpec = SMPackageSynopsisSpecForTarget(SlatePackageSnapshotTargetSynopsisShort);
    NSDictionary *longSynopsisSpec = SMPackageSynopsisSpecForTarget(SlatePackageSnapshotTargetSynopsisLong);
    NSRect shortSynopsisDefaultScrollFrame = (shortSynopsisSpec != nil)
        ? NSRectFromString([shortSynopsisSpec objectForKey:SMPackageSynopsisPanelKeyScrollFrame])
        : shortSynopsisFrame;
    NSRect longSynopsisDefaultScrollFrame = (longSynopsisSpec != nil)
        ? NSRectFromString([longSynopsisSpec objectForKey:SMPackageSynopsisPanelKeyScrollFrame])
        : longSynopsisFrame;
    NSRect shortSynopsisDefaultLabelFrame = (shortSynopsisSpec != nil)
        ? NSRectFromString([shortSynopsisSpec objectForKey:SMPackageSynopsisPanelKeyLabelFrame])
        : shortSynopsisLabelFrame;
    NSRect longSynopsisDefaultLabelFrame = (longSynopsisSpec != nil)
        ? NSRectFromString([longSynopsisSpec objectForKey:SMPackageSynopsisPanelKeyLabelFrame])
        : longSynopsisLabelFrame;

    CGFloat layoutHorizontalOffset = NSMinX(layoutBounds) - NSMinX(defaultRootFrame);
    [self applyAssetStackHorizontalOffset:layoutHorizontalOffset];

    CGFloat synopsisXOffset = SMPackageSynopsisStackXOffset();
    CGFloat defaultSynopsisMinX = layoutHorizontalOffset + MIN(NSMinX(shortSynopsisDefaultScrollFrame), NSMinX(longSynopsisDefaultScrollFrame)) + synopsisXOffset;
    CGFloat assetStackRightEdge = MAX(NSMaxX([_typeField frame]),
                                      MAX(NSMaxX([_name frame]),
                                          MAX(NSMaxX([_vendorid frame]),
                                              MAX(NSMaxX([_mediaType frame]),
                                                  MAX(NSMaxX([_releaseDate frame]),
                                                      MAX(NSMaxX([_ratingSystem frame]), NSMaxX([_rating frame])))))));
    CGFloat constrainedSynopsisMinX = MAX(defaultSynopsisMinX, assetStackRightEdge + gap);
    CGFloat synopsisXDelta = constrainedSynopsisMinX - defaultSynopsisMinX;

    shortSynopsisFrame.origin.x = layoutHorizontalOffset + NSMinX(shortSynopsisDefaultScrollFrame) + synopsisXOffset + synopsisXDelta;
    longSynopsisFrame.origin.x = layoutHorizontalOffset + NSMinX(longSynopsisDefaultScrollFrame) + synopsisXOffset + synopsisXDelta;
    shortSynopsisLabelFrame.origin.x = layoutHorizontalOffset + NSMinX(shortSynopsisDefaultLabelFrame) + synopsisXOffset + synopsisXDelta;
    longSynopsisLabelFrame.origin.x = layoutHorizontalOffset + NSMinX(longSynopsisDefaultLabelFrame) + synopsisXOffset + synopsisXDelta;

    CGFloat metadataPanelLabelHeight = SMPackageMetadataPanelLabelHeight;
    CGFloat metadataPanelLabelGap = SMPackageMetadataPanelLabelGap;
    CGFloat shortSynopsisLabelYOffset = NSMinY(shortSynopsisDefaultLabelFrame) - NSMaxY(shortSynopsisDefaultScrollFrame);
    CGFloat synopsisInterRowGap = MAX(SMPackageSynopsisInterRowGapMinimum,
                                      NSMinY(shortSynopsisDefaultScrollFrame) - NSMaxY(longSynopsisDefaultScrollFrame));
    CGFloat longSynopsisLabelYOffset = NSMinY(longSynopsisDefaultLabelFrame) - NSMaxY(longSynopsisDefaultScrollFrame);
    CGFloat defaultSynopsisBottomY = MIN(NSMinY(shortSynopsisDefaultScrollFrame), NSMinY(longSynopsisDefaultScrollFrame));
    CGFloat titleHeight = SlateInspectorRailSectionHeaderHeight();
    CGFloat statusHeight = SlateInspectorRailDisclosureRowHeight();
    CGFloat titleGap = SlateInspectorRailSectionGap();
    CGFloat defaultContentTopY = SlateWorkspacePrimaryPaneTableAnchorTopY()
        + titleHeight
        + SlateInspectorRailSectionHeaderYOffset();
    CGFloat defaultContentBottomY = defaultSynopsisBottomY;
    CGFloat defaultTopInset = NSHeight(defaultRootFrame) - defaultContentTopY;
    CGFloat defaultBottomInset = defaultContentBottomY;
    CGFloat contentTopY = NSMaxY(layoutBounds) - defaultTopInset;
    CGFloat contentBottomY = NSMinY(layoutBounds) + defaultBottomInset;
    if (contentTopY <= contentBottomY) {
        contentBottomY = contentTopY - 1.0;
    }
    CGFloat assetStackVerticalOffset = (NSMinY(layoutBounds) - NSMinY(defaultRootFrame)) - SMPackageAssetStackDownshift;
    [self applyAssetStackVerticalOffset:assetStackVerticalOffset];

    CGFloat readinessTopY = contentTopY - titleHeight - SlateInspectorRailSectionHeaderYOffset();
    CGFloat sharedContentTopY = contentTopY;

    CGFloat synopsisTopY = contentTopY;
    CGFloat metadataTopY = sharedContentTopY;
    CGFloat metadataBottomY = contentBottomY;
    CGFloat readinessBottomY = NSMinY(layoutBounds) + readinessBottomInset;
    BOOL suppressMetadataRailForPinnedReadiness = (_inspectorRailPinned
                                                   && showReadinessRail
                                                   && workspaceWidthForLayout < SlateInspectorRailPackageMinimumHostWidth());
    BOOL showMetadataRail = (!suppressMetadataRailForPinnedReadiness && sharedContentTopY > readinessBottomY);
    CGFloat metadataMatrixVerticalInset = SMPackageMetadataMatrixVerticalInset;
    CGFloat metadataTopInsetFromHeader = MAX(0.0, gap - SlateInspectorRailSectionHeaderYOffset());
    CGFloat metadataMatrixTopY = (metadataTopY + metadataTopInsetFromHeader) - 32.0;
    CGFloat metadataMatrixBottomFloorY = readinessBottomY + metadataInteriorInset;
    CGFloat metadataMatrixBottomY = MAX(metadataBottomY + metadataMatrixVerticalInset, metadataMatrixBottomFloorY);
    if (metadataMatrixTopY <= metadataMatrixBottomY) {
        metadataMatrixTopY = metadataTopY;
        metadataMatrixBottomY = metadataBottomY;
    }
    // Keep metadata matrix anchored at the top and shrink upward from the bottom
    // as vertical space compresses; do not force a minimum band height.
    CGFloat metadataBandHeight = MAX(1.0, metadataMatrixTopY - metadataMatrixBottomY);
    CGFloat synopsisDefaultRightEdge = layoutHorizontalOffset + MAX(NSMaxX(shortSynopsisDefaultScrollFrame),
                                           NSMaxX(longSynopsisDefaultScrollFrame)) + synopsisXOffset + synopsisXDelta;
    CGFloat metadataStartX = synopsisDefaultRightEdge + middleRailGap;
    CGFloat metadataWidth = MAX(SMPackageMetadataMinimumWidth, contentRailRightX - metadataStartX);
    CGFloat metadataMatrixX = metadataStartX + SMPackageMetadataMatrixXOffset();
    // Keep the outer metadata group geometry stable while enforcing a
    // symmetric inner inset (left/right) for matrix content.
    metadataMatrixX += metadataInteriorInset;
    metadataWidth = MAX(SMPackageMetadataColumnMinimumWidth,
                        metadataWidth - (metadataInteriorInset * 2.0));
    CGFloat metadataGroupInsetX = metadataInteriorInset;

    // Keep the metadata matrix in a 2-column layout until it is truly constrained.
    NSUInteger metadataColumnCount = 2;
    CGFloat metadataColumnWidth = floor((metadataWidth - (gap * (metadataColumnCount - 1))) / metadataColumnCount);
    if (metadataColumnWidth < SMPackageMetadataSingleColumnThreshold) {
        metadataColumnCount = 1;
        metadataColumnWidth = metadataWidth;
    }
    metadataColumnWidth = MAX(SMPackageMetadataColumnMinimumWidth, metadataColumnWidth);

    NSUInteger metadataRowCount = (metadataPanelCount + metadataColumnCount - 1) / metadataColumnCount;
    CGFloat effectiveMetadataGap = 0.0;
    if (metadataRowCount > 1) {
        CGFloat maxGapBudget = MAX(0.0, metadataBandHeight - (CGFloat)metadataRowCount);
        effectiveMetadataGap = MIN(gap, maxGapBudget / (metadataRowCount - 1));
    }
    CGFloat metadataRowHeight = ((metadataBandHeight - (effectiveMetadataGap * (metadataRowCount - 1))) / metadataRowCount);
    metadataRowHeight = MAX(1.0, metadataRowHeight);

    for (NSUInteger index = 0; index < metadataPanelCount; index++) {
        NSUInteger columnIndex = index % metadataColumnCount;
        NSUInteger rowIndex = index / metadataColumnCount;
        CGFloat frameX = metadataMatrixX + ((metadataColumnWidth + gap) * columnIndex);
        CGFloat frameY = metadataMatrixTopY - ((rowIndex + 1) * metadataRowHeight) - (rowIndex * effectiveMetadataGap);
        CGFloat panelScrollHeight = MAX(1.0, metadataRowHeight - metadataPanelLabelHeight - metadataPanelLabelGap);
        NSRect panelFrame = NSMakeRect(frameX, frameY, metadataColumnWidth, panelScrollHeight);
        NSRect panelLabelFrame = NSMakeRect(frameX,
                                            NSMaxY(panelFrame) + metadataPanelLabelGap,
                                            metadataColumnWidth,
                                            metadataPanelLabelHeight);
        NSView *panelView = [metadataPanels objectAtIndex:index];
        NSView *panelLabel = [metadataLabels objectAtIndex:index];
        [panelView setHidden:!showMetadataRail];
        [panelView setFrame:panelFrame];
        [panelLabel setHidden:!showMetadataRail];
        [panelLabel setFrame:panelLabelFrame];
    }

    // Establish baseline synopsis frames; metadata-visible layout below
    // stretches them vertically against the metadata group frame.
    CGFloat fixedSynopsisWidth = MAX(SMPackageSynopsisMinimumWidth, NSWidth(shortSynopsisDefaultScrollFrame));
    CGFloat fixedShortSynopsisHeight = MAX(1.0, NSHeight(shortSynopsisDefaultScrollFrame));
    CGFloat fixedLongSynopsisHeight = MAX(1.0, NSHeight(longSynopsisDefaultScrollFrame));
    CGFloat fixedSynopsisGap = MAX(SMPackageSynopsisInterRowGapMinimum, synopsisInterRowGap);

    shortSynopsisFrame.size.width = fixedSynopsisWidth;
    shortSynopsisFrame.size.height = fixedShortSynopsisHeight;
    shortSynopsisFrame.origin.y = floor(synopsisTopY - fixedShortSynopsisHeight);

    longSynopsisFrame.size.width = fixedSynopsisWidth;
    longSynopsisFrame.size.height = fixedLongSynopsisHeight;
    longSynopsisFrame.origin.y = floor(shortSynopsisFrame.origin.y
                                       - fixedLongSynopsisHeight
                                       - fixedSynopsisGap
                                       - SMPackageLongSynopsisExtraDrop);
    [shortSynopsisScroll setFrame:shortSynopsisFrame];
    [longSynopsisScroll setFrame:longSynopsisFrame];

    shortSynopsisLabelFrame.origin.y = floor(NSMaxY(shortSynopsisFrame) + shortSynopsisLabelYOffset);
    [shortSynopsisLabel setFrame:shortSynopsisLabelFrame];
    longSynopsisLabelFrame.origin.y = floor(NSMaxY(longSynopsisFrame) + longSynopsisLabelYOffset);
    [longSynopsisLabel setFrame:longSynopsisLabelFrame];

    [_metadataSectionLabel setStringValue:SMPackageSectionTitleMetadata];
    [_metadataSectionLabel setHidden:!showMetadataRail];
    [_metadataSectionLabel setFrame:NSMakeRect(metadataMatrixX,
                                               metadataTopY + SlateInspectorRailSectionHeaderYOffset(),
                                               metadataWidth,
                                               titleHeight)];

    if (!showReadinessRail) {
        [_readinessPresenter setRailHidden:YES];
    } else {
        NSRect readinessSectionFrame = NSMakeRect(rightRailX,
                                                  readinessTopY + SlateInspectorRailSectionHeaderYOffset(),
                                                  railWidth,
                                                  titleHeight);
        CGFloat readinessStatusY = readinessTopY - statusHeight - 2.0;
        NSRect readinessStatusFrame = NSMakeRect(rightRailX, readinessStatusY, railWidth, statusHeight);

        CGFloat readinessTextTopLimitY = readinessTopY - statusHeight - titleGap;
        CGFloat availableForReadinessText = MAX(0.0, readinessTextTopLimitY - readinessBottomY);
        CGFloat minimumReadinessTextHeight = titleHeight + titleGap + SlateInspectorRailWarningBlockMinHeight();
        CGFloat desiredReadinessTextHeight = floor(availableForReadinessText * SMPackageReadinessTextRatio);
        CGFloat readinessScrollHeight = MAX(minimumReadinessTextHeight, desiredReadinessTextHeight);
        readinessScrollHeight = MIN(availableForReadinessText, readinessScrollHeight);
        if (readinessScrollHeight < minimumReadinessTextHeight) {
            readinessScrollHeight = availableForReadinessText;
        }

        NSRect readinessScrollFrame = NSMakeRect(rightRailX,
                                                 readinessBottomY,
                                                 railWidth,
                                                 readinessScrollHeight);
        NSRect pinFrame = NSMakeRect((rightRailX + railWidth) - SlateInspectorRailPinControlWidth(),
                                     NSMinY(readinessSectionFrame),
                                     SlateInspectorRailPinControlWidth(),
                                     SlateInspectorRailDisclosureRowHeight());
        [_readinessPresenter applySectionFrame:readinessSectionFrame
                                   statusFrame:readinessStatusFrame
                                   scrollFrame:readinessScrollFrame
                                      pinFrame:pinFrame
                                    pinVisible:YES];
    }

    CGFloat metadataHeaderInsetX = SMPackageMetadataGroupHeaderInsetX;
    CGFloat metadataHeaderTopInset = SMPackageMetadataGroupHeaderTopInset;
    CGFloat metadataGroupTopY = sharedContentTopY;
    CGFloat metadataGroupBottomY = readinessBottomY;
    if (metadataGroupTopY > metadataGroupBottomY) {
        NSRect metadataGroupFrame = NSMakeRect(metadataMatrixX - metadataGroupInsetX,
                                               metadataGroupBottomY,
                                               metadataWidth + (metadataGroupInsetX * 2.0),
                                               metadataGroupTopY - metadataGroupBottomY);
        [_metadataGroupBox setFrame:metadataGroupFrame];
        [_metadataGroupBox setHidden:!showMetadataRail];
        [_metadataSectionLabel setFrame:NSMakeRect(NSMinX(metadataGroupFrame) + metadataHeaderInsetX,
                                                   NSMaxY(metadataGroupFrame) - titleHeight - metadataHeaderTopInset,
                                                   MAX(1.0, NSWidth(metadataGroupFrame) - metadataHeaderInsetX - 8.0),
                                                   titleHeight)];
    } else {
        [_metadataGroupBox setHidden:YES];
        [_metadataSectionLabel setHidden:YES];
    }

    if (showMetadataRail && _metadataGroupBox != nil && ![_metadataGroupBox isHidden]) {
        NSRect metadataGroupFrame = [_metadataGroupBox frame];
        CGFloat synopsisTargetTopY = floor(NSMaxY(metadataGroupFrame));
        CGFloat synopsisTargetBottomY = floor(NSMinY(metadataGroupFrame));
        CGFloat synopsisTargetHeight = MAX(1.0, synopsisTargetTopY - synopsisTargetBottomY);
        CGFloat shortLabelHeight = MAX(1.0, NSHeight(shortSynopsisLabelFrame));
        CGFloat longLabelHeight = MAX(1.0, NSHeight(longSynopsisLabelFrame));
        CGFloat shortLabelToScrollGap = MAX(0.0, shortSynopsisLabelYOffset);
        CGFloat longLabelToScrollGap = MAX(0.0, longSynopsisLabelYOffset);
        CGFloat shortScrollToLongLabelGap = MAX(0.0, NSMinY(shortSynopsisDefaultScrollFrame) - NSMaxY(longSynopsisDefaultLabelFrame));
        CGFloat fixedSynopsisChromeHeight = shortLabelHeight
            + shortLabelToScrollGap
            + shortScrollToLongLabelGap
            + longLabelHeight
            + longLabelToScrollGap;
        CGFloat availableSynopsisTextHeight = MAX(2.0, synopsisTargetHeight - fixedSynopsisChromeHeight);
        CGFloat defaultSynopsisTextHeight = fixedShortSynopsisHeight + fixedLongSynopsisHeight;
        CGFloat shortSynopsisRatio = (defaultSynopsisTextHeight > 0.0)
            ? (fixedShortSynopsisHeight / defaultSynopsisTextHeight)
            : 0.5;
        CGFloat stretchedShortSynopsisHeight = MAX(1.0, floor(availableSynopsisTextHeight * shortSynopsisRatio));

        shortSynopsisFrame.size.height = stretchedShortSynopsisHeight;
        shortSynopsisLabelFrame.origin.y = synopsisTargetTopY - shortLabelHeight;
        shortSynopsisFrame.origin.y = shortSynopsisLabelFrame.origin.y
            - shortLabelToScrollGap
            - stretchedShortSynopsisHeight;
        longSynopsisLabelFrame.origin.y = NSMinY(shortSynopsisFrame)
            - shortScrollToLongLabelGap
            - longLabelHeight;
        longSynopsisFrame.origin.y = synopsisTargetBottomY;
        longSynopsisFrame.size.height = MAX(1.0, NSMinY(longSynopsisLabelFrame)
                                            - longLabelToScrollGap
                                            - synopsisTargetBottomY);

        [shortSynopsisScroll setFrame:shortSynopsisFrame];
        [longSynopsisScroll setFrame:longSynopsisFrame];
        [shortSynopsisLabel setFrame:shortSynopsisLabelFrame];
        [longSynopsisLabel setFrame:longSynopsisLabelFrame];
    }

    [self alignPosterArtLaneBottomToLongSynopsisFrame:longSynopsisFrame];
}

- (void)applyWorkspaceLayoutForWidth:(CGFloat)workspaceWidth
{
    [self ensurePackageSectionedFlowViews];

    SMPackageRailMode railMode = SMPackageRailModeForWidth(workspaceWidth);
    [self applyPackagePanelsForRailMode:railMode];
}

#pragma mark - Mode Switch and Probe

- (void)captureModeSwitchScrollSnapshotForTextView:(NSTextView *)textView
                                              key:(NSString *)key
                                             into:(NSMutableDictionary *)snapshot
{
    if (!SMPackStringHasContent(key) || textView == nil || snapshot == nil) {
        return;
    }

    NSDictionary *scrollSnapshot = SMPackageScrollSnapshotForScrollView([self scrollViewForPackageTextView:textView]);
    if (scrollSnapshot != nil) {
        [snapshot setObject:scrollSnapshot forKey:key];
    }
}

- (void)captureModeSwitchScrollSnapshotForScrollView:(NSScrollView *)scrollView
                                                key:(NSString *)key
                                               into:(NSMutableDictionary *)snapshot
{
    if (!SMPackStringHasContent(key) || scrollView == nil || snapshot == nil) {
        return;
    }

    NSDictionary *scrollSnapshot = SMPackageScrollSnapshotForScrollView(scrollView);
    if (scrollSnapshot != nil) {
        [snapshot setObject:scrollSnapshot forKey:key];
    }
}

- (void)restoreModeSwitchScrollSnapshotForTextView:(NSTextView *)textView
                                              key:(NSString *)key
                                       fromSnapshot:(NSDictionary *)snapshot
{
    if (!SMPackStringHasContent(key) || textView == nil || ![snapshot isKindOfClass:[NSDictionary class]]) {
        return;
    }

    NSDictionary *scrollSnapshot = [snapshot objectForKey:key];
    SMPackageRestoreScrollSnapshotForScrollView([self scrollViewForPackageTextView:textView], scrollSnapshot);
}

- (void)restoreModeSwitchScrollSnapshotForScrollView:(NSScrollView *)scrollView
                                                key:(NSString *)key
                                        fromSnapshot:(NSDictionary *)snapshot
{
    if (!SMPackStringHasContent(key) || scrollView == nil || ![snapshot isKindOfClass:[NSDictionary class]]) {
        return;
    }

    NSDictionary *scrollSnapshot = [snapshot objectForKey:key];
    SMPackageRestoreScrollSnapshotForScrollView(scrollView, scrollSnapshot);
}

- (NSDictionary *)modeSwitchContextSnapshot
{
    NSMutableDictionary *snapshot = [NSMutableDictionary dictionary];
    for (NSDictionary *panel in [self synopsisPanels]) {
        NSString *snapshotKey = [panel objectForKey:SMPackageMetadataPanelKeySnapshot];
        NSTextView *textView = [panel objectForKey:SMPackageMetadataPanelKeyTextView];
        [self captureModeSwitchScrollSnapshotForTextView:textView key:snapshotKey into:snapshot];
    }
    for (NSDictionary *panel in [self metadataCollectionPanels]) {
        NSString *snapshotKey = [panel objectForKey:SMPackageMetadataPanelKeySnapshot];
        NSTextView *textView = [panel objectForKey:SMPackageMetadataPanelKeyTextView];
        [self captureModeSwitchScrollSnapshotForTextView:textView key:snapshotKey into:snapshot];
    }
    [self captureModeSwitchScrollSnapshotForScrollView:[_readinessPresenter scrollView] key:@"readinessScroll" into:snapshot];

    return snapshot;
}

- (NSDictionary *)layoutProbeSnapshot
{
    NSView *rootView = [self view];
    NSRect rootBounds = (rootView != nil) ? [rootView bounds] : NSZeroRect;
    NSRect metadataGroupFrame = (_metadataGroupBox != nil) ? [_metadataGroupBox frame] : NSZeroRect;
    NSScrollView *readinessScrollView = [_readinessPresenter scrollView];
    NSTextField *readinessSectionLabel = [_readinessPresenter sectionLabel];
    NSButton *inspectorPinButton = [_readinessPresenter pinButton];
    NSRect readinessFrame = (readinessScrollView != nil) ? [readinessScrollView frame] : NSZeroRect;
    NSRect readinessLabelFrame = (readinessSectionLabel != nil) ? [readinessSectionLabel frame] : NSZeroRect;
    NSRect pinFrame = (inspectorPinButton != nil) ? [inspectorPinButton frame] : NSZeroRect;
    NSScrollView *shortSynopsisScroll = [self synopsisScrollViewForTarget:SlatePackageSnapshotTargetSynopsisShort];
    NSRect shortSynopsisFrame = (shortSynopsisScroll != nil) ? [shortSynopsisScroll frame] : NSZeroRect;
    CGFloat rootMaxX = NSMaxX(rootBounds);

    BOOL metadataVisible = (_metadataGroupBox != nil && ![_metadataGroupBox isHidden] && NSWidth(metadataGroupFrame) > 0.0);
    BOOL readinessVisible = (readinessScrollView != nil && ![readinessScrollView isHidden] && NSWidth(readinessFrame) > 0.0);
    BOOL pinVisible = (inspectorPinButton != nil && ![inspectorPinButton isHidden]);

    NSMutableDictionary *layoutProbe = [NSMutableDictionary dictionary];
    [layoutProbe setObject:SMPackageProbeRect(rootBounds) forKey:@"rootBounds"];
    [layoutProbe setObject:[NSNumber numberWithDouble:NSWidth(rootBounds)] forKey:@"workspaceWidth"];
    [layoutProbe setObject:SMPackageProbeRailModeCode(NSWidth(rootBounds)) forKey:@"workspaceWidthClass"];
    [layoutProbe setObject:SMPackageProbeRailModeName(NSWidth(rootBounds)) forKey:@"workspaceRailMode"];
    [layoutProbe setObject:[NSNumber numberWithBool:metadataVisible] forKey:@"showMetadataRail"];
    [layoutProbe setObject:[NSNumber numberWithBool:readinessVisible] forKey:@"showReadinessRail"];
    [layoutProbe setObject:[NSNumber numberWithBool:pinVisible] forKey:@"pinVisible"];
    [layoutProbe setObject:[NSNumber numberWithBool:_inspectorRailPinned] forKey:@"pinState"];
    [layoutProbe setObject:SMPackageProbeRect(shortSynopsisFrame) forKey:@"synopsisFrame"];
    [layoutProbe setObject:SMPackageProbeRect(metadataGroupFrame) forKey:@"metadataGroupFrame"];
    [layoutProbe setObject:SMPackageProbeRect(readinessFrame) forKey:@"readinessFrame"];
    [layoutProbe setObject:SMPackageProbeRect(readinessLabelFrame) forKey:@"readinessLabelFrame"];
    [layoutProbe setObject:SMPackageProbeRect(pinFrame) forKey:@"pinFrame"];

    if (metadataVisible && NSWidth(shortSynopsisFrame) > 0.0) {
        [layoutProbe setObject:[NSNumber numberWithDouble:(NSMinX(metadataGroupFrame) - NSMaxX(shortSynopsisFrame))]
                        forKey:@"gapSynopsisToMetadata"];
        [layoutProbe setObject:[NSNumber numberWithDouble:(rootMaxX - NSMaxX(metadataGroupFrame))]
                        forKey:@"rightInsetMetadata"];
    }
    if (metadataVisible) {
        NSArray *metadataPanels = [self metadataCollectionPanels];
        BOOL hasMetadataPanelFrame = NO;
        CGFloat metadataPanelsMinX = 0.0;
        CGFloat metadataPanelsMaxX = 0.0;
        CGFloat metadataPanelsMinY = 0.0;
        NSMutableArray *columnOrigins = [NSMutableArray array];
        for (NSDictionary *panel in metadataPanels) {
            NSScrollView *scrollView = [panel objectForKey:SMPackageMetadataPanelKeyScrollView];
            if (![scrollView isKindOfClass:[NSScrollView class]] || [scrollView isHidden]) {
                continue;
            }
            NSRect panelFrame = [scrollView frame];
            if (!hasMetadataPanelFrame) {
                hasMetadataPanelFrame = YES;
                metadataPanelsMinX = NSMinX(panelFrame);
                metadataPanelsMaxX = NSMaxX(panelFrame);
                metadataPanelsMinY = NSMinY(panelFrame);
            } else {
                metadataPanelsMinX = MIN(metadataPanelsMinX, NSMinX(panelFrame));
                metadataPanelsMaxX = MAX(metadataPanelsMaxX, NSMaxX(panelFrame));
                metadataPanelsMinY = MIN(metadataPanelsMinY, NSMinY(panelFrame));
            }

            NSNumber *originX = [NSNumber numberWithDouble:NSMinX(panelFrame)];
            if (![columnOrigins containsObject:originX]) {
                [columnOrigins addObject:originX];
            }
        }

        if (hasMetadataPanelFrame) {
            [layoutProbe setObject:[NSNumber numberWithDouble:(metadataPanelsMinX - NSMinX(metadataGroupFrame))]
                            forKey:@"metadataInnerInsetLeft"];
            [layoutProbe setObject:[NSNumber numberWithDouble:(NSMaxX(metadataGroupFrame) - metadataPanelsMaxX)]
                            forKey:@"metadataInnerInsetRight"];
            [layoutProbe setObject:[NSNumber numberWithDouble:(metadataPanelsMinY - NSMinY(metadataGroupFrame))]
                            forKey:@"metadataInnerInsetBottom"];

            if ([columnOrigins count] > 1) {
                NSArray *sortedOrigins = [columnOrigins sortedArrayUsingSelector:@selector(compare:)];
                CGFloat leftOrigin = [[sortedOrigins objectAtIndex:0] doubleValue];
                CGFloat rightOrigin = [[sortedOrigins objectAtIndex:1] doubleValue];
                CGFloat leftColumnRight = 0.0;
                CGFloat rightColumnLeft = 0.0;
                BOOL hasLeftColumn = NO;
                BOOL hasRightColumn = NO;
                for (NSDictionary *panel in metadataPanels) {
                    NSScrollView *scrollView = [panel objectForKey:SMPackageMetadataPanelKeyScrollView];
                    if (![scrollView isKindOfClass:[NSScrollView class]] || [scrollView isHidden]) {
                        continue;
                    }
                    NSRect panelFrame = [scrollView frame];
                    CGFloat panelOrigin = NSMinX(panelFrame);
                    if (fabs(panelOrigin - leftOrigin) < 0.5) {
                        leftColumnRight = hasLeftColumn ? MAX(leftColumnRight, NSMaxX(panelFrame)) : NSMaxX(panelFrame);
                        hasLeftColumn = YES;
                    } else if (fabs(panelOrigin - rightOrigin) < 0.5) {
                        rightColumnLeft = hasRightColumn ? MIN(rightColumnLeft, NSMinX(panelFrame)) : NSMinX(panelFrame);
                        hasRightColumn = YES;
                    }
                }
                if (hasLeftColumn && hasRightColumn) {
                    [layoutProbe setObject:[NSNumber numberWithDouble:(rightColumnLeft - leftColumnRight)]
                                    forKey:@"metadataColumnGap"];
                }
            }
        }
    }
    if (metadataVisible && readinessVisible) {
        [layoutProbe setObject:[NSNumber numberWithDouble:(NSMinX(readinessFrame) - NSMaxX(metadataGroupFrame))]
                        forKey:@"gapMetadataToReadiness"];
    }
    if (readinessVisible) {
        [layoutProbe setObject:[NSNumber numberWithDouble:(rootMaxX - NSMaxX(readinessFrame))]
                        forKey:@"rightInsetReadiness"];
    }
    if (pinVisible && readinessSectionLabel != nil) {
        [layoutProbe setObject:[NSNumber numberWithDouble:(NSMinY(pinFrame) - NSMinY(readinessLabelFrame))]
                        forKey:@"pinLabelDeltaY"];
    }

    NSTextField *localeLabel = nil;
    NSArray *metadataLabels = [self metadataCollectionLabels];
    if ([metadataLabels count] > 0 && [[metadataLabels objectAtIndex:0] isKindOfClass:[NSTextField class]]) {
        localeLabel = [metadataLabels objectAtIndex:0];
    }
    if (_metadataSectionLabel != nil && localeLabel != nil) {
        CGFloat metadataLabelTextTopY = SlateInspectorRailLabelTextTopY(_metadataSectionLabel);
        CGFloat localeLabelTextTopY = SlateInspectorRailLabelTextTopY(localeLabel);
        [layoutProbe setObject:[NSNumber numberWithDouble:metadataLabelTextTopY]
                        forKey:@"metadataLabelTextTopY"];
        [layoutProbe setObject:[NSNumber numberWithDouble:localeLabelTextTopY]
                        forKey:@"localeLabelTextTopY"];
        [layoutProbe setObject:[NSNumber numberWithDouble:(metadataLabelTextTopY - localeLabelTextTopY)]
                        forKey:@"metadataLocaleTopDeltaY"];
    }

    return layoutProbe;
}

- (void)restoreModeSwitchContextSnapshot:(NSDictionary *)snapshot
{
    if (![snapshot isKindOfClass:[NSDictionary class]]) {
        return;
    }

    for (NSDictionary *panel in [self synopsisPanels]) {
        NSString *snapshotKey = [panel objectForKey:SMPackageMetadataPanelKeySnapshot];
        NSTextView *textView = [panel objectForKey:SMPackageMetadataPanelKeyTextView];
        [self restoreModeSwitchScrollSnapshotForTextView:textView key:snapshotKey fromSnapshot:snapshot];
    }
    for (NSDictionary *panel in [self metadataCollectionPanels]) {
        NSString *snapshotKey = [panel objectForKey:SMPackageMetadataPanelKeySnapshot];
        NSTextView *textView = [panel objectForKey:SMPackageMetadataPanelKeyTextView];
        [self restoreModeSwitchScrollSnapshotForTextView:textView key:snapshotKey fromSnapshot:snapshot];
    }
    [self restoreModeSwitchScrollSnapshotForScrollView:[_readinessPresenter scrollView] key:@"readinessScroll" fromSnapshot:snapshot];
}

- (NSView *)preferredModeFirstResponderView
{
    return [self synopsisTextViewForTarget:SlatePackageSnapshotTargetSynopsisShort];
}

#pragma mark - Teardown

- (void)dealloc
{
    [_synopsisPanels release];
    [_metadataGroupBox release];
    [_metadataSectionLabel release];
    [_readinessPresenter release];
    [_metadataCollectionPanels release];
    [_canonicalValidationFindings release];
    [super dealloc];
}

@end
