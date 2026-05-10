//
//  SlateRuntimeBridge.m
//  Slate
//
//  Created by Jerry Hale on 3/20/26
//  Copyright (c) 2026 Jerry Hale All rights reserved.
//

#import "Runtime/SlateRuntimeBridge.h"

#import "Movie/SMMovie.h"
#import "Runtime/SlateChapterSnapshotContract.h"
#import "Runtime/SlatePackageContextContract.h"
#import "Runtime/SlatePackageSnapshotContract.h"
#import "Runtime/SlateReviewSnapshotContract.h"
#import "Runtime/SlateRuntimeAcquisitionContract.h"
#import "Runtime/SlateRuntimeCommandContract.h"
#import "Runtime/SlateTimelineSnapshotContract.h"
#import "Runtime/SlateTrackSnapshotContract.h"
#import "Runtime/SlateValidationRuntimeContract.h"
#import "Validation/SMValidationCanonicalDictionaryKeys.h"

#import <dispatch/dispatch.h>
#import <math.h>

#pragma mark - Package Snapshot Helpers

static NSString * const SlateRuntimeProcessResultStdoutDataKey = @"stdoutData";
static NSString * const SlateRuntimeProcessResultStderrDataKey = @"stderrData";
static NSString * const SlateRuntimeProcessResultTerminationStatusKey = @"terminationStatus";
static NSString * const SlateRuntimeProcessResultExceptionReasonKey = @"exceptionReason";

static BOOL SlateRuntimeStringHasContent(NSString *value)
{
    if (![value isKindOfClass:[NSString class]]) {
        return NO;
    }

    return [[value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] > 0;
}

static NSString *SlateRuntimeStringOrEmpty(id value)
{
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

static NSString *SlateRuntimeStringFromData(NSData *data)
{
    if (![data isKindOfClass:[NSData class]] || [data length] == 0) {
        return @"";
    }

    NSString *string = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    return string ?: @"";
}

static NSNumber *SlateRuntimeNumber(double value)
{
    return [NSNumber numberWithDouble:(isfinite(value) ? value : 0.0)];
}

static NSArray *SlateRuntimeDictionaryRowsOrEmpty(id value)
{
    if (![value isKindOfClass:[NSArray class]]) {
        return [NSArray array];
    }

    NSMutableArray *rows = [NSMutableArray arrayWithCapacity:[value count]];
    for (id row in value) {
        if ([row isKindOfClass:[NSDictionary class]]) {
            [rows addObject:row];
        }
    }

    return rows;
}

static NSDictionary *SlateRuntimeDictionaryOrEmpty(id value)
{
    return [value isKindOfClass:[NSDictionary class]] ? value : [NSDictionary dictionary];
}

static NSDictionary *SlateRuntimeProcessResult(NSData *stdoutData, NSData *stderrData, int terminationStatus, NSString *exceptionReason)
{
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   stdoutData ?: [NSData data], SlateRuntimeProcessResultStdoutDataKey,
                                   stderrData ?: [NSData data], SlateRuntimeProcessResultStderrDataKey,
                                   [NSNumber numberWithInt:terminationStatus], SlateRuntimeProcessResultTerminationStatusKey,
                                   nil];
    if (SlateRuntimeStringHasContent(exceptionReason)) {
        [result setObject:exceptionReason forKey:SlateRuntimeProcessResultExceptionReasonKey];
    }
    return result;
}

static NSData *SlateRuntimeProcessData(NSDictionary *result, NSString *key)
{
    NSData *data = [result objectForKey:key];
    return [data isKindOfClass:[NSData class]] ? data : [NSData data];
}

static int SlateRuntimeProcessTerminationStatus(NSDictionary *result)
{
    NSNumber *terminationStatus = [result objectForKey:SlateRuntimeProcessResultTerminationStatusKey];
    return [terminationStatus respondsToSelector:@selector(intValue)] ? [terminationStatus intValue] : -1;
}

static NSString *SlateRuntimeProcessExceptionReason(NSDictionary *result)
{
    return SlateRuntimeStringOrEmpty([result objectForKey:SlateRuntimeProcessResultExceptionReasonKey]);
}

static NSString *SlateRuntimeProcessStderrText(NSDictionary *result)
{
    return SlateRuntimeStringFromData(SlateRuntimeProcessData(result, SlateRuntimeProcessResultStderrDataKey));
}

static void SlateRuntimeClosePipeWriter(NSPipe *pipe)
{
    if (pipe == nil) {
        return;
    }

    @try {
        [[pipe fileHandleForWriting] closeFile];
    }
    @catch (NSException *exception) {
        #pragma unused(exception)
    }
}

static NSDictionary *SlateRuntimeRunExecutable(NSString *launchPath, NSArray *arguments, NSData *stdinData)
{
    if (!SlateRuntimeStringHasContent(launchPath)) {
        return nil;
    }

    NSTask *task = [[[NSTask alloc] init] autorelease];
    NSPipe *stdinPipe = (stdinData != nil) ? [NSPipe pipe] : nil;
    NSPipe *stdoutPipe = [NSPipe pipe];
    NSPipe *stderrPipe = [NSPipe pipe];
    [task setLaunchPath:launchPath];
    [task setArguments:([arguments isKindOfClass:[NSArray class]] ? arguments : [NSArray array])];
    if (stdinPipe != nil) {
        [task setStandardInput:stdinPipe];
    }
    [task setStandardOutput:stdoutPipe];
    [task setStandardError:stderrPipe];

    __block NSData *stdoutData = nil;
    __block NSData *stderrData = nil;
    dispatch_group_t drainGroup = dispatch_group_create();
    BOOL launched = NO;

    @try {
        [task launch];
        launched = YES;

        dispatch_group_async(drainGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            @autoreleasepool {
                NSData *data = [[stdoutPipe fileHandleForReading] readDataToEndOfFile];
                stdoutData = [data retain];
            }
        });
        dispatch_group_async(drainGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            @autoreleasepool {
                NSData *data = [[stderrPipe fileHandleForReading] readDataToEndOfFile];
                stderrData = [data retain];
            }
        });

        if (stdinData != nil) {
            [[stdinPipe fileHandleForWriting] writeData:stdinData];
            [[stdinPipe fileHandleForWriting] closeFile];
        }

        [task waitUntilExit];
        dispatch_group_wait(drainGroup, DISPATCH_TIME_FOREVER);
    }
    @catch (NSException *exception) {
        SlateRuntimeClosePipeWriter(stdinPipe);
        if (launched) {
            @try {
                [task terminate];
            }
            @catch (NSException *terminateException) {
                #pragma unused(terminateException)
            }
            dispatch_group_wait(drainGroup, DISPATCH_TIME_FOREVER);
        }

        NSDictionary *result = SlateRuntimeProcessResult(stdoutData, stderrData, -1, [exception reason]);
        [stdoutData release];
        [stderrData release];
        return result;
    }

    NSDictionary *result = SlateRuntimeProcessResult(stdoutData, stderrData, [task terminationStatus], nil);
    [stdoutData release];
    [stderrData release];
    return result;
}

static NSDictionary *SlateRuntimeRectDictionary(NSRect rect)
{
    return [NSDictionary dictionaryWithObjectsAndKeys:
            SlateRuntimeNumber(NSMinX(rect)), SlateTimelineSnapshotRectKeyX,
            SlateRuntimeNumber(NSMinY(rect)), SlateTimelineSnapshotRectKeyY,
            SlateRuntimeNumber(NSWidth(rect)), SlateTimelineSnapshotRectKeyWidth,
            SlateRuntimeNumber(NSHeight(rect)), SlateTimelineSnapshotRectKeyHeight,
            nil];
}

