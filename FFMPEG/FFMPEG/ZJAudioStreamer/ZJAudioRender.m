//
//  ZJAudioRender.m
//  FFMPEG
//
//  Created by Kattern on 2017/7/25.
//  Copyright © 2017年 Kattern. All rights reserved.
//

#import "ZJAudioRender.h"
#import "ZJAudioDecoder.h"
#import "ZJAudioAnalyzer.h"
#import <CoreAudio/CoreAudioTypes.h>
//#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <pthread.h>
#import <sys/types.h>
#import <sys/time.h>
#import <mach/mach_time.h>
#import <Accelerate/Accelerate.h>

@interface ZJAudioRender ()
{
    pthread_mutex_t _mutex;
    pthread_cond_t _cond;
    AudioComponentInstance _outputAudioUint;
    
    uint8_t *_buffer;
    NSUInteger _bufferByteCount;
    NSUInteger _firstValidByteOffset;
    NSUInteger _validByteCount;
    
    NSUInteger _bufferTimer;
    BOOL _started;
    NSArray *_analyzers;
    
    uint64_t _startedTime;
    uint64_t _interruptedTime;
    uint64_t _totalInterruptedInterval;
    
    double _volume;
}


@end
@implementation ZJAudioRender
@synthesize started = _started;
@synthesize analyzes = _analyzers;
+(instancetype)renderWithBufferTime:(NSUInteger)buffer
{
    return [[[self class] alloc] initWithBufferTime:buffer];
}
-(instancetype)initWithBufferTime:(NSUInteger)bufferTime
{
    self = [super init];
    if (self){
        pthread_mutex_init(&_mutex, NULL);
        pthread_cond_init(&_cond, NULL);
        _bufferTimer = bufferTime;
        _volume = 1.0;
        
    }
    return self;
}
-(void)dealloc
{
    if (_outputAudioUint != NULL){
        [self tearDown];
    }
    if (_buffer != NULL){
        free(_buffer);
    }
    pthread_mutex_destroy(&_mutex);
    pthread_cond_destroy(&_cond);
}
-(void)_setShouldInterceprTime:(BOOL)shouldInterceptTiming
{
    if (_startedTime == 0){
        _startedTime = mach_absolute_time();
    }
    if ((_interruptedTime !=0) == shouldInterceptTiming){
        return;
    }
    if (shouldInterceptTiming){
        _interruptedTime = mach_absolute_time();
    }else{
        _totalInterruptedInterval += mach_absolute_time() - _interruptedTime;
        _interruptedTime = 0;
    }
}
static OSStatus au_render_callback(void * inRefCon,AudioUnitRenderActionFlags *inActionFlags,const AudioTimeStamp *inTimeStamp,
                                   UInt32 inBusNumber,UInt32 inNumberFrames,AudioBufferList *ioData)
{
    __unsafe_unretained ZJAudioRender *render = (__bridge ZJAudioRender*)inRefCon;
    pthread_mutex_lock(&render->_mutex);
    NSUInteger totalBytesToCopy = ioData->mBuffers[0].mDataByteSize;
    NSUInteger validByteCount = render->_validByteCount;
    if (validByteCount < totalBytesToCopy){
        [render->_analyzers makeObjectsPerformSelector:@selector(flush)];
        [render _setShouldInterceprTime:YES];
        
        *inActionFlags = kAudioUnitRenderAction_OutputIsSilence;
        bzero(ioData->mBuffers[0].mData, ioData->mBuffers[0].mDataByteSize);
        pthread_mutex_unlock(&render->_mutex);
        return noErr;
    }else{
        [render _setShouldInterceprTime:NO];
    }
    uint8_t *bytes = render->_buffer + render->_firstValidByteOffset;
    uint8_t *outBuffer = (uint8_t*)ioData->mBuffers[0].mData;
    NSUInteger outBufSize = ioData->mBuffers[0].mDataByteSize;
    NSUInteger bytesToCopy = MIN(outBufSize, validByteCount);
    NSUInteger firstFrag = bytesToCopy;
    
    if (render->_firstValidByteOffset + bytesToCopy > render->_bufferByteCount){
        firstFrag = render->_bufferByteCount - render->_firstValidByteOffset;
    }
    if(firstFrag < bytesToCopy){
        memcpy(outBuffer, bytes, firstFrag);
        memcpy(outBuffer+firstFrag, render->_buffer, bytesToCopy-firstFrag);
    }else{
        memcpy(outBuffer, bytes, bytesToCopy);
    }
    NSArray *analyzers = render->_analyzers;
    if (analyzers != nil){
        for (ZJAudioAnalyzer *analyzer in analyzers){
            [analyzer handlePCLSamples:(int16_t*)outBuffer count:bytesToCopy/sizeof(int16_t)];
        }
    }
    if (render->_volume != 1.0){
        int16_t *samples = (int16_t*)outBuffer;
        size_t sampleCount = bytesToCopy/sizeof(int16_t);
        
        float floatSamples[sampleCount];
        vDSP_vflt16(samples, 1, floatSamples, 1, sampleCount);
        
        float volume = render->_volume;
        vDSP_vsmul(floatSamples, 1, &volume, floatSamples, 1, sampleCount);
        vDSP_vfix16(floatSamples, 1, samples, 1, sampleCount);
    }
    if (bytesToCopy < outBufSize){
        bzero(outBuffer+bytesToCopy, outBufSize - bytesToCopy);
    }
    render->_validByteCount  -= bytesToCopy;
    render->_firstValidByteOffset = (render->_firstValidByteOffset + bytesToCopy) % render->_bufferByteCount;
    pthread_mutex_unlock(&render->_mutex);
    pthread_cond_signal(&render->_cond);
    return noErr;
}
-(BOOL)setUp
{
    if (_outputAudioUint != NULL){
        return YES;
    }
    OSStatus status;
    AudioComponentDescription desc;
    desc.componentType = kAudioUnitType_Output;
    desc.componentSubType = kAudioUnitSubType_RemoteIO;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;
    
    AudioComponent comp = AudioComponentFindNext(NULL, &desc);
    if (comp == NULL){
        return NO;
    }
    status = AudioComponentInstanceNew(comp, &_outputAudioUint);
    if (status != noErr){
        _outputAudioUint = NULL;
        return NO;
    }
    AudioStreamBasicDescription requestDesc = [ZJAudioDecoder defaultOutputFormat];
    status = AudioUnitSetProperty(_outputAudioUint, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &requestDesc, sizeof(requestDesc));
    if (status != noErr){
        AudioComponentInstanceDispose(_outputAudioUint);
        _outputAudioUint = NULL;
        return NO;
    }
    UInt32 size = sizeof(requestDesc);
    status = AudioUnitGetProperty(_outputAudioUint, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &requestDesc, &size);
    if (status != noErr){
        AudioComponentInstanceDispose(_outputAudioUint);
        _outputAudioUint = NULL;
        return NO;
    }
    AURenderCallbackStruct input;
    input.inputProc = au_render_callback;
    input.inputProcRefCon = (__bridge void*)self;
    
    status = AudioUnitSetProperty(_outputAudioUint, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &input, sizeof(input));
    if (status != noErr){
        AudioComponentInstanceDispose(_outputAudioUint);
        _outputAudioUint = NULL;
        return NO;
    }
    status = AudioUnitInitialize(_outputAudioUint);
    if (status != noErr){
        AudioComponentInstanceDispose(_outputAudioUint);
        _outputAudioUint = NULL;
        return NO;
    }
    if (_buffer == NULL){
        _bufferByteCount = (_bufferTimer * requestDesc.mSampleRate /1000) *(requestDesc.mChannelsPerFrame *requestDesc.mBitsPerChannel / 8);
        _firstValidByteOffset = 0;
        _validByteCount = 0;
        _buffer = (uint8_t*)calloc(1, _bufferByteCount);
    }
    return YES;
}

