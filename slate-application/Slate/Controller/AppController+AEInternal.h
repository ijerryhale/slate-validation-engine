//
//  AppController+AEInternal.h
//  Slate
//
//  Created by Jerry Hale on 5/6/26.
//  Copyright (c) 2026 Jerry Hale. All rights reserved.
//
//  Proprietary and confidential.
//  This file is part of Slate and is not open source software.
//
//  No license is granted to copy, modify, distribute, sublicense, or use this
//  source code except under a written agreement with the copyright holder.
//  Unauthorized use, disclosure, reproduction, or distribution is prohibited.
//

#import "AppController+AE.h"

#import "AppController+Private.h"
#import "ChapterViewController.h"
#import "DictionaryKeys.h"
#import "PackageViewController.h"
#import "TimelineState.h"
#import "TimelineView.h"
#import "TrackViewController.h"
#import "UtilAECodec.h"

enum
{
    kSlateAppleEventClass = 'SLAT',
    kSlateAppleEventPing = 'PING',
    kSlateAppleEventHelp = 'HELP',
    kSlateAppleEventGetWindowBounds = 'GWND',
    kSlateAppleEventSetWindowBounds = 'SWND',
    kSlateAppleEventGetMode = 'GMOD',
    kSlateAppleEventSetMode = 'SMOD',
    kSlateAppleEventGetWorkspaceWidth = 'GWWD',
    kSlateAppleEventGetWorkspaceClass = 'GWCL',
    kSlateAppleEventGetPlaybackSeconds = 'GSEC',
    kSlateAppleEventSetPlaybackSeconds = 'SSEC',
    kSlateAppleEventGetPlaybackRate = 'GRAT',
    kSlateAppleEventTogglePlayback = 'TPLY',
    kSlateAppleEventOpenPath = 'FPTH',
    kSlateAppleEventTrackMovieDetails = 'TDET',
    kSlateAppleEventChapterDetails = 'CDET',
    kSlateAppleEventReadinessReport = 'RRPT',
    kSlateAppleEventReadinessSummary = 'RSUM',
    kSlateAppleEventSnapshot = 'SNAP'
};

typedef void (*SMAppleEventHandlerIMP)(id, SEL, NSAppleEventDescriptor *, NSAppleEventDescriptor *);

@interface AppController (SMAppleEventsPrivate)
- (void)applyModeWorkspaceResponsiveLayout;
- (CGFloat)currentWorkspaceResponsiveWidth;
- (void)fastBackward:(id)sender;
- (void)stepBackward:(id)sender;
- (void)stepForward:(id)sender;
- (void)fastForward:(id)sender;
- (void)layoutScrubberTimeLabels;
- (void)refreshCropValues:(id)sender;
- (void)selectBottomPane:(id)sender;
- (void)toggleCropRect:(id)sender;
- (void)updateCurrentSize;
- (void)togglePlayPause:(id)sender;

- (double)movieCurrentTime;
- (void)setMovieCurrentTime:(double)time;

- (void)rebuildTransportTimelineKeyViewLoop;
- (NSArray *)transportTimelineFocusOrderViews;
- (NSView *)transportContainerView;
- (NSButton *)transportButtonForAction:(SEL)action;

- (TrackViewController *)ensureTrackViewControllerLoaded;
- (PackageViewController *)ensurePackageViewControllerLoaded;
- (ChapterViewController *)ensureChapterViewControllerLoaded;

- (void)handleSlateAppleEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent;
- (void)dispatchAppleEventWithID:(AEEventID)eventID
                 directDescriptor:(NSAppleEventDescriptor *)directDescriptor
                       replyEvent:(NSAppleEventDescriptor *)replyEvent;
- (SEL)handlerSelectorForAppleEventID:(AEEventID)eventID;

- (void)installAutomationExtensionAppleEventHandlersWithManager:(NSAppleEventManager *)manager
                                                       selector:(SEL)selector;
- (void)removeAutomationExtensionAppleEventHandlersWithManager:(NSAppleEventManager *)manager;
- (SEL)automationExtensionHandlerSelectorForAppleEventID:(AEEventID)eventID;
- (NSString *)automationExtensionAppleEventHelpText;
- (NSAppleEventDescriptor *)automationExtensionSnapshotDescriptorForDescriptor:(NSAppleEventDescriptor *)descriptor;

- (NSString *)automationAppleEventHelpText;
- (void)populateOperatorReplyEvent:(NSAppleEventDescriptor *)replyEvent
                            eventID:(AEEventID)eventID
                        resultObject:(id)resultObject;
- (void)populateOperatorErrorReplyEvent:(NSAppleEventDescriptor *)replyEvent
                                 eventID:(AEEventID)eventID
                             errorNumber:(SInt32)errorNumber
                                    code:(NSString *)code
                                 message:(NSString *)message;

- (NSAppleEventDescriptor *)automationWindowBoundsDescriptor;
- (NSDictionary *)automationTrackMovieDetailsPayload;
- (NSDictionary *)automationChapterDetailsPayload;
- (NSDictionary *)automationReadinessReportPayload;
- (NSDictionary *)automationReadinessSummaryPayload;

- (void)handleAppleEventPingWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                replyEvent:(NSAppleEventDescriptor *)replyEvent;
- (void)handleAppleEventHelpWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                replyEvent:(NSAppleEventDescriptor *)replyEvent;
- (void)handleAppleEventGetWindowBoundsWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                            replyEvent:(NSAppleEventDescriptor *)replyEvent;
- (void)handleAppleEventSetWindowBoundsWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                            replyEvent:(NSAppleEventDescriptor *)replyEvent;
- (void)handleAppleEventGetModeWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                    replyEvent:(NSAppleEventDescriptor *)replyEvent;
- (void)handleAppleEventSetModeWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                    replyEvent:(NSAppleEventDescriptor *)replyEvent;
- (void)handleAppleEventGetWorkspaceWidthWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                              replyEvent:(NSAppleEventDescriptor *)replyEvent;
- (void)handleAppleEventGetWorkspaceClassWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                              replyEvent:(NSAppleEventDescriptor *)replyEvent;
- (void)handleAppleEventGetPlaybackSecondsWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                               replyEvent:(NSAppleEventDescriptor *)replyEvent;
- (void)handleAppleEventSetPlaybackSecondsWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                               replyEvent:(NSAppleEventDescriptor *)replyEvent;
- (void)handleAppleEventGetPlaybackRateWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                            replyEvent:(NSAppleEventDescriptor *)replyEvent;
- (void)handleAppleEventTogglePlaybackWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                           replyEvent:(NSAppleEventDescriptor *)replyEvent;
- (void)handleAppleEventOpenPathWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                    replyEvent:(NSAppleEventDescriptor *)replyEvent;
- (void)handleAppleEventTrackMovieDetailsWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                             replyEvent:(NSAppleEventDescriptor *)replyEvent;
- (void)handleAppleEventChapterDetailsWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                          replyEvent:(NSAppleEventDescriptor *)replyEvent;
- (void)handleAppleEventReadinessReportWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                           replyEvent:(NSAppleEventDescriptor *)replyEvent;
- (void)handleAppleEventReadinessSummaryWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                            replyEvent:(NSAppleEventDescriptor *)replyEvent;
- (void)handleAppleEventSnapshotWithDescriptor:(NSAppleEventDescriptor *)directDescriptor
                                    replyEvent:(NSAppleEventDescriptor *)replyEvent;
@end
