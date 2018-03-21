//
//  FDUSBDevice.m
//  ARMSerialWireDebug
//
//  Created by Denis Bohm on 1/7/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDError.h"
#import "FDLogger.h"
#import "FDUSBDevice.h"

#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>

@interface FDUSBDevice ()

@property IOUSBInterfaceInterface **interface;
@property NSData *writeData;
@property NSMutableData *readData;
@property UInt32 locationID;
@property NSString *typeAndLocation;

@end

@implementation FDUSBDevice

- (id)init
{
    if (self = [super init]) {
        _logger = [[FDLogger alloc] init];
    }
    return self;
}

- (NSString *)description
{
    return _typeAndLocation ? _typeAndLocation : [super description];
}

- (BOOL)open:(NSError **)error
{
    if (_deviceInterface == nil) {
        return FDErrorReturn(error, nil);
    }

    kern_return_t kernReturn = (*_deviceInterface)->USBDeviceOpen(_deviceInterface);
    if (kernReturn != kIOReturnSuccess) {
        FDLog(@"failure opening USB device: %08x", kernReturn);
//        (void) (*_deviceInterface)->Release(_deviceInterface);
//        self.deviceInterface = NULL;
        return FDErrorReturn(error, nil);
    }
    
    //Placing the constant kIOUSBFindInterfaceDontCare into the following
    //fields of the IOUSBFindInterfaceRequest structure will allow you
    //to find all the interfaces
    IOUSBFindInterfaceRequest request;
    request.bInterfaceClass = kIOUSBFindInterfaceDontCare;
    request.bInterfaceSubClass = kIOUSBFindInterfaceDontCare;
    request.bInterfaceProtocol = kIOUSBFindInterfaceDontCare;
    request.bAlternateSetting = kIOUSBFindInterfaceDontCare;
    
    //Get an iterator for the interfaces on the device
    io_iterator_t iterator;
    kernReturn = (*_deviceInterface)->CreateInterfaceIterator(_deviceInterface, &request, &iterator);
    if (kernReturn != kIOReturnSuccess) {
        FDLog(@"failure CreateInterfaceIterator: %08x", kernReturn);
    }
    io_service_t usbInterface;
    while ((usbInterface = IOIteratorNext(iterator))) {
        //Create an intermediate plug-in
        IOCFPlugInInterface **plugInInterface = NULL;
        SInt32 score;
        kernReturn = IOCreatePlugInInterfaceForService(usbInterface,
                                               kIOUSBInterfaceUserClientTypeID,
                                               kIOCFPlugInInterfaceID,
                                               &plugInInterface,
                                                       &score);
        if (kernReturn != kIOReturnSuccess) {
            FDLog(@"failure IOCreatePlugInInterfaceForService: %08x", kernReturn);
        }
        //Release the usbInterface object after getting the plug-in
        kernReturn = IOObjectRelease(usbInterface);
        if ((kernReturn != kIOReturnSuccess) || !plugInInterface) {
            FDLog(@"failure IOObjectRelease: %08x", kernReturn);
            break;
        }
        
        //Now create the device interface for the interface
        IOUSBInterfaceInterface **interface = NULL;
        HRESULT result = (*plugInInterface)->QueryInterface(plugInInterface,
                                                    CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID),
                                                    (LPVOID *) &interface);
        //No longer need the intermediate plug-in
        (*plugInInterface)->Release(plugInInterface);
        if (result || !interface) {
            FDLog(@"failure QueryInterface: %08x", kernReturn);
            break;
        }
                   
        //Get interface class and subclass
        UInt8 interfaceClass;
        kernReturn = (*interface)->GetInterfaceClass(interface, &interfaceClass);
        UInt8 interfaceSubClass;
        kernReturn = (*interface)->GetInterfaceSubClass(interface, &interfaceSubClass);

        // NSLog(@"Interface class %d, subclass %d", interfaceClass, interfaceSubClass);

        //Now open the interface. This will cause the pipes associated with
        //the endpoints in the interface descriptor to be instantiated
        kernReturn = (*interface)->USBInterfaceOpen(interface);
        if (kernReturn != kIOReturnSuccess) {
            FDLog(@"failure USBInterfaceOpen: %08x", kernReturn);
           (void) (*interface)->Release(interface);
           break;
        }
        
        kernReturn = (*interface)->GetLocationID(interface, &_locationID);
        if (kernReturn != KERN_SUCCESS) {
            NSLog(@"GetLocationID failed (%08x)", kernReturn);
        }
        _location = [NSNumber numberWithLong:_locationID];
        _typeAndLocation = [NSString stringWithFormat:@"Olimex ARM-USB-TINY-H %u", _locationID];

        // use the first interface -denis
        _interface = interface;
        
        // setup asynchronous operation
        CFRunLoopSourceRef runLoopSource;
        kernReturn = (*interface)->CreateInterfaceAsyncEventSource(interface, &runLoopSource);
        if (kernReturn != kIOReturnSuccess) {
            FDLog(@"failure CreateInterfaceAsyncEventSource: %08x", kernReturn);
            (void) (*interface)->USBInterfaceClose(interface);
            (void) (*interface)->Release(interface);
            break;
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, kCFRunLoopCommonModes); // kCFRunLoopDefaultMode);
        
        break;
    }

    return YES;
}

