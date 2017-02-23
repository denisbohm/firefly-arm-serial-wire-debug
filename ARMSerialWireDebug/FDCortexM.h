//
//  FDCortexM.h
//  ARMSerialWireDebug
//
//  Created by Denis Bohm on 1/7/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import <Foundation/Foundation.h>

#define CORTEX_M_REGISTER_R0    0
#define CORTEX_M_REGISTER_R1    1
#define CORTEX_M_REGISTER_R2    2
#define CORTEX_M_REGISTER_R3    3
#define CORTEX_M_REGISTER_R4    4
#define CORTEX_M_REGISTER_R5    5
#define CORTEX_M_REGISTER_R6    6
#define CORTEX_M_REGISTER_R7    7
#define CORTEX_M_REGISTER_R8    8
#define CORTEX_M_REGISTER_R9    9
#define CORTEX_M_REGISTER_R10  10
#define CORTEX_M_REGISTER_R11  11
#define CORTEX_M_REGISTER_R12  12
#define CORTEX_M_REGISTER_IP   12
#define CORTEX_M_REGISTER_R13  13
#define CORTEX_M_REGISTER_SP   13
#define CORTEX_M_REGISTER_R14  14
#define CORTEX_M_REGISTER_LR   14
#define CORTEX_M_REGISTER_R15  15
#define CORTEX_M_REGISTER_PC   15
#define CORTEX_M_REGISTER_XPSR 16
#define CORTEX_M_REGISTER_MSP  17
#define CORTEX_M_REGISTER_PSP  18

#define CORTEX_M_REGISTER_S0  0x40
#define CORTEX_M_REGISTER_S1  0x41
#define CORTEX_M_REGISTER_S2  0x42
#define CORTEX_M_REGISTER_S3  0x43
#define CORTEX_M_REGISTER_S4  0x44
#define CORTEX_M_REGISTER_S5  0x45
#define CORTEX_M_REGISTER_S6  0x46
#define CORTEX_M_REGISTER_S7  0x47
#define CORTEX_M_REGISTER_S8  0x48
#define CORTEX_M_REGISTER_S9  0x49
#define CORTEX_M_REGISTER_S10 0x4a
#define CORTEX_M_REGISTER_S11 0x4b
#define CORTEX_M_REGISTER_S12 0x4c
#define CORTEX_M_REGISTER_S13 0x4d
#define CORTEX_M_REGISTER_S14 0x4e
#define CORTEX_M_REGISTER_S15 0x4f
#define CORTEX_M_REGISTER_S16 0x50
#define CORTEX_M_REGISTER_S17 0x51
#define CORTEX_M_REGISTER_S18 0x52
#define CORTEX_M_REGISTER_S19 0x53
#define CORTEX_M_REGISTER_S20 0x54
#define CORTEX_M_REGISTER_S21 0x55
#define CORTEX_M_REGISTER_S22 0x56
#define CORTEX_M_REGISTER_S23 0x57
#define CORTEX_M_REGISTER_S24 0x58
#define CORTEX_M_REGISTER_S25 0x59
#define CORTEX_M_REGISTER_S26 0x5a
#define CORTEX_M_REGISTER_S27 0x5b
#define CORTEX_M_REGISTER_S28 0x5c
#define CORTEX_M_REGISTER_S29 0x5d
#define CORTEX_M_REGISTER_S30 0x5e
#define CORTEX_M_REGISTER_S31 0x5f

@interface FDAddressRange : NSObject
@property UInt32 location;
@property UInt32 length;
@end

@class FDLogger;
@class FDSerialWireDebug;

@interface FDCortexM : NSObject

@property (nullable) FDSerialWireDebug *serialWireDebug;
@property (nonnull) FDLogger *logger;

@property (nonnull) FDAddressRange *programRange;
@property (nonnull) FDAddressRange *stackRange;
@property (nonnull) FDAddressRange *heapRange;
@property uint32_t breakLocation;

- (BOOL)setupCall:(UInt32)pc r0:(uint32_t)r0 r1:(uint32_t)r1 r2:(uint32_t)r2 r3:(uint32_t)r3 run:(BOOL)run error:(NSError * _Nullable * _Nullable)error;
- (BOOL)start:(UInt32)pc r0:(uint32_t)r0 r1:(uint32_t)r1 r2:(uint32_t)r2 r3:(uint32_t)r3 error:(NSError * _Nullable * _Nullable)error;
- (BOOL)waitForHalt:(NSTimeInterval)timeout resultR0:(nonnull UInt32 *)resultR0 error:(NSError * _Nullable * _Nullable)error;

- (BOOL)run:(UInt32)pc r0:(uint32_t)r0 r1:(uint32_t)r1 r2:(uint32_t)r2 r3:(uint32_t)r3 timeout:(NSTimeInterval)timeout resultR0:(nonnull UInt32 *)resultR0 error:(NSError * _Nullable * _Nullable)error;
- (BOOL)run:(UInt32)pc r0:(uint32_t)r0 r1:(uint32_t)r1 r2:(uint32_t)r2 timeout:(NSTimeInterval)timeout resultR0:(nonnull UInt32 *)resultR0 error:(NSError * _Nullable * _Nullable)error;
- (BOOL)run:(UInt32)pc r0:(uint32_t)r0 r1:(uint32_t)r1 timeout:(NSTimeInterval)timeout resultR0:(nonnull UInt32 *)resultR0 error:(NSError * _Nullable * _Nullable)error;
- (BOOL)run:(UInt32)pc r0:(uint32_t)r0 timeout:(NSTimeInterval)timeout resultR0:(nonnull UInt32 *)resultR0 error:(NSError * _Nullable * _Nullable)error;
- (BOOL)run:(UInt32)pc timeout:(NSTimeInterval)timeout resultR0:(nonnull UInt32 *)resultR0 error:(NSError * _Nullable * _Nullable)error;

- (BOOL)run:(UInt32)pc r0:(uint32_t)r0 r1:(uint32_t)r1 r2:(uint32_t)r2 r3:(uint32_t)r3 timeout:(NSTimeInterval)timeout error:(NSError * _Nullable * _Nullable)error;
- (BOOL)run:(UInt32)pc r0:(uint32_t)r0 r1:(uint32_t)r1 r2:(uint32_t)r2 timeout:(NSTimeInterval)timeout error:(NSError * _Nullable * _Nullable)error;
- (BOOL)run:(UInt32)pc r0:(uint32_t)r0 r1:(uint32_t)r1 timeout:(NSTimeInterval)timeout error:(NSError * _Nullable * _Nullable)error;
- (BOOL)run:(UInt32)pc r0:(uint32_t)r0 timeout:(NSTimeInterval)timeout error:(NSError * _Nullable * _Nullable)error;
- (BOOL)run:(UInt32)pc timeout:(NSTimeInterval)timeout error:(NSError * _Nullable * _Nullable)error;

@end
