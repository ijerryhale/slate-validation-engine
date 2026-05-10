//
//  AppController+Sidecar.h
//  Slate
//
//  Created by Jerry Hale on 4/26/26.
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

@interface AppController (Sidecars)

- (void)createTrackMenuIfNeeded;
- (void)createValidationMenuIfNeeded;
- (BOOL)sidecarAutoloadEnabled;
- (IBAction)toggleSidecarAutoload:(id)sender;
- (BOOL)movieHasSidecarTracksOfMediaType:(NSString *)mediaType;
- (BOOL)track:(SMTrack *)track matchesSidecarMediaType:(NSString *)mediaType;
- (BOOL)hasEnabledSidecarTracksOfMediaType:(NSString *)mediaType;
- (void)setEnabled:(BOOL)enabled forSidecarTracksOfMediaType:(NSString *)mediaType;
- (BOOL)movieHasSubtitleSidecarTracks;
- (BOOL)movieHasClosedCaptionSidecarTracks;
- (void)syncSidecarVisibilityState;
- (IBAction)toggleSubtitles:(id)sender;
- (IBAction)toggleClosedCaption:(id)sender;
- (void)autoloadReferenceSidecarsIfNeeded;

@end
