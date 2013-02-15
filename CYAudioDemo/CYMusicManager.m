//
//  CYMusicManager.m
//  CYAudioDemo
//
//  Created by Lancy on 15/2/13.
//  Copyright (c) 2013 Lancy. All rights reserved.
//

#import "CYAudioSessionManager.h"
#import "CYAudioQueuePlayer.h"
#import "CYAudioStreamer.h"

#import "CYMusicManager.h"

@interface CYMusicManager() <CYAudioStreamerDelegate>

@property (nonatomic, strong) CYAudioSessionManager *audioSessionManager;
@property (nonatomic, strong) CYAudioStreamer *audioStreamer;
@property (nonatomic, strong) CYAudioQueuePlayer *audioQueuePlayer;

@end

@implementation CYMusicManager

+ (CYMusicManager *)shareManager
{
    static CYMusicManager* shareManager;
    if (!shareManager) {
        shareManager = [[CYMusicManager alloc] init];
    }
    return shareManager;
}

- (id)init
{
    if (self = [super init]) {
        [self initAudioSessionManager];
    }
    return self;
}

- (void)playMediaItem:(MPMediaItem *)mediaItem
{
    if (self.audioQueuePlayer) {
        [self.audioQueuePlayer stopQueue];
    }
    if (self.audioStreamer) {
        [self.audioStreamer cancleStreaming];
    }
    [self initStreamerWithMediaItem:mediaItem];
    [self initAudioQueuePlayer];
    [self.audioStreamer startStreaming];
    [self.audioQueuePlayer startQueue];
}

- (void)initAudioSessionManager
{
    self.audioSessionManager = [[CYAudioSessionManager alloc] init];
}

- (void)initStreamerWithMediaItem:(MPMediaItem *)mediaItem
{
    NSLog(@"%@", [mediaItem valueForProperty:MPMediaItemPropertyTitle]);
    AVURLAsset *songAsset = [AVURLAsset assetWithURL:[mediaItem valueForProperty:MPMediaItemPropertyAssetURL]];
    self.audioStreamer = [[CYAudioStreamer alloc] initWithUrlAssert:songAsset delegate:self];
}

- (void)initAudioQueuePlayer
{
    self.audioQueuePlayer = [[CYAudioQueuePlayer alloc] init];
    [self.audioQueuePlayer setupQueueWithAudioStreamBasicDescription:[self.audioStreamer audioStreamBasicDescription]];
}

- (void)streamer:(CYAudioStreamer *)streamer didGetPacketData:(NSData *)packetData
{
    if (self.audioQueuePlayer) {
        [self.audioQueuePlayer handlePacketData:packetData];
    } else {
        NSLog(@"Warning: didn't init palyer");
    }
}




@end