/*
- (void)close
{
    if (_deviceInterface == NULL) {
        return;
    }
    
    (void) (*_interface)->USBInterfaceClose(_interface);
    (void) (*_interface)->Release(_interface);
    
    kern_return_t kernReturn = (*_deviceInterface)->USBDeviceClose(_deviceInterface);
    if (kernReturn != kIOReturnSuccess) {
        FDLog(@"failure closing USB device: %08x", kernReturn);
    }
    kernReturn = (*_deviceInterface)->Release(_deviceInterface);
    if (kernReturn != kIOReturnSuccess) {
        FDLog(@"failure releasing USB device interface: %08x", kernReturn);
    }
    self.deviceInterface = NULL;
}
*/

- (void)close
{
    if (_interface == NULL) {
        return;
    }
    
    (void) (*_interface)->USBInterfaceClose(_interface);
    (void) (*_interface)->Release(_interface);
    self.interface = NULL;
}

- (void)releaseDevice
{
    [self close];

    kern_return_t kernReturn = (*_deviceInterface)->USBDeviceClose(_deviceInterface);
    if (kernReturn != kIOReturnSuccess) {
        FDLog(@"failure closing USB device: %08x", kernReturn);
    }
    kernReturn = (*_deviceInterface)->Release(_deviceInterface);
    if (kernReturn != kIOReturnSuccess) {
        FDLog(@"failure releasing USB device interface: %08x", kernReturn);
    }
    self.deviceInterface = NULL;
}

- (BOOL)checkPreconditions:(NSError **)error
{
    if (_interface == nil) {
        return FDErrorReturn(error, nil);
    }
    if (![FDError checkThreadIsCancelled:error]) {
        return NO;
    }
    return YES;
}

- (BOOL)request:(UInt8)request value:(UInt16)value error:(NSError **)error
{
    if (![self checkPreconditions:error]) {
        return NO;
    }
    IOUSBDevRequest devRequest;
    bzero(&devRequest, sizeof(devRequest));
    devRequest.bmRequestType = USBmakebmRequestType(kUSBOut, kUSBVendor, kUSBDevice);
    devRequest.bRequest = request;
    devRequest.wValue = value;
    devRequest.wIndex = 1;
    kern_return_t kernReturn = (*_deviceInterface)->DeviceRequest(_deviceInterface, &devRequest);
    if (kernReturn != kIOReturnSuccess) {
        FDLog(@"failure DeviceRequest: %08x", kernReturn);
    }
    return YES;
}

