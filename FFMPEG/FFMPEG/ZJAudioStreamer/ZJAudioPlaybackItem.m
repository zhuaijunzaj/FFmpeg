//
//  ZJAudioPlaybackItem.m
//  FFMPEG
//
//  Created by Kattern on 2017/7/21.
//  Copyright © 2017年 Kattern. All rights reserved.
//

#import "ZJAudioPlaybackItem.h"
#import "ZJAudioFileProvider.h"
#import "ZJAudioFileProcessor.h"


@interface ZJAudioPlaybackItem ()
{
    ZJAudioFileProvider *_fileProvider;
    ZJAudioFileProcessor *_fileProcessor;
    AudioFileID _fileID;
    AudioStreamBasicDescription _fileformat;
    NSUInteger _bitRate;
    NSUInteger _dateOffset;
    NSUInteger _estimateDuration;
}
@end
@implementation ZJAudioPlaybackItem
@synthesize fileProvider = _fileProvider;
@synthesize filePreprocessor = _filePreprocessor;
@synthesize fileID = _fileID;
@synthesize fileFormat = _fileFormat;
@synthesize bitRate = _bitRate;
@synthesize dataOffset = _dataOffset;
@synthesize estimatedDuration = _estimateDuration;

-(id<ZJAudioFile>)audioFile
{
    return [_fileProvider audioFile];
}
-(NSURL*)cachedURL
{
    return [_fileProvider cachedURL];
}
-(BOOL)isOpened
{
    return _fileID != NULL;
}
-(NSData*)mappedData
{
    return [_fileProvider mappedData];
}
static OSStatus audio_file_read(void *inClientData,SInt64 inPosition,UInt32 requestCount,void *buffer,UInt32 *actualCount)
{
    __unsafe_unretained ZJAudioPlaybackItem *item = (__bridge ZJAudioPlaybackItem*)inClientData;
    if(inPosition + requestCount > [[item mappedData] length]){
        if (inPosition >= [[item mappedData] length]){
            *actualCount = 0;
        }else{
            *actualCount = (UInt32)(SInt64)([[item mappedData] length] - inPosition);
        }
    }else{
        *actualCount =requestCount;
    }
    if (*actualCount == 0){
        return noErr;
    }
    if ([item filePreprocessor] == nil){
        memcpy(buffer, (uint8_t*)[[item mappedData] bytes]+inPosition, *actualCount);
    }else{
        NSData *input = [NSData dataWithBytesNoCopy:(uint8_t*)[[item mappedData] bytes] + inPosition length:*actualCount freeWhenDone:NO];
        NSData *output = [[item filePreprocessor] hanldeData:input offset:(NSUInteger)inPosition];
        memcpy(buffer, [output bytes], [output length]);
    }
    return noErr;
}
static SInt64 audio_file_get_size(void *clientData)
{
    __unsafe_unretained ZJAudioPlaybackItem *item = (__bridge ZJAudioPlaybackItem*)clientData;
    return (SInt64)[[item mappedData] length];
}
-(BOOL)_openWithFileTypeHint:(AudioFileTypeID)fileTypeHint
{
    OSStatus status;
    status = AudioFileOpenWithCallbacks((__bridge void*)self, audio_file_read, NULL, audio_file_get_size, NULL, fileTypeHint, &_fileID);
    return status == noErr;
}
-(BOOL)_openWithFallbacks
{
    NSArray *fallbackTypeIDS = [self _fallbackTypeIDs];
    for (NSNumber *typeIDNumber in fallbackTypeIDS){
        AudioFileTypeID typeID = (AudioFileTypeID)[typeIDNumber unsignedLongValue];
        if([self _openWithFileTypeHint:typeID]){
            return YES;
        }
    }
    return NO;
}


