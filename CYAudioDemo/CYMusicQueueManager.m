//
//  CYMusicQueueManager.m
//  CYAudioDemo
//
//  Created by Lancy on 15/2/13.
//  Copyright (c) 2013 Lancy. All rights reserved.
//

#import "CYMusicQueueManager.h"

@interface CYMusicQueueManager()

@property (nonatomic, strong) NSMutableArray *musicQueue;
@property (assign) NSUInteger currentPlayingIndex;

@end

@implementation CYMusicQueueManager


- (id)init
{
    if (self = [super init]) {
        self.musicQueue = [NSMutableArray array];
        self.currentPlayingIndex = 0;
    }
    return self;
}

- (void)addMediaItemCollection:(MPMediaItemCollection *)mediaItemCollection
{
    [self.musicQueue addObjectsFromArray:[mediaItemCollection items]];
}

- (void)removeAllItems
{
    [self.musicQueue removeAllObjects];
}


- (void)addMediaItem:(MPMediaItem *)mediaItem
{
    [self.musicQueue addObject:mediaItem];
}
- (void)addListenerItem
{
    [self.musicQueue addObject:@"CYListenerItem"];
}
- (id)getCurrentMusic
{
    return self.musicQueue[self.currentPlayingIndex];
}
- (id)getNextMusic
{
    self.currentPlayingIndex++;
    return self.musicQueue[self.currentPlayingIndex];
}
- (id)getLastMusic
{
    self.currentPlayingIndex--;
    return self.musicQueue[self.currentPlayingIndex];
}


@end
