//
//  ZJAudioDecoder.m
//  FFMPEG
//
//  Created by Kattern on 2017/7/22.
//  Copyright © 2017年 Kattern. All rights reserved.
//

#import "ZJAudioDecoder.h"
#import "ZJAudioFileProvider.h"
#import "ZJAudioPlaybackItem.h"
#import "ZJAudioPCM.h"
#include <AudioToolbox/AudioToolbox.h>
#include <pthread.h>

typedef struct {
    AudioFileID afid;
    SInt64 pos;
    void *srcBuffer;
    UInt32 srcBufferSize;
    AudioStreamBasicDescription srcFormat;
    UInt32 srcSizePerPacket;
    UInt32 numPacketsPerRead;
    AudioStreamPacketDescription *pktDecs;
}AudioFileIO;

typedef struct{
    AudioStreamBasicDescription inputFormat;
    AudioStreamBasicDescription outputFormat;
    AudioFileIO afio;
    
    SInt64 decodeValidFrmaes;
    AudioStreamPacketDescription *outputPktDecs;
    
    UInt32 outputBufferSize;
    void *outputBuffer;
    UInt32 numOutputPackets;
    SInt64 outputPos;
    pthread_mutex_t mutex;
}DecodingContext;

@interface ZJAudioDecoder()
{
    ZJAudioPlaybackItem *_playbackItem;
    ZJAudioPCM *_lpcm;
    
    AudioStreamBasicDescription _outputFormat;
    AudioConverterRef _audioConverter;
    
    NSUInteger _bufferSize;
    DecodingContext _decodingContex;
    BOOL _decodingContextInitialized;
}

@end
@implementation ZJAudioDecoder
@synthesize playbackItem = _playbackItem;
@synthesize lpcm = _lpcm;

