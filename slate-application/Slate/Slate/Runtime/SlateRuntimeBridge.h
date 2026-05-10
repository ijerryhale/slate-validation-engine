//
//  SlateRuntimeBridge.h
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

#import <Cocoa/Cocoa.h>

@class SMMovie;

@interface SlateRuntimeBridge : NSObject

+ (NSDictionary *)packageContextForPackagePath:(NSString *)packagePath;
+ (NSDictionary *)packageSnapshotForPackagePath:(NSString *)packagePath;
+ (NSDictionary *)trackSnapshotForMovie:(SMMovie *)movie hasMovie:(BOOL)hasMovie;
+ (NSDictionary *)chapterSnapshotForPackagePath:(NSString *)packagePath
                                          movie:(SMMovie *)movie
                                     hasPackage:(BOOL)hasPackage;
+ (NSDictionary *)validationReportForPackagePath:(NSString *)packagePath
                                   observedState:(NSDictionary *)observedState;
+ (NSDictionary *)reviewPaneSnapshotWithPaneKey:(NSString *)paneKey
                                          title:(NSString *)title
                                       findings:(NSArray *)findings
                                    emptyStatus:(NSString *)emptyStatus
                                   emptyMessage:(NSString *)emptyMessage
                     jumpLinksByFindingIdentity:(NSDictionary *)jumpLinksByFindingIdentity;
+ (NSDictionary *)reviewSnapshotWithContext:(NSDictionary *)context
                             canonicalReport:(NSDictionary *)canonicalReport
                                  activePane:(NSString *)activePane;
+ (NSDictionary *)timelineSnapshotWithBounds:(NSRect)bounds
                                    duration:(NSTimeInterval)duration
                                 currentTime:(NSTimeInterval)currentTime
                                   frameRate:(double)frameRate
                              selectionStart:(NSTimeInterval)selectionStart
                                selectionEnd:(NSTimeInterval)selectionEnd
                            sideReadoutWidth:(CGFloat)sideReadoutWidth
                             contentTopInset:(CGFloat)contentTopInset
                                 usableMovie:(BOOL)usableMovie
                       currentTimecodeString:(NSString *)currentTimecodeString;
+ (NSDictionary *)commandResultWithCommand:(NSString *)command
                                    payload:(NSDictionary *)payload
                                     result:(id)result;
+ (NSDictionary *)commandErrorWithCommand:(NSString *)command
                                  payload:(NSDictionary *)payload
                                     code:(NSString *)code
                                  message:(NSString *)message;
+ (NSDictionary *)runtimeAcquisitionStatus;

@end
