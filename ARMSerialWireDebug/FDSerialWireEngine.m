//
//  FDSerialWireEngine.m
//  ARMSerialWireDebug
//
//  Created by Denis Bohm on 6/28/16.
//  Copyright © 2016 Firefly Design LCC. All rights reserved.
//

#import "FDSerialWireEngine.h"

@interface FDSerialWireEngine ()

@property UInt16 gpioInputs;
@property UInt16 gpioOutputs;
@property UInt16 gpioDirections;

@property NSUInteger gpioWriteBit;
@property NSUInteger gpioResetBit;
@property NSUInteger gpioIndicatorBit;
@property NSUInteger gpioDetectBit;

@end

@implementation FDSerialWireEngine

- (id)init
{
    if (self = [super init]) {
        _logger = [[FDLogger alloc] init];
        
        _clockDivisor = 5;

        _gpioDirections = 0b0000111100011011;
        _gpioOutputs = 0b0000001000000000;
        _gpioWriteBit = 3;
        _gpioResetBit = 9;
        _gpioIndicatorBit = 11;
        _gpioDetectBit = 5;
        
    }
    return self;
}

- (BOOL)initialize:(NSError * _Nullable * _Nullable)error {
    if (![_serialEngine read:error]) {
        FDLog(@"unexpected error: %@", error);
    }

    [_serialEngine setLoopback:false];
    [_serialEngine setClockDivisor:_clockDivisor];
    if (![_serialEngine write:error]) {
        return NO;
    }

    if (![_serialEngine setLatencyTimer:2 error:error]) {
        return NO;
    }
    if (![_serialEngine setMPSEEBitMode:error]) {
        return NO;
    }
    if (![_serialEngine reset:error]) {
        return NO;
    }

    [_serialEngine setLowByte:_gpioOutputs direction:_gpioDirections];
    [_serialEngine setHighByte:_gpioOutputs >> 8 direction:_gpioDirections >> 8];
    [_serialEngine sendImmediate];
    if (![_serialEngine write:error]) {
        return NO;
    }

    if (![self getGpios:error]) {
        return NO;
    }

    // reading detect seems flakey, the following seems to make it stable -denis
    [self setGpioBit:_gpioWriteBit value:true];
    if (![self getGpios:error]) {
        return NO;
    }

    return YES;
}

- (BOOL)getGpios:(NSError **)error
{
    [_serialEngine getLowByte];
    [_serialEngine getHighByte];
    [_serialEngine sendImmediate];
    if (![_serialEngine write:error]) {
        return NO;
    }
    NSData *data = [_serialEngine read:2 error:error];
    if (data == nil) {
        return NO;
    }
    UInt8 *bytes = (UInt8 *)data.bytes;
    _gpioInputs = (bytes[1] << 8) | bytes[0];
    return YES;
}

- (BOOL)getDetect:(BOOL *)detect error:(NSError **)error
{
    if (![self getGpios:error]) {
        return NO;
    }
    *detect = _gpioInputs & (1 << _gpioDetectBit) ? NO : YES;
    return YES;
}

- (void)setGpioBit:(NSUInteger)bit value:(BOOL)value
{
    UInt16 mask = 1 << bit;
    UInt16 outputs = _gpioOutputs;
    if (value) {
        outputs |= mask;
    } else {
        outputs &= ~mask;
    }
    if (outputs == _gpioOutputs) {
        return;
    }
    _gpioOutputs = outputs;
    if (mask & 0x00ff) {
        [_serialEngine setLowByte:_gpioOutputs direction:_gpioDirections];
    } else {
        [_serialEngine setHighByte:_gpioOutputs >> 8 direction:_gpioDirections >> 8];
    }
}

- (void)setIndicator:(BOOL)value
{
    [self setGpioBit:_gpioIndicatorBit value:value];
}

- (void)setReset:(BOOL)value
{
    [self setGpioBit:_gpioResetBit value:value];
}

- (void)turnToWrite
{
    [self setGpioBit:_gpioWriteBit value:true];
}

- (void)shiftOutBits:(uint8_t)byte bitCount:(NSUInteger)bitCount
{
    [_serialEngine shiftOutBitsLSBFirstNegativeEdge:byte bitCount:bitCount];
}

- (void)shiftOutData:(nonnull NSData *)data
{
    [_serialEngine shiftOutDataLSBFirstNegativeEdge:data];
}

- (void)turnToRead
{
    [self setGpioBit:_gpioWriteBit value:false];
}

- (void)shiftInBits:(NSUInteger)bitCount
{
    [_serialEngine shiftInBitsLSBFirstPositiveEdge:bitCount];
}

- (void)shiftInData:(NSUInteger)byteCount
{
    [_serialEngine shiftInDataLSBFirstPositiveEdge:byteCount];
}

- (BOOL)write:(NSError * _Nullable * _Nullable)error
{
    return [_serialEngine write:error];
}

- (NSData *)read:(NSUInteger)byteCount error:(NSError * _Nullable * _Nullable)error
{
    [_serialEngine sendImmediate];
    return [_serialEngine read:(UInt32)byteCount error:error];
}

- (NSData *)read:(NSError * _Nullable * _Nullable)error
{
    return [_serialEngine read:error];
}

@end
