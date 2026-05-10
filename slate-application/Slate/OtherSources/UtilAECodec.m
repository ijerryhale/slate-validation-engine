//
//  UtilAECodec.m
//  Slate
//

#import "UtilAECodec.h"

static NSString * const UtilAEOperatorResultSchemaVersion = @"operatorResult.v1";

NSString *UtilAENormalizedTokenString(NSString *value)
{
    if (![value isKindOfClass:[NSString class]]) {
        return nil;
    }

    return [[value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
}

NSNumber *UtilAENumberFromDescriptor(NSAppleEventDescriptor *descriptor)
{
    if (descriptor == nil) {
        return nil;
    }

    DescType descriptorType = [descriptor descriptorType];
    if (descriptorType == typeSInt16 || descriptorType == typeSInt32 || descriptorType == typeUInt32) {
        return [NSNumber numberWithInt:[descriptor int32Value]];
    }

    if (descriptorType == typeIEEE32BitFloatingPoint
        || descriptorType == typeIEEE64BitFloatingPoint
        || descriptorType == typeSInt64) {
        return [NSNumber numberWithDouble:[descriptor doubleValue]];
    }

    NSString *stringValue = [descriptor stringValue];
    if ([stringValue length] == 0) {
        return nil;
    }

    NSScanner *scanner = [NSScanner scannerWithString:stringValue];
    double parsedValue = 0.0;
    if ([scanner scanDouble:&parsedValue] && [scanner isAtEnd]) {
        return [NSNumber numberWithDouble:parsedValue];
    }

    return nil;
}

NSString *UtilAEStringFromDescriptor(NSAppleEventDescriptor *descriptor)
{
    if (descriptor == nil) {
        return nil;
    }

    NSString *stringValue = [descriptor stringValue];
    if ([stringValue length] > 0) {
        return stringValue;
    }

    NSAppleEventDescriptor *unicodeText = [descriptor coerceToDescriptorType:typeUnicodeText];
    return [unicodeText stringValue];
}

NSArray *UtilAENumericListFromDescriptor(NSAppleEventDescriptor *descriptor, NSInteger expectedCount)
{
    if (descriptor == nil || expectedCount <= 0) {
        return nil;
    }

    NSAppleEventDescriptor *listDescriptor = descriptor;
    if ([listDescriptor descriptorType] != typeAEList) {
        listDescriptor = [descriptor coerceToDescriptorType:typeAEList];
    }
    if (listDescriptor == nil || [listDescriptor numberOfItems] < expectedCount) {
        return nil;
    }

    NSMutableArray *values = [NSMutableArray arrayWithCapacity:(NSUInteger)expectedCount];
    for (NSInteger index = 1; index <= expectedCount; index++) {
        NSAppleEventDescriptor *itemDescriptor = [listDescriptor descriptorAtIndex:index];
        NSNumber *numericValue = UtilAENumberFromDescriptor(itemDescriptor);
        if (numericValue == nil) {
            return nil;
        }
        [values addObject:numericValue];
    }

    return values;
}

NSString *UtilAEPathFromDescriptor(NSAppleEventDescriptor *descriptor)
{
    if (descriptor == nil) {
        return nil;
    }

    NSURL *fileURL = nil;
    if ([descriptor respondsToSelector:@selector(fileURLValue)]) {
        fileURL = [descriptor fileURLValue];
    }
    if ([fileURL isFileURL]) {
        return [[fileURL path] stringByStandardizingPath];
    }

    NSString *path = UtilAEStringFromDescriptor(descriptor);
    if ([path length] == 0) {
        return nil;
    }

    if ([path hasPrefix:@"file://"]) {
        NSURL *url = [NSURL URLWithString:path];
        if ([url isFileURL]) {
            return [[url path] stringByStandardizingPath];
        }
    }

    return [[path stringByExpandingTildeInPath] stringByStandardizingPath];
}

NSAppleEventDescriptor *UtilAEDescriptorListFromNumericArray(NSArray *values)
{
    if (![values isKindOfClass:[NSArray class]]) {
        return nil;
    }

    NSAppleEventDescriptor *listDescriptor = [NSAppleEventDescriptor listDescriptor];
    for (NSUInteger index = 0; index < [values count]; index++) {
        NSNumber *value = [values objectAtIndex:index];
        if (![value isKindOfClass:[NSNumber class]]) {
            continue;
        }

        [listDescriptor insertDescriptor:[NSAppleEventDescriptor descriptorWithDouble:[value doubleValue]]
                                 atIndex:(NSInteger)index + 1];
    }

    return listDescriptor;
}

NSAppleEventDescriptor *UtilAEJSONDescriptorForObject(id object)
{
    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:object options:0 error:&jsonError];
    if (jsonData == nil || jsonError != nil) {
        return [NSAppleEventDescriptor descriptorWithString:@"{}"];
    }

    NSString *jsonString = [[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] autorelease];
    if ([jsonString length] == 0) {
        jsonString = @"{}";
    }

    return [NSAppleEventDescriptor descriptorWithString:jsonString];
}

NSString *UtilAEFourCharCodeString(OSType fourCharCode)
{
    unsigned char chars[4];
    chars[0] = (unsigned char)((fourCharCode >> 24) & 0xff);
    chars[1] = (unsigned char)((fourCharCode >> 16) & 0xff);
    chars[2] = (unsigned char)((fourCharCode >> 8) & 0xff);
    chars[3] = (unsigned char)(fourCharCode & 0xff);

    NSString *stringValue = [[[NSString alloc] initWithBytes:chars
                                                       length:4
                                                     encoding:NSMacOSRomanStringEncoding] autorelease];
    if ([stringValue length] == 4) {
        return stringValue;
    }

    return [NSString stringWithFormat:@"%08X", (unsigned int)fourCharCode];
}

NSDictionary *UtilAEOperatorResultPayload(OSType eventClass,
                                          AEEventID eventID,
                                          id result)
{
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    [payload setObject:(result != nil ? result : [NSNull null]) forKey:@"result"];
    [payload setObject:[NSNumber numberWithBool:YES] forKey:@"ok"];
    [payload setObject:UtilAEOperatorResultSchemaVersion forKey:@"schemaVersion"];
    [payload setObject:UtilAEFourCharCodeString(eventClass) forKey:@"eventClass"];
    [payload setObject:UtilAEFourCharCodeString(eventID) forKey:@"eventID"];
    return payload;
}

NSDictionary *UtilAEOperatorErrorPayload(OSType eventClass,
                                         AEEventID eventID,
                                         NSString *code,
                                         NSString *message,
                                         SInt32 appleEventError)
{
    NSMutableDictionary *error = [NSMutableDictionary dictionary];
    [error setObject:([code length] > 0 ? code : @"appleEventError") forKey:@"code"];
    [error setObject:([message length] > 0 ? message : @"Apple Event failed.") forKey:@"message"];
    [error setObject:[NSNumber numberWithInt:appleEventError] forKey:@"appleEventError"];

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    [payload setObject:[NSNull null] forKey:@"result"];
    [payload setObject:[NSNumber numberWithBool:NO] forKey:@"ok"];
    [payload setObject:UtilAEOperatorResultSchemaVersion forKey:@"schemaVersion"];
    [payload setObject:UtilAEFourCharCodeString(eventClass) forKey:@"eventClass"];
    [payload setObject:UtilAEFourCharCodeString(eventID) forKey:@"eventID"];
    [payload setObject:error forKey:@"error"];
    return payload;
}

void UtilAEPopulateReplyError(NSAppleEventDescriptor *replyEvent,
                              SInt32 errorNumber,
                              NSString *message)
{
    if (replyEvent == nil) {
        return;
    }

    [replyEvent setParamDescriptor:[NSAppleEventDescriptor descriptorWithInt32:errorNumber]
                        forKeyword:keyErrorNumber];

    if ([message length] > 0) {
        [replyEvent setParamDescriptor:[NSAppleEventDescriptor descriptorWithString:message]
                            forKeyword:keyErrorString];
    }
}

void UtilAEPopulateReplyResult(NSAppleEventDescriptor *replyEvent,
                               NSAppleEventDescriptor *resultDescriptor)
{
    if (replyEvent == nil || resultDescriptor == nil) {
        return;
    }

    [replyEvent setParamDescriptor:resultDescriptor forKeyword:keyDirectObject];
}
