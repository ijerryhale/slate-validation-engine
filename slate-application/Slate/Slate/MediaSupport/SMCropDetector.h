//
//  SMCropDetector.h
//  Slate
//
//  Created by Jerry Hale on 3/22/26.
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
#import <AppKit/AppKit.h>

#import "SMCropGeometry.h"

typedef struct {
    SMCropMargins margins;
    CGFloat confidence;
    BOOL hasDetection;
} SMCropDetectionResult;

NS_INLINE SMCropDetectionResult SMCropDetectionResultMake(SMCropMargins margins,
                                                                CGFloat confidence,
                                                                BOOL hasDetection)
{
    SMCropDetectionResult result;
    result.margins = margins;
    result.confidence = confidence;
    result.hasDetection = hasDetection;
    return result;
}

@interface SMCropDetector : NSObject

+ (SMCropDetectionResult)conservativeBlackBorderDetectionForImages:(NSArray *)images
                                                          naturalSize:(CGSize)naturalSize;

+ (SMCropDetectionResult)conservativeBlackBorderDetectionForImages:(NSArray *)images
                                                          naturalSize:(CGSize)naturalSize
                                                       blackThreshold:(CGFloat)blackThreshold
                                                     minimumRunLength:(NSUInteger)minimumRunLength
                                                  minimumConsensusRatio:(CGFloat)minimumConsensusRatio;

@end

static const CGFloat SMCropDetectorDefaultBlackThreshold = 24.0f / 255.0f;
static const CGFloat SMCropDetectorDefaultConsensusRatio = 0.66f;
static const NSUInteger SMCropDetectorDefaultMinimumRunLength = 8;
static const NSInteger SMCropDetectorConsensusTolerance = 2;

NS_INLINE CGFloat SMCropDetectorPixelLuma(unsigned char *pixel)
{
    CGFloat red = pixel[0] / 255.0f;
    CGFloat green = pixel[1] / 255.0f;
    CGFloat blue = pixel[2] / 255.0f;
    return (0.2126f * red) + (0.7152f * green) + (0.0722f * blue);
}

NS_INLINE NSImage *SMCropDetectorResizedImage(NSImage *image, NSSize size)
{
    if (image == nil || size.width <= 0.0 || size.height <= 0.0) {
        return nil;
    }

    NSRect targetFrame = NSMakeRect(0.0, 0.0, size.width, size.height);
    NSImageRep *sourceImageRep = [image bestRepresentationForRect:targetFrame
                                                          context:nil
                                                            hints:nil];
    NSImage *targetImage = [[NSImage alloc] initWithSize:size];

    [targetImage lockFocus];
    if (sourceImageRep != nil) {
        [sourceImageRep drawInRect:targetFrame];
    } else {
        [image drawInRect:targetFrame
                 fromRect:NSZeroRect
                operation:NSCompositeSourceOver
                 fraction:1.0];
    }
    [targetImage unlockFocus];

    return [targetImage autorelease];
}

NS_INLINE NSBitmapImageRep *SMCropDetectorBitmapRepresentationForImage(NSImage *image, CGSize naturalSize)
{
    if (image == nil || naturalSize.width <= 0.0 || naturalSize.height <= 0.0) {
        return nil;
    }

    NSSize targetSize = NSMakeSize(naturalSize.width, naturalSize.height);
    NSImage *normalizedImage = SMCropDetectorResizedImage(image, targetSize);
    NSData *tiffData = [normalizedImage TIFFRepresentation];
    if (tiffData == nil) {
        return nil;
    }

    NSBitmapImageRep *bitmap = [[[NSBitmapImageRep alloc] initWithData:tiffData] autorelease];
    if (bitmap == nil || [bitmap bitsPerPixel] < 24 || [bitmap bitmapData] == NULL) {
        return nil;
    }

    return bitmap;
}

