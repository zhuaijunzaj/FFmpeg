//
//  MediaControl.cpp
//  FFMPEG
//
//  Created by 朱爱俊 on 2017/8/10.
//  Copyright © 2017年 朱爱俊. All rights reserved.
//

#include "MediaControl.hpp"

MediaControl::MediaControl():hasVideo(false)
{
    vDecoder = new ZJVideoDecoder();
    vRender = new ZJVideoRender();
    vReader = new  FFmpegReader();
}
MediaControl::~MediaControl()
{
    if (vDecoder) delete vDecoder;
    if (vRender) delete vRender;
    if (vReader) delete vReader;
}
int MediaControl::openMedia(const char *path, float windowWidth, float windowHeght)
{
    if (path == NULL) return -1;
    int ret = vReader->openMedia(path);
    if (ret == 0){
        ZJMediaContext* mediaCtx = vReader->getMediaCtx();
        if (!mediaCtx || (!mediaCtx->hasVideo && !mediaCtx->hasAudio)){
            vReader->closeMedia();
            return -1;
        }
        if (mediaCtx->hasVideo){
            if (windowWidth > 0 && windowHeght > 0){
                ret = vDecoder->openDecoder(mediaCtx);
                if (ret == 0){
                    vRender->renderInit(windowWidth, windowHeght);
                }else{
                    vDecoder->closeDecoder();
                }
            }else{
                return -1;
            }
        }else{
            return -1;
        }
    }
    return 0;
}

MediaContext* MediaControl::mediaCtx()
{
    return vReader->getMediaCtx();
}

int MediaControl::play(float pos)
{
    if (pos > 0){
       int ret = vReader->setplayerPos(pos);
        if (ret == 0){
            AVPacket *packet = NULL;
            ret = vReader->readPacket(packet);
            if (ret == Source_Err_ReadVideoPkt) {
                ret = vDecoder->flushPacket();
                if (ret == 0){
                    do {
                        AVFrame *vFrame = av_frame_alloc();
                        ret = vDecoder->flushDecoder(vFrame);
                        vRender->renderVideo(mediaCtx(), vFrame);
                    } while (ret >= 0);
                }else{
                    return -1;
                }
            }else if (Source_Err_ReadAudioPkt){
                
            }
            return -1;
        }
    }
    return -1;
}
