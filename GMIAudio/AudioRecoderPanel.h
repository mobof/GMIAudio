//
//  AudioRecoderPanel.h
//  Linkdood
//
//  Created by 熊清 on 16/6/24.
//  Copyright © 2016年 GMI. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum : int {
    RECORD_CANCEL,
    RECORD_START,
    RECORD_TOTEXT,
    RECORD_SEND,
    RECORD_DISMISS,
} RECORD_STATE;

@interface AudioRecoderPanel : UIView

@property (assign,nonatomic) bool speechAuth;
@property (strong,nonatomic) NSString *speechString;
@property (strong,nonatomic) void (^callback)(RECORD_STATE state);

+ (instancetype)loadNib;

@end
