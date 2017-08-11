//
//  ZJAudioEventLoop.m
//  FFMPEG
//
//  Created by Kattern on 2017/7/25.
//  Copyright © 2017年 Kattern. All rights reserved.
//

#import "ZJAudioEventLoop.h"
#import "ZJAudioStreamer.h"
#import "ZJAudioStreamer_Private.h"
#import "ZJAudioStreamer+Options.h"
#import "ZJAudioFileProvider.h"
#import "ZJAudioPlaybackItem.h"
#import "ZJAudioPCM.h"
#import "ZJAudioDecoder.h"
#import "ZJAudioRender.h"
#include <sys/types.h>
#include <sys/event.h>
#include <sys/time.h>
#include <pthread.h>
#include <sched.h>

typedef NS_ENUM(uint64_t,event_type){
    event_play,
    event_pause,
    event_stop,
    event_seek,
    event_streamer_changed,
    event_provider_events,
    event_finalizing,
    event_interruption_begin,
    event_interruption_end,
    event_old_device_unavailable,
    event_first = event_play,
    event_last = event_old_device_unavailable,
    event_timeout
};
@interface ZJAudioEventLoop ()
{
    ZJAudioRender *_render;
    ZJAudioStreamer *_currentStreamer;
    
    NSUInteger _decoderBufferSize;
    ZJAudioFileProviderEventBlock _fileProviderBlock;
    
    int _kq;
    void *_lastKQUserData;
    pthread_mutex_t _mutex;
    pthread_t _thread;
}

@end
@implementation ZJAudioEventLoop
@synthesize currentStreamer = _currentStreamer;
@dynamic analyzers;

