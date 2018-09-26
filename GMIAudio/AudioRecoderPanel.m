//
//  AudioRecoderPanel.m
//  Linkdood
//
//  Created by 熊清 on 16/6/24.
//  Copyright © 2016年 GMI. All rights reserved.
//

#import "AudioRecoderPanel.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <Speech/Speech.h>

#define MAX_RECORDTIME          60


@interface AudioRecoderPanel()<UIGestureRecognizerDelegate>
{
    IBOutlet UIButton *recoder;
    IBOutlet UILabel *tipLabel;
    IBOutlet UIButton *keyboardBtn;
    IBOutlet UILabel *remindLabel;
    IBOutlet UIPanGestureRecognizer *panGesture;
    IBOutlet UIVisualEffectView *blurView;
    
    bool audioAuth;//是否有语音权限
    
    CGPoint oldPoint;
    NSTimer *recoderTimer;
    int recoderSecond;
    
    API_AVAILABLE(ios(10.0))
    AVAudioEngine *audioEngine;//语音识别引擎
    API_AVAILABLE(ios(10.0))
    SFSpeechRecognizer *speechRecognizer;
    API_AVAILABLE(ios(10.0))
    SFSpeechAudioBufferRecognitionRequest *speechRequest; //语音请求对象
    API_AVAILABLE(ios(10.0))
    SFSpeechRecognitionTask *currentSpeechTask;
}

@end

@implementation AudioRecoderPanel

+ (instancetype)loadNib {
    AudioRecoderPanel *audioPanel = [[NSBundle bundleForClass:self] loadNibNamed:@"AudioRecoderPanel" owner:nil options:nil].firstObject;
    return audioPanel;
}

-(void)awakeFromNib
{
    [super awakeFromNib];
    
    if ([[AVAudioSession sharedInstance] respondsToSelector:@selector(requestRecordPermission:)]) {
        [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL available) {
            audioAuth = available;
            [self refreshSubviews:audioAuth speech:self.speechAuth];
        }];
    }
    
    if (@available(iOS 10.0, *)) {
        [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
            switch (status) {
                case SFSpeechRecognizerAuthorizationStatusAuthorized:
                    self.speechAuth = true;
                    break;
                default:
                    self.speechAuth = false;
                    break;
            }
            [self refreshSubviews:audioAuth speech:self.speechAuth];
        }];
    }else{
        self.speechAuth = false;
        [self refreshSubviews:audioAuth speech:self.speechAuth];
    }
}

- (void)refreshSubviews:(bool)audio speech:(bool)speech{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (audio) {
            [blurView setHidden:YES];
            oldPoint = CGPointMake([UIScreen mainScreen].bounds.size.width / 2, recoder.center.y);
            recoderSecond = MAX_RECORDTIME;
            [recoder setImage:[self maskedImage:recoder.imageView.image withColor:[UIColor colorWithRed:50/255 green:173/255 blue:238/255 alpha:1.0]] forState:UIControlStateNormal];
            [keyboardBtn setImage:[self maskedImage:keyboardBtn.imageView.image withColor:[UIColor colorWithRed:50/255 green:173/255 blue:238/255 alpha:1.0]] forState:UIControlStateNormal];
            [recoder setHidden:NO];
            [tipLabel setHidden:NO];
            [remindLabel setHidden:NO];
            
            //支持语音识别
            if (speech) {
                audioEngine = [[AVAudioEngine alloc] init];
                speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:[NSLocale localeWithLocaleIdentifier:@"zh_CN"]];
                [speechRecognizer setDelegate:self];
            }
        }else{
            [blurView setHidden:NO];
            [recoder setHidden:YES];
            [tipLabel setHidden:YES];
            [remindLabel setHidden:YES];
        }
    });
}

-(void)layoutSubviews{
    [super layoutSubviews];
}

- (IBAction)tapRecoder:(id)sender
{
    //重置语音识别内容
    self.speechString = nil;
    if (recoderTimer.isValid) {
        if (self.speechAuth) {
            [self endRecoder:CGPointMake(0, 0)];
        }
        return;
    }
    
    //录音状态UI
    recoderTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateTimer) userInfo:nil repeats:YES];
    [UIView animateWithDuration:1.0 delay:0 options:UIViewAnimationOptionRepeat|UIViewAnimationOptionAutoreverse|UIViewKeyframeAnimationOptionAllowUserInteraction animations:^{
        recoder.alpha = 0.3;
    } completion: nil];
    [self setTipText];
    
    //开始录音
    if (_callback) {
        _callback(RECORD_START);
    }
    
    //加载语音识别模块
    if (self.speechAuth) {
        [remindLabel setText:@"左滑发送|点击取消|右滑转文字"];
        [remindLabel setTextColor:[UIColor colorWithRed:153.0 / 255.0 green:169.0 / 255.0 blue:169.0 / 255.0 alpha:1]];
        
        //启动声音处理器
        if (currentSpeechTask) {
            [currentSpeechTask cancel];
            currentSpeechTask = nil;
        }
        //创建语音识别
        speechRequest = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
        speechRequest.shouldReportPartialResults = true;
        currentSpeechTask =
        [speechRecognizer recognitionTaskWithRequest:speechRequest
                                       resultHandler:^(SFSpeechRecognitionResult * _Nullable result,
                                                       NSError * _Nullable error)
        {
             bool isFinal = false;
             if (result) {
                 self.speechString = [[result bestTranscription] formattedString]; //语音转文本
                 isFinal = [result isFinal];
             }
             if (error || isFinal) {
                 [audioEngine stop];
                 [speechRequest endAudio];
                 [audioEngine.inputNode removeTapOnBus:0];
                 speechRequest = nil;
                 currentSpeechTask = nil;
             }
        }];
        
        //设置音频格式
        AVAudioFormat *recordingFormat = [audioEngine.inputNode outputFormatForBus:0];
        [audioEngine.inputNode installTapOnBus:0 bufferSize:1024 format:recordingFormat block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
            [speechRequest appendAudioPCMBuffer:buffer];
        }];
        [audioEngine prepare];
        [audioEngine startAndReturnError:nil];
    }else{
        [remindLabel setText:@"左滑发送|右滑取消"];
        [remindLabel setTextColor:[UIColor colorWithRed:153.0 / 255.0 green:169.0 / 255.0 blue:169.0 / 255.0 alpha:1]];
    }
}

