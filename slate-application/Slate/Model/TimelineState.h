//
//  TimelineState.h
//  Slate
//
//  Created by Jerry Hale on 3/25/26.
//  Copyright (c) 2026 Jerry Hale. All rights reserved.
//
//  Proprietary and confidential.
//  This file is part of Slate and is not open source software.
//
//  No license is granted to copy, modify, distribute, sublicense, or use this
//  source code except under a written agreement with the copyright holder.
//  Unauthorized use, disclosure, reproduction, or distribution is prohibited.
//

#import <Foundation/Foundation.h>

@interface TimelineState : NSObject
{
    NSTimeInterval  _currentTime;
    NSTimeInterval  _duration;
    NSTimeInterval  _selectionStart;
    NSTimeInterval  _selectionEnd;
    NSString        *_currentTimecodeString;
    double          _frameRate;
    BOOL            _scrubbing;
}

@property NSTimeInterval currentTime;
@property NSTimeInterval duration;
@property NSTimeInterval selectionStart;
@property NSTimeInterval selectionEnd;
@property (nonatomic, copy) NSString *currentTimecodeString;
@property double frameRate;
@property (getter=isScrubbing) BOOL scrubbing;

- (void)resetForDuration:(NSTimeInterval)duration;

@end
