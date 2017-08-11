//
//  ZJAudioFileProvider.m
//  FFMPEG
//
//  Created by Kattern on 2017/7/20.
//  Copyright © 2017年 Kattern. All rights reserved.
//

#import "ZJAudioFileProvider.h"
#import "ZJAudioHttpRequest.h"
#import "ZJAudioStreamer+Options.h"
#import <CommonCrypto/CommonDigest.h>
#import <AudioToolbox/AudioToolbox.h>
#import "ZJAudioMediazLibraryAssetLoader.h"
#import "NSData+ZJMappedFile.h"
#import <MobileCoreServices/MobileCoreServices.h>
static id<ZJAudioFile> gHintFile = nil;
static ZJAudioFileProvider *gHintProvider = nil;
static BOOL gLastProviderIsFinished = NO;

@interface ZJAudioFileProvider()
{
@protected
    id <ZJAudioFile> _audioFile;
    ZJAudioFileProviderEventBlock _eventBlock;
    NSString *_cachedPath;
    NSURL *_cachedURL;
    NSString *_mimeType;
    NSString *_fileExtension;
    NSString *_sha256;
    NSData *_mappedData;
    NSUInteger _expectedLength;
    NSUInteger _receivedLength;
    BOOL _failed;
}
-(instancetype)_initWithAudioFile:(id<ZJAudioFile>)audioFile;
@end

@interface _ZJAudioLocalFileProvider : ZJAudioFileProvider

@end

@interface _ZJAudioRemoteFileProvider : ZJAudioFileProvider
{
    ZJAudioHttpRequest *_request;
    NSURL *_audioFileURL;
    NSString *_audioFileHost;
    CC_SHA256_CTX *_sha256Ctx;
    
    AudioFileStreamID _audioFileStreamID;
    BOOL _requiresCompleteFile;
    BOOL _readyToProductPackets;
    BOOL _requestCompleted;
}

@end

@implementation _ZJAudioLocalFileProvider

-(instancetype)_initWithAudioFile:(id<ZJAudioFile>)audioFile
{
    self = [super _initWithAudioFile:audioFile];
    if (self){
        _cachedURL = [audioFile audioFileURL];
        _cachedPath = [_cachedURL path];
        BOOL isDirectory = NO;
        if (![[NSFileManager defaultManager] fileExistsAtPath:_cachedPath isDirectory:&isDirectory] || isDirectory){
            return nil;
        }
        _mappedData = [NSData zj_modifiableDatahMappedContentsOfFile:_cachedPath];
        _expectedLength = [_mappedData length];
        _receivedLength = [_mappedData length];
        
    }
    return self;
}
-(NSString*)mimeType
{
    if (_mimeType == nil && [self fileExtension] != nil){
        CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)[self fileExtension], NULL);
        if (uti != NULL){
            _mimeType = CFBridgingRelease(UTTypeCopyAllTagsWithClass(uti, kUTTagClassMIMEType));
        }
    }
    return _mimeType;
}
-(NSString*)fileExtension
{
    if (_fileExtension == nil){
        _fileExtension = [[[self audioFile] audioFileURL] pathExtension];
    }
    return _fileExtension;
}
-(NSString *)sha256
{
    if (_sha256 == nil && [self mappedData] != nil ){
        unsigned char hash[CC_SHA256_DIGEST_LENGTH];
        CC_SHA256([[self mappedData] bytes], (CC_LONG)[self mappedData].length, hash);
        NSMutableString *result = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
        for (size_t i = 0; i < CC_SHA256_DIGEST_LENGTH; ++i) {
            [result appendFormat:@"%02x", hash[i]];
        }
        
        _sha256 = [result copy];
    }
    return _sha256;
}
-(NSUInteger)downloadSpeed
{
    return _receivedLength;
}
-(BOOL)isReady
{
    return YES;
}
-(BOOL)isFinished
{
    return YES;
}
@end

@implementation _ZJAudioRemoteFileProvider
@synthesize  finished = _requestCompleted;

