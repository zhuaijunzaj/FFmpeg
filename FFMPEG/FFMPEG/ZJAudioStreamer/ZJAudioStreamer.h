//
//  ZJAudioStreamer.h
//  FFMPEG
//
//  Created by Kattern on 2017/7/25.
//  Copyright © 2017年 Kattern. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZJAudioBase.h"
#import "ZJAudioFile.h"
#import "ZJAudioFileProcessor.h"
#import "ZJAudioAnalyzer+Default.h"

ZJAudio_EXTERN NSString *const kZJAudioStreamerErrorDomain;
typedef NS_ENUM(NSUInteger, ZJAudioStreamerStatus){
    ZJAudioStreamerPlaying,
    ZJAudioStreamerPaused,
    ZJAudioStreamerIdle,
    ZJAudioStreamerFinished,
    ZJAudioStreamerBuffering,
    ZJAudioStreamerError
} ;
typedef NS_ENUM(NSInteger,ZJAudioStreamerErrocode){
    ZJAudioStreamerNetworkError,
    ZJAudioStreamerDecoingError
};
@interface ZJAudioStreamer : NSObject

@property (nonatomic, assign, readonly) ZJAudioStreamerStatus status;
@property (nonatomic, strong, readonly) NSError *error;
@property (nonatomic, readonly) id<ZJAudioFile>  audioFile;
@property (nonatomic, strong, readonly) NSURL *url;
@property (nonatomic, assign, readonly) NSTimeInterval duration;
@property (nonatomic, assign) NSTimeInterval currentTime;
@property (nonatomic, assign) double volume;
@property (nonatomic, copy) NSArray *analyzers;
@property (nonatomic, strong, readonly) NSString *cachedPath;
@property (nonatomic, strong, readonly) NSURL *cachedURL;
@property (nonatomic, strong, readonly) NSString *sha256;
@property (nonatomic, assign, readonly) NSUInteger expectedLength;
@property (nonatomic, readonly) NSUInteger receivedLength;
@property (nonatomic, readonly) NSUInteger downloadSpeed;
@property (nonatomic, assign, readonly) double bufferingRatio;

+(instancetype)streamerWithAudioFie:(id<ZJAudioFile>)audioFile;
-(instancetype)initWithAuidoFile:(id<ZJAudioFile>)audioFile;
+(double)volume;
+(void)setVolume:(double)volume;
+(NSArray*)analyzers;
+(void)setAnalyzers:(NSArray*)analyzers;
+(void)setHintWithAudioFile:(id<ZJAudioFile>)audioFile;

-(void)play;
-(void)pause;
-(void)stop;
@end
