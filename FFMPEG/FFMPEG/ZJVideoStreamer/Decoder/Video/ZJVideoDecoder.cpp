//
//  ZJVideoDecoder.cpp
//  FFMPEG
//
//  Created by 朱爱俊 on 2017/8/10.
//  Copyright © 2017年 朱爱俊. All rights reserved.
//

#include "ZJVideoDecoder.hpp"
#include "FFmpegVideoDecoder.hpp"

ZJVideoDecoder::ZJVideoDecoder()
{
    videoDecoder = new FFmpegVideoDecoder();
}

int ZJVideoDecoder::openDecoder(ZJMediaContext *mediaCtx)
{
    if (mediaCtx == NULL){
        return -1;
    }
    return videoDecoder->openDecoder(mediaCtx);
}

void ZJVideoDecoder::closeDecoder()
{
    videoDecoder->closeDecoder();
}
int getVideoFrame(VideoFrame *pFrameout)
{
    int ret = -1;
    if (pFrameout){
        
    }
    
    return ret;
}
