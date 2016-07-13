//
//  FDInstrument.m
//  ARMSerialWireDebug
//
//  Created by Denis Bohm on 7/12/16.
//  Copyright © 2016 Firefly Design LCC. All rights reserved.
//

#import "FDInstrument.h"

#import "FDError.h"

@interface FDInstrumentSerialWire ()

@property FDInstrument *instrument;

@end

@interface FDInstrument () <FDSerialWire>

@property FDInstrumentSerialWire *serialWire;

@end

@implementation FDInstrumentSerialWire

- (BOOL)getDetect:(nonnull BOOL *)detect error:(NSError * _Nullable * _Nullable)error
{
    return NO; // not implemented -denis
}

- (void)setIndicator:(BOOL)value
{
    [_instrument setIndicator:value];
}

- (void)setReset:(BOOL)value
{
    [_instrument setReset:value];
}

- (void)turnToRead
{
    [_instrument turnToRead];
}

- (void)turnToWrite
{
    [_instrument turnToWrite];
}

- (void)shiftOutBits:(uint8_t)byte bitCount:(NSUInteger)bitCount
{
    [_instrument shiftOutBits:byte bitCount:bitCount];
}

- (void)shiftOutData:(nonnull NSData *)data
{
    [_instrument shiftOutData:data];
}

- (void)shiftInBits:(NSUInteger)bitCount
{
    [_instrument shiftInBits:bitCount];
}

- (void)shiftInData:(NSUInteger)byteCount
{
    [_instrument shiftInData:byteCount];
}

- (BOOL)write:(NSError * _Nullable * _Nullable)error
{
    return [_instrument write:error];
}

- (nullable NSData *)read:(NSUInteger)byteCount error:(NSError * _Nullable * _Nullable)error
{
    return [_instrument read:byteCount error:error];
}

- (nullable NSData *)read:(NSError * _Nullable * _Nullable)error
{
    return [_instrument read:error];
}

@end

@implementation FDInstrumentColor
@end

@implementation FDInstrument

- (id)init
{
    if (self = [super init]) {
        _usbPort = [[FDUSBPort alloc] init];
        _serialWire = [[FDInstrumentSerialWire alloc] init];
        _serialWire.instrument = self;
    }
    return self;
}

- (nullable FDInstrumentSerialWire *)getSerialWire:(NSInteger)identifier error:(NSError * _Nullable * _Nullable)error
{
    if (identifier != 0) {
        FDErrorReturn(error, nil);
        return nil;
    }
    return _serialWire;
}

- (BOOL)setLED:(NSInteger)identifier value:(BOOL)value error:(NSError **)error
{
    FDErrorReturn(error, nil);
    return NO;
}

- (BOOL)setVoltage:(NSInteger)identifier value:(float)value error:(NSError **)error
{
    FDErrorReturn(error, nil);
    return NO;
}

- (BOOL)setRelay:(NSInteger)identifier value:(BOOL)value error:(NSError **)error
{
    FDErrorReturn(error, nil);
    return NO;
}

- (float)getVoltage:(NSInteger)identifier error:(NSError **)error
{
    FDErrorReturn(error, nil);
    return 0.0f;
}

- (FDInstrumentColor *)getColor:(NSInteger)identifier error:(NSError **)error
{
    FDErrorReturn(error, nil);
    return nil;
}

- (BOOL)getDetect:(nonnull BOOL *)detect error:(NSError **)error
{
    FDErrorReturn(error, nil);
    return NO; // not implemented -denis
}

- (void)setIndicator:(BOOL)value
{
    UInt8 bytes[] = {0x80, value ? 0b001 : 0b000, 0b01};
    [_usbPort append:[NSData dataWithBytes:bytes length:sizeof(bytes)]];
}

- (void)setReset:(BOOL)value
{
    UInt8 bytes[] = {0x80, value ? 0b010 : 0b000, 0b010};
    [_usbPort append:[NSData dataWithBytes:bytes length:sizeof(bytes)]];
}

- (void)turnToRead
{
    UInt8 bytes[] = {0x80, 0b100, 0b100};
    [_usbPort append:[NSData dataWithBytes:bytes length:sizeof(bytes)]];
}

- (void)turnToWrite
{
    UInt8 bytes[] = {0x80, 0b000, 0b100};
    [_usbPort append:[NSData dataWithBytes:bytes length:sizeof(bytes)]];
}

- (void)shiftOutBits:(uint8_t)byte bitCount:(NSUInteger)bitCount
{
    UInt8 bytes[] = {0x1b, bitCount - 1, byte};
    [_usbPort append:[NSData dataWithBytes:bytes length:sizeof(bytes)]];
}

- (void)shiftOutData:(nonnull NSData *)data
{
    NSUInteger count = data.length - 1;
    UInt8 bytes[] = {0x19, count, count >> 8};
    NSMutableData *mutableData = [NSMutableData dataWithBytes:bytes length:sizeof(bytes)];
    [mutableData appendData:data];
    [_usbPort append:data];
}

- (void)shiftInBits:(NSUInteger)bitCount
{
    UInt8 bytes[] = {0x2a, bitCount - 1};
    [_usbPort append:[NSData dataWithBytes:bytes length:sizeof(bytes)]];
}

- (void)shiftInData:(NSUInteger)byteCount
{
    NSUInteger count = byteCount - 1;
    UInt8 bytes[] = {0x28, count, count >> 8};
    [_usbPort append:[NSData dataWithBytes:bytes length:sizeof(bytes)]];
}

- (BOOL)write:(NSError * _Nullable * _Nullable)error
{
    return [_usbPort write:error];
}

- (nullable NSData *)read:(NSUInteger)byteCount error:(NSError * _Nullable * _Nullable)error
{
    return [_usbPort read:byteCount error:error];
}

- (nullable NSData *)read:(NSError * _Nullable * _Nullable)error
{
    return [_usbPort read:error];
}

@end
