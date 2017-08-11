//
//  FFmpegReader.hpp
//  FFMPEG
//
//  Created by 朱爱俊 on 2017/8/10.
//  Copyright © 2017年 朱爱俊. All rights reserved.
//

#ifndef FFmpegReader_hpp
#define FFmpegReader_hpp

#include <stdio.h>
extern "C"
{
#include <libavformat/avformat.h>
#include <libavutil/display.h>
};


typedef struct ZJMediaContext{
    
    bool hasVideo;
    bool hasAudio;
    int nChannels;
    float duration;
    int videoStreamIndex;
    int audioStreamIndex;
    float videoWidth;
    float videoHeight;

    AVFormatContext *pFormatCtx;
    AVCodecContext *pVideoCodecCtx;
    AVCodecContext *pAudioCodecCtx;
    AVCodecParameters *pVideoCodecParams;
    AVCodecParameters *pAudioCodecParams;
    
}MediaContext;

class FFmpegReader{
public:
    FFmpegReader();
    ~FFmpegReader();
    
    int openMedia(const char* mediaPath);
    void closeMedia();
    int readPacket(AVPacket *packet);
    MediaContext* getMediaCtx();
private:
    FILE *fileId;
    MediaContext mediaCtx;
    int m_audioStreamIndex;
    int m_videoStreamIndex;
    double m_timeBase;
};
#endif /* FFmpegRender_hpp */
