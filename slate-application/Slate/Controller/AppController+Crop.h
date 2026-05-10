//
//  AppController+Crop.h
//  Slate
//
//  Created by Jerry Hale on 5/6/26.
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
#import "MediaSupport/SMCropGeometry.h"

@interface AppController (Crop)

- (SMCropMargins)currentOverlayCropMargins;
- (void)restoreCropOverlayFromPackageContextIfPossible:(NSDictionary *)packageContext;
- (IBAction)grabChapterCropRect:(id)sender;
- (void)refreshCropValues:(NSNotification *)notif;

@end
