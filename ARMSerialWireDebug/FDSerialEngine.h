//
//  FDSerialEngine.h
//  program
//
//  Created by Denis Bohm on 1/7/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FDUSBDevice;

@interface FDSerialEngine : NSObject

@property (nullable) FDUSBDevice *usbDevice;
@property NSTimeInterval timeout;

- (BOOL)reset:(NSError * _Nullable * _Nullable)error;
- (BOOL)setLatencyTimer:(UInt16)value error:(NSError * _Nullable * _Nullable)error;
- (BOOL)setResetMode:(NSError * _Nullable * _Nullable)error;
- (BOOL)setMPSEEBitMode:(NSError * _Nullable * _Nullable)error;

- (void)setLoopback:(bool)enable;
- (void)setClockDivisor:(UInt16)divisor;
- (void)setLowByte:(UInt8)value direction:(UInt8)direction;
- (void)getLowByte;
- (void)setHighByte:(UInt8)value direction:(UInt8)direction;
- (void)getHighByte;
- (void)sendImmediate;
- (void)shiftOutBitsLSBFirstNegativeEdge:(UInt8)byte bitCount:(NSUInteger)bitCount;
- (void)shiftOutUInt32LSBFirstNegativeEdge:(UInt32)word;
- (void)shiftOutDataLSBFirstNegativeEdge:(nonnull NSData *)data;
- (void)shiftInBitsLSBFirstPositiveEdge:(NSUInteger)bitCount;
- (void)shiftInUInt32LSBFirstPositiveEdge;
- (void)shiftInDataLSBFirstPositiveEdge:(NSUInteger)byteCount;

- (BOOL)write:(NSError * _Nullable * _Nullable)error;
- (nullable NSData *)read:(UInt32)length error:(NSError * _Nullable * _Nullable)error;
- (nullable NSData *)read:(NSError * _Nullable * _Nullable)error;

@end
