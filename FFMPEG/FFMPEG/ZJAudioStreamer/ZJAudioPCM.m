//
//  ZJAudioPCM.m
//  FFMPEG
//
//  Created by Kattern on 2017/7/20.
//  Copyright © 2017年 Kattern. All rights reserved.
//

#import "ZJAudioPCM.h"
#include <libkern/OSAtomic.h>

typedef struct data_segment{
    void *bytes;
    NSUInteger length;
    struct data_segment *next;
}data_segment;

@interface ZJAudioPCM()
{
    @private
    data_segment *_segments;
    BOOL _end;
    OSSpinLock _lock;
}
@end
@implementation ZJAudioPCM
@synthesize end = _end;

-(id)init
{
    self = [super init];
    if (self){
        _lock = OS_SPINLOCK_INIT;
    }
    return self;
}
-(void)dealloc
{
    while (_segments != NULL) {
        data_segment *segment = _segments->next;
        free(_segments);
        _segments = segment;
    }
}
-(void)setEnd:(BOOL)end
{
    OSSpinLockLock(&_lock);
    if (end && !_end){
        _end = end;
    }
    OSSpinLockUnlock(&_lock);
}
-(BOOL)readBytes:(void **)bytes length:(NSUInteger *)length
{
    *bytes = NULL;
    *length = 0;
    OSSpinLockLock(&_lock);
    if (_end && _segments == NULL){
        OSSpinLockUnlock(&_lock);
        return NO;
    }
    if (_segments != NULL){
        *length = _segments->length;
        *bytes = malloc(*length);
        memcpy(*bytes, _segments->bytes, *length);
        
        data_segment *next = _segments->next;
        free(_segments);
        _segments = next;
    }
    OSSpinLockUnlock(&_lock);
    return YES;
}
-(void)writeBytes:(const void *)bytes length:(NSUInteger)length
{
    OSSpinLockLock(&_lock);
    if (_end){
        OSSpinLockUnlock(&_lock);
        return;
    }
    if (bytes == NULL || length == 0){
        OSSpinLockUnlock(&_lock);
        return;
    }
    
    data_segment *segment = (data_segment*)malloc(sizeof(data_segment)+length);
    segment->bytes = segment+1;
    segment->length= length;
    segment->next = NULL;
    memcpy(segment->bytes, bytes, length);
    
    data_segment **link = &_segments;
    while (*link != NULL) {
        data_segment *current = *link;
        link= &current->next;
    }
    *link = segment;
    
    OSSpinLockUnlock(&_lock);
}
@end
