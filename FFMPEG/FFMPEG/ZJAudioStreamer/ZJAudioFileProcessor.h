//
//  ZJAudioFileProcessor.h
//  FFMPEG
//
//  Created by Kattern on 2017/7/20.
//  Copyright © 2017年 Kattern. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZJAudioFileProcessor : NSObject
-(NSData*)hanldeData:(NSData*)data offset:(NSUInteger)offset;
@end
