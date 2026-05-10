//
//  SMValidationCanonicalDictionaryKeys.h
//  Slate
//
//  Created by Jerry Hale on 4/21/26.
//  Copyright (c) 2026 Jerry Hale. All rights reserved.
//
//  Proprietary and confidential.
//  This file is part of Slate and is not open source software.
//
//  No license is granted to copy, modify, distribute, sublicense, or use this
//  source code except under a written agreement with the copyright holder.
//  Unauthorized use, disclosure, reproduction, or distribution is prohibited.
//

#ifndef SLATE_SMVALIDATIONCANONICALDICTIONARYKEYS_H
#define SLATE_SMVALIDATIONCANONICALDICTIONARYKEYS_H

#import <Foundation/Foundation.h>

// Canonical finding dictionary keys.
static NSString * const SMValidationFindingKeyCode = @"code";
static NSString * const SMValidationFindingKeySeverity = @"severity";
static NSString * const SMValidationFindingKeyCategory = @"category";
static NSString * const SMValidationFindingKeyScope = @"scope";
static NSString * const SMValidationFindingKeyTitle = @"title";
static NSString * const SMValidationFindingKeyEvidence = @"evidence";
static NSString * const SMValidationFindingKeyFallbackUsed = @"fallbackUsed";
static NSString * const SMValidationFindingKeyIdentitySource = @"identitySource";

// Canonical report dictionary keys.
static NSString * const SMValidationReportKeySchemaVersion = @"schemaVersion";
static NSString * const SMValidationReportKeyStatus = @"status";
static NSString * const SMValidationReportKeySummary = @"summary";
static NSString * const SMValidationReportKeyNextFinding = @"nextFinding";
static NSString * const SMValidationReportKeyFindings = @"findings";
static NSString * const SMValidationReportKeyOperatorText = @"operatorText";
static NSString * const SMValidationReportKeyValidationResultPayload = @"validationResultPayload";

// Machine-readable validation payload keys.
static NSString * const SMValidationResultPayloadKeySchemaVersion = @"schemaVersion";
static NSString * const SMValidationResultPayloadKeyFindings = @"findings";
static NSString * const SMValidationResultPayloadSchemaVersion1 = @"1";

// Summary sub-dictionary keys.
static NSString * const SMValidationSummaryKeyBlockers = @"blockers";
static NSString * const SMValidationSummaryKeyWarnings = @"warnings";
static NSString * const SMValidationSummaryKeyTotal = @"total";

// Canonical value constants.
static NSString * const SMValidationSchemaVersion1 = @"1";
static NSString * const SMValidationStatusPass = @"pass";
static NSString * const SMValidationSeverityCodeBlocker = @"blocker";
static NSString * const SMValidationSeverityCodeWarning = @"warning";
static NSString * const SMValidationCategoryCodeTracks = @"tracks";
static NSString * const SMValidationCategoryCodeRoles = @"roles";
static NSString * const SMValidationCategoryCodePackage = @"package";
static NSString * const SMValidationCategoryCodeMetadata = @"metadata";
static NSString * const SMValidationCategoryCodeChapters = @"chapters";

// Canonical fallback values.
static NSString * const SMValidationFallbackFindingCode = @"finding.unknown";
static NSString * const SMValidationFallbackFindingScope = @"session";
static NSString * const SMValidationFallbackFindingTitle = @"Readiness finding";
static NSString * const SMValidationFallbackFindingEvidence = @"No supporting evidence was provided.";

#endif
