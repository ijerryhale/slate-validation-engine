//
//  AppController+Focus.m
//  Slate
//

#import "AppController+Focus.h"

#import "PlayerView.h"

static NSView *FocusTransportContainerView(AppController *controller)
{
    return [[controller playerView] superview];
}

static NSButton *FocusTransportButtonForAction(AppController *controller, SEL action)
{
    NSView *containerView = FocusTransportContainerView(controller);
    if (containerView == nil || action == NULL) {
        return nil;
    }

    for (NSView *subview in [containerView subviews]) {
        if (![subview isKindOfClass:[NSButton class]]) {
            continue;
        }

        NSButton *button = (NSButton *)subview;
        if ([button action] == action) {
            return button;
        }
    }

    return nil;
}

@implementation AppController (Focus)

- (NSArray *)transportTimelineFocusOrderViews
{
    NSMutableArray *focusViews = [NSMutableArray array];
    NSView *timelineView = _timelineView;
    NSView *volumeSlider = _volume;
    NSButton *fastBackward = FocusTransportButtonForAction(self, @selector(fastBackward:));
    NSButton *stepBackward = FocusTransportButtonForAction(self, @selector(stepBackward:));
    NSButton *playPause = FocusTransportButtonForAction(self, @selector(togglePlayPause:));
    NSButton *stepForward = FocusTransportButtonForAction(self, @selector(stepForward:));
    NSButton *fastForward = FocusTransportButtonForAction(self, @selector(fastForward:));
    NSButton *timecodeToggle = _timecodeOverlayButton;
    NSView *colorWell = _colorWell;
    NSButton *cropToggle = FocusTransportButtonForAction(self, @selector(toggleCropRect:));

    NSArray *candidates = [NSArray arrayWithObjects:
                           timelineView ?: [NSNull null],
                           volumeSlider ?: [NSNull null],
                           fastBackward ?: [NSNull null],
                           stepBackward ?: [NSNull null],
                           playPause ?: [NSNull null],
                           stepForward ?: [NSNull null],
                           fastForward ?: [NSNull null],
                           timecodeToggle ?: [NSNull null],
                           colorWell ?: [NSNull null],
                           cropToggle ?: [NSNull null],
                           _rawCropLeft ?: [NSNull null],
                           _rawCropTop ?: [NSNull null],
                           _rawCropRght ?: [NSNull null],
                           _rawCropBtm ?: [NSNull null],
                           _views ?: [NSNull null],
                           nil];

    for (id candidate in candidates) {
        if (![candidate isKindOfClass:[NSView class]]) {
            continue;
        }

        NSView *view = (NSView *)candidate;
        if ([view isHidden] || [view window] != _window) {
            continue;
        }
        if ([view isKindOfClass:[NSControl class]] && ![(NSControl *)view isEnabled]) {
            continue;
        }

        [focusViews addObject:view];
    }

    return focusViews;
}

- (void)rebuildTransportTimelineKeyViewLoop
{
    NSArray *focusViews = [self transportTimelineFocusOrderViews];
    if ([focusViews count] < 2) {
        return;
    }

    for (NSUInteger index = 0; index < [focusViews count]; index++) {
        NSView *currentView = [focusViews objectAtIndex:index];
        NSUInteger nextIndex = (index + 1) % [focusViews count];
        NSView *nextView = [focusViews objectAtIndex:nextIndex];
        [currentView setNextKeyView:nextView];
    }
}

@end
