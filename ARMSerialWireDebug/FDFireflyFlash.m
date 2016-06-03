//
//  FDFireflyFlash.m
//  ARMSerialWireDebug
//
//  Created by Denis Bohm on 7/22/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDError.h"
#import "FDExecutable.h"
#import "FDFireflyFlash.h"

#import <ARMSerialWireDebug/FDCortexM.h>
#import <ARMSerialWireDebug/FDSerialWireDebug.h>

#define FIREFLY_FLASH_STACK_LENGTH 128

@interface FDFireflyFlash ()

@property FDExecutable *fireflyFlashExecutable;
@property uint32_t fireflyFlashProgramEnd;

@end

@implementation FDFireflyFlash

+ (FDFireflyFlash *)fireflyFlash:(NSString *)processor error:(NSError **)error
{
    NSString *className = [NSString stringWithFormat:@"FDFireflyFlash%@", processor];
    Class class = NSClassFromString(className);
    FDFireflyFlash *fireflyFlash = [[class alloc] init];
    if (fireflyFlash == nil) {
        NSString *reason = [NSString stringWithFormat:@"FDFireflyFlash: processor unknown: '%@'", processor];
        FDErrorReturn(error, @{@"reason": reason});
        return nil;
    }
    fireflyFlash.processor = processor;
    return fireflyFlash;
}

- (id)init
{
    if (self = [super init]) {
        _logger = [[FDLogger alloc] init];
    }
    return self;
}

- (BOOL)setupProcessor:(NSError **)error
{
    return FDErrorReturn(error, @{@"reason": @"unimplemented"});
}

- (BOOL)massErase:(NSError **)error
{
    return FDErrorReturn(error, @{@"reason": @"unimplemented"});
}

- (BOOL)disableWatchdogByErasingIfNeeded:(BOOL *)erased error:(NSError **)error
{
    return FDErrorReturn(error, @{@"reason": @"unimplemented"});
}

- (BOOL)feedWatchdog:(NSError **)error
{
    return FDErrorReturn(error, @{@"reason": @"unimplemented"});
}

- (BOOL)setDebugLock:(NSError **)error
{
    return FDErrorReturn(error, @{@"reason": @"unimplemented"});
}

- (BOOL)getDebugLock:(BOOL *)debugLock error:(NSError **)error
{
    return FDErrorReturn(error, @{@"reason": @"unimplemented"});
}

// See the firefly-ice-firmware project in github for source code to generate the FireflyFlash elf files. -denis
- (BOOL)loadFireflyFlashFirmwareIntoRAM:(NSError **)error
{
    NSString *flashResource = [NSString stringWithFormat:@"FireflyFlash%@", _processor];
    NSString *path = [NSString stringWithFormat:@"%@/THUMB RAM Debug/%@.elf", _directory, flashResource];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        path = [[NSBundle mainBundle] pathForResource:flashResource ofType:@"elf"];
        if (path == nil) {
            path = [[NSBundle bundleForClass:[self class]] pathForResource:flashResource ofType:@"elf"];
        }
    }
    FDExecutable *fireflyFlashExecutable = [[FDExecutable alloc] init];
    if (![fireflyFlashExecutable load:path error:error]) {
        return NO;
    }
    fireflyFlashExecutable.sections = [fireflyFlashExecutable combineAllSectionsType:FDExecutableSectionTypeProgram address:_ramAddress length:_ramSize pageSize:4];

    if (![self.serialWireDebug reset:error]) {
        return NO;
    }

    for (FDExecutableSection *section in fireflyFlashExecutable.sections) {
        switch (section.type) {
            case FDExecutableSectionTypeData:
            case FDExecutableSectionTypeProgram: {
                if (![_serialWireDebug writeMemory:section.address data:section.data error:error]) {
                    return NO;
                }
                uint32_t end = section.address + (uint32_t)section.data.length;
                if (end > _fireflyFlashProgramEnd) {
                    _fireflyFlashProgramEnd = end;
                }
            } break;
        }
    }

    _fireflyFlashExecutable = fireflyFlashExecutable;
    return YES;
}

