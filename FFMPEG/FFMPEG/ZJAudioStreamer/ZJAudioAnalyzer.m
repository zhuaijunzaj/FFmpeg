//
//  ZJAudioAnalyzer.m
//  FFMPEG
//
//  Created by Kattern on 2017/7/20.
//  Copyright © 2017年 Kattern. All rights reserved.
//

#import "ZJAudioAnalyzer.h"
#import "ZJAudioAnalyzer_Private.h"
#import <Accelerate/Accelerate.h>
#import <pthread.h>
#import <mach/mach_time.h>

@interface ZJAudioAnalyzer ()
{
    int16_t _sampleBuffer[kZJAudioAnalyzerSampleCount];
    struct{
        float sample[kZJAudioAnalyzerSampleCount];
        float left[kZJAudioAnalyzerSampleCount];
        float right[kZJAudioAnalyzerSampleCount];
    }_vertors;
    
    struct{
        float left[kZJAudioAnalyzerSampleCount];
        float right[kZJAudioAnalyzerSampleCount];
        float overall[kZJAudioAnalyzerSampleCount];
    }_levels;
    
    uint64_t _inerval;
    uint64_t _lastTime;
    BOOL _enabled;
    pthread_mutex_t mutex;
}
@end
@implementation ZJAudioAnalyzer
@synthesize enabled = _enabled;
+(instancetype)analyzer
{
    return [[self alloc] init];
}
-(id)init
{
    self = [super init];
    if(self){
        _enabled = NO;
        pthread_mutex_init(&mutex, NULL);
        _lastTime = 0;
        [self setInterval:0.1];
        [self flush];
    }
    return self;
}
-(void)dealloc{
    pthread_mutex_destroy(&mutex);
}
-(void)handlePCLSamples:(int16_t *)samples count:(NSUInteger)count
{
    pthread_mutex_lock(&mutex);
    if (samples == NULL || count == 0){
        pthread_mutex_unlock(&mutex);
        return;
    }
    if (!_enabled){
        pthread_mutex_unlock(&mutex);
        return;
    }
    uint64_t currentTime = mach_absolute_time();
    if (currentTime - _lastTime < _inerval){
        pthread_mutex_unlock(&mutex);
        return;
    }else{
        _lastTime = currentTime;
    }
    if (count >= kZJAudioAnalyzerSampleCount){
        [self _analyzeLinearPCMSamples:samples];
    }else{
        memcpy(_sampleBuffer, samples, (sizeof(int16_t))*count);
        memset(_sampleBuffer, 0, (sizeof(int16_t))*(kZJAudioAnalyzerSampleCount-count));
        [self _analyzeLinearPCMSamples:samples];
    }
    pthread_mutex_unlock(&mutex);
    
}
-(void)flush
{
    pthread_mutex_lock(&mutex);
    vDSP_vclr(_levels.overall, 1, kZJAudioAnalyzerLevelCount);
    pthread_mutex_unlock(&mutex);
}
+(double)_absoluteTimeConversion
{
    static double conversion;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mach_timebase_info_data_t info;
        mach_timebase_info(&info);
        conversion = 1.0e-9 * info.numer / info.denom;
    });
    return conversion;
}
-(NSTimeInterval)interval
{
    return [[self class] _absoluteTimeConversion];
}
-(void)setInterval:(NSTimeInterval)interval
{
    pthread_mutex_lock(&mutex);
    _inerval = interval;
    pthread_mutex_unlock(&mutex);
}
-(void)setEnabled:(BOOL)enabled
{
    if (_enabled != enabled){
        pthread_mutex_lock(&mutex);
        _enabled = enabled;
        pthread_mutex_unlock(&mutex);
    }
}
-(void)copyLevels:(float *)levels
{
    pthread_mutex_lock(&mutex);
    if (levels != NULL){
        memcpy(levels, _levels.overall, sizeof(float)*kZJAudioAnalyzerLevelCount);
    }
    pthread_mutex_unlock(&mutex);
}

-(void)_analyzeLinearPCMSamples:(const int16_t*)samples
{
    [self _spliteStereoSample:samples];
    [self processChannelVectors:_vertors.left toLevels:_levels.left];
    [self processChannelVectors:_vertors.right toLevels:_levels.right];
    [self _updateLevels];
}
-(void)_spliteStereoSample:(const int16_t*)samples
{
    static const float scale = INT16_MAX;
    vDSP_vflt16((int16_t*)samples, 1, _vertors.sample, 1, kZJAudioAnalyzerSampleCount);
    vDSP_vsdiv(_vertors.sample, 1, (float*)&scale, _vertors.sample, 1, kZJAudioAnalyzerSampleCount);

    DSPSplitComplex complexSplit;
    complexSplit.realp = _vertors.left;
    complexSplit.imagp = _vertors.right;
    vDSP_ctoz((const DSPComplex*)_vertors.sample, 2, &complexSplit, 1, kZJAudioAnalyzerCount);
}
-(void)_updateLevels
{
    static const float scale =2.0f;
    vDSP_vadd(_levels.left, 1, _levels.right, 1, _levels.overall, 1, kZJAudioAnalyzerCount);
    vDSP_vdiv(_levels.overall, 1, (float*)&scale, 1, _levels.overall, 1, kZJAudioAnalyzerCount);
    
    static const float min = 0.0f;
    static const float max = 0.0f;
    vDSP_vclip(_levels.overall, 1, (float*)&min, (float*)&max,_levels.overall , 1, kZJAudioAnalyzerCount);
}
-(void)processChannelVectors:(const float *)vectors toLevels:(float *)levels
{
    [self doesNotRecognizeSelector:_cmd];
}
@end
