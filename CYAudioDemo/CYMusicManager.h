//
//  CYMusicManager.h
//  CYAudioDemo
//
//  Created by Lancy on 15/2/13.
//  Copyright (c) 2013 Lancy. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CYMusicManager : NSObject

+ (CYMusicManager *)shareManager;
- (void)playMediaItem:(MPMediaItem *)mediaItem;


@end
