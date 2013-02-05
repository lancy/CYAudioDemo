//
//  CYAudioQueuePlayer.m
//  CYAudioDemo
//
//  Created by Lancy on 3/2/13.
//  Copyright (c) 2013 Lancy. All rights reserved.
//

#import "CYAudioQueuePlayer.h"


#define kNumberPlaybackBuffers	16

#define kAQMaxPacketDescs 6	// Number of packet descriptions in our array (formerly 512)

typedef enum
{
	AS_INITIALIZED = 0,
	AS_STARTING_FILE_THREAD,
    AS_BUFFERING,
	AS_PLAYING,
    AS_STOPPED
} AudioStreamerState;

typedef struct MyPlayer {
	// AudioQueueRef				queue; // the audio queue object
	// AudioStreamBasicDescription dataFormat; // file's data stream description
	AudioFileID					playbackFile; // reference to your output file
	SInt64						packetPosition; // current packet index in output file
	UInt32						numPacketsToRead; // number of packets to read from file
	AudioStreamPacketDescription *packetDescs; // array of packet descriptions for read buffer
	// AudioQueueBufferRef			buffers[kNumberPlaybackBuffers];
	Boolean						isDone; // playback has completed
} MyPlayer;


@interface CYAudioQueuePlayer()
{
    UInt32 _bufferByteSize;
    size_t _bytesFilled;				// how many bytes have been filled
    size_t _packetsFilled;			// how many packets have been filled
    
    AudioQueueBufferRef	_audioQueueBuffers[kNumberPlaybackBuffers];
    
    AudioStreamPacketDescription _packetDescs[kAQMaxPacketDescs];	// packet descriptions for enqueuing audio
    bool _inuse[kNumberPlaybackBuffers];			// flags to indicate that a buffer is still in use
    unsigned int _fillBufferIndex;	// the index of the audioQueueBuffer that is being filled
    
    NSThread *_internalThread;
    
    pthread_mutex_t _queueBuffersMutex;			// a mutex to protect the inuse flags
	pthread_cond_t _queueBufferReadyCondition;	// a condition varable for handling the inuse flags
    
    NSInteger _buffersUsed;
    
    AudioStreamerState _state;
    
   	OSStatus _err;
    
   	AudioQueueRef _queue;
    MyPlayer _player;

}

@end

@implementation CYAudioQueuePlayer

- (void)setupQueueWithAudioStreamBasicDescription:(AudioStreamBasicDescription)audioStreamBasicDescription;
{
    AudioStreamBasicDescription asbd = audioStreamBasicDescription;
    
    CheckError(AudioQueueNewOutput(&asbd, // ASBD
                                   audioQueueOutputCallback, // Callback
                                   (__bridge void *)self, // user data
                                   NULL, // run loop
                                   NULL, // run loop mode
                                   0, // flags (always 0)
                                   &_queue), // output: reference to AudioQueue object
               "AudioQueueNewOutput failed");
    
    
    
    // adjust buffer size to represent about a half second (0.5) of audio based on this format
    CalculateBytesForTime(asbd,  0.5, &_bufferByteSize, &_player.numPacketsToRead);
    _bufferByteSize = 2048;
    NSLog(@"this is buffer byte size %lu", _bufferByteSize);
    //   bufferByteSize = 800;
    
    // get magic cookie from file and set on queue
    MyCopyEncoderCookieToQueue(_player.playbackFile, _queue);
    
    // allocate the buffers and prime the queue with some data before starting
    _player.isDone = false;
    _player.packetPosition = 0;
    int i;
    for (i = 0; i < kNumberPlaybackBuffers; ++i)
    {
        CheckError(AudioQueueAllocateBuffer(_queue, _bufferByteSize, &_audioQueueBuffers[i]), "AudioQueueAllocateBuffer failed");
        
        // EOF (the entire file's contents fit in the buffers)
        if (_player.isDone)
            break;
    }
    
    AudioSessionInitialize (
                            NULL,                          // 'NULL' to use the default (main) run loop
                            NULL,                          // 'NULL' to use the default run loop mode
                            NULL,  //ASAudioSessionInterruptionListenera reference to your interruption callback
                            NULL                       // data to pass to your interruption listener callback
                            );
    UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
    AudioSessionSetProperty (
                             kAudioSessionProperty_AudioCategory,
                             sizeof (sessionCategory),
                             &sessionCategory
                             );
    AudioSessionSetActive(true);
    
    [self performSelectorInBackground:@selector(waitUntilDone) withObject:nil];

    
}

- (void)waitUntilDone
{
    // start the queue. this function returns immedatly and begins
    // invoking the callback, as needed, asynchronously.
    //CheckError(AudioQueueStart(queue, NULL), "AudioQueueStart failed");
    
    // and wait
    printf("Playing...\n");
    do
    {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.25, false);
    } while (!_player.isDone /*|| gIsRunning*/);
    
    // isDone represents the state of the Audio File enqueuing. This does not mean the
    // Audio Queue is actually done playing yet. Since we have 3 half-second buffers in-flight
    // run for continue to run for a short additional time so they can be processed
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 2, false);
    
    // end playback
    _player.isDone = true;
    CheckError(AudioQueueStop(_queue, TRUE), "AudioQueueStop failed");
    
