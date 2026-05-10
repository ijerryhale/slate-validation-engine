//
//  AppController+Packages.m
//  Slate
//

#import "AppController+Package.h"
#import "AppController+Status.h"
#import "AppController+Crop.h"
#import "AppController+Validation.h"
#import <sys/stat.h>

#import "QuadrantView.h"
#import "ChapterViewController.h"
#import "TrackViewController.h"
#import "PackageViewController.h"
#import "Runtime/SlatePackageContextContract.h"
#import "Runtime/SlateRuntimeBridge.h"
#import "Validation/SMValidationCanonicalDictionaryKeys.h"

static BOOL SMPackageStringHasContent(NSString *value)
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

static NSString *SMPackageStringValue(id value)
{
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

static BOOL SlatePackageContextHasPackage(NSDictionary *context)
{
    return ([[context objectForKey:SlatePackageContextKeySchemaVersion] isEqualToString:SlatePackageContextSchemaVersion1]
            && [[context objectForKey:SlatePackageContextKeyHasPackage] boolValue]);
}

static NSDictionary *SlatePackageContextPackageSnapshot(NSDictionary *context)
{
    return SMPackageDictionaryValue([context objectForKey:SlatePackageContextKeyPackageSnapshot]);
}

static NSDictionary *SlatePackageContextSummary(NSDictionary *context)
{
    return SMPackageDictionaryValue([context objectForKey:SlatePackageContextKeySummary]);
}

static NSDictionary *SlatePackageContextPrimaryAsset(NSDictionary *context)
{
    return SMPackageDictionaryValue([context objectForKey:SlatePackageContextKeyPrimaryAsset]);
}

static NSDictionary *SlatePackageContextError(NSDictionary *context)
{
    return SMPackageDictionaryValue([context objectForKey:SlatePackageContextKeyError]);
}

static NSString *SMCanonicalLocalPath(NSString *path)
{
    if (!SMPackageStringHasContent(path)) {
        return nil;
    }

    NSString *standardizedPath = [path stringByStandardizingPath];
    if (!SMPackageStringHasContent(standardizedPath)) {
        return nil;
    }

    NSURL *resolvedURL = [[NSURL fileURLWithPath:standardizedPath] URLByResolvingSymlinksInPath];
    NSString *resolvedPath = [resolvedURL path];
    if (SMPackageStringHasContent(resolvedPath)) {
        return [resolvedPath stringByStandardizingPath];
    }

    return standardizedPath;
}

static BOOL SMLocalPathsReferenceSameFilesystemItem(NSString *leftPath, NSString *rightPath)
{
    if (!SMPackageStringHasContent(leftPath) || !SMPackageStringHasContent(rightPath)) {
        return NO;
    }

    struct stat leftStat;
    struct stat rightStat;
    if (lstat([leftPath fileSystemRepresentation], &leftStat) != 0) {
        return NO;
    }
    if (lstat([rightPath fileSystemRepresentation], &rightStat) != 0) {
        return NO;
    }

    return (leftStat.st_dev == rightStat.st_dev && leftStat.st_ino == rightStat.st_ino);
}

static BOOL SMDeclaredPathLooksLikeVideoAsset(NSString *path)
{
    NSString *extension = [[path pathExtension] lowercaseString];
    if (!SMPackageStringHasContent(extension)) {
        return NO;
    }

    static NSSet *videoExtensions = nil;
    if (videoExtensions == nil) {
        videoExtensions = [[NSSet alloc] initWithObjects:@"mov", @"mp4", @"m4v", @"mxf", nil];
    }

    return [videoExtensions containsObject:extension];
}

static const CGFloat SMPackageReportDialogBodyWidth = 620.0;
static const CGFloat SMPackageReportDialogMinimumBodyHeight = 140.0;
static const CGFloat SMPackageReportDialogMaximumBodyHeight = 440.0;
static const CGFloat SMPackageReportDialogTextInset = 8.0;

@interface SMPackageReportDialogTextView : NSTextView
@end

@implementation SMPackageReportDialogTextView

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

static CGFloat SMPackageReportDialogBodyHeightForText(NSString *text)
{
    NSString *body = (text ?: @"");
    NSFont *font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
    NSDictionary *attributes = [NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName];
    CGFloat textWidth = SMPackageReportDialogBodyWidth - (SMPackageReportDialogTextInset * 2.0);
    NSRect bounds = [body boundingRectWithSize:NSMakeSize(textWidth, CGFLOAT_MAX)
                                       options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading)
                                    attributes:attributes];
    CGFloat height = ceil(NSHeight(bounds)) + (SMPackageReportDialogTextInset * 2.0);
    height = MAX(SMPackageReportDialogMinimumBodyHeight, height);
    return MIN(SMPackageReportDialogMaximumBodyHeight, height);
}

