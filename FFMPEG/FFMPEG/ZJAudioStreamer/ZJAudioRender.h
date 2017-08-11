//
//  ZJAudioRender.h
//  FFMPEG
//
//  Created by Kattern on 2017/7/25.
//  Copyright © 2017年 Kattern. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZJAudioRender : NSObject
@property (nonatomic, readonly) NSUInteger currentTime;
@property (nonatomic, readonly, getter=isStarted) BOOL started;
@property (nonatomic, assign,getter=isInterrupted) BOOL interrupted;
@property (nonatomic, assign) double volume;
@property (nonatomic, copy) NSArray *analyzes;

+(instancetype)renderWithBufferTime:(NSUInteger)buffer;
-(instancetype)initWithBufferTime:(NSUInteger)bufferTime;
-(BOOL)setUp;
-(void)tearDown;
-(void)renderBytes:(const void*)bytes length:(NSUInteger)length;
-(void)stop;
-(void)flush;
-(void)flushShouldResetTiming:(BOOL)shouldResetTiming;
@end
