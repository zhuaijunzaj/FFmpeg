//
//  ZJAudioAnalyzer.h
//  FFMPEG
//
//  Created by Kattern on 2017/7/20.
//  Copyright © 2017年 Kattern. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kZJAudioAnalyzerLevelCount 20

@interface ZJAudioAnalyzer : NSObject
@property (nonatomic, assign) NSTimeInterval interval;
@property (nonatomic, assign, getter=isEnabled) BOOL enabled;
+(instancetype)analyzer;
-(void)handlePCLSamples:(int16_t*)samples count:(NSUInteger)count;
-(void)flush;
-(void)copyLevels:(float*)levels;
@end
