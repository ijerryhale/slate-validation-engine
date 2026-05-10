//
//  SlatePackageContextContract.h
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

#ifndef SLATE_SLATEPACKAGECONTEXTCONTRACT_H
#define SLATE_SLATEPACKAGECONTEXTCONTRACT_H

#import <Foundation/Foundation.h>

// Plain Foundation envelope emitted by SlatePackageRuntime. Slate.app owns the
// selected path and this dictionary; it does not own the parser/session object.
static NSString * const SlatePackageContextSchemaVersion1 = @"packageContext.v1";

// Top-level keys.
static NSString * const SlatePackageContextKeySchemaVersion = @"schemaVersion";
static NSString * const SlatePackageContextKeyHasPackage = @"hasPackage";
static NSString * const SlatePackageContextKeySource = @"source";
static NSString * const SlatePackageContextKeyPackageSnapshot = @"packageSnapshot";
static NSString * const SlatePackageContextKeySummary = @"summary";
static NSString * const SlatePackageContextKeyPrimaryAsset = @"primaryAsset";
static NSString * const SlatePackageContextKeyError = @"error";

// Summary keys.
static NSString * const SlatePackageContextSummaryKeyTitle = @"title";
static NSString * const SlatePackageContextSummaryKeyDetails = @"details";

// Primary asset keys.
static NSString * const SlatePackageContextPrimaryAssetKeyAssetTypeID = @"assetTypeID";
static NSString * const SlatePackageContextPrimaryAssetKeyMediaType = @"mediaType";
static NSString * const SlatePackageContextPrimaryAssetKeyDeclaredPath = @"declaredPath";
static NSString * const SlatePackageContextPrimaryAssetKeyResolvedPath = @"resolvedPath";
static NSString * const SlatePackageContextPrimaryAssetKeyPathKind = @"pathKind";
static NSString * const SlatePackageContextPrimaryAssetKeyExistenceStatus = @"existenceStatus";
static NSString * const SlatePackageContextPrimaryAssetKeyCropTop = @"cropTop";
static NSString * const SlatePackageContextPrimaryAssetKeyCropLeft = @"cropLeft";
static NSString * const SlatePackageContextPrimaryAssetKeyCropBottom = @"cropBottom";
static NSString * const SlatePackageContextPrimaryAssetKeyCropRight = @"cropRight";

// Error keys.
static NSString * const SlatePackageContextErrorKeyCode = @"code";
static NSString * const SlatePackageContextErrorKeyMessage = @"message";

#endif
