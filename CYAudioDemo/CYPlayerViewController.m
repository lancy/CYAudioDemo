//
//  CYPlayerViewController.m
//  CYAudioDemo
//
//  Created by Lancy on 14/2/13.
//  Copyright (c) 2013 Lancy. All rights reserved.
//

#import "CYPlayerViewController.h"
#import "CYAudioSessionManager.h"
#import "CYAudioQueuePlayer.h"
#import "CYAudioStreamer.h"


@interface CYPlayerViewController() <CYAudioStreamerDelegate>

@property (nonatomic, strong) CYAudioSessionManager *audioSessionManager;
@property (nonatomic, strong) CYAudioStreamer *audioStreamer;
@property (nonatomic, strong) CYAudioQueuePlayer *queuePlayer;


@end

@implementation CYPlayerViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self initNotification];
    [self initAudioSessionManager];
    [self initStreamer];
    [self initQueuePlayer];
    [self initUserInterface];
}

- (void)initNotification
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(CYAudioQueuePlayerDidStopPlaying) name:@"CYAudioQueuePlayerDidStopPlaying" object:nil];
}

- (void)CYAudioQueuePlayerDidStopPlaying
{
    static int currentPlaying = 3;
    currentPlaying++;
    
    MPMediaQuery *everything = [[MPMediaQuery alloc] init];
    NSArray *itemsFromGenericQuery = [everything items];
    MPMediaItem *mediaItem = [itemsFromGenericQuery objectAtIndex:currentPlaying];
    NSLog(@"%@", [mediaItem valueForProperty:MPMediaItemPropertyTitle]);
    AVURLAsset *songAsset = [AVURLAsset assetWithURL:[mediaItem valueForProperty:MPMediaItemPropertyAssetURL]];
    
    self.audioStreamer = [[CYAudioStreamer alloc] initWithUrlAssert:songAsset delegate:self];
    
    [self.audioStreamer startStreaming];
    [self.queuePlayer startQueue];
    
}

- (void)initUserInterface
{
    MPVolumeView *volumeView = [[MPVolumeView alloc] init];
    [volumeView setFrame:CGRectMake(20, 500, 280, 44)];
    [self.view addSubview:volumeView];
}

- (void)initAudioSessionManager
{
    self.audioSessionManager = [[CYAudioSessionManager alloc] init];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
}

- (void)initStreamer
{
    MPMediaQuery *everything = [[MPMediaQuery alloc] init];
    NSArray *itemsFromGenericQuery = [everything items];
    MPMediaItem *mediaItem = [itemsFromGenericQuery objectAtIndex:3];
    NSLog(@"%@", [mediaItem valueForProperty:MPMediaItemPropertyTitle]);
    AVURLAsset *songAsset = [AVURLAsset assetWithURL:[mediaItem valueForProperty:MPMediaItemPropertyAssetURL]];
    
    self.audioStreamer = [[CYAudioStreamer alloc] initWithUrlAssert:songAsset delegate:self];
}

- (void)initQueuePlayer
{
    self.queuePlayer = [[CYAudioQueuePlayer alloc] init];
    [self.queuePlayer setupQueueWithAudioStreamBasicDescription:[self.audioStreamer audioStreamBasicDescription]];
}

- (void)streamer:(CYAudioStreamer *)streamer didGetPacketData:(NSData *)packetData
{
    if (self.queuePlayer) {
        [self.queuePlayer handlePacketData:packetData];
    } else {
        NSLog(@"Warning: didn't init palyer");
    }
}
- (IBAction)didTapStartStreamingButton:(id)sender {
    [self.audioStreamer startStreaming];
}

- (IBAction)didTapPlayButton:(id)sender {
    [self.queuePlayer startQueue];
}
- (IBAction)didTapPauseButton:(id)sender {
    [self.queuePlayer pauseQueue];
}
- (IBAction)didTapStopButton:(id)sender {
    [self.queuePlayer stopQueue];
}

//Make sure we can recieve remote control events
- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
    //if it is a remote control event handle it correctly
    if (event.type == UIEventTypeRemoteControl) {
        if (event.subtype == UIEventSubtypeRemoteControlPlay) {
            [self.queuePlayer startQueue];
        } else if (event.subtype == UIEventSubtypeRemoteControlPause) {
            [self.queuePlayer pauseQueue];
        } else if (event.subtype == UIEventSubtypeRemoteControlTogglePlayPause) {
            if ([self.queuePlayer isPlaying]) {
                [self.queuePlayer pauseQueue];
            } else {
                [self.queuePlayer startQueue];
            }
        }
    }
}

@end