- (BOOL)setupCortexM:(NSError **)error
{
    _cortexM = [[FDCortexM alloc] init];
    _cortexM.serialWireDebug = _serialWireDebug;
    _cortexM.logger.consumer = _logger.consumer;
    
    uint32_t programLength = _fireflyFlashProgramEnd - _ramAddress;
    
    _cortexM.programRange.location = _ramAddress;
    _cortexM.programRange.length = programLength;
    _cortexM.stackRange.location = _ramAddress + programLength;
    _cortexM.stackRange.length = FIREFLY_FLASH_STACK_LENGTH;
    _cortexM.heapRange.location = _ramAddress + programLength + FIREFLY_FLASH_STACK_LENGTH;
    _cortexM.heapRange.length = _ramSize - programLength - FIREFLY_FLASH_STACK_LENGTH;
    _pagesPerWrite = _cortexM.heapRange.length / _pageSize;
    
    FDExecutableFunction *haltFunction = _fireflyFlashExecutable.functions[@"halt"];
    _cortexM.breakLocation = haltFunction.address;
    return YES;
}

- (BOOL)reset:(NSError **)error
{
    if (![self massErase:error]) {
        return NO;
    }
    if (![_serialWireDebug reset:error]) {
        return NO;
    }
    if (![_serialWireDebug run:error]) {
        return NO;
    }
    [NSThread sleepForTimeInterval:0.001];
    if (![_serialWireDebug halt:error]) {
        return NO;
    }
    return YES;
}

- (BOOL)initialize:(FDSerialWireDebug *)serialWireDebug error:(NSError **)error
{
    _serialWireDebug = serialWireDebug;
    _logger = _serialWireDebug.logger;
    if (![self setupProcessor:error]) {
        return NO;
    }
    if (![self loadFireflyFlashFirmwareIntoRAM:error]) {
        return NO;
    }
    if (![self setupCortexM:error]) {
        return NO;
    }
    return YES;
}

- (BOOL)checkCancel:(NSError **)error
{
    if ([NSThread currentThread].isCancelled) {
        return FDErrorReturn(error, @{@"reason": @"Cancelled"});
    }
    return YES;
}

- (BOOL)writePages:(uint32_t)address data:(NSData *)data error:(NSError **)error
{
    return [self writePages:address data:data erase:NO error:error];
}

- (BOOL)writePages:(uint32_t)address data:(NSData *)data erase:(BOOL)erase error:(NSError **)error
{
    FDExecutableFunction *writePagesFunction = _fireflyFlashExecutable.functions[@"write_pages"];
    uint32_t offset = 0;
    while (offset < data.length) {
        if (![self checkCancel:error]) {
            return NO;
        }
        uint32_t length = (uint32_t) (data.length - offset);
        uint32_t pages = length / _pageSize;
        if (pages > _pagesPerWrite) {
            pages = _pagesPerWrite;
            length = pages * _pageSize;
        }
        NSData *subdata = [data subdataWithRange:NSMakeRange(offset, length)];
        if (![_serialWireDebug writeMemory:_cortexM.heapRange.location data:subdata error:error]) {
            return NO;
        }
        if (![self feedWatchdog:error]) {
            return NO;
        }
        UInt32 result;
        if (![_cortexM run:writePagesFunction.address r0:address r1:_cortexM.heapRange.location r2:pages r3:erase ? 1 : 0 timeout:5 resultR0:&result error:error]) {
            return NO;
        }
        offset += length;
        address += length;
    }
    return YES;
}

- (BOOL)program:(FDExecutable *)executable error:(NSError **)error
{
    if (![_serialWireDebug halt:error]) {
        return NO;
    }

    NSArray *sections = [executable combineSectionsType:FDExecutableSectionTypeProgram address:0 length:_ramAddress pageSize:_pageSize];
    for (FDExecutableSection *section in sections) {
        switch (section.type) {
            case FDExecutableSectionTypeData:
                break;
            case FDExecutableSectionTypeProgram: {
                if (section.address >= _ramAddress) {
                    FDLog(@"ignoring RAM data for address 0x%08x length %lu", section.address, (unsigned long)section.data.length);
                    continue;
                }
//                FDLog(@"writing flash at 0x%08x length %lu", section.address, (unsigned long)section.data.length);
                if (![self writePages:section.address data:section.data error:error]) {
                    return NO;
                }
// slower method using SWD only (no flash function required in RAM -denis
//                [_serialWireDebug program:section.address data:section.data];
                NSData *verify = [_serialWireDebug readMemory:section.address length:(uint32_t)section.data.length error:error];
                if (verify == nil) {
                    return NO;
                }
                if (![section.data isEqualToData:verify]) {
                    FDLog(@"write verification failed!");
                    NSString *reason = @"flash verification failure";
                    return FDErrorReturn(error, @{@"reason": reason});
                }
            } break;
        }
    }
    return YES;
}

@end
