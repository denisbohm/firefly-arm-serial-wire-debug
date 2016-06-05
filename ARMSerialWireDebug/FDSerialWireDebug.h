//
//  FDSerialWireDebug.h
//  ARMSerialWireDebug
//
//  Created by Denis Bohm on 1/7/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FDLogger;
@class FDSerialEngine;

@interface FDSerialWireDebug : NSObject

@property (nullable) FDSerialEngine *serialEngine;
@property (nonnull) FDLogger *logger;

@property UInt16 clockDivisor;

@property BOOL maskInterrupts;

@property BOOL minimalDebugPort;

- (BOOL)initialize:(NSError * _Nullable * _Nullable)error;

- (BOOL)getGpioDetect:(nonnull BOOL *)detect error:(NSError * _Nullable * _Nullable)error;

- (void)setGpioIndicator:(BOOL)value;
- (void)setGpioReset:(BOOL)value;

- (void)detachDebugPort;
- (void)resetDebugPort;
- (BOOL)readDebugPortIDCode:(nonnull UInt32 *)value error:(NSError * _Nullable * _Nullable)error;
- (BOOL)readTargetID:(nonnull UInt32 *)value error:(NSError * _Nullable * _Nullable)error;
- (BOOL)initializeDebugPort:(NSError * _Nullable * _Nullable)error;

- (BOOL)isAuthenticationAccessPortActive:(nonnull BOOL *)value error:(NSError * _Nullable * _Nullable)error;
- (BOOL)authenticationAccessPortErase:(NSError * _Nullable * _Nullable)error;
- (BOOL)authenticationAccessPortReset:(NSError * _Nullable * _Nullable)error;

- (BOOL)readAccessPortID:(UInt8)accessPort value:(nonnull UInt32 *)value error:(NSError * _Nullable * _Nullable)error;
- (BOOL)initializeAccessPort:(NSError * _Nullable * _Nullable)error;

- (BOOL)readCPUID:(nonnull UInt32 *)value error:(NSError * _Nullable * _Nullable)error;

- (BOOL)checkDebugPortStatus:(NSError * _Nullable * _Nullable)error;

- (BOOL)readMemory:(UInt32)address value:(nonnull UInt32 *)value error:(NSError * _Nullable * _Nullable)error;
- (BOOL)writeMemory:(UInt32)address value:(UInt32)value error:(NSError * _Nullable * _Nullable)error;

- (BOOL)writeMemory:(UInt32)address data:(nonnull NSData *)data error:(NSError * _Nullable * _Nullable)error;
- (nullable NSData *)readMemory:(UInt32)address length:(UInt32)length error:(NSError * _Nullable * _Nullable)error;

- (BOOL)readMemoryUInt8:(UInt32)address value:(nonnull UInt8 *)value error:(NSError * _Nullable * _Nullable)error;
- (BOOL)readMemoryUInt16:(UInt32)address value:(nonnull UInt16 *)value error:(NSError * _Nullable * _Nullable)error;

- (BOOL)setVectorTable:(uint32_t)address error:(NSError * _Nullable * _Nullable)error;

- (BOOL)massErase:(NSError * _Nullable * _Nullable)error;
- (BOOL)erase:(UInt32)address error:(NSError * _Nullable * _Nullable)error;
- (BOOL)flash:(UInt32)address data:(nonnull NSData *)data error:(NSError * _Nullable * _Nullable)error;

- (BOOL)reset:(NSError * _Nullable * _Nullable)error;

- (BOOL)readRegister:(UInt16)registerID value:(nonnull UInt32 *)value error:(NSError * _Nullable * _Nullable)error;
- (BOOL)writeRegister:(UInt16)registerID value:(UInt32)value error:(NSError * _Nullable * _Nullable)error;

- (BOOL)halt:(NSError * _Nullable * _Nullable)error;
- (BOOL)step:(NSError * _Nullable * _Nullable)error;
- (BOOL)run:(NSError * _Nullable * _Nullable)error;

- (BOOL)isHalted:(nonnull BOOL *)halted error:(NSError * _Nullable * _Nullable)error;
- (BOOL)waitForHalt:(NSTimeInterval)timeout error:(NSError * _Nullable * _Nullable)error;

- (BOOL)breakpointCount:(nonnull UInt32 *)count error:(NSError * _Nullable * _Nullable)error;
- (BOOL)enableBreakpoints:(BOOL)enable error:(NSError * _Nullable * _Nullable)error;
- (BOOL)getBreakpoint:(uint32_t)n address:(nonnull uint32_t *)address enabled:(nonnull BOOL *)enabled error:(NSError * _Nullable * _Nullable)error;
- (BOOL)setBreakpoint:(uint32_t)n address:(uint32_t)address error:(NSError * _Nullable * _Nullable)error;
- (BOOL)disableBreakpoint:(uint32_t)n error:(NSError * _Nullable * _Nullable)error;
- (BOOL)disableAllBreakpoints:(NSError * _Nullable * _Nullable)error;

@end
