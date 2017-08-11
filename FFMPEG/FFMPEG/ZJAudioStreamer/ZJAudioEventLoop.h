//
//  ZJAudioEventLoop.h
//  FFMPEG
//
//  Created by Kattern on 2017/7/25.
//  Copyright © 2017年 Kattern. All rights reserved.
//

#import <Foundation/Foundation.h>
@class ZJAudioStreamer;

@interface ZJAudioEventLoop : NSObject
@property (nonatomic, strong) ZJAudioStreamer *currentStreamer;
@property (nonatomic, assign) NSTimeInterval currentTime;
@property (nonatomic, assign) double volume;
@property (nonatomic, copy) NSArray *analyzers;
+(instancetype)sharedEventLoop;
-(void)play;
-(void)pause;
-(void)stop;
@end
