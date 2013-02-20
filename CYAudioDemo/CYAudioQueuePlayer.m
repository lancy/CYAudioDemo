//
//  CYAudioQueuePlayer.m
//  CYAudioDemo
//
//  Created by Lancy on 3/2/13.
//  Copyright (c) 2013 Lancy. All rights reserved.
//

#import "CYAudioQueuePlayer.h"


#define kNumberPlaybackBuffers	3

#define kAQMaxPacketDescs 6	// Number of packet descriptions in our array (formerly 512)

typedef enum
{
	AS_INITIALIZED = 0,
    AS_PAUSE,
    AS_BUFFERING,
	AS_PLAYING,
    AS_STOPPED
} AudioQueuePlayerState;


@interface CYAudioQueuePlayer()
{
    UInt32 _bufferByteSize;
    
    AudioQueueBufferRef	_audioQueueBuffers[kNumberPlaybackBuffers];
    
    AudioStreamPacketDescription _packetDescs[kAQMaxPacketDescs];	// packet descriptions for enqueuing audio
    bool _inuse[kNumberPlaybackBuffers];			// flags to indicate that a buffer is still in use
    unsigned int _fillBufferIndex;	// the index of the audioQueueBuffer that is being filled
        
    pthread_mutex_t _queueBuffersMutex;			// a mutex to protect the inuse flags
	pthread_cond_t _queueBufferReadyCondition;	// a condition varable for handling the inuse flags
    
    NSInteger _buffersUsed;
    
    AudioQueuePlayerState _state;
    
   	OSStatus _err;
   	AudioQueueRef _queue;
    
}

@property (nonatomic, strong) NSOperationQueue *operationQueue;
@property (nonatomic, strong) NSMutableArray *packetsDatas;
@property (assign) NSUInteger packetUsedIndex;

@property (assign) BOOL isFinishedPlaying;

@end

@implementation CYAudioQueuePlayer

- (void)setupQueueWithAudioStreamBasicDescription:(AudioStreamBasicDescription)audioStreamBasicDescription;
{
    pthread_mutex_init(&_queueBuffersMutex, NULL);
    pthread_cond_init(&_queueBufferReadyCondition, NULL);
    
    _state = AS_INITIALIZED;

    self.packetsDatas = [NSMutableArray array];
    self.packetUsedIndex = 0;
    
    self.operationQueue = [[NSOperationQueue alloc] init];
    [self.operationQueue setMaxConcurrentOperationCount:1];
    [self.operationQueue addObserver:self forKeyPath:@"operations" options:0 context:NULL];
    
    AudioStreamBasicDescription asbd = audioStreamBasicDescription;
    
    CheckError(AudioQueueNewOutput(&asbd, // ASBD
                                   audioQueueOutputCallback, // Callback
                                   (__bridge void *)self, // user data
                                   NULL, // run loop
                                   NULL, // run loop mode
                                   0, // flags (always 0)
                                   &_queue), // output: reference to AudioQueue object
               "AudioQueueNewOutput failed");
    
    
    
    _bufferByteSize = 2048;
    int i;
    for (i = 0; i < kNumberPlaybackBuffers; ++i)
    {
        CheckError(AudioQueueAllocateBuffer(_queue, _bufferByteSize, &_audioQueueBuffers[i]), "AudioQueueAllocateBuffer failed");
    }
    
    AudioQueueAddPropertyListener(_queue, kAudioQueueProperty_IsRunning, audioQueueFinishedPlayingCallback, (__bridge void *)self);
}

- (BOOL)isPlaying
{
    if (_state == AS_PLAYING) {
        return YES;
    } else {
        return NO;
    }
}

- (void)startQueue;
{
    _state = AS_PLAYING;
    AudioQueueStart(_queue, NULL);
}


- (void)pauseQueue
{
    _state = AS_PAUSE;
    AudioQueuePause(_queue);
}



- (void)stopQueue
{
    _state = AS_STOPPED;
    AudioQueueStop(_queue, TRUE);
    [self.operationQueue cancelAllOperations];
    self.packetUsedIndex = 0;
    [self.packetsDatas removeAllObjects];
    self.packetsDatas = nil;
}

- (void)disposeQueue
{
    AudioQueueDispose(_queue, TRUE);
}


#pragma mark - handle operation queue completed
- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                         change:(NSDictionary *)change context:(void *)context
{
    if (object == self.operationQueue && [keyPath isEqualToString:@"operations"]) {
        if ([self.operationQueue.operations count] == 0) {
            [self stopQueue];
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object
                               change:change context:context];
    }
}


#pragma mark - buffer handler

- (void)handlePacketData:(NSData *)packetData
{
    NSBlockOperation *appendDataOperation = [NSBlockOperation blockOperationWithBlock:^{
        [self.packetsDatas addObject:packetData];
    }];
    NSBlockOperation *enqueueBufferOperation = [NSBlockOperation blockOperationWithBlock:^{
            [self enqueueBuffer];
    }];
    [enqueueBufferOperation addDependency:appendDataOperation];
    [self.operationQueue addOperation:appendDataOperation];
    [self.operationQueue addOperation:enqueueBufferOperation];
}

- (void)enqueueBuffer
{
    @synchronized(self)
    {
        NSData *packetData = self.packetsDatas[self.packetUsedIndex];
        self.packetUsedIndex++;
        UInt32 packetSize = [packetData length];
        void *packetDataPointer = alloca(packetSize);
        [packetData getBytes:packetDataPointer length:packetSize];
        
        AudioQueueBufferRef fillBuf = _audioQueueBuffers[_fillBufferIndex];
        memcpy((char*)fillBuf->mAudioData,
               (const char*)(packetDataPointer), packetSize);
        
        // fill out packet description
        _packetDescs[0].mDataByteSize = packetSize;
        _packetDescs[0].mStartOffset = 0;
            
        _inuse[_fillBufferIndex] = true;		// set in use flag
        _buffersUsed++;
        
        // enqueue buffer
        fillBuf->mAudioDataByteSize = packetSize;
                
        _err = AudioQueueEnqueueBuffer(_queue, fillBuf, 1, _packetDescs);
        if (_err)
        {
            NSLog(@"could not enqueue queue with buffer");
            return;
        }
        
        // go to next buffer
        if (++_fillBufferIndex >= kNumberPlaybackBuffers) _fillBufferIndex = 0;
        
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
    
    pthread_mutex_lock(&_queueBuffersMutex);
    
    _inuse[bufIndex] = false;
    _buffersUsed--;
    
    pthread_cond_signal(&_queueBufferReadyCondition);
    pthread_mutex_unlock(&_queueBuffersMutex);

    
}

void audioQueueFinishedPlayingCallback (
                                       void                  *inUserData,
                                       AudioQueueRef         inAQ,
                                       AudioQueuePropertyID  inID
                                       )
{
    UInt32 isRunning;
    UInt32 dataSize = sizeof(UInt32);
    AudioQueueGetProperty(inAQ, inID, &isRunning, &dataSize);
    if (isRunning == 0) {
        CYAudioQueuePlayer *audioQueuePlayer = (__bridge CYAudioQueuePlayer *) inUserData;
        [audioQueuePlayer didStopPlaying];
    }
}

- (void)didStopPlaying
{
    if (self.operationQueue.operationCount == 0) {
        self.isFinishedPlaying = YES;
    } else {
        self.isFinishedPlaying = NO;
    }
    if ([self.delegate respondsToSelector:@selector(player:didStopPlayingWithFinishedFlag:)]) {
        [self.delegate player:self didStopPlayingWithFinishedFlag:self.isFinishedPlaying];
    }
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
