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

+ (CYMusicQueueManager *)shareManager
{
    static CYMusicQueueManager* shareManager;
    if (!shareManager) {
        shareManager = [[CYMusicQueueManager alloc] init];
    }
    return shareManager;
}

- (id)init
{
    if (self = [super init]) {
        self.musicQueue = [[NSMutableArray alloc] init];
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
- (id)currentItem
{
    return self.musicQueue[self.currentPlayingIndex];
}
- (id)nextItem
{
    if (self.currentPlayingIndex < [self.musicQueue count]) {
        self.currentPlayingIndex++;
        return self.musicQueue[self.currentPlayingIndex];
    } else {
        return nil;
    }
}
- (id)lastItem
{
    if (self.currentPlayingIndex > 0) {
        self.currentPlayingIndex--;
        return self.musicQueue[self.currentPlayingIndex];
    } else {
        return nil;
    }
}


@end
