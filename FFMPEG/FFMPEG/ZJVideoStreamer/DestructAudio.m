//
//  DestructAudio.m
//  FFMPEG
//
//  Created by 朱爱俊 on 2017/8/3.
//  Copyright © 2017年 朱爱俊. All rights reserved.
//

#import "DestructAudio.h"
#import <libavformat/avformat.h>
#import <libavcodec/avcodec.h>
#import <libswscale/swscale.h>
#import <libavutil/imgutils.h>
#import <libavutil/samplefmt.h>
#import <libswresample/swresample.h>
#import "SDL.h"

static  Uint8  *audio_chunk;
static  Uint32  audio_len;
static  Uint8  *audio_pos;

@interface DestructAudio ()
{
    NSString *_path;
    NSString *outputFile;
    FILE *outputFileId;
    
    AVFormatContext *pFormatCtx;
    int i,videoindex,audioindex;
    AVCodecContext *pCodecCtx;
    AVCodecContext *pAudioCtx;
    
    AVCodec *pCodec;
    AVCodec *pAudioCodec;
    
    AVFrame *pFrame,*pFrameYUV;
    unsigned char *out_buffer;
    unsigned char *out_audio_buffer;
    AVPacket *packet;
    int y_size;
    
    int ret;
    struct SwsContext *img_convert_ctx;
    struct SwrContext *au_convert_ctx;
    
