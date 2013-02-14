//
//  CYPlayerViewController.m
//  CYAudioDemo
//
//  Created by Lancy on 14/2/13.
//  Copyright (c) 2013 Lancy. All rights reserved.
//

#import "CYPlayerViewController.h"
#import "CYAudioQueuePlayer.h"
#import "CYAudioStreamer.h"


@interface CYPlayerViewController() <CYAudioStreamerDelegate>

@property (nonatomic, strong) CYAudioStreamer *audioStreamer;
@property (nonatomic, strong) CYAudioQueuePlayer *queuePlayer;


@end

@implementation CYPlayerViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self initStreamer];
    [self initQueuePlayer];
    [self initUserInterface];
}

- (void)initUserInterface
{
    MPVolumeView *volumeView = [[MPVolumeView alloc] init];
    [volumeView setFrame:CGRectMake(20, 500, 280, 44)];
    [self.view addSubview:volumeView];
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

@end
