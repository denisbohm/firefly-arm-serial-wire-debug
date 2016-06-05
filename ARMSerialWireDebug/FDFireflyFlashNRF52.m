//
//  FDFireflyFlashNRF52.m
//  ARMSerialWireDebug
//
//  Created by Denis Bohm on 8/19/15.
//  Copyright (c) 2015 Firefly Design. All rights reserved.
//

#import "FDFireflyFlashNRF52.h"

@implementation FDFireflyFlashNRF52

- (BOOL)setupProcessor:(NSError **)error
{
    self.pageSize = 4096;
    self.ramAddress = 0x20000000;
    self.ramSize = 65536;
    return YES;
}

- (BOOL)disableWatchdogByErasingIfNeeded:(BOOL *)erased error:(NSError **)error
{
    *erased = NO;
    return YES; // !!! need to implement -denis
}

- (BOOL)feedWatchdog:(NSError **)error
{
    return YES; // !!! need to implement -denis
}

#define CTRL_AP_RESET 0x000
#define CTRL_AP_ERASEALL 0x004
#define CTRL_AP_ERASEALLSTATUS 0x008
#define CTRL_AP_APPROTECTSTATUS 0x00c
#define CTRL_AP_IDR 0x0fc

#define CTRL_AP_IDR_VALUE 0x02880000

- (BOOL)unlockByErasingAll
{
//    if (![self.serialWireDebug readAccessPort:(UInt8)registerOffset value:(UInt32 *)value error:(NSError **)error
    return YES;
}

#define UICR 0x10001000

#define APPROTECT 0x208

#define UICR_APPROTECT (UICR + APPROTECT)

// Note: when nRF52 is locked it returns the following
// IDCODE 2ba01477
// CPUID = 05fa0004
- (BOOL)setDebugLock:(NSError **)error
{
    return [self nvmc:NRF_NVMC_CONFIG_WEN_Wen address:UICR_APPROTECT value:0xffffff00 error:error];
}

- (BOOL)getDebugLock:(BOOL *)debugLock error:(NSError **)error
{
    uint32_t value;
    if (![self.serialWireDebug readMemory:UICR_APPROTECT value:&value error:error]) {
        return NO;
    }
    *debugLock = (value & 0x000000ff) != 0x000000ff;
    return YES;
}

@end