static NSView *SMPackageReportDialogBodyView(NSString *text)
{
    CGFloat bodyHeight = SMPackageReportDialogBodyHeightForText(text);
    NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(0.0,
                                                                                0.0,
                                                                                SMPackageReportDialogBodyWidth,
                                                                                bodyHeight)] autorelease];
    [scrollView setBorderType:NSBezelBorder];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setAutohidesScrollers:YES];

    NSTextView *textView = [[[SMPackageReportDialogTextView alloc] initWithFrame:NSMakeRect(0.0,
                                                                                            0.0,
                                                                                            SMPackageReportDialogBodyWidth,
                                                                                            bodyHeight)] autorelease];
    [textView setEditable:NO];
    [textView setSelectable:YES];
    [textView setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
    [textView setString:(text ?: @"")];
    [textView setHorizontallyResizable:NO];
    [textView setVerticallyResizable:YES];
    [textView setAutoresizingMask:NSViewWidthSizable];
    [[textView textContainer] setWidthTracksTextView:YES];
    [[textView textContainer] setContainerSize:NSMakeSize(SMPackageReportDialogBodyWidth - (SMPackageReportDialogTextInset * 2.0),
                                                          CGFLOAT_MAX)];

    [scrollView setDocumentView:textView];
    return scrollView;
}

static NSUInteger SMPackageValidationSummaryCount(NSDictionary *report, NSString *key)
{
    NSDictionary *summary = [report objectForKey:SMValidationReportKeySummary];
    NSNumber *count = [summary isKindOfClass:[NSDictionary class]] ? [summary objectForKey:key] : nil;
    return [count isKindOfClass:[NSNumber class]] ? [count unsignedIntegerValue] : 0;
}

static NSString *SMPackageValidationAlertTitle(NSDictionary *report)
{
    NSUInteger blockerCount = SMPackageValidationSummaryCount(report, SMValidationSummaryKeyBlockers);
    NSUInteger warningCount = SMPackageValidationSummaryCount(report, SMValidationSummaryKeyWarnings);

    if (blockerCount > 0) {
        return [NSString stringWithFormat:@"Readiness: %lu blocker%@", (unsigned long)blockerCount, blockerCount == 1 ? @"" : @"s"];
    }
    if (warningCount > 0) {
        return [NSString stringWithFormat:@"Readiness: %lu warning%@", (unsigned long)warningCount, warningCount == 1 ? @"" : @"s"];
    }
    return @"Readiness: Pass";
}

static NSString *SMPackageValidationOperatorText(NSDictionary *report)
{
    NSString *operatorText = [report objectForKey:SMValidationReportKeyOperatorText];
    return [operatorText isKindOfClass:[NSString class]] ? operatorText : @"";
}

static NSURL *SMPackageURLFromOpenPanel(AppController *self)
{
    #pragma unused(self)
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setAllowedFileTypes:[NSArray arrayWithObjects:@"json", @"xml", nil]];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setAllowsMultipleSelection:NO];

    NSInteger result = [openPanel runModal];
    if (result != NSOKButton) {
        return nil;
    }

    NSURL *url = [[openPanel URLs] firstObject];
    if (url == nil) {
        return nil;
    }

    return url;
}

