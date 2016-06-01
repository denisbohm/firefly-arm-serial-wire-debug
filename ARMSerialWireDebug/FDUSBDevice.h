//
//  FDUSBDevice.h
//  program
//
//  Created by Denis Bohm on 1/7/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import <Foundation/Foundation.h>

#include <IOKit/usb/IOUSBLib.h>

@class FDLogger;
@class FDUSBDevice;

@protocol FDUSBDeviceDelegate <NSObject>

- (void)usbDevice:(nonnull FDUSBDevice *)usbDevice readPipeAsync:(nonnull NSData *)data error:(nullable NSError *)error;
- (void)usbDevice:(nonnull FDUSBDevice *)usbDevice writePipeAsync:(nonnull NSData *)data error:(nullable NSError *)error;

@end

@class FDUSBMonitor;

@interface FDUSBDevice : NSObject

@property (nonnull) FDLogger *logger;
@property (nonnull) FDUSBMonitor *usbMonitor;
@property io_service_t service;
@property IOUSBDeviceInterface * _Nullable * _Nullable deviceInterface;
@property io_object_t notification;

@property (nullable) id<FDUSBDeviceDelegate> delegate;

@property (nullable) NSObject *location;

- (BOOL)open:(NSError * _Nullable * _Nullable)error;
- (void)close;

- (BOOL)request:(UInt8)request value:(UInt16)value error:(NSError * _Nullable * _Nullable)error;

- (BOOL)writePipe:(UInt8)pipe data:(nonnull NSData *)data error:(NSError * _Nullable * _Nullable)error;
- (BOOL)writePipeAsync:(UInt8)pipe data:(nonnull NSData *)data error:(NSError * _Nullable * _Nullable)error;

- (nullable NSData *)readPipe:(UInt8)pipe length:(UInt32)length error:(NSError * _Nullable * _Nullable)error;
- (BOOL)readPipeAsync:(UInt8)pipe length:(UInt32)length error:(NSError * _Nullable * _Nullable)error;

@end