static NSDictionary *SlateRuntimeAcquisitionRuntimeEntryWithStatus(NSString *name, NSString *artifactName, NSString *status)
{
    return [NSDictionary dictionaryWithObjectsAndKeys:
            SlateRuntimeStringOrEmpty(name), SlateRuntimeAcquisitionRuntimeKeyName,
            SlateRuntimeStringHasContent(status) ? status : SlateRuntimeAcquisitionStatusMissing, SlateRuntimeAcquisitionRuntimeKeyStatus,
            SlateRuntimeStringOrEmpty(artifactName), SlateRuntimeAcquisitionRuntimeKeyArtifactName,
            [NSNumber numberWithBool:NO], SlateRuntimeAcquisitionRuntimeKeyRequired,
            nil];
}

static NSString *SlateRuntimePackageRuntimeExecutableName(void)
{
    return @"SlatePackageRuntime";
}

static NSString *SlateRuntimeValidationRuntimeExecutableName(void)
{
    return SlateValidationRuntimeExecutableName;
}

static NSString *SlateRuntimeTrackRuntimeExecutableName(void)
{
    return @"SlateTrackRuntime";
}

static NSString *SlateRuntimeChapterRuntimeExecutableName(void)
{
    return @"SlateChapterRuntime";
}

static NSString *SlateRuntimeReviewRuntimeExecutableName(void)
{
    return @"SlateReviewRuntime";
}

static NSString *SlateRuntimeTimelineRuntimeExecutableName(void)
{
    return @"SlateTimelineRuntime";
}

static BOOL SlateRuntimeExecutableExistsAtPath(NSString *path)
{
    if (!SlateRuntimeStringHasContent(path)) {
        return NO;
    }
    return [[NSFileManager defaultManager] isExecutableFileAtPath:[path stringByExpandingTildeInPath]];
}

static void SlateRuntimeAddCandidateExecutablePath(NSMutableArray *candidates, NSString *path)
{
    if (!SlateRuntimeStringHasContent(path) || candidates == nil) {
        return;
    }
    NSString *expandedPath = [path stringByExpandingTildeInPath];
    if (![candidates containsObject:expandedPath]) {
        [candidates addObject:expandedPath];
    }
}

static NSArray *SlateRuntimeExecutableCandidates(NSString *executableName, NSString *environmentKey)
{
    NSMutableArray *candidates = [NSMutableArray array];
    NSString *environmentPath = SlateRuntimeStringHasContent(environmentKey)
        ? [[[NSProcessInfo processInfo] environment] objectForKey:environmentKey]
        : nil;
    SlateRuntimeAddCandidateExecutablePath(candidates, environmentPath);

    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *mainBundlePath = [mainBundle bundlePath];
    NSString *bundleParent = [mainBundlePath stringByDeletingLastPathComponent];
    SlateRuntimeAddCandidateExecutablePath(candidates, [bundleParent stringByAppendingPathComponent:executableName]);

    return candidates;
}

static NSMutableDictionary *SlateRuntimeExecutablePathCache(void)
{
    static NSMutableDictionary *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[NSMutableDictionary alloc] init];
    });
    return cache;
}

static NSString *SlateRuntimeExecutablePathCacheKey(NSString *executableName, NSString *environmentKey)
{
    return [NSString stringWithFormat:@"%@|%@",
            SlateRuntimeStringOrEmpty(executableName),
            SlateRuntimeStringOrEmpty(environmentKey)];
}

static NSString *SlateRuntimeCachedExecutablePath(NSString *cacheKey)
{
    if (!SlateRuntimeStringHasContent(cacheKey)) {
        return nil;
    }

    NSMutableDictionary *cache = SlateRuntimeExecutablePathCache();
    @synchronized(cache) {
        NSString *cachedPath = [cache objectForKey:cacheKey];
        return [cachedPath isKindOfClass:[NSString class]] ? cachedPath : nil;
    }
}

static void SlateRuntimeCacheExecutablePath(NSString *cacheKey, NSString *path)
{
    if (!SlateRuntimeStringHasContent(cacheKey) || !SlateRuntimeStringHasContent(path)) {
        return;
    }

    NSMutableDictionary *cache = SlateRuntimeExecutablePathCache();
    @synchronized(cache) {
        [cache setObject:path forKey:cacheKey];
    }
}

static NSString *SlateRuntimeExecutablePathForRuntime(NSString *executableName, NSString *environmentKey)
{
    NSString *cacheKey = SlateRuntimeExecutablePathCacheKey(executableName, environmentKey);
    NSString *cachedPath = SlateRuntimeCachedExecutablePath(cacheKey);
    if (SlateRuntimeStringHasContent(cachedPath) && SlateRuntimeExecutableExistsAtPath(cachedPath)) {
        return cachedPath;
    }

    for (NSString *candidate in SlateRuntimeExecutableCandidates(executableName, environmentKey)) {
        if (SlateRuntimeExecutableExistsAtPath(candidate)) {
            SlateRuntimeCacheExecutablePath(cacheKey, candidate);
            return candidate;
        }
    }
    return nil;
}

static NSString *SlateRuntimePackageRuntimeExecutablePath(void)
{
    return SlateRuntimeExecutablePathForRuntime(SlateRuntimePackageRuntimeExecutableName(), @"SLATE_PACKAGE_RUNTIME_PATH");
}

static NSString *SlateRuntimeValidationRuntimeExecutablePath(void)
{
    return SlateRuntimeExecutablePathForRuntime(SlateRuntimeValidationRuntimeExecutableName(), SlateValidationRuntimeEnvironmentKey);
}

static NSString *SlateRuntimeTrackRuntimeExecutablePath(void)
{
    return SlateRuntimeExecutablePathForRuntime(SlateRuntimeTrackRuntimeExecutableName(), @"SLATE_TRACK_RUNTIME_PATH");
}

static NSString *SlateRuntimeChapterRuntimeExecutablePath(void)
{
    return SlateRuntimeExecutablePathForRuntime(SlateRuntimeChapterRuntimeExecutableName(), @"SLATE_CHAPTER_RUNTIME_PATH");
}

static NSString *SlateRuntimeReviewRuntimeExecutablePath(void)
{
    return SlateRuntimeExecutablePathForRuntime(SlateRuntimeReviewRuntimeExecutableName(), @"SLATE_REVIEW_RUNTIME_PATH");
}

static NSString *SlateRuntimeTimelineRuntimeExecutablePath(void)
{
    return SlateRuntimeExecutablePathForRuntime(SlateRuntimeTimelineRuntimeExecutableName(), @"SLATE_TIMELINE_RUNTIME_PATH");
}

