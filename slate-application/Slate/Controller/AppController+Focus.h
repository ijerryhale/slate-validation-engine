//
//  AppController+Focus.h
//  Slate
//

#import "AppController.h"

@interface AppController (Focus)

- (NSArray *)transportTimelineFocusOrderViews;
- (void)rebuildTransportTimelineKeyViewLoop;

@end
