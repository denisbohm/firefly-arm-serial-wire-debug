//
//  FDCortexM.m
//  ARMSerialWireDebug
//
//  Created by Denis Bohm on 1/7/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDCortexM.h"
#import "FDFireflyFlash.h"
#import "FDLogger.h"
#import "FDSerialWireDebug.h"

@implementation FDAddressRange
@end

@interface FDCortexM ()

@end

@implementation FDCortexM

- (id)init
{
    if (self = [super init]) {
        _logger = [[FDLogger alloc] init];
        _programRange = [[FDAddressRange alloc] init];
        _stackRange = [[FDAddressRange alloc] init];
        _heapRange = [[FDAddressRange alloc] init];
    }
    return self;
}

- (void)logDebugInfo
{
    uint32_t dhcsr;
    if (![_serialWireDebug readMemory:0xE000EDF0 value:&dhcsr error:nil]) {
        return;
    }
    uint32_t demcr;
    if (![_serialWireDebug readMemory:0xE000EDFC value:&demcr error:nil]) {
        return;
    }
    uint32_t pc;
    if (![_serialWireDebug readRegister:CORTEX_M_REGISTER_PC value:&pc error:nil]) {
        return;
    }
    uint32_t lr;
    if (![_serialWireDebug readRegister:CORTEX_M_REGISTER_LR value:&lr error:nil]) {
        return;
    }
    NSLog(@"run timeout: dhcsr=0x%08x demcr=0x%08x pc=0x%08x lr=0x%08x", dhcsr, demcr, pc, lr);
}

- (BOOL)start:(UInt32)pc r0:(uint32_t)r0 r1:(uint32_t)r1 r2:(uint32_t)r2 r3:(uint32_t)r3 error:(NSError **)error
{
    // Note: We can only use hardware breakpoints if code is in FLASH.
    // So, instead, we set the link register to a halt function, which then gets called on return. -denis
    /*
     [_serialWireDebug disableAllBreakpoints];
     [_serialWireDebug setBreakpoint:0 address:_breakLocation];
     [_serialWireDebug enableBreakpoints:YES];
     */

    NSMutableArray<FDSerialWireDebugTransfer *> *transfers = [NSMutableArray array];
    uint32_t dhcsr = SWD_DHCSR_DBGKEY | SWD_DHCSR_CTRL_DEBUGEN | SWD_DHCSR_CTRL_HALT;
    [transfers addObject:[FDSerialWireDebugTransfer writeMemory:SWD_MEMORY_DHCSR value:dhcsr]]; // halt
    [transfers addObject:[FDSerialWireDebugTransfer writeRegister:CORTEX_M_REGISTER_R0 value:r0]];
    [transfers addObject:[FDSerialWireDebugTransfer writeRegister:CORTEX_M_REGISTER_R1 value:r1]];
    [transfers addObject:[FDSerialWireDebugTransfer writeRegister:CORTEX_M_REGISTER_R2 value:r2]];
    [transfers addObject:[FDSerialWireDebugTransfer writeRegister:CORTEX_M_REGISTER_R3 value:r3]];
    uint32_t sp = _stackRange.location + _stackRange.length;
    [transfers addObject:[FDSerialWireDebugTransfer writeRegister:CORTEX_M_REGISTER_SP value:sp]];
    [transfers addObject:[FDSerialWireDebugTransfer writeRegister:CORTEX_M_REGISTER_PC value:pc]];
    uint32_t lr = _breakLocation | 0x00000001;
    [transfers addObject:[FDSerialWireDebugTransfer writeRegister:CORTEX_M_REGISTER_LR value:lr]];
    dhcsr = SWD_DHCSR_DBGKEY | SWD_DHCSR_CTRL_DEBUGEN;
    if (_serialWireDebug.maskInterrupts) {
        dhcsr |= SWD_DHCSR_CTRL_MASKINTS;
    }
    [transfers addObject:[FDSerialWireDebugTransfer writeMemory:SWD_MEMORY_DHCSR value:dhcsr]]; // run
    return [_serialWireDebug transfer:transfers error:error];
}

