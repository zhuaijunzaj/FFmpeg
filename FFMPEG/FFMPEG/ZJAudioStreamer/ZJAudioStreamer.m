//
//  ZJAudioStreamer.m
//  FFMPEG
//
//  Created by Kattern on 2017/7/25.
//  Copyright © 2017年 Kattern. All rights reserved.
//

#import "ZJAudioStreamer.h"
#import "ZJAudioStreamer_Private.h"
#import "ZJAudioFileProvider.h"
#import "ZJAudioEventLoop.h"

NSString *const kZJAudioStreamerErrorDomain = @"com.zj.audio-streamer.error-domain";

@interface ZJAudioStreamer ( )
{
    id<ZJAudioFile> _audioFile;
    ZJAudioStreamerStatus _status;
    NSError *_error;
    NSTimeInterval _duration;
    NSInteger _timingOffset;
    
    ZJAudioFileProvider *_fileProvider;
    ZJAudioPlaybackItem *_playbackItem;
    ZJAudioDecoder *_decoder;
    double _bufferingRatio;
    
    BOOL _pausedByInterruption;
}
@end
@implementation ZJAudioStreamer
@synthesize status = _status;
@synthesize error = _error;

@synthesize duration = _duration;
@synthesize timingOffset = _timingOffset;

@synthesize fileProvider = _fileProvider;
@synthesize playbackItem = _playbackItem;
@synthesize decoder = _decoder;

@synthesize bufferingRatio = _bufferingRatio;
@synthesize pausedByInterruption = _pausedByInterruption;

+(instancetype)streamerWithAudioFie:(id<ZJAudioFile>)audioFile
{
    return [[[self class] alloc] initWithAuidoFile:audioFile];
}
-(instancetype)initWithAuidoFile:(id<ZJAudioFile>)audioFile
{
    self = [super init];
    if (self){
        _audioFile = audioFile;
        _status = ZJAudioStreamerIdle;
        _fileProvider = [ZJAudioFileProvider fileProviderWithAudioFile:audioFile];
        if (_fileProvider == nil) return nil;
        _bufferingRatio =(double)[_fileProvider receivedLength] / [_fileProvider expectedLength];
    }
    return self;
}
+(double)volume
{
    return [[ZJAudioEventLoop sharedEventLoop] volume];
}
+(void)setVolume:(double)volume
{
    [[ZJAudioEventLoop sharedEventLoop] setVolume:volume];
}
+(NSArray*)analyzers
{
    return [[ZJAudioEventLoop sharedEventLoop] analyzers];
}
+(void)setAnalyzers:(NSArray *)analyzers
{
    [[ZJAudioEventLoop sharedEventLoop] setAnalyzers:analyzers];
}
+(void)setHintWithAudioFile:(id<ZJAudioFile>)audioFile
{
    [ZJAudioFileProvider setHintWithAudioFile:audioFile];
}
-(id<ZJAudioFile>)audioFile
{
    return _audioFile;
}
-(NSURL*)url
{
    return [_audioFile audioFileURL];
}
-(NSTimeInterval)currentTime
{
    if ([[ZJAudioEventLoop sharedEventLoop] currentStreamer] != self){
        return 0.0;
    }
    return [[ZJAudioEventLoop sharedEventLoop] currentTime];
}
-(void)setCurrentTime:(NSTimeInterval)currentTime
{
    if ([[ZJAudioEventLoop sharedEventLoop] currentStreamer] != self){
        return ;
    }
    [[ZJAudioEventLoop sharedEventLoop] setCurrentTime:currentTime];
}
-(double)volume
{
    return [[self class] volume];
}
-(void)setVolume:(double)volume
{
    [[self class] setVolume:volume];
}
-(NSArray*)analyzers
{
    return [[self class] analyzers];
}
-(void)setAnalyzers:(NSArray *)analyzers
{
    [[self class] setAnalyzers:analyzers];
}
-(NSString*)cachedPath
{
    return [_fileProvider cachedPath];
}
-(NSURL*)cachedURL
{
    return [_fileProvider cachedURL];
}
-(NSString*)sha256
{
    return [_fileProvider sha256];
}
-(NSUInteger)expectedLength
{
    return [_fileProvider expectedLength];
}
-(NSUInteger)receivedLength
{
    return [_fileProvider receivedLength];
}
-(NSUInteger)downloadSpeed
{
    return [_fileProvider downloadSpeed];
}
-(void)play
{
    @synchronized (self) {
        if (_status != ZJAudioStreamerPaused && _status != ZJAudioStreamerIdle && _status != ZJAudioStreamerFinished){
            return;
        }
        if ([[ZJAudioEventLoop sharedEventLoop] currentStreamer] != self){
            [[ZJAudioEventLoop sharedEventLoop] pause];
            [[ZJAudioEventLoop sharedEventLoop] setCurrentStreamer:self];
        }
        [[ZJAudioEventLoop sharedEventLoop] play];
    }
}
-(void)pause
{
    @synchronized (self) {
        if (_status != ZJAudioStreamerPaused && _status != ZJAudioStreamerIdle && _status != ZJAudioStreamerFinished){
            return;
        }
        if ([[ZJAudioEventLoop sharedEventLoop] currentStreamer] != self){
            return;
        }
        [[ZJAudioEventLoop sharedEventLoop] pause];
    }
}
-(void)stop
{
    @synchronized (self) {
        if ( _status != ZJAudioStreamerIdle ){
            return;
        }
        if ([[ZJAudioEventLoop sharedEventLoop] currentStreamer] != self){
            return;
        }
        [[ZJAudioEventLoop sharedEventLoop] stop];
        [[ZJAudioEventLoop sharedEventLoop] setCurrentStreamer:nil];
        
    }
}
@end






















































