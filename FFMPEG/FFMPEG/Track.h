//
//  Track.h
//  FFMPEG
//
//  Created by 朱爱俊 on 2017/7/26.
//  Copyright © 2017年 朱爱俊. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZJAudioFile.h"

@interface Track : NSObject<ZJAudioFile>
@property (nonatomic, strong) NSString *artist;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSURL *audioFileURL;

@end
