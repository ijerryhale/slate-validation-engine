//
//  AppController+AECore.m
//  Slate
//

#import "AppController+AEInternal.h"
#import "AppController+Validation.h"
#import "Runtime/SlatePackageContextContract.h"
#import "Runtime/SlatePackageSnapshotContract.h"
#import "Runtime/SlateReviewSnapshotContract.h"
#import "Runtime/SlateRuntimeBridge.h"
#import "Runtime/SlateRuntimeCommandContract.h"
#import "Validation/SMValidationCanonicalDictionaryKeys.h"

static const CGFloat SMAutomationWorkspaceWidthWideMinimum = 1280.0;
static const CGFloat SMAutomationWorkspaceWidthMediumMinimum = 900.0;
static const CGFloat SMAutomationWindowMinimumWidth = 480.0;
static const CGFloat SMAutomationWindowMinimumHeight = 320.0;

static NSString * const SMAutomationModeTrack = @"track";
static NSString * const SMAutomationModePackage = @"package";
static NSString * const SMAutomationModeChapter = @"chapter";

static NSDictionary *SMAutomationDictionaryValue(id value)
{
    return [value isKindOfClass:[NSDictionary class]] ? value : [NSDictionary dictionary];
}

static NSString *SMAutomationStringValue(id value)
{
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

static NSDictionary *SMAutomationPackageSource(NSDictionary *packageContext)
{
    return SMAutomationDictionaryValue([packageContext objectForKey:SlatePackageContextKeySource]);
}

static NSDictionary *SMAutomationPackageSnapshot(NSDictionary *packageContext)
{
    return SMAutomationDictionaryValue([packageContext objectForKey:SlatePackageContextKeyPackageSnapshot]);
}

static NSDictionary *SMAutomationPackageAssetStack(NSDictionary *packageContext)
{
    return SMAutomationDictionaryValue([SMAutomationPackageSnapshot(packageContext) objectForKey:SlatePackageSnapshotKeyAssetStack]);
}

static NSString * const SMAutomationReplyPong = @"pong";
static NSString * const SMAutomationErrorUnknownEvent = @"Unknown Slate Apple Event.";
static NSString * const SMAutomationErrorHandlerUnavailable = @"Slate Apple Event handler unavailable.";
static NSString * const SMAutomationErrorExpectedBounds = @"Expected bounds list {x, y, width, height} with width >= 480 and height >= 320.";
static NSString * const SMAutomationErrorExpectedMode = @"Mode must be one of: track, package, chapter (or 0/1/2).";
static NSString * const SMAutomationErrorExpectedSeconds = @"Expected numeric playback seconds.";
static NSString * const SMAutomationErrorNoMovie = @"No movie is currently loaded.";
static NSString * const SMAutomationErrorNoValidationContext = @"No movie or package is currently loaded.";
static NSString * const SMAutomationErrorExpectedPath = @"Expected file path (string, file URL, alias, or POSIX file).";
static NSString * const SMAutomationErrorExpectedSnapshot = @"Snapshot type must be status or health.";

static NSString * const SMAutomationSnapshotStatus = @"status";

static BOOL SMIsBottomPaneModeTag(NSInteger tag)
{
    return (tag == cntrl_trak || tag == cntrl_pdata || tag == cntrl_chap);
}

static NSInteger StoredBottomPaneTag(NSUserDefaults *defaults)
{
    NSInteger tag = [defaults integerForKey:BOTTOM_PANE];
    if (!SMIsBottomPaneModeTag(tag)) {
        return cntrl_trak;
    }
    return tag;
}

static NSString *SMWorkspaceWidthClassCodeForWidth(CGFloat width)
{
    if (width >= SMAutomationWorkspaceWidthWideMinimum) {
        return @"2";
    }
    if (width >= SMAutomationWorkspaceWidthMediumMinimum) {
        return @"1";
    }
    return @"0";
}

static NSInteger SMModeTagForAutomationString(NSString *modeName)
{
    NSString *normalized = UtilAENormalizedTokenString(modeName);
    if (normalized == nil || [normalized length] == 0) {
        return NSIntegerMin;
    }

    if ([normalized isEqualToString:SMAutomationModeTrack]
        || [normalized isEqualToString:@"t"]
        || [normalized isEqualToString:@"1"]) {
        return cntrl_trak;
    }
    if ([normalized isEqualToString:SMAutomationModePackage]
        || [normalized isEqualToString:@"p"]
        || [normalized isEqualToString:@"2"]) {
        return cntrl_pdata;
    }
    if ([normalized isEqualToString:SMAutomationModeChapter]
        || [normalized isEqualToString:@"c"]
        || [normalized isEqualToString:@"0"]) {
        return cntrl_chap;
    }

    return NSIntegerMin;
}

static NSString *SMAutomationModeNameForTag(NSInteger tag)
{
    switch (tag)
    {
        case cntrl_trak:
            return SMAutomationModeTrack;
        case cntrl_pdata:
            return SMAutomationModePackage;
        case cntrl_chap:
            return SMAutomationModeChapter;
        default:
            break;
    }

    return SMAutomationModeTrack;
}

static NSString *SMAutomationFirstTokenFromDescriptor(NSAppleEventDescriptor *descriptor)
{
    if (descriptor == nil) {
        return nil;
    }

    NSAppleEventDescriptor *tokenDescriptor = descriptor;
    if ([descriptor descriptorType] == typeAEList && [descriptor numberOfItems] > 0) {
        tokenDescriptor = [descriptor descriptorAtIndex:1];
    }

    NSString *token = UtilAEStringFromDescriptor(tokenDescriptor);
    if ([token length] > 0) {
        return token;
    }

    NSNumber *numericToken = UtilAENumberFromDescriptor(tokenDescriptor);
    return (numericToken != nil) ? [numericToken stringValue] : nil;
}

static NSString *SMAutomationOperatorSnapshotTypeFromDescriptor(NSAppleEventDescriptor *descriptor)
{
    NSString *normalized = UtilAENormalizedTokenString(SMAutomationFirstTokenFromDescriptor(descriptor));
    if (normalized == nil || [normalized length] == 0) {
        return SMAutomationSnapshotStatus;
    }

    if ([normalized isEqualToString:@"0"]
        || [normalized isEqualToString:@"status"]
        || [normalized isEqualToString:@"health"]
        || [normalized isEqualToString:@"runtime"]
        || [normalized isEqualToString:@"app"]) {
        return SMAutomationSnapshotStatus;
    }

    return nil;
}

static void SMAutomationInstallExtensionHandlers(id target, NSAppleEventManager *manager, SEL handlerSelector)
{
    SEL extensionSelector = @selector(installAutomationExtensionAppleEventHandlersWithManager:selector:);
    if (![target respondsToSelector:extensionSelector]) {
        return;
    }

    void (*installer)(id, SEL, NSAppleEventManager *, SEL) = (void (*)(id, SEL, NSAppleEventManager *, SEL))[target methodForSelector:extensionSelector];
    if (installer != NULL) {
        installer(target, extensionSelector, manager, handlerSelector);
    }
}

static void SMAutomationRemoveExtensionHandlers(id target, NSAppleEventManager *manager)
{
    SEL extensionSelector = @selector(removeAutomationExtensionAppleEventHandlersWithManager:);
    if (![target respondsToSelector:extensionSelector]) {
        return;
    }

    void (*remover)(id, SEL, NSAppleEventManager *) = (void (*)(id, SEL, NSAppleEventManager *))[target methodForSelector:extensionSelector];
    if (remover != NULL) {
        remover(target, extensionSelector, manager);
    }
}

static SEL SMAutomationExtensionHandlerSelector(id target, AEEventID eventID)
{
    SEL extensionSelector = @selector(automationExtensionHandlerSelectorForAppleEventID:);
    if (![target respondsToSelector:extensionSelector]) {
        return NULL;
    }

    SEL (*resolver)(id, SEL, AEEventID) = (SEL (*)(id, SEL, AEEventID))[target methodForSelector:extensionSelector];
    return (resolver != NULL) ? resolver(target, extensionSelector, eventID) : NULL;
}

static NSString *SMAutomationExtensionHelpText(id target)
{
    SEL extensionSelector = @selector(automationExtensionAppleEventHelpText);
    if (![target respondsToSelector:extensionSelector]) {
        return nil;
    }

    id (*provider)(id, SEL) = (id (*)(id, SEL))[target methodForSelector:extensionSelector];
    id helpText = (provider != NULL) ? provider(target, extensionSelector) : nil;
    return [helpText isKindOfClass:[NSString class]] ? helpText : nil;
}

static NSAppleEventDescriptor *SMAutomationExtensionSnapshotDescriptor(id target, NSAppleEventDescriptor *descriptor)
{
    SEL extensionSelector = @selector(automationExtensionSnapshotDescriptorForDescriptor:);
    if (![target respondsToSelector:extensionSelector]) {
        return nil;
    }

    id (*provider)(id, SEL, NSAppleEventDescriptor *) = (id (*)(id, SEL, NSAppleEventDescriptor *))[target methodForSelector:extensionSelector];
    id snapshotDescriptor = (provider != NULL) ? provider(target, extensionSelector, descriptor) : nil;
    return [snapshotDescriptor isKindOfClass:[NSAppleEventDescriptor class]] ? snapshotDescriptor : nil;
}

@implementation AppController (AECore)

#pragma mark - Apple Event Automation Helpers

- (NSArray *)automationWindowBounds
{
    if (_window == nil) {
        return [NSArray arrayWithObjects:
                [NSNumber numberWithDouble:0.0],
                [NSNumber numberWithDouble:0.0],
                [NSNumber numberWithDouble:0.0],
                [NSNumber numberWithDouble:0.0],
                nil];
    }

    NSRect frame = [_window frame];
    return [NSArray arrayWithObjects:
            [NSNumber numberWithDouble:frame.origin.x],
            [NSNumber numberWithDouble:frame.origin.y],
            [NSNumber numberWithDouble:frame.size.width],
            [NSNumber numberWithDouble:frame.size.height],
            nil];
}

- (BOOL)applyAutomationWindowBoundsFromArray:(NSArray *)bounds
{
    if (_window == nil || ![bounds isKindOfClass:[NSArray class]] || [bounds count] < 4) {
        return NO;
    }

    double x = [[bounds objectAtIndex:0] doubleValue];
    double y = [[bounds objectAtIndex:1] doubleValue];
    double width = [[bounds objectAtIndex:2] doubleValue];
    double height = [[bounds objectAtIndex:3] doubleValue];

    if (!isfinite(x) || !isfinite(y) || !isfinite(width) || !isfinite(height)) {
        return NO;
    }

    if (width < SMAutomationWindowMinimumWidth || height < SMAutomationWindowMinimumHeight) {
        return NO;
    }

    [_window setFrame:NSMakeRect(x, y, width, height) display:YES];
    [_window makeKeyAndOrderFront:nil];
    [self layoutScrubberTimeLabels];
    [self applyModeWorkspaceResponsiveLayout];
    [self updateCurrentSize];
    [self refreshCropValues:nil];
    return YES;
}

- (NSString *)currentModeAutomationString
{
    NSInteger tag = _currentTag;
    if (tag != cntrl_chap && tag != cntrl_trak && tag != cntrl_pdata) {
        tag = StoredBottomPaneTag([NSUserDefaults standardUserDefaults]);
    }

    return SMAutomationModeNameForTag(tag);
}

- (BOOL)setModeFromAutomationString:(NSString *)modeName
{
    NSInteger tag = SMModeTagForAutomationString(modeName);
    if (tag == NSIntegerMin) {
        return NO;
    }

    if (_views != nil) {
        [_views selectCellAtRow:0 column:tag];
        [self selectBottomPane:_views];
        return YES;
    }

    _currentTag = tag;
    [self applyModeWorkspaceResponsiveLayout];
    return YES;
}

- (NSString *)workspaceResponsiveWidthClassCode
{
    return SMWorkspaceWidthClassCodeForWidth([self currentWorkspaceResponsiveWidth]);
}

- (void)populateOperatorReplyEvent:(NSAppleEventDescriptor *)replyEvent
                            eventID:(AEEventID)eventID
                        resultObject:(id)resultObject
{
    UtilAEPopulateReplyResult(replyEvent,
                              UtilAEJSONDescriptorForObject(UtilAEOperatorResultPayload(kSlateAppleEventClass,
                                                                                       eventID,
                                                                                       resultObject)));
}

- (void)populateOperatorErrorReplyEvent:(NSAppleEventDescriptor *)replyEvent
                                 eventID:(AEEventID)eventID
                             errorNumber:(SInt32)errorNumber
                                    code:(NSString *)code
                                 message:(NSString *)message
{
    UtilAEPopulateReplyResult(replyEvent,
                              UtilAEJSONDescriptorForObject(UtilAEOperatorErrorPayload(kSlateAppleEventClass,
                                                                                      eventID,
                                                                                      code,
                                                                                      message,
                                                                                      errorNumber)));
}

- (void)installSlateAppleEventHandlers
{
    NSAppleEventManager *manager = [NSAppleEventManager sharedAppleEventManager];
    SEL selector = @selector(handleSlateAppleEvent:withReplyEvent:);

    [manager setEventHandler:self andSelector:selector forEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventPing];
    [manager setEventHandler:self andSelector:selector forEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventHelp];
    [manager setEventHandler:self andSelector:selector forEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventGetWindowBounds];
    [manager setEventHandler:self andSelector:selector forEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventSetWindowBounds];
    [manager setEventHandler:self andSelector:selector forEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventGetMode];
    [manager setEventHandler:self andSelector:selector forEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventSetMode];
    [manager setEventHandler:self andSelector:selector forEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventGetWorkspaceWidth];
    [manager setEventHandler:self andSelector:selector forEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventGetWorkspaceClass];
    [manager setEventHandler:self andSelector:selector forEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventGetPlaybackSeconds];
    [manager setEventHandler:self andSelector:selector forEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventSetPlaybackSeconds];
    [manager setEventHandler:self andSelector:selector forEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventGetPlaybackRate];
    [manager setEventHandler:self andSelector:selector forEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventTogglePlayback];
    [manager setEventHandler:self andSelector:selector forEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventOpenPath];
    [manager setEventHandler:self andSelector:selector forEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventTrackMovieDetails];
    [manager setEventHandler:self andSelector:selector forEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventChapterDetails];
    [manager setEventHandler:self andSelector:selector forEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventReadinessReport];
    [manager setEventHandler:self andSelector:selector forEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventReadinessSummary];
    [manager setEventHandler:self andSelector:selector forEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventSnapshot];

    SMAutomationInstallExtensionHandlers(self, manager, selector);
}

- (void)removeSlateAppleEventHandlers
{
    NSAppleEventManager *manager = [NSAppleEventManager sharedAppleEventManager];

    [manager removeEventHandlerForEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventPing];
    [manager removeEventHandlerForEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventHelp];
    [manager removeEventHandlerForEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventGetWindowBounds];
    [manager removeEventHandlerForEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventSetWindowBounds];
    [manager removeEventHandlerForEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventGetMode];
    [manager removeEventHandlerForEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventSetMode];
    [manager removeEventHandlerForEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventGetWorkspaceWidth];
    [manager removeEventHandlerForEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventGetWorkspaceClass];
    [manager removeEventHandlerForEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventGetPlaybackSeconds];
    [manager removeEventHandlerForEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventSetPlaybackSeconds];
    [manager removeEventHandlerForEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventGetPlaybackRate];
    [manager removeEventHandlerForEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventTogglePlayback];
    [manager removeEventHandlerForEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventOpenPath];
    [manager removeEventHandlerForEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventTrackMovieDetails];
    [manager removeEventHandlerForEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventChapterDetails];
    [manager removeEventHandlerForEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventReadinessReport];
    [manager removeEventHandlerForEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventReadinessSummary];
    [manager removeEventHandlerForEventClass:kSlateAppleEventClass andEventID:kSlateAppleEventSnapshot];

    SMAutomationRemoveExtensionHandlers(self, manager);
}

- (NSAppleEventDescriptor *)automationWindowBoundsDescriptor
{
    return UtilAEDescriptorListFromNumericArray([self automationWindowBounds]);
}

- (NSDictionary *)automationOperatorSnapshotPayload
{
    NSMutableDictionary *snapshot = [NSMutableDictionary dictionary];
    [snapshot setObject:@"slateAppStatus.v1" forKey:@"schemaVersion"];
    [snapshot setObject:@"status" forKey:@"snapshotType"];
    [snapshot setObject:[self currentModeAutomationString] forKey:@"mode"];
    [snapshot setObject:[self automationWindowBounds] forKey:@"windowBounds"];
    [snapshot setObject:[NSNumber numberWithDouble:[self currentWorkspaceResponsiveWidth]] forKey:@"workspaceWidth"];
    [snapshot setObject:[self workspaceResponsiveWidthClassCode] forKey:@"workspaceWidthClass"];
    [snapshot setObject:[NSNumber numberWithBool:(_movie != nil)] forKey:@"hasMovie"];
    [snapshot setObject:[NSNumber numberWithBool:([_packagePath length] > 0 || [_packageContext count] > 0)] forKey:@"hasPackage"];
    [snapshot setObject:[NSNumber numberWithDouble:(_movie != nil ? [_movie rate] : 0.0)] forKey:@"playbackRate"];
    [snapshot setObject:[NSNumber numberWithDouble:[self movieCurrentTime]] forKey:@"playbackSeconds"];
    [snapshot setObject:[NSNumber numberWithDouble:[_timelineState duration]] forKey:@"durationSeconds"];
    [snapshot setObject:[SlateRuntimeBridge runtimeAcquisitionStatus] forKey:@"runtimeAcquisition"];

    NSString *moviePath = [[_movie URL] path];
    if ([moviePath length] > 0) {
        [snapshot setObject:moviePath forKey:@"moviePath"];
    }
    if ([_packagePath length] > 0) {
        [snapshot setObject:_packagePath forKey:@"packagePath"];
    }

    return snapshot;
}

- (NSDictionary *)automationTrackMovieDetailsPayload
{
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    [payload setObject:@"trackMovieDetails.v1" forKey:@"schemaVersion"];
    [payload setObject:[NSNumber numberWithBool:(_movie != nil)] forKey:@"hasMovie"];
    [payload setObject:[self currentModeAutomationString] forKey:@"mode"];

    if (_movie == nil) {
        [payload setObject:@"noMovie" forKey:@"error"];
        [payload setObject:@"No movie is currently loaded." forKey:@"message"];
        [payload setObject:[NSArray array] forKey:@"tracks"];
        [payload setObject:[NSNumber numberWithUnsignedInteger:0] forKey:@"trackCount"];
        return payload;
    }

    TrackViewController *trackController = [self ensureTrackViewControllerLoaded];
    if (trackController == nil) {
        [payload setObject:@"trackInspectorUnavailable" forKey:@"error"];
        [payload setObject:@"Track + Movie inspector data is unavailable." forKey:@"message"];
        [payload setObject:[NSArray array] forKey:@"tracks"];
        [payload setObject:[NSNumber numberWithUnsignedInteger:0] forKey:@"trackCount"];
        return payload;
    }

    NSArray *tracks = [trackController trackMovieInspectorDetailRows];
    if (![tracks isKindOfClass:[NSArray class]]) {
        tracks = [NSArray array];
    }

    [payload setObject:tracks forKey:@"tracks"];
    [payload setObject:[NSNumber numberWithUnsignedInteger:[tracks count]] forKey:@"trackCount"];

    NSString *moviePath = [[_movie URL] path];
    if ([moviePath length] > 0) {
        [payload setObject:moviePath forKey:@"moviePath"];
    }

    NSString *movieDisplayName = [_movie attributeForKey:SMMovieDisplayNameAttribute];
    if ([movieDisplayName isKindOfClass:[NSString class]] && [movieDisplayName length] > 0) {
        [payload setObject:movieDisplayName forKey:@"movieDisplayName"];
    }

    return payload;
}

- (NSDictionary *)automationChapterDetailsPayload
{
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    [payload setObject:@"chapterDetails.v1" forKey:@"schemaVersion"];
    [payload setObject:[NSNumber numberWithBool:(_packageContext != nil)] forKey:@"hasPackage"];
    [payload setObject:[self currentModeAutomationString] forKey:@"mode"];

    if (_packageContext == nil) {
        [payload setObject:@"noPackage" forKey:@"error"];
        [payload setObject:@"No package is currently loaded." forKey:@"message"];
        [payload setObject:[NSArray array] forKey:@"chapters"];
        [payload setObject:[NSNumber numberWithUnsignedInteger:0] forKey:@"chapterCount"];
        return payload;
    }

    ChapterViewController *chapterController = [self ensureChapterViewControllerLoaded];
    if (chapterController == nil) {
        [payload setObject:@"chapterInspectorUnavailable" forKey:@"error"];
        [payload setObject:@"Chapter inspector data is unavailable." forKey:@"message"];
        [payload setObject:[NSArray array] forKey:@"chapters"];
        [payload setObject:[NSNumber numberWithUnsignedInteger:0] forKey:@"chapterCount"];
        return payload;
    }

    NSArray *chapters = [chapterController chapterInspectorDetailRows];
    if (![chapters isKindOfClass:[NSArray class]]) {
        chapters = [NSArray array];
    }

    [payload setObject:chapters forKey:@"chapters"];
    [payload setObject:[NSNumber numberWithUnsignedInteger:[chapters count]] forKey:@"chapterCount"];

    if ([_packagePath length] > 0) {
        [payload setObject:_packagePath forKey:@"packagePath"];
    }

    NSString *packageSourceKind = SMAutomationStringValue([SMAutomationPackageSource(_packageContext) objectForKey:SlatePackageSnapshotSourceKeyKind]);
    if ([packageSourceKind isKindOfClass:[NSString class]] && [packageSourceKind length] > 0) {
        [payload setObject:packageSourceKind forKey:@"packageSourceKind"];
    }

    NSString *packageVendorID = SMAutomationStringValue([SMAutomationPackageAssetStack(_packageContext) objectForKey:SlatePackageSnapshotAssetKeyVendorID]);
    if ([packageVendorID isKindOfClass:[NSString class]] && [packageVendorID length] > 0) {
        [payload setObject:packageVendorID forKey:@"packageVendorID"];
    }

    return payload;
}

- (NSDictionary *)automationReadinessContextPayload
{
    NSMutableDictionary *context = [NSMutableDictionary dictionary];
    [context setObject:@"readinessContext.v1" forKey:@"schemaVersion"];
    [context setObject:[NSNumber numberWithBool:(_movie != nil)] forKey:@"hasMovie"];
    [context setObject:[NSNumber numberWithBool:(_packageContext != nil)] forKey:@"hasPackage"];
    [context setObject:[self currentModeAutomationString] forKey:@"mode"];

    NSString *moviePath = [[_movie URL] path];
    if ([moviePath length] > 0) {
        [context setObject:moviePath forKey:@"moviePath"];
    }

    NSString *movieDisplayName = [_movie attributeForKey:SMMovieDisplayNameAttribute];
    if ([movieDisplayName isKindOfClass:[NSString class]] && [movieDisplayName length] > 0) {
        [context setObject:movieDisplayName forKey:@"movieDisplayName"];
    }

    if ([_packagePath length] > 0) {
        [context setObject:_packagePath forKey:@"packagePath"];
    }

    NSString *packageSourceKind = SMAutomationStringValue([SMAutomationPackageSource(_packageContext) objectForKey:SlatePackageSnapshotSourceKeyKind]);
    if ([packageSourceKind isKindOfClass:[NSString class]] && [packageSourceKind length] > 0) {
        [context setObject:packageSourceKind forKey:@"packageSourceKind"];
    }

    NSString *packageVendorID = SMAutomationStringValue([SMAutomationPackageAssetStack(_packageContext) objectForKey:SlatePackageSnapshotAssetKeyVendorID]);
    if ([packageVendorID isKindOfClass:[NSString class]] && [packageVendorID length] > 0) {
        [context setObject:packageVendorID forKey:@"packageVendorID"];
    }

    NSString *packageMediaType = SMAutomationStringValue([SMAutomationPackageAssetStack(_packageContext) objectForKey:SlatePackageSnapshotAssetKeyMediaType]);
    if ([packageMediaType isKindOfClass:[NSString class]] && [packageMediaType length] > 0) {
        [context setObject:packageMediaType forKey:@"packageMediaType"];
    }

    return context;
}

- (NSDictionary *)automationCurrentValidationReport
{
    if (_movie == nil && _packageContext == nil) {
        return nil;
    }

    return [self currentValidationReport];
}

- (NSDictionary *)automationReadinessReportPayload
{
    NSDictionary *report = [self automationCurrentValidationReport];
    if (report == nil) {
        return [NSDictionary dictionaryWithObjectsAndKeys:
                @"noValidationContext", @"error",
                SMAutomationErrorNoValidationContext, @"message",
                nil];
    }

    NSDictionary *context = [self automationReadinessContextPayload];
    NSDictionary *reviewSnapshot = [SlateRuntimeBridge reviewSnapshotWithContext:context
                                                               canonicalReport:report
                                                                    activePane:[self currentModeAutomationString]];
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    [payload setObject:@"readinessReport.v1" forKey:@"schemaVersion"];
    [payload setObject:context forKey:@"context"];
    [payload setObject:reviewSnapshot forKey:@"reviewSnapshot"];
    [payload setObject:([report objectForKey:SMValidationReportKeyStatus] ?: SMValidationStatusPass)
                forKey:SMValidationReportKeyStatus];
    [payload setObject:([report objectForKey:SMValidationReportKeySummary] ?: [NSDictionary dictionary])
                forKey:SMValidationReportKeySummary];
    [payload setObject:([report objectForKey:SMValidationReportKeyNextFinding] ?: [NSNull null])
                forKey:SMValidationReportKeyNextFinding];
    [payload setObject:([report objectForKey:SMValidationReportKeyFindings] ?: [NSArray array])
                forKey:SMValidationReportKeyFindings];
    [payload setObject:([report objectForKey:SMValidationReportKeyOperatorText] ?: @"")
                forKey:SMValidationReportKeyOperatorText];
    [payload setObject:([report objectForKey:SMValidationReportKeyValidationResultPayload] ?: [NSDictionary dictionary])
                forKey:SMValidationReportKeyValidationResultPayload];
    return payload;
}

- (NSDictionary *)automationReadinessSummaryPayload
{
    NSDictionary *report = [self automationCurrentValidationReport];
    if (report == nil) {
        return [NSDictionary dictionaryWithObjectsAndKeys:
                @"noValidationContext", @"error",
                SMAutomationErrorNoValidationContext, @"message",
                nil];
    }

    NSDictionary *context = [self automationReadinessContextPayload];
    NSDictionary *reviewSnapshot = [SlateRuntimeBridge reviewSnapshotWithContext:context
                                                               canonicalReport:report
                                                                    activePane:[self currentModeAutomationString]];
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    [payload setObject:@"readinessSummary.v1" forKey:@"schemaVersion"];
    [payload setObject:context forKey:@"context"];
    [payload setObject:reviewSnapshot forKey:@"reviewSnapshot"];
    [payload setObject:([report objectForKey:SMValidationReportKeyStatus] ?: SMValidationStatusPass)
                forKey:SMValidationReportKeyStatus];
    [payload setObject:([report objectForKey:SMValidationReportKeySummary] ?: [NSDictionary dictionary])
                forKey:SMValidationReportKeySummary];
    [payload setObject:([report objectForKey:SMValidationReportKeyNextFinding] ?: [NSNull null])
                forKey:SMValidationReportKeyNextFinding];
    [payload setObject:([report objectForKey:SMValidationReportKeyOperatorText] ?: @"")
                forKey:SMValidationReportKeyOperatorText];
    return payload;
}

- (NSString *)automationAppleEventHelpText
{
    static NSString * const SMAutomationOperatorHelpText =
        @"Slate Apple Events (class 'SLAT')\n"
         "Operator surface returns JSON:\n"
         "{\"result\":...,\"ok\":true,\"schemaVersion\":\"operatorResult.v1\",\"eventClass\":\"SLAT\",\"eventID\":\"PING\"}\n"
         "Failures return ok=false with error.code, error.message, and error.appleEventError.\n"
         "Command-style results use runtimeCommandResult.v1 inside result.\n"
         "SNAP [status|health] -> result Slate.app health/status snapshot\n"
         "PING -> result \"pong\"\n"
         "HELP -> result help text\n"
         "GWND -> result [x, y, width, height]\n"
         "SWND {x, y, width, height} -> result [x, y, width, height]\n"
         "GMOD -> result mode (track/package/chapter)\n"
         "SMOD \"chapter|track|package|0|1|2\" -> result mode\n"
         "GWWD -> result workspace width\n"
         "GWCL -> result workspace width class code (2=wide, 1=medium, 0=compact)\n"
         "GSEC -> result playback seconds\n"
         "SSEC <seconds> -> result playback seconds\n"
         "GRAT -> result playback rate\n"
         "TPLY -> result playback rate after toggle\n"
         "FPTH <path> -> result opened path\n"
         "TDET -> result Track + Movie inspector details for loaded movie tracks\n"
         "CDET -> result Chapter + Image inspector details for loaded package chapters\n"
         "RRPT -> result full readiness report for loaded movie/package context\n"
         "RSUM -> result readiness summary for loaded movie/package context";

    NSMutableString *help = [NSMutableString stringWithString:SMAutomationOperatorHelpText];

    NSString *extensionHelp = SMAutomationExtensionHelpText(self);
    if ([extensionHelp length] > 0) {
        [help appendString:@"\n\nAutomation extension surface:\n"];
        [help appendString:extensionHelp];
    }

    [help appendString:@"\n\nExample: tell application id \"com.tmt.slate\" to «event SLATSWND» {80, 80, 1280, 880}"];
    return help;
}

- (SEL)handlerSelectorForAppleEventID:(AEEventID)eventID
{
    static NSDictionary *dispatchMap = nil;
    if (dispatchMap == nil) {
        dispatchMap = [[NSDictionary alloc] initWithObjectsAndKeys:
                       NSStringFromSelector(@selector(handleAppleEventPingWithDescriptor:replyEvent:)), [NSNumber numberWithUnsignedInt:kSlateAppleEventPing],
                       NSStringFromSelector(@selector(handleAppleEventHelpWithDescriptor:replyEvent:)), [NSNumber numberWithUnsignedInt:kSlateAppleEventHelp],
                       NSStringFromSelector(@selector(handleAppleEventGetWindowBoundsWithDescriptor:replyEvent:)), [NSNumber numberWithUnsignedInt:kSlateAppleEventGetWindowBounds],
                       NSStringFromSelector(@selector(handleAppleEventSetWindowBoundsWithDescriptor:replyEvent:)), [NSNumber numberWithUnsignedInt:kSlateAppleEventSetWindowBounds],
                       NSStringFromSelector(@selector(handleAppleEventGetModeWithDescriptor:replyEvent:)), [NSNumber numberWithUnsignedInt:kSlateAppleEventGetMode],
                       NSStringFromSelector(@selector(handleAppleEventSetModeWithDescriptor:replyEvent:)), [NSNumber numberWithUnsignedInt:kSlateAppleEventSetMode],
                       NSStringFromSelector(@selector(handleAppleEventGetWorkspaceWidthWithDescriptor:replyEvent:)), [NSNumber numberWithUnsignedInt:kSlateAppleEventGetWorkspaceWidth],
                       NSStringFromSelector(@selector(handleAppleEventGetWorkspaceClassWithDescriptor:replyEvent:)), [NSNumber numberWithUnsignedInt:kSlateAppleEventGetWorkspaceClass],
                       NSStringFromSelector(@selector(handleAppleEventGetPlaybackSecondsWithDescriptor:replyEvent:)), [NSNumber numberWithUnsignedInt:kSlateAppleEventGetPlaybackSeconds],
                       NSStringFromSelector(@selector(handleAppleEventSetPlaybackSecondsWithDescriptor:replyEvent:)), [NSNumber numberWithUnsignedInt:kSlateAppleEventSetPlaybackSeconds],
                       NSStringFromSelector(@selector(handleAppleEventGetPlaybackRateWithDescriptor:replyEvent:)), [NSNumber numberWithUnsignedInt:kSlateAppleEventGetPlaybackRate],
                       NSStringFromSelector(@selector(handleAppleEventTogglePlaybackWithDescriptor:replyEvent:)), [NSNumber numberWithUnsignedInt:kSlateAppleEventTogglePlayback],
                       NSStringFromSelector(@selector(handleAppleEventOpenPathWithDescriptor:replyEvent:)), [NSNumber numberWithUnsignedInt:kSlateAppleEventOpenPath],
                       NSStringFromSelector(@selector(handleAppleEventTrackMovieDetailsWithDescriptor:replyEvent:)), [NSNumber numberWithUnsignedInt:kSlateAppleEventTrackMovieDetails],
                       NSStringFromSelector(@selector(handleAppleEventChapterDetailsWithDescriptor:replyEvent:)), [NSNumber numberWithUnsignedInt:kSlateAppleEventChapterDetails],
                       NSStringFromSelector(@selector(handleAppleEventReadinessReportWithDescriptor:replyEvent:)), [NSNumber numberWithUnsignedInt:kSlateAppleEventReadinessReport],
                       NSStringFromSelector(@selector(handleAppleEventReadinessSummaryWithDescriptor:replyEvent:)), [NSNumber numberWithUnsignedInt:kSlateAppleEventReadinessSummary],
                       NSStringFromSelector(@selector(handleAppleEventSnapshotWithDescriptor:replyEvent:)), [NSNumber numberWithUnsignedInt:kSlateAppleEventSnapshot],
                       nil];
    }

    NSString *selectorName = [dispatchMap objectForKey:[NSNumber numberWithUnsignedInt:eventID]];
    if ([selectorName length] > 0) {
        return NSSelectorFromString(selectorName);
    }

    return SMAutomationExtensionHandlerSelector(self, eventID);
}

- (void)dispatchAppleEventWithID:(AEEventID)eventID
                 directDescriptor:(NSAppleEventDescriptor *)directDescriptor
                       replyEvent:(NSAppleEventDescriptor *)replyEvent
{
    SEL selector = [self handlerSelectorForAppleEventID:eventID];
    if (selector == NULL) {
        [self populateOperatorErrorReplyEvent:replyEvent
                                      eventID:eventID
                                  errorNumber:errAEEventNotHandled
                                         code:@"unknownEvent"
                                      message:SMAutomationErrorUnknownEvent];
        return;
    }

    SMAppleEventHandlerIMP handler = (SMAppleEventHandlerIMP)[self methodForSelector:selector];
    if (handler == NULL) {
        [self populateOperatorErrorReplyEvent:replyEvent
                                      eventID:eventID
                                  errorNumber:errAEEventNotHandled
                                         code:@"handlerUnavailable"
                                      message:SMAutomationErrorHandlerUnavailable];
        return;
    }

    handler(self, selector, directDescriptor, replyEvent);
}

- (void)handleAppleEventPingWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                replyEvent:(NSAppleEventDescriptor *)replyEvent
{
    #pragma unused(directDescriptor)
    [self populateOperatorReplyEvent:replyEvent
                              eventID:kSlateAppleEventPing
                          resultObject:SMAutomationReplyPong];
}

- (void)handleAppleEventHelpWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                replyEvent:(NSAppleEventDescriptor *)replyEvent
{
    #pragma unused(directDescriptor)
    NSString *helpText = [self automationAppleEventHelpText];
    [self populateOperatorReplyEvent:replyEvent
                              eventID:kSlateAppleEventHelp
                          resultObject:helpText];
}

- (void)handleAppleEventSnapshotWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                    replyEvent:(NSAppleEventDescriptor *)replyEvent
{
    NSString *snapshotType = SMAutomationOperatorSnapshotTypeFromDescriptor(directDescriptor);
    if ([snapshotType length] == 0) {
        NSAppleEventDescriptor *extensionDescriptor = SMAutomationExtensionSnapshotDescriptor(self, directDescriptor);
        if (extensionDescriptor != nil) {
            UtilAEPopulateReplyResult(replyEvent, extensionDescriptor);
            return;
        }

        [self populateOperatorErrorReplyEvent:replyEvent
                                      eventID:kSlateAppleEventSnapshot
                                  errorNumber:paramErr
                                         code:@"expectedSnapshotType"
                                      message:SMAutomationErrorExpectedSnapshot];
        return;
    }

    [self populateOperatorReplyEvent:replyEvent
                              eventID:kSlateAppleEventSnapshot
                          resultObject:[self automationOperatorSnapshotPayload]];
}

- (void)handleAppleEventGetWindowBoundsWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                            replyEvent:(NSAppleEventDescriptor *)replyEvent
{
    #pragma unused(directDescriptor)
    NSArray *bounds = [self automationWindowBounds];
    [self populateOperatorReplyEvent:replyEvent
                              eventID:kSlateAppleEventGetWindowBounds
                          resultObject:bounds];
}

- (void)handleAppleEventSetWindowBoundsWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                            replyEvent:(NSAppleEventDescriptor *)replyEvent
{
    NSArray *bounds = UtilAENumericListFromDescriptor(directDescriptor, 4);
    if (bounds == nil || ![self applyAutomationWindowBoundsFromArray:bounds]) {
        [self populateOperatorErrorReplyEvent:replyEvent
                                      eventID:kSlateAppleEventSetWindowBounds
                                  errorNumber:paramErr
                                         code:@"expectedBounds"
                                      message:SMAutomationErrorExpectedBounds];
        return;
    }

    [self populateOperatorReplyEvent:replyEvent
                              eventID:kSlateAppleEventSetWindowBounds
                          resultObject:[self automationWindowBounds]];
}

- (void)handleAppleEventGetModeWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                    replyEvent:(NSAppleEventDescriptor *)replyEvent
{
    #pragma unused(directDescriptor)
    NSString *modeName = [self currentModeAutomationString];
    [self populateOperatorReplyEvent:replyEvent
                              eventID:kSlateAppleEventGetMode
                          resultObject:modeName];
}

- (void)handleAppleEventSetModeWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                    replyEvent:(NSAppleEventDescriptor *)replyEvent
{
    NSString *modeName = UtilAEStringFromDescriptor(directDescriptor);
    if (![self setModeFromAutomationString:modeName]) {
        [self populateOperatorErrorReplyEvent:replyEvent
                                      eventID:kSlateAppleEventSetMode
                                  errorNumber:paramErr
                                         code:@"expectedMode"
                                      message:SMAutomationErrorExpectedMode];
        return;
    }

    NSString *currentMode = [self currentModeAutomationString];
    NSDictionary *payload = [NSDictionary dictionaryWithObject:(modeName ?: @"") forKey:SlateRuntimeCommandKeyMode];
    NSDictionary *commandResult = [SlateRuntimeBridge commandResultWithCommand:SlateRuntimeCommandSetMode
                                                                    payload:payload
                                                                     result:[NSDictionary dictionaryWithObject:currentMode
                                                                                                        forKey:SlateRuntimeCommandKeyMode]];
    [self populateOperatorReplyEvent:replyEvent
                              eventID:kSlateAppleEventSetMode
                          resultObject:commandResult];
}

- (void)handleAppleEventGetWorkspaceWidthWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                              replyEvent:(NSAppleEventDescriptor *)replyEvent
{
    #pragma unused(directDescriptor)
    NSNumber *width = [NSNumber numberWithDouble:[self currentWorkspaceResponsiveWidth]];
    [self populateOperatorReplyEvent:replyEvent
                              eventID:kSlateAppleEventGetWorkspaceWidth
                          resultObject:width];
}

- (void)handleAppleEventGetWorkspaceClassWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                              replyEvent:(NSAppleEventDescriptor *)replyEvent
{
    #pragma unused(directDescriptor)
    NSString *widthClass = [self workspaceResponsiveWidthClassCode];
    [self populateOperatorReplyEvent:replyEvent
                              eventID:kSlateAppleEventGetWorkspaceClass
                          resultObject:widthClass];
}

- (void)handleAppleEventGetPlaybackSecondsWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                               replyEvent:(NSAppleEventDescriptor *)replyEvent
{
    #pragma unused(directDescriptor)
    NSNumber *seconds = [NSNumber numberWithDouble:[self movieCurrentTime]];
    [self populateOperatorReplyEvent:replyEvent
                              eventID:kSlateAppleEventGetPlaybackSeconds
                          resultObject:seconds];
}

- (void)handleAppleEventSetPlaybackSecondsWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                               replyEvent:(NSAppleEventDescriptor *)replyEvent
{
    NSNumber *seconds = UtilAENumberFromDescriptor(directDescriptor);
    if (seconds == nil) {
        [self populateOperatorErrorReplyEvent:replyEvent
                                      eventID:kSlateAppleEventSetPlaybackSeconds
                                  errorNumber:paramErr
                                         code:@"expectedSeconds"
                                      message:SMAutomationErrorExpectedSeconds];
        return;
    }
    if (_movie == nil) {
        [self populateOperatorErrorReplyEvent:replyEvent
                                      eventID:kSlateAppleEventSetPlaybackSeconds
                                  errorNumber:errAENoSuchObject
                                         code:@"noMovie"
                                      message:SMAutomationErrorNoMovie];
        return;
    }

    double duration = [_timelineState duration];
    double targetSeconds = [seconds doubleValue];
    if (isfinite(duration) && duration > 0.0) {
        targetSeconds = MIN(duration, MAX(0.0, targetSeconds));
    } else {
        targetSeconds = MAX(0.0, targetSeconds);
    }
    [self setMovieCurrentTime:targetSeconds];
    NSDictionary *payload = [NSDictionary dictionaryWithObject:[NSNumber numberWithDouble:[seconds doubleValue]]
                                                        forKey:SlateRuntimeCommandKeySeconds];
    NSDictionary *commandResult = [SlateRuntimeBridge commandResultWithCommand:SlateRuntimeCommandJumpToTime
                                                                    payload:payload
                                                                     result:[NSDictionary dictionaryWithObject:[NSNumber numberWithDouble:[self movieCurrentTime]]
                                                                                                        forKey:SlateRuntimeCommandKeySeconds]];
    [self populateOperatorReplyEvent:replyEvent
                              eventID:kSlateAppleEventSetPlaybackSeconds
                          resultObject:commandResult];
}

- (void)handleAppleEventGetPlaybackRateWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                            replyEvent:(NSAppleEventDescriptor *)replyEvent
{
    #pragma unused(directDescriptor)
    NSNumber *rate = [NSNumber numberWithDouble:(_movie != nil ? [_movie rate] : 0.0)];
    [self populateOperatorReplyEvent:replyEvent
                              eventID:kSlateAppleEventGetPlaybackRate
                          resultObject:rate];
}

- (void)handleAppleEventTogglePlaybackWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                           replyEvent:(NSAppleEventDescriptor *)replyEvent
{
    #pragma unused(directDescriptor)
    if (_movie == nil) {
        [self populateOperatorErrorReplyEvent:replyEvent
                                      eventID:kSlateAppleEventTogglePlayback
                                  errorNumber:errAENoSuchObject
                                         code:@"noMovie"
                                      message:SMAutomationErrorNoMovie];
        return;
    }

    [self togglePlayPause:nil];
    [self populateOperatorReplyEvent:replyEvent
                              eventID:kSlateAppleEventTogglePlayback
                          resultObject:[NSNumber numberWithDouble:[_movie rate]]];
}

- (void)handleAppleEventOpenPathWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                    replyEvent:(NSAppleEventDescriptor *)replyEvent
{
    NSString *path = UtilAEPathFromDescriptor(directDescriptor);
    if ([path length] == 0) {
        [self populateOperatorErrorReplyEvent:replyEvent
                                      eventID:kSlateAppleEventOpenPath
                                  errorNumber:paramErr
                                         code:@"expectedPath"
                                      message:SMAutomationErrorExpectedPath];
        return;
    }

    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [self populateOperatorErrorReplyEvent:replyEvent
                                      eventID:kSlateAppleEventOpenPath
                                  errorNumber:fnfErr
                                         code:@"pathNotFound"
                                      message:[NSString stringWithFormat:@"Path does not exist: %@", path]];
        return;
    }

    [self application:[NSApplication sharedApplication] openFile:path];
    NSDictionary *payload = [NSDictionary dictionaryWithObject:path forKey:SlateRuntimeCommandKeyPath];
    NSDictionary *commandResult = [SlateRuntimeBridge commandResultWithCommand:SlateRuntimeCommandOpenPath
                                                                    payload:payload
                                                                     result:[NSDictionary dictionaryWithObject:path
                                                                                                        forKey:SlateRuntimeCommandKeyPath]];
    [self populateOperatorReplyEvent:replyEvent
                              eventID:kSlateAppleEventOpenPath
                          resultObject:commandResult];
}

