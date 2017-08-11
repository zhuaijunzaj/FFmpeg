//
//  ZJVideoEventLoop.h
//  FFMPEG
//
//  Created by 朱爱俊 on 2017/8/10.
//  Copyright © 2017年 朱爱俊. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZJVideoEventLoop : NSObject
@property (nonatomic, assign) NSTimeInterval currentTime;
@property (nonatomic, assign) double volume;

+(instancetype)sharedEventLoop;
-(void)play;
-(void)pause;
-(void)stop;

@end
