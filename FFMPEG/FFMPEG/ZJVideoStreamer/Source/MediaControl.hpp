//
//  MediaControl.hpp
//  FFMPEG
//
//  Created by 朱爱俊 on 2017/8/10.
//  Copyright © 2017年 朱爱俊. All rights reserved.
//

#ifndef MediaControl_hpp
#define MediaControl_hpp

#include <stdio.h>
#include "ZJVideoDecoder.hpp"
#include "ZJVideoRender.hpp"
#include "FFmpegReader.hpp"


class MediaControl{
public:
    MediaControl();
    ~MediaControl();
    int openMedia(const char* path,float windowWidth,float windowHeght);
    MediaContext *mediaCtx();
private:
    ZJVideoDecoder *vDecoder;
    ZJVideoRender *vRender;
    FFmpegReader *vReader;
    
    bool hasVideo;
};
#endif /* MediaControl_hpp */
