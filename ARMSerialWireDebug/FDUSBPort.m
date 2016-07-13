//
//  FDUSBPort.m
//  ARMSerialWireDebug
//
//  Created by Denis Bohm on 7/12/16.
//  Copyright © 2016 Firefly Design LCC. All rights reserved.
//

#import "FDUSBPort.h"

#import "FDError.h"

@interface FDUSBPort () <FDUSBDeviceDelegate>

@property UInt8 readPipe;
@property UInt8 writePipe;

@property NSData *readData;
@property NSCondition *readCondition;

@property NSMutableData *writeData;

@end

@implementation FDUSBPort

- (id)init
{
    if (self = [super init]) {
        _timeout = 0.5;
        _readPipe = 1;
        _writePipe = 2;
        _writeData = [NSMutableData data];
        _readCondition = [[NSCondition alloc] init];
    }
    return self;
}

- (void)usbDevice:(FDUSBDevice *)usbDevice writePipeAsync:(NSData *)data error:(NSError *)error
{
}

- (void)append:(NSData *)data
{
    [_writeData appendData:data];
}

- (BOOL)write:(NSError **)error
{
    if (_writeData.length == 0) {
        return YES;
    }
    //    NSLog(@"write %@", _writeData);
    if (![_usbDevice writePipe:_writePipe data:_writeData error:error]) {
        return NO;
    }
    _writeData = nil;
    _writeData = [NSMutableData data];
    return YES;
}

- (void)usbDevice:(FDUSBDevice *)usbDevice readPipeAsync:(NSData *)data error:(NSError *)error
{
    [_readCondition lock];
    self.readData = data;
    [_readCondition broadcast];
    [_readCondition unlock];
}

- (NSData *)read:(NSError **)error
{
    NSData *data = nil;
    if (_timeout) {
        [_readCondition lock];
        self.readData = nil;
        _usbDevice.delegate = self;
        if (![_usbDevice readPipeAsync:_readPipe length:4096 error:error]) {
            [_readCondition unlock];
            return nil;
        }
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:_timeout];
        if (![_readCondition waitUntilDate:deadline]) {
            [_readCondition unlock];
            FDErrorReturn(error, @{@"reason": @"USB read timeout"});
            return nil;
        }
        data = self.readData;
        self.readData = nil;
        [_readCondition unlock];
    } else {
        data = [_usbDevice readPipe:_readPipe length:4096 error:error];
        if (data == nil) {
            return nil;
        }
    }

    //    NSLog(@"read %@", data);
    return [data subdataWithRange:NSMakeRange(2, data.length - 2)];
}

- (NSData *)read:(NSUInteger)length error:(NSError **)error
{
    if (![self write:error]) {
        return nil;
    }

    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:2.0];
    NSMutableData *data = [NSMutableData dataWithCapacity:2 + length];
    while (data.length < length) {
        NSData *subdata = [self read:error];
        if (subdata == nil) {
            return nil;
        }
        /*
         if (subdata.length == 0) {
         FDErrorReturn(error, @{@"reason": @"insufficient data available"});
         return nil;
         }
         */
        [data appendData:subdata];
        NSDate *now = [NSDate date];
        if ([deadline compare:now] == NSOrderedAscending) {
            FDErrorReturn(error, @{@"reason": @"timeout"});
            return nil;
        }
    }
    return data;
}

@end
