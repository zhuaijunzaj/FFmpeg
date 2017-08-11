//
//  ZJAudioFile.h
//  FFMPEG
//
//  Created by Kattern on 2017/7/20.
//  Copyright © 2017年 Kattern. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ZJAudioFileProcessor;
@protocol ZJAudioFile <NSObject>
@required
-(NSURL*)audioFileURL;
@optional
-(NSString*)audioFileHost;
-(ZJAudioFileProcessor*)audioFileProcessor;
@end
