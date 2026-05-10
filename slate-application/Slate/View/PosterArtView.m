//
//  PosterArtView.m
//  Slate
//
//  Created by Jerry Hale on 3/20/26
//  Copyright (c) 2026 Jerry Hale All rights reserved.

#import "PosterArtView.h"

@implementation PosterArtView

-(void)awakeFromNib
{
	[super awakeFromNib];
}

-(void)initWindowCnt { _windowCnt = 0; }

-(void)doubleAction
{
    //  NSLog(@"doubleAction");
    NSImage *image = [self image];
        
    if (image)
    {
        NSRect      e = [[NSScreen mainScreen] frame];
        NSImageRep  *rep = [[image representations] objectAtIndex:0];
        NSSize      imageSize = NSMakeSize(rep.pixelsWide, rep.pixelsHigh);
        NSSize      imgWindowSize;

        imgWindowSize.width = imageSize.width;
        imgWindowSize.height = e.size.height;

        if (imgWindowSize.height > imageSize.height)
            imgWindowSize.height = imageSize.height;

        NSWindow    *posterWindow = [[NSWindow alloc]
                initWithContentRect:NSMakeRect((e.size.width / 2) - (imageSize.width / 2), (e.size.height / 2) - (imageSize.height / 2), imgWindowSize.width, imgWindowSize.height)
                                                    styleMask:NSClosableWindowMask | NSTitledWindowMask | NSResizableWindowMask
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO];
        NSImageView     *imageView = [[NSImageView alloc]initWithFrame:NSMakeRect(0, 0, imageSize.width, imageSize.height)];
        
        [imageView setImage:image];
        [imageView setImageScaling:NSImageScaleProportionallyUpOrDown];
        
        NSScrollView    *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, imgWindowSize.width, imgWindowSize.height)];
        
        [scrollView setBorderType:NSNoBorder];
        [scrollView setHasVerticalScroller:YES];
        [scrollView setHasHorizontalScroller:YES];
        [scrollView setAutohidesScrollers:YES];
        [scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [scrollView setDocumentView:imageView];

        [[posterWindow contentView] addSubview:scrollView];
        
        imageSize.height += 18;

        [posterWindow setMaxSize:imageSize];
        [posterWindow setReleasedWhenClosed:YES];
        [posterWindow makeKeyAndOrderFront:nil];
        
        [NSApp addWindowsItem:posterWindow title:[NSString stringWithFormat:@"Poster Art %i", ++_windowCnt] filename:NO];
    }
}

-(void)mouseDown:(NSEvent *)event
{
    if ([event clickCount] >= 2) {
        [self doubleAction];
    } else {
        [super mouseDown:event];
    }
}

-(void)dealloc
{
    [super dealloc];
}

@end
