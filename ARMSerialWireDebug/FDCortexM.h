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

+ (nonnull NSString *)debugPortIDCodeDescription:(uint32_t)debugPortIDCode;
+ (nonnull NSString *)cpuIDDescription:(uint32_t)cpuID;

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
