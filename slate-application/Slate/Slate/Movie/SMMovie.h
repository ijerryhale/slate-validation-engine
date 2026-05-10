//
//  SMMovie.h
//  Slate
//
//  Created by Jerry Hale on 3/20/26.
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
#import <AVFoundation/AVFoundation.h>

typedef struct SMTime {
    long long timeValue;
    long timeScale;
    long flags;
    long long timeEpoch;
} SMTime;

typedef struct SMTimeRange {
    SMTime time;
    SMTime duration;
} SMTimeRange;

typedef void *Movie;
typedef void *Track;
typedef void *Media;
typedef void *UserData;

typedef struct TimeCodeTime {
    short hours;
    short minutes;
    short seconds;
    short frames;
} TimeCodeTime;

typedef struct TimeCodeDef {
    long flags;
} TimeCodeDef;

typedef struct TimeCodeRecord {
    TimeCodeTime t;
} TimeCodeRecord;

typedef int SMPropertyClass;
typedef int SMPropertyID;
typedef void (*SMMoviePropertyListenerUPP)(Movie movie, SMPropertyClass propertyClass, SMPropertyID propertyID, id observer);

typedef NS_ENUM(NSInteger, SMMovieOperationPhase) {
    SMMovieOperationBeginPhase = 0,
    SMMovieOperationUpdatePercentPhase = 1,
    SMMovieOperationEndPhase = 2
};

extern const SMTime SMZeroTime;

extern NSString * const SMMovieNaturalSizeAttribute;
extern NSString * const SMMovieDisplayNameAttribute;
extern NSString * const SMMovieLoadStateAttribute;
extern NSString * const SMMovieEditableAttribute;
extern NSString * const SMMovieFileNameAttribute;
extern NSString * const SMMovieOpenAsyncOKAttribute;
extern NSString * const SMMovieDontInteractWithUserAttribute;
extern NSString * const SMTrackMediaTypeAttribute;
extern NSString * const SMTrackIDAttribute;
extern NSString * const SMTrackDisplayNameAttribute;
extern NSString * const SMTrackFormatSummaryAttribute;
extern NSString * const SMTrackLanguageAttribute;

extern NSString * const SMMediaDurationAttribute;
extern NSString * const SMMediaSampleCountAttribute;
extern NSString * const SMMediaCharacteristicHasVideoFrameRate;

extern NSString * const SMMediaTypeVideo;
extern NSString * const SMMediaTypeSound;
extern NSString * const SMMediaTypeText;
extern NSString * const SMMediaTypeSubtitle;
extern NSString * const SMMediaTypeClosedCaption;
extern NSString * const SMMediaTypeTimeCode;

extern NSString * const SMMovieDidEndNotification;
extern NSInteger const SMMovieLoadStateComplete;
extern NSString * const SMMovieApertureModeClean;
extern NSString * const SMMovieApertureModeProduction;
extern NSString * const SMMovieApertureModeEncodedPixels;
SMTime SMMakeTime(long long timeValue, long timeScale);
SMTime SMMakeTimeWithTimeInterval(NSTimeInterval timeInterval);
SMTime SMMakeTimeScaled(SMTime time, long newScale);
SMTime SMTimeDecrement(SMTime lhs, SMTime rhs);
SMTimeRange SMMakeTimeRange(SMTime time, SMTime duration);
NSComparisonResult SMTimeCompare(SMTime lhs, SMTime rhs);
BOOL SMGetTimeInterval(SMTime time, NSTimeInterval *timeInterval);

@interface NSValue (SMTimeValue)
+ (NSValue *)valueWithSMTime:(SMTime)time;
- (SMTime)SMTimeValue;
@end

@interface SMMedia : NSObject
{
    AVAssetTrack *_assetTrack;
    NSMutableDictionary *_attributes;
    long _movieTimeScale;
}

- (instancetype)initWithAssetTrack:(AVAssetTrack *)assetTrack;
- (instancetype)initWithAssetTrack:(AVAssetTrack *)assetTrack movieTimeScale:(long)movieTimeScale;
- (instancetype)initWithAttributes:(NSDictionary *)attributes;
- (id)attributeForKey:(NSString *)key;
- (BOOL)hasCharacteristic:(NSString *)characteristic;
- (SMTime)mediaTime:(SMTime)time;
- (OSType)sampleFormatAtIndex:(long)sampleIndex;
@end

@class SMMovie;

@interface SMTrack : NSObject
{
    SMMovie *_movie;
    AVAssetTrack *_assetTrack;
    NSMutableDictionary *_attributes;
}

- (instancetype)initWithAssetTrack:(AVAssetTrack *)assetTrack movie:(SMMovie *)movie;
- (instancetype)initSyntheticTrackWithMovie:(SMMovie *)movie attributes:(NSDictionary *)attributes mediaAttributes:(NSDictionary *)mediaAttributes;
- (AVAssetTrack *)assetTrack;
- (SMMedia *)media;
- (id)attributeForKey:(NSString *)key;
- (void)setAttribute:(id)value forKey:(NSString *)key;
- (NSSize)apertureModeDimensionsForMode:(NSString *)mode;
- (NSArray *)videoInspectorDetailPairs;
- (SMMovie *)movie;
- (SMTime)timeRange;
- (SMTime)startTime;
- (BOOL)justOneSample:(SMTimeRange)range;
- (void)deleteSegment:(SMTimeRange)range;
- (void)insertSegmentOfTrack:(SMTrack *)srcTrack fromRange:(SMTimeRange)srcRange scaledToRange:(SMTimeRange)dstRange;
- (void)removeFromMovie;
- (long)trackID;
- (BOOL)isEnabled;
- (void)setEnabled:(BOOL)enabled;
- (BOOL)isMutedForPlayback;
- (void)setMutedForPlayback:(BOOL)muted;
- (float)audioGain;
- (void)setAudioGain:(float)audioGain;
- (NSTimeInterval)displayDurationSeconds;
- (NSString *)subtitleTextAtTime:(SMTime)time;
@end

