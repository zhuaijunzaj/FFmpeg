//
//  ZJVideoRender.cpp
//  FFMPEG
//
//  Created by 朱爱俊 on 2017/8/10.
//  Copyright © 2017年 朱爱俊. All rights reserved.
//

#include "ZJVideoRender.hpp"


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
    
    return 0;
}
