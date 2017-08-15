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
    videoPacket = av_packet_alloc();
    videoPacket->data = NULL;
    videoPacket->size = 0;
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

int ZJVideoDecoder::flushPacket()
{
    int ret = videoDecoder->setInputFrmame(videoPacket);
    if (ret < 0){
        printf("decoder failed");
        return -1;
    }
    return 0;
}
int ZJVideoDecoder::flushDecoder(AVFrame *vFrame)
{
    VideoFrame *pFrame = NULL;
    int ret = videoDecoder->getOutputFrame(pFrame);
    if (ret < 0 && ret != AVERROR_EOF){
        av_packet_unref(videoPacket);
        return -1;
    }
    vFrame = pFrame->pFrame;
    return 0;
}
