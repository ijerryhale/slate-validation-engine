//
//  SlateChapterSnapshotContract.h
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

#ifndef SLATE_SLATECHAPTERSNAPSHOTCONTRACT_H
#define SLATE_SLATECHAPTERSNAPSHOTCONTRACT_H

#import <Foundation/Foundation.h>

// Plain Foundation snapshot consumed by the chapter UI adapter.
// No table view, controller, image, package, or movie objects belong here.
static NSString * const SlateChapterSnapshotSchemaVersion1 = @"chapterSnapshot.v1";

// Top-level keys.
static NSString * const SlateChapterSnapshotKeySchemaVersion = @"schemaVersion";
static NSString * const SlateChapterSnapshotKeyHasPackage = @"hasPackage";
static NSString * const SlateChapterSnapshotKeyRows = @"rows";
static NSString * const SlateChapterSnapshotKeyChapterCount = @"chapterCount";
static NSString * const SlateChapterSnapshotKeyError = @"error";

// Optional structured error keys when the runtime-backed snapshot is unavailable.
static NSString * const SlateChapterSnapshotErrorKeyCode = @"code";
static NSString * const SlateChapterSnapshotErrorKeyMessage = @"message";

// Row keys shared by the table, C + I inspector, crop status, and operator AEs.
static NSString * const SlateChapterSnapshotRowKeyRowIndex = @"rowIndex";
static NSString * const SlateChapterSnapshotRowKeyRow = @"row";
static NSString * const SlateChapterSnapshotRowKeyChapterID = @"chapterID";
static NSString * const SlateChapterSnapshotRowKeyTitle = @"title";
static NSString * const SlateChapterSnapshotRowKeyMediaChapterTimecode = @"mediaChapterTimecode";
static NSString * const SlateChapterSnapshotRowKeyMediaImageTimecode = @"mediaImageTimecode";
static NSString * const SlateChapterSnapshotRowKeyAbsoluteChapterTimecode = @"absoluteChapterTimecode";
static NSString * const SlateChapterSnapshotRowKeyAbsoluteImageTimecode = @"absoluteImageTimecode";
static NSString * const SlateChapterSnapshotRowKeyChapterTimeValue = @"chapterTimeValue";
static NSString * const SlateChapterSnapshotRowKeyImageTimeValue = @"imageTimeValue";
static NSString * const SlateChapterSnapshotRowKeyCropTop = @"cropTop";
static NSString * const SlateChapterSnapshotRowKeyCropLeft = @"cropLeft";
static NSString * const SlateChapterSnapshotRowKeyCropBottom = @"cropBottom";
static NSString * const SlateChapterSnapshotRowKeyCropRight = @"cropRight";
static NSString * const SlateChapterSnapshotRowKeyCropDisplay = @"cropDisplay";
static NSString * const SlateChapterSnapshotRowKeyDeclaredImagePath = @"declaredImagePath";
static NSString * const SlateChapterSnapshotRowKeyResolvedImagePath = @"resolvedImagePath";
static NSString * const SlateChapterSnapshotRowKeyImageValid = @"imageValid";
static NSString * const SlateChapterSnapshotRowKeyImageStatus = @"imageStatus";
static NSString * const SlateChapterSnapshotRowKeyDetails = @"details";
static NSString * const SlateChapterSnapshotRowKeyDetailsText = @"detailsText";

// Inspector detail pair keys.
static NSString * const SlateChapterSnapshotDetailKeyKey = @"key";
static NSString * const SlateChapterSnapshotDetailKeyValue = @"value";

// Primary table column identifiers.
static NSString * const SlateChapterSnapshotColumnTitle = @"chapterTitle";
static NSString * const SlateChapterSnapshotColumnMediaChapterTimecode = @"mediaChapterTimecode";
static NSString * const SlateChapterSnapshotColumnMediaImageTimecode = @"mediaImageTimecode";
static NSString * const SlateChapterSnapshotColumnAbsoluteChapterTimecode = @"chapterTimecode";
static NSString * const SlateChapterSnapshotColumnAbsoluteImageTimecode = @"imageTimecode";
static NSString * const SlateChapterSnapshotColumnCrop = @"CROP";
static NSString * const SlateChapterSnapshotColumnImageFilePath = @"imageFilePath";
static NSString * const SlateChapterSnapshotColumnImageValid = @"ISVALIDIMG";

#endif
