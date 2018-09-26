//
//  AudioManager.m
//  AudioTool
//
//  Created by 熊清 on 2017/11/17.
//  Copyright © 2017年 GMI. All rights reserved.
//

#import "AudioManager.h"
#import "amrFileCodec.h"
#import "AudioRecoderPanel.h"

@interface AudioRecordPlay()<AVAudioRecorderDelegate,AVAudioPlayerDelegate>{
    NSDictionary *setting;
}

/**
 注册语音播放状态回调
 */
@property (strong,nonatomic) void(^playState)(int state);

@end

@implementation AudioRecordPlay

-(instancetype)initWith:(NSDictionary<NSString *,id> *)properties {
    self = [super init];
    if (self) {
        setting = properties;
    }
    return self;
}

#pragma mark --record audio
- (void)startRecord:(NSString *)audioPath{
    //禁止休眠
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    //输入声源
    NSArray* inputs = [AVAudioSession sharedInstance].availableInputs;
    if (inputs.count > 0) {
        [[AVAudioSession sharedInstance] setPreferredInput:inputs.lastObject error:nil];
    }
    //音频资源
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryRecord withOptions:AVAudioSessionCategoryOptionAllowBluetooth error:nil];
    
    recorder = [[AVAudioRecorder alloc] initWithURL:[NSURL fileURLWithPath:audioPath?audioPath:Audio_Record_Path] settings:setting?setting:Audio_Setting_Default error:&error];
    [recorder setMeteringEnabled:YES];
    if ([recorder prepareToRecord]) {
        [recorder record];
        NSLog(@"start record");
    }
}

- (void)cancelRecord
{
    NSLog(@"cancel record");
    NSURL *url = [[NSURL alloc] initWithString:recorder.url.absoluteString];
    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
    [url release];
    [recorder stop];
    [recorder release];
    recorder = nil;
    //取消禁止休眠
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    //释放音频资源占用
    [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
}

- (NSURL *)stopRecord {
    NSLog(@"stop record path=%@",recorder.url.absoluteString);
    NSURL *url = [[NSURL alloc]initWithString:recorder.url.absoluteString];
    [recorder stop];
    [recorder release];
    recorder = nil;
    //取消禁止休眠
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    //释放音频资源占用
    [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    return [url autorelease];
}

#pragma mark --play audio
//判断语音是否在播放
- (BOOL)isPlaying{
    if (player && player.playing) {
        return YES;
    }
    return NO;
}

-(void)playAudioFile:(NSString *)audioPath playState:(void(^)(int state))state{
    //若语音文件路径错误
    if (!audioPath || audioPath.length == 0) {
        NSLog(@"error audio path");
        return;
    }
    //判断是否正在播放该语音文件
    if (player.isPlaying) {
        if ([player.url isEqual:[NSURL fileURLWithPath:audioPath]]) {
            [self pausePlay];
            return;
        }
        [self stopPlay];
    }
    
    //amr文件播放
    NSData *data = [NSData dataWithContentsOfFile:audioPath];
    if (!data) {
        NSLog(@"error audio data");
        return;
    }
    
    NSLog(@"start decode");
    NSData *audioData = DecodeAMRToWAVE(data);
    NSLog(@"end decode");
    
    //播放前注册近距离事件
    [self registerProximityMonitoring];
    
    if (audioData) {//若是amr文件
        //判断是否正在播放该语音数据
        if (player.isPlaying) {
            if ([player.data isEqual:audioData]) {
                [self pausePlay];
                return;
            }
            [self stopPlay];
        }
        player = [[AVAudioPlayer alloc] initWithData:audioData error:&error];
    }else {//若是wav文件
        player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:audioPath] error:&error];
    }
    self.playState = state;
    player.delegate = self;
    [player prepareToPlay];
    [player setVolume:1.0];
    if(![player play]){
        [self sendStatus:1];
    } else {
        [self sendStatus:0];
    }
}

- (void)playAudioData:(NSData *)data playState:(void(^)(int state))state{
    if (!data) {
        NSLog(@"error audio data");
        return;
    }
    
    NSLog(@"start decode");
    NSData *audioData = DecodeAMRToWAVE(data);
    NSLog(@"end decode");
    if (!audioData) {//非amr文件
        audioData = data;
    }
    //播放前注册近距离事件
    [self registerProximityMonitoring];
    
    //判断是否正在播放该语音数据
    if (player.isPlaying) {
        if ([player.data isEqual:audioData]) {
            [self pausePlay];
            return;
        }
        [self stopPlay];
    }
    self.playState = state;
    player = [[AVAudioPlayer alloc] initWithData:audioData error:&error];
    player.delegate = self;
    [player prepareToPlay];
    [player setVolume:1.0];
    if(![player play]){
        [self sendStatus:1];
    } else {
        [self sendStatus:0];
    }
}

-(void)pausePlay{
    [self sendStatus:3];
}

-(void)stopPlay {
    [self sendStatus:1];
}

