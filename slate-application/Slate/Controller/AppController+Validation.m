//
//  AppController+Validation.m
//  Slate
//

#import "AppController+Validation.h"
#import "AppController+PaneHost.h"

#import "DictionaryKeys.h"
#import "Movie/SMMovie.h"
#import "Movie/SMMoviePlaybackSupport.h"
#import "Runtime/SlateRuntimeBridge.h"
#import "Runtime/SlateValidationRuntimeContract.h"
#import "Validation/SMValidationCanonicalDictionaryKeys.h"
#import "TimelineState.h"
#import "ChapterViewController.h"
#import "TrackViewController.h"
#import "PackageViewController.h"

static const CGFloat SMReadinessReportDialogBodyWidth = 620.0;
static const CGFloat SMReadinessReportDialogMinimumBodyHeight = 140.0;
static const CGFloat SMReadinessReportDialogMaximumBodyHeight = 440.0;
static const CGFloat SMReadinessReportDialogTextInset = 8.0;

@interface SMReadinessReportDialogTextView : NSTextView
@end

@implementation SMReadinessReportDialogTextView

- (BOOL)performDefaultButtonClick:(id)sender
{
    NSWindow *window = [self window];
    NSButtonCell *defaultButtonCell = [window defaultButtonCell];
    NSView *buttonView = [defaultButtonCell controlView];
    if ([buttonView isKindOfClass:[NSButton class]]) {
        [(NSButton *)buttonView performClick:sender];
        return YES;
    }
    return NO;
}

- (void)insertNewline:(id)sender
{
    if (![self performDefaultButtonClick:sender]) {
        [super insertNewline:sender];
    }
}

- (void)insertNewlineIgnoringFieldEditor:(id)sender
{
    if (![self performDefaultButtonClick:sender]) {
        [super insertNewlineIgnoringFieldEditor:sender];
    }
}

@end

static CGFloat SMReadinessReportDialogBodyHeightForText(NSString *text)
{
    NSString *body = (text ?: @"");
    NSFont *font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
    NSDictionary *attributes = [NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName];
    CGFloat textWidth = SMReadinessReportDialogBodyWidth - (SMReadinessReportDialogTextInset * 2.0);
    NSRect bounds = [body boundingRectWithSize:NSMakeSize(textWidth, CGFLOAT_MAX)
                                       options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading)
                                    attributes:attributes];
    CGFloat height = ceil(NSHeight(bounds)) + (SMReadinessReportDialogTextInset * 2.0);
    height = MAX(SMReadinessReportDialogMinimumBodyHeight, height);
    return MIN(SMReadinessReportDialogMaximumBodyHeight, height);
}

static NSView *SMReadinessReportDialogBodyView(NSString *text)
{
    CGFloat bodyHeight = SMReadinessReportDialogBodyHeightForText(text);
    NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(0.0,
                                                                                0.0,
                                                                                SMReadinessReportDialogBodyWidth,
                                                                                bodyHeight)] autorelease];
    [scrollView setBorderType:NSBezelBorder];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setAutohidesScrollers:YES];

    NSTextView *textView = [[[SMReadinessReportDialogTextView alloc] initWithFrame:NSMakeRect(0.0,
                                                                                              0.0,
                                                                                              SMReadinessReportDialogBodyWidth,
                                                                                              bodyHeight)] autorelease];
    [textView setEditable:NO];
    [textView setSelectable:YES];
    [textView setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
    [textView setString:(text ?: @"")];
    [textView setHorizontallyResizable:NO];
    [textView setVerticallyResizable:YES];
    [textView setAutoresizingMask:NSViewWidthSizable];
    [[textView textContainer] setWidthTracksTextView:YES];
    [[textView textContainer] setContainerSize:NSMakeSize(SMReadinessReportDialogBodyWidth - (SMReadinessReportDialogTextInset * 2.0),
                                                          CGFLOAT_MAX)];

    [scrollView setDocumentView:textView];
    return scrollView;
}

static NSString *SMCanonicalFindingCategoryCode(NSDictionary *finding)
{
    NSString *categoryCode = [finding objectForKey:SMValidationFindingKeyCategory];
    return [categoryCode isKindOfClass:[NSString class]] ? categoryCode : @"";
}

