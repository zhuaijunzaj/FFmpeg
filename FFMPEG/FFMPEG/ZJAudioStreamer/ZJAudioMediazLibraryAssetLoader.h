//
//  ZJAudioMediazLibraryAssetLoader.h
//  FFMPEG
//
//  Created by Kattern on 2017/7/20.
//  Copyright © 2017年 Kattern. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^ZJMPMediaLibraryAssetLoaderCompleteBlock)(void);

@interface ZJAudioMediazLibraryAssetLoader : NSObject

@property (nonatomic, strong, readonly) NSURL *assetURL;
@property (nonatomic, strong, readonly) NSString *cachedPath;
@property (nonatomic, strong, readonly) NSString *mimeType;
@property (nonatomic, strong, readonly) NSString *fileExtension;
@property (nonatomic, assign, readonly, getter=isFailed) BOOL failed;
@property (nonatomic,copy) ZJMPMediaLibraryAssetLoaderCompleteBlock completeBlock;

+(instancetype)loaderWithURL:(NSURL*)url;
-(instancetype)initWithURL:(NSURL*)url;

-(void)start;
-(void)cancel;
@end