//0 播放 1 播放完成 2出错 3暂停播放
-(void)sendStatus:(int)status {
    if (self.playState) {
        self.playState(status);
    }
    if (status == 0) {
        return;
    }

    if (status == 3) {
        [player pause];
        return;
    }
    
    if (player != nil) {
        [player stop];
        [player prepareToPlay];
        [player release];
        player = nil;
    }
    //释放音频资源占用
    [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
}

- (void)registerProximityMonitoring{
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionAllowBluetooth error: &error];
    //添加近距离事件监听，添加前先设置为YES，如果设置完后还是NO的话，说明当前设备没有近距离传感器
    [[UIDevice currentDevice] setProximityMonitoringEnabled:YES];
    if ([UIDevice currentDevice].proximityMonitoringEnabled == YES) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sensorStateChange:)name:UIDeviceProximityStateDidChangeNotification object:nil];
    }
}

- (void)removeProximityMonitoring{
    //移除近距离事件监听，添加前先设置为YES，如果设置完后还是NO的话，说明当前设备没有近距离传感器
    [[UIDevice currentDevice] setProximityMonitoringEnabled:YES];
    if ([UIDevice currentDevice].proximityMonitoringEnabled == YES) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceProximityStateDidChangeNotification object:nil];
    }
    [[UIDevice currentDevice] setProximityMonitoringEnabled:NO];
}

#pragma mark --AVAudioPlayerDelegate
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    [self sendStatus:1];
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error{
    [self sendStatus:2];
}

#pragma mark - 处理近距离监听触发事件
-(void)sensorStateChange:(NSNotificationCenter *)notification{
    if ([UIDevice currentDevice].proximityMonitoringEnabled == YES && ![self isPlaying]) {
        //播放结束移除近距离事件
        [self removeProximityMonitoring];
    }
    
    if ([[UIDevice currentDevice] proximityState] == YES){//黑屏
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionAllowBluetooth error:nil];
    }else{//亮屏
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionAllowBluetooth error:nil];
    }
}

- (void)dealloc {
    [recorder dealloc];
    recorder = nil;
    [player stop];
    [player release];
    player = nil;
    _playState = nil;
    [_playState release];
    //释放音频资源占用
    [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    [super dealloc];
}

@end

@interface AudioManager(){
    AudioRecordPlay *audio;
    AudioRecoderPanel *audioRecoderPanel;
}
@end

@implementation AudioManager

static AudioManager * instance = nil;
+ (instancetype)sharedInstance{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AudioManager alloc] init];
        instance->audio = [[AudioRecordPlay alloc] init];
    });
    return instance;
}

- (UIView*)audioRecoderView:(void(^)(RECORD_STATE state))state{
    audioRecoderPanel = [AudioRecoderPanel loadNib];
    [audioRecoderPanel setCallback:state];
    return audioRecoderPanel;
}

- (AudioRecordPlay*)audioRecord{
    return audio;
}

- (NSString*)speechText{
    return audioRecoderPanel.speechString;
}

#pragma mark --class method
+ (NSTimeInterval)timeWithAudioPath:(NSString *)audioPath{
    NSData *data = [NSData dataWithContentsOfFile:audioPath];
    if (!data) {
        return 0;
    }
    NSError *error;
    AVAudioPlayer *play = [[AVAudioPlayer alloc] initWithData:data error:&error];
    if (error) {
        [play release];
        return 0;
    }
    NSTimeInterval time = [play duration] * 1000;
    [play release];
    return time;
}
+ (NSTimeInterval)timeWithAudioData:(NSData *)audioData{
    if (!audioData) {
        return 0;
    }
    NSError *error;
    AVAudioPlayer *play = [[AVAudioPlayer alloc] initWithData:audioData error:&error];
    if (error) {
        [play release];
        return 0;
    }
    NSTimeInterval time = ((int)[play duration]) * 1000;
    [play release];
    return time;
}
+ (NSData *)encodeAmr:(NSString *)audioPath{
    NSData *data = [NSData dataWithContentsOfFile:audioPath];
    if (!data) {
        return data;
    }
    return EncodeWAVEToAMR(data, 1, 16);
}
+ (NSData *)encodeAmrData:(NSData *)audioData{
    return EncodeWAVEToAMR(audioData, 1, 16);
}
+ (int)encodeWave:(NSString *)wavePath toAmr:(NSString *)amrPath{
    return EncodeWAVEFileToAMRFile(wavePath.UTF8String, amrPath.UTF8String, 1, 16);
}
+ (NSData *)decodeAmr:(NSString *)audioPath{
    NSData *data = [NSData dataWithContentsOfFile:audioPath];
    if (!data) {
        return data;
    }
    return DecodeAMRToWAVE(data);
}
+ (NSData *)decodeAmrData:(NSData *)audioData{
    return DecodeAMRToWAVE(audioData);
}
+ (int)decodeAmr:(NSString *)amrPath toWave:(NSString *)wavePath{
    return DecodeAMRFileToWAVEFile(wavePath.UTF8String, amrPath.UTF8String);
}

@end
