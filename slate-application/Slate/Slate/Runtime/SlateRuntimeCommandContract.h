//
//  SlateRuntimeCommandContract.h
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

#ifndef SLATE_SLATERUNTIMECOMMANDCONTRACT_H
#define SLATE_SLATERUNTIMECOMMANDCONTRACT_H

#import <Foundation/Foundation.h>

// Plain Foundation command-result surface. Commands describe adapter intent;
// execution may stay in-process until the runtime split is real.
static NSString * const SlateRuntimeCommandResultSchemaVersion1 = @"runtimeCommandResult.v1";

// Command names.
static NSString * const SlateRuntimeCommandOpenPath = @"openPath";
static NSString * const SlateRuntimeCommandRefresh = @"refresh";
static NSString * const SlateRuntimeCommandSetMode = @"setMode";
static NSString * const SlateRuntimeCommandSelectRow = @"selectRow";
static NSString * const SlateRuntimeCommandJumpToTime = @"jumpToTime";
static NSString * const SlateRuntimeCommandRevealFinding = @"revealFinding";
static NSString * const SlateRuntimeCommandNextFinding = @"nextFinding";
static NSString * const SlateRuntimeCommandPreviousFinding = @"previousFinding";

// Command result keys.
static NSString * const SlateRuntimeCommandResultKeySchemaVersion = @"schemaVersion";
static NSString * const SlateRuntimeCommandResultKeyCommand = @"command";
static NSString * const SlateRuntimeCommandResultKeyPayload = @"payload";
static NSString * const SlateRuntimeCommandResultKeyAccepted = @"accepted";
static NSString * const SlateRuntimeCommandResultKeyResult = @"result";
static NSString * const SlateRuntimeCommandResultKeyError = @"error";

// Common payload/result keys.
static NSString * const SlateRuntimeCommandKeyPath = @"path";
static NSString * const SlateRuntimeCommandKeyMode = @"mode";
static NSString * const SlateRuntimeCommandKeyPane = @"pane";
static NSString * const SlateRuntimeCommandKeyRowIndex = @"rowIndex";
static NSString * const SlateRuntimeCommandKeySeconds = @"seconds";
static NSString * const SlateRuntimeCommandKeyFinding = @"finding";
static NSString * const SlateRuntimeCommandKeySnapshot = @"snapshot";

// Error keys.
static NSString * const SlateRuntimeCommandErrorKeyCode = @"code";
static NSString * const SlateRuntimeCommandErrorKeyMessage = @"message";

#endif