NS_INLINE NSUInteger SMCropDetectorEdgeInsetForBitmap(NSBitmapImageRep *bitmap,
                                                         BOOL horizontal,
                                                         BOOL fromMaxEdge,
                                                         CGFloat blackThreshold,
                                                         NSUInteger minimumRunLength)
{
    if (bitmap == nil) {
        return 0;
    }

    NSUInteger width = (NSUInteger)[bitmap pixelsWide];
    NSUInteger height = (NSUInteger)[bitmap pixelsHigh];
    NSUInteger bytesPerRow = (NSUInteger)[bitmap bytesPerRow];
    unsigned char *data = [bitmap bitmapData];
    if (width == 0 || height == 0 || bytesPerRow == 0 || data == NULL) {
        return 0;
    }

    NSUInteger lineCount = horizontal ? height : width;
    NSUInteger scanLimit = lineCount / 3;
    NSUInteger darkLineCount = 0;

    for (NSUInteger offset = 0; offset < scanLimit; offset++) {
        NSUInteger lineIndex = fromMaxEdge ? (lineCount - offset - 1) : offset;
        NSUInteger darkRunLength = 0;
        NSUInteger sampleCount = horizontal ? width : height;

        for (NSUInteger sampleIndex = 0; sampleIndex < sampleCount; sampleIndex++) {
            NSUInteger x = horizontal ? sampleIndex : lineIndex;
            NSUInteger y = horizontal ? lineIndex : sampleIndex;
            unsigned char *pixel = data + (y * bytesPerRow) + (x * 4);

            if (SMCropDetectorPixelLuma(pixel) <= blackThreshold) {
                darkRunLength++;
                if (darkRunLength >= minimumRunLength) {
                    break;
                }
            } else {
                darkRunLength = 0;
            }
        }

        if (darkRunLength < minimumRunLength) {
            break;
        }

        darkLineCount++;
    }

    return darkLineCount;
}

NS_INLINE SMCropMargins SMCropDetectorMarginsForImage(NSImage *image,
                                                            CGSize naturalSize,
                                                            CGFloat blackThreshold,
                                                            NSUInteger minimumRunLength)
{
    NSBitmapImageRep *bitmap = SMCropDetectorBitmapRepresentationForImage(image, naturalSize);
    if (bitmap == nil) {
        return SMCropMarginsZero();
    }

    SMCropMargins margins = SMCropMarginsMake(
        (CGFloat)SMCropDetectorEdgeInsetForBitmap(bitmap, NO, NO, blackThreshold, minimumRunLength),
        (CGFloat)SMCropDetectorEdgeInsetForBitmap(bitmap, YES, NO, blackThreshold, minimumRunLength),
        (CGFloat)SMCropDetectorEdgeInsetForBitmap(bitmap, NO, YES, blackThreshold, minimumRunLength),
        (CGFloat)SMCropDetectorEdgeInsetForBitmap(bitmap, YES, YES, blackThreshold, minimumRunLength));

    return SMCropMarginsClamp(margins, naturalSize);
}

NS_INLINE BOOL SMCropDetectorEdgeAgrees(NSInteger value, NSInteger pivot)
{
    return llabs((long long)value - (long long)pivot) <= SMCropDetectorConsensusTolerance;
}

NS_INLINE NSInteger SMCropDetectorMedianValue(NSArray *values)
{
    if ([values count] == 0) {
        return 0;
    }

    NSArray *sortedValues = [values sortedArrayUsingSelector:@selector(compare:)];
    return [[sortedValues objectAtIndex:([sortedValues count] / 2)] integerValue];
}