- (void)tearDown
{
    if (_outputAudioUint == NULL) {
        return;
    }
    
    [self stop];
    [self _tearDownWithoutStop];
}
-(void)_tearDownWithoutStop
{
    AudioUnitUninitialize(_outputAudioUint);
    AudioComponentInstanceDispose(_outputAudioUint);
    _outputAudioUint = NULL;
    
}
-(void)renderBytes:(const void *)bytes length:(NSUInteger)length
{
    if (_outputAudioUint == NULL) return;
    
    while (length > 0) {
        pthread_mutex_lock(&_mutex);
        NSUInteger emptyByteCount = _bufferByteCount - _validByteCount;
        while (emptyByteCount == 0) {
            if (!_started){
                if (_interrupted){
                    pthread_mutex_unlock(&_mutex);
                    return;
                }
                pthread_mutex_unlock(&_mutex);
                AudioOutputUnitStart(_outputAudioUint);
                pthread_mutex_lock(&_mutex);
                _started = YES;
            }
            struct timeval tv;
            struct timespec ts;
            gettimeofday(&tv, NULL);
            ts.tv_sec = tv.tv_sec +1;
            ts.tv_nsec = 0;
            pthread_cond_timedwait(&_cond, &_mutex, NULL);
            emptyByteCount = _bufferByteCount - _validByteCount;
        }
        NSUInteger firstEmptyByteOffset = (_firstValidByteOffset + _validByteCount) % _bufferByteCount;
        NSUInteger bytesToCopy;
        if (firstEmptyByteOffset + emptyByteCount > _bufferByteCount){
            bytesToCopy = MIN(length, _bufferByteCount - firstEmptyByteOffset);
        }else{
            bytesToCopy = MIN(length,emptyByteCount);
        }
        memcpy(_buffer + firstEmptyByteOffset, bytes, bytesToCopy);
        length -= bytesToCopy;
        bytes = (const uint8_t*)bytes + bytesToCopy;
        _validByteCount += bytesToCopy;
        pthread_mutex_unlock(&_mutex);
    }
}

