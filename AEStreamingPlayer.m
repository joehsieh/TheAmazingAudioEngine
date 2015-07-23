//
//  AEStreamingChannel.m
//  TheAmazingAudioEngine
//
//  Created by joe on 15/07/21.
//  Copyright (c) 2015年 A Tasty Pixel. All rights reserved.
//

#import "AEStreamingPlayer.h"
#import "AEAudioStreamingLoaderOperation.h"
#import <libkern/OSAtomic.h>

@interface AEStreamingPlayer ()
{
	AudioBufferList              *_audio;
}
@property (nonatomic, strong, readwrite) NSURL *url;
@property (nonatomic, strong) AEAudioStreamingLoaderOperation *audioStreamingLoaderOperation;
@end

@implementation AEStreamingPlayer
@synthesize url = _url, loop=_loop, volume=_volume, pan=_pan, channelIsPlaying=_channelIsPlaying, channelIsMuted=_channelIsMuted, removeUponFinish=_removeUponFinish, completionBlock = _completionBlock, startLoopBlock = _startLoopBlock;
// @dynamic currentTime, duration;

+ (id)audioFilePlayerWithURL:(NSURL*)url audioController:(AEAudioController *)audioController error:(NSError **)error {

	AEStreamingPlayer *player = [[self alloc] init];
	player->_volume = 1.0;
	player->_channelIsPlaying = YES;
	player.url = url;

	AEAudioStreamingLoaderOperation *operation = [[AEAudioStreamingLoaderOperation alloc] initWithURL:url];
	player.audioStreamingLoaderOperation = operation;

#warning check the retain cycle problems in block
	__block AEAudioStreamingLoaderOperation *weakOperation = operation;

	operation.didCompleteBlock = ^(){
		// Reached the end of the audio - either loop, or stop
		if ( player.loop ) {
			if ( player.startLoopBlock ) {
				// Notify main thread that the loop playback has restarted
				AEAudioControllerSendAsynchronousMessageToMainThread(audioController, notifyLoopRestart, (__bridge void *)(player), sizeof(AEStreamingPlayer*));
			}
		} else {
			// Notify main thread that playback has finished
			AEAudioControllerSendAsynchronousMessageToMainThread(audioController, notifyPlaybackStopped, (__bridge void *)(player), sizeof(AEStreamingPlayer*));
			player.channelIsPlaying = NO;
		}
		[weakOperation cancel];
		weakOperation = nil;
	};
	operation.didReceiveErrorBlock = ^(NSError *inError) {
		[weakOperation cancel];
		weakOperation = nil;
	};
	operation.didUpdateCurrentPlaybackTimeBlock = ^(NSTimeInterval inPlaybackTime){
//		NSLog(@"%@", @(inPlaybackTime));
	};
	[operation start];
	return player;
}

- (void)dealloc {
	if ( _audio ) {
		for ( int i=0; i<_audio->mNumberBuffers; i++ ) {
			free(_audio->mBuffers[i].mData);
		}
		free(_audio);
	}
}

- (void)replay
{
	AEAudioStreamingLoaderOperation *operation = [[AEAudioStreamingLoaderOperation alloc] initWithURL:_url];
	if (self.audioStreamingLoaderOperation) {
		[self.audioStreamingLoaderOperation cancel];
		self.audioStreamingLoaderOperation = nil;
	}
	self.audioStreamingLoaderOperation = operation;
}

static void notifyLoopRestart(AEAudioController *audioController, void *userInfo, int length) {
	AEStreamingPlayer *THIS = (__bridge AEStreamingPlayer*)*(void**)userInfo;

	if ( THIS.startLoopBlock ) THIS.startLoopBlock();
}

static void notifyPlaybackStopped(AEAudioController *audioController, void *userInfo, int length) {
	AEStreamingPlayer *THIS = (__bridge AEStreamingPlayer*)*(void**)userInfo;
	THIS.channelIsPlaying = NO;

	if ( THIS->_removeUponFinish ) {
		[audioController removeChannels:@[THIS]];
	}

	if ( THIS.completionBlock ) THIS.completionBlock();
}

static OSStatus renderCallback(__unsafe_unretained AEStreamingPlayer *THIS, __unsafe_unretained AEAudioController *audioController, const AudioTimeStamp *time, UInt32 frames, AudioBufferList *audio) {
	return  [THIS.audioStreamingLoaderOperation pullAudioData:audio timestamp:time frames:frames];
}

-(AEAudioControllerRenderCallback)renderCallback {
	return &renderCallback;
}
@end
