//
//  ZJVideoRender.hpp
//  FFMPEG
//
//  Created by 朱爱俊 on 2017/8/10.
//  Copyright © 2017年 朱爱俊. All rights reserved.
//

#ifndef ZJVideoRender_hpp
#define ZJVideoRender_hpp

#include <stdio.h>
#include "SDL.h"

class ZJVideoRender{
public:
    ZJVideoRender();
    ~ZJVideoRender();
    
    int renderInit(float width,float height);
private:
    SDL_Window *window;
    SDL_Renderer *sdlRender;
    SDL_Texture *sdlTextureRender;
    SDL_Rect    *sdlRect;
    float screen_w;
    float screen_h;
};
#endif /* ZJVideoRender_hpp */
