//
//  AEAudioStreamingLoaderOperation.h
//  TheEngineSample
//
//  Created by joe on 15/07/21.
//  Copyright (c) 2015年 A Tasty Pixel. All rights reserved.
//

/*
 Responsibilites:
 - Fetches raw data by network (Fetcher)
 - Parse raw data to get part of compressed audio file (Parser)
 - Decodes audio from compressed format to LPCM (Converter)
 - Saves LPCM into AudioBuffer
 */

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

/*
 Problems
 - How to handle error of parsing audio data?
 */

@interface AEAudioStreamingLoaderOperation : NSOperation
- (instancetype)initWithURL:(NSURL *)inURL;
- (void)pullAudioData:(const AudioTimeStamp *)inTimeStamp frames:(UInt32)inFrames audio:(AudioBufferList *)inBufferList;
/*!
 * A block to use to receive audio
 *
 *  If this is set, then audio will be provided via this block as it is
 *  loaded, instead of stored within @link bufferList @endlink.
 */
@property (nonatomic, copy) void (^audioReceiverBlock)(AudioBufferList *audio, UInt32 lengthInFrames);

@property (nonatomic, copy) void (^completedBlock)();


/*!
 * The loaded audio, once operation has completed, unless @link audioReceiverBlock @endlink is set.
 *
 *  You are responsible for freeing both the memory pointed to by each mData pointer,
 *  as well as the buffer list itself. If an error occurred, this will be NULL.
 */
@property (nonatomic, readonly) AudioBufferList *bufferList;

/*!
 * The length of the audio file
 */
@property (nonatomic, readonly) UInt32 lengthInFrames;

/*!
 * The error, if one occurred
 */
@property (nonatomic, strong, readonly) NSError *error;
@property (nonatomic, assign, readonly) BOOL enoughDataToPlay;
@end
