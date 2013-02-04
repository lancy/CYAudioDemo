//
//  CYViewController.m
//  CYAudioDemo
//
//  Created by Lancy on 3/2/13.
//  Copyright (c) 2013 Lancy. All rights reserved.
//
#import <MediaPlayer/MediaPlayer.h>

#import "CYViewController.h"
#import "CYAudioQueuePlayer.h"
#import "CYAudioStreamer.h"

@interface CYViewController () <CYAudioStreamerDelegate>

@property (nonatomic, strong) CYAudioStreamer *audioStreamer;
@property (nonatomic, strong) CYAudioQueuePlayer *queuePlayer;

@end

@implementation CYViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    MPMediaQuery *everything = [[MPMediaQuery alloc] init];
    NSArray *itemsFromGenericQuery = [everything items];
    MPMediaItem *mediaItem = [itemsFromGenericQuery objectAtIndex:3];
    NSLog(@"%@", [mediaItem valueForProperty:MPMediaItemPropertyTitle]);
    AVURLAsset *songAsset = [AVURLAsset assetWithURL:[mediaItem valueForProperty:MPMediaItemPropertyAssetURL]];

    
    self.audioStreamer = [[CYAudioStreamer alloc] initWithUrlAssert:songAsset delegate:self];
    
    self.queuePlayer = [[CYAudioQueuePlayer alloc] init];
    [self.queuePlayer setupQueueWithAudioStreamBasicDescription:[self.audioStreamer audioStreamBasicDescription]];
    
    [self.audioStreamer startStreaming];

}

- (void)streamer:(CYAudioStreamer *)streamer didGetSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    [self.queuePlayer handleSampleBuffer:sampleBuffer];
}

@end
