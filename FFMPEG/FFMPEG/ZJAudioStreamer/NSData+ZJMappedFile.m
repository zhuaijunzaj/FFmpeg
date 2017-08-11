//
//  NSData+ZJMappedFile.m
//  FFMPEG
//
//  Created by Kattern on 2017/7/21.
//  Copyright © 2017年 Kattern. All rights reserved.
//

#import "NSData+ZJMappedFile.h"
#import <sys/types.h>
#import <sys/mman.h>

static NSMutableDictionary *get_size_map()
{
    static NSMutableDictionary *map = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = [[NSMutableDictionary alloc] init];
    });
    return map;
}
static void mmap_deallocate(void *ptr,void *info)
{
    NSNumber *key = [NSNumber numberWithUnsignedLongLong:(uintptr_t)ptr];
    NSNumber *fileSzie = nil;
    
    NSMutableDictionary *sizeMap = get_size_map();
    @synchronized (sizeMap) {
        fileSzie = [sizeMap objectForKey:key];
        [sizeMap removeObjectForKey:key];
    }
    size_t size = (size_t)[fileSzie unsignedLongLongValue];
    munmap(ptr, size);
}

static CFAllocatorRef get_mmap_dealloctor()
{
    static CFAllocatorRef dealloctor = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CFAllocatorContext context;
        bzero(&context, sizeof(context));
        context.deallocate = mmap_deallocate;
        
        dealloctor = CFAllocatorCreate(kCFAllocatorDefault, &context);
    });
    return dealloctor;
}

@implementation NSData (ZJMappedFile)
+(instancetype)zj_dataWithMappedContentsOfFile:(NSString *)path
{
    return [[self class] _zj_dataWithMappedContentFile:path modifiable:NO];
}
+(instancetype)zj_dataWithMappedContentsOfURL:(NSURL *)url
{
    return [[self class] zj_dataWithMappedContentsOfFile:[url path]];
}
+(instancetype)zj_modifiableDataMappedContentsOfURL:(NSURL *)url
{
    return [[self class] zj_modifiableDatahMappedContentsOfFile:[url path]];
}
+(instancetype)zj_modifiableDatahMappedContentsOfFile:(NSString *)path
{
    return [[self class] _zj_dataWithMappedContentFile:path modifiable:YES];
}

+(instancetype)_zj_dataWithMappedContentFile:(NSString*)path modifiable:(BOOL)modifiable
{
    NSFileHandle *fileHandle = nil;
    if (modifiable){
        fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:path];
    }else{
        fileHandle = [NSFileHandle fileHandleForReadingAtPath:path];
    }
    if (fileHandle == nil) return nil;
    int fd = [fileHandle fileDescriptor];
    if (fd < 0) return nil;
    off_t size = lseek(fd, 0, SEEK_END);
    if (size < 0) return nil;
    int protection = PROT_READ;
    if (modifiable){
        protection |= PROT_WRITE;
    }
    
    void *address = mmap(NULL, (size_t)size, protection, MAP_FILE|MAP_SHARED, fd, 0);
    if (address == MAP_FAILED) return nil;
    
    NSMutableDictionary *sizeMap = get_size_map();
    @synchronized (sizeMap) {
        [sizeMap setObject:[NSNumber numberWithUnsignedLongLong:(unsigned long long)size]
                    forKey:[NSNumber numberWithUnsignedLongLong:(uintptr_t)address]];
    }
    return CFBridgingRelease(CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, (const UInt8 *)address, (CFIndex)size,get_mmap_dealloctor()));
}
-(void)zj_synchronizeMappedFile
{
    NSNumber *key = [NSNumber numberWithUnsignedLongLong:(uintptr_t)[self bytes]];
    NSNumber *fileSize =nil;
    
    NSMutableDictionary *sizeMap = get_size_map();
    @synchronized (sizeMap) {
        fileSize = [sizeMap objectForKey:key];
    }
    if (fileSize == nil) return;
    size_t size = (size_t)[fileSize unsignedLongLongValue];
    msync((void *)[self bytes], size, MS_SYNC | MS_INVALIDATE);
}


@end
