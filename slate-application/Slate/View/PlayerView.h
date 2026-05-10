//
//  PlayerView.h
//  Slate
//
//  Created by Jerry Hale on 3/20/26.
//  Copyright (c) 2026 Jerry Hale. All rights reserved.
//
//  Proprietary and confidential.
//  This file is part of Slate and is not open source software.
//
//  No license is granted to copy, modify, distribute, sublicense, or use this
//  source code except under a written agreement with the copyright holder.
//  Unauthorized use, disclosure, reproduction, or distribution is prohibited.
//

#import <AVKit/AVKit.h>
#import <QuartzCore/QuartzCore.h>
#import "MediaSupport/SMCropGeometry.h"

@interface PlayerView : AVPlayerView <CALayerDelegate>
{
    double              _scaleFactor;
    NSTrackingArea      *_trackingArea;
    SMMovie             *_movie;
    AVPlayerItem        *_observedPlayerItem;
    CALayer             *_backgroundLayer;
    NSView              *_subtitleOverlayView;
    NSTextField         *_subtitleLabel;
    NSView              *_timecodeOverlayView;
    NSTextField         *_timecodeLabel;
    NSView              *_messageOverlayView;
    NSTextField         *_messageLabel;
    NSView              *_disabledOverlayView;
    NSTimer             *_unsupportedStateTimer;
    NSTimer             *_shuttleTimer;
    float               _shuttleRate;

    CGRect              _cropRect;
    CAShapeLayer        *_cropLayer;
	
    IBOutlet NSButton   *_playButton;
     
    NSPoint             _lastDragLocation;
    NSPoint             _cropDragStartPoint;
    CGRect              _cropDragInitialRect;
    NSInteger           _activeResizeHandleIndex;
    BOOL                _isDraggingCropRect;
    BOOL                _isResizingCropRect;
    
    NSCursor            *_cursEastWest,
                        *_cursNorthEastSouthWest,
                        *_cursNorthSouth,
                        *_cursNorthWestSouthEast;
    IBOutlet NSButton   *_crop;
}

@property CGRect                cropRect;
@property (retain) SMMovie      *movie;

@property (assign) CAShapeLayer *cropLayer;
@property (assign) NSButton     *crop;

-(IBAction)toggleCropRect:(id)sender;
-(void)createCropRect;
-(void)deleteCropRect;

-(SMCropMargins)sourceCropMarginsFromOverlay;
-(CGRect)sourceCropRectFromOverlay;
-(NSRect)movieBounds;
-(void)setPlayerLayerBackgroundColor:(NSColor *)color;
-(void)refreshSubtitleOverlay;
- (void)showMessage:(NSString *)message;
- (void)clearMessage;

- (void)stopMovie;

-(IBAction)setVolume:(id)sender;
-(IBAction)togglePlayPause:(id)sender;
-(IBAction)stepForward:(id)sender;
-(IBAction)stepBackward:(id)sender;
-(IBAction)fastForward:(id)sender;
-(IBAction)fastBackward:(id)sender;

@end