    int screen_w ;
    int screen_h ;
    SDL_Window *screen;
    SDL_Renderer *sdlRender;
    SDL_Texture *sdlTexture;
    SDL_Rect sdlRect;
    SDL_AudioSpec audioSpec;
    
    
}
@end
@implementation DestructAudio
-(id)initWithFilePath:(NSString*)path outputPath:(NSString*)outPath
{
    self = [super init];
    if (self){
        _path = path;
        outputFile = [[NSBundle mainBundle] pathForResource:@"output" ofType:@"mp3"];
        
        outputFileId = fopen([outPath UTF8String], "wb+");
        if (outputFileId == nil) return nil;
       
        av_register_all();
        
    }
    return self;
}
void  fill_audio(void *udata,Uint8 *stream,int len)
{
    SDL_memset(stream, 0, len);
    if (audio_len == 0) return;
    len = MIN(len, audio_len);
    SDL_MixAudio(stream, audio_pos, len, SDL_MIX_MAXVOLUME);
    audio_pos += len;
    audio_len -= len;
    
    
    
}
-(int)start
{
    pFormatCtx = avformat_alloc_context();
    if (avformat_open_input(&pFormatCtx, [_path UTF8String], NULL, NULL) < 0){
        NSLog(@"could not open input file");
        return -1;
    }
    if(avformat_find_stream_info(pFormatCtx, NULL) < 0){
        NSLog(@"Could not find stream information");
        return -1;
    }
    videoindex = -1;
    for (i = 0;i<pFormatCtx->nb_streams;i++){
        if (pFormatCtx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO){
            videoindex = i;
        }else if (pFormatCtx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO){
            audioindex = i;
        }
    }
    if (videoindex == -1){
        NSLog(@"could not find a video stream");
        return -1;
    }
    if (audioindex == -1){
        NSLog(@"could not find a audio stream");
        return -1;
    }
    
    pCodecCtx = avcodec_alloc_context3(NULL);
    if (pCodecCtx == NULL){
        NSLog(@"Could not allocate avcodecContext");
        return -1;
    }
    avcodec_parameters_to_context(pCodecCtx, pFormatCtx->streams[videoindex]->codecpar);
    pCodec = avcodec_find_decoder(pCodecCtx->codec_id);
    if (pCodec == NULL){
        NSLog(@"Codec not found");
        return -1;
    }
    if (avcodec_open2(pCodecCtx, pCodec, NULL) < 0){
        NSLog(@"Cound not open Codec");
        return -1;
    }
    
    //audio
    pAudioCtx = avcodec_alloc_context3(NULL);
    if (pAudioCtx == NULL){
        NSLog(@"Could not allocate audio strame");
        return -1;
    }
    avcodec_parameters_to_context(pAudioCtx, pFormatCtx->streams[audioindex]->codecpar);
    pAudioCodec = avcodec_find_decoder(pAudioCtx->codec_id);
    if (pAudioCodec == NULL){
        NSLog(@"could not find auido context");
        return -1;
    }
    if (avcodec_open2(pAudioCtx, pAudioCodec, NULL) < 0){
        NSLog(@"could not open auido codec");
        return -1;
    }
    pFrame = av_frame_alloc();
    pFrameYUV = av_frame_alloc();
    AVFrame *audioFrame = av_frame_alloc();
    
    out_buffer = (uint8_t*)malloc(av_image_get_buffer_size(AV_PIX_FMT_YUV420P,pCodecCtx->width,pCodecCtx->height,1));
    av_image_fill_arrays(pFrameYUV->data, pFrameYUV->linesize, out_buffer, AV_PIX_FMT_YUV420P, pCodecCtx->width, pCodecCtx->height, 1);
    
    SDL_SetMainReady();
    if (SDL_Init(SDL_INIT_VIDEO|SDL_INIT_AUDIO|SDL_INIT_TIMER)){
        NSLog(@"SDL initialize failed:%s",SDL_GetError());
        return -1;
    }
    screen_w = pCodecCtx->width;
    screen_h = pCodecCtx->height;
    
    screen = SDL_CreateWindow("Demo", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, screen_w, screen_h, SDL_WINDOW_RESIZABLE|SDL_WINDOW_OPENGL);
    if (!screen){
        NSLog(@"cound not create window");
        return -1;
    }
    sdlRender = SDL_CreateRenderer(screen, -1, SDL_RENDERER_ACCELERATED);
    sdlTexture = SDL_CreateTexture(sdlRender, SDL_PIXELFORMAT_IYUV, SDL_TEXTUREACCESS_STREAMING, screen_w, screen_h);
    
    y_size = screen_w * screen_h;
    
    SDL_Event event;
    packet = av_packet_alloc();
    packet->data = NULL;
    packet->size = 0;
    
    //audio params
    uint64_t out_channel_layout=AV_CH_LAYOUT_STEREO;
    int out_channel_sample = pAudioCtx->frame_size;
    enum AVSampleFormat out_sample_fmt = AV_SAMPLE_FMT_S16;
    int out_sample = 44100;
    int out_channles = av_get_channel_layout_nb_channels(out_channel_layout);
    int out_buffer_size = av_samples_get_buffer_size(NULL, out_channles, out_channel_sample, out_sample_fmt, 1);
    out_audio_buffer = (uint8_t*)av_malloc(out_buffer_size*2);
    
    audioSpec.freq = out_sample;
    audioSpec.format = AUDIO_S16SYS;
    audioSpec.channels = out_channles;
    audioSpec.silence = 0;
    audioSpec.samples = out_channel_sample;
    audioSpec.callback =fill_audio;
    audioSpec.userdata = pAudioCtx;
    
    if (SDL_OpenAudio(&audioSpec, NULL) < 0){
        NSLog(@"could not open audio");
        return -1;
    }
    
    int64_t in_channel_layout = av_get_default_channel_layout(pAudioCtx->channels);
    au_convert_ctx = swr_alloc();
    au_convert_ctx = swr_alloc_set_opts(au_convert_ctx, out_channel_layout, out_sample_fmt, out_sample, in_channel_layout, pAudioCtx->sample_fmt, pAudioCtx->sample_rate, 0, NULL);
    swr_init(au_convert_ctx);
    
    SDL_PauseAudio(0);
    
    while (av_read_frame(pFormatCtx, packet) >= 0) {
        if (packet->stream_index == videoindex){
            ret = avcodec_send_packet(pCodecCtx, packet);
            if (ret < 0 && ret != AVERROR(EAGAIN) && ret != AVERROR_EOF){
                av_packet_unref(packet);
                NSLog(@"error:%s",av_err2str(ret));
                return ret;
            }
            for(;;){
                ret = avcodec_receive_frame(pCodecCtx, pFrame);
                if (ret < 0 && ret != AVERROR_EOF){
                    av_packet_unref(packet);
                    NSLog(@"error:%s",av_err2str(ret));
                    break;
                }
                img_convert_ctx =sws_getContext(pCodecCtx->width, pCodecCtx->height, pCodecCtx->pix_fmt, pCodecCtx->width, pCodecCtx->height, AV_PIX_FMT_YUV420P, SWS_BICUBIC, NULL, NULL, NULL);
                sws_scale(img_convert_ctx, (const uint8_t* const*)pFrame->data, pFrame->linesize, 0, pCodecCtx->height, pFrameYUV->data, pFrameYUV->linesize);
                sws_freeContext(img_convert_ctx);
                
                sdlRect.x = 0;
                sdlRect.y = 0;
                sdlRect.w = screen_w;
                sdlRect.h = screen_h;
                
                SDL_UpdateYUVTexture(sdlTexture, &sdlRect, pFrameYUV->data[0], pFrameYUV->linesize[0], pFrameYUV->data[1], pFrameYUV->linesize[1], pFrameYUV->data[2], pFrameYUV->linesize[2]);
                SDL_RenderClear(sdlRender);
                SDL_RenderCopy(sdlRender, sdlTexture, &sdlRect, &sdlRect);
                SDL_RenderPresent(sdlRender);
                SDL_Delay(20);
            }
        }else if (packet->stream_index == audioindex){
            
            ret = avcodec_send_packet(pAudioCtx, packet);
            if (ret < 0 && ret != AVERROR(EAGAIN) && ret != AVERROR_EOF){
                av_packet_unref(packet);
                NSLog(@"error:%s",av_err2str(ret));
                return ret;
            }
            for(;;){
                ret = avcodec_receive_frame(pAudioCtx, audioFrame);
                if (ret < 0 && ret != AVERROR_EOF){
                    av_packet_unref(packet);
                    NSLog(@"error:%s",av_err2str(ret));
                    break;
                }
                int64_t out_samples = av_rescale_rnd(swr_get_delay(au_convert_ctx, 48000) + pAudioCtx->sample_rate, 44100, 48000, AV_ROUND_UP);
                ret = swr_convert(au_convert_ctx, &out_audio_buffer, (int)out_samples, (const uint8_t**)pFrame->data, pFrame->nb_samples);
                if (ret < 0 && ret != AVERROR(EAGAIN) && ret != AVERROR_EOF){
                    av_packet_unref(packet);
                    NSLog(@"error:%s",av_err2str(ret));
                    return ret;
                }
                fwrite(out_audio_buffer, 1, out_buffer_size, outputFileId);
            }
            while (audio_len > 0) {
                SDL_Delay(1);
            }
            audio_chunk = (uint8_t*)out_audio_buffer;
            audio_len = out_buffer_size;
            audio_pos = audio_chunk;
        }
            av_packet_unref(packet);
            SDL_PollEvent(&event);
            switch (event.type) {
                case SDL_QUIT:
                    SDL_Quit();
                    return -1;
                    break;
                    
                default:
                    break;
            }
    }
    
    SDL_DestroyTexture(sdlTexture);
    av_free(pFrameYUV);
    avcodec_close(pCodecCtx);
    avformat_close_input(&pFormatCtx);
    return 0;
}
@end
















































