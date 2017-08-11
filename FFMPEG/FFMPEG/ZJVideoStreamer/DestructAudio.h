//
//  DestructAudio.h
//  FFMPEG
//
//  Created by 朱爱俊 on 2017/8/3.
//  Copyright © 2017年 朱爱俊. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DestructAudio : NSObject
-(id)initWithFilePath:(NSString*)path outputPath:(NSString*)outPath;

-(int)start;
@end
