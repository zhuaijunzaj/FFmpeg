//
//  NSData+ZJMappedFile.h
//  FFMPEG
//
//  Created by Kattern on 2017/7/21.
//  Copyright © 2017年 Kattern. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (ZJMappedFile)
+(instancetype)zj_dataWithMappedContentsOfFile:(NSString*)path;
+(instancetype)zj_dataWithMappedContentsOfURL:(NSURL *)url;

+(instancetype)zj_modifiableDatahMappedContentsOfFile:(NSString*)path;
+(instancetype)zj_modifiableDataMappedContentsOfURL:(NSURL*)url;

-(void)zj_synchronizeMappedFile;
@end
