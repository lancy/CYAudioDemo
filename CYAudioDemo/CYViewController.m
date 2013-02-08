//
//  CYViewController.m
//  CYAudioDemo
//
//  Created by Lancy on 3/2/13.
//  Copyright (c) 2013 Lancy. All rights reserved.
//
#import <MediaPlayer/MediaPlayer.h>
#import <GameKit/GameKit.h>

#import "CYViewController.h"
#import "CYAudioQueuePlayer.h"
#import "CYAudioStreamer.h"

@interface CYViewController () <CYAudioStreamerDelegate, GKPeerPickerControllerDelegate, GKSessionDelegate>

@property (nonatomic, strong) CYAudioStreamer *audioStreamer;
@property (nonatomic, strong) CYAudioQueuePlayer *queuePlayer;

@property (nonatomic, strong) GKSession *session;
@property (nonatomic, strong) GKPeerPickerController *peerPickerController;
@property (nonatomic, strong) NSMutableArray *peersConnected;

@end

@implementation CYViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    
    
    
    [self initGameKit];
    [self beginStreaming];
}

- (void)initGameKit
{
    self.peerPickerController = [[GKPeerPickerController alloc] init];
    [self.peerPickerController setDelegate:self];
    [self.peerPickerController setConnectionTypesMask:GKPeerPickerConnectionTypeNearby];
    
    self.peersConnected = [[NSMutableArray alloc] init];
    
    UIButton *conectButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [conectButton addTarget:self action:@selector(tapConnectButton:) forControlEvents:UIControlEventTouchUpInside];
    [conectButton setTitle:@"Conect" forState:UIControlStateNormal];
    [conectButton setFrame:CGRectMake(20, 100, 280, 44)];
    [conectButton setTag:12];
    [self.view addSubview:conectButton];

}

- (void)beginStreaming
{
    MPMediaQuery *everything = [[MPMediaQuery alloc] init];
    NSArray *itemsFromGenericQuery = [everything items];
    MPMediaItem *mediaItem = [itemsFromGenericQuery objectAtIndex:3];
    NSLog(@"%@", [mediaItem valueForProperty:MPMediaItemPropertyTitle]);
    AVURLAsset *songAsset = [AVURLAsset assetWithURL:[mediaItem valueForProperty:MPMediaItemPropertyAssetURL]];
    
    self.audioStreamer = [[CYAudioStreamer alloc] initWithUrlAssert:songAsset delegate:self];
    
    AudioStreamBasicDescription audioStreamBasicDescription = [self.audioStreamer audioStreamBasicDescription];
    NSData *ASBDData = [NSData dataWithBytes:&audioStreamBasicDescription length:sizeof(audioStreamBasicDescription)];
    
    NSDictionary *beginSinal = @{@"audioStreamBasicDescription": ASBDData};
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:beginSinal];
    
//    [self.session sendData:data toPeers:self.peersConnected withDataMode:GKSendDataReliable error:nil];
    
    NSDictionary *signal = [NSKeyedUnarchiver  unarchiveObjectWithData:data];

    AudioStreamBasicDescription temp;
    [[signal objectForKey:@"audioStreamBasicDescription"] getBytes:&temp length:[[signal objectForKey:@"audioStreamBasicDescription"] length]];

    self.queuePlayer = [[CYAudioQueuePlayer alloc] init];
    [self.queuePlayer setupQueueWithAudioStreamBasicDescription:temp];

    [self.audioStreamer startStreaming];
}

- (void)streamer:(CYAudioStreamer *)streamer didGetPacketData:(NSData *)packetData
{
    [self.queuePlayer handlePacketData:packetData];
}


#pragma mark - GKPeerPickerControllerDelegate

- (GKSession *)peerPickerController:(GKPeerPickerController *)picker sessionForConnectionType:(GKPeerPickerConnectionType)type
{
    return [[GKSession alloc] initWithSessionID:@"com.vivianaranha.sendfart" displayName:nil sessionMode:GKSessionModePeer];
}

- (void)peerPickerController:(GKPeerPickerController *)picker didConnectPeer:(NSString *)peerID toSession:(GKSession *)session{
    
    // Get the session and assign it locally
    self.session = session;
    [session setDelegate:self];
    
    //No need of teh picekr anymore
    [picker dismiss];
}

// Function to receive data when sent from peer
- (void)receiveData:(NSData *)data fromPeer:(NSString *)peer inSession: (GKSession *)session context:(void *)context
{
}

#pragma mark - GKSessionDelegate

- (void)session:(GKSession *)session peer:(NSString *)peerID didChangeState:(GKPeerConnectionState)state
{
    if(state == GKPeerStateConnected){
        // Add the peer to the Array
        [self.peersConnected addObject:peerID];
        // Used to acknowledge that we will be sending data
        [session setDataReceiveHandler:self withContext:nil];
        
        [[self.view viewWithTag:12] removeFromSuperview];
        
        UIButton *sendSongBtn = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [sendSongBtn addTarget:self action:@selector(beginStreaming) forControlEvents:UIControlEventTouchUpInside];
        [sendSongBtn setTitle:@"Start Streaming" forState:UIControlStateNormal];
        sendSongBtn.frame = CGRectMake(20, 100, 280, 30);
        sendSongBtn.tag = 12;
        [self.view addSubview:sendSongBtn];
    }
}

- (void)tapConnectButton:(id)sender
{
    [self.peerPickerController show];
}



@end
