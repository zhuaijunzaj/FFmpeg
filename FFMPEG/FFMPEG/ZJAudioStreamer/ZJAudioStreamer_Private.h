//
//  ZJAudioStreamer_Private.h
//  FFMPEG
//
//  Created by Kattern on 2017/7/25.
//  Copyright © 2017年 Kattern. All rights reserved.
//

#import "ZJAudioStreamer.h"

@class ZJAudioFileProvider;
@class ZJAudioPlaybackItem;
@class ZJAudioDecoder;

@interface ZJAudioStreamer ()
@property (nonatomic, assign) ZJAudioStreamerStatus status;
@property (nonatomic, strong) NSError *error;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, assign) NSInteger timingOffset;

@property (nonatomic, readonly) ZJAudioFileProvider *fileProvider;
@property (nonatomic, strong) ZJAudioPlaybackItem *playbackItem;
@property (nonatomic, strong) ZJAudioDecoder *decoder;

@property (nonatomic, assign) double bufferingRatio;

#if TARGET_OS_IPHONE
@property (nonatomic, assign, getter=isPausedByInterruption) BOOL pausedByInterruption;
#endif /* TARGET_OS_IPHONE */
@end