static BOOL SlateRuntimePackageSnapshotIsUsable(NSDictionary *snapshot)
{
    if (![snapshot isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    return [[snapshot objectForKey:SlatePackageSnapshotKeySchemaVersion] isEqualToString:SlatePackageSnapshotSchemaVersion1];
}

static NSDictionary *SlateRuntimeTrackEmptySnapshot(BOOL hasMovie)
{
    return [NSDictionary dictionaryWithObjectsAndKeys:
            SlateTrackSnapshotSchemaVersion1, SlateTrackSnapshotKeySchemaVersion,
            [NSNumber numberWithBool:hasMovie], SlateTrackSnapshotKeyHasMovie,
            [NSArray array], SlateTrackSnapshotKeyRows,
            [NSNumber numberWithUnsignedInteger:0], SlateTrackSnapshotKeyTrackCount,
            nil];
}

static NSDictionary *SlateRuntimeTrackUnavailableSnapshot(BOOL hasMovie, NSString *code, NSString *message)
{
    NSMutableDictionary *snapshot = [NSMutableDictionary dictionaryWithDictionary:SlateRuntimeTrackEmptySnapshot(hasMovie)];
    NSDictionary *error = [NSDictionary dictionaryWithObjectsAndKeys:
                           SlateRuntimeStringOrEmpty(code), SlateTrackSnapshotErrorKeyCode,
                           SlateRuntimeStringHasContent(message) ? message : @"SlateTrackRuntime could not produce track snapshot output.", SlateTrackSnapshotErrorKeyMessage,
                           nil];
    [snapshot setObject:error forKey:SlateTrackSnapshotKeyError];
    return snapshot;
}

static NSDictionary *SlateRuntimeChapterEmptySnapshot(BOOL hasPackage)
{
    return [NSDictionary dictionaryWithObjectsAndKeys:
            SlateChapterSnapshotSchemaVersion1, SlateChapterSnapshotKeySchemaVersion,
            [NSNumber numberWithBool:hasPackage], SlateChapterSnapshotKeyHasPackage,
            [NSArray array], SlateChapterSnapshotKeyRows,
            [NSNumber numberWithUnsignedInteger:0], SlateChapterSnapshotKeyChapterCount,
            nil];
}

static NSDictionary *SlateRuntimeChapterUnavailableSnapshot(BOOL hasPackage, NSString *code, NSString *message)
{
    NSMutableDictionary *snapshot = [NSMutableDictionary dictionaryWithDictionary:SlateRuntimeChapterEmptySnapshot(hasPackage)];
    NSDictionary *error = [NSDictionary dictionaryWithObjectsAndKeys:
                           SlateRuntimeStringOrEmpty(code), SlateChapterSnapshotErrorKeyCode,
                           SlateRuntimeStringHasContent(message) ? message : @"SlateChapterRuntime could not produce chapter snapshot output.", SlateChapterSnapshotErrorKeyMessage,
                           nil];
    [snapshot setObject:error forKey:SlateChapterSnapshotKeyError];
    return snapshot;
}

static BOOL SlateRuntimePackageContextIsUsable(NSDictionary *context)
{
    if (![context isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    return [[context objectForKey:SlatePackageContextKeySchemaVersion] isEqualToString:SlatePackageContextSchemaVersion1];
}

static NSDictionary *SlateRuntimePackageUnavailableContext(NSString *packagePath, NSString *code, NSString *message)
{
    NSDictionary *source = [NSDictionary dictionaryWithObjectsAndKeys:
                            SlateRuntimeStringOrEmpty(packagePath), SlatePackageSnapshotSourceKeyPath,
                            nil];
    NSDictionary *error = [NSDictionary dictionaryWithObjectsAndKeys:
                           SlateRuntimeStringOrEmpty(code), SlatePackageContextErrorKeyCode,
                           SlateRuntimeStringHasContent(message) ? message : @"SlatePackageRuntime could not produce package context.", SlatePackageContextErrorKeyMessage,
                           nil];
    return [NSDictionary dictionaryWithObjectsAndKeys:
            SlatePackageContextSchemaVersion1, SlatePackageContextKeySchemaVersion,
            [NSNumber numberWithBool:NO], SlatePackageContextKeyHasPackage,
            source, SlatePackageContextKeySource,
            error, SlatePackageContextKeyError,
            nil];
}

static NSDictionary *SlateRuntimePackagePayloadFromExecutable(NSString *command, NSString *packagePath)
{
    NSString *runtimePath = SlateRuntimePackageRuntimeExecutablePath();
    if (!SlateRuntimeStringHasContent(runtimePath) || !SlateRuntimeStringHasContent(packagePath)) {
        return nil;
    }

    NSDictionary *processResult = SlateRuntimeRunExecutable(runtimePath,
                                                         [NSArray arrayWithObjects:(SlateRuntimeStringHasContent(command) ? command : @"snapshot"), @"--package", packagePath, nil],
                                                         nil);
    if (processResult == nil || SlateRuntimeStringHasContent(SlateRuntimeProcessExceptionReason(processResult))) {
        return nil;
    }

    if (SlateRuntimeProcessTerminationStatus(processResult) != 0) {
        NSString *stderrText = SlateRuntimeProcessStderrText(processResult);
        return SlateRuntimePackageUnavailableContext(packagePath,
                                                  @"runtime.package_failed",
                                                  SlateRuntimeStringHasContent(stderrText) ? stderrText : @"SlatePackageRuntime reported a package error.");
    }

    NSData *stdoutData = SlateRuntimeProcessData(processResult, SlateRuntimeProcessResultStdoutDataKey);
    if ([stdoutData length] == 0) {
        return nil;
    }

    NSError *jsonError = nil;
    id jsonObject = [NSJSONSerialization JSONObjectWithData:stdoutData options:0 error:&jsonError];
    if (![jsonObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    return (NSDictionary *)jsonObject;
}

static NSDictionary *SlateRuntimePackageContextFromExecutable(NSString *packagePath)
{
    if (!SlateRuntimeStringHasContent(SlateRuntimePackageRuntimeExecutablePath())) {
        return SlateRuntimePackageUnavailableContext(packagePath,
                                                  @"runtime.package_missing",
                                                  @"SlatePackageRuntime is missing from the same directory as Slate.app.");
    }

    NSDictionary *context = SlateRuntimePackagePayloadFromExecutable(@"context", packagePath);
    return SlateRuntimePackageContextIsUsable(context)
        ? context
        : SlateRuntimePackageUnavailableContext(packagePath,
                                             @"runtime.package_bad_contract",
                                             @"SlatePackageRuntime context did not satisfy package context contract.");
}

static NSDictionary *SlateRuntimePackageSnapshotFromExecutable(NSString *packagePath)
{
    NSDictionary *snapshot = SlateRuntimePackagePayloadFromExecutable(@"snapshot", packagePath);
    return SlateRuntimePackageSnapshotIsUsable(snapshot) ? snapshot : nil;
}

static BOOL SlateRuntimeTrackSnapshotIsUsable(NSDictionary *snapshot)
{
    if (![snapshot isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    return [[snapshot objectForKey:SlateTrackSnapshotKeySchemaVersion] isEqualToString:SlateTrackSnapshotSchemaVersion1];
}

static NSDictionary *SlateRuntimeTrackSnapshotFromExecutable(SMMovie *movie)
{
    NSString *runtimePath = SlateRuntimeTrackRuntimeExecutablePath();
    NSString *moviePath = [[movie URL] path];
    if (!SlateRuntimeStringHasContent(runtimePath) || !SlateRuntimeStringHasContent(moviePath)) {
        return nil;
    }

    NSDictionary *processResult = SlateRuntimeRunExecutable(runtimePath,
                                                         [NSArray arrayWithObjects:@"snapshot", @"--movie", moviePath, nil],
                                                         nil);
    if (processResult == nil || SlateRuntimeStringHasContent(SlateRuntimeProcessExceptionReason(processResult))) {
        return nil;
    }

    NSData *stdoutData = SlateRuntimeProcessData(processResult, SlateRuntimeProcessResultStdoutDataKey);
    if (SlateRuntimeProcessTerminationStatus(processResult) != 0 || [stdoutData length] == 0) {
        return nil;
    }

    NSError *jsonError = nil;
    id jsonObject = [NSJSONSerialization JSONObjectWithData:stdoutData options:0 error:&jsonError];
    if (![jsonObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSDictionary *snapshot = (NSDictionary *)jsonObject;
    return SlateRuntimeTrackSnapshotIsUsable(snapshot) ? snapshot : nil;
}

static BOOL SlateRuntimeChapterSnapshotIsUsable(NSDictionary *snapshot)
{
    if (![snapshot isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    return [[snapshot objectForKey:SlateChapterSnapshotKeySchemaVersion] isEqualToString:SlateChapterSnapshotSchemaVersion1];
}

static NSDictionary *SlateRuntimeChapterSnapshotFromExecutable(NSString *packagePath, SMMovie *movie)
{
    NSString *runtimePath = SlateRuntimeChapterRuntimeExecutablePath();
    NSString *moviePath = [[movie URL] path];
    if (!SlateRuntimeStringHasContent(runtimePath) || !SlateRuntimeStringHasContent(packagePath)) {
        return nil;
    }

    NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"snapshot", @"--package", packagePath, nil];
    if (SlateRuntimeStringHasContent(moviePath)) {
        [arguments addObject:@"--movie"];
        [arguments addObject:moviePath];
    }

    NSDictionary *processResult = SlateRuntimeRunExecutable(runtimePath, arguments, nil);
    if (processResult == nil || SlateRuntimeStringHasContent(SlateRuntimeProcessExceptionReason(processResult))) {
        return nil;
    }

    NSData *stdoutData = SlateRuntimeProcessData(processResult, SlateRuntimeProcessResultStdoutDataKey);
    if (SlateRuntimeProcessTerminationStatus(processResult) != 0 || [stdoutData length] == 0) {
        return nil;
    }

    NSError *jsonError = nil;
    id jsonObject = [NSJSONSerialization JSONObjectWithData:stdoutData options:0 error:&jsonError];
    if (![jsonObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSDictionary *snapshot = (NSDictionary *)jsonObject;
    return SlateRuntimeChapterSnapshotIsUsable(snapshot) ? snapshot : nil;
}

static NSDictionary *SlateRuntimeValidationUnavailableReport(NSString *code, NSString *message)
{
    NSDictionary *finding = [NSDictionary dictionaryWithObjectsAndKeys:
                             SlateRuntimeStringHasContent(code) ? code : @"runtime.validation_unavailable", SMValidationFindingKeyCode,
                             SMValidationSeverityCodeBlocker, SMValidationFindingKeySeverity,
                             SMValidationCategoryCodePackage, SMValidationFindingKeyCategory,
                             @"runtime", SMValidationFindingKeyScope,
                             @"Validation runtime is unavailable", SMValidationFindingKeyTitle,
                             SlateRuntimeStringHasContent(message) ? message : @"SlateValidationRuntime could not be launched.", SMValidationFindingKeyEvidence,
                             [NSNumber numberWithBool:NO], SMValidationFindingKeyFallbackUsed,
                             @"runtime-contract", SMValidationFindingKeyIdentitySource,
                             nil];
    NSArray *findings = [NSArray arrayWithObject:finding];
    NSDictionary *summary = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithUnsignedInteger:1], SMValidationSummaryKeyBlockers,
                             [NSNumber numberWithUnsignedInteger:0], SMValidationSummaryKeyWarnings,
                             [NSNumber numberWithUnsignedInteger:1], SMValidationSummaryKeyTotal,
                             nil];
    NSDictionary *payload = [NSDictionary dictionaryWithObjectsAndKeys:
                             SMValidationResultPayloadSchemaVersion1, SMValidationResultPayloadKeySchemaVersion,
                             findings, SMValidationResultPayloadKeyFindings,
                             nil];
    NSString *operatorText = [NSString stringWithFormat:@"Blockers (1)\n- Validation runtime is unavailable\n  %@",
                              SlateRuntimeStringHasContent(message) ? message : @"SlateValidationRuntime could not be launched."];
    return [NSDictionary dictionaryWithObjectsAndKeys:
            SMValidationSchemaVersion1, SMValidationReportKeySchemaVersion,
            SMValidationSeverityCodeBlocker, SMValidationReportKeyStatus,
            summary, SMValidationReportKeySummary,
            finding, SMValidationReportKeyNextFinding,
            findings, SMValidationReportKeyFindings,
            operatorText, SMValidationReportKeyOperatorText,
            payload, SMValidationReportKeyValidationResultPayload,
            nil];
}

static BOOL SlateRuntimeValidationReportIsUsable(NSDictionary *report)
{
    if (![report isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    if (![[report objectForKey:SMValidationReportKeySchemaVersion] isEqualToString:SMValidationSchemaVersion1]) {
        return NO;
    }
    return ([[report objectForKey:SMValidationReportKeySummary] isKindOfClass:[NSDictionary class]]
            && [[report objectForKey:SMValidationReportKeyFindings] isKindOfClass:[NSArray class]]
            && [[report objectForKey:SMValidationReportKeyOperatorText] isKindOfClass:[NSString class]]);
}

static NSDictionary *SlateRuntimeValidationReportFromExecutable(NSString *packagePath, NSDictionary *observedState)
{
    NSString *runtimePath = SlateRuntimeValidationRuntimeExecutablePath();
    if (!SlateRuntimeStringHasContent(runtimePath)) {
        return SlateRuntimeValidationUnavailableReport(@"runtime.validation_missing",
                                                   @"SlateValidationRuntime is missing from the same directory as Slate.app.");
    }

    NSMutableArray *arguments = [NSMutableArray arrayWithObject:@"report"];
    if (SlateRuntimeStringHasContent(packagePath)) {
        [arguments addObject:@"--package"];
        [arguments addObject:packagePath];
    }

    NSData *inputData = nil;
    if ([observedState isKindOfClass:[NSDictionary class]]) {
        NSError *serializationError = nil;
        inputData = [NSJSONSerialization dataWithJSONObject:observedState options:0 error:&serializationError];
        if ([inputData length] == 0) {
            return SlateRuntimeValidationUnavailableReport(@"runtime.validation_observed_state_invalid",
                                                       @"Observed state could not be serialized for SlateValidationRuntime.");
        }
        [arguments addObject:@"--observed-state"];
        [arguments addObject:@"-"];
    }

    NSDictionary *processResult = SlateRuntimeRunExecutable(runtimePath, arguments, inputData);
    NSString *exceptionReason = SlateRuntimeProcessExceptionReason(processResult);
    if (processResult == nil || SlateRuntimeStringHasContent(exceptionReason)) {
        return SlateRuntimeValidationUnavailableReport(@"runtime.validation_launch_failed",
                                                   exceptionReason);
    }

    NSData *stdoutData = SlateRuntimeProcessData(processResult, SlateRuntimeProcessResultStdoutDataKey);
    if ([stdoutData length] == 0) {
        NSString *stderrText = SlateRuntimeProcessStderrText(processResult);
        return SlateRuntimeValidationUnavailableReport(@"runtime.validation_no_output",
                                                   SlateRuntimeStringHasContent(stderrText) ? stderrText : @"SlateValidationRuntime produced no report output.");
    }

    NSError *jsonError = nil;
    id jsonObject = [NSJSONSerialization JSONObjectWithData:stdoutData options:0 error:&jsonError];
    if (![jsonObject isKindOfClass:[NSDictionary class]]) {
        return SlateRuntimeValidationUnavailableReport(@"runtime.validation_bad_output",
                                                   @"SlateValidationRuntime produced malformed report JSON.");
    }

    NSDictionary *report = (NSDictionary *)jsonObject;
    if (!SlateRuntimeValidationReportIsUsable(report)) {
        return SlateRuntimeValidationUnavailableReport(@"runtime.validation_bad_contract",
                                                   @"SlateValidationRuntime report did not satisfy validation report contract.");
    }

    return report;
}

static NSArray *SlateRuntimeReviewFindingsWithSeverity(NSArray *findings, NSString *severity)
{
    NSArray *safeFindings = SlateRuntimeDictionaryRowsOrEmpty(findings);
    if ([safeFindings count] == 0 || !SlateRuntimeStringHasContent(severity)) {
        return [NSArray array];
    }

    NSMutableArray *matches = [NSMutableArray array];
    NSString *normalizedSeverity = [severity lowercaseString];
    for (NSDictionary *finding in safeFindings) {
        NSString *findingSeverity = [[finding objectForKey:SMValidationFindingKeySeverity] lowercaseString];
        if ([findingSeverity isEqualToString:normalizedSeverity]) {
            [matches addObject:finding];
        }
    }
    return matches;
}

static NSString *SlateRuntimeReviewStatusForCounts(NSUInteger blockerCount, NSUInteger warningCount)
{
    if (blockerCount > 0) {
        return SMValidationSeverityCodeBlocker;
    }
    if (warningCount > 0) {
        return SMValidationSeverityCodeWarning;
    }
    return SMValidationStatusPass;
}

static NSString *SlateRuntimeReviewDisplayTextForFindings(NSArray *findings)
{
    NSArray *safeFindings = SlateRuntimeDictionaryRowsOrEmpty(findings);
    if ([safeFindings count] == 0) {
        return @"No readiness findings.";
    }

    NSMutableArray *lines = [NSMutableArray arrayWithCapacity:[safeFindings count]];
    for (NSDictionary *finding in safeFindings) {
        NSString *severity = SlateRuntimeStringOrEmpty([finding objectForKey:SMValidationFindingKeySeverity]);
        NSString *title = SlateRuntimeStringOrEmpty([finding objectForKey:SMValidationFindingKeyTitle]);
        NSString *evidence = SlateRuntimeStringOrEmpty([finding objectForKey:SMValidationFindingKeyEvidence]);
        [lines addObject:[NSString stringWithFormat:@"%@: %@", severity, title]];
        if (SlateRuntimeStringHasContent(evidence)) {
            [lines addObject:[NSString stringWithFormat:@"  %@", evidence]];
        }
    }
    return [lines componentsJoinedByString:@"\n"];
}

static NSDictionary *SlateRuntimeReviewPaneSnapshot(NSString *paneKey,
                                                 NSString *title,
                                                 NSArray *findings,
                                                 NSString *emptyStatus,
                                                 NSString *emptyMessage,
                                                 NSDictionary *jumpLinksByFindingIdentity)
{
    NSArray *safeFindings = SlateRuntimeDictionaryRowsOrEmpty(findings);
    NSArray *blockers = SlateRuntimeReviewFindingsWithSeverity(safeFindings, SMValidationSeverityCodeBlocker);
    NSArray *warnings = SlateRuntimeReviewFindingsWithSeverity(safeFindings, SMValidationSeverityCodeWarning);
    id nextFinding = [safeFindings count] > 0 ? [safeFindings objectAtIndex:0] : [NSNull null];

    return [NSDictionary dictionaryWithObjectsAndKeys:
            SlateReviewPaneSnapshotSchemaVersion1, SlateReviewPaneSnapshotKeySchemaVersion,
            SlateRuntimeStringOrEmpty(paneKey), SlateReviewPaneSnapshotKeyPane,
            SlateRuntimeStringOrEmpty(title), SlateReviewPaneSnapshotKeyTitle,
            SlateRuntimeReviewStatusForCounts([blockers count], [warnings count]), SlateReviewPaneSnapshotKeyStatus,
            safeFindings, SlateReviewPaneSnapshotKeyFindings,
            [NSNumber numberWithUnsignedInteger:[safeFindings count]], SlateReviewPaneSnapshotKeyFindingCount,
            blockers, SlateReviewPaneSnapshotKeyBlockers,
            warnings, SlateReviewPaneSnapshotKeyWarnings,
            SlateRuntimeStringOrEmpty(emptyStatus), SlateReviewPaneSnapshotKeyEmptyStatus,
            SlateRuntimeStringOrEmpty(emptyMessage), SlateReviewPaneSnapshotKeyEmptyMessage,
            SlateRuntimeDictionaryOrEmpty(jumpLinksByFindingIdentity), SlateReviewPaneSnapshotKeyJumpLinksByFindingIdentity,
            nextFinding, SlateReviewPaneSnapshotKeyNextFinding,
            [NSNull null], SlateReviewPaneSnapshotKeyPreviousFinding,
            SlateRuntimeReviewDisplayTextForFindings(safeFindings), SlateReviewPaneSnapshotKeyDisplayText,
            nil];
}

static BOOL SlateRuntimeReviewPaneSnapshotIsUsable(NSDictionary *snapshot)
{
    if (![snapshot isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    return [[snapshot objectForKey:SlateReviewPaneSnapshotKeySchemaVersion] isEqualToString:SlateReviewPaneSnapshotSchemaVersion1];
}

static NSDictionary *SlateRuntimeReviewPaneUnavailableSnapshot(NSString *paneKey,
                                                           NSString *title,
                                                           NSString *emptyStatus,
                                                           NSString *emptyMessage,
                                                           NSDictionary *jumpLinksByFindingIdentity,
                                                           NSString *code,
                                                           NSString *message)
{
    NSMutableDictionary *snapshot = [NSMutableDictionary dictionaryWithDictionary:
                                     SlateRuntimeReviewPaneSnapshot(paneKey,
                                                                 title,
                                                                 [NSArray array],
                                                                 emptyStatus,
                                                                 emptyMessage,
                                                                 jumpLinksByFindingIdentity)];
    NSDictionary *error = [NSDictionary dictionaryWithObjectsAndKeys:
                           SlateRuntimeStringOrEmpty(code), SlateReviewPaneSnapshotErrorKeyCode,
                           SlateRuntimeStringHasContent(message) ? message : @"SlateReviewRuntime could not produce pane readiness output.", SlateReviewPaneSnapshotErrorKeyMessage,
                           nil];
    [snapshot setObject:error forKey:SlateReviewPaneSnapshotKeyError];
    return snapshot;
}

static BOOL SlateRuntimeReviewSnapshotIsUsable(NSDictionary *snapshot)
{
    if (![snapshot isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    return [[snapshot objectForKey:SlateReviewSnapshotKeySchemaVersion] isEqualToString:SlateReviewSnapshotSchemaVersion1];
}

static NSDictionary *SlateRuntimeReviewUnavailableSnapshot(NSDictionary *context,
                                                        NSString *activePane,
                                                        NSString *code,
                                                        NSString *message)
{
    NSDictionary *finding = [NSDictionary dictionaryWithObjectsAndKeys:
                             SlateRuntimeStringHasContent(code) ? code : @"runtime.review_missing", SMValidationFindingKeyCode,
                             SMValidationSeverityCodeBlocker, SMValidationFindingKeySeverity,
                             SMValidationCategoryCodePackage, SMValidationFindingKeyCategory,
                             @"runtime", SMValidationFindingKeyScope,
                             @"Review runtime is unavailable", SMValidationFindingKeyTitle,
                             SlateRuntimeStringHasContent(message) ? message : @"SlateReviewRuntime is missing from the same directory as Slate.app.", SMValidationFindingKeyEvidence,
                             [NSNumber numberWithBool:NO], SMValidationFindingKeyFallbackUsed,
                             @"runtime-contract", SMValidationFindingKeyIdentitySource,
                             nil];
    NSArray *findings = [NSArray arrayWithObject:finding];
    NSDictionary *summary = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithUnsignedInteger:1], SMValidationSummaryKeyBlockers,
                             [NSNumber numberWithUnsignedInteger:0], SMValidationSummaryKeyWarnings,
                             [NSNumber numberWithUnsignedInteger:1], SMValidationSummaryKeyTotal,
                             nil];
    NSArray *paneOrder = [NSArray arrayWithObjects:SlateReviewPaneKeyPackage, SlateReviewPaneKeyTrack, SlateReviewPaneKeyChapter, nil];
    NSDictionary *panes = [NSDictionary dictionaryWithObjectsAndKeys:
                           SlateRuntimeReviewPaneSnapshot(SlateReviewPaneKeyPackage,
                                                       @"Package Readiness",
                                                       findings,
                                                       @"Review runtime missing",
                                                       @"SlateReviewRuntime could not produce readiness review output.",
                                                       [NSDictionary dictionary]), SlateReviewPaneKeyPackage,
                           SlateRuntimeReviewPaneSnapshot(SlateReviewPaneKeyTrack,
                                                       @"Track Readiness",
                                                       [NSArray array],
                                                       @"Review runtime missing",
                                                       @"SlateReviewRuntime could not produce readiness review output.",
                                                       [NSDictionary dictionary]), SlateReviewPaneKeyTrack,
                           SlateRuntimeReviewPaneSnapshot(SlateReviewPaneKeyChapter,
                                                       @"Chapter Readiness",
                                                       [NSArray array],
                                                       @"Review runtime missing",
                                                       @"SlateReviewRuntime could not produce readiness review output.",
                                                       [NSDictionary dictionary]), SlateReviewPaneKeyChapter,
                           nil];

    return [NSDictionary dictionaryWithObjectsAndKeys:
            SlateReviewSnapshotSchemaVersion1, SlateReviewSnapshotKeySchemaVersion,
            SlateRuntimeDictionaryOrEmpty(context), SlateReviewSnapshotKeyContext,
            SMValidationSeverityCodeBlocker, SlateReviewSnapshotKeyStatus,
            summary, SlateReviewSnapshotKeySummary,
            findings, SlateReviewSnapshotKeyFindings,
            panes, SlateReviewSnapshotKeyPanes,
            paneOrder, SlateReviewSnapshotKeyPaneOrder,
            SlateRuntimeStringOrEmpty(activePane), SlateReviewSnapshotKeyActivePane,
            [NSNumber numberWithInteger:0], SlateReviewSnapshotKeyCurrentFindingIndex,
            finding, SlateReviewSnapshotKeyNextFinding,
            [NSNull null], SlateReviewSnapshotKeyPreviousFinding,
            SlateRuntimeReviewDisplayTextForFindings(findings), SlateReviewSnapshotKeyDisplayText,
            nil];
}

static NSDictionary *SlateRuntimeReviewPaneSnapshotFromExecutable(NSString *paneKey,
                                                               NSString *title,
                                                               NSArray *findings,
                                                               NSString *emptyStatus,
                                                               NSString *emptyMessage,
                                                               NSDictionary *jumpLinksByFindingIdentity)
{
    NSString *runtimePath = SlateRuntimeReviewRuntimeExecutablePath();
    if (!SlateRuntimeStringHasContent(runtimePath)) {
        return nil;
    }

    NSDictionary *payload = [NSDictionary dictionaryWithObjectsAndKeys:
                             SlateRuntimeStringOrEmpty(paneKey), @"paneKey",
                             SlateRuntimeStringOrEmpty(title), @"title",
                             SlateRuntimeDictionaryRowsOrEmpty(findings), @"findings",
                             SlateRuntimeStringOrEmpty(emptyStatus), @"emptyStatus",
                             SlateRuntimeStringOrEmpty(emptyMessage), @"emptyMessage",
                             SlateRuntimeDictionaryOrEmpty(jumpLinksByFindingIdentity), @"jumpLinksByFindingIdentity",
                             nil];
    NSError *serializationError = nil;
    NSData *inputData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&serializationError];
    if ([inputData length] == 0) {
        return nil;
    }

    NSDictionary *processResult = SlateRuntimeRunExecutable(runtimePath,
                                                         [NSArray arrayWithObjects:@"pane", @"--stdin", nil],
                                                         inputData);
    if (processResult == nil || SlateRuntimeStringHasContent(SlateRuntimeProcessExceptionReason(processResult))) {
        return nil;
    }

    NSData *stdoutData = SlateRuntimeProcessData(processResult, SlateRuntimeProcessResultStdoutDataKey);
    if (SlateRuntimeProcessTerminationStatus(processResult) != 0 || [stdoutData length] == 0) {
        return nil;
    }

    NSError *jsonError = nil;
    id jsonObject = [NSJSONSerialization JSONObjectWithData:stdoutData options:0 error:&jsonError];
    if (![jsonObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSDictionary *snapshot = (NSDictionary *)jsonObject;
    return SlateRuntimeReviewPaneSnapshotIsUsable(snapshot) ? snapshot : nil;
}

static NSDictionary *SlateRuntimeReviewSnapshotFromExecutable(NSDictionary *context,
                                                           NSDictionary *canonicalReport,
                                                           NSString *activePane)
{
    NSString *runtimePath = SlateRuntimeReviewRuntimeExecutablePath();
    if (!SlateRuntimeStringHasContent(runtimePath)) {
        return nil;
    }

    NSDictionary *payload = [NSDictionary dictionaryWithObjectsAndKeys:
                             SlateRuntimeDictionaryOrEmpty(context), @"context",
                             SlateRuntimeDictionaryOrEmpty(canonicalReport), @"canonicalReport",
                             SlateRuntimeStringOrEmpty(activePane), @"activePane",
                             nil];
    NSError *serializationError = nil;
    NSData *inputData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&serializationError];
    if ([inputData length] == 0) {
        return nil;
    }

    NSDictionary *processResult = SlateRuntimeRunExecutable(runtimePath,
                                                         [NSArray arrayWithObjects:@"snapshot", @"--stdin", nil],
                                                         inputData);
    if (processResult == nil || SlateRuntimeStringHasContent(SlateRuntimeProcessExceptionReason(processResult))) {
        return nil;
    }

    NSData *stdoutData = SlateRuntimeProcessData(processResult, SlateRuntimeProcessResultStdoutDataKey);
    if (SlateRuntimeProcessTerminationStatus(processResult) != 0 || [stdoutData length] == 0) {
        return nil;
    }

    NSError *jsonError = nil;
    id jsonObject = [NSJSONSerialization JSONObjectWithData:stdoutData options:0 error:&jsonError];
    if (![jsonObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSDictionary *snapshot = (NSDictionary *)jsonObject;
    return SlateRuntimeReviewSnapshotIsUsable(snapshot) ? snapshot : nil;
}

static BOOL SlateRuntimeTimelineSnapshotIsUsable(NSDictionary *snapshot)
{
    if (![snapshot isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    return [[snapshot objectForKey:SlateTimelineSnapshotKeySchemaVersion] isEqualToString:SlateTimelineSnapshotSchemaVersion1];
}

static NSDictionary *SlateRuntimeTimelineSnapshotFromExecutable(NSRect bounds,
                                                            NSTimeInterval duration,
                                                            NSTimeInterval currentTime,
                                                            double frameRate,
                                                            NSTimeInterval selectionStart,
                                                            NSTimeInterval selectionEnd,
                                                            CGFloat sideReadoutWidth,
                                                            CGFloat contentTopInset,
                                                            BOOL usableMovie,
                                                            NSString *currentTimecodeString)
{
    NSString *runtimePath = SlateRuntimeTimelineRuntimeExecutablePath();
    if (!SlateRuntimeStringHasContent(runtimePath) || NSWidth(bounds) <= 0.0 || NSHeight(bounds) <= 0.0) {
        return nil;
    }

    NSDictionary *state = [NSDictionary dictionaryWithObjectsAndKeys:
                           SlateRuntimeNumber(duration), SlateTimelineSnapshotStateKeyDuration,
                           SlateRuntimeNumber(currentTime), SlateTimelineSnapshotStateKeyCurrentTime,
                           SlateRuntimeNumber(frameRate), SlateTimelineSnapshotStateKeyFrameRate,
                           SlateRuntimeNumber(selectionStart), SlateTimelineSnapshotStateKeySelectionStart,
                           SlateRuntimeNumber(selectionEnd), SlateTimelineSnapshotStateKeySelectionEnd,
                           SlateRuntimeStringOrEmpty(currentTimecodeString), SlateTimelineSnapshotStateKeyCurrentTimecodeString,
                           nil];
    NSDictionary *payload = [NSDictionary dictionaryWithObjectsAndKeys:
                             SlateRuntimeRectDictionary(bounds), @"bounds",
                             state, @"state",
                             [NSNumber numberWithBool:usableMovie], @"usableMovie",
                             SlateRuntimeNumber(sideReadoutWidth), @"sideReadoutWidth",
                             SlateRuntimeNumber(contentTopInset), @"contentTopInset",
                             nil];
    NSError *serializationError = nil;
    NSData *inputData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&serializationError];
    if ([inputData length] == 0) {
        return nil;
    }

    NSDictionary *processResult = SlateRuntimeRunExecutable(runtimePath,
                                                         [NSArray arrayWithObjects:@"snapshot", @"--stdin", nil],
                                                         inputData);
    if (processResult == nil || SlateRuntimeStringHasContent(SlateRuntimeProcessExceptionReason(processResult))) {
        return nil;
    }

    NSData *stdoutData = SlateRuntimeProcessData(processResult, SlateRuntimeProcessResultStdoutDataKey);
    if (SlateRuntimeProcessTerminationStatus(processResult) != 0 || [stdoutData length] == 0) {
        return nil;
    }

    NSError *jsonError = nil;
    id jsonObject = [NSJSONSerialization JSONObjectWithData:stdoutData options:0 error:&jsonError];
    if (![jsonObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSDictionary *snapshot = (NSDictionary *)jsonObject;
    return SlateRuntimeTimelineSnapshotIsUsable(snapshot) ? snapshot : nil;
}

@implementation SlateRuntimeBridge

+ (NSDictionary *)packageContextForPackagePath:(NSString *)packagePath
{
    return SlateRuntimePackageContextFromExecutable(packagePath);
}

+ (NSDictionary *)packageSnapshotForPackagePath:(NSString *)packagePath
{
    return SlateRuntimePackageSnapshotFromExecutable(packagePath);
}

+ (NSDictionary *)trackSnapshotForMovie:(SMMovie *)movie hasMovie:(BOOL)hasMovie
{
    if (!hasMovie) {
        return SlateRuntimeTrackEmptySnapshot(NO);
    }
    if (!SlateRuntimeStringHasContent(SlateRuntimeTrackRuntimeExecutablePath())) {
        return SlateRuntimeTrackUnavailableSnapshot(YES,
                                                 @"runtime.track_missing",
                                                 @"SlateTrackRuntime is missing from the same directory as Slate.app.");
    }

    NSDictionary *externalSnapshot = SlateRuntimeTrackSnapshotFromExecutable(movie);
    if (externalSnapshot != nil) {
        return externalSnapshot;
    }

    return SlateRuntimeTrackUnavailableSnapshot(YES,
                                             @"runtime.track_bad_contract",
                                             @"SlateTrackRuntime did not return a usable track snapshot contract.");
}

+ (NSDictionary *)chapterSnapshotForPackagePath:(NSString *)packagePath
                                          movie:(SMMovie *)movie
                                     hasPackage:(BOOL)hasPackage
{
    if (!hasPackage) {
        return SlateRuntimeChapterEmptySnapshot(NO);
    }
    if (!SlateRuntimeStringHasContent(SlateRuntimeChapterRuntimeExecutablePath())) {
        return SlateRuntimeChapterUnavailableSnapshot(YES,
                                                   @"runtime.chapter_missing",
                                                   @"SlateChapterRuntime is missing from the same directory as Slate.app.");
    }

    NSDictionary *externalSnapshot = SlateRuntimeChapterSnapshotFromExecutable(packagePath, movie);
    if (externalSnapshot != nil) {
        return externalSnapshot;
    }

    return SlateRuntimeChapterUnavailableSnapshot(YES,
                                               @"runtime.chapter_bad_contract",
                                               @"SlateChapterRuntime did not return a usable chapter snapshot contract.");
}

+ (NSDictionary *)validationReportForPackagePath:(NSString *)packagePath
                                   observedState:(NSDictionary *)observedState
{
    return SlateRuntimeValidationReportFromExecutable(packagePath, observedState);
}

+ (NSDictionary *)reviewPaneSnapshotWithPaneKey:(NSString *)paneKey
                                          title:(NSString *)title
                                       findings:(NSArray *)findings
                                    emptyStatus:(NSString *)emptyStatus
                                   emptyMessage:(NSString *)emptyMessage
                     jumpLinksByFindingIdentity:(NSDictionary *)jumpLinksByFindingIdentity
{
    if (!SlateRuntimeStringHasContent(SlateRuntimeReviewRuntimeExecutablePath())) {
        return SlateRuntimeReviewPaneUnavailableSnapshot(paneKey,
                                                     title,
                                                     emptyStatus,
                                                     emptyMessage,
                                                     jumpLinksByFindingIdentity,
                                                     @"runtime.review_missing",
                                                     @"SlateReviewRuntime is missing from the same directory as Slate.app.");
    }

    NSDictionary *externalSnapshot = SlateRuntimeReviewPaneSnapshotFromExecutable(paneKey,
                                                                              title,
                                                                              findings,
                                                                              emptyStatus,
                                                                              emptyMessage,
                                                                              jumpLinksByFindingIdentity);
    if (externalSnapshot != nil) {
        return externalSnapshot;
    }

    return SlateRuntimeReviewPaneUnavailableSnapshot(paneKey,
                                                 title,
                                                 emptyStatus,
                                                 emptyMessage,
                                                 jumpLinksByFindingIdentity,
                                                 @"runtime.review_bad_contract",
                                                 @"SlateReviewRuntime did not return a usable pane readiness contract.");
}

+ (NSDictionary *)reviewSnapshotWithContext:(NSDictionary *)context
                             canonicalReport:(NSDictionary *)canonicalReport
                                  activePane:(NSString *)activePane
{
    NSDictionary *externalSnapshot = SlateRuntimeReviewSnapshotFromExecutable(context, canonicalReport, activePane);
    if (externalSnapshot != nil) {
        return externalSnapshot;
    }

    return SlateRuntimeReviewUnavailableSnapshot(context,
                                             activePane,
                                             @"runtime.review_missing",
                                             @"SlateReviewRuntime is missing from the same directory as Slate.app.");
}

+ (NSDictionary *)timelineSnapshotWithBounds:(NSRect)bounds
                                    duration:(NSTimeInterval)duration
                                 currentTime:(NSTimeInterval)currentTime
                                   frameRate:(double)frameRate
                              selectionStart:(NSTimeInterval)selectionStart
                                selectionEnd:(NSTimeInterval)selectionEnd
                            sideReadoutWidth:(CGFloat)sideReadoutWidth
                             contentTopInset:(CGFloat)contentTopInset
                                 usableMovie:(BOOL)usableMovie
                       currentTimecodeString:(NSString *)currentTimecodeString
{
    return SlateRuntimeTimelineSnapshotFromExecutable(bounds,
                                                  duration,
                                                  currentTime,
                                                  frameRate,
                                                  selectionStart,
                                                  selectionEnd,
                                                  sideReadoutWidth,
                                                  contentTopInset,
                                                  usableMovie,
                                                  currentTimecodeString);
}

+ (NSDictionary *)commandResultWithCommand:(NSString *)command
                                    payload:(NSDictionary *)payload
                                     result:(id)result
{
    return [NSDictionary dictionaryWithObjectsAndKeys:
            SlateRuntimeCommandResultSchemaVersion1, SlateRuntimeCommandResultKeySchemaVersion,
            SlateRuntimeStringOrEmpty(command), SlateRuntimeCommandResultKeyCommand,
            SlateRuntimeDictionaryOrEmpty(payload), SlateRuntimeCommandResultKeyPayload,
            [NSNumber numberWithBool:YES], SlateRuntimeCommandResultKeyAccepted,
            (result ?: [NSNull null]), SlateRuntimeCommandResultKeyResult,
            nil];
}

+ (NSDictionary *)commandErrorWithCommand:(NSString *)command
                                  payload:(NSDictionary *)payload
                                     code:(NSString *)code
                                  message:(NSString *)message
{
    NSDictionary *error = [NSDictionary dictionaryWithObjectsAndKeys:
                           SlateRuntimeStringOrEmpty(code), SlateRuntimeCommandErrorKeyCode,
                           SlateRuntimeStringOrEmpty(message), SlateRuntimeCommandErrorKeyMessage,
                           nil];
    return [NSDictionary dictionaryWithObjectsAndKeys:
            SlateRuntimeCommandResultSchemaVersion1, SlateRuntimeCommandResultKeySchemaVersion,
            SlateRuntimeStringOrEmpty(command), SlateRuntimeCommandResultKeyCommand,
            SlateRuntimeDictionaryOrEmpty(payload), SlateRuntimeCommandResultKeyPayload,
            [NSNumber numberWithBool:NO], SlateRuntimeCommandResultKeyAccepted,
            error, SlateRuntimeCommandResultKeyError,
            [NSNull null], SlateRuntimeCommandResultKeyResult,
            nil];
}

+ (NSDictionary *)runtimeAcquisitionStatus
{
    BOOL validationRuntimeAvailable = (SlateRuntimeValidationRuntimeExecutablePath() != nil);
    BOOL packageRuntimeAvailable = (SlateRuntimePackageRuntimeExecutablePath() != nil);
    BOOL trackRuntimeAvailable = (SlateRuntimeTrackRuntimeExecutablePath() != nil);
    BOOL chapterRuntimeAvailable = (SlateRuntimeChapterRuntimeExecutablePath() != nil);
    BOOL reviewRuntimeAvailable = (SlateRuntimeReviewRuntimeExecutablePath() != nil);
    BOOL timelineRuntimeAvailable = (SlateRuntimeTimelineRuntimeExecutablePath() != nil);
    BOOL anyRuntimeAvailable = (validationRuntimeAvailable || packageRuntimeAvailable || trackRuntimeAvailable || chapterRuntimeAvailable || reviewRuntimeAvailable || timelineRuntimeAvailable);
    BOOL allRuntimeAvailable = (validationRuntimeAvailable && packageRuntimeAvailable && trackRuntimeAvailable && chapterRuntimeAvailable && reviewRuntimeAvailable && timelineRuntimeAvailable);
    NSString *message = nil;
    if (allRuntimeAvailable) {
        message = @"Validation, package, track, chapter, review, and timeline runtime artifacts are available.";
    } else if (anyRuntimeAvailable) {
        NSMutableArray *availableNames = [NSMutableArray array];
        if (validationRuntimeAvailable) {
            [availableNames addObject:@"validation"];
        }
        if (packageRuntimeAvailable) {
            [availableNames addObject:@"package"];
        }
        if (trackRuntimeAvailable) {
            [availableNames addObject:@"track"];
        }
        if (chapterRuntimeAvailable) {
            [availableNames addObject:@"chapter"];
        }
        if (reviewRuntimeAvailable) {
            [availableNames addObject:@"review"];
        }
        if (timelineRuntimeAvailable) {
            [availableNames addObject:@"timeline"];
        }
        message = [NSString stringWithFormat:@"%@ runtime artifact%@ available; unavailable runtime-backed surfaces report structured errors.",
                   [[availableNames componentsJoinedByString:@" and "] capitalizedString],
                   ([availableNames count] == 1 ? @" is" : @"s are")];
    } else {
        message = @"Runtime artifacts are missing; runtime-backed surfaces report structured errors.";
    }

    NSArray *installLocations = [NSArray arrayWithObjects:
                                 @"Same directory as Slate.app",
                                 nil];
    NSArray *runtimes = [NSArray arrayWithObjects:
                         SlateRuntimeAcquisitionRuntimeEntryWithStatus(SlateRuntimeNameValidation,
                                                                    @"SlateValidationRuntime",
                                                                    validationRuntimeAvailable ? SlateRuntimeAcquisitionStatusAvailable : SlateRuntimeAcquisitionStatusMissing),
                         SlateRuntimeAcquisitionRuntimeEntryWithStatus(SlateRuntimeNamePackage,
                                                                    @"SlatePackageRuntime",
                                                                    packageRuntimeAvailable ? SlateRuntimeAcquisitionStatusAvailable : SlateRuntimeAcquisitionStatusMissing),
                         SlateRuntimeAcquisitionRuntimeEntryWithStatus(SlateRuntimeNameTrack,
                                                                    @"SlateTrackRuntime",
                                                                    trackRuntimeAvailable ? SlateRuntimeAcquisitionStatusAvailable : SlateRuntimeAcquisitionStatusMissing),
                         SlateRuntimeAcquisitionRuntimeEntryWithStatus(SlateRuntimeNameChapter,
                                                                    @"SlateChapterRuntime",
                                                                    chapterRuntimeAvailable ? SlateRuntimeAcquisitionStatusAvailable : SlateRuntimeAcquisitionStatusMissing),
                         SlateRuntimeAcquisitionRuntimeEntryWithStatus(SlateRuntimeNameReview,
                                                                    @"SlateReviewRuntime",
                                                                    reviewRuntimeAvailable ? SlateRuntimeAcquisitionStatusAvailable : SlateRuntimeAcquisitionStatusMissing),
                         SlateRuntimeAcquisitionRuntimeEntryWithStatus(SlateRuntimeNameTimeline,
                                                                    @"SlateTimelineRuntime",
                                                                    timelineRuntimeAvailable ? SlateRuntimeAcquisitionStatusAvailable : SlateRuntimeAcquisitionStatusMissing),
                         nil];

    return [NSDictionary dictionaryWithObjectsAndKeys:
            SlateRuntimeAcquisitionSchemaVersion1, SlateRuntimeAcquisitionKeySchemaVersion,
            [NSNumber numberWithBool:allRuntimeAvailable], SlateRuntimeAcquisitionKeyOK,
            allRuntimeAvailable ? SlateRuntimeAcquisitionModeExternal : (anyRuntimeAvailable ? SlateRuntimeAcquisitionModeHybrid : SlateRuntimeAcquisitionModeInProcess), SlateRuntimeAcquisitionKeyMode,
            message, SlateRuntimeAcquisitionKeyMessage,
            installLocations, SlateRuntimeAcquisitionKeyInstallLocations,
            runtimes, SlateRuntimeAcquisitionKeyRuntimes,
            @"Install signed Slate runtime artifacts that match the runtime manifest before enabling external runtime mode.", SlateRuntimeAcquisitionKeyDownloadHint,
            nil];
}

@end
