//
//  ZJPlayer.cpp
//  FFMPEG
//
//  Created by 朱爱俊 on 2017/8/10.
//  Copyright © 2017年 朱爱俊. All rights reserved.
//

#include "ZJPlayer.hpp"

ZJPlayer* ZJPlayer::minstance = NULL;

ZJPlayer* ZJPlayer::sharedInstance()
{
    if (minstance == NULL){
        minstance = new ZJPlayer();
    }
    return minstance;
}

ZJPlayer::ZJPlayer():pwindowWidth(0),pwindowHeight(0),mplayerStatus(ZJPlayerStatus_Initialized)
{
    mediaCtl = new MediaControl();
}
ZJPlayer::~ZJPlayer()
{
    if (mediaCtl) delete mediaCtl;
}
int ZJPlayer::openMedia(const char *path, float windowWidth, float windowHeght)
{
    pwindowHeight = windowHeght;
    pwindowWidth = windowWidth;
    if (path == NULL) return -1;
    int ret = checkNextStatus(ZJPlayerStatus_Opend);
    if (ret == Player_Err_None){
        mediaCtl->openMedia(path, windowWidth, windowHeght);
        pmediaContext = mediaCtl->mediaCtx();
    }
    return 0;
}
const ZJMediaContext* ZJPlayer::mediaContext()
{
    return pmediaContext;
}

PlayerStatus ZJPlayer::getPlayerStatus()
{
    return mplayerStatus;
}
//int ZJPlayer::play(float pos)
//{
//    if (checkNextStatus(ZJPlayerStatus_Playing) == 0){
//        
//    }
//}
int ZJPlayer::checkNextStatus(PlayerStatus status)
{
    int ret = Player_Err_UnKnown;
    switch (status) {
        case ZJPlayerStatus_Opend:
            if (mplayerStatus == ZJPlayerStatus_Initialized || mplayerStatus == ZJPlayerStatus_Closed){
                ret = Player_Err_None;
            }else if (mplayerStatus == ZJPlayerStatus_Unknown){
                ret = Player_Err_NotInited;
            }else{
                ret = Player_Err_MediaStillAct;
            }
            break;
        case ZJPlayerStatus_Playing:
            if (mplayerStatus == ZJPlayerStatus_Opend || mplayerStatus == ZJPlayerStatus_Paused){
                ret = Player_Err_None;
            }else if (mplayerStatus == ZJPlayerStatus_Playing){
                ret = Player_Err_MediaPlaying;
            }else{
                ret = Player_Err_NoMediaOpened;
            }
            break;
        case ZJPlayerStatus_Seeking:
            if (mplayerStatus == ZJPlayerStatus_Paused || mplayerStatus == ZJPlayerStatus_Playing){
                ret = Player_Err_None;
            }else if (mplayerStatus == ZJPlayerStatus_Seeking){
                ret = Player_Err_MediaSeeking;
            }else{
                ret = Player_Err_NoMeidaActive;
            }
            break;
        case ZJPlayerStatus_Paused:
            if (mplayerStatus == ZJPlayerStatus_Paused || mplayerStatus == ZJPlayerStatus_Seeking || mplayerStatus == ZJPlayerStatus_Playing){
                ret = Player_Err_None;
            }else{
                ret= Player_Err_NoMediaPlaying;
            }
            break;
        case ZJPlayerStatus_Closed:
            if (mplayerStatus == ZJPlayerStatus_Opend ||
                mplayerStatus == ZJPlayerStatus_Paused ||
                mplayerStatus == ZJPlayerStatus_Seeking ||
                mplayerStatus == ZJPlayerStatus_Playing){
                ret =Player_Err_None;
            }else{
                ret = Player_Err_NoMeidaActive;
            }
            break;
        default:
            break;
    }
    return ret;
}







































