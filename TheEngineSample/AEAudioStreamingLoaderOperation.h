//
//  AEAudioStreamingLoaderOperation.h
//  TheEngineSample
//
//  Created by joe on 15/07/21.
//  Copyright (c) 2015年 A Tasty Pixel. All rights reserved.
//

/*
 Responsibilites:
 - Fetches compressed audio file by network
 - Decodes audio from compressed format to LPCM
 - Saves LPCM into AudioBuffer
 */

#import <Foundation/Foundation.h>

@interface AEAudioStreamingLoaderOperation : NSOperation

@end
