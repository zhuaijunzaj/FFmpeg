//
//  ZJAudioPlaybackItem.h
//  FFMPEG
//
//  Created by Kattern on 2017/7/21.
//  Copyright © 2017年 Kattern. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreAudioKit/CoreAudioKit.h>

@class ZJAudioFileProvider;
@class ZJAudioFileProcessor;
@protocol ZJAudioFile ;

@interface ZJAudioPlaybackItem : NSObject
@property (nonatomic, strong, readonly) ZJAudioFileProvider *fileProvider;
@property (nonatomic, strong, readonly) ZJAudioFileProcessor *filePreprocessor;
@property (nonatomic, readonly) id <ZJAudioFile> audioFile;

@property (nonatomic, strong, readonly) NSURL *cachedURL;
@property (nonatomic, strong, readonly) NSData *mappedData;

@property (nonatomic, readonly) AudioFileID fileID;
@property (nonatomic, readonly) AudioStreamBasicDescription fileFormat;
@property (nonatomic, readonly) NSUInteger bitRate;
@property (nonatomic, readonly) NSUInteger dataOffset;
@property (nonatomic, readonly) NSUInteger estimatedDuration;

@property (nonatomic, readonly, getter=isOpened) BOOL opened;


+(instancetype)playbackItemWithFileProvider:(ZJAudioFileProvider*)fileProvider;
-(instancetype)initWithFileProvider:(ZJAudioFileProvider*)fileProvider;

-(BOOL)open;
-(void)close;
@end
