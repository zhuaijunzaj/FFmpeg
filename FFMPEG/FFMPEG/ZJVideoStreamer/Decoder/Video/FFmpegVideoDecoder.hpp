//
//  FFmpegVideoDecoder.hpp
//  FFMPEG
//
//  Created by 朱爱俊 on 2017/8/10.
//  Copyright © 2017年 朱爱俊. All rights reserved.
//

#ifndef FFmpegVideoDecoder_hpp
#define FFmpegVideoDecoder_hpp

#include <stdio.h>
extern "C"
{
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/pixdesc.h>
#include <libavcodec/videotoolbox.h>
};

#include "ZJVideoDecoder.hpp"

class FFmpegVideoDecoder{
public:
    FFmpegVideoDecoder();
    ~FFmpegVideoDecoder();
    
    int openDecoder(ZJMediaContext *mediaCtx);
    void closeDecoder();
    int getOutputFrame(VideoFrame *outFrame);
private:
    
    static AVPixelFormat getVideoDecoderPixFormat(AVCodecContext* context, AVPixelFormat const formats[]);
    
    AVCodecContext *videoCodecCtx;
    AVCodecParameters *videoParamsCtx;
    double m_timeBase;
    AVFrame *pVideoFrame;
};
#endif /* FFmpegVideoDecoder_hpp */
