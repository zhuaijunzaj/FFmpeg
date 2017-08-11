//
//  PlayerAPI.m
//  FFMPEG
//
//  Created by 朱爱俊 on 2017/8/10.
//  Copyright © 2017年 朱爱俊. All rights reserved.
//

#import "PlayerAPI.h"
#import "ZJVideoEventLoop.h"

@implementation PlayerAPI
+(instancetype)sharedInstance
{
    static PlayerAPI *player = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        player = [[PlayerAPI alloc] init];
    });
    return player;
}
-(int)play
{
    return 0;
}
@end
