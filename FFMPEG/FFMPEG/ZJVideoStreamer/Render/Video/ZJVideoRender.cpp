//
//  ZJVideoRender.cpp
//  FFMPEG
//
//  Created by 朱爱俊 on 2017/8/10.
//  Copyright © 2017年 朱爱俊. All rights reserved.
//

#include "ZJVideoRender.hpp"
#import <libavutil/imgutils.h>
#import <libswscale/swscale.h>

ZJVideoRender::ZJVideoRender():screen_h(0),screen_w(0)
{
    
}
ZJVideoRender::~ZJVideoRender()
{
    
}
int ZJVideoRender::renderInit(float width,float height)
{
    SDL_SetMainReady();
    if (SDL_Init(SDL_INIT_VIDEO|SDL_INIT_AUDIO|SDL_INIT_TIMER)){
        printf("SDL initialize failed:%s",SDL_GetError());
        return -1;
    }
    screen_w = width;
    screen_h = height;
    window = SDL_CreateWindow("ZJPlayer", 0, 0, width, height, SDL_WINDOW_FULLSCREEN);
    if (window == NULL) return -1;
    sdlRender = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
    sdlTextureRender = SDL_CreateTexture(sdlRender, SDL_PIXELFORMAT_IYUV, SDL_TEXTUREACCESS_STREAMING, screen_w, screen_h);
    out_buffer = (uint8_t*)malloc(av_image_get_buffer_size(AV_PIX_FMT_YUV420P,screen_w,screen_h,1));
    frameYUV = av_frame_alloc();
    av_image_fill_arrays(frameYUV->data, frameYUV->linesize, out_buffer, AV_PIX_FMT_YUV420P, screen_w, screen_h, 1);
    return 0;
}

int ZJVideoRender::renderVideo(ZJMediaContext *mediaCtx,AVFrame *pFrame)
{
    
    video_convert_ctx = sws_getContext(screen_w, screen_h, mediaCtx->pVideoCodecCtx->pix_fmt, screen_w, screen_h, AV_PIX_FMT_YUV420P, SWS_BICUBIC, NULL, NULL, NULL);
    sws_scale(video_convert_ctx, (const uint8_t* const*)pFrame->data, pFrame->linesize, 0, screen_h, frameYUV->data, frameYUV->linesize);
    sws_freeContext(video_convert_ctx);
    sdlRect.x = 0;
    sdlRect.y = 0;
    sdlRect.w = screen_w;
    sdlRect.h = screen_h;
    SDL_UpdateYUVTexture(sdlTextureRender, &sdlRect, frameYUV->data[0], frameYUV->linesize[0], frameYUV->data[1], frameYUV->linesize[1], frameYUV->data[2], frameYUV->linesize[2]);
    SDL_RenderClear(sdlRender);
    SDL_RenderCopy(sdlRender, sdlTextureRender, &sdlRect, &sdlRect);
    SDL_RenderPresent(sdlRender);
    SDL_Delay(20);
    return 0;
}
