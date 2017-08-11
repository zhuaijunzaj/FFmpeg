//
//  ZJVideoDecoder.hpp
//  FFMPEG
//
//  Created by 朱爱俊 on 2017/8/10.
//  Copyright © 2017年 朱爱俊. All rights reserved.
//

#ifndef ZJVideoDecoder_hpp
#define ZJVideoDecoder_hpp

#include <stdio.h>
#include "FFmpegReader.hpp"

typedef struct {
    AVFrame *pFrame;
    uint64_t ntimestamp;
}VideoFrame;
class FFmpegVideoDecoder;

class ZJVideoDecoder{
public:
    ZJVideoDecoder();
    ~ZJVideoDecoder();
    
    int openDecoder(ZJMediaContext *mediaCtx);
    void closeDecoder();
    int getVideoFrame(VideoFrame *pFrameout);
private:
    FFmpegVideoDecoder *videoDecoder;
};
#endif /* ZJVideoDecoder_hpp */
