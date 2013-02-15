//
//  CYAudioQueuePlayer.h
//  CYAudioDemo
//
//  Created by Lancy on 3/2/13.
//  Copyright (c) 2013 Lancy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <pthread.h>

@interface CYAudioQueuePlayer : NSObject


- (void)setupQueueWithAudioStreamBasicDescription:(AudioStreamBasicDescription)audioStreamBasicDescription;
- (void)handlePacketData:(NSData *)packetData;


- (BOOL)isPlaying;
- (void)startQueue;
- (void)stopQueue;
- (void)pauseQueue;



@end
