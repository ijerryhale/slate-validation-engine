//
//  AppController+Status.m
//  Slate
//

#import "AppController+Status.h"

static NSTimeInterval const SMStatusMessageFadeDurationSeconds = 8.0;
static NSString * const SMStatusTrackPaneNoMovie = @"Open a movie to inspect tracks, roles, and readiness.";
static NSString * const SMStatusChapterPaneNoPackage = @"Open a package to inspect manifest values, chapter rows, and readiness.";
static NSString * const SMStatusPackagePaneNoPackage = @"Open a package to inspect manifest values, assets, and readiness.";

static NSString *SMStatusTrimmedString(NSString *value)
{
    if (![value isKindOfClass:[NSString class]]) {
        return @"";
    }

    return [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

@interface AppController (StatusPrivate)
- (NSString *)statusGuidanceMessageForBottomPaneTag:(NSInteger)tag;
@end

@implementation AppController (Status)

- (NSString *)statusGuidanceMessageForBottomPaneTag:(NSInteger)tag
{
    if (tag == cntrl_trak) {
        return _hasMovie ? nil : SMStatusTrackPaneNoMovie;
    }

    if (tag == cntrl_chap) {
        return (_packageContext != nil) ? nil : SMStatusChapterPaneNoPackage;
    }

    if (tag == cntrl_pdata) {
        return (_packageContext != nil) ? nil : SMStatusPackagePaneNoPackage;
    }

    return nil;
}

- (void)showStatusMessage:(NSString *)message persist:(BOOL)persist
{
    if (![_status isKindOfClass:[NSTextField class]]) {
        return;
    }

    NSString *normalized = SMStatusTrimmedString(message);

    if ([normalized length] == 0) {
        [_status setStringValue:@""];
        [_status setAlphaValue:0.0];
        _statusMessagePinned = NO;
        return;
    }

    [_status setAlphaValue:1.0];
    [_status setStringValue:normalized];
    _statusMessagePinned = persist;

    if (persist) {
        return;
    }

    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:SMStatusMessageFadeDurationSeconds];
    [[_status animator] setAlphaValue:0.0];
    [NSAnimationContext endGrouping];
}

- (void)showChapterCropRectStatusWithTop:(CGFloat)top
                                    left:(CGFloat)left
                                  bottom:(CGFloat)bottom
                                   right:(CGFloat)right
                                 context:(NSString *)context
                                  suffix:(NSString *)suffix
                                 persist:(BOOL)persist
{
    NSString *normalizedContext = SMStatusTrimmedString(context);
    NSString *normalizedSuffix = SMStatusTrimmedString(suffix);
    NSString *message = nil;

    NSString *label = ([normalizedContext length] > 0) ? normalizedContext : @"Chapter crop rect";
    message = [NSString stringWithFormat:@"%@ TL{%.0f %.0f} BR{%.0f %.0f}",
                                         label,
                                         top,
                                         left,
                                         bottom,
                                         right];

    if ([normalizedSuffix length] > 0) {
        message = [message stringByAppendingFormat:@" %@", normalizedSuffix];
    }

    [self showStatusMessage:message persist:persist];
}

- (void)refreshBottomPaneStatusGuidance
{
    NSString *guidance = [self statusGuidanceMessageForBottomPaneTag:_currentTag];
    if ([guidance length] > 0) {
        [self showStatusMessage:guidance persist:YES];
        return;
    }

    if (_statusMessagePinned) {
        [self showStatusMessage:[_status stringValue] persist:NO];
    }
}

@end
