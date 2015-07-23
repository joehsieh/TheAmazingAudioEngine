//
//  NJPacketArray.h
//  EasyPlayer
//
//  Created by joehsieh on 2014/12/25.
//  Copyright (c) 2014年 NJ. All rights reserved.
//

/*
 Renames this class
 */

@import Foundation;
@import AudioToolbox;

typedef struct {
    AudioStreamPacketDescription packetDescription;
    void *data;
} NJAudioPacketInfo;

@interface NJPacketArray : NSObject
- (void)reset;
- (void)storePacket:(NJAudioPacketInfo *)packetInfo;
- (NJAudioPacketInfo *)readNextPacket;
@property (nonatomic, assign, readonly) BOOL hasPacketsToPlay;
@property (nonatomic, assign, readonly) NSUInteger packetReadIndex;
@end
