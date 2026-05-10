//
//  AppController+TrailerExport.h
//  Slate
//
//  Created by Jerry Hale on 3/27/26.
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

@interface AppController (TrailerExport)

- (void)resetTrailerExportState;
- (void)updateTrailerExportProgress:(NSTimer *)timer;
- (void)presentTrailerExportError:(NSError *)error;
- (void)finishFFmpegTrailerExportWithResult:(NSDictionary *)result;
- (void)finishTrailerExport;
- (void)startTrailerExportToURL:(NSURL *)outputURL timeRange:(SMTimeRange)timeRange;
- (void)trailerPanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (IBAction)createTrailer:(id)sender;

@end
