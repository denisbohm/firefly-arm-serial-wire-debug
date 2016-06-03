//
//  FDUSBMonitor.h
//  ARMSerialWireDebug
//
//  Created by Denis Bohm on 1/7/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FDUSBDevice;
@class FDLogger;
@class FDUSBMonitor;

@protocol FDUSBMonitorDelegate <NSObject>

- (void)usbMonitor:(nonnull FDUSBMonitor *)usbMonitor usbDeviceAdded:(nonnull FDUSBDevice *)usbDevice;
- (void)usbMonitor:(nonnull FDUSBMonitor *)usbMonitor usbDeviceRemoved:(nonnull FDUSBDevice *)usbDevice;

@end

@protocol FDUSBMonitorMatcher <NSObject>

- (BOOL)matches:(IOUSBDeviceInterface * _Nonnull * _Nonnull)deviceInterface;

@end

@interface FDUSBMonitorMatcherVidPid : NSObject<FDUSBMonitorMatcher>

+ (nonnull FDUSBMonitorMatcherVidPid *)matcher:(nonnull NSString *)name vid:(uint16_t)vid pid:(uint16_t)pid;

@property (nonnull) NSString *name;
@property uint16_t vid;
@property uint16_t pid;

@end

@interface FDUSBMonitor : NSObject

@property (nonnull) NSArray<FDUSBMonitorMatcher> *matchers;
@property UInt16 vendor;
@property UInt16 product;

@property (nullable) id<FDUSBMonitorDelegate> delegate;
@property (nonnull) FDLogger *logger;

@property (readonly, nonnull) NSArray<FDUSBDevice *> *devices;

- (void)start;
- (void)stop;

- (nullable FDUSBDevice *)deviceWithLocation:(nonnull NSObject *)location;

@end
