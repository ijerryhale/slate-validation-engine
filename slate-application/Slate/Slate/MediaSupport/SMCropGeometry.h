//
//  SMCropGeometry.h
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
#import <CoreGraphics/CoreGraphics.h>

typedef struct {
    CGFloat left;
    CGFloat top;
    CGFloat right;
    CGFloat bottom;
} SMCropMargins;

NS_INLINE SMCropMargins SMCropMarginsMake(CGFloat left, CGFloat top, CGFloat right, CGFloat bottom)
{
    SMCropMargins margins;
    margins.left = left;
    margins.top = top;
    margins.right = right;
    margins.bottom = bottom;
    return margins;
}

NS_INLINE CGFloat SMCropClamp(CGFloat value, CGFloat minimum, CGFloat maximum)
{
    return MIN(MAX(value, minimum), maximum);
}

NS_INLINE CGFloat SMCropRoundedEvenValue(CGFloat value)
{
    NSInteger roundedValue = (NSInteger)llround(value);
    if ((roundedValue % 2) != 0) {
        roundedValue += (roundedValue < 0 ? -1 : 1);
    }
    return (CGFloat)roundedValue;
}

NS_INLINE SMCropMargins SMCropMarginsZero(void)
{
    return SMCropMarginsMake(0.0, 0.0, 0.0, 0.0);
}

NS_INLINE SMCropMargins SMCropMarginsClamp(SMCropMargins margins, CGSize naturalSize)
{
    SMCropMargins clampedMargins = margins;

    clampedMargins.left = SMCropClamp(clampedMargins.left, 0.0, naturalSize.width);
    clampedMargins.right = SMCropClamp(clampedMargins.right, 0.0, naturalSize.width);
    clampedMargins.top = SMCropClamp(clampedMargins.top, 0.0, naturalSize.height);
    clampedMargins.bottom = SMCropClamp(clampedMargins.bottom, 0.0, naturalSize.height);

    CGFloat horizontalOverflow = (clampedMargins.left + clampedMargins.right) - naturalSize.width;
    if (horizontalOverflow > 0.0) {
        CGFloat adjustment = ceil(horizontalOverflow / 2.0);
        clampedMargins.left = SMCropClamp(clampedMargins.left - adjustment, 0.0, naturalSize.width);
        clampedMargins.right = SMCropClamp(clampedMargins.right - adjustment, 0.0, naturalSize.width);
    }

    CGFloat verticalOverflow = (clampedMargins.top + clampedMargins.bottom) - naturalSize.height;
    if (verticalOverflow > 0.0) {
        CGFloat adjustment = ceil(verticalOverflow / 2.0);
        clampedMargins.top = SMCropClamp(clampedMargins.top - adjustment, 0.0, naturalSize.height);
        clampedMargins.bottom = SMCropClamp(clampedMargins.bottom - adjustment, 0.0, naturalSize.height);
    }

    return clampedMargins;
}

NS_INLINE SMCropMargins SMCropMarginsSnapToEven(SMCropMargins margins, CGSize naturalSize)
{
    SMCropMargins evenMargins = SMCropMarginsMake(SMCropRoundedEvenValue(margins.left),
                                                        SMCropRoundedEvenValue(margins.top),
                                                        SMCropRoundedEvenValue(margins.right),
                                                        SMCropRoundedEvenValue(margins.bottom));
    return SMCropMarginsClamp(evenMargins, naturalSize);
}

NS_INLINE SMCropMargins SMCropMarginsFromOverlayRect(CGRect overlayRect,
                                                           CGRect displayedMovieRect,
                                                           CGSize naturalSize)
{
    if (CGRectIsEmpty(displayedMovieRect) || naturalSize.width <= 0.0 || naturalSize.height <= 0.0) {
        return SMCropMarginsZero();
    }

    CGFloat scaleX = naturalSize.width / CGRectGetWidth(displayedMovieRect);
    CGFloat scaleY = naturalSize.height / CGRectGetHeight(displayedMovieRect);

    CGFloat left = (CGRectGetMinX(overlayRect) - CGRectGetMinX(displayedMovieRect)) * scaleX;
    CGFloat top = (CGRectGetMinY(overlayRect) - CGRectGetMinY(displayedMovieRect)) * scaleY;
    CGFloat right = (CGRectGetMaxX(displayedMovieRect) - CGRectGetMaxX(overlayRect)) * scaleX;
    CGFloat bottom = (CGRectGetMaxY(displayedMovieRect) - CGRectGetMaxY(overlayRect)) * scaleY;

    SMCropMargins margins = SMCropMarginsMake(left, top, right, bottom);
    return SMCropMarginsClamp(margins, naturalSize);
}

NS_INLINE CGRect SMCropRectFromMargins(SMCropMargins margins, CGSize naturalSize)
{
    SMCropMargins clampedMargins = SMCropMarginsClamp(margins, naturalSize);

    CGFloat width = MAX(0.0, naturalSize.width - clampedMargins.left - clampedMargins.right);
    CGFloat height = MAX(0.0, naturalSize.height - clampedMargins.top - clampedMargins.bottom);

    return CGRectMake(clampedMargins.left, clampedMargins.top, width, height);
}

NS_INLINE BOOL SMCropMarginsEqualToMargins(SMCropMargins lhs, SMCropMargins rhs)
{
    return (lhs.left == rhs.left
            && lhs.top == rhs.top
            && lhs.right == rhs.right
            && lhs.bottom == rhs.bottom);
}