+(AudioStreamBasicDescription)defaultOutputFormat
{
    static AudioStreamBasicDescription defaultOutputFormat;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultOutputFormat.mFormatID = kAudioFormatLinearPCM;
        defaultOutputFormat.mSampleRate = 44100;
        defaultOutputFormat.mBitsPerChannel = 16;
        defaultOutputFormat.mChannelsPerFrame = 2;
        defaultOutputFormat.mBytesPerFrame = defaultOutputFormat.mChannelsPerFrame *(defaultOutputFormat.mBitsPerChannel / 8);
        defaultOutputFormat.mFramesPerPacket = 1;
        defaultOutputFormat.mBytesPerPacket = defaultOutputFormat.mFramesPerPacket * defaultOutputFormat.mBytesPerFrame;
        defaultOutputFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    });
    return defaultOutputFormat;
}
+(instancetype)decoderWithPlaybackItem:(ZJAudioPlaybackItem *)playbackItem bufferSize:(NSUInteger)bufferSize
{
    return [[[self class] alloc] initWithPlaybackItem:playbackItem bufferSize:bufferSize];
}
-(instancetype)initWithPlaybackItem:(ZJAudioPlaybackItem *)playbackItem bufferSize:(NSUInteger)bufferSize
{
    self = [super init];
    if (self){
        _playbackItem = playbackItem;
        _bufferSize = bufferSize;
        _lpcm = [[ZJAudioPCM alloc] init];
        _outputFormat = [[self class] defaultOutputFormat];
        
        [self _createAudioConverter];
        if (_audioConverter == nil) return nil;
    }
    return self;
}
-(void)dealloc
{
    if (_decodingContextInitialized){
        [self tearDown];
    }
    if (_audioConverter != NULL){
        AudioConverterDispose(_audioConverter);
    }
}
-(void)_createAudioConverter
{
    AudioStreamBasicDescription inputFormat = [_playbackItem fileFormat];
    OSStatus status = AudioConverterNew(&inputFormat, &_outputFormat, &_audioConverter);
    if(status != noErr){
        _audioConverter = NULL;
    }
}
-(void)_fillMagicCookieForAudioFileID:(AudioFileID)inputFile
{
    UInt32 cookSize = 0;
    OSStatus status = AudioFileGetPropertyInfo(inputFile, kAudioFilePropertyMagicCookieData, &cookSize, NULL);
    if (status != noErr){
        return;
    }
    if (status == noErr && cookSize > 0){
        void *cookie = malloc(cookSize);
        status= AudioFileGetProperty(inputFile, kAudioFilePropertyMagicCookieData, &cookSize, cookie);
        if (status != noErr){
            free(cookie);
            return;
        }
        status = AudioConverterSetProperty(_audioConverter, kAudioConverterDecompressionMagicCookie, cookSize, cookie);
        free(cookie);
        if (status != noErr){
            return;
        }
    }
}
-(BOOL)setUp
{
    if(_decodingContextInitialized){
        return YES;
    }
    AudioFileID inputFile = [_playbackItem fileID];
    if (inputFile == NULL) return NO;
    
    _decodingContex.inputFormat = [_playbackItem fileFormat];
    _decodingContex.outputFormat = _outputFormat;
    [self _fillMagicCookieForAudioFileID:inputFile];
    UInt32 size;
    OSStatus status;
    
    size = sizeof(_decodingContex.inputFormat);
    status = AudioConverterGetProperty(_audioConverter, kAudioConverterCurrentInputStreamDescription,&size, &_decodingContex.inputFormat);
    if (status != noErr){
        return NO;
    }
    AudioStreamBasicDescription baseFormat;
    UInt32 propertySize = sizeof(baseFormat);
    AudioFileGetProperty(inputFile, kAudioFilePropertyDataFormat, &propertySize, &baseFormat);
    
    double actualToBaseSampleRation = 1.0;
    if (_decodingContex.inputFormat.mSampleRate != baseFormat.mSampleRate && _decodingContex.inputFormat.mSampleRate != 0.0 && baseFormat.mSampleRate != 0.0){
        actualToBaseSampleRation = _decodingContex.inputFormat.mSampleRate / baseFormat.mSampleRate;
    }
    double srcRation = 0.0;
    if (_decodingContex.outputFormat.mSampleRate != 0.0 && _decodingContex.inputFormat.mSampleRate != 0.0){
        srcRation = _decodingContex.outputFormat.mSampleRate / _decodingContex.inputFormat.mSampleRate;
    }
    _decodingContex.decodeValidFrmaes = 0;
    AudioFilePacketTableInfo srcPti;
    if (_decodingContex.inputFormat.mBitsPerChannel == 0){
        size = sizeof(srcPti);
        status = AudioFileGetProperty(inputFile, kAudioFilePropertyPacketTableInfo, &size, &srcPti);
        if (status == noErr){
            _decodingContex.decodeValidFrmaes = (SInt64)(actualToBaseSampleRation *srcRation * srcPti.mNumberValidFrames + 0.5);
            
            AudioConverterPrimeInfo primeInfo ;
            primeInfo.leadingFrames = (UInt32)(srcPti.mPrimingFrames *actualToBaseSampleRation +0.5);
            primeInfo.trailingFrames = 0;
            
            status = AudioConverterSetProperty(_audioConverter, kAudioConverterPrimeInfo, sizeof(primeInfo), &primeInfo);
            if (status != noErr) return NO;
        }
    }
    
    _decodingContex.afio.afid = inputFile;
    _decodingContex.afio.srcBufferSize = (UInt32)_bufferSize;
    _decodingContex.afio.srcBuffer = malloc(_decodingContex.afio.srcBufferSize);
    _decodingContex.afio.pos = 0;
    _decodingContex.afio.srcFormat = _decodingContex.inputFormat;
    
    if (_decodingContex.inputFormat.mBytesPerPacket == 0){
        size = sizeof(_decodingContex.afio.srcSizePerPacket);
        status = AudioFileGetProperty(inputFile, kAudioFilePropertyDeferSizeUpdates, &size, &_decodingContex.afio.srcSizePerPacket);
        if (status != noErr){
            free(_decodingContex.afio.srcBuffer);
            return NO;
        }
        _decodingContex.afio.numPacketsPerRead = _decodingContex.afio.srcBufferSize / _decodingContex.afio.srcSizePerPacket;
        _decodingContex.afio.pktDecs = (AudioStreamPacketDescription*)malloc(sizeof(AudioStreamPacketDescription)*_decodingContex.afio.numPacketsPerRead);
    }else{
        _decodingContex.afio.srcSizePerPacket = _decodingContex.inputFormat.mBytesPerPacket;
        _decodingContex.afio.numPacketsPerRead = _decodingContex.afio.srcBufferSize / _decodingContex.afio.srcSizePerPacket;
        _decodingContex.afio.pktDecs = NULL;
    }
    _decodingContex.outputPktDecs = NULL;
    UInt32 outputSizePerPacket = _decodingContex.outputFormat.mBytesPerPacket;
    _decodingContex.outputBufferSize = (UInt32)_bufferSize;
    _decodingContex.outputBuffer = malloc(_decodingContex.outputBufferSize);
    if (outputSizePerPacket == 0){
        size = sizeof(outputSizePerPacket);
        status = AudioConverterGetProperty(_audioConverter, kAudioConverterPropertyMaximumOutputPacketSize, &size, &outputSizePerPacket);
        if (status != noErr){
            free(_decodingContex.outputBuffer);
            free(_decodingContex.afio.srcBuffer);
            if (_decodingContex.afio.pktDecs != NULL){
                free(_decodingContex.afio.pktDecs);
            }
            return NO;
        }
        _decodingContex.outputPktDecs = (AudioStreamPacketDescription*)malloc(sizeof(AudioStreamPacketDescription)*_decodingContex.outputBufferSize / outputSizePerPacket);
    }
    _decodingContex.numOutputPackets = _decodingContex.outputBufferSize / outputSizePerPacket;
    _decodingContex.outputPos = 0;
    pthread_mutex_init(&_decodingContex.mutex, NULL);
    _decodingContextInitialized = YES;
    return YES;
    
}
-(void)tearDown
{
    if (!_decodingContextInitialized){
        return;
    }
    free(_decodingContex.afio.srcBuffer);
    free(_decodingContex.outputBuffer);
    if (_decodingContex.afio.pktDecs != NULL){
        free(_decodingContex.afio.pktDecs);
    }
    if (_decodingContex.outputPktDecs != NULL){
        free(_decodingContex.outputPktDecs);
    }
    pthread_mutex_destroy(&_decodingContex.mutex);
    _decodingContextInitialized = NO;
        
}
static OSStatus decoder_data_proc(AudioConverterRef inAudioConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription **outDataPacketDescription, void *inUserData)
{
    AudioFileIO *aifo = (AudioFileIO*)inUserData;
    if (*ioNumberDataPackets > aifo->numPacketsPerRead){
        *ioNumberDataPackets = aifo->numPacketsPerRead;
    }
    UInt32 outNumBytes ;
    OSStatus status = AudioFileReadPackets(aifo->afid, FALSE, &outNumBytes, aifo->pktDecs, aifo->pos, ioNumberDataPackets, aifo->srcBuffer);
    if (status != noErr){
        return  status;
    }
    aifo->pos += *ioNumberDataPackets;
    ioData->mBuffers[0].mData = aifo->srcBuffer;
    ioData->mBuffers[0].mDataByteSize = outNumBytes;
    ioData->mBuffers[0].mNumberChannels =aifo->srcFormat.mChannelsPerFrame;
    
    if (outDataPacketDescription != NULL){
        *outDataPacketDescription = aifo->pktDecs;
    }
    return noErr;
}
-(ZJAudioDecoderStatus)decodeOnce
{
    if (!_decodingContextInitialized){
        return ZJAudioDecoderFailed;
    }
    pthread_mutex_lock(&_decodingContex.mutex);
    ZJAudioFileProvider *provider = [_playbackItem fileProvider];
    if ([provider isFailed]){
        [_lpcm setEnd:YES];
        pthread_mutex_unlock(&_decodingContex.mutex);
        return ZJAudioDecoderFailed;
    }
    if (![provider isFinished]){
        NSUInteger dataOffset = [_playbackItem dataOffset];
        NSUInteger expectedDataLength = [provider expectedLength];
        NSInteger receiveDataLength = [provider receivedLength] - dataOffset;
        
        SInt64 packetNumber = _decodingContex.afio.pos + _decodingContex.afio.numPacketsPerRead;
        SInt64 packetDataOfferst = packetNumber * _decodingContex.afio.srcSizePerPacket;
        
        SInt64 bytesPerPacket = _decodingContex.afio.srcSizePerPacket;
        SInt64 bytesPerPerRead = bytesPerPacket * _decodingContex.afio.numPacketsPerRead;
        
        SInt64 framesPerPacket = _decodingContex.inputFormat.mFramesPerPacket;
        double inetrvalPerPacket = 1000.0/_decodingContex.inputFormat.mSampleRate * framesPerPacket;
        double intervalPerRead = inetrvalPerPacket / bytesPerPacket *bytesPerPerRead;
        
        double downloadTime = 1000.0 * (bytesPerPerRead - (receiveDataLength - packetDataOfferst)) / [provider downloadSpeed];
        SInt64 bytesRemaining =(SInt64)( expectedDataLength - (NSUInteger)receiveDataLength);
        
        if(receiveDataLength < packetDataOfferst || (bytesRemaining > 0 && downloadTime > intervalPerRead)){
            pthread_mutex_unlock(&_decodingContex.mutex);
            return  ZJAudioDecoderWaiting;
        }
    }
    AudioBufferList fillBufList;
    fillBufList.mNumberBuffers = 1;
    fillBufList.mBuffers[0].mNumberChannels = _decodingContex.inputFormat.mChannelsPerFrame;
    fillBufList.mBuffers[0].mDataByteSize = _decodingContex.outputBufferSize;
    fillBufList.mBuffers[0].mData = _decodingContex.outputBuffer;
    
    OSStatus status;
    UInt32 ioOutputDataPackets = _decodingContex.numOutputPackets;
    status = AudioConverterFillComplexBuffer(_audioConverter, decoder_data_proc, &_decodingContex.afio, &ioOutputDataPackets, &fillBufList, _decodingContex.outputPktDecs);
    if (status != noErr){
        pthread_mutex_unlock(&_decodingContex.mutex);
        return ZJAudioDecoderFailed;
    }
    if (ioOutputDataPackets == 0){
        [_lpcm setEnd:YES];
        pthread_mutex_unlock(&_decodingContex.mutex);
        return ZJAudioDecoderEndEncountered;
    }
    SInt64 frame1 = _decodingContex.outputPos + ioOutputDataPackets;
    if (_decodingContex.decodeValidFrmaes != 0 && frame1 > _decodingContex.decodeValidFrmaes){
        SInt64 frameTotrim64 = frame1 - _decodingContex.decodeValidFrmaes;
        UInt32 framesToTrim = (frameTotrim64 > ioOutputDataPackets) ? ioOutputDataPackets:(UInt32)frameTotrim64;
        int bytesTotrim = (int)(framesToTrim * _decodingContex.outputFormat.mBytesPerFrame);
        fillBufList.mBuffers[0].mDataByteSize -= (unsigned long)bytesTotrim;
        ioOutputDataPackets -= framesToTrim;
        
        if (ioOutputDataPackets == 0){
            [_lpcm setEnd:YES];
            pthread_mutex_unlock(&_decodingContex.mutex);
            return ZJAudioDecoderEndEncountered;
        }
    }
    
    UInt32 inNumBytes = fillBufList.mBuffers[0].mDataByteSize;
    [_lpcm writeBytes:_decodingContex.outputBuffer length:inNumBytes];
    _decodingContex.outputPos += ioOutputDataPackets;
    
    pthread_mutex_unlock(&_decodingContex.mutex);
    return ZJAudioDecoderSucceeded;
}
- (void)seekToTime:(NSUInteger)milliseconds
{
    if (!_decodingContextInitialized) {
        return;
    }
    
    pthread_mutex_lock(&_decodingContex.mutex);
    
    double frames = (double)milliseconds * _decodingContex.inputFormat.mSampleRate / 1000.0;
    double packets = frames / _decodingContex.inputFormat.mFramesPerPacket;
    SInt64 packetNumebr = (SInt64)lrint(floor(packets));
    
    _decodingContex.afio.pos = packetNumebr;
    _decodingContex.outputPos = packetNumebr * _decodingContex.inputFormat.mFramesPerPacket / _decodingContex.outputFormat.mFramesPerPacket;
    
    pthread_mutex_unlock(&_decodingContex.mutex);
}
@end




























































































