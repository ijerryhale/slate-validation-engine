// Read-only audio layout queries used by the public Slate app adapter.

#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

@class SMTrack;

NSString *SMAudioChannelSummaryFromTrack(AVAssetTrack *track);

// Returns a caller-owned AudioChannelLayout buffer when successful.
OSStatus SMCopyTrackAudioLayout(SMTrack *track,
                                UInt32 *outLayoutSize,
                                AudioChannelLayout **outLayout);
