//
//  ZJAudioDecoder.h
//  FFMPEG
//
//  Created by Kattern on 2017/7/22.
//  Copyright © 2017年 Kattern. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudioTypes.h>

typedef NS_ENUM(NSUInteger,ZJAudioDecoderStatus) {
    ZJAudioDecoderSucceeded,
    ZJAudioDecoderFailed,
    ZJAudioDecoderEndEncountered,
    ZJAudioDecoderWaiting
};

@class ZJAudioPlaybackItem;
@class ZJAudioPCM;

@interface ZJAudioDecoder : NSObject

@property (nonatomic, strong, readonly) ZJAudioPlaybackItem *playbackItem;
@property (nonatomic, strong, readonly) ZJAudioPCM *lpcm;
+(AudioStreamBasicDescription) defaultOutputFormat;
+(instancetype)decoderWithPlaybackItem:(ZJAudioPlaybackItem*)playbackItem
                            bufferSize:(NSUInteger)bufferSize;
-(instancetype)initWithPlaybackItem:(ZJAudioPlaybackItem*)playbackItem
                         bufferSize:(NSUInteger)bufferSize;
-(BOOL)setUp;
-(void)tearDown;

- (ZJAudioDecoderStatus)decodeOnce;
- (void)seekToTime:(NSUInteger)milliseconds;
@end