@implementation AppController (Packages)

- (NSString *)currentPackagePath
{
    return _packagePath;
}

- (IBAction)openPackageInput:(id)sender
{
    #pragma unused(sender)
    NSURL *url = SMPackageURLFromOpenPanel(self);
    if (url == nil) {
        return;
    }

    [self openPackageContextFromURL:url presentErrors:YES];
}

- (IBAction)showPackageSummary:(id)sender
{
    #pragma unused(sender)
    if (_packageContext == nil) {
        [self presentPackageOpenErrorWithTitle:@"No Package"
                               informativeText:@"Open a package JSON or Apple manifest file first to inspect its declared package structure."];
        return;
    }

    [self presentPackageContext:_packageContext];
}

- (void)closePackageContextResettingUIState
{
    [_packageContext release];
    _packageContext = nil;
    [_packagePath release];
    _packagePath = nil;

    [_trackViewController assetTypeFromPackageContext:nil];
    [_chapterViewController applyChapterSnapshot:[SlateRuntimeBridge chapterSnapshotForPackagePath:nil
                                                                                             movie:nil
                                                                                        hasPackage:NO]];
    [_packageViewController clearPackagePresentation];
    [_packageViewController.view setNeedsDisplay:YES];
    [self refreshValidationViewAdapters];
    [self refreshBottomPaneStatusGuidance];
}

- (BOOL)openPackageContextFromURL:(NSURL *)url presentErrors:(BOOL)presentErrors
{
    if (url == nil) {
        if (presentErrors) {
            [self presentPackageOpenErrorWithTitle:@"Open Package Failed"
                                   informativeText:@"No package URL was provided."];
        }
        return NO;
    }

    NSString *packagePath = [url path];
    if (!SMPackageStringHasContent(packagePath)) {
        if (presentErrors) {
            [self presentPackageOpenErrorWithTitle:@"Open Package Failed"
                                   informativeText:@"No package file path was provided."];
        }
        return NO;
    }

    if (![self pathLooksLikePackageInput:packagePath]) {
        if (presentErrors) {
            [self presentPackageOpenErrorWithTitle:@"Open Package Failed"
                                   informativeText:@"Only package JSON and Apple manifest XML files are supported here."];
        }
        return NO;
    }

    NSDictionary *packageContext = [SlateRuntimeBridge packageContextForPackagePath:packagePath];
    if (!SlatePackageContextHasPackage(packageContext)) {
        if (presentErrors) {
            NSString *message = [SlatePackageContextError(packageContext) objectForKey:SlatePackageContextErrorKeyMessage];
            [self presentPackageOpenErrorWithTitle:@"Open Package Failed"
                                   informativeText:(SMPackageStringHasContent(message) ? message : @"The selected package could not be parsed by SlatePackageRuntime.")];
        }
        return NO;
    }

    [_packageContext release];
    _packageContext = [packageContext retain];
    [_packagePath release];
    _packagePath = [packagePath copy];

    [self refreshPackageAdaptersFromCurrentContext];
    [self refreshValidationViewAdapters];
    [self refreshBottomPaneStatusGuidance];
    [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:url];

    return YES;
}

- (void)refreshPackageAdaptersFromCurrentContext
{
    if (!SlatePackageContextHasPackage(_packageContext)) {
        [_trackViewController assetTypeFromPackageContext:nil];
        [_chapterViewController applyChapterSnapshot:[SlateRuntimeBridge chapterSnapshotForPackagePath:nil
                                                                                                 movie:nil
                                                                                            hasPackage:NO]];
        [_packageViewController clearPackagePresentation];
        return;
    }

    [_trackViewController assetTypeFromPackageContext:_packageContext];
    NSDictionary *chapterSnapshot = [SlateRuntimeBridge chapterSnapshotForPackagePath:_packagePath
                                                                             movie:_movie
                                                                        hasPackage:YES];
    [_chapterViewController applyChapterSnapshot:chapterSnapshot];
    [self restoreCropOverlayFromPackageContextIfPossible:_packageContext];
    [_packageViewController presentPackageSnapshot:SlatePackageContextPackageSnapshot(_packageContext)];
    [_packageViewController.view setNeedsDisplay:YES];
}

