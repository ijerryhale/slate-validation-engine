//
//  SlateRuntimeAcquisitionContract.h
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

#ifndef SLATE_SLATERUNTIMEACQUISITIONCONTRACT_H
#define SLATE_SLATERUNTIMEACQUISITIONCONTRACT_H

#import <Foundation/Foundation.h>

// Plain Foundation runtime-acquisition/status contract. This is the adapter's
// parseable answer when a runtime is missing or not yet split out.
static NSString * const SlateRuntimeAcquisitionSchemaVersion1 = @"runtimeAcquisition.v1";

// Top-level keys.
static NSString * const SlateRuntimeAcquisitionKeySchemaVersion = @"schemaVersion";
static NSString * const SlateRuntimeAcquisitionKeyOK = @"ok";
static NSString * const SlateRuntimeAcquisitionKeyMode = @"mode";
static NSString * const SlateRuntimeAcquisitionKeyMessage = @"message";
static NSString * const SlateRuntimeAcquisitionKeyInstallLocations = @"installLocations";
static NSString * const SlateRuntimeAcquisitionKeyRuntimes = @"runtimes";
static NSString * const SlateRuntimeAcquisitionKeyDownloadHint = @"downloadHint";

// Runtime entry keys.
static NSString * const SlateRuntimeAcquisitionRuntimeKeyName = @"name";
static NSString * const SlateRuntimeAcquisitionRuntimeKeyStatus = @"status";
static NSString * const SlateRuntimeAcquisitionRuntimeKeyArtifactName = @"artifactName";
static NSString * const SlateRuntimeAcquisitionRuntimeKeyRequired = @"required";

// Status values.
static NSString * const SlateRuntimeAcquisitionModeInProcess = @"inProcess";
static NSString * const SlateRuntimeAcquisitionModeHybrid = @"hybrid";
static NSString * const SlateRuntimeAcquisitionModeExternal = @"external";
static NSString * const SlateRuntimeAcquisitionStatusAvailable = @"available";
static NSString * const SlateRuntimeAcquisitionStatusMissing = @"missing";
static NSString * const SlateRuntimeAcquisitionStatusInProcess = @"inProcess";

// Future runtime names.
static NSString * const SlateRuntimeNameValidation = @"SlateValidationRuntime";
static NSString * const SlateRuntimeNamePackage = @"SlatePackageRuntime";
static NSString * const SlateRuntimeNameTrack = @"SlateTrackRuntime";
static NSString * const SlateRuntimeNameChapter = @"SlateChapterRuntime";
static NSString * const SlateRuntimeNameReview = @"SlateReviewRuntime";
static NSString * const SlateRuntimeNameTimeline = @"SlateTimelineRuntime";

#endif