-(void)stop
{
    [_analyzers makeObjectsPerformSelector:@selector(flush)];
    if (_outputAudioUint == NULL){
        return;
    }
    pthread_mutex_lock(&_mutex);
    if (_started){
        pthread_mutex_unlock(&_mutex);
        AudioOutputUnitStop(_outputAudioUint);
        pthread_mutex_lock(&_mutex);
        [self _setShouldInterceprTime:YES];
        _started = NO;
    }
    pthread_mutex_unlock(&_mutex);
    pthread_cond_signal(&_cond);
}
-(void)flush
{
    [self flushShouldResetTiming:YES];
}
-(void)flushShouldResetTiming:(BOOL)shouldResetTiming
{
    [_analyzers makeObjectsPerformSelector:@selector(flush)];
    
    if (_outputAudioUint == NULL) return;
    pthread_mutex_lock(&_mutex);
    _firstValidByteOffset = 0;
    _validByteCount = 0;
    if (shouldResetTiming)[self _resetTime];
    pthread_mutex_unlock(&_mutex);
    pthread_cond_signal(&_cond);
}
+(double)_absoluteTimeConversion
{
    static  double conversion;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mach_timebase_info_data_t info;
        mach_timebase_info(&info);
        conversion = 1.0e-9 *info.numer / info.denom;
    });
    return conversion;
}
-(void)_resetTime
{
    _startedTime = 0;
    _interruptedTime =0;
    _totalInterruptedInterval = 0;
}
-(NSUInteger)currentTime
{
    if (_startedTime == 0) return 0;
    double base = [[self class] _absoluteTimeConversion]*1000.0;
    uint64_t interval;
    if (_interruptedTime == 0) interval = mach_absolute_time() - _startedTime - _totalInterruptedInterval;
    else interval = _interruptedTime - _startedTime - _totalInterruptedInterval;
    return base*interval;
}
-(void)setInterrupted:(BOOL)interrupted
{
    pthread_mutex_lock(&_mutex);
    _interrupted = interrupted;
    pthread_mutex_unlock(&_mutex);
}
-(double)volume
{
    return _volume;

}
-(void)setVolume:(double)volume
{
    _volume = volume;

}
@end

























