- (IBAction)panGestureAction:(UIPanGestureRecognizer*)pan
{
    if (!recoderTimer.isValid) {
        return;
    }
    CGPoint point = [pan translationInView:self];
    [recoder setCenter:(CGPoint){oldPoint.x + point.x,oldPoint.y}];
    if (fabs(point.x) >= recoder.frame.size.width) {
        if (self.speechAuth) {
            [remindLabel setText:point.x < 0?@"松开发送":@"松开转文字"];
        }else{
            [remindLabel setText:point.x < 0?@"松开发送":@"松开取消"];
        }
    }else{
        if (self.speechAuth) {
            [remindLabel setText:@"左滑发送|点击取消|右滑转文字"];
        }else{
            [remindLabel setText:@"左滑发送|右滑取消"];
        }
    }
    if (pan.state == UIGestureRecognizerStateEnded) {
        [UIView animateWithDuration:0.3 animations:^{
            [recoder setCenter:CGPointMake(self.center.x, oldPoint.y)];
            [recoder setImage:[self maskedImage:recoder.currentImage withColor:[UIColor colorWithRed:50/255 green:173/255 blue:238/255 alpha:1.0]] forState:UIControlStateNormal];
        }];
        if (fabs(point.x) >= recoder.frame.size.width) {
            [self endRecoder:point];
        }
    }
}

- (IBAction)toOpenLocationAuthorization:(id)sender
{
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]]) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
    }
}

- (IBAction)hideAudioPanel:(id)sender{
    [remindLabel setText:@""];
    if (_callback) {
        _callback(RECORD_DISMISS);
    }
}

- (void)updateTimer
{
    recoderSecond -= 1;
    [self setTipText];
    
    if (recoderSecond == 0) {
        [self endRecoder:CGPointMake(0, 0)];//超时自动取消
    }
}

- (void)setTipText
{
    NSString *prefix = (recoderSecond % MAX_RECORDTIME) > 0?@"00":@"01";
    NSString *suffix = recoderSecond >= 10?((recoderSecond % MAX_RECORDTIME) == 0?@"00":[NSString stringWithFormat:@"%d",recoderSecond]):[NSString stringWithFormat:@"0%d",recoderSecond];
    [tipLabel setText:[NSString stringWithFormat:@"%@:%@",prefix,suffix]];
}

- (void)endRecoder:(CGPoint)point{
    if (point.x == 0) {//取消
        [remindLabel setText:@""];
        if (_callback) {
            _callback(RECORD_CANCEL);
        }
    }else if (point.x > 0) {//转文字
        if (self.speechAuth) {
            if (self.speechString && self.speechString.length > 0) {
                [remindLabel setText:@""];
                if (_callback) {
                    _callback(RECORD_TOTEXT);
                }
            }else{
                [remindLabel setText:@"语音识别失败"];
                [remindLabel setTextColor:UIColor.redColor];
                _callback(RECORD_CANCEL);
            }
        }else{
            [remindLabel setText:@""];
            if (_callback) {
                _callback(RECORD_CANCEL);
            }
        }
    }else{//发送语音
        [remindLabel setText:@""];
        if (_callback) {
            _callback(RECORD_SEND);
        }
    }
    
    //停止语音识别
    if (_speechAuth) {
        [audioEngine stop];
        [speechRequest endAudio];
        [audioEngine.inputNode removeTapOnBus:0];
    }
    //取消计时器，UI恢复
    [recoderTimer invalidate];
    [recoder setAlpha:1.0];
    [recoder.layer removeAllAnimations];
    recoderSecond = MAX_RECORDTIME;
    [tipLabel setText:@"点击开始录音"];
}

- (void)speechRecognizer:(SFSpeechRecognizer *)speechRecognizer availabilityDidChange:(BOOL)available API_AVAILABLE(ios(10.0)){
    self.speechAuth = available;
    [self refreshSubviews:audioAuth speech:self.speechAuth];
}

- (UIImage *)maskedImage:(UIImage*)image withColor:(UIColor *)maskColor
{
    NSParameterAssert(maskColor != nil);
    
    CGRect imageRect = CGRectMake(0.0f, 0.0f, image.size.width, image.size.height);
    UIImage *newImage = nil;
    
    UIGraphicsBeginImageContextWithOptions(imageRect.size, NO, image.scale);
    {
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        CGContextScaleCTM(context, 1.0f, -1.0f);
        CGContextTranslateCTM(context, 0.0f, -(imageRect.size.height));
        
        CGContextClipToMask(context, imageRect, image.CGImage);
        CGContextSetFillColorWithColor(context, maskColor.CGColor);
        CGContextFillRect(context, imageRect);
        
        newImage = UIGraphicsGetImageFromCurrentImageContext();
    }
    UIGraphicsEndImageContext();
    
    return newImage;
}

@end
