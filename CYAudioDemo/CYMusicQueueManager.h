//
//  CYMusicQueueManager.h
//  CYAudioDemo
//
//  Created by Lancy on 15/2/13.
//  Copyright (c) 2013 Lancy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>

@interface CYMusicQueueManager : NSObject


+ (CYMusicQueueManager *)shareManager;

- (void)addMediaItemCollection:(MPMediaItemCollection *)mediaItemCollection;
- (void)addMediaItem:(MPMediaItem *)mediaItem;
- (void)addListenerItem;

- (void)removeAllItems;

- (id)currentItem;
- (id)nextItem;
- (id)lastItem;

@end
