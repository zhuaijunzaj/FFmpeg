//
//  ZJAudioHttpRequest.m
//  FFMPEG
//
//  Created by Kattern on 2017/7/20.
//  Copyright © 2017年 Kattern. All rights reserved.
//

#import "ZJAudioHttpRequest.h"
#import <sys/types.h>
#import <sys/sysctl.h>
#import <pthread.h>
#import <UIKit/UIKit.h>

static struct{
    pthread_t thread;
    pthread_mutex_t mutex;
    pthread_cond_t cond;
    CFRunLoopRef runloop;
}controller;

static void* controller_main(void* info)
{
    pthread_setname_np("com.kattern.thread");
    pthread_mutex_lock(&controller.mutex);
    controller.runloop = CFRunLoopGetCurrent();
    pthread_mutex_unlock(&controller.mutex);
    pthread_cond_signal(&controller.cond);
    
    CFRunLoopSourceContext context;
    bzero(&context, sizeof(context));
    
    CFRunLoopSourceRef source = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context);
    CFRunLoopAddSource(controller.runloop, source, kCFRunLoopDefaultMode);
    CFRunLoopRun();
    
    CFRunLoopRemoveSource(controller.runloop, source, kCFRunLoopDefaultMode);
    CFRelease(source);
    
    pthread_mutex_destroy(&controller.mutex);
    pthread_cond_destroy(&controller.cond);
    return NULL;
}
static CFRunLoopRef controller_get_runloop()
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pthread_mutex_init(&controller.mutex, NULL);
        pthread_cond_init(&controller.cond, NULL);
        controller.runloop = NULL;
        
        pthread_create(&controller.thread, NULL, controller_main, NULL);
        pthread_mutex_lock(&controller.mutex);
        if(controller.runloop == NULL){
            pthread_cond_wait(&controller.cond, &controller.mutex);
        }
        pthread_mutex_unlock(&controller.mutex);
    });
    return controller.runloop;
}
@interface ZJAudioHttpRequest ()
{
    CFHTTPMessageRef _message;
    CFReadStreamRef _responseStream;
    NSInteger _statusCode;
    BOOL _failed;
    CFAbsoluteTime _startedTime;
    NSUInteger _receivedLength;
    NSString *_responseString;
}
@end
@implementation ZJAudioHttpRequest
+(instancetype)requestWithURL:(NSURL *)url
{
    if (url == nil) return nil;
    return [[[self class] alloc] initWithURL:url];
}
-(instancetype)initWithURL:(NSURL *)url
{
    self = [super init];
    if (self){
        _userAgnet = [[self class] defaultUserAgent];
        _timeoutInterval = [[self class] defaultTimeoutInterval];
        _message = CFHTTPMessageCreateRequest(kCFAllocatorDefault, CFSTR("GET"), (__bridge CFURLRef)url, kCFHTTPVersion1_1);
    }
    return self;
}
-(void)dealloc
{
    if (_responseStream != NULL){
         [self _closeResponseStream];
        CFRelease(_responseStream);
    }
    CFRelease(_message);
}
+(NSTimeInterval)defaultTimeoutInterval
{
    return 20.0;
}
+(NSString*)defaultUserAgent
{
    static NSString *defaultUserAgent = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
        NSString *appName = infoDict[@"CFBundleName"];
        NSString *shortVersion = infoDict[@"CFBundleShortVersionString"];
        NSString *bundleVersion = infoDict[@"CFBundleVersion"];
        
        NSString *deviceName = nil;
        NSString *systemName = nil;
        NSString *systemVersion = nil;
        
#if TARGET_OS_IPHONE
        
        UIDevice *device = [UIDevice currentDevice];
        deviceName = [device model];
        systemName = [device systemName];
        systemVersion = [device systemVersion];
        
#else /* TARGET_OS_IPHONE */
        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
        SInt32 versionMajor, versionMinor, versionBugFix;
        Gestalt(gestaltSystemVersionMajor, &versionMajor);
        Gestalt(gestaltSystemVersionMinor, &versionMinor);
        Gestalt(gestaltSystemVersionBugFix, &versionBugFix);
#pragma clang diagnostic pop
        int mib[2] = { CTL_HW, HW_MODEL };
        size_t len = 0;
        sysctl(mib, 2, NULL, &len, NULL, 0);
        char *hw_model = malloc(len);
        sysctl(mib, 2, hw_model, &len, NULL, 0);
        deviceName = [NSString stringWithFormat:@"Macintosh %s", hw_model];
        free(hw_model);
        
        systemName = @"Mac OS X";
        systemVersion = [NSString stringWithFormat:@"%u.%u.%u", versionMajor, versionMinor, versionBugFix];
        
#endif /* TARGET_OS_IPHONE */
        
        NSString *locale = [[NSLocale currentLocale] localeIdentifier];
        defaultUserAgent = [NSString stringWithFormat:@"%@ %@ build %@ (%@; %@ %@; %@)", appName, shortVersion, bundleVersion, deviceName, systemName, systemVersion, locale];
    });
    return defaultUserAgent;
}
-(void)_invokeCompleteBlock
{
    @synchronized (self) {
        if (_completeBlock){
            _completeBlock();
        }
    }
}
-(void)_invokeProgressBlockWithDownloadProgress:(float)downloadProgress
{
    @synchronized (self) {
        if (_progressBlock){
            _progressBlock(downloadProgress);
        }
    }
}
-(void)_invokeDidReceiveResponseBlock
{
    @synchronized (self) {
        if (_responseBlock){
            _responseBlock();
        }
    }
}
-(void)_invokeDidReceiveDataBlock:(NSData*)data
{
    @synchronized (self) {
        if (_receiveDataBlock){
            _receiveDataBlock(data);
        }
    }
}
-(void)_checkResponseContentLength
{
    if (_responseHeader == nil)
        return;
    NSString *string = _responseHeader[@"Content-Length"];
    _responseContentLength = (NSUInteger)[string integerValue];
}
-(void)_readResponseHeaders
{
    if (_responseHeader != nil) return;
    
    CFHTTPMessageRef message =  (CFHTTPMessageRef)CFReadStreamCopyProperty(_responseStream, kCFStreamPropertyHTTPResponseHeader);
    if (message == NULL) {
        CFRelease(message);
        return;
    }
    
    _responseHeader = CFBridgingRelease(CFHTTPMessageCopyAllHeaderFields(message));
    _statusCode  = CFHTTPMessageGetResponseStatusCode(message);
    _statusMessage = CFBridgingRelease(CFHTTPMessageCopyResponseStatusLine(message));
    CFRelease(message);
    
    [self _checkResponseContentLength];
    [self _invokeDidReceiveResponseBlock];
    
}
-(void)_updateProgress
{
    
    double downloadProgress;
    if (_responseContentLength == 0){
        if (_responseHeader != nil){
            downloadProgress = 1.0;
        }else{
            downloadProgress = 0.0;
        }
    }else{
        downloadProgress  = (double)_receivedLength / _responseContentLength;
    }
    [self _invokeProgressBlockWithDownloadProgress:downloadProgress];
    
}
-(void)_updateDownloadSpeed
{
    _downloadSpeed = _receivedLength/(CFAbsoluteTimeGetCurrent()-_startedTime);
}
-(void)_closeResponseStream
{
    CFReadStreamClose(_responseStream);
    CFReadStreamUnscheduleFromRunLoop(_responseStream, controller_get_runloop(), kCFRunLoopDefaultMode);
    CFReadStreamSetClient(_responseStream, kCFStreamEventNone, NULL, NULL);
}
-(void)_responseStreamHasBytesAvailable
{
    [self _readResponseHeaders];
    if (!CFReadStreamHasBytesAvailable(_responseStream)) return;
    
    CFIndex bufferSize;
    if (_responseContentLength > 262144) {
        bufferSize = 262144;
    }
    else if (_responseContentLength > 65536) {
        bufferSize = 65536;
    }
    else {
        bufferSize = 16384;
    }
    UInt8 buffer[bufferSize];
    CFIndex bytesRead = CFReadStreamRead(_responseStream, buffer, bufferSize);
    if (bytesRead < 0){
        [self _responseStreamErrorEncountered];
        return;
    }
    if (bytesRead > 0){
        NSData *data = [NSData dataWithBytes:buffer length:bufferSize];
        @synchronized (self) {
            if (_receiveDataBlock == NULL){
                if (_responseData == nil){
                    _responseData = [NSMutableData data];
                }
                [_responseData appendData:data];
            }else{
                [self _invokeDidReceiveDataBlock:data];
            }
            _receivedLength += (unsigned long)bytesRead;
            [self _updateProgress];
            [self _updateDownloadSpeed];
        }
    }
}
-(void)_responseStreameEndEncountered
{
    [self _readResponseHeaders];
    [self _invokeProgressBlockWithDownloadProgress:1.0];
    [self _invokeCompleteBlock];
}
-(void)_responseStreamErrorEncountered
{
    [self _readResponseHeaders];
    _failed = YES;
    [self _closeResponseStream];
    [self _invokeCompleteBlock];
}
static void response_stream_clinet_callback(CFReadStreamRef stream,CFStreamEventType type,void *clientCallBackInfo)
{
    @autoreleasepool {
        __unsafe_unretained ZJAudioHttpRequest *request = (__bridge ZJAudioHttpRequest*)clientCallBackInfo;
        @synchronized (request) {
            switch (type) {
                case kCFStreamEventHasBytesAvailable:
                    [request _responseStreamHasBytesAvailable];
                    break;
                case kCFStreamEventEndEncountered:
                    [request _responseStreameEndEncountered];
                    break;
                case kCFStreamEventErrorOccurred:
                    [request _responseStreamErrorEncountered];
                    break;
                default:
                    break;
            }
        }
    }
}