-(instancetype)_initWithAudioFile:(id<ZJAudioFile>)audioFile
{
    self = [super _initWithAudioFile:audioFile];
    if (self){
        _audioFileURL = [audioFile audioFileURL];
        if ([audioFile respondsToSelector:@selector(audioFileHost)]){
            _audioFileHost = [audioFile audioFileHost];
        }
        if ([ZJAudioStreamer options] & ZJAudioStreamerRequireSHA256){
            _sha256Ctx = (CC_SHA256_CTX*)malloc(sizeof(CC_SHA256_CTX));
            CC_SHA256_Init(_sha256Ctx);
        }
        [self _openAudioFileStream];
        [self _createRequest];
        [_request start];
    }
    return self;
}
-(void)dealloc
{
    @synchronized (_request) {
        [_request setCompleteBlock:NULL];
        [_request setProgressBlock:NULL];
        [_request setProgressBlock:NULL];
        [_request setReceiveDataBlock:NULL];
        [_request cancel];
    }
    if (_sha256Ctx != nil) free(_sha256Ctx);
    [self _closeAudioFileStream];
    [[NSFileManager defaultManager] removeItemAtPath:_cachedPath error:NULL];
}
+(NSString*)_sha256ForAudioFileURL:(NSURL*)audioFileURL
{
    NSString *string = [audioFileURL absoluteString];
    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256([string UTF8String], (CC_LONG)[string lengthOfBytesUsingEncoding:NSUTF8StringEncoding], hash);
    NSMutableString *result = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (size_t i = 0; i < CC_SHA256_DIGEST_LENGTH; ++i) {
        [result appendFormat:@"%02x", hash[i]];
    }
    
    return result;
    
}
+(NSString*)_cachedPathForAudioFileURL:(NSURL*)url
{
    NSString *filename = [NSString stringWithFormat:@"zj-%@.tmp",[self _sha256ForAudioFileURL:url]];
    return [NSTemporaryDirectory() stringByAppendingString:filename];
}
-(void)_invokeEventBlock
{
    if (_eventBlock){
        _eventBlock();
    }
}
-(void)_reqeustComplete
{
    if ([_request isFailed] ||!([_request statusCode] >=200 && [_request statusCode] < 300)){
        _failed = YES;
        return;
    }else{
        _requestCompleted = YES;
        [_mappedData zj_synchronizeMappedFile];
    }
    if (!_failed && _sha256Ctx != NULL){
        unsigned char hash[CC_SHA256_DIGEST_LENGTH];
        CC_SHA256_Final(hash, _sha256Ctx);
        NSMutableString *result = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
        for (size_t i = 0; i < CC_SHA256_DIGEST_LENGTH; ++i) {
            [result appendFormat:@"%02x", hash[i]];
        }
        
        _sha256 = [result copy];
    }
    if (gHintFile != nil && gHintProvider != nil){
        gHintProvider = [[[self class] alloc] _initWithAudioFile:gHintFile];
    }
    [self _invokeEventBlock];
}
-(void)_requestDidReportProgress:(double)progress
{
    [self _invokeEventBlock];
}
-(void)_requestDidReceiveResnponse
{
    _expectedLength = [_request responseContentLength];
    _cachedPath = [[self class] _cachedPathForAudioFileURL:_audioFileURL];
    _cachedURL = [NSURL fileURLWithPath:_cachedPath];
    [[NSFileManager defaultManager] createFileAtPath:_cachedPath contents:nil attributes:nil];
    [[NSFileManager defaultManager] setAttributes:@{NSFileProtectionKey:NSFileProtectionNone} ofItemAtPath:_cachedPath error:NULL];
    [[NSFileHandle fileHandleForReadingAtPath:_cachedPath] truncateFileAtOffset:_expectedLength];
    _mimeType = [[_request responseHeader] objectForKey:@"Content-Type"];
    _mappedData = [NSData zj_modifiableDatahMappedContentsOfFile:_cachedPath];
}
-(void)_requestDidReceiveData:(NSData*)data
{
    if (_mappedData == nil){
        return;
    }
    NSUInteger availableSpace = _expectedLength - _receivedLength;
    NSUInteger bytesToWrite = MIN(availableSpace, [data length]);
    memcpy((uint8_t*)[_mappedData bytes]+_receivedLength, [data bytes], bytesToWrite);
    _receivedLength += bytesToWrite;
    
    if (_sha256Ctx != NULL){
        CC_SHA256_Update(_sha256Ctx, [data bytes], (CC_LONG)[data length]);
    }
    if (!_readyToProductPackets && !_failed && !_requiresCompleteFile){
        OSStatus status = kAudioFileStreamError_UnsupportedFileType;
        if (_audioFileStreamID != NULL){
            status = AudioFileStreamParseBytes(_audioFileStreamID, (UInt32)[data length], [data bytes], 0);
        }
        if (status != noErr && status != kAudioFileStreamError_NotOptimized){
            NSArray *fallbackTypeIDs = [self _fallbackTypeIDs];
            for (NSNumber *typeIDNumber in fallbackTypeIDs){
                AudioFileTypeID typeID =(AudioFileTypeID)[typeIDNumber unsignedLongValue];
                [self _closeAudioFileStream];
                [self _openAudioFileStreamWithFileTypeHint:typeID];
                
                if (_audioFileStreamID != NULL){
                    status = AudioFileStreamParseBytes(_audioFileStreamID, (UInt32)_receivedLength, [_mappedData bytes], 0);
                    if (status == noErr || status == kAudioFileStreamError_NotOptimized){
                        break;
                    }
                }
            }
            if (status == noErr || status == kAudioFileStreamError_NotOptimized) _failed = YES;
            
        }
        if (status == kAudioFileStreamError_NotOptimized){
            [self _closeAudioFileStream];
            _requiresCompleteFile = YES;
        }
    }
}
-(void)_createRequest
{
    _request = [ZJAudioHttpRequest requestWithURL:_audioFileURL];
    if (_audioFileHost != nil){
        [_request setHost:_audioFileHost];
    }
    
    __unsafe_unretained _ZJAudioRemoteFileProvider *_self =self;
    [_request setCompleteBlock:^{
        [_self _reqeustComplete];
    }];
    [_request setProgressBlock:^(float downloadProgress){
        [_self _requestDidReportProgress:downloadProgress];
    }];
    [_request setResponseBlock:^{
        [_self _requestDidReceiveResnponse];
    }];
    [_request setReceiveDataBlock:^(NSData *data){
        [_self _requestDidReceiveData:data];
    }];
}
-(void)_handleAudioFileStreamProperty:(AudioFileStreamPropertyID)propertyID
{
    if (propertyID == kAudioFileStreamProperty_ReadyToProducePackets){
        _readyToProductPackets = YES;
    }
}
- (void)_handleAudioFileStreamPackets:(const void *)packets
                        numberOfBytes:(UInt32)numberOfBytes
                      numberOfPackets:(UInt32)numberOfPackets
                   packetDescriptions:(AudioStreamPacketDescription *)packetDescriptioins
{
}
static void audio_file_stream_property_listener_proc(void* inClientData,
                                                     AudioFileStreamID inAudioFileStream,
                                                     AudioFileStreamPropertyID inPropertyID,
                                                     UInt32 *ioFlags)
{
    __unsafe_unretained _ZJAudioRemoteFileProvider *fileProder = (__bridge _ZJAudioRemoteFileProvider*)inClientData;
    [fileProder _handleAudioFileStreamProperty:inPropertyID];
}
static void audio_file_stream_packets_proc(void *inClientData,
                                           UInt32 inNumberBytes,
                                           UInt32 inNumberPackets,
                                           const void *inInputData,
                                           AudioStreamPacketDescription *inPacketDescription)
{
    __unsafe_unretained _ZJAudioRemoteFileProvider *fileProder = (__bridge _ZJAudioRemoteFileProvider*)inClientData;
    [fileProder _handleAudioFileStreamPackets:inClientData numberOfBytes:inNumberBytes numberOfPackets:inNumberPackets packetDescriptions:inPacketDescription];
}
-(void)_openAudioFileStream
{
    [self _openAudioFileStreamWithFileTypeHint:0];
}
-(void)_openAudioFileStreamWithFileTypeHint:(AudioFileTypeID)fileTypeHint
{
    OSStatus status = AudioFileStreamOpen((__bridge void*)self, audio_file_stream_property_listener_proc, audio_file_stream_packets_proc, fileTypeHint, &_audioFileStreamID);
    if (status != noErr){
        _audioFileStreamID = NULL;
    }
}
-(void)_closeAudioFileStream
{
    if (_audioFileStreamID != NULL){
        AudioFileStreamClose(_audioFileStreamID);
        _audioFileStreamID = NULL;
    }
}
-(NSArray*)_fallbackTypeIDs
{
    NSMutableArray *fallbackTypeIDs = [NSMutableArray array];
    NSMutableSet *fallbackTypeIDSet = [NSMutableSet set];
    
    struct{
        CFStringRef specifier;
        AudioFilePropertyID propertyID;
    } properties[]={
        {(__bridge CFStringRef)[self mimeType],kAudioFileGlobalInfo_TypesForMIMEType},
        {(__bridge CFStringRef)[self fileExtension],kAudioFileGlobalInfo_TypesForExtension}
    };
    const size_t numberOfProperties = sizeof(properties)/sizeof(properties[0]);
    for (size_t i = 0;i<numberOfProperties;++i){
        if (properties[i].specifier == NULL){
            continue;
        }
        UInt32 outSize = 0;
        OSStatus status;
        status = AudioFileGetGlobalInfoSize(properties[i].propertyID, sizeof(properties[i].specifier), &properties[i].specifier, &outSize);
        if (status != noErr){
            continue;
        }
        size_t count = outSize / sizeof(AudioFileTypeID);
        AudioFileTypeID *buffer = (AudioFileTypeID*)malloc(outSize);
        if (buffer == NULL) continue;
        status = AudioFileGetGlobalInfo(properties[i].propertyID, sizeof(properties[i].specifier), &properties[i].specifier, &outSize, buffer);
        if (status != noErr){
            free(buffer);
            continue;
        }
        for (size_t j =0;j<count;j++){
            NSNumber *tid = [NSNumber numberWithUnsignedLongLong:buffer[j]];
            if ([fallbackTypeIDSet containsObject:tid]) continue;
            [fallbackTypeIDs addObject:tid];
            [fallbackTypeIDSet addObject:tid];
        }
        free(buffer);
    }
    return fallbackTypeIDs;
}
-(NSString*)fileExtension
{
    if (_fileExtension == nil){
        _fileExtension = [[[[self audioFile] audioFileURL] path] pathExtension];
    }
    return _fileExtension;
}
-(NSUInteger)downloadSpeed{
    return [_request downloadSpeed];
}
-(BOOL)isReady
{
    if (!_requiresCompleteFile){
        return _readyToProductPackets;
    }
    return _requestCompleted;
}
@end
@implementation ZJAudioFileProvider
@synthesize audioFile = _audioFile;
@synthesize eventBlock = _eventBlock;
@synthesize cachedPath = _cachedPath;
@synthesize cachedURL = _cachedURL;
@synthesize mimeType = _mimeType;
@synthesize fileExtension = _fileExtension;
@synthesize sha256 = _sha256;
@synthesize mappedData = _mappedData;
@synthesize expectedLength = _expectedLength;
@synthesize receivedLength = _receivedLength;
@synthesize failed = _failed;

