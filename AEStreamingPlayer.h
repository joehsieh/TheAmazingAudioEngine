//
//  AEStreamingChannel.h
//  TheAmazingAudioEngine
//
//  Created by joe on 15/07/21.
//  Copyright (c) 2015年 A Tasty Pixel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TheAmazingAudioEngine.h"


/* TODO
	- Shows alert when error occurred.
	- Checks threads which running these code.
    - Profile
 */

@interface AEStreamingPlayer : NSObject <AEAudioPlayable>
/*!
 * Initialise
 *
 * @param audioController The Audio Controller
 */
+ (id)audioFilePlayerWithURL:(NSURL*)url audioController:(AEAudioController*)audioController error:(NSError**)error;

@property (nonatomic, strong, readonly) NSURL *url;         //!< Original media URL
@property (nonatomic, readwrite) BOOL loop;                 //!< Whether to loop this track
@property (nonatomic, readwrite) float volume;              //!< Track volume
@property (nonatomic, readwrite) float pan;                 //!< Track pan
@property (nonatomic, readwrite) BOOL channelIsPlaying;     //!< Whether the track is playing
@property (nonatomic, readwrite) BOOL channelIsMuted;       //!< Whether the track is muted
@property (nonatomic, readwrite) BOOL removeUponFinish;     //!< Whether the track automatically removes itself from the audio controller after playback completes
@property (nonatomic, copy) void(^completionBlock)();       //!< A block to be called when playback finishes
@property (nonatomic, copy) void(^startLoopBlock)();        //!< A block to be called when the loop restarts in loop mode
- (void)replay;
@end