- (BOOL)writePipe:(UInt8)pipe data:(NSData *)data error:(NSError **)error
{
    if (![self checkPreconditions:error]) {
        return NO;
    }
    kern_return_t kernReturn = (*_interface)->WritePipe(_interface, pipe, (void *)data.bytes, (UInt32)data.length);
    if (kernReturn != kIOReturnSuccess) {
        return FDErrorReturn(error, @{@"kern_return": @(kernReturn)});
    }
    return YES;
}

- (void)WritePipeAsyncCallback:(IOReturn)result arg0:(void *)arg0
{
    NSError *error = nil;
    if ([self checkPreconditions:&error]) {
        if (result != kIOReturnSuccess) {
            FDErrorReturn(&error, @{@"IOReturn": @(result)});
        }
    }
    NSData *data = _writeData;
    _writeData = nil;
    [_delegate usbDevice:self writePipeAsync:data error:error];
}

static
void WritePipeAsyncCallback(void *refCon, IOReturn result, void *arg0)
{
    FDUSBDevice *usbDevice = (__bridge FDUSBDevice *)refCon;
    [usbDevice WritePipeAsyncCallback:result arg0:arg0];
}

- (BOOL)writePipeAsync:(UInt8)pipe data:(NSData *)data error:(NSError **)error
{
    if (![self checkPreconditions:error]) {
        return NO;
    }
    _writeData = [NSData dataWithData:data];
    kern_return_t kernReturn = (*_interface)->WritePipeAsync(_interface, pipe, (void *)_writeData.bytes, (UInt32)_writeData.length, WritePipeAsyncCallback, (__bridge void *)self);
    if (kernReturn != kIOReturnSuccess) {
        _writeData = nil;
        return FDErrorReturn(error, @{@"kern_return": @(kernReturn)});
    }
    return YES;
}

- (NSData *)readPipe:(UInt8)pipe length:(UInt32)length error:(NSError **)error
{
    if (![self checkPreconditions:error]) {
        return nil;
    }
    NSMutableData *data = [NSMutableData dataWithLength:length];
    UInt32 readLength = length;
    kern_return_t kernReturn = (*_interface)->ReadPipe(_interface, pipe, (void *)data.bytes, &readLength);
    if (kernReturn != kIOReturnSuccess) {
        FDErrorReturn(error, @{@"kern_return": @(kernReturn)});
        return nil;
    }
    [data setLength:readLength];
    return data;
}

- (void)ReadPipeAsyncCallback:(IOReturn)result arg0:(void *)arg0
{
    NSError *error = nil;
    if ([self checkPreconditions:&error]) {
        if (result != kIOReturnSuccess) {
            FDErrorReturn(&error, @{@"IOReturn": @(result)});
        }
    }
    UInt32 length = (UInt32) arg0;
    [_readData setLength:length];
    NSData *data = _readData;
    _readData = nil;
    [_delegate usbDevice:self readPipeAsync:data error:error];
}

static
void ReadPipeAsyncCallback(void *refCon, IOReturn result, void *arg0)
{
    FDUSBDevice *usbDevice = (__bridge FDUSBDevice *)refCon;
    [usbDevice ReadPipeAsyncCallback:result arg0:arg0];
}

- (BOOL)readPipeAsync:(UInt8)pipe length:(UInt32)length error:(NSError **)error
{
    if (![self checkPreconditions:error]) {
        return NO;
    }
    if (_readData != nil) {
        return FDErrorReturn(error, @{@"reason": @"previous read is still pending"});
    }
    _readData = [NSMutableData dataWithLength:length];
    IOReturn result = (*_interface)->ReadPipeAsync(_interface, pipe, (void *)_readData.bytes, length, ReadPipeAsyncCallback, (__bridge void *)self);
    if (result != kIOReturnSuccess) {
        _readData = nil;
        return FDErrorReturn(error, @{@"IOReturn": @(result)});
    }
    return YES;
}

@end
