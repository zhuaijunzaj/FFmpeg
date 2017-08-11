//
//  ZJAudioFileProvider.h
//  FFMPEG
//
//  Created by Kattern on 2017/7/20.
//  Copyright © 2017年 Kattern. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZJAudioFile.h"

typedef void (^ZJAudioFileProviderEventBlock)(void);

@interface ZJAudioFileProvider : NSObject

@property (nonatomic, retain) id<ZJAudioFile>audioFile;
@property (nonatomic,   copy) ZJAudioFileProviderEventBlock eventBlock;
@property (nonatomic, copy, readonly) NSString *cachedPath;
@property (nonatomic, strong, readonly) NSURL *cachedURL;
@property (nonatomic, copy, readonly) NSString *mimeType;
@property (nonatomic, copy, readonly) NSString *fileExtension;
@property (nonatomic, copy, readonly) NSString *sha256;
@property (nonatomic, strong, readonly) NSData *mappedData;
@property (nonatomic, assign, readonly) NSUInteger expectedLength;
@property (nonatomic, assign, readonly) NSUInteger receivedLength;
@property (nonatomic, assign, readonly) NSUInteger downloadSpeed;

@property (nonatomic, assign, readonly, getter=isFailed) BOOL failed;
@property (nonatomic, assign, readonly, getter=isReady) BOOL ready;
@property (nonatomic, assign, readonly, getter=isFinished) BOOL finished;
+(instancetype)fileProviderWithAudioFile:(id<ZJAudioFile>)audioFile;
+(void)setHintWithAudioFile:(id<ZJAudioFile>)audioFile;

@end
