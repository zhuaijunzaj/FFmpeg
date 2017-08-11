//
//  ZJAudioHttpRequest.h
//  FFMPEG
//
//  Created by Kattern on 2017/7/20.
//  Copyright © 2017年 Kattern. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^ZJAudioHttpReqeustCompleteBlock)(void);
typedef void(^ZJAudioHttpRequestProgressBlock)(float downloadProgress);
typedef void(^ZJAudioHttpRequestDidReceiveResponseBlock)(void);
typedef void(^ZJAudioHttpRequestDidReceiveDataBlock)(NSData *data);

@interface ZJAudioHttpRequest : NSObject
@property (nonatomic, assign) NSTimeInterval timeoutInterval;
@property (nonatomic, strong) NSString *userAgnet;
@property (nonatomic, strong) NSString *host;

@property (nonatomic, strong, readonly) NSMutableData *responseData;
@property (nonatomic, copy, readonly)   NSString *responseString;
@property (nonatomic, strong, readonly) NSDictionary *responseHeader;
@property (nonatomic, assign, readonly) NSUInteger responseContentLength;
@property (nonatomic, copy, readonly)   NSString *statusMessage;
@property (nonatomic, assign,readonly) NSInteger statusCode;
@property (nonatomic, assign, readonly) NSUInteger downloadSpeed;
@property (nonatomic, assign, getter=isFailed) BOOL failed;

@property (nonatomic, copy) ZJAudioHttpReqeustCompleteBlock completeBlock;
@property (nonatomic, copy) ZJAudioHttpRequestProgressBlock  progressBlock;
@property (nonatomic, copy) ZJAudioHttpRequestDidReceiveDataBlock receiveDataBlock;
@property (nonatomic, copy) ZJAudioHttpRequestDidReceiveResponseBlock responseBlock;


+(instancetype)requestWithURL:(NSURL*)url;
-(instancetype)initWithURL:(NSURL*)url;
+(NSTimeInterval)defaultTimeoutInterval;
+(NSString*)defaultUserAgent;

-(void)start;
-(void)cancel;
@end