- (void)handleAppleEventTrackMovieDetailsWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                             replyEvent:(NSAppleEventDescriptor *)replyEvent
{
    #pragma unused(directDescriptor)
    NSDictionary *payload = [self automationTrackMovieDetailsPayload];
    NSString *errorCode = [payload objectForKey:@"error"];
    if ([errorCode length] > 0) {
        [self populateOperatorErrorReplyEvent:replyEvent
                                      eventID:kSlateAppleEventTrackMovieDetails
                                  errorNumber:errAENoSuchObject
                                         code:errorCode
                                      message:[payload objectForKey:@"message"]];
        return;
    }

    [self populateOperatorReplyEvent:replyEvent
                              eventID:kSlateAppleEventTrackMovieDetails
                          resultObject:payload];
}

- (void)handleAppleEventChapterDetailsWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                          replyEvent:(NSAppleEventDescriptor *)replyEvent
{
    #pragma unused(directDescriptor)
    NSDictionary *payload = [self automationChapterDetailsPayload];
    NSString *errorCode = [payload objectForKey:@"error"];
    if ([errorCode length] > 0) {
        [self populateOperatorErrorReplyEvent:replyEvent
                                      eventID:kSlateAppleEventChapterDetails
                                  errorNumber:errAENoSuchObject
                                         code:errorCode
                                      message:[payload objectForKey:@"message"]];
        return;
    }

    [self populateOperatorReplyEvent:replyEvent
                              eventID:kSlateAppleEventChapterDetails
                          resultObject:payload];
}

- (void)handleAppleEventReadinessReportWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                           replyEvent:(NSAppleEventDescriptor *)replyEvent
{
    #pragma unused(directDescriptor)
    NSDictionary *payload = [self automationReadinessReportPayload];
    NSString *errorCode = [payload objectForKey:@"error"];
    if ([errorCode length] > 0) {
        [self populateOperatorErrorReplyEvent:replyEvent
                                      eventID:kSlateAppleEventReadinessReport
                                  errorNumber:errAENoSuchObject
                                         code:errorCode
                                      message:[payload objectForKey:@"message"]];
        return;
    }

    [self populateOperatorReplyEvent:replyEvent
                              eventID:kSlateAppleEventReadinessReport
                          resultObject:payload];
}

- (void)handleAppleEventReadinessSummaryWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                            replyEvent:(NSAppleEventDescriptor *)replyEvent
{
    #pragma unused(directDescriptor)
    NSDictionary *payload = [self automationReadinessSummaryPayload];
    NSString *errorCode = [payload objectForKey:@"error"];
    if ([errorCode length] > 0) {
        [self populateOperatorErrorReplyEvent:replyEvent
                                      eventID:kSlateAppleEventReadinessSummary
                                  errorNumber:errAENoSuchObject
                                         code:errorCode
                                      message:[payload objectForKey:@"message"]];
        return;
    }

    [self populateOperatorReplyEvent:replyEvent
                              eventID:kSlateAppleEventReadinessSummary
                          resultObject:payload];
}

- (void)handleSlateAppleEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
    AEEventID eventID = [event eventID];
    NSAppleEventDescriptor *directDescriptor = [event paramDescriptorForKeyword:keyDirectObject];
    [self dispatchAppleEventWithID:eventID directDescriptor:directDescriptor replyEvent:replyEvent];
}

@end
