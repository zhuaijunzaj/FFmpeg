//
//  ZJAudioStreamer+Options.m
//  FFMPEG
//
//  Created by Kattern on 2017/7/25.
//  Copyright © 2017年 Kattern. All rights reserved.
//

#import "ZJAudioStreamer+Options.h"

NSString *const kZJAudioStreamerVolumeKey  = @"ZJAudioStreamerVolume";
const NSUInteger kZJAudioStreamerBufferTime = 200.0;

static ZJAudioStreamerOptions gOptions = ZJAudioStreamerDefaultOptions;
@implementation ZJAudioStreamer (Options)
+(ZJAudioStreamerOptions)options
{
    return gOptions;
}
+(void)setOptions:(ZJAudioStreamerOptions)options
{
    if (!!((gOptions ^ options) && ZJAudioStreamerKeepPersistentVolume) && !(options & ZJAudioStreamerKeepPersistentVolume)){
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kZJAudioStreamerVolumeKey];
    }
    gOptions = options;
}
@end
