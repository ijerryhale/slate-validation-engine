//
//  UtilAECodec.h
//  Slate
//
//  Created by Jerry Hale on 5/3/26.
//  Copyright (c) 2026 Jerry Hale. All rights reserved.
//
//  Proprietary and confidential.
//  This file is part of Slate and is not open source software.
//
//  No license is granted to copy, modify, distribute, sublicense, or use this
//  source code except under a written agreement with the copyright holder.
//  Unauthorized use, disclosure, reproduction, or distribution is prohibited.
//

#import <AppKit/AppKit.h>

NSString *UtilAENormalizedTokenString(NSString *value);
NSNumber *UtilAENumberFromDescriptor(NSAppleEventDescriptor *descriptor);
NSString *UtilAEStringFromDescriptor(NSAppleEventDescriptor *descriptor);
NSArray *UtilAENumericListFromDescriptor(NSAppleEventDescriptor *descriptor, NSInteger expectedCount);
NSString *UtilAEPathFromDescriptor(NSAppleEventDescriptor *descriptor);
NSAppleEventDescriptor *UtilAEDescriptorListFromNumericArray(NSArray *values);
NSAppleEventDescriptor *UtilAEJSONDescriptorForObject(id object);
NSString *UtilAEFourCharCodeString(OSType fourCharCode);
NSDictionary *UtilAEOperatorResultPayload(OSType eventClass,
                                          AEEventID eventID,
                                          id result);
NSDictionary *UtilAEOperatorErrorPayload(OSType eventClass,
                                         AEEventID eventID,
                                         NSString *code,
                                         NSString *message,
                                         SInt32 appleEventError);

void UtilAEPopulateReplyError(NSAppleEventDescriptor *replyEvent,
                              SInt32 errorNumber,
                              NSString *message);
void UtilAEPopulateReplyResult(NSAppleEventDescriptor *replyEvent,
                               NSAppleEventDescriptor *resultDescriptor);