+(instancetype)sharedEventLoop
{
    static ZJAudioEventLoop *sharedEventLoop = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedEventLoop = [[ZJAudioEventLoop alloc] init];
    });
    return sharedEventLoop;
}
-(instancetype)init
{
    self = [super init];
    if (self){
        _kq = kqueue();
        pthread_mutex_init(&_mutex, NULL);
        
        [self _setupAudioSession];
        _render  = [ZJAudioRender renderWithBufferTime:kZJAudioStreamerBufferTime];
        [_render setUp];
        
        if ([[NSUserDefaults standardUserDefaults] objectForKey:kZJAudioStreamerVolumeKey] != nil){
            [self setVolume:[[NSUserDefaults standardUserDefaults] doubleForKey:kZJAudioStreamerVolumeKey]];
        }else{
            [self setVolume:1.0];
        }
        _decoderBufferSize = [[self class] _decoderBufferSize];
        
        [self _setupFileProviderEventBlock];
        [self _enableEvents];
        [self _createThread];
    }
    return self;
}
-(void)dealloc
{
    [self _sendEvent:event_finalizing];
    pthread_join(_thread, NULL);
    close(_kq);
    pthread_mutex_destroy(&_mutex);
}
+(NSUInteger)_decoderBufferSize
{
    AudioStreamBasicDescription format = [ZJAudioDecoder defaultOutputFormat];
    return kZJAudioStreamerBufferTime * format.mSampleRate * format.mChannelsPerFrame * format.mBitsPerChannel /8 /1000;
}
-(void)_handleAuidoSessionInterruptionWithState:(UInt32)state
{
    if (state == kAudioSessionBeginInterruption){
        [_render setInterrupted:YES];
        [_render stop];
    }else if (state == kAudioSessionEndInterruption){
        AudioSessionInterruptionType interruptionType = kAudioSessionInterruptionType_ShouldNotResume;
        UInt32 ingterruptionTypeSize = sizeof(interruptionType);
        OSStatus status;
        status = AudioSessionGetProperty(kAudioSessionProperty_InterruptionType, &ingterruptionTypeSize, &interruptionType);
        NSAssert(status == noErr, @"failed to get interruption type");
        
        [self _sendEvent:event_interruption_end userData:(void*)(uintptr_t)interruptionType];
    }
}
-(void)_handleAudioRouteChangeWithDictionary:(NSDictionary*)routeChangeDictionary
{
    NSUInteger reason = [[routeChangeDictionary objectForKey:(__bridge  NSString*)kAudioSession_RouteChangeKey_Reason] unsignedIntegerValue];
    if (reason != kAudioSessionRouteChangeReason_OldDeviceUnavailable) return;
    
    NSDictionary *previousRouteDescription = [routeChangeDictionary objectForKey:(__bridge NSString*)kAudioSession_AudioRouteKey_Outputs];
    NSArray *previousOutputRoytes = [previousRouteDescription objectForKey:(__bridge NSString*)kAudioSession_AudioRouteKey_Outputs];
    if (previousOutputRoytes.count == 0) return;
    
    NSString *previousOutputType = [[previousOutputRoytes objectAtIndex:0] objectForKey:(__bridge NSString*)kAudioSession_AudioRouteKey_Type];
    if (previousOutputType == nil ||
        (![previousOutputType isEqualToString:(__bridge NSString *)kAudioSessionOutputRoute_Headphones] &&
         ![previousOutputType isEqualToString:(__bridge NSString *)kAudioSessionOutputRoute_BluetoothA2DP]))   return;
    [self _sendEvent:event_old_device_unavailable];
    
}
static void audio_session_interruption_listener(void *inClientData,UInt32 inInterruptionState)
{
    __unsafe_unretained ZJAudioEventLoop *loop = (__bridge ZJAudioEventLoop*)inClientData;
    [loop _handleAuidoSessionInterruptionWithState:inInterruptionState];
}
static void audio_route_change_listener(void *inClientData,AudioSessionPropertyID inID,UInt32 inDataSize,const void *inData)
{
    if (inID != kAudioSessionProperty_AudioRouteChange){
        return;
    }
    __unsafe_unretained ZJAudioEventLoop *loop = (__bridge  ZJAudioEventLoop*)inClientData;
    [loop _handleAudioRouteChangeWithDictionary:(__bridge NSDictionary*)inData];
}
-(void)_setupAudioSession
{
    AudioSessionInitialize(NULL, NULL, audio_session_interruption_listener,(__bridge void*)self);
    UInt32 audioCategory = kAudioSessionCategory_MediaPlayback;
    AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(audioCategory), &audioCategory);
    
    AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, audio_route_change_listener, (__bridge void *)self);
    AudioSessionSetActive(YES);
    
}
-(void)_setupFileProviderEventBlock
{
    __unsafe_unretained ZJAudioEventLoop* loop = self;
    _fileProviderBlock = ^{
        [loop _sendEvent:event_provider_events];
    };
}
-(void)_enableEvents
{
    for (uint64_t event = event_first;event <= event_last;++event){
        struct kevent kev;
        EV_SET(&kev, event, EVFILT_USER, EV_ADD|EV_ENABLE|EV_CLEAR, 0, 0, NULL);
        kevent(_kq, &kev, 1, NULL, 0, NULL);
    }
}
-(void)_createThread
{
    pthread_attr_t attr;
    struct sched_param sched_prarm;
    int sched_policy = SCHED_FIFO;
    
    pthread_attr_init(&attr);
    pthread_attr_setschedpolicy(&attr, sched_policy);
    sched_prarm.sched_priority = sched_get_priority_max(sched_policy);
    pthread_attr_setschedparam(&attr, &sched_prarm);
    
    pthread_create(&_thread, &attr, event_loop_main, (__bridge void*)self);
    pthread_attr_destroy(&attr);
    
}
-(void)_sendEvent:(event_type)type
{
    [self _sendEvent:type userData:NULL];
}
- (void)_sendEvent:(event_type)event userData:(void *)userData
{
    struct kevent kev;
    EV_SET(&kev, event, EVFILT_USER, 0, NOTE_TRIGGER, 0, userData);
    kevent(_kq, &kev, 1, NULL, 0, NULL);
}
-(event_type)_waitForEvent
{
    return  [self _waitForEventWithTimeout:NSUIntegerMax];
}
-(event_type)_waitForEventWithTimeout:(NSUInteger)timeout
{
    struct timespec _ts;
    struct timespec *ts = NULL;
    if (timeout != NSUIntegerMax){
        ts = &_ts;
        ts->tv_sec = timeout / 1000;
        ts->tv_nsec = (timeout%1000)*1000;
    }
    while (1) {
        struct kevent kev;
        int n = kevent(_kq, NULL, 0, &kev, 1, ts);
        if (n > 0){
            if (kev.filter == EVFILT_USER && kev.ident >= event_first && kev.ident <= event_last){
                _lastKQUserData = kev.udata;
                return kev.ident;
            }
        }else{
            break;
        }
    }
    return  event_timeout;
}
-(BOOL)_handleEvent:(event_type)event withStreamer:(ZJAudioStreamer**)streamer
{
    if (event == event_play){
        if (*streamer != nil && ([*streamer status] == ZJAudioStreamerPaused || [*streamer status] == ZJAudioStreamerIdle || [*streamer status] == ZJAudioStreamerFinished)){
            if ([_render isInterrupted]){
                const OSStatus status = AudioSessionSetActive(YES);
                if (status == noErr){
                    [*streamer setStatus:ZJAudioStreamerPlaying];
                    [_render setInterrupted:NO];
                }
            }else{
                [*streamer setStatus:ZJAudioStreamerPlaying];
            }
            
            
        }
    }else if (event == event_pause){
        if (*streamer != nil && ([*streamer status] != ZJAudioStreamerPaused) && [*streamer status] != ZJAudioStreamerIdle && [*streamer status] != ZJAudioStreamerFinished){
            [_render stop];
            [*streamer setStatus:ZJAudioStreamerPaused];
        }
    }else if (event == event_stop){
        if (*streamer != nil && [*streamer status] != ZJAudioStreamerIdle){
            if ([*streamer status] != ZJAudioStreamerPaused){
                [_render stop];
            }
            [_render flush];
            [*streamer setDecoder:nil];
            [*streamer setPlaybackItem:nil];
            [*streamer setStatus:ZJAudioStreamerIdle];
        }
    }else if (event == event_seek){
        if(*streamer != nil && [*streamer decoder] != nil){
            NSUInteger milliseconds = MIN((NSUInteger)(uintptr_t)_lastKQUserData, [[*streamer playbackItem] estimatedDuration]);
            [*streamer setTimingOffset:(NSInteger)milliseconds - (NSInteger)[_render currentTime]];
            [[*streamer decoder] seekToTime:milliseconds];
            [_render flushShouldResetTiming:NO];
        }
    }else if (event == event_streamer_changed){
        [_render stop];
        [_render flush];
        
        [[*streamer fileProvider] setEventBlock:NULL];
        *streamer = _currentStreamer;
        [[*streamer fileProvider] setEventBlock:_fileProviderBlock];
    }else if (event == event_provider_events){
        if (*streamer != nil && [*streamer status] == ZJAudioStreamerBuffering){
            [*streamer setStatus:ZJAudioStreamerPlaying];
        }
        [*streamer setBufferingRatio:(double)[[*streamer fileProvider] receivedLength]/[[*streamer fileProvider] expectedLength]];
    }else if (event == event_finalizing){
        return NO;
    }else if (event == event_interruption_begin){
        if (*streamer != nil && ([*streamer status] != ZJAudioStreamerPaused && [*streamer status] != ZJAudioStreamerIdle && [*streamer status] != ZJAudioStreamerFinished)) {
            [self performSelector:@selector(pause) onThread:[NSThread mainThread] withObject:nil waitUntilDone:NO];
            [*streamer setPausedByInterruption:YES];
        }
    }else if (event == event_interruption_end){
        const AudioSessionInterruptionType interruptionType = (AudioSessionInterruptionType)(uintptr_t)_lastKQUserData;
        NSAssert(interruptionType == kAudioSessionInterruptionType_ShouldResume || interruptionType == kAudioSessionInterruptionType_ShouldNotResume, @"invailid interruption type");
        if (interruptionType == kAudioSessionInterruptionType_ShouldResume){
            OSStatus status;
            status = AudioSessionSetActive(YES);
            NSAssert(status == noErr, @"failed to active audio session");
            if (status == noErr){
                [_render setInterrupted:NO];
                if (*streamer != nil && [*streamer status] == ZJAudioStreamerPaused && [*streamer isPausedByInterruption]){
                    [*streamer setPausedByInterruption:NO];
                    [self performSelector:@selector(play) onThread:[NSThread mainThread] withObject:nil waitUntilDone:NO ];
                }
            }
        }else if (interruptionType == kAudioSessionInterruptionType_ShouldNotResume){
            
        }
    }else if (event == event_old_device_unavailable){
        if (*streamer != nil){
            if ([*streamer status] != ZJAudioStreamerPaused && [*streamer status] != ZJAudioStreamerIdle && [*streamer status] != ZJAudioStreamerFinished){
                [self performSelector:@selector(pause) onThread:[NSThread mainThread] withObject:nil waitUntilDone:NO];
                [*streamer setPausedByInterruption:NO];
            }
        }
    }else if (event == event_timeout){
        
    }
    return YES;
}
-(void)_handleStreamer:(ZJAudioStreamer*)streamer
{
    if (streamer == nil) return;
    if ([streamer status] != ZJAudioStreamerPlaying) return;
    if ([[streamer fileProvider] isFailed]){
        [streamer setError:[NSError errorWithDomain:kZJAudioStreamerErrorDomain code:ZJAudioStreamerNetworkError userInfo:nil]];
        [streamer setStatus:ZJAudioStreamerError];
        return;
    }
    if (![[streamer fileProvider] isReady]){
        [streamer setStatus:ZJAudioStreamerBuffering];
        return;
    }
    if ([streamer playbackItem] == nil){
        [streamer setPlaybackItem:[ZJAudioPlaybackItem playbackItemWithFileProvider:[streamer fileProvider]]];
        if (![[streamer playbackItem] open]){
            [streamer setError:[NSError errorWithDomain:kZJAudioStreamerErrorDomain code:ZJAudioStreamerDecoingError userInfo:nil]];
            [streamer setStatus:ZJAudioStreamerError];
            return;
        }
        [streamer setDuration:(NSTimeInterval)[[streamer playbackItem] estimatedDuration] /1000.0];
    }
    if ([streamer decoder] == nil){
        [streamer setDecoder:[ZJAudioDecoder decoderWithPlaybackItem:[streamer playbackItem] bufferSize:_decoderBufferSize]];
        if (![[streamer decoder] setUp]){
            [streamer setError:[NSError errorWithDomain:kZJAudioStreamerErrorDomain code:ZJAudioStreamerDecoingError userInfo:nil]];
            [streamer setStatus:ZJAudioStreamerError];
            return;
        }
    }
    
    switch ([[streamer decoder] decodeOnce]) {
        case ZJAudioDecoderSucceeded:
            
            break;
        case ZJAudioDecoderFailed:
            [streamer setError:[NSError errorWithDomain:kZJAudioStreamerErrorDomain code:ZJAudioStreamerError userInfo:nil]];
            [streamer setStatus:ZJAudioStreamerError];
            break;
        case ZJAudioDecoderEndEncountered:
            [_render stop];
            [streamer setDecoder:nil];
            [streamer setPlaybackItem:nil];
            [streamer setStatus:ZJAudioStreamerFinished];
            break;
        case ZJAudioDecoderWaiting:
            [streamer setStatus:ZJAudioStreamerBuffering];
            break;
        default:
            break;
    }
    void *bytes = NULL;
    NSUInteger length = 0;
    [[[streamer decoder] lpcm] readBytes:&bytes length:&length];
    if (bytes != NULL){
        [_render renderBytes:bytes length:length];
        free(bytes);
    }
}
-(void)_eventLoop
{
    ZJAudioStreamer *streamer = nil;
    while (1) {
        @autoreleasepool {
            if (streamer != nil){
                switch ([streamer status]) {
                    case ZJAudioStreamerPaused:
                    case ZJAudioStreamerIdle:
                    case ZJAudioStreamerFinished:
                    case ZJAudioStreamerBuffering:
                    case ZJAudioStreamerError:
                        if (![self _handleEvent:[self _waitForEvent] withStreamer:&streamer]){
                            return;
                        }
                        break;
                        
                    default:
                        break;
                }
            }else{
                if (![self _handleEvent:[self _waitForEvent] withStreamer:&streamer]) return;
            }
            if (![self _handleEvent:[self _waitForEventWithTimeout:0] withStreamer:&streamer]) return;
            if (streamer != nil){
                [self _handleStreamer:streamer];
            }
        }
    }
}
static void *event_loop_main(void* info)
{
    pthread_setname_np("com.zj.audio-streamer");
    __unsafe_unretained ZJAudioEventLoop *eventloop = (__bridge ZJAudioEventLoop*)info;
    @autoreleasepool {
        [eventloop _eventLoop];
    }
    return NULL;
}
-(void)setCurrentStreamer:(ZJAudioStreamer*)currentStreamer
{
    if (_currentStreamer != currentStreamer){
        _currentStreamer = currentStreamer;
        [self _sendEvent:event_streamer_changed];
    }
}
-(NSTimeInterval)currentTime
{
    return (NSTimeInterval)(NSUInteger)[[self currentStreamer] timingOffset] + [_render currentTime]/1000.0;
}
-(void)setCurrentTime:(NSTimeInterval)currentTime
{
    NSUInteger milliseconds = (NSUInteger)lrint(currentTime*1000.0);
    [self _sendEvent:event_seek userData:(void*)(uintptr_t)milliseconds];
}
-(double)volume
{
    return [_render volume];
}
-(void)setVolume:(double)volume
{
    [_render setVolume:volume];
    if ([ZJAudioStreamer options] & ZJAudioStreamerKeepPersistentVolume){
        [[NSUserDefaults standardUserDefaults] setDouble:volume forKey:kZJAudioStreamerVolumeKey];
    }
}
-(void)play
{
    [self _sendEvent:event_play];
}
-(void)pause
{
    [self _sendEvent:event_pause];
}
-(void)stop
{
    [self _sendEvent:event_stop];
}
-(id)forwardingTargetForSelector:(SEL)aSelector
{
    if (aSelector == @selector(analyzers)){
        aSelector = @selector(setAnalyzes:);
        return _render;
    }
    return [super forwardingTargetForSelector:aSelector];
}
@end

























































