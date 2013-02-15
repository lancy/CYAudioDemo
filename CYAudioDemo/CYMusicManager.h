//
//  CYMusicManager.h
//  CYAudioDemo
//
//  Created by Lancy on 15/2/13.
//  Copyright (c) 2013 Lancy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>

@interface CYMusicManager : NSObject

+ (CYMusicManager *)shareManager;

- (void)playDefaultMusicQueue;
- (void)playMediaItem:(MPMediaItem *)mediaItem;

- (void)togglePlayPause;
- (void)playNextMusic;
- (void)playPreviousMusic;



@end
