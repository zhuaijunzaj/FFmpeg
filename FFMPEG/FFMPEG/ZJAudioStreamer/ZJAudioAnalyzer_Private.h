//
//  ZJAudioAnalyzer_Private.h
//  FFMPEG
//
//  Created by Kattern on 2017/7/20.
//  Copyright © 2017年 Kattern. All rights reserved.
//

#import "ZJAudioAnalyzer.h"

#define kZJAudioAnalyzerSampleCount 1024
#define kZJAudioAnalyzerCount       (kZJAudioAnalyzerSampleCount / 2)

@interface ZJAudioAnalyzer ()
- (void)processChannelVectors:(const float *)vectors toLevels:(float *)levels;
@end