-(NSArray*)_fallbackTypeIDs
{
    NSMutableArray *fallbackTypeIDs = [NSMutableArray array];
    NSMutableSet *fallbackTypeIDSet = [NSMutableSet set];
    
    struct{
        CFStringRef specifier;
        AudioFilePropertyID propertyID;
    } properties[]={
        {(__bridge CFStringRef)[_fileProvider mimeType],kAudioFileGlobalInfo_TypesForMIMEType},
        {(__bridge CFStringRef)[_fileProvider fileExtension],kAudioFileGlobalInfo_TypesForExtension}
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


-(BOOL)open
{
    if ([self isOpened]){
        return YES;
    }
    if(![self _openWithFileTypeHint:0] && ![self _openWithFallbacks]){
        _fileID = NULL;
        return NO;
    }
    if (![self _fillFileFormat] || ![self _fillMiscProperties]){
        AudioFileClose(_fileID);
        _fileID = NULL;
        return NO;
    }
    return YES;
}

-(BOOL)_fillFileFormat
{
    UInt32 size;
    OSStatus status;
    status = AudioFileGetPropertyInfo(_fileID, kAudioFilePropertyFormatList, &size, NULL);
    if (status != noErr){
        return NO;
    }
    UInt32 numFormats = size / sizeof(AudioFormatListItem);
    AudioFormatListItem *formatList = (AudioFormatListItem*)malloc(size);
    
    status = AudioFileGetProperty(_fileID, kAudioFilePropertyFormatList, &size, formatList);
    if (status != noErr){
        free(formatList);
        return NO;
    }
    if (numFormats == 1){
        _fileFormat = formatList[0].mASBD;
    }else{
        status = AudioFormatGetPropertyInfo(kAudioFormatProperty_DecodeFormatIDs, 0, NULL, &size);
        if (status != noErr){
            free(formatList);
            return NO;
        }
        UInt32 numDecoders = size / sizeof(OSType);
        OSType *decoderIDs = (OSType*)malloc(size);
        status = AudioFormatGetProperty(kAudioFormatProperty_DecodeFormatIDs, 0, NULL, &size, decoderIDs);
        if (status != noErr){
            free(formatList);
            free(decoderIDs);
            return NO;
        }
        UInt32 i;
        for (i = 0; i< numFormats;++i){
            OSType decoderID = formatList[i].mASBD.mFormatID;
            BOOL found = NO;
            for (UInt32 j=0;j<numDecoders;++j){
                if (decoderID == decoderIDs[j]){
                    found = YES;
                    break;
                }
            }
            if (found){
                break;
            }
        }
        free(decoderIDs);
        if (i >= numFormats){
            free(formatList);
            return NO;
        }
        _fileFormat = formatList[i].mASBD;
    }
    free(formatList);
    return YES;
}

-(BOOL)_fillMiscProperties
{
    UInt32 size;
    OSStatus status;
    
    UInt32 bitRate = 0;
    size = sizeof(bitRate);
    status = AudioFileGetProperty(_fileID, kAudioFilePropertyBitRate, &size, &bitRate);
    if (status != noErr){
        return NO;
    }
    _bitRate = bitRate;
    SInt64 dataOffset = 0;
    size = sizeof(dataOffset);
    status = AudioFileGetProperty(_fileID, kAudioFilePropertyDataOffset, &size, &dataOffset);
    if (status != noErr){
        return NO;
    }
    _dataOffset = (NSUInteger)dataOffset;
    Float64 estimateDuration = 0.0;
    size = sizeof(estimateDuration);
    status = AudioFileGetProperty(_fileID, kAudioFilePropertyEstimatedDuration, &size, &estimateDuration);
    if (status != noErr){
        return NO;
    }
    _estimateDuration = estimateDuration *1000.0;
    return YES;
}

-(void)close
{
    if (![self isOpened]) return;
    AudioFileClose(_fileID);
    _fileID = NULL;
}

+(instancetype)playbackItemWithFileProvider:(ZJAudioFileProvider *)fileProvider
{
    return [[[self class] alloc] initWithFileProvider:fileProvider];
}
-(instancetype)initWithFileProvider:(ZJAudioFileProvider*)fileProvider
{
    self = [super init];
    if (self){
        _fileProvider = fileProvider;
        if ([_fileProvider respondsToSelector:@selector(audioFileProcessor)]){
            _fileProcessor = [[self audioFile] audioFileProcessor];
        }
    }
    return self;
}

-(void)dealloc
{
    if ([self isOpened]){
        [self close];
    }
}


































@end
