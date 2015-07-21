//
//  AEStreamingChannel.h
//  TheAmazingAudioEngine
//
//  Created by joe on 15/07/21.
//  Copyright (c) 2015年 A Tasty Pixel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TheAmazingAudioEngine.h"

@interface AEStreamingChannel : NSObject <AEAudioPlayable>
/*!
 * Initialise
 *
 * @param audioController The Audio Controller
 */
- (id)initWithAudioController:(AEAudioController*)audioController;

@property (nonatomic, assign) float volume;
@property (nonatomic, assign) float pan;
@property (nonatomic, assign) BOOL channelIsMuted;
@property (nonatomic, readonly) AudioStreamBasicDescription audioDescription;
@end
