//
//  QuadrantView.h
//  Slate
//
//  Created by Jerry Hale on 3/19/26.
//  Copyright (c) 2026 Jerry Hale. All rights reserved.
//
//  Proprietary and confidential.
//  This file is part of Slate and is not open source software.
//
//  No license is granted to copy, modify, distribute, sublicense, or use this
//  source code except under a written agreement with the copyright holder.
//  Unauthorized use, disclosure, reproduction, or distribution is prohibited.
//

extern NSString *kKeyLastClicked;
extern NSString *kKeyScaleFactor;


@interface QuadrantView : NSView
{
    int                     _lastClickedImg;
    NSColor                 *_backgroundColor;
    BOOL                    _disabledAppearanceEnabled;
    
    IBOutlet NSImageView    *_quad0;
    IBOutlet NSImageView    *_quad1;
    IBOutlet NSImageView    *_quad2;
    IBOutlet NSImageView    *_quad3;
    NSView                  *_disabledMaskView;
    
    IBOutlet  NSPopUpButton *_zoomPopUpButton;
}

@property int  lastClickedImg;
@property (nonatomic, retain) NSColor  *backgroundColor;
@property (nonatomic, assign) BOOL disabledAppearanceEnabled;

-(void)setImage:(NSImage *)image;
@end
