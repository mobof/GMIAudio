//
//  AudioManager.h
//  AudioTool
//
//  Created by 熊清 on 2017/11/17.
//  Copyright © 2017年 GMI. All rights reserved.
//

#define Audio_Setting_Default   @{AVFormatIDKey:[NSNumber numberWithInt:kAudioFormatLinearPCM],AVSampleRateKey:[NSNumber numberWithFloat:8000.00],AVNumberOfChannelsKey:[NSNumber numberWithInt:1],AVLinearPCMBitDepthKey:[NSNumber numberWithInt:16],AVLinearPCMIsNonInterleaved:[NSNumber numberWithBool:NO],AVLinearPCMIsFloatKey:[NSNumber numberWithBool:NO],AVLinearPCMIsBigEndianKey:[NSNumber numberWithBool:NO]}
#define Audio_Record_Path   [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat: @"%.0f", [NSDate timeIntervalSinceReferenceDate] * 1000.0]]

#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

@interface AudioRecordPlay : NSObject{
    AVAudioRecorder *recorder;
    AVAudioPlayer *player;
    NSError * error;
}

/**
 通过参数初始化(通道|声场等)
 properties的值参考Audio_Setting_Default
 具体差异化请参考[[AVAudioRecorder alloc] initWithURL: settings: error:]
 */
- (instancetype)initWith:(NSDictionary<NSString *, id> *)properties;

#pragma mark --record audio
/**
 开始录音
 audioPath若为空则音频文件路径为Audio_Record_Path
 */
- (void)startRecord:(NSString *)audioPath;

/**
 取消录音
 */
- (void)cancelRecord;

/**
 结束录音
 返回音频文件路径
 */
- (NSURL *)stopRecord;

#pragma mark --play audio
/**
 是否正在播放
 */
- (BOOL)isPlaying;

/**
 播放语音文件
 回调播放状态//0开始播放 1播放完成 2播放出错 3暂停播放
 */
- (void)playAudioFile:(NSString *)audioPath playState:(void(^)(int state))state;

/**
 播放语音数据
 回调播放状态//0开始播放 1播放完成 2播放出错 3暂停播放
 */
- (void)playAudioData:(NSData *)audioData playState:(void(^)(int state))state;

/**
 暂停播放
 */
- (void)pausePlay;

/**
 停止播放
 */
- (void)stopPlay;

@end

@interface AudioManager : NSObject

+ (instancetype)sharedInstance;

#pragma mark --default recorder view
/**
 AudioManager默认录音界面
 state为回调录音状态(0-取消,1-开始,2-转文字,3-发送语音,4-取消录音面板)
 */
- (UIView*)audioRecoderView:(void(^)(int state))state;

/**
 AudioManager默认录音播放管理
 */
- (AudioRecordPlay*)audioRecord;

/**
 AudioManager默认录音界面返回的语音识别文字
 */
- (NSString*)speechText;

#pragma mark --class method
+ (NSTimeInterval)timeWithAudioPath:(NSString *)audioPath;
+ (NSTimeInterval)timeWithAudioData:(NSData *)audioData;
+ (NSData *)encodeAmr:(NSString *)audioPath;
+ (NSData *)encodeAmrData:(NSData *)audioData;
+ (int)encodeWave:(NSString *)wavePath toAmr:(NSString *)amrPath;
+ (NSData *)decodeAmr:(NSString *)audioPath;
+ (NSData *)decodeAmrData:(NSData *)audioData;
+ (int)decodeAmr:(NSString *)amrPath toWave:(NSString *)wavePath;

@end
