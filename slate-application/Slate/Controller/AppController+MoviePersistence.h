//
//  AppController+MoviePersistence.h
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

@interface AppController (MoviePersistence)

- (void)presentSaveFailureWithMessageText:(NSString *)message informativeText:(NSString *)informativeText;
- (BOOL)ensureBackupExistsForCurrentMovie:(NSError **)error;
- (BOOL)saveCurrentMovieRebuildingTracks:(BOOL)rebuildTracks;
- (BOOL)saveCurrentMovieToURL:(NSURL *)outputURL;
- (IBAction)doSave:(id)sender;
- (IBAction)saveDocumentAs:(id)sender;

@end
