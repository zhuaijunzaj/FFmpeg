//
//  PlayerAPI.h
//  FFMPEG
//
//  Created by 朱爱俊 on 2017/8/10.
//  Copyright © 2017年 朱爱俊. All rights reserved.
//

#import <Foundation/Foundation.h>



@interface PlayerAPI : NSObject
+(instancetype)sharedInstance;
-(int)play;
@end
