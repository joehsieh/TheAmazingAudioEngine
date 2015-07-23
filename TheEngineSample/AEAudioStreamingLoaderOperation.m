//
//  AEAudioStreamingLoaderOperation.m
//  TheEngineSample
//
//  Created by joe on 15/07/21.
//  Copyright (c) 2015年 A Tasty Pixel. All rights reserved.
//

#import "AEAudioStreamingLoaderOperation.h"
#import "AEAudioController.h"
#import "NJPacketArray.h"

#define checkResult(result,operation) (_checkResult((result),(operation),strrchr(__FILE__, '/')+1,__LINE__))
static inline BOOL _checkResult(OSStatus result, const char *operation, const char* file, int line) {
	if ( result != noErr ) {
		NSLog(@"%s:%d: %s result %d %08X %4.4s\n", file, line, operation, (int)result, (int)result, (char*)&result);
		return NO;
	}
	return YES;
}

void parserDidParseProperty (
							 void                        *inClientData,
							 AudioFileStreamID           inAudioFileStream,
							 AudioFileStreamPropertyID   inPropertyID,
							 UInt32                      *ioFlags
							 );

void parserDidParsePacket (
						   void                          *inClientData,
						   UInt32                        inNumberBytes,
						   UInt32                        inNumberPackets,
						   const void                    *inInputData,
						   AudioStreamPacketDescription  *inPacketDescriptions
						   );

OSStatus NJFillRawPacketData(AudioConverterRef               inAudioConverter,
							 UInt32*                         ioNumberDataPackets,
							 AudioBufferList*                ioData,
							 AudioStreamPacketDescription**  outDataPacketDescription,
							 void*                           inUserData);

@interface AEAudioStreamingLoaderOperation () <NSURLSessionDelegate>
@property (nonatomic, strong) NSURL *URL;
@property (nonatomic, strong) NSURLSession *URLSession;

@property (nonatomic, assign) AudioFileStreamID audioFileStreamID; // file stream parser
@property (nonatomic, assign) AudioConverterRef converter; // converter
@property (nonatomic, assign) AudioStreamBasicDescription asbdFromAudioStreaming;
@property (nonatomic, strong) NJPacketArray *packetArray;

@property (nonatomic, assign) AudioBufferList *bufferList;
@property (nonatomic, assign) BOOL enoughDataToPlay;
@property (nonatomic, assign) BOOL hasPacketsToPlay;
@end

@implementation AEAudioStreamingLoaderOperation

- (void)dealloc
{
	AudioConverterReset(_converter);
	_bufferList->mNumberBuffers = 1;
	_bufferList->mBuffers[0].mNumberChannels = 2;
	_bufferList->mBuffers[0].mDataByteSize = 0;
	bzero(_bufferList->mBuffers[0].mData, 0);
	AudioConverterDispose(_converter);
	free(_bufferList->mBuffers[0].mData);
	free(_bufferList);
}

- (instancetype)initWithURL:(NSURL *)inURL
{
	self = [super init];
	if (self) {
		self.URL = inURL;
		self.URLSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:nil];

		// Open file stream parser
		OSStatus status = AudioFileStreamOpen((__bridge void *)(self), parserDidParseProperty, parserDidParsePacket,  0, &_audioFileStreamID);

		if (!checkResult(status, "AudioFileStreamOpen")) {
			NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status
											 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Couldn't open file stream", @"")}];
			if (self.didReceiveErrorBlock) {
				self.didReceiveErrorBlock(error);
				return self;
			}
		}

		// Initialize array of packets
		self.packetArray = [[NJPacketArray alloc] init];
		UInt32 second = 1;
		UInt32 packetSize = 44100 * second * 8;
		_bufferList = (AudioBufferList *)calloc(1, sizeof(AudioBufferList));
		_bufferList->mNumberBuffers = 1;
		_bufferList->mBuffers[0].mNumberChannels = 2;
		_bufferList->mBuffers[0].mDataByteSize = packetSize;
		_bufferList->mBuffers[0].mData = calloc(1, packetSize);
	}
	return self;
}

- (void)main
{
	NSURLRequest *request = [[NSURLRequest alloc] initWithURL:self.URL];
	NSURLSessionTask *task = [self.URLSession dataTaskWithRequest:request];
	[task resume];
}

#pragma mark - NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
	if (self.didReceiveErrorBlock) {
		self.didReceiveErrorBlock(error);
		return;
	}
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
	[self ae_parseBytes:data]; // start to parse data
}


#pragma mark - Parser

- (void)ae_parseBytes:(NSData *)inData
{
	OSStatus status = AudioFileStreamParseBytes(self.audioFileStreamID, (UInt32)inData.length, inData.bytes, 0);
	if (!checkResult(status, "AudioFileStreamParseBytes")) {
		NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status
										 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Couldn't parse audio data", @"")}];
		if (self.didReceiveErrorBlock) {
			self.didReceiveErrorBlock(error);
			return;
		}
	}
}

#pragma mark - Converter

- (void)ae_createConverterByASBD:(AudioStreamBasicDescription)inASBD
{
	self.asbdFromAudioStreaming = inASBD;
	// create converter by ASBD
	AudioStreamBasicDescription LPCMASBD = [AEAudioController interleaved16BitStereoAudioDescription];
	AudioConverterNew(&inASBD, &LPCMASBD, &_converter);
}

