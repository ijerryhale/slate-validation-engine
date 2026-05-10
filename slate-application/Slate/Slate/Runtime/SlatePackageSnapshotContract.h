//
//  SlatePackageSnapshotContract.h
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

#ifndef SLATE_SLATEPACKAGESNAPSHOTCONTRACT_H
#define SLATE_SLATEPACKAGESNAPSHOTCONTRACT_H

#import <Foundation/Foundation.h>

// Plain Foundation snapshot consumed by the package UI adapter.
// No view, image, or session objects belong in this contract.
static NSString * const SlatePackageSnapshotSchemaVersion1 = @"packageSnapshot.v1";

// Top-level keys.
static NSString * const SlatePackageSnapshotKeySchemaVersion = @"schemaVersion";
static NSString * const SlatePackageSnapshotKeySource = @"source";
static NSString * const SlatePackageSnapshotKeyAssetStack = @"assetStack";
static NSString * const SlatePackageSnapshotKeySynopsis = @"synopsis";
static NSString * const SlatePackageSnapshotKeyMetadataCollections = @"metadataCollections";
static NSString * const SlatePackageSnapshotKeyPosterArt = @"posterArt";

// Source keys.
static NSString * const SlatePackageSnapshotSourceKeyKind = @"kind";
static NSString * const SlatePackageSnapshotSourceKeyPath = @"path";
static NSString * const SlatePackageSnapshotSourceKeyPackageType = @"packageType";

// Asset stack keys.
static NSString * const SlatePackageSnapshotAssetKeyType = @"type";
static NSString * const SlatePackageSnapshotAssetKeyName = @"name";
static NSString * const SlatePackageSnapshotAssetKeyVendorID = @"vendorID";
static NSString * const SlatePackageSnapshotAssetKeyMediaType = @"mediaType";
static NSString * const SlatePackageSnapshotAssetKeyReleaseDate = @"releaseDate";
static NSString * const SlatePackageSnapshotAssetKeyRatingSystem = @"ratingSystem";
static NSString * const SlatePackageSnapshotAssetKeyRating = @"rating";

// Synopsis keys.
static NSString * const SlatePackageSnapshotSynopsisKeyShort = @"short";
static NSString * const SlatePackageSnapshotSynopsisKeyLong = @"long";

// Metadata collection entry keys.
static NSString * const SlatePackageSnapshotCollectionKeyDisplayText = @"displayText";
static NSString * const SlatePackageSnapshotCollectionKeyItems = @"items";

// Poster art keys.
static NSString * const SlatePackageSnapshotPosterKeyDeclaredPath = @"declaredPath";
static NSString * const SlatePackageSnapshotPosterKeyResolvedPath = @"resolvedPath";
static NSString * const SlatePackageSnapshotPosterKeyPathKind = @"pathKind";
static NSString * const SlatePackageSnapshotPosterKeyExistenceStatus = @"existenceStatus";

// Package readiness/rail targets.
static NSString * const SlatePackageSnapshotTargetType = @"metadata.type";
static NSString * const SlatePackageSnapshotTargetName = @"metadata.name";
static NSString * const SlatePackageSnapshotTargetVendor = @"metadata.vendor";
static NSString * const SlatePackageSnapshotTargetMediaType = @"metadata.mediaType";
static NSString * const SlatePackageSnapshotTargetReleaseDate = @"metadata.releaseDate";
static NSString * const SlatePackageSnapshotTargetRatingSystem = @"metadata.ratingSystem";
static NSString * const SlatePackageSnapshotTargetRating = @"metadata.rating";
static NSString * const SlatePackageSnapshotTargetPoster = @"metadata.poster";
static NSString * const SlatePackageSnapshotTargetSynopsisShort = @"metadata.synopsis.short";
static NSString * const SlatePackageSnapshotTargetSynopsisLong = @"metadata.synopsis.long";
static NSString * const SlatePackageSnapshotTargetLocales = @"metadata.locales";
static NSString * const SlatePackageSnapshotTargetChapters = @"metadata.chapters";
static NSString * const SlatePackageSnapshotTargetPlatforms = @"metadata.platforms";
static NSString * const SlatePackageSnapshotTargetGenres = @"metadata.genres";
static NSString * const SlatePackageSnapshotTargetCast = @"metadata.cast";
static NSString * const SlatePackageSnapshotTargetCrew = @"metadata.crew";

#endif
