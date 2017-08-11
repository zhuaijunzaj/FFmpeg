//
//  ZJAudioFrequencyAnalyzer.m
//  FFMPEG
//
//  Created by Kattern on 2017/7/20.
//  Copyright © 2017年 Kattern. All rights reserved.
//

#import "ZJAudioFrequencyAnalyzer.h"
#import "ZJAudioAnalyzer_Private.h"
#import <Accelerate/Accelerate.h>

@interface ZJAudioFrequencyAnalyzer ()
{
    size_t _log2Count;
    float _hamingWindow[kZJAudioAnalyzerCount];
    struct{
        float real[kZJAudioAnalyzerCount/2];
        float imag[kZJAudioAnalyzerCount/2];
    }_complexSplitBuffer;
    DSPSplitComplex _complexSplit;
    FFTSetup _fft;
}
@end
@implementation ZJAudioFrequencyAnalyzer
-(id)init
{
    self = [super init];
    if (self){
        _log2Count = (size_t)lrint(log2(kZJAudioAnalyzerCount));
        vDSP_hamm_window(_hamingWindow, kZJAudioAnalyzerCount, 0);
        _complexSplit.realp = _complexSplitBuffer.real;
        _complexSplit.imagp = _complexSplitBuffer.imag;
        _fft = vDSP_create_fftsetup(_log2Count, kFFTRadix2);
    }
    return self;
}
-(void)dealloc
{
    vDSP_destroy_fftsetup(_fft);
}
-(void)_splitInterleavedComplexVectors:(const float*)vectors
{
    vDSP_vmul((float*)vectors, 1, _hamingWindow, 1, (float*)vectors, 1, kZJAudioAnalyzerCount);
    vDSP_ctoz((const DSPComplex*)vectors, 2, &_complexSplit, 1, kZJAudioAnalyzerCount/2);
}

-(void)_perfomrForwardDFTWithVectors:(const float*)vectors
{
    vDSP_fft_zrip(_fft, &_complexSplit, 1, _log2Count, kFFTDirection_Forward);
    vDSP_zvabs(&_complexSplit, 1, (float*)vectors, 1, kZJAudioAnalyzerCount/2);
    static const float scale = 2.0f;
    vDSP_vsmul(vectors, 1, &scale, (float*)vectors, 1, kZJAudioAnalyzerCount/2);
}

-(void)_normalizeVectors:(const float*)vectors toLevels:(float*)levels
{
    static const int size = kZJAudioAnalyzerCount / 4;
    vDSP_vsq(vectors, 1, (float*)vectors, 1, size);
    vvlog10((double*)vectors, (double*)vectors, &size);
    
    static const float multiplier = 1.0f/16.0f;
    const float increment = sqrtf(multiplier);
    vDSP_vsma(vectors, 1, &multiplier, &increment, 1, (float*)vectors, 1, kZJAudioAnalyzerCount/2);
    for (size_t i = 0;i<kZJAudioAnalyzerCount;i++){
        levels[i] = vectors[1 + ((size - 1) / kZJAudioAnalyzerCount) * i];
    }
}

-(void)processChannelVectors:(const float *)vectors toLevels:(float *)levels
{
    [self _splitInterleavedComplexVectors:vectors];
    [self _perfomrForwardDFTWithVectors:vectors];
    [self _normalizeVectors:vectors toLevels:levels];
}


@end
