//
//  FDUSBPort.h
//  ARMSerialWireDebug
//
//  Created by Denis Bohm on 7/12/16.
//  Copyright © 2016 Firefly Design LCC. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "FDUSBDevice.h"

@interface FDUSBPort : NSObject

@property (nullable) FDUSBDevice *usbDevice;
@property NSTimeInterval timeout;

- (void)append:(nonnull NSData *)data;
- (BOOL)write:(NSError * _Nullable * _Nullable)error;
- (nullable NSData *)read:(NSUInteger)length error:(NSError * _Nullable * _Nullable)error;
- (nullable NSData *)read:(NSError * _Nullable * _Nullable)error;

@end
