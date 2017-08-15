//
//  FFmpegReader.hpp
//  FFMPEG
//
//  Created by 朱爱俊 on 2017/8/10.
//  Copyright © 2017年 朱爱俊. All rights reserved.
//

#ifndef FFmpegReader_hpp
#define FFmpegReader_hpp

#define Source_Err_None            0x00000000
#define Source_Err_ReadEOS         0x0000F001
#define Source_Err_OpenFaild       0x0000F002
#define Source_Err_SetPosFaild     0x0000F003
#define Source_Err_ReadAudioPkt    0x0000F004
#define Source_Err_ReadVideoPkt    0x0000F005
#define Source_Err_NoStreamInfo    0x0000F006
#define Source_Err_NoMediaTrack    0x0000F007
#define Source_Err_ReadPacketFaild 0x0000F008

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
    int setplayerPos(float pos);
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
