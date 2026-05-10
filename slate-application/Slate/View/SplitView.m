//
//  SplitView.m
//  Slate
//
//  Created by Jerry Hale on 3/20/26
//  Copyright (c) 2026 Jerry Hale All rights reserved.


#import "SplitView.h"

@implementation SplitView

-(BOOL) _tryParsingDividerPositionIndex:(NSInteger*) anInteger fromKey:(NSString*) key
{
    #pragma unused (key)
    *anInteger = 0;
    return YES;
}

-(CGFloat)positionForDividerAtIndex:(NSInteger)idx
{
    NSRect frame = [[[self subviews] objectAtIndex:idx] frame];
    if (self.isVertical) {
        return NSMaxX(frame) + ([self dividerThickness] * idx);
    }
    else {
        return NSMaxY(frame) + ([self dividerThickness] * idx);
    }
}

-(void)setPosition:(CGFloat)position ofDividerAtIndex:(NSInteger)dividerIndex animate:(BOOL)animate
{
    if (!animate)
        [super setPosition:position ofDividerAtIndex:dividerIndex];
    else
        [[self animator] setValue:[NSNumber numberWithFloat:position] forKey:[NSString stringWithFormat:@"dividerPosition%ld", (long)dividerIndex, nil]];
}

-(id)animationForKey:(NSString *)key
{
    id animation = [super animationForKey:key];
    NSInteger idx;
    if (animation == nil && [self _tryParsingDividerPositionIndex:&idx fromKey:key]) {
        animation = [super animationForKey:@"dividerPosition"];
    }
    
    return animation;
}

-(id)valueForUndefinedKey:(NSString *)key
{
    NSInteger idx;
    if ([self _tryParsingDividerPositionIndex:&idx fromKey:key]) {
        CGFloat position = [self positionForDividerAtIndex:idx];
        return [NSNumber numberWithFloat:position];
    }
    
    return nil;
}

-(void)setValue:(id)value forUndefinedKey:(NSString *)key
{
    NSInteger idx;
    if ([value isKindOfClass:[NSNumber class]] && [self _tryParsingDividerPositionIndex:&idx fromKey:key]) {
        [super setPosition:[value floatValue] ofDividerAtIndex:idx];
    }
}
@end
