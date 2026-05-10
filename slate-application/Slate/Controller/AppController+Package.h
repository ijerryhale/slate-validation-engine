//
//  AppController+Package.h
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

@interface AppController (Packages)

- (IBAction)openPackageInput:(id)sender;
- (IBAction)showPackageSummary:(id)sender;
- (void)closePackageContextResettingUIState;
- (BOOL)openPackageContextFromURL:(NSURL *)url presentErrors:(BOOL)presentErrors;
- (void)presentPackageContext:(NSDictionary *)packageContext;
- (void)presentPackageOpenErrorWithTitle:(NSString *)title informativeText:(NSString *)informativeText;
- (BOOL)shouldRetainPackageContextWhenOpeningMoviePath:(NSString *)moviePath;
- (void)refreshPackageAdaptersFromCurrentContext;
- (BOOL)pathLooksLikePackageInput:(NSString *)path;
- (NSString *)currentPackagePath;

@end
