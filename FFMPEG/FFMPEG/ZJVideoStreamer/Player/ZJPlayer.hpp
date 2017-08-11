//
//  ZJPlayer.hpp
//  FFMPEG
//
//  Created by 朱爱俊 on 2017/8/10.
//  Copyright © 2017年 朱爱俊. All rights reserved.
//

#ifndef ZJPlayer_hpp
#define ZJPlayer_hpp

#include <stdio.h>
#include "FFmpegReader.hpp"
#include "MediaControl.hpp"

#define Player_Err_None                 0x00000000
#define Player_Err_NotInited            0x0000A001
#define Player_Err_NoMediaOpened        0x0000A002
#define Player_Err_NoMediaPlaying       0x0000A003
#define Player_Err_NoMeidaActive        0x0000A004
#define Player_Err_MediaStillAct        0x0000A005
#define Player_Err_MediaPlaying         0x0000A006
#define Player_Err_MediaSeeking         0x0000A007
#define Player_Err_OpenFail             0x0000A008
#define Player_Err_SeekFailed           0x0000A009
#define Player_Err_OutOfDuraion         0x0000A00A
#define Player_Err_NoMediaContent       0x0000A00B
#define Player_Err_OpenAudioDecFail     0x0000A00C
#define Player_Err_OpenVideoDecFail     0x0000A00D
#define Player_Err_OpenAudioDevFail     0x0000A00E
#define Player_Err_OpenVideoDevFail     0x0000A00F
#define Player_Err_UnKnown              0xF000AFFF

typedef enum {
    ZJPlayerStatus_Initialized = 0,
    ZJPlayerStatus_Opend,
    ZJPlayerStatus_Playing,
    ZJPlayerStatus_Seeking,
    ZJPlayerStatus_Paused,
    ZJPlayerStatus_Closed,
    ZJPlayerStatus_Unknown = -1,
}PlayerStatus;

class ZJPlayer{
public:
    ~ZJPlayer();
    static ZJPlayer* sharedInstance();
    int openMedia(const char* path,float windowWidth,float windowHeght);
    int play(float pos = 0);
    int pause;
    int seek(float seekPos);
    int getDuration();
    int getPlayingPos();
    int getBufferingPos();
    PlayerStatus getPlayerStatus();
    const MediaContext *mediaContext();
    char* getVideoInfo(const char* key);
    void setVideoParam(const char* key,const char* value);
    void setPlayCallback(void* clientData,void(*callback)(void*,uint32_t msg));
    void resetWindowSize(float width,float height);
    void updateWindowSize(void *window,float width,float height);
private:
    ZJPlayer();
    ZJPlayer(const ZJPlayer&);
    ZJPlayer& operator = (const ZJPlayer&);
    int checkNextStatus(PlayerStatus status);
    static ZJPlayer *minstance;

    MediaControl *mediaCtl;
    MediaContext *pmediaContext;
    float    pwindowWidth;
    float    pwindowHeight;
    PlayerStatus mplayerStatus;
    
};
#endif /* ZJPlayer_hpp */