@interface SMMovie : NSObject
{
    NSURL *_URL;
    AVMutableMovie *_movie;
    AVPlayerItem *_playerItem;
    AVPlayer *_player;
    NSMutableDictionary *_movieAttributes;
    NSMutableDictionary *_trackAttributes;
}

+ (SMMovie *)movie;
+ (SMMovie *)movieWithFile:(NSString *)file error:(NSError **)error;
+ (SMMovie *)movieWithAttributes:(NSDictionary *)attributes error:(NSError **)error;
- (instancetype)initWithURL:(NSURL *)url error:(NSError **)error;
- (AVPlayer *)player;
- (AVPlayerItem *)playerItem;
- (NSURL *)URL;
- (id)attributeForKey:(NSString *)key;
- (void)setMovieAttributes:(NSDictionary *)attributes;
- (NSArray *)tracks;
- (NSArray *)tracksOfMediaType:(NSString *)mediaType;
- (void)setCurrentTime:(SMTime)time;
- (void)setCurrentTime:(SMTime)time tolerance:(SMTime)tolerance;
- (SMTime)currentTime;
- (long long)currentTimeValue;
- (SMTime)duration;
- (long long)durationTimeValue;
- (TimeScale)timeScale;
- (void)setCurrentTimeValue:(long long)timeValue;
- (SMTime)startTime;
- (SMTimeRange)timeRange;
- (NSString *)timeCodeStringForTime:(SMTime)time;
- (NSString *)timeCodeStringForTimeValue:(long long)timeValue;
- (NSString *)currentTimeCodeString;
- (void)play;
- (void)stop;
- (void)stepForward;
- (void)stepBackward;
- (float)rate;
- (void)setRate:(float)rate;
- (float)volume;
- (void)setVolume:(float)volume;
- (float)audioGain;
- (void)setAudioGain:(float)audioGain;
- (SMTrack *)insertSegmentOfTrack:(SMTrack *)track timeRange:(SMTimeRange)range atTime:(SMTime)time;
- (void)gotoBeginning;
- (void)setEditable:(BOOL)editable;
- (void)removeTrack:(SMTrack *)track;
- (NSData *)coverArt;
- (NSImage *)currentFrameImage;
- (SMTrack *)trackByID:(long)tid;
@end

@interface SMMovie (PlaybackSupport)
- (void)addPlaybackReferenceAudioTrack:(SMTrack *)track;
- (NSArray *)addPlaybackReferenceAudioTracksFromURL:(NSURL *)url error:(NSError **)error;
@end

@interface SMMovie (ExportSupport)
- (BOOL)updateMovieFile;
- (BOOL)writeToFile:(NSString *)file withAttributes:(NSDictionary *)attributes error:(NSError **)error;
- (NSTask *)trailerExportTaskToURL:(NSURL *)url fileType:(AVFileType)fileType timeRange:(SMTimeRange)range error:(NSError **)error;
- (AVAssetExportSession *)exportSessionToURL:(NSURL *)url fileType:(AVFileType)fileType timeRange:(SMTimeRange)range error:(NSError **)error;
@end

@interface SMMovie (SubtitleSupport)
- (NSArray *)subtitleSidecarTracks;
- (BOOL)hasSubtitleSidecarTrackForSourceURL:(NSURL *)sourceURL;
- (SMTrack *)addSyntheticSidecarDisplayTextTrackWithItems:(NSArray *)displayItems langCode:(short)langCode mediaType:(NSString *)mediaType formatLabel:(NSString *)formatLabel sourceURL:(NSURL *)sourceURL;
- (SMTrack *)addSidecarITTSubtitleTrackFromURL:(NSURL *)url error:(NSError **)error;
- (SMTrack *)addSidecarSRTSubtitleTrackFromURL:(NSURL *)url error:(NSError **)error;
- (SMTrack *)addSidecarTTMLSubtitleTrackFromURL:(NSURL *)url error:(NSError **)error;
- (SMTrack *)addSidecarSCCSubtitleTrackFromURL:(NSURL *)url error:(NSError **)error;
@end

@interface SMMovie (FullLoad)
+ (SMMovie *)movieWithFullyLoadedFile:(NSString *)file;
@end

extern NSString *SMMediaSampleException;

@interface SMMedia (Sample)
- (NSData *)sampleAtTime:(SMTime)time;
- (NSString *)textSampleAtTime:(SMTime)time;
@end

extern NSString *SMMovieNoSuchFileException;
extern NSString *SMMovieInitException;
extern NSString *SMTrackInitException;

@interface SMMovie (ErrorException)
+ (SMMovie *)movieWithFile:(NSString *)file;
@end

@interface SMTrack (ErrorException)
@end

extern NSString *SMMediaSampleFormatException;

@interface SMMovie (EditingHidden)
- (void)setEditable:(BOOL)ed;
@end

@interface SMMovie (TrackID)
- (SMTrack *)trackByID:(long)tid;
@end

@interface SMTrack (TrackID)
- (long)trackID;
@end

@interface SMMovie (CoverArt)
- (NSData *)coverArt;
@end
