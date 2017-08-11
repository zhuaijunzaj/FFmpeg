//
//  ZJAudioStreamer+Options.h
//  FFMPEG
//
//  Created by Kattern on 2017/7/25.
//  Copyright © 2017年 Kattern. All rights reserved.
//

#import "ZJAudioStreamer.h"
ZJAudio_EXTERN NSString *const kZJAudioStreamerVolumeKey;
ZJAudio_EXTERN const NSUInteger kZJAudioStreamerBufferTime;

typedef NS_OPTIONS(NSUInteger, ZJAudioStreamerOptions) {
    ZJAudioStreamerKeepPersistentVolume = 1 <<0,
    ZJAudioStreamerRemoveCacheOnDeallocation = 1<< 1,
    ZJAudioStreamerRequireSHA256 = 1 <<2,
    ZJAudioStreamerDefaultOptions = ZJAudioStreamerKeepPersistentVolume | ZJAudioStreamerRemoveCacheOnDeallocation
};
@interface ZJAudioStreamer (Options)
+(ZJAudioStreamerOptions)options;
+(void)setOptions:(ZJAudioStreamerOptions)options;
@end