- (BOOL)waitForHalt:(NSTimeInterval)timeout resultR0:(UInt32 *)resultR0 error:(NSError **)error
{
    if ([_serialWireDebug waitForHalt:timeout error:error]) {
        if ([_serialWireDebug readRegister:CORTEX_M_REGISTER_R0 value:resultR0 error:error]) {
            return YES;
        }
    }

    [self logDebugInfo];
    uint32_t current_pc;
    if ([_serialWireDebug readRegister:CORTEX_M_REGISTER_PC value:&current_pc error:nil]) {
        if (current_pc == (_breakLocation | 0x00000001)) {
            NSLog(@"halted, but halt bit not set");
            if ([_serialWireDebug readRegister:CORTEX_M_REGISTER_R0 value:resultR0 error:nil]) {
                return YES;
            }
        }
    }
    return NO;
}

- (BOOL)run:(UInt32)pc r0:(uint32_t)r0 r1:(uint32_t)r1 r2:(uint32_t)r2 r3:(uint32_t)r3 timeout:(NSTimeInterval)timeout resultR0:(UInt32 *)resultR0 error:(NSError **)error
{
    if (![self start:pc r0:r0 r1:r1 r2:r2 r3:r3 error:error]) {
        return NO;
    }
    return [self waitForHalt:timeout resultR0:resultR0 error:error];
}

- (BOOL)run:(UInt32)pc r0:(uint32_t)r0 r1:(uint32_t)r1 r2:(uint32_t)r2 timeout:(NSTimeInterval)timeout resultR0:(UInt32 *)resultR0 error:(NSError **)error
{
    return [self run:pc r0:r0 r1:r1 r2:r2 r3:0 timeout:timeout resultR0:resultR0 error:error];
}

- (BOOL)run:(UInt32)pc r0:(uint32_t)r0 r1:(uint32_t)r1 timeout:(NSTimeInterval)timeout resultR0:(UInt32 *)resultR0 error:(NSError **)error
{
    return [self run:pc r0:r0 r1:r1 r2:0 r3:0 timeout:timeout resultR0:resultR0 error:error];
}

- (BOOL)run:(UInt32)pc r0:(uint32_t)r0 timeout:(NSTimeInterval)timeout resultR0:(UInt32 *)resultR0 error:(NSError **)error
{
    return [self run:pc r0:r0 r1:0 r2:0 r3:0 timeout:timeout resultR0:resultR0 error:error];
}

- (BOOL)run:(UInt32)pc timeout:(NSTimeInterval)timeout resultR0:(UInt32 *)resultR0 error:(NSError **)error
{
    return [self run:pc r0:0 r1:0 r2:0 r3:0 timeout:timeout resultR0:resultR0 error:error];
}

- (BOOL)run:(UInt32)pc r0:(uint32_t)r0 r1:(uint32_t)r1 r2:(uint32_t)r2 r3:(uint32_t)r3 timeout:(NSTimeInterval)timeout error:(NSError **)error
{
    if (![self start:pc r0:r0 r1:r1 r2:r2 r3:r3 error:error]) {
        return NO;
    }
    UInt32 resultR0;
    return [self waitForHalt:timeout resultR0:&resultR0 error:error];
}

- (BOOL)run:(UInt32)pc r0:(uint32_t)r0 r1:(uint32_t)r1 r2:(uint32_t)r2 timeout:(NSTimeInterval)timeout error:(NSError **)error
{
    return [self run:pc r0:r0 r1:r1 r2:r2 r3:0 timeout:timeout error:error];
}

- (BOOL)run:(UInt32)pc r0:(uint32_t)r0 r1:(uint32_t)r1 timeout:(NSTimeInterval)timeout error:(NSError **)error
{
    return [self run:pc r0:r0 r1:r1 r2:0 r3:0 timeout:timeout error:error];
}

- (BOOL)run:(UInt32)pc r0:(uint32_t)r0 timeout:(NSTimeInterval)timeout error:(NSError **)error
{
    return [self run:pc r0:r0 r1:0 r2:0 r3:0 timeout:timeout error:error];
}

- (BOOL)run:(UInt32)pc timeout:(NSTimeInterval)timeout error:(NSError **)error
{
    return [self run:pc r0:0 r1:0 r2:0 r3:0 timeout:timeout error:error];
}

@end
