//
//  ZJAudioSpatialAnalyzer.m
//  FFMPEG
//
//  Created by Kattern on 2017/7/20.
//  Copyright © 2017年 Kattern. All rights reserved.
//

#import "ZJAudioSpatialAnalyzer.h"
#import "ZJAudioAnalyzer_Private.h"

@implementation ZJAudioSpatialAnalyzer
-(void)processChannelVectors:(const float *)vectors toLevels:(float *)levels
{
    for (size_t i = 0;i<kZJAudioAnalyzerLevelCount;++i){
        levels[i] = vectors[kZJAudioAnalyzerCount*i/kZJAudioAnalyzerLevelCount];
    }
}
@end