cleanup:
    AudioQueueDispose(_queue, TRUE);
    AudioFileClose(_player.playbackFile);
}


#pragma mark - buffer handler

- (void)handleSampleBuffer:(CMSampleBufferRef)sample
{
    _state = AS_BUFFERING;
    
    CMItemCount numSamples = CMSampleBufferGetNumSamples(sample);
    
    if (!sample || (numSamples == 0)) {
        return;
    }
    
    Boolean isBufferDataReady = CMSampleBufferDataIsReady(sample);
    
    if (!isBufferDataReady) {
        while (!isBufferDataReady) {
            NSLog(@"buffer is not ready!");
        }
    }
    
    CMBlockBufferRef CMBuffer = CMSampleBufferGetDataBuffer(sample);
    AudioBufferList audioBufferList;
    
    CheckError(CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
                                                                       sample,
                                                                       NULL,
                                                                       &audioBufferList,
                                                                       sizeof(audioBufferList),
                                                                       NULL,
                                                                       NULL,
                                                                       kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
                                                                       &CMBuffer
                                                                       ),
               "could not read sample data");
    
    const AudioStreamPacketDescription   * inPacketDescriptions;
    size_t								 packetDescriptionsSizeOut;
    size_t inNumberPackets;
    
    CheckError(CMSampleBufferGetAudioStreamPacketDescriptionsPtr(sample,
                                                                 &inPacketDescriptions,
                                                                 &packetDescriptionsSizeOut),
               "could not read sample packet descriptions");
    
    inNumberPackets = packetDescriptionsSizeOut/sizeof(AudioStreamPacketDescription);
    
    AudioBuffer audioBuffer = audioBufferList.mBuffers[0];
    
    for (int i = 0; i < inNumberPackets; ++i)
    {
        
        SInt64 dataOffset = inPacketDescriptions[i].mStartOffset;
        UInt32 packetSize   = inPacketDescriptions[i].mDataByteSize;
        
        size_t packetSpaceRemaining;
        packetSpaceRemaining = _bufferByteSize - _bytesFilled;
        
        // if the space remaining in the buffer is not enough for the data contained in this packet
        // then just write it
        if (packetSpaceRemaining < packetSize)
        {
            // NSLog(@"oops! packetSpaceRemaining (%zu) is smaller than datasize (%lu) SO WE WILL SHIP PACKET [%d]: (abs number %lu)",
            //     packetSpaceRemaining, dataSize, i, packetNumber);
            
            [self enqueueBuffer];
            
            
            //                [self encapsulateAndShipPacket:packet packetDescriptions:packetDescriptions packetID:assetID];
        }
        
        
        // copy data to the audio queue buffer
        AudioQueueBufferRef fillBuf = _audioQueueBuffers[_fillBufferIndex];
        memcpy((char*)fillBuf->mAudioData + _bytesFilled,
               (const char*)(audioBuffer.mData + dataOffset), packetSize);
        
        
        
        // fill out packet description
        _packetDescs[_packetsFilled] = inPacketDescriptions[i];
        _packetDescs[_packetsFilled].mStartOffset = _bytesFilled;
        
        
        _bytesFilled += packetSize;
        _packetsFilled += 1;
        
        
        // if this is the last packet, then ship it
        size_t packetsDescsRemaining = kAQMaxPacketDescs - _packetsFilled;
        if (packetsDescsRemaining == 0) {
            //NSLog(@"woooah! this is the last packet (%d).. so we will ship it!", i);
            [self enqueueBuffer];
            //  [self encapsulateAndShipPacket:packet packetDescriptions:packetDescriptions packetID:assetID];
        }
    }
}
//


