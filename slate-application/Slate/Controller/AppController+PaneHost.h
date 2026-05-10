//
//  AppController+PaneHost.h
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

#import "AppController.h"

@interface AppController (PaneHost)

- (IBAction)selectBottomPane:(id)sender;
- (CGFloat)currentWorkspaceResponsiveWidth;
- (void)applyModeWorkspaceResponsiveLayout;

- (id)ensureBottomPaneControllerForTag:(NSInteger)tag;
- (TrackViewController *)ensureTrackViewControllerLoaded;
- (PackageViewController *)ensurePackageViewControllerLoaded;
- (ChapterViewController *)ensureChapterViewControllerLoaded;

@end
