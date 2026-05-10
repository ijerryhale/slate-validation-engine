//
//  Window.m
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

#import "Window.h"
#import "../Controller/AppController.h"

@implementation Window

static BOOL viewIsVisible(NSView *view)
{
    NSView *currentView = view;
    while (currentView != nil) {
        if ([currentView isHidden]) {
            return NO;
        }
        currentView = [currentView superview];
    }

    return YES;
}

static BOOL WindowShouldHandleSpaceForPlayback(NSWindow *window, NSEvent *event)
{
    if (event.type != NSEventTypeKeyDown) {
        return NO;
    }

    if ((event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask) != 0) {
        return NO;
    }

    if (![[event charactersIgnoringModifiers] isEqualToString:@" "]) {
        return NO;
    }

    id firstResponder = [window firstResponder];
    if ([firstResponder isKindOfClass:[NSTextView class]] && [(NSTextView *)firstResponder isEditable]) {
        id editedObject = [(NSTextView *)firstResponder delegate];
        if ([editedObject isKindOfClass:[NSView class]] && viewIsVisible((NSView *)editedObject)) {
            return NO;
        }
    }

    return YES;
}

- (BOOL)performKeyEquivalent:(NSEvent *)event
{
    if (WindowShouldHandleSpaceForPlayback(self, event)) {
        AppController *appDelegate = appcontroller();
        if ([appDelegate respondsToSelector:@selector(togglePlayPause:)]) {
            [NSApp sendAction:@selector(togglePlayPause:) to:appDelegate from:self];
            return YES;
        }
    }

    return [super performKeyEquivalent:event];
}

- (void)sendEvent:(NSEvent *)event
{
    if (WindowShouldHandleSpaceForPlayback(self, event)) {
        AppController *appDelegate = appcontroller();
        if ([appDelegate respondsToSelector:@selector(togglePlayPause:)]) {
            [NSApp sendAction:@selector(togglePlayPause:) to:appDelegate from:self];
            return;
        }
    }

    [super sendEvent:event];
}
@end
