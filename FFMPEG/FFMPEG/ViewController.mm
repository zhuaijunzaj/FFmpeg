//
//  ViewController.m
//  FFMPEG
//
//  Created by Kattern on 2017/7/14.
//  Copyright © 2017年 Kattern. All rights reserved.
//

#import "ViewController.h"
#import "Track.h"
#import "ZJAudioStreamer.h"
#import "DestructAudio.h"
#import "SDL.h"
@interface ViewController ()
{
    ZJAudioStreamer *streamer;
   
}
@property (nonatomic, strong) NSData *metalData;
@end



@implementation ViewController
@synthesize metalData;




- (void)viewDidLoad {
    [super viewDidLoad];
//    NSString *path = [[NSBundle mainBundle] pathForResource:@"testVideo" ofType:@"mkv"];
//    DestructAudio *desAudio = [[DestructAudio alloc] initWithFilePath:path];
//    [desAudio start];
    //复制文件到沙盒
    NSString *path = [[NSBundle mainBundle] pathForResource:@"testVideo" ofType:@"mkv"];
    NSString *sandBoxPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    NSString *appLib = [sandBoxPath stringByAppendingString:@"/Caches"];
    NSString *filePath = [appLib stringByAppendingPathComponent:[path lastPathComponent]];
    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]){
        NSError *error;
        BOOL ret = [[NSFileManager defaultManager] copyItemAtPath:path toPath:filePath error:&error];
        NSLog(@"result = :%d",ret);
    }
    
    path = [[NSBundle mainBundle] pathForResource:@"output" ofType:@"mp3"];
    filePath = [appLib stringByAppendingPathComponent:[path lastPathComponent]];
    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]){
        NSError *error;
        BOOL ret = [[NSFileManager defaultManager] copyItemAtPath:path toPath:filePath error:&error];
        NSLog(@"result = :%d",ret);
    }

}

- (IBAction)playAction:(id)sender {
    NSString *sandBoxPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    NSString *appLib = [sandBoxPath stringByAppendingString:@"/Caches"];
    NSString *filePath = [appLib stringByAppendingPathComponent:@"testVideo.mkv"];
    NSString *outPath = [appLib stringByAppendingPathComponent:@"output.mp3"];
    DestructAudio *desAudio = [[DestructAudio alloc] initWithFilePath:filePath outputPath:outPath];
    [desAudio start];
//    Track *track = [[Track alloc] init];
//    track.artist = @"Kattern";
//    track.title = @"testDemo";
//    track.audioFileURL = [NSURL fileURLWithPath:filePath];
//    
//    if (streamer){
//        [streamer removeObserver:self forKeyPath:@"status"];
//        streamer = nil;
//    }
//    streamer = [ZJAudioStreamer streamerWithAudioFie:track];
//    [streamer play];
//    [ZJAudioStreamer setHintWithAudioFile:track];
// 
//    [streamer addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    
}
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"status"]){
        switch ([streamer status]) {
            case ZJAudioStreamerFinished:
                [self playAction:nil];
                break;
                
            default:
                break;
        }
    }
}
- (IBAction)setVolume:(id)sender {
    [streamer setVolume:[(UISlider*)sender value]];
}
- (IBAction)setSeekTime:(id)sender {
    [streamer setCurrentTime:[streamer duration]*[(UISlider*)sender value]];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
