//
//  UtilInspectorRailCoord.h
//  Slate
//
//  Created by Jerry Hale on 4/30/26.
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

@protocol SMInspectorRailModeAdapter <NSObject>
- (void)applyWorkspaceLayoutForWidth:(CGFloat)workspaceWidth;
@end

@interface UtilInspectorRailCoord : NSObject

- (void)registerAdapter:(id<SMInspectorRailModeAdapter>)adapter forTag:(NSInteger)tag;
- (void)setActiveTag:(NSInteger)tag;
- (void)applyWorkspaceWidth:(CGFloat)workspaceWidth;

@end
