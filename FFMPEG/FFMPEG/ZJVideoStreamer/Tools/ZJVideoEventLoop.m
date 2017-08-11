//
//  ZJVideoEventLoop.m
//  FFMPEG
//
//  Created by 朱爱俊 on 2017/8/10.
//  Copyright © 2017年 朱爱俊. All rights reserved.
//

#import "ZJVideoEventLoop.h"
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

@interface ZJVideoEventLoop()
{
    int _kq;
    void *_lastKQUserData;
    pthread_mutex_t _mutex;
    pthread_t _thread;
}

@end
@implementation ZJVideoEventLoop

+(instancetype)sharedEventLoop
{
    static ZJVideoEventLoop *eventLoop = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        eventLoop = [[ZJVideoEventLoop alloc] init];
    });
    return eventLoop;
}
-(id)init
{
    self = [super init];
    if (self){
        _kq = kqueue();
        pthread_mutex_init(&_mutex, NULL);
        [self _enableEvents];
        [self _createThread];
    }
    return self;
}
-(void)_enableEvents
{
    for (uint64_t event = event_first;event <= event_last;++event){
        struct kevent kev;
        EV_SET(&kev, event, EVFILT_USER, EV_ADD|EV_ENABLE|EV_CLEAR, 0, 0, NULL);
        kevent(_kq, &kev, 1, NULL, 0, NULL);
    }
}
static void *event_loop_main(void* info)
{
    pthread_setname_np("com.zj.audio-streamer");
    __unsafe_unretained ZJVideoEventLoop *eventloop = (__bridge ZJVideoEventLoop*)info;
    @autoreleasepool {
        [eventloop _eventLoop];
    }
    return NULL;
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
-(void)_eventLoop
{
    while (1) {
        @autoreleasepool {
            
        }
    }
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
@end
