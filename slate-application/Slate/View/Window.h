//
//  Window.h
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

@interface Window : NSWindow
- (BOOL)performKeyEquivalent:(NSEvent *)event;
- (void)sendEvent:(NSEvent *)event;

@end