NS_INLINE NSInteger SMCropDetectorConservativeValue(NSArray *values, CGFloat minimumConsensusRatio, CGFloat *edgeConfidence)
{
    NSInteger pivot = SMCropDetectorMedianValue(values);
    NSMutableArray *agreeingValues = [NSMutableArray array];

    for (NSNumber *value in values) {
        if (SMCropDetectorEdgeAgrees([value integerValue], pivot)) {
            [agreeingValues addObject:value];
        }
    }

    CGFloat confidence = ([values count] > 0) ? ((CGFloat)[agreeingValues count] / (CGFloat)[values count]) : 0.0f;
    if (edgeConfidence != NULL) {
        *edgeConfidence = confidence;
    }

    if (confidence < minimumConsensusRatio || [agreeingValues count] == 0) {
        return 0;
    }

    NSInteger conservativeValue = NSIntegerMax;
    for (NSNumber *value in agreeingValues) {
        conservativeValue = MIN(conservativeValue, [value integerValue]);
    }

    return (conservativeValue == NSIntegerMax) ? 0 : conservativeValue;
}

NS_INLINE SMCropDetectionResult SMCropDetectorConservativeBlackBorderDetectionForImages(NSArray *images,
                                                                                               CGSize naturalSize,
                                                                                               CGFloat blackThreshold,
                                                                                               NSUInteger minimumRunLength,
                                                                                               CGFloat minimumConsensusRatio)
{
    if ([images count] == 0 || naturalSize.width <= 0.0 || naturalSize.height <= 0.0) {
        return SMCropDetectionResultMake(SMCropMarginsZero(), 0.0f, NO);
    }

    NSMutableArray *leftValues = [NSMutableArray array];
    NSMutableArray *topValues = [NSMutableArray array];
    NSMutableArray *rightValues = [NSMutableArray array];
    NSMutableArray *bottomValues = [NSMutableArray array];

    for (NSImage *image in images) {
        SMCropMargins margins = SMCropDetectorMarginsForImage(image, naturalSize, blackThreshold, minimumRunLength);
        [leftValues addObject:[NSNumber numberWithInteger:(NSInteger)llround(margins.left)]];
        [topValues addObject:[NSNumber numberWithInteger:(NSInteger)llround(margins.top)]];
        [rightValues addObject:[NSNumber numberWithInteger:(NSInteger)llround(margins.right)]];
        [bottomValues addObject:[NSNumber numberWithInteger:(NSInteger)llround(margins.bottom)]];
    }

    CGFloat leftConfidence = 0.0f;
    CGFloat topConfidence = 0.0f;
    CGFloat rightConfidence = 0.0f;
    CGFloat bottomConfidence = 0.0f;

    SMCropMargins conservativeMargins = SMCropMarginsMake(
        (CGFloat)SMCropDetectorConservativeValue(leftValues, minimumConsensusRatio, &leftConfidence),
        (CGFloat)SMCropDetectorConservativeValue(topValues, minimumConsensusRatio, &topConfidence),
        (CGFloat)SMCropDetectorConservativeValue(rightValues, minimumConsensusRatio, &rightConfidence),
        (CGFloat)SMCropDetectorConservativeValue(bottomValues, minimumConsensusRatio, &bottomConfidence));

    conservativeMargins = SMCropMarginsSnapToEven(conservativeMargins, naturalSize);

    CGFloat confidence = MIN(MIN(leftConfidence, topConfidence), MIN(rightConfidence, bottomConfidence));
    BOOL hasDetection = confidence >= minimumConsensusRatio
        && !SMCropMarginsEqualToMargins(conservativeMargins, SMCropMarginsZero());

    return SMCropDetectionResultMake(conservativeMargins, confidence, hasDetection);
}

NS_INLINE SMCropDetectionResult SMCropDetectorConservativeBlackBorderDetectionForImagesDefault(NSArray *images,
                                                                                                      CGSize naturalSize)
{
    return SMCropDetectorConservativeBlackBorderDetectionForImages(images,
                                                                      naturalSize,
                                                                      SMCropDetectorDefaultBlackThreshold,
                                                                      SMCropDetectorDefaultMinimumRunLength,
                                                                      SMCropDetectorDefaultConsensusRatio);
}