static BOOL SMCanonicalFindingHasProjectionContract(NSDictionary *finding)
{
    if (![finding isKindOfClass:[NSDictionary class]]) {
        return NO;
    }

    return ([[finding objectForKey:SMValidationFindingKeyCode] isKindOfClass:[NSString class]]
            && [[finding objectForKey:SMValidationFindingKeySeverity] isKindOfClass:[NSString class]]
            && [[finding objectForKey:SMValidationFindingKeyCategory] isKindOfClass:[NSString class]]
            && [[finding objectForKey:SMValidationFindingKeyScope] isKindOfClass:[NSString class]]
            && [[finding objectForKey:SMValidationFindingKeyTitle] isKindOfClass:[NSString class]]
            && [[finding objectForKey:SMValidationFindingKeyEvidence] isKindOfClass:[NSString class]]);
}

static NSArray *SMCanonicalFindingsFromReportPayload(NSDictionary *reportPayload)
{
    if (![reportPayload isKindOfClass:[NSDictionary class]]) {
        return [NSArray array];
    }

    NSArray *findings = [reportPayload objectForKey:SMValidationReportKeyFindings];
    if (![findings isKindOfClass:[NSArray class]] || [findings count] == 0) {
        return [NSArray array];
    }

    NSMutableArray *canonicalFindings = [NSMutableArray arrayWithCapacity:[findings count]];
    for (NSDictionary *finding in findings) {
        if (SMCanonicalFindingHasProjectionContract(finding)) {
            [canonicalFindings addObject:finding];
        }
    }
    return canonicalFindings;
}

static NSArray *SMCanonicalFindingsForCategories(NSArray *findings, NSArray *categoryCodes)
{
    if (![findings isKindOfClass:[NSArray class]] || [findings count] == 0) {
        return [NSArray array];
    }
    if (![categoryCodes isKindOfClass:[NSArray class]] || [categoryCodes count] == 0) {
        return [NSArray array];
    }

    NSSet *categorySet = [NSSet setWithArray:categoryCodes];
    NSMutableArray *filteredFindings = [NSMutableArray array];
    for (NSDictionary *finding in findings) {
        if (![finding isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        if ([categorySet containsObject:SMCanonicalFindingCategoryCode(finding)]) {
            [filteredFindings addObject:finding];
        }
    }

    return filteredFindings;
}

static double SMObservedMovieFrameRate(SMMovie *movie, double fallbackFrameRate)
{
    NSArray *videoTracks = [movie tracksOfMediaType:SMMediaTypeVideo];
    for (id track in videoTracks) {
        if (![track respondsToSelector:@selector(media)]) {
            continue;
        }

        SMMedia *media = [track media];
        NSNumber *frameRateNumber = [media attributeForKey:SMMediaSampleCountAttribute];
        double frameRate = [frameRateNumber doubleValue];
        if (frameRate > 0.0) {
            return frameRate;
        }
    }

    return fallbackFrameRate;
}

static NSArray *SMObservedTextTrackSourcePathsForMovie(SMMovie *movie)
{
    NSMutableArray *sourcePaths = [NSMutableArray array];
    for (SMTrack *track in [movie subtitleSidecarTracks]) {
        NSURL *sourceURL = [track attributeForKey:SMPlaybackSourceURLAttributeKey];
        if ([sourceURL isKindOfClass:[NSURL class]] && [sourceURL isFileURL] && [[sourceURL path] length] > 0) {
            [sourcePaths addObject:[sourceURL path]];
        }
    }
    return sourcePaths;
}

static id SMValidationJSONSafeObject(id value)
{
    if (value == nil) {
        return nil;
    }
    if ([value isKindOfClass:[NSString class]]
        || [value isKindOfClass:[NSNumber class]]
        || [value isKindOfClass:[NSNull class]]) {
        return value;
    }
    if ([value isKindOfClass:[NSURL class]]) {
        return [(NSURL *)value path] ?: [(NSURL *)value absoluteString];
    }
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *safeArray = [NSMutableArray arrayWithCapacity:[(NSArray *)value count]];
        for (id item in (NSArray *)value) {
            id safeItem = SMValidationJSONSafeObject(item);
            [safeArray addObject:(safeItem ?: [NSNull null])];
        }
        return safeArray;
    }
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *safeDictionary = [NSMutableDictionary dictionaryWithCapacity:[(NSDictionary *)value count]];
        for (id key in (NSDictionary *)value) {
            if (![key isKindOfClass:[NSString class]]) {
                continue;
            }
            id safeValue = SMValidationJSONSafeObject([(NSDictionary *)value objectForKey:key]);
            [safeDictionary setObject:(safeValue ?: [NSNull null]) forKey:key];
        }
        return safeDictionary;
    }

    return [value description] ?: @"";
}

static void SMValidationSetString(NSMutableDictionary *dictionary, NSString *key, NSString *value)
{
    if ([value isKindOfClass:[NSString class]] && [value length] > 0) {
        [dictionary setObject:value forKey:key];
    }
}

