//
//  CYAudioStreamer.m
//  CYAudioDemo
//
//  Created by Lancy on 3/2/13.
//  Copyright (c) 2013 Lancy. All rights reserved.
//

#define PACKET_CAPACITY 2048

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
        
//        [_assertReader setTimeRange:CMTimeRangeMake(kCMTimeZero, CMTimeMake(5, 1))];
        [_assertReader setTimeRange:CMTimeRangeMake(kCMTimeZero, urlAssert.duration)];
        
        AVAssetTrack* track = [urlAssert.tracks objectAtIndex:0];
        _audioStreamBasicDescription = [self getTrackNativeSettings:track];
        _assertReaderOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:track
                                                                       outputSettings:nil];
        [_assertReader addOutput:_assertReaderOutput];
        [self.assertReader startReading];

    }
    
    return self;
}

- (void)startStreaming
{
    
    dispatch_queue_t streamingQueue =  dispatch_queue_create("StreamingQueue", nil);
    dispatch_async(streamingQueue, ^{   
        
        CMSampleBufferRef sampleBuffer;
        while ((sampleBuffer = [self.assertReaderOutput copyNextSampleBuffer])) {
            
            if (sampleBuffer) {
                CMTime durationTime = CMSampleBufferGetDuration(sampleBuffer);
                if (CMTimeGetSeconds(durationTime) == 0.0) {
                    break;
                }
                
                CMBlockBufferRef blockBuffer;
                AudioBufferList audioBufferList;
                CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, NULL, &audioBufferList, sizeof(AudioBufferList), NULL, NULL, 0, &blockBuffer);
                CFRelease(blockBuffer);
                
                for (int i = 0; i < audioBufferList.mNumberBuffers; i++) {
                    AudioBuffer audioBuffer = audioBufferList.mBuffers[i];
                    
                    int mod = audioBuffer.mDataByteSize % PACKET_CAPACITY;
                    int numberOfPacket;
                    if (mod != 0) {
                        numberOfPacket = audioBuffer.mDataByteSize / PACKET_CAPACITY + 1;
                    } else {
                        numberOfPacket = audioBuffer.mDataByteSize / PACKET_CAPACITY;
                    }
                    
                    // AudioBufferのデータを格納しているポインタ
                    void *audioBufferPointer = audioBuffer.mData;
                    
                    int remainedDataSize = audioBuffer.mDataByteSize;
                    for (int i = 0; i < numberOfPacket; i++) {
                        int sendDataSize;
                        if (remainedDataSize < PACKET_CAPACITY) {
                            sendDataSize = remainedDataSize;
                        } else {
                            sendDataSize = PACKET_CAPACITY;
                        }
                        
                        NSData *data = [NSData dataWithBytes:audioBufferPointer length:sendDataSize];
                        
                        if ([self.delegate respondsToSelector:@selector(streamer:didGetPacketData:)]) {
                            [self.delegate streamer:self didGetPacketData:data];
                        }
                        
                        remainedDataSize -= sendDataSize;
                        
                        if (i < numberOfPacket - 1) {
                            audioBufferPointer += PACKET_CAPACITY;
                        }
                    }
                }
                CMSampleBufferInvalidate(sampleBuffer);
                CFRelease(sampleBuffer);
                sampleBuffer = NULL;

            }
        }
        NSLog(@"Did finished streaming audio");
    });
    dispatch_release(streamingQueue);
}

- (void)cancleStreaming
{
    [self.assertReader cancelReading];
}

- (AudioStreamBasicDescription)getTrackNativeSettings:(AVAssetTrack *) track
{
    
    CMFormatDescriptionRef formDesc = (__bridge CMFormatDescriptionRef)[[track formatDescriptions] objectAtIndex:0];
    const AudioStreamBasicDescription* asbdPointer = CMAudioFormatDescriptionGetStreamBasicDescription(formDesc);
//    CFRelease(formDesc);
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
