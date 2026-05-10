//
//  UtilInspectorRailCoord.m
//  Slate
//

#import "UtilInspectorRailCoord.h"

@interface UtilInspectorRailCoord ()
{
    NSMutableDictionary *_adapterByTag;
    NSInteger _activeTag;
}
@end

@implementation UtilInspectorRailCoord

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _adapterByTag = [[NSMutableDictionary alloc] init];
        _activeTag = -1;
    }
    return self;
}

- (void)dealloc
{
    [_adapterByTag release];
    [super dealloc];
}

- (void)registerAdapter:(id<SMInspectorRailModeAdapter>)adapter forTag:(NSInteger)tag
{
    NSNumber *key = [NSNumber numberWithInteger:tag];
    if (adapter == nil) {
        [_adapterByTag removeObjectForKey:key];
        return;
    }

    [_adapterByTag setObject:adapter forKey:key];
}

- (void)setActiveTag:(NSInteger)tag
{
    _activeTag = tag;
}

- (void)applyWorkspaceWidth:(CGFloat)workspaceWidth
{
    NSNumber *key = [NSNumber numberWithInteger:_activeTag];
    id adapter = [_adapterByTag objectForKey:key];
    if ([adapter respondsToSelector:@selector(applyWorkspaceLayoutForWidth:)]) {
        [(id<SMInspectorRailModeAdapter>)adapter applyWorkspaceLayoutForWidth:workspaceWidth];
    }
}

@end
