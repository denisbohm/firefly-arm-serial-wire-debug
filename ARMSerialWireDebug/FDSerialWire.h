//
//  FDSerialWire.h
//  ARMSerialWireDebug
//
//  Created by Denis Bohm on 6/28/16.
//  Copyright © 2016 Firefly Design LCC. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol FDSerialWire <NSObject>

- (void)setIndicator:(BOOL)value;
- (void)setReset:(BOOL)value;
- (BOOL)getDetect:(nonnull BOOL *)detect error:(NSError * _Nullable * _Nullable)error;

- (void)turnToWrite;
- (void)shiftOutBits:(uint8_t)byte bitCount:(NSUInteger)bitCount;
- (void)shiftOutData:(nonnull NSData *)data;

- (void)turnToRead;
- (void)shiftInBits:(NSUInteger)bitCount;
- (void)shiftInData:(NSUInteger)byteCount;

- (BOOL)write:(NSError * _Nullable * _Nullable)error;
- (nullable NSData *)read:(NSUInteger)byteCount error:(NSError * _Nullable * _Nullable)error;
- (nullable NSData *)read:(NSError * _Nullable * _Nullable)error;

@end
