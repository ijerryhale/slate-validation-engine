//
//  QuadrentView.m
//  Slate
//
//  Created by Jerry Hale on 3/20/26
//  Copyright (c) 2026 Jerry Hale All rights reserved.

#import "DictionaryKeys.h"

#import "AppController.h"

#import "QuadrantView.h"

NSString *kKeyLastClicked = @"LastClicked";
NSString *kKeyScaleFactor = @"ScaleFactor";

@implementation QuadrantView

@synthesize lastClickedImg = _lastClickedImg;
@synthesize backgroundColor = _backgroundColor;
@synthesize disabledAppearanceEnabled = _disabledAppearanceEnabled;

typedef NS_ENUM(NSInteger, SMQuadrantCorner) {
    SMQuadrantCornerTopLeft = 0,
    SMQuadrantCornerTopRight = 1,
    SMQuadrantCornerBottomLeft = 2,
    SMQuadrantCornerBottomRight = 3,
};

static const CGFloat SMQuadrantInterQuadGap = 4.0;
static const CGFloat SMQuadrantDisabledOverlayAlpha = 0.18;
static const CGFloat SMQuadrantDisabledQuadAlpha = 0.42;
static const CGFloat SMQuadrantEnabledQuadAlpha = 1.0;

static NSView *SMQuadrantEnsureDisabledMaskView(QuadrantView *view)
{
    if (view->_disabledMaskView != nil) {
        return view->_disabledMaskView;
    }

    view->_disabledMaskView = [[[NSView alloc] initWithFrame:[view bounds]] autorelease];
    [view->_disabledMaskView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [view->_disabledMaskView setWantsLayer:YES];
    [[view->_disabledMaskView layer] setBackgroundColor:[[NSColor colorWithCalibratedWhite:1.0
                                                                       alpha:SMQuadrantDisabledOverlayAlpha] CGColor]];
    [view->_disabledMaskView setHidden:YES];
    [view addSubview:view->_disabledMaskView positioned:NSWindowAbove relativeTo:nil];
    return view->_disabledMaskView;
}

static NSRect SMQuadrantSourceRect(NSSize sourceSize, NSSize targetSize, SMQuadrantCorner corner)
{
    CGFloat cropWidth = MIN(sourceSize.width, MAX(1.0, floor(targetSize.width)));
    CGFloat cropHeight = MIN(sourceSize.height, MAX(1.0, floor(targetSize.height)));
    CGFloat rightX = MAX(0.0, sourceSize.width - cropWidth);
    CGFloat topY = MAX(0.0, sourceSize.height - cropHeight);

    switch (corner) {
        case SMQuadrantCornerTopLeft:
            return NSMakeRect(0.0, topY, cropWidth, cropHeight);
        case SMQuadrantCornerTopRight:
            return NSMakeRect(rightX, topY, cropWidth, cropHeight);
        case SMQuadrantCornerBottomLeft:
            return NSMakeRect(0.0, 0.0, cropWidth, cropHeight);
        case SMQuadrantCornerBottomRight:
            return NSMakeRect(rightX, 0.0, cropWidth, cropHeight);
    }

    return NSZeroRect;
}

static NSImage *SMQuadrantCornerImage(NSImage *image, NSImageView *imageView, SMQuadrantCorner corner)
{
    if (image == nil || imageView == nil) {
        return nil;
    }

    NSSize sourceSize = [image size];
    if (sourceSize.width <= 0.0 || sourceSize.height <= 0.0) {
        return nil;
    }

    NSSize targetSize = [imageView bounds].size;
    if (targetSize.width <= 0.0 || targetSize.height <= 0.0) {
        targetSize = [imageView frame].size;
    }

    NSRect sourceRect = SMQuadrantSourceRect(sourceSize, targetSize, corner);
    if (sourceRect.size.width <= 0.0 || sourceRect.size.height <= 0.0) {
        return nil;
    }

    NSImage *cropped = [[[NSImage alloc] initWithSize:sourceRect.size] autorelease];
    [cropped lockFocus];
    [image drawInRect:NSMakeRect(0.0, 0.0, sourceRect.size.width, sourceRect.size.height)
             fromRect:sourceRect
            operation:NSCompositeSourceOver
             fraction:1.0];
    [cropped unlockFocus];
    return cropped;
}

- (void)layoutQuadrantImageViews
{
    if (_quad0 == nil || _quad1 == nil || _quad2 == nil || _quad3 == nil) {
        return;
    }

    NSRect bounds = NSIntegralRect([self bounds]);
    CGFloat availableWidth = MAX(0.0, NSWidth(bounds) - SMQuadrantInterQuadGap);
    CGFloat availableHeight = MAX(0.0, NSHeight(bounds) - SMQuadrantInterQuadGap);
    CGFloat quadSide = floor(MIN(availableWidth / 2.0, availableHeight / 2.0));

    if (quadSide <= 0.0) {
        [_quad0 setFrame:NSZeroRect];
        [_quad1 setFrame:NSZeroRect];
        [_quad2 setFrame:NSZeroRect];
        [_quad3 setFrame:NSZeroRect];
        return;
    }

    CGFloat gridWidth = (quadSide * 2.0) + SMQuadrantInterQuadGap;
    CGFloat gridHeight = (quadSide * 2.0) + SMQuadrantInterQuadGap;
    CGFloat originX = floor(NSMinX(bounds) + ((NSWidth(bounds) - gridWidth) / 2.0));
    CGFloat originY = floor(NSMinY(bounds) + ((NSHeight(bounds) - gridHeight) / 2.0));

    NSRect bottomLeft = NSMakeRect(originX, originY, quadSide, quadSide);
    NSRect bottomRight = NSMakeRect(originX + quadSide + SMQuadrantInterQuadGap, originY, quadSide, quadSide);
    NSRect topLeft = NSMakeRect(originX, originY + quadSide + SMQuadrantInterQuadGap, quadSide, quadSide);
    NSRect topRight = NSMakeRect(originX + quadSide + SMQuadrantInterQuadGap, originY + quadSide + SMQuadrantInterQuadGap, quadSide, quadSide);

    [_quad0 setFrame:NSIntegralRect(topLeft)];
    [_quad1 setFrame:NSIntegralRect(topRight)];
    [_quad2 setFrame:NSIntegralRect(bottomLeft)];
    [_quad3 setFrame:NSIntegralRect(bottomRight)];
}

- (void)setBackgroundColor:(NSColor *)backgroundColor
{
    if (_backgroundColor == backgroundColor || [_backgroundColor isEqual:backgroundColor]) {
        return;
    }

    [_backgroundColor release];
    _backgroundColor = [backgroundColor retain];
    if (self.layer == nil) {
        [self setWantsLayer:YES];
    }
    self.layer.backgroundColor = _backgroundColor.CGColor;
    [self setNeedsDisplay:YES];
}

- (void)setDisabledAppearanceEnabled:(BOOL)disabledAppearanceEnabled
{
    if (_disabledAppearanceEnabled == disabledAppearanceEnabled) {
        return;
    }

    _disabledAppearanceEnabled = disabledAppearanceEnabled;
    CGFloat quadAlpha = _disabledAppearanceEnabled ? SMQuadrantDisabledQuadAlpha : SMQuadrantEnabledQuadAlpha;
    [_quad0 setAlphaValue:quadAlpha];
    [_quad1 setAlphaValue:quadAlpha];
    [_quad2 setAlphaValue:quadAlpha];
    [_quad3 setAlphaValue:quadAlpha];
    NSView *maskView = SMQuadrantEnsureDisabledMaskView(self);
    [maskView setFrame:[self bounds]];
    [maskView setHidden:(!_disabledAppearanceEnabled)];
    [self addSubview:maskView positioned:NSWindowAbove relativeTo:nil];
    [self setNeedsDisplay:YES];
}

-(void)setImage:(NSImage *)image
{
    if (image)
    {
        [_quad0 setImage:SMQuadrantCornerImage(image, _quad0, SMQuadrantCornerTopLeft)];
        [_quad1 setImage:SMQuadrantCornerImage(image, _quad1, SMQuadrantCornerTopRight)];
        [_quad2 setImage:SMQuadrantCornerImage(image, _quad2, SMQuadrantCornerBottomLeft)];
        [_quad3 setImage:SMQuadrantCornerImage(image, _quad3, SMQuadrantCornerBottomRight)];
    }
    else
    {
        [_quad0 setImage:nil];
        [_quad1 setImage:nil];
        [_quad2 setImage:nil];
        [_quad3 setImage:nil];
    }
}

-(void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
    if (_lastClickedImg)
    {
        NSRect  frame = [self frame];
        
        switch (_lastClickedImg)
        {
            case 1:
                frame.origin.x = frame.origin.y = 0;
            break;
            case 2:
                frame.origin.x = (frame.size.width / 2) - 2;
                frame.origin.y = 0;
            break;
            case 3:
                frame.origin.x = 0;
                frame.origin.y = (frame.size.height / 2) - 2;
            break;
            case 4:
                frame.origin.x = (frame.size.width / 2) - 2;
                frame.origin.y = (frame.size.height / 2) - 2;
            break;
        }
        
        frame.size.height = (frame.size.height / 2) + 2;
        frame.size.width = (frame.size.width / 2) + 2;

        [[NSColor colorWithDeviceRed:1.0 - [_backgroundColor redComponent]
                                    green:1.0 - [_backgroundColor greenComponent]
                                    blue:1.0 - [_backgroundColor blueComponent]
                                    alpha:1] set];
        NSRectFill(frame);
    }

}


static NSColor *StoredBackgroundColor(NSUserDefaults *defaults)
{
    id value = [defaults objectForKey:LAYER_BACK_COLOR];
    if (![value isKindOfClass:[NSDictionary class]]) return [NSColor blackColor];

    NSData *colorData = [(NSDictionary *)value objectForKey:LAYER_BACK_COLOR];
    if (![colorData isKindOfClass:[NSData class]]) return  [NSColor blackColor];

    id color = [NSKeyedUnarchiver unarchiveObjectWithData:colorData];
    if (![color isKindOfClass:[NSColor class]]) return  [NSColor blackColor];

    return (NSColor *)color;
}

-(void)awakeFromNib
{
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    NSColor *c = StoredBackgroundColor(prefs);

    
    if (c == nil)
    _backgroundColor = [NSColor blackColor];
    else
        self.backgroundColor = c;
    
    [self setWantsLayer:YES];
    self.layer.backgroundColor = _backgroundColor.CGColor;
    _disabledAppearanceEnabled = NO;
    
    [_quad0 setImageScaling:NSImageScaleNone];
   [_quad0 setImageAlignment:NSImageAlignTopLeft];
    
    [_quad1 setImageScaling:NSImageScaleNone];
    [_quad1 setImageAlignment:NSImageAlignTopRight];

    [_quad2 setImageScaling:NSImageScaleNone];
    [_quad2 setImageAlignment:NSImageAlignBottomLeft];
    
    [_quad3 setImageScaling:NSImageScaleNone];
     [_quad3 setImageAlignment:NSImageAlignBottomRight];

    SMQuadrantEnsureDisabledMaskView(self);
    [self setDisabledAppearanceEnabled:YES];
    [self layoutQuadrantImageViews];
}

- (void)setFrameSize:(NSSize)newSize
{
    [super setFrameSize:newSize];
    NSView *maskView = _disabledMaskView;
    if (maskView != nil) {
        [maskView setFrame:[self bounds]];
        [self addSubview:maskView positioned:NSWindowAbove relativeTo:nil];
    }
    [self layoutQuadrantImageViews];
}

- (void)layout
{
    [super layout];
    NSView *maskView = _disabledMaskView;
    if (maskView != nil) {
        [maskView setFrame:[self bounds]];
        [self addSubview:maskView positioned:NSWindowAbove relativeTo:nil];
    }
    [self layoutQuadrantImageViews];
}

- (BOOL) acceptsFirstMouse:(NSEvent *)event
{
    #pragma unused (event)
    return (YES);
}

- (void)mouseDown:(NSEvent *)event
{
#if 0
    // Retained-behavior fence: quadrant click-to-zoom is intentionally disabled for now.
    if (_disabledAppearanceEnabled || ![[self window] makeFirstResponder:self] || _quad0.image == nil)
        return;

    float   midX = NSMidX(self.bounds),
            midY = NSMidY(self.bounds),
            mouseX = [self convertPoint:[event locationInWindow] fromView:nil].x,
            mouseY = [self convertPoint:[event locationInWindow] fromView:nil].y;
    
    _lastClickedImg = 0;

    if (mouseX < midX && mouseY < midY) //  lower left image
        _lastClickedImg = 1;
    else if (mouseX > midX && mouseY < midY) //  lower right image
        _lastClickedImg = 2;
    else if (mouseX < midX && mouseY > midY) //  upper left image
        _lastClickedImg = 3;
    else                                    //  upper right image
        _lastClickedImg = 4;

    [[NSNotificationCenter defaultCenter] postNotificationName:ZOOM_TO_CORNER object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithDouble:_zoomPopUpButton.indexOfSelectedItem + 2], kKeyScaleFactor,
                                    [NSNumber numberWithInt:_lastClickedImg], kKeyLastClicked,
																				nil]];
    [self setNeedsDisplay:YES];
#else
    #pragma unused (event)
    return;
#endif
}

- (void)mouseUp:(NSEvent *)event
{
#if 0
    #pragma unused (event)
    _lastClickedImg *= -1;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:ZOOM_TO_CORNER object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithDouble:-100], kKeyScaleFactor,
                                    [NSNumber numberWithInt:_lastClickedImg], kKeyLastClicked,
																				nil]];
    [self setNeedsDisplay:YES];
#else
    #pragma unused (event)
    return;
#endif
}
@end