-(void)start
{
    if (_responseStream != NULL) return;
    CFHTTPMessageSetHeaderFieldValue(_message, CFSTR("User-Agent"), (__bridge CFStringRef)_userAgnet);
    if (_host != nil){
        CFHTTPMessageSetHeaderFieldValue(_message, CFSTR("Host"), (__bridge CFStringRef)_host);
    }
    _responseStream = CFReadStreamCreateForHTTPRequest(kCFAllocatorDefault, _message);
    CFReadStreamSetProperty(_responseStream, kCFStreamPropertyHTTPShouldAutoredirect, kCFBooleanTrue);
    CFReadStreamSetProperty(_responseStream, CFSTR("_kCFStreamPropertyReadTimeout"), (__bridge CFNumberRef)[NSNumber numberWithDouble:_timeoutInterval]);
    CFReadStreamSetProperty(_responseStream, CFSTR("_kCFStreamPropertyWriteTimeout"), (__bridge CFNumberRef)[NSNumber numberWithDouble:_timeoutInterval]);
    
    CFStreamClientContext context;
    bzero(&context, sizeof(context));
    context.info = (__bridge void*)self;
    CFReadStreamSetClient(_responseStream, kCFStreamEventHasBytesAvailable|kCFStreamEventEndEncountered|kCFStreamEventErrorOccurred, response_stream_clinet_callback, &context);
    CFReadStreamScheduleWithRunLoop(_responseStream, controller_get_runloop(), kCFRunLoopDefaultMode);
    CFReadStreamOpen(_responseStream);
    
    _startedTime = CFAbsoluteTimeGetCurrent();
    _downloadSpeed = 0;
}

-(void)cancel
{
    if (_responseStream == NULL || _failed) return;
    __block CFTypeRef __request =CFBridgingRetain(self);
    CFRunLoopPerformBlock(controller_get_runloop(), kCFRunLoopDefaultMode, ^{
        @autoreleasepool {
            [(__bridge  ZJAudioHttpRequest*)__request _closeResponseStream];
            CFBridgingRelease(__request);
        }
    });
}
-(NSString *)responseString
{
    if (_responseData == nil) return nil;
    if (_responseStream == nil){
        _responseString = [[NSString alloc] initWithData:_responseData encoding:NSUTF8StringEncoding];
    }
    return _responseString;
}



@end
