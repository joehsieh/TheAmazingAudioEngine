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

/*
 Error handling:
 - error of network problems
 - error of parsing packets
 - error of convert packets
 */

/*
 Check code running on which thread
 - 
 - 
 */
#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface AEAudioStreamingLoaderOperation : NSOperation
- (instancetype)initWithURL:(NSURL *)inURL;
- (OSStatus)pullAudioData:(AudioBufferList *)inBufferList timestamp:(const AudioTimeStamp *)inTimeStamp frames:(UInt32)inFrames;
@property (nonatomic, copy) void (^didCompleteBlock)();
@property (nonatomic, copy) void (^didReceiveErrorBlock)();
@property (nonatomic, copy) void (^didUpdateCurrentPlaybackTimeBlock)(NSTimeInterval time);
@end