static NSUInteger SMValidationReportSummaryCount(NSDictionary *report, NSString *key)
{
    NSDictionary *summary = [report objectForKey:SMValidationReportKeySummary];
    NSNumber *count = [summary isKindOfClass:[NSDictionary class]] ? [summary objectForKey:key] : nil;
    return [count isKindOfClass:[NSNumber class]] ? [count unsignedIntegerValue] : 0;
}

static NSString *SMValidationAlertTitleForCanonicalReport(NSDictionary *report)
{
    NSUInteger blockerCount = SMValidationReportSummaryCount(report, SMValidationSummaryKeyBlockers);
    NSUInteger warningCount = SMValidationReportSummaryCount(report, SMValidationSummaryKeyWarnings);

    if (blockerCount > 0) {
        return [NSString stringWithFormat:@"Readiness: %lu blocker%@", (unsigned long)blockerCount, blockerCount == 1 ? @"" : @"s"];
    }
    if (warningCount > 0) {
        return [NSString stringWithFormat:@"Readiness: %lu warning%@", (unsigned long)warningCount, warningCount == 1 ? @"" : @"s"];
    }
    return @"Readiness: Pass";
}

static NSString *SMValidationOperatorTextForCanonicalReport(NSDictionary *report)
{
    NSString *operatorText = [report objectForKey:SMValidationReportKeyOperatorText];
    return [operatorText isKindOfClass:[NSString class]] ? operatorText : @"";
}

@implementation AppController (Validation)

- (void)ensureValidationPaneControllersLoaded
{
    [self ensureTrackViewControllerLoaded];
    [self ensureChapterViewControllerLoaded];
    [self ensurePackageViewControllerLoaded];
}

- (void)applyCanonicalValidationFindingsFromReport:(NSDictionary *)canonicalReport
{
    NSArray *canonicalFindings = SMCanonicalFindingsFromReportPayload(canonicalReport);

    [_trackViewController applyCanonicalValidationFindings:SMCanonicalFindingsForCategories(canonicalFindings,
                                                                                             [NSArray arrayWithObjects:SMValidationCategoryCodeTracks, SMValidationCategoryCodeRoles, nil])];
    [_chapterViewController applyCanonicalValidationFindings:SMCanonicalFindingsForCategories(canonicalFindings,
                                                                                               [NSArray arrayWithObject:SMValidationCategoryCodeChapters])];
    [_packageViewController applyCanonicalValidationFindings:SMCanonicalFindingsForCategories(canonicalFindings,
                                                                                               [NSArray arrayWithObjects:SMValidationCategoryCodePackage, SMValidationCategoryCodeMetadata, nil])];
}

