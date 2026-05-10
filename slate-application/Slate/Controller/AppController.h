//
//  AppController.h
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

extern NSString    *BASE_URL;

enum	// popup tag choices
{
	cntrl_chap = 0,
    cntrl_trak = 1,
    cntrl_pdata = 2
};

@class PlayerView;
@class TrackViewController;
@class PackageViewController;
@class ChapterViewController;
@class TimelineState;
@class TimelineView;
@class UtilInspectorRailCoord;

@interface AppController : NSObject <NSApplicationDelegate, NSMenuItemValidation, NSMenuDelegate>
{
    BOOL                            _hasMovie,
                                    _movieIsDirty,
                                    _updatingTimelineFromPlayback,
                                    _subtitleVisible,
                                    _closedCaptionVisible,
                                    _timecodeOverlayVisible,
                                    _statusMessagePinned;

    double                          _movieFrameRate;
    float                           _playbackRateBeforeScrub;
    SMMovie                         *_movie;
    SMMovie                         *_autoloadedSidecarMovie;
    NSString                        *_packagePath;
    NSDictionary                    *_packageContext;

    NSRect                          _frameForNonFullScreenMode;
    AVAssetExportSession            *_trailerExportSession;
    NSTask                          *_trailerExportTask;

    //  for scrubber
    NSTimeInterval                  _currentTime;
    NSTimer                         *_timelineTimer,
                                    *_scrubSeekTimer,
                                    *_trailerExportProgressTimer;
    NSTimeInterval                  _pendingScrubTime;
    BOOL                            _hasPendingScrubSeek;
    TimelineState                   *_timelineState;
    NSMutableDictionary             *_modeSwitchContextByTag;
    UtilInspectorRailCoord          *_inspectorRailHostCoordinator;

    NSInteger                       _currentTag;
    
	IBOutlet NSWindow               *_window;
    IBOutlet PlayerView             *_playerView;
    IBOutlet NSView                *_topView;
     IBOutlet NSView                *_bottomView;

    PackageViewController          *_packageViewController;
    TrackViewController            *_trackViewController;
    ChapterViewController           *_chapterViewController;

    IBOutlet NSProgressIndicator    *_progressIndicator;
    IBOutlet NSTextField            *_status;
    IBOutlet TimelineView      *_timelineView;
    CGFloat                         _timelineBaseY;
    IBOutlet NSSlider               *_volume;
    
    IBOutlet NSTextField            *_format;
    IBOutlet NSTextField            *_frameRate;
    IBOutlet NSTextField            *_currentSize;
 
    //  don't delete, used to edit crop rect values
    //   BOOL                               _valueHasChanged;
    //    NSString                        *_initEditString;
    IBOutlet NSTextField            *_rawCropLeft;
    IBOutlet NSTextField            *_rawCropTop;
    IBOutlet NSTextField            *_rawCropRght;
    IBOutlet NSTextField            *_rawCropBtm;

    IBOutlet NSColorWell            *_colorWell;
    IBOutlet NSButton               *_timecodeOverlayButton;
    IBOutlet NSMatrix               *_views;
}

@property double                            movieFrameRate;
@property (assign) SMMovie                  *movie;
@property BOOL                              hasMovie;
@property BOOL                              movieIsDirty;
@property NSTimeInterval                    movieCurrentTime;

@property (assign) PlayerView               *playerView;
@property (assign) NSView                   *topView;
@property (assign) NSView                   *bottomView;
@property (retain) TimelineState                *timelineState;


@property (assign) NSTextField				*rawCropLeft;
@property (assign) NSTextField				*rawCropTop;
@property (assign) NSTextField				*rawCropRght;
@property (assign) NSTextField				*rawCropBtm;

@property (assign) PackageViewController *packageViewController;
@property (assign) TrackViewController   *trackViewController;
@property (assign) ChapterViewController *chapterViewController;

+(id)infoValueForKey:(NSString *)key;

-(NSSize)naturalSize;
-(NSString *)codec:(SMMedia *)trackMedia;

-(void)updateCurrentSize;
- (void)windowDidResize:(NSNotification *)notification;
- (IBAction)setBackgroundColor:(id)sender;

- (IBAction)toggleTimecodeOverlay:(id)sender;
- (IBAction)togglePlayPause:(id)sender;

-(BOOL)movieIsDirty;
-(void)setMovieIsDirty:(BOOL)value;
-(BOOL)subtitleVisible;
-(BOOL)closedCaptionVisible;
- (BOOL)timecodeOverlayVisible;
- (BOOL)movieHasTimecodeTrack;
- (IBAction)addReferenceTrack:(id)sender;
- (IBAction)deleteTrack:(id)sender;
-(IBAction)doOpen:(id)sender;
- (IBAction)openRecentOperatorInput:(id)sender;
- (IBAction)clearRecentOperatorInputs:(id)sender;

-(BOOL)application:(NSApplication *)sender openFile:(NSString *)filename;

@end

AppController *appcontroller(void);
