//
//  CYAudioStreamer.m
//  CYAudioDemo
//
//  Created by Lancy on 3/2/13.
//  Copyright (c) 2013 Lancy. All rights reserved.
//

#import "CYAudioStreamer.h"

@interface CYAudioStreamer()

@property (nonatomic, strong) AVAssetReader *assertReader;
@property (nonatomic, strong) AVAssetReaderOutput *assertReaderOutput;

@end
@implementation CYAudioStreamer

- (id)initWithUrlAssert:(AVURLAsset *)urlAssert delegate:(id<CYAudioStreamerDelegate>)delegate;
{
    if (self = [super init]) {
        [self setDelegate:delegate];
        
        NSError *error = nil;
        _assertReader = [[AVAssetReader alloc] initWithAsset:urlAssert error:&error];
        
        [_assertReader setTimeRange:CMTimeRangeMake(kCMTimeZero, urlAssert.duration)];
        
        AVAssetTrack* track = [urlAssert.tracks objectAtIndex:0];
        _audioStreamBasicDescription = [self getTrackNativeSettings:track];
        _assertReaderOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:track
                                                                       outputSettings:nil];
        [_assertReader addOutput:_assertReaderOutput];
    }
    
    return self;
}

- (void)startStreaming
{
    [self.assertReader startReading];
    
    dispatch_queue_t backGround = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    dispatch_async(backGround, ^{
        CMSampleBufferRef sample;
        while ((sample = [self.assertReaderOutput copyNextSampleBuffer])) {
            if ([self.delegate respondsToSelector:@selector(streamer:didGetSampleBuffer:)]) {
                [self.delegate streamer:self didGetSampleBuffer:sample];
            }
        }
        NSLog(@"No sample can read.");
    });
}


- (AudioStreamBasicDescription)getTrackNativeSettings:(AVAssetTrack *) track
{
    
    CMFormatDescriptionRef formDesc = (__bridge CMFormatDescriptionRef)[[track formatDescriptions] objectAtIndex:0];
    const AudioStreamBasicDescription* asbdPointer = CMAudioFormatDescriptionGetStreamBasicDescription(formDesc);
    //because this is a pointer and not a struct we need to move the data into a struct so we can use it
    AudioStreamBasicDescription asbd = {0};
    memcpy(&asbd, asbdPointer, sizeof(asbd));
    //asbd now contains a basic description for the track
    return asbd;
    
}


// generic error handler - if err is nonzero, prints error message and exits program.
static void CheckError(OSStatus error, const char *operation)
{
    if (error == noErr) return;
        
    char str[20];
    // see if it appears to be a 4-kchar-code
    *(UInt32 *)(str + 1) = CFSwapInt32HostToBig(error);
    if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) {
        str[0] = str[5] = '\'';
        str[6] = '\0';
    } else
        // no, format it as an integer
        sprintf(str, "%d", (int)error);
    
    fprintf(stderr, "Error: %s (%s)\n", operation, str);
    
    exit(1);
}

@end
