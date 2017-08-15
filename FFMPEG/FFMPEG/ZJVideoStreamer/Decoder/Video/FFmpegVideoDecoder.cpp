//
//  FFmpegVideoDecoder.cpp
//  FFMPEG
//
//  Created by 朱爱俊 on 2017/8/10.
//  Copyright © 2017年 朱爱俊. All rights reserved.
//

#include "FFmpegVideoDecoder.hpp"

FFmpegVideoDecoder::FFmpegVideoDecoder():m_timeBase(0)
{
    
}
FFmpegVideoDecoder::~FFmpegVideoDecoder()
{
    
}

int FFmpegVideoDecoder::openDecoder(ZJMediaContext *mediaCtx)
{
    if (mediaCtx == NULL) return -1;
    
    videoCodecCtx = mediaCtx->pVideoCodecCtx;
    videoParamsCtx = mediaCtx->pVideoCodecParams;
    videoCodecCtx->get_format = FFmpegVideoDecoder::getVideoDecoderPixFormat;
    AVStream *pStream = mediaCtx->pFormatCtx->streams[mediaCtx->videoStreamIndex];
    m_timeBase = av_q2d(pStream->time_base);
    AVCodec *pvideoCodec = avcodec_find_decoder(videoParamsCtx->codec_id);
    av_codec_set_pkt_timebase(videoCodecCtx, videoCodecCtx->time_base);
    
    if (pvideoCodec == NULL) return -1;
    if (avcodec_open2(videoCodecCtx, pvideoCodec, NULL) < 0) return -1;
    pVideoFrame = av_frame_alloc();
    if (pVideoFrame == NULL) return -1;
    return 0;
}

void FFmpegVideoDecoder::closeDecoder()
{
    if (pVideoFrame){
        av_free(pVideoFrame);
        pVideoFrame = NULL;
    }
    avcodec_close(videoCodecCtx);
}

int FFmpegVideoDecoder::getOutputFrame(VideoFrame *outFrame)
{
    int ret = avcodec_receive_frame(videoCodecCtx, pVideoFrame);
    if (ret == 0){
        uint64_t ntimeStamp = 0;
        if (pVideoFrame->pts != AV_NOPTS_VALUE){
            ntimeStamp = pVideoFrame->pts;
        }else if (pVideoFrame->pkt_dts != AV_NOPTS_VALUE){
            ntimeStamp = pVideoFrame->pkt_dts;
        }
        outFrame->pFrame = pVideoFrame;
        outFrame->ntimestamp = ntimeStamp;
    }
    return ret;
}
int FFmpegVideoDecoder::setInputFrmame(AVPacket *inoutPacket)
{
    int ret = avcodec_send_packet(videoCodecCtx, inoutPacket);
    if (ret == 0){
        av_packet_unref(inoutPacket);
        return -1;
    }
    return -1;
}
AVPixelFormat FFmpegVideoDecoder::getVideoDecoderPixFormat(AVCodecContext *context, const AVPixelFormat *formats)
{
    uint32_t i = 0;
    for (i = 0; formats[i] != AV_PIX_FMT_NONE; ++i)
    {
        printf("ffmpeg supported format[ %d ]: %s", i, av_get_pix_fmt_name(formats[i]));
    }
    for (auto j = 0; formats[j] != AV_PIX_FMT_NONE; ++j){
        if (formats[j] == AV_PIX_FMT_VIDEOTOOLBOX){
            auto result = av_videotoolbox_default_init(context);
            if (result < 0){
                return AV_PIX_FMT_YUV420P;
            }else{
                return AV_PIX_FMT_VIDEOTOOLBOX;
            }
        }
    }
    return formats[i-1];
}
















































