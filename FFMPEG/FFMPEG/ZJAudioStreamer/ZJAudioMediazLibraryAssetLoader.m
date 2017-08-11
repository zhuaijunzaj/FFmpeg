//
//  ZJAudioMediazLibraryAssetLoader.m
//  FFMPEG
//
//  Created by Kattern on 2017/7/20.
//  Copyright © 2017年 Kattern. All rights reserved.
//

#import "ZJAudioMediazLibraryAssetLoader.h"
#import <AVFoundation/AVFoundation.h>
#import <CommonCrypto/CommonDigest.h>

@interface ZJAudioMediazLibraryAssetLoader()
{
    NSString *_cachePath;
    AVAssetExportSession *_exportSession;
}
@end
@implementation ZJAudioMediazLibraryAssetLoader
+(instancetype)loaderWithURL:(NSURL *)url
{
    return [[self alloc] initWithURL:url];
}
-(instancetype)initWithURL:(NSURL *)url
{
    self = [super init];
    if (self){
        _assetURL = url;
    }
    return self;
}
-(void)start
{
    if (_exportSession == nil)
        return;
    AVAsset *asset = [AVAsset assetWithURL:_assetURL];
    if (asset == nil){
        return;
    }
    _exportSession = [AVAssetExportSession exportSessionWithAsset:asset presetName:AVAssetExportPresetPassthrough];
    if (_exportSession == nil){
        return;
    }
    [_exportSession setOutputFileType:AVFileTypeCoreAudioFormat];
    [_exportSession setOutputURL:[NSURL fileURLWithPath:[self cachedPath]]];
    
    __weak typeof(self) weakSelf = self;
    [_exportSession exportAsynchronouslyWithCompletionHandler:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf _exportSessionDidComplete];
    }];
    
}
-(void)cancel
{
    if(_exportSession == nil){
        return;
    }
    [_exportSession cancelExport];
    _exportSession = nil;
}
-(void)_exportSessionDidComplete
{
    if ([_exportSession status] != AVAssetExportSessionStatusCompleted || [_exportSession error] != nil){
        [self _reportFailure];
        return;
    }
    [self _invokeCompleteBlock];
}

-(void)_invokeCompleteBlock
{
    @synchronized (self) {
        if (_completeBlock){
            _completeBlock();
        }
    }
}
-(void)_reportFailure
{
    _failed = YES;
    [self _invokeCompleteBlock];
}

-(NSString*)cachedPath
{
    if (_cachePath == nil){
        NSString *filename = [NSString stringWithFormat:@"zj-mla-%@.%@",[[self class] _sha256ForURL:_assetURL],[self fileExtension]];
        _cachePath = [NSTemporaryDirectory() stringByAppendingString:filename];
        if ([[NSFileManager defaultManager] fileExistsAtPath:_cachePath]){
            [[NSFileManager defaultManager] removeItemAtPath:_cachePath error:NULL];
        }
    }
    return _cachePath;
}

-(NSString*)mimeType
{
    return AVFileTypeCoreAudioFormat;
}

-(NSString*)fileExtension{
    return @"caf";
}

+(NSString*)_sha256ForURL:(NSURL*)url
{
    NSString *string = [url absoluteString];
    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256([string UTF8String], (CC_LONG)[string lengthOfBytesUsingEncoding:NSUTF8StringEncoding], hash);
    
    NSMutableString *result = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (size_t i = 0; i < CC_SHA256_DIGEST_LENGTH; ++i) {
        [result appendFormat:@"%02x", hash[i]];
    }
    return result;
}



































@end
