//
//  CYNowPlayingViewController.m
//  CYAudioDemo
//
//  Created by Lancy on 15/2/13.
//  Copyright (c) 2013 Lancy. All rights reserved.
//

#import "CYNowPlayingViewController.h"
#import "CYMusicQueueManager.h"
#import "CYMusicManager.h"


@interface CYNowPlayingViewController()

@property (weak, nonatomic) IBOutlet UILabel *songTitleLabel;

@end


@implementation CYNowPlayingViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidChangedPlayingItem:) name:@"CYMusicManagerDidChangedPlayingItem" object:nil];
    
    MPMediaQuery *query = [MPMediaQuery songsQuery];
    [[CYMusicQueueManager shareManager] removeAllItems];
    MPMediaItemCollection *collection = [MPMediaItemCollection collectionWithItems:[query items]];
    [[CYMusicQueueManager shareManager] addMediaItemCollection:collection];
    [[CYMusicManager shareManager] playDefaultMusicQueue];
    
}

- (void)handleDidChangedPlayingItem:(id)sender
{
    MPMediaItem *item = [[CYMusicQueueManager shareManager] currentItem];
    [self.songTitleLabel setText:[item valueForProperty:MPMediaItemPropertyTitle]];
}

- (IBAction)didTapLastButton:(id)sender {
    [[CYMusicManager shareManager] playPreviousMusic];
}
- (IBAction)didTapPlayPauseButton:(id)sender {
    [[CYMusicManager shareManager] togglePlayPause];
}
- (IBAction)didTapNextButton:(id)sender {
    [[CYMusicManager shareManager] playNextMusic];
}

- (void)viewDidUnload {
    [self setSongTitleLabel:nil];
    [super viewDidUnload];
}
@end
