//
//  TimelineReadouts.h
//  Slate
//
//  Created by Jerry Hale on 4/24/26.
//  Copyright (c) 2026 Jerry Hale. All rights reserved.
//
//  Proprietary and confidential.
//  This file is part of Slate and is not open source software.
//
//  No license is granted to copy, modify, distribute, sublicense, or use this
//  source code except under a written agreement with the copyright holder.
//  Unauthorized use, disclosure, reproduction, or distribution is prohibited.
//

#import <Cocoa/Cocoa.h>
#import "TimelineGeometry.h"

@class CALayer;

@interface TimelineReadouts : NSObject

- (void)attachToHostLayer:(CALayer *)hostLayer;
- (void)ensureReadoutLayersIfNeeded;
- (void)layoutReadoutLayersForBounds:(NSRect)bounds layout:(TimelineLayoutSnapshot)layout;
- (void)updateReadoutValuesForLayout:(TimelineLayoutSnapshot)layout bounds:(NSRect)bounds usableMovie:(BOOL)usableMovie currentTimecodeString:(NSString *)currentTimecodeString;
- (void)updateCurrentTimePositionForBounds:(NSRect)bounds layout:(TimelineLayoutSnapshot)layout playheadCenterX:(CGFloat)playheadCenterX;
- (CGFloat)gutterLabelWidth;
- (CGFloat)contentTopInset;

@end