+(instancetype)_fileProviderWithAudioFile:(id<ZJAudioFile>)audioFile
{
    if (audioFile == nil) return nil;
    NSURL *audioFileURL = [audioFile audioFileURL];
    if (audioFileURL == nil) return nil;
    if ([audioFileURL isFileURL]){
        return [[_ZJAudioLocalFileProvider alloc]_initWithAudioFile:audioFile];
    }else{
        return [[_ZJAudioRemoteFileProvider alloc] _initWithAudioFile:audioFile];
    }
}
+(instancetype)fileProviderWithAudioFile:(id<ZJAudioFile>)audioFile
{
    if ((audioFile == gHintFile || [audioFile isEqual:gHintFile]) && gHintProvider != nil){
        ZJAudioFileProvider *provider = gHintProvider;
        gHintFile = nil;
        gHintProvider = nil;
        gLastProviderIsFinished =[provider isFinished];
        return provider;
    }
    gHintFile = nil;
    gHintProvider = nil;
    gLastProviderIsFinished = NO;
    return [self _fileProviderWithAudioFile:audioFile];
}
+(void)setHintWithAudioFile:(id<ZJAudioFile>)audioFile
{
    if (audioFile == gHintFile || [audioFile isEqual:gHintFile]){
        return;
    }
    gHintFile = nil;
    gHintProvider = nil;
    if (audioFile == nil) return;
    NSURL *audioFileURL = [audioFile audioFileURL];
    if (audioFileURL == nil) return;
    gHintFile = audioFile;
    if (gLastProviderIsFinished){
        gHintProvider = [self _fileProviderWithAudioFile:gHintFile];
    }
}
-(instancetype)_initWithAudioFile:(id<ZJAudioFile>)audioFile
{
    self = [super init];
    if (self){
        _audioFile = audioFile;
    }
    return self;
}
- (NSUInteger)downloadSpeed
{
    [self doesNotRecognizeSelector:_cmd];
    return 0;
}

- (BOOL)isReady
{
    [self doesNotRecognizeSelector:_cmd];
    return NO;
}

- (BOOL)isFinished
{
    [self doesNotRecognizeSelector:_cmd];
    return NO;
}

@end
























