- (void)enqueueBuffer
{
    @synchronized(self)
    {
        
        _inuse[_fillBufferIndex] = true;		// set in use flag
        _buffersUsed++;
        
        // enqueue buffer
        AudioQueueBufferRef fillBuf = _audioQueueBuffers[_fillBufferIndex];
        fillBuf->mAudioDataByteSize = _bytesFilled;
        
		if (_packetsFilled)
		{
			_err = AudioQueueEnqueueBuffer(_queue, fillBuf, _packetsFilled, _packetDescs);
		}
		else
		{
			_err = AudioQueueEnqueueBuffer(_queue, fillBuf, 0, NULL);
		}
        
        if (_err)
        {
            NSLog(@"could not enqueue queue with buffer");
            return;
        }
        
        
        if (_state == AS_BUFFERING)
        {
            //
            // Fill all the buffers before starting. This ensures that the
            // AudioFileStream stays a small amount ahead of the AudioQueue to
            // avoid an audio glitch playing streaming files on iPhone SDKs < 3.0
            //
            if (_buffersUsed == kNumberPlaybackBuffers - 1)
            {
//                NSLog(@"STARTING THE QUEUE");
                _err = AudioQueueStart(_queue, NULL);
                if (_err)
                {
                    NSLog(@"couldn't start queue");
                    return;
                }
                _state = AS_PLAYING;
            }
        }
        
        // go to next buffer
        if (++_fillBufferIndex >= kNumberPlaybackBuffers) _fillBufferIndex = 0;
        _bytesFilled = 0;		// reset bytes filled
   		_packetsFilled = 0;		// reset packets filled
        
    }
    
    // wait until next buffer is not in use
    pthread_mutex_lock(&_queueBuffersMutex);
    while (_inuse[_fillBufferIndex])
    {
        pthread_cond_wait(&_queueBufferReadyCondition, &_queueBuffersMutex);
    }
    pthread_mutex_unlock(&_queueBuffersMutex);
}

#pragma mark - call back function

static void audioQueueOutputCallback(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inCompleteAQBuffer)
{
    CYAudioQueuePlayer *audioQueuePlayer = (__bridge CYAudioQueuePlayer *) inUserData;
    [audioQueuePlayer myCallback:inUserData
               inAudioQueue:inAQ
        audioQueueBufferRef:inCompleteAQBuffer];
    
}

- (void)myCallback:(void *)userData
      inAudioQueue:(AudioQueueRef)inAQ
audioQueueBufferRef:(AudioQueueBufferRef)inCompleteAQBuffer
{
    
    unsigned int bufIndex = -1;
    for (unsigned int i = 0; i < kNumberPlaybackBuffers; ++i)
    {
        if (inCompleteAQBuffer == _audioQueueBuffers[i])
        {
            bufIndex = i;
            break;
        }
    }
    
    if (bufIndex == -1)
    {
        NSLog(@"something went wrong at queue callback");
        return;
    }
    
    
//    NSLog(@"in call back and we are freeing buf index %d", bufIndex);
    _inuse[bufIndex] = false;
    _buffersUsed--;
}

#pragma mark - Utility functions

// many encoded formats require a 'magic cookie'. if the file has a cookie we get it
// and configure the queue with it
static void MyCopyEncoderCookieToQueue(AudioFileID theFile, AudioQueueRef queue ) {
    UInt32 propertySize;
    OSStatus result = AudioFileGetPropertyInfo (theFile, kAudioFilePropertyMagicCookieData, &propertySize, NULL);
    if (result == noErr && propertySize > 0)
    {
        Byte* magicCookie = (UInt8*)malloc(sizeof(UInt8) * propertySize);
        CheckError(AudioFileGetProperty (theFile, kAudioFilePropertyMagicCookieData, &propertySize, magicCookie), "get cookie from file failed");
        CheckError(AudioQueueSetProperty(queue, kAudioQueueProperty_MagicCookie, magicCookie, propertySize), "set cookie on queue failed");
        free(magicCookie);
    }
}


void CalculateBytesForTime(AudioStreamBasicDescription inDesc, Float64 inSeconds, UInt32 *outBufferSize, UInt32 *outNumPackets)
{
    
    // we need to calculate how many packets we read at a time, and how big a buffer we need.
    // we base this on the size of the packets in the file and an approximate duration for each buffer.
    //
    // first check to see what the max size of a packet is, if it is bigger than our default
    // allocation size, that needs to become larger
    
    // we don't have access to file packet size, so we just default it to maxBufferSize
    UInt32 maxPacketSize = 0x10000;
    
    static const int maxBufferSize = 0x10000; // limit size to 64K
    static const int minBufferSize = 0x4000; // limit size to 16K
    
    if (inDesc.mFramesPerPacket) {
        Float64 numPacketsForTime = inDesc.mSampleRate / inDesc.mFramesPerPacket * inSeconds;
        *outBufferSize = numPacketsForTime * maxPacketSize;
    } else {
        // if frames per packet is zero, then the codec has no predictable packet == time
        // so we can't tailor this (we don't know how many Packets represent a time period
        // we'll just return a default buffer size
        *outBufferSize = maxBufferSize > maxPacketSize ? maxBufferSize : maxPacketSize;
    }
    
    // we're going to limit our size to our default
    if (*outBufferSize > maxBufferSize && *outBufferSize > maxPacketSize)
        *outBufferSize = maxBufferSize;
    else {
        // also make sure we're not too small - we don't want to go the disk for too small chunks
        if (*outBufferSize < minBufferSize)
            *outBufferSize = minBufferSize;
    }
    *outNumPackets = *outBufferSize / maxPacketSize;
}

// generic error handler - if err is nonzero, prints error message and exits program.
static void CheckError(OSStatus error, const char *operation)
{
    if (error == noErr) return;
        
    char str[20];
    // see if it appears to be a 4-char-code
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
