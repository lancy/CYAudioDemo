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
#import "CYMusicQueueManager.h"

@interface CYMusicManager() <CYAudioStreamerDelegate, CYAudioQueuePlayerDelegate>

@property (nonatomic, strong) CYAudioSessionManager *audioSessionManager;
@property (nonatomic, strong) CYAudioStreamer *audioStreamer;
@property (nonatomic, strong) CYAudioQueuePlayer *audioQueuePlayer;

@end

@implementation CYMusicManager

+ (CYMusicManager *)shareManager
{
    static dispatch_once_t pred = 0;
    __strong static id _sharedObject = nil;
    dispatch_once(&pred, ^{
        _sharedObject = [[self alloc] init]; // or some other init method
    });
    return _sharedObject;
}

- (id)init
{
    if (self = [super init]) {
        [self initAudioSessionManager];
    }
    return self;
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
    [self.audioQueuePlayer setDelegate:self];
}

#pragma mark - queue manager

- (void)playDefaultMusicQueue
{
    id item = [[CYMusicQueueManager shareManager] currentItem];
    if ([item isKindOfClass:[MPMediaItem class]]) {
        [self playMediaItem:item];
    }
}

- (void)playMediaItem:(MPMediaItem *)mediaItem
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"CYMusicManagerDidChangedPlayingItem" object:mediaItem];
    if (self.audioQueuePlayer) {
        [self.audioQueuePlayer stopQueue];
        [self.audioQueuePlayer setDelegate:nil];
    }
    if (self.audioStreamer) {
        [self.audioStreamer setDelegate:nil];
        [self.audioStreamer cancleStreaming];
    }
    [self initStreamerWithMediaItem:mediaItem];
    [self initAudioQueuePlayer];
    [self.audioStreamer startStreaming];
    [self.audioQueuePlayer startQueue];
}

- (void)togglePlayPause
{
    if ([self.audioQueuePlayer isPlaying]) {
        [self.audioQueuePlayer pauseQueue];
    } else {
        [self.audioQueuePlayer startQueue];
    }
}

- (void)playNextMusic
{
    id item = [[CYMusicQueueManager shareManager] nextItem];
    if ([item isKindOfClass:[MPMediaItem class]]) {
        [self playMediaItem:item];
    }

}
- (void)playPreviousMusic
{
    id item = [[CYMusicQueueManager shareManager] lastItem];
    if ([item isKindOfClass:[MPMediaItem class]]) {
        [self playMediaItem:item];
    }
}


#pragma mark - streamer delegate

- (void)streamer:(CYAudioStreamer *)streamer didGetPacketData:(NSData *)packetData
{
    if (self.audioQueuePlayer) {
        [self.audioQueuePlayer handlePacketData:packetData];
    } else {
        NSLog(@"Warning: didn't init palyer");
    }
}

#pragma mark - player deleagte

- (void)player:(CYAudioQueuePlayer *)player didStopPlayingWithFinishedFlag:(BOOL)isFinishedPlaying
{
    NSLog(@"Did stop playing with finished flag: %d", isFinishedPlaying);
    if (isFinishedPlaying) {
        [self playNextMusic];
    }
}




@end