- (void)presentPackageContext:(NSDictionary *)packageContext
{
    if (!SlatePackageContextHasPackage(packageContext)) {
        return;
    }

    NSDictionary *summary = SlatePackageContextSummary(packageContext);
    NSMutableString *details = [NSMutableString stringWithString:SMPackageStringValue([summary objectForKey:SlatePackageContextSummaryKeyDetails])];
    NSDictionary *validationReport = [self currentValidationReport];
    if (validationReport != nil) {
        [details appendString:@"\n\nReadiness Report:"];
        [details appendFormat:@"\n%@", SMPackageValidationAlertTitle(validationReport)];
        NSString *alertDetails = SMPackageValidationOperatorText(validationReport);
        if (SMPackageStringHasContent(alertDetails)) {
            [details appendFormat:@"\n%@", alertDetails];
        }
    }

    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:SMPackageStringValue([summary objectForKey:SlatePackageContextSummaryKeyTitle])];
    [alert setAccessoryView:SMPackageReportDialogBodyView(details)];
    [alert setAlertStyle:NSInformationalAlertStyle];
    [alert beginSheetModalForWindow:_window modalDelegate:self didEndSelector:nil contextInfo:nil];
}

- (void)presentPackageOpenErrorWithTitle:(NSString *)title informativeText:(NSString *)informativeText
{
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:title];
    [alert setInformativeText:informativeText ?: @""];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert beginSheetModalForWindow:_window modalDelegate:self didEndSelector:nil contextInfo:nil];
}

- (BOOL)shouldRetainPackageContextWhenOpeningMoviePath:(NSString *)moviePath
{
    if (!SlatePackageContextHasPackage(_packageContext) || !SMPackageStringHasContent(moviePath)) {
        return NO;
    }

    NSDictionary *primaryAsset = SlatePackageContextPrimaryAsset(_packageContext);
    NSString *mediaType = [[SMPackageStringValue([primaryAsset objectForKey:SlatePackageContextPrimaryAssetKeyMediaType]) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    BOOL declaresVideoAsset = [mediaType isEqualToString:@"video"];
    if (!declaresVideoAsset) {
        declaresVideoAsset = SMDeclaredPathLooksLikeVideoAsset([primaryAsset objectForKey:SlatePackageContextPrimaryAssetKeyDeclaredPath]);
    }

    if (!declaresVideoAsset) {
        return NO;
    }

    NSString *declaredPrimaryPath = SMCanonicalLocalPath([primaryAsset objectForKey:SlatePackageContextPrimaryAssetKeyResolvedPath]);
    NSString *openedMoviePath = SMCanonicalLocalPath(moviePath);
    if (!SMPackageStringHasContent(declaredPrimaryPath) || !SMPackageStringHasContent(openedMoviePath)) {
        return NO;
    }

    if ([declaredPrimaryPath isEqualToString:openedMoviePath]) {
        return YES;
    }

    if ([declaredPrimaryPath caseInsensitiveCompare:openedMoviePath] == NSOrderedSame) {
        return YES;
    }

    return SMLocalPathsReferenceSameFilesystemItem(declaredPrimaryPath, openedMoviePath);
}

- (BOOL)pathLooksLikePackageInput:(NSString *)path
{
    NSString *extension = [[path pathExtension] lowercaseString];
    return [extension isEqualToString:@"json"] || [extension isEqualToString:@"xml"];
}

@end
