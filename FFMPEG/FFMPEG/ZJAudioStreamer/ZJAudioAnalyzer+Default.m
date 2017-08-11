//
//  ZJAudioAnalyzer+Default.m
//  FFMPEG
//
//  Created by Kattern on 2017/7/20.
//  Copyright © 2017年 Kattern. All rights reserved.
//

#import "ZJAudioAnalyzer+Default.h"
#import "ZJAudioSpatialAnalyzer.h"
#import "ZJAudioFrequencyAnalyzer.h"
@implementation ZJAudioAnalyzer (Default)

+(instancetype)spatialAnalyzer
{
    return [ZJAudioSpatialAnalyzer analyzer];
}
+(instancetype)frequencyAnalyzer
{
    return [ZJAudioFrequencyAnalyzer analyzer];
}
@end
