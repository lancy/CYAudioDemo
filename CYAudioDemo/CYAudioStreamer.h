//
//  CYAudioStreamer.h
//  CYAudioDemo
//
//  Created by Lancy on 3/2/13.
//  Copyright (c) 2013 Lancy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>


@class CYAudioStreamer;

@protocol CYAudioStreamerDelegate <NSObject>
@optional
- (void)streamer:(CYAudioStreamer *)streamer didGetPacketData:(NSData *)packetData;

@end


@interface CYAudioStreamer : NSObject

@property (nonatomic, weak) id<CYAudioStreamerDelegate> delegate;

@property (nonatomic, readonly) AudioStreamBasicDescription audioStreamBasicDescription;

- (id)initWithUrlAssert:(AVURLAsset *)urlAssert delegate:(id<CYAudioStreamerDelegate>)delegate;

- (void)startStreaming;

@end