- (void)ae_storePacket:(const void *)inData pakcageCount:(UInt32)inPacketCount packetDescription:(AudioStreamPacketDescription *)inPacketDescription
{
	@synchronized(self) {
		for (NSUInteger i = 0 ; i < inPacketCount; i++) {
			AudioStreamPacketDescription *packetDescription = &inPacketDescription[i];
			NJAudioPacketInfo *packetInfo = calloc(1, sizeof(NJAudioPacketInfo));
			packetInfo->data = malloc(packetDescription->mDataByteSize);
			memcpy(packetInfo->data, inData + packetDescription->mStartOffset, packetDescription->mDataByteSize);
			memcpy(&packetInfo->packetDescription, packetDescription, sizeof(AudioStreamPacketDescription));
			[self.packetArray storePacket:packetInfo];

		}
	}
}

- (OSStatus)pullAudioData:(AudioBufferList *)inBufferList timestamp:(const AudioTimeStamp *)inTimeStamp frames:(UInt32)inNumberFrames;
{
	if (!self.enoughDataToPlay) {
		return !noErr;
	}
	if (!self.hasPacketsToPlay) {
		[self.packetArray reset];
		if (self.didCompleteBlock) {
			self.didCompleteBlock();
		}
		return noErr;
	}
	OSStatus status = AudioConverterFillComplexBuffer(self.converter, NJFillRawPacketData, (__bridge void *)(self), &inNumberFrames, self.bufferList, NULL);

	if (!checkResult(status, "AudioConverterFillComplexBuffer")) {
		[self.packetArray reset];
		NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status
									 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Couldn't covert audio data", @"")}];
		if (self.didReceiveErrorBlock) {
			self.didReceiveErrorBlock(error);
			return status;
		}
	}

	if (noErr == status && inNumberFrames) {
		inBufferList->mNumberBuffers = 1;
		inBufferList->mBuffers[0].mNumberChannels = 2;
		inBufferList->mBuffers[0].mDataByteSize = self.bufferList->mBuffers[0].mDataByteSize;
		inBufferList->mBuffers[0].mData = self.bufferList->mBuffers[0].mData;
		status = noErr;
	}
	return status;
}

- (BOOL)hasPacketsToPlay
{
	return self.packetArray.hasPacketsToPlay;
}

@end

void parserDidParseProperty (
							 void                        *inClientData,
							 AudioFileStreamID           inAudioFileStream,
							 AudioFileStreamPropertyID   inPropertyID,
							 UInt32                      *ioFlags
							 )
{
	AEAudioStreamingLoaderOperation *self = (__bridge AEAudioStreamingLoaderOperation *)inClientData;
	if (inPropertyID == kAudioFileStreamProperty_DataFormat) {
		AudioStreamBasicDescription audioStreamDescription;
		UInt32 descriptionSize = sizeof(AudioStreamBasicDescription);
		OSStatus status = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_DataFormat, &descriptionSize, &audioStreamDescription);

		if (!checkResult(status, "AudioFileStreamGetProperty")) {
			[self.packetArray reset];
			NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status
											 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Couldn't get property", @"")}];
			if (self.didReceiveErrorBlock) {
				self.didReceiveErrorBlock(error);
			}
		}
		[self ae_createConverterByASBD:audioStreamDescription];

	}
	else if (inPropertyID == kAudioFileStreamProperty_ReadyToProducePackets) {
		self.enoughDataToPlay = YES;
	}
}

void parserDidParsePacket (
						   void                          *inClientData,
						   UInt32                        inNumberBytes,
						   UInt32                        inNumberPackets,
						   const void                    *inInputData,
						   AudioStreamPacketDescription  *inPacketDescriptions
						   )
{
	AEAudioStreamingLoaderOperation *self = (__bridge AEAudioStreamingLoaderOperation *)inClientData;
	[self ae_storePacket:inInputData pakcageCount:inNumberPackets packetDescription:inPacketDescriptions];
}

OSStatus NJFillRawPacketData(AudioConverterRef               inAudioConverter,
							 UInt32*                         ioNumberDataPackets,
							 AudioBufferList*                ioData,
							 AudioStreamPacketDescription**  outDataPacketDescription,
							 void*                           inUserData)
{
	AEAudioStreamingLoaderOperation *operation = (__bridge AEAudioStreamingLoaderOperation *)inUserData;
	NJAudioPacketInfo *packetInfo = [operation.packetArray readNextPacket];
	ioData->mNumberBuffers = 1;
	ioData->mBuffers[0].mDataByteSize = packetInfo->packetDescription.mDataByteSize;
	ioData->mBuffers[0].mData = packetInfo->data;
#warning we should not use aspd from retrieved packet directly.
	//	*outDataPacketDescription = &packetInfo.packetDescription;
	UInt32 length = packetInfo->packetDescription.mDataByteSize;
	static AudioStreamPacketDescription aspdesc;
	*outDataPacketDescription = &aspdesc;
	aspdesc.mDataByteSize = length;
	aspdesc.mStartOffset = 0;
	aspdesc.mVariableFramesInPacket = 1;
	if (operation.didUpdateCurrentPlaybackTimeBlock) {
		assert(operation.asbdFromAudioStreaming.mFramesPerPacket > 0);
		operation.didUpdateCurrentPlaybackTimeBlock(operation.packetArray.packetReadIndex * operation.asbdFromAudioStreaming.mFramesPerPacket / operation.asbdFromAudioStreaming.mSampleRate);
	}
	return noErr;
}
