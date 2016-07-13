//
//  FDInstrument.h
//  ARMSerialWireDebug
//
//  Created by Denis Bohm on 7/12/16.
//  Copyright © 2016 Firefly Design LCC. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "FDSerialWire.h"
#import "FDUSBPort.h"

@interface FDInstrumentSerialWire : NSObject <FDSerialWire>
@end

@interface FDInstrumentColor : NSObject
@property uint16_t c;
@property uint16_t r;
@property uint16_t g;
@property uint16_t b;
@end

@interface FDInstrument : NSObject

@property (nonnull) FDUSBPort *usbPort;

- (nullable FDInstrumentSerialWire *)getSerialWire:(NSInteger)identifier error:(NSError * _Nullable * _Nullable)error;

- (BOOL)setLED:(NSInteger)identifier value:(BOOL)value error:(NSError * _Nullable * _Nullable)error;

- (BOOL)setVoltage:(NSInteger)identifier value:(float)value error:(NSError * _Nullable * _Nullable)error;

- (BOOL)setRelay:(NSInteger)identifier value:(BOOL)value error:(NSError * _Nullable * _Nullable)error;

- (float)getVoltage:(NSInteger)identifier error:(NSError * _Nullable * _Nullable)error;

- (nullable FDInstrumentColor *)getColor:(NSInteger)identifier error:(NSError * _Nullable * _Nullable)error;

@end
