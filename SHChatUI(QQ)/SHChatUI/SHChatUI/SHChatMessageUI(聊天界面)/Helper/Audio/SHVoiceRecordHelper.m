//
//  SHVoiceRecordHelper.m
//  SHChatMessageUI
//
//  Created by CSH on 16/7/27.
//  Copyright © 2016年 CSH. All rights reserved.
//

#import "SHVoiceRecordHelper.h"
#import <AVFoundation/AVFoundation.h>
#import "SHFileHelper.h"
#import "SHMessageMacroHeader.h"
#import "SHAudioPlayerHelper.h"


@interface SHVoiceRecordHelper ()<AVAudioRecorderDelegate>

@property (nonatomic, strong) AVAudioRecorder *recorder;
@property (nonatomic, copy) NSString *wavPath;
@property (nonatomic, copy) NSString *amrPath;

@end

@implementation SHVoiceRecordHelper

#pragma mark - 设置代理
- (id)initWithDelegate:(id<SHVoiceRecordHelperDelegate>)delegate {
    if (self = [super init]) {
        _delegate = delegate;
    }
    return self;
}

#pragma mark - 开始录音
- (void)startRecord{
    //配置路径
    [self recorderPath];
    //配置录音
    [self setRecorder];
    //开始录音
    [_recorder record];
}


#pragma mark - 停止录音
- (void)stopRecord {
    //录制时间
    int recorderTime = (int)roundf(_recorder.currentTime);
    //停止录音
    [_recorder stop];
    
    if (recorderTime >= kSHMinRecordTime) {
        //在规定时长内
        //生成 AMR 与 WAV
        [self wavTOamr];
        
        //发送语音
        if ([_delegate respondsToSelector:@selector(voiceRecordFinishWithWavPath:AmrPath:RecordDuration:)]) {
            [_delegate voiceRecordFinishWithWavPath:self.wavPath.lastPathComponent AmrPath:self.amrPath.lastPathComponent RecordDuration:[NSString stringWithFormat:@"%d",recorderTime]];
        }
        
    }else{//最短时间
        
        [_recorder deleteRecording];
        if ([_delegate respondsToSelector:@selector(voiceRecordTimeWithRuleTime:)]) {
            [_delegate voiceRecordTimeWithRuleTime:recorderTime];
        }
        
    }
    
}


#pragma mark - 取消录音
- (void)cancelRecord {
    [_recorder stop];
    [_recorder deleteRecording];
}

#pragma mark - 录音配置
- (void)setRecorder{
    
    
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *setCategoryError = nil;
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&setCategoryError];
    
    if(setCategoryError){
        NSLog(@"%@", [setCategoryError description]);
    }
    
    _recorder = nil;
    NSError *error = nil;
    NSDictionary *settingsDict = [SHFileHelper getAudioRecorderSettingDict];
    NSURL *url = [NSURL fileURLWithPath:self.wavPath];

    _recorder =  [[AVAudioRecorder alloc] initWithURL:url settings:settingsDict error:&error];
    if (error) {
        NSLog(@"%@",error);
    }
    //开启声波检测
    _recorder.meteringEnabled = YES;
    _recorder.delegate = self;
    [_recorder prepareToRecord];
    
    //录音的时候停止播放
    [[SHAudioPlayerHelper shareInstance] stopAudio];
}

- (int)peekRecorderVoiceMetersWithMax:(int)max {
    [_recorder updateMeters];
    // 0 - 1
    float peakPower = pow(10, (0.05 * [_recorder peakPowerForChannel:0]));
    // 超出1为1
    if (peakPower > 1) {
        peakPower = 1;
    }
    return peakPower*max;
}


#pragma mark - WAV-->AMR
- (void)wavTOamr{
    //    转格式 WAV-->AMR
    [VoiceConverter wavToAmr:self.wavPath amrSavePath:self.amrPath];
    
}

#pragma mark - 获取路径
- (void)recorderPath {
    
    self.wavPath = [NSString stringWithFormat:@"%@/%@.wav",kSHAudioWAVPath,[SHMessageTimeHelper getTimeZoneMs]];
    
    self.amrPath = [NSString stringWithFormat:@"%@/%@.amr",kSHAudioAMRPath,[SHMessageTimeHelper getTimeZoneMs]];

}

@end
