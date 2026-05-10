//
//  AppController+Crop.m
//  Slate
//

#import "AppController+Crop.h"
#import "AppController+Status.h"

#import "DictionaryKeys.h"
#import "PlayerView.h"
#import "Runtime/SlatePackageContextContract.h"

static CGRect SMOverlayRectFromSourceMargins(SMCropMargins margins, CGRect displayedMovieRect, CGSize naturalSize)
{
    if (CGRectIsEmpty(displayedMovieRect) || naturalSize.width <= 0.0 || naturalSize.height <= 0.0) {
        return displayedMovieRect;
    }

    SMCropMargins clampedMargins = SMCropMarginsClamp(margins, naturalSize);
    CGFloat scaleX = CGRectGetWidth(displayedMovieRect) / naturalSize.width;
    CGFloat scaleY = CGRectGetHeight(displayedMovieRect) / naturalSize.height;

    return CGRectMake(CGRectGetMinX(displayedMovieRect) + (clampedMargins.left * scaleX),
                      CGRectGetMinY(displayedMovieRect) + (clampedMargins.top * scaleY),
                      MAX(0.0, CGRectGetWidth(displayedMovieRect) - ((clampedMargins.left + clampedMargins.right) * scaleX)),
                      MAX(0.0, CGRectGetHeight(displayedMovieRect) - ((clampedMargins.top + clampedMargins.bottom) * scaleY)));
}

@implementation AppController (Crop)

- (SMCropMargins)currentOverlayCropMargins
{
    if (_playerView.cropLayer) {
        return SMCropMarginsSnapToEven([_playerView sourceCropMarginsFromOverlay], NSSizeToCGSize([[[appcontroller() movie] attributeForKey:SMMovieNaturalSizeAttribute] sizeValue]));
    }

    return SMCropMarginsZero();
}

- (void)restoreCropOverlayFromPackageContextIfPossible:(NSDictionary *)packageContext
{
    NSDictionary *primaryAVAsset = [packageContext objectForKey:SlatePackageContextKeyPrimaryAsset];
    if (![primaryAVAsset isKindOfClass:[NSDictionary class]]) {
        return;
    }

    SMCropMargins margins = SMCropMarginsMake([[primaryAVAsset objectForKey:SlatePackageContextPrimaryAssetKeyCropLeft] floatValue],
                                              [[primaryAVAsset objectForKey:SlatePackageContextPrimaryAssetKeyCropTop] floatValue],
                                              [[primaryAVAsset objectForKey:SlatePackageContextPrimaryAssetKeyCropRight] floatValue],
                                              [[primaryAVAsset objectForKey:SlatePackageContextPrimaryAssetKeyCropBottom] floatValue]);
    margins = SMCropMarginsClamp(margins, NSSizeToCGSize([[[appcontroller() movie] attributeForKey:SMMovieNaturalSizeAttribute] sizeValue]));

    BOOL hasCrop = !SMCropMarginsEqualToMargins(margins, SMCropMarginsZero());
    if (!hasCrop) {
        if (_playerView.cropLayer) {
            [_playerView deleteCropRect];
            [_playerView.crop setState:0];
        }
        [self refreshCropValues:nil];
        return;
    }

    if (!_playerView.cropLayer) {
        [_playerView createCropRect];
    }

    CGRect overlayRect = SMOverlayRectFromSourceMargins(margins,
                                                        NSRectToCGRect(_playerView.movieBounds),
                                                        NSSizeToCGSize([[[appcontroller() movie] attributeForKey:SMMovieNaturalSizeAttribute] sizeValue]));
    [_playerView setCropRect:overlayRect];
    [_playerView.cropLayer setNeedsDisplay];
    [_playerView.crop setState:1];
    [self refreshCropValues:nil];
}

- (IBAction)grabChapterCropRect:(id)sender
{
    #pragma unused (sender)

    [_window endEditingFor:nil];
    [_window makeFirstResponder:_playerView];

    SMCropMargins margins = [self currentOverlayCropMargins];
    [self showChapterCropRectStatusWithTop:margins.top
                                      left:margins.left
                                    bottom:margins.bottom
                                     right:margins.right
                                   context:@"Chapter crop rect set"
                                    suffix:nil
                                   persist:NO];
}

- (void)refreshCropValues:(NSNotification *)notif
{
    #pragma unused (notif)
    if (_playerView.cropLayer)
    {
        SMCropMargins margins = [_playerView sourceCropMarginsFromOverlay];

        [_rawCropLeft setStringValue:[NSString stringWithFormat:@"%.0f", margins.left]];
        [_rawCropTop setStringValue:[NSString stringWithFormat:@"%.0f", margins.top]];
        [_rawCropRght setStringValue:[NSString stringWithFormat:@"%.0f", margins.right]];
        [_rawCropBtm setStringValue:[NSString stringWithFormat:@"%.0f", margins.bottom]];
    }
    else
    {
        [_rawCropLeft setStringValue:@"0"];
        [_rawCropTop setStringValue:@"0"];
        [_rawCropRght setStringValue:@"0"];
        [_rawCropBtm setStringValue:@"0"];
    }
}

@end
