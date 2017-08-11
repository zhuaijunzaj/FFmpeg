//
//  FFmpegReader.cpp
//  FFMPEG
//
//  Created by 朱爱俊 on 2017/8/10.
//  Copyright © 2017年 朱爱俊. All rights reserved.
//

#include "FFmpegReader.hpp"

FFmpegReader::FFmpegReader():m_audioStreamIndex(-1),m_videoStreamIndex(-1),m_timeBase(0.0)
{
    av_register_all();
    avformat_network_init();
    memset(&mediaCtx, 0, sizeof(mediaCtx));
}
FFmpegReader::~FFmpegReader()
{
    
}
int FFmpegReader::openMedia(const char *mediaPath)
{
    if (mediaPath == NULL) return -1;
    fileId = fopen(mediaPath, "r");
    if (fileId == NULL) return -1;
    
    //open meida
    mediaCtx.pFormatCtx = avformat_alloc_context();
    int ret;
    ret = avformat_open_input(&mediaCtx.pFormatCtx, mediaPath, NULL, NULL);
    if(ret < 0) return -1;
    
    ret  = avformat_find_stream_info(mediaCtx.pFormatCtx, NULL);
    if (ret < 0) return -1;
    
    for (int i = 0; i < mediaCtx.pFormatCtx->nb_streams; i++){
        if (mediaCtx.pFormatCtx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO){
            m_videoStreamIndex = i;
        }else if (mediaCtx.pFormatCtx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO){
            m_audioStreamIndex = i;
        }
    }
    if (m_audioStreamIndex == -1)   return -1;
    if (m_videoStreamIndex == -1)   return -1;
    
    //configure audio
    AVCodecParameters *paudioCodecParam = mediaCtx.pFormatCtx->streams[m_audioStreamIndex]->codecpar;
    AVCodec *paudioCodec = avcodec_find_decoder(paudioCodecParam->codec_id);
    AVCodecContext *paudioCodexCtx = avcodec_alloc_context3(paudioCodec);
    avcodec_parameters_to_context(paudioCodexCtx, paudioCodecParam);
    AVStream *pstream = mediaCtx.pFormatCtx->streams[m_audioStreamIndex];
    
    m_timeBase = av_q2d(pstream->time_base);
    mediaCtx.hasAudio = true;
    mediaCtx.audioStreamIndex = m_audioStreamIndex;
    mediaCtx.pAudioCodecCtx = paudioCodexCtx;
    mediaCtx.pAudioCodecParams = paudioCodecParam;
    mediaCtx.nChannels = paudioCodecParam->channels;
    
    //configure video
    
    AVCodecParameters *pvideoCodecParam = mediaCtx.pFormatCtx->streams[m_videoStreamIndex]->codecpar;
    AVCodec *pvideoCodec = avcodec_find_decoder(pvideoCodecParam->codec_id);
    AVCodecContext *pvideoCodecCtx = avcodec_alloc_context3(pvideoCodec);
    avcodec_parameters_to_context(pvideoCodecCtx, pvideoCodecParam);
    pstream = mediaCtx.pFormatCtx->streams[m_videoStreamIndex];
    
    if (m_timeBase == 0){
        m_timeBase = av_q2d(pstream->time_base);
    }
    mediaCtx.hasVideo= true;
    mediaCtx.videoStreamIndex = m_videoStreamIndex;
    mediaCtx.pVideoCodecCtx = pvideoCodecCtx;
    mediaCtx.pVideoCodecParams = pvideoCodecParam;
    mediaCtx.videoWidth = pvideoCodecParam->width;
    mediaCtx.videoHeight = pvideoCodecParam->height;
    
    mediaCtx.duration = mediaCtx.pFormatCtx->duration/1000;
    return 0;
}

int FFmpegReader::readPacket(AVPacket *packet)
{
    int nReadRet = av_read_frame(mediaCtx.pFormatCtx, packet);
    if (nReadRet < 0) return -1;
    return nReadRet;
}
 MediaContext* FFmpegReader::getMediaCtx()
{
    return &mediaCtx;
}
void FFmpegReader::closeMedia()
{
    m_videoStreamIndex = -1;
    m_audioStreamIndex = -1;
    avformat_close_input(&mediaCtx.pFormatCtx);
    avcodec_free_context(&mediaCtx.pAudioCodecCtx);
    avcodec_free_context(&mediaCtx.pVideoCodecCtx);
    avformat_free_context(mediaCtx.pFormatCtx);
    memset(&mediaCtx, 0, sizeof(ZJMediaContext));
}














































