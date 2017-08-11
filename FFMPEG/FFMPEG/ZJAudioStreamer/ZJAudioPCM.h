//
//  ZJAudioPCM.h
//  FFMPEG
//
//  Created by Kattern on 2017/7/20.
//  Copyright © 2017年 Kattern. All rights reserved.
//

#import <Foundation/Foundation.h>

//pcm 数据

@interface ZJAudioPCM : NSObject
@property (nonatomic, assign,getter=isEnd) BOOL end;
-(BOOL)readBytes:(void**)bytes length:(NSUInteger*)length;
-(void)writeBytes:(const void*)bytes length:(NSUInteger)length;
@end