- (NSDictionary *)currentValidationObservedStatePayload
{
    [self ensureValidationPaneControllersLoaded];

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    [payload setObject:SlateValidationObservedStateSchemaVersion1 forKey:SlateValidationObservedStateKeySchemaVersion];
    [payload setObject:[NSNumber numberWithBool:(_movie != nil)] forKey:SlateValidationObservedStateKeyHasMovie];

    if (_movie != nil) {
        NSSize naturalSize = [self naturalSize];
        SMValidationSetString(payload, SlateValidationObservedStateKeyObservedMoviePath, [[_movie URL] path]);
        SMValidationSetString(payload, SlateValidationObservedStateKeyObservedMovieDisplayName, [_movie attributeForKey:SMMovieDisplayNameAttribute]);
        [payload setObject:[NSNumber numberWithDouble:naturalSize.width] forKey:SlateValidationObservedStateKeyObservedMovieNaturalWidth];
        [payload setObject:[NSNumber numberWithDouble:naturalSize.height] forKey:SlateValidationObservedStateKeyObservedMovieNaturalHeight];
        [payload setObject:[NSNumber numberWithDouble:SMObservedMovieFrameRate(_movie, _movieFrameRate)] forKey:SlateValidationObservedStateKeyObservedFrameRate];
        [payload setObject:[NSNumber numberWithLongLong:[_movie currentTimeValue]] forKey:SlateValidationObservedStateKeyObservedMovieCurrentTimeValue];
        [payload setObject:[NSNumber numberWithLongLong:[_movie durationTimeValue]] forKey:SlateValidationObservedStateKeyObservedMovieDurationTimeValue];
        [payload setObject:[NSNumber numberWithLong:[_movie timeScale]] forKey:SlateValidationObservedStateKeyObservedMovieTimeScale];
        [payload setObject:[NSNumber numberWithUnsignedInteger:[[_movie tracksOfMediaType:SMMediaTypeVideo] count]] forKey:SlateValidationObservedStateKeyObservedVideoTrackCount];
        [payload setObject:[NSNumber numberWithUnsignedInteger:[[_movie tracksOfMediaType:SMMediaTypeSound] count]] forKey:SlateValidationObservedStateKeyObservedAudioTrackCount];
        NSUInteger observedMovieTextTrackCount = [[_movie tracksOfMediaType:SMMediaTypeText] count]
            + [[_movie tracksOfMediaType:SMMediaTypeSubtitle] count]
            + [[_movie tracksOfMediaType:SMMediaTypeClosedCaption] count];
        NSUInteger observedPlaybackOnlyTextTrackCount = [[_movie subtitleSidecarTracks] count];
        [payload setObject:[NSNumber numberWithUnsignedInteger:observedMovieTextTrackCount] forKey:SlateValidationObservedStateKeyObservedMovieTextTrackCount];
        [payload setObject:[NSNumber numberWithUnsignedInteger:observedPlaybackOnlyTextTrackCount] forKey:SlateValidationObservedStateKeyObservedPlaybackOnlyTextTrackCount];
        [payload setObject:SMObservedTextTrackSourcePathsForMovie(_movie) forKey:SlateValidationObservedStateKeyObservedTextTrackSourcePaths];
        [payload setObject:[NSNumber numberWithUnsignedInteger:(observedMovieTextTrackCount + observedPlaybackOnlyTextTrackCount)] forKey:SlateValidationObservedStateKeyObservedTextTrackCount];

        if (_trackViewController != nil) {
            NSArray *trackRows = [_trackViewController validationObservedTrackRows];
            [payload setObject:[NSNumber numberWithBool:YES] forKey:SlateValidationObservedStateKeyHasObservedTrackState];
            [payload setObject:(SMValidationJSONSafeObject(trackRows) ?: [NSArray array]) forKey:SlateValidationObservedStateKeyObservedTrackRows];
            [payload setObject:[NSNumber numberWithInteger:[_trackViewController selectedAssetTypeID]] forKey:SlateValidationObservedStateKeyObservedAssetTypeID];
        }

        if (_chapterViewController != nil) {
            NSArray *chapterRows = [_chapterViewController validationObservedChapterRows];
            [payload setObject:[NSNumber numberWithBool:YES] forKey:SlateValidationObservedStateKeyHasObservedChapterState];
            [payload setObject:[NSNumber numberWithUnsignedInteger:[chapterRows count]] forKey:SlateValidationObservedStateKeyObservedChapterRowCount];
            [payload setObject:(SMValidationJSONSafeObject(chapterRows) ?: [NSArray array]) forKey:SlateValidationObservedStateKeyObservedChapterRows];
        }
    }

    if (_timelineState != nil) {
        [payload setObject:[NSNumber numberWithBool:YES] forKey:SlateValidationObservedStateKeyHasObservedTimelineState];
        [payload setObject:[NSNumber numberWithDouble:[_timelineState duration]] forKey:SlateValidationObservedStateKeyObservedTimelineDuration];
        [payload setObject:[NSNumber numberWithDouble:[_timelineState currentTime]] forKey:SlateValidationObservedStateKeyObservedTimelineCurrentTime];
        [payload setObject:[NSNumber numberWithDouble:[_timelineState selectionStart]] forKey:SlateValidationObservedStateKeyObservedTimelineSelectionStart];
        [payload setObject:[NSNumber numberWithDouble:[_timelineState selectionEnd]] forKey:SlateValidationObservedStateKeyObservedTimelineSelectionEnd];
    }

    return payload;
}

- (NSDictionary *)currentValidationReport
{
    NSDictionary *report = [SlateRuntimeBridge validationReportForPackagePath:_packagePath
                                                             observedState:[self currentValidationObservedStatePayload]];
    [self applyCanonicalValidationFindingsFromReport:report];
    return report;
}

- (void)refreshValidationViewAdapters
{
    [self currentValidationReport];
}

- (IBAction)showValidationReadiness:(id)sender
{
    #pragma unused(sender)
    NSDictionary *report = [self currentValidationReport];

    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:SMValidationAlertTitleForCanonicalReport(report)];
    [alert setAccessoryView:SMReadinessReportDialogBodyView(SMValidationOperatorTextForCanonicalReport(report))];
    [alert setAlertStyle:(SMValidationReportSummaryCount(report, SMValidationSummaryKeyBlockers) > 0) ? NSCriticalAlertStyle : NSInformationalAlertStyle];
    [alert beginSheetModalForWindow:_window modalDelegate:self didEndSelector:nil contextInfo:nil];
}

@end
