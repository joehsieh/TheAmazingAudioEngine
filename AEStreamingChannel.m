//
//  AEStreamingChannel.m
//  TheAmazingAudioEngine
//
//  Created by joe on 15/07/21.
//  Copyright (c) 2015年 A Tasty Pixel. All rights reserved.
//

#import "AEStreamingChannel.h"
#import "TPCircularBuffer.h"
#import "TPCircularBuffer+AudioBufferList.h"

static const int kAudioBufferLength = 16384;

@interface AEStreamingChannel ()
{
	TPCircularBuffer _buffer;
}
@property (nonatomic, strong) AEAudioController *audioController;
@end

@implementation AEStreamingChannel

- (id)initWithAudioController:(AEAudioController*)audioController {
	if ( !(self = [super init]) ) return nil;
	TPCircularBufferInit(&_buffer, kAudioBufferLength);
	self.audioController = audioController;
	_volume = 1.0;
	return self;
}

- (void)dealloc {
	TPCircularBufferCleanup(&_buffer);
	self.audioController = nil;
}

static OSStatus renderCallback(__unsafe_unretained AEStreamingChannel *THIS,
							   __unsafe_unretained AEAudioController *audioController,
							   const AudioTimeStamp     *time,
							   UInt32                    frames,
							   AudioBufferList          *audio) {
	while ( 1 ) {
		// Discard any buffers with an incompatible format, in the event of a format change
		AudioBufferList *nextBuffer = TPCircularBufferNextBufferList(&THIS->_buffer, NULL);
		if ( !nextBuffer ) break;
		if ( nextBuffer->mNumberBuffers == audio->mNumberBuffers ) break;
		TPCircularBufferConsumeNextBufferList(&THIS->_buffer);
	}

	UInt32 fillCount = TPCircularBufferPeek(&THIS->_buffer, NULL, AEAudioControllerAudioDescription(audioController));
	if ( fillCount > frames ) {
		UInt32 skip = fillCount - frames;
		TPCircularBufferDequeueBufferListFrames(&THIS->_buffer,
												&skip,
												NULL,
												NULL,
												AEAudioControllerAudioDescription(audioController));
	}

	TPCircularBufferDequeueBufferListFrames(&THIS->_buffer,
											&frames,
											audio,
											NULL,
											AEAudioControllerAudioDescription(audioController));

	return noErr;
}

- (AEAudioControllerRenderCallback)renderCallback
{
	return &renderCallback;
}

- (AudioStreamBasicDescription)audioDescription
{
	return _audioController.audioDescription;
}
@end
