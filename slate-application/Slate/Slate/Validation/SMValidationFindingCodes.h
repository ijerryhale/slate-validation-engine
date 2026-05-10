//
//  SMValidationFindingCodes.h
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

#import <Foundation/Foundation.h>

// Finding codes that UI adapters consume directly. Keep these stable even if
// titles/evidence wording changes.
static NSString * const SMValidationFindingCodeTracksAssetTypeIsUnknown = @"tracks.asset_type_is_unknown";
static NSString * const SMValidationFindingCodeChaptersChapterImageIsNotMarkedValid = @"chapters.chapter_image_is_not_marked_valid";
static NSString * const SMValidationFindingCodeEngineRuleIdentityIsIncomplete = @"engine.rule_identity_is_incomplete";

// Canonical session scopes.
static NSString * const SMValidationScopeTrackState = @"track-state";
static NSString * const SMValidationScopeChapterState = @"chapter-state";
static NSString * const SMValidationScopeSMPkgSession = @"package-session";
static NSString * const SMValidationScopePackageMetadata = @"package-metadata";

// Scope prefixes for row-scoped findings.
static NSString * const SMValidationScopeTrackRowPrefix = @"track-row:";
static NSString * const SMValidationScopeChapterRowPrefix = @"chapter-row:";
static NSString * const SMValidationScopeLocaleRowPrefix = @"locale-row:";
static NSString * const SMValidationScopePlatformRowPrefix = @"platform-row:";
static NSString * const SMValidationScopeAssetRowPrefix = @"asset-row:";
static NSString * const SMValidationScopeGenreRowPrefix = @"genre-row:";
static NSString * const SMValidationScopeEngineRuleIdentity = @"engine:rule-identity";
