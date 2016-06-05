//
//  FDFireflyFlashNRF52.m
//  ARMSerialWireDebug
//
//  Created by Denis Bohm on 8/19/15.
//  Copyright (c) 2015 Firefly Design. All rights reserved.
//

#import "FDError.h"
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

#define NRF52_AP_REG_RESET 0x00
#define NRF52_AP_REG_ERASEALL 0x04
#define NRF52_AP_REG_ERASEALLSTATUS 0x08
#define NRF52_AP_REG_APPROTECTSTATUS 0x0c
#define NRF52_AP_REG_IDR 0xfc

#define NRF52_CTRL_AP_ID 0x02880000

#define SWD_NRF52_CTRL_AP_ERASE_TIMEOUT 10.0

- (BOOL)isAuthenticationAccessPortActive:(BOOL *)active error:(NSError **)error
{
    UInt32 apid;
    if (![self.serialWireDebug readAccessPort:SWD_DP_SELECT_APSEL_NRF52_CTRL_AP registerOffset:NRF52_AP_REG_IDR value:&apid error:error]) {
        return NO;
    }
    if (SWD_IDR_CODE(apid) != SWD_IDR_CODE(NRF52_CTRL_AP_ID)) {
        FDLog(@"unexpected nRF52 CTRL AP ID");
    }

    UInt32 value;
    if (![self.serialWireDebug readAccessPort:SWD_DP_SELECT_APSEL_NRF52_CTRL_AP registerOffset:NRF52_AP_REG_APPROTECTSTATUS value:&value error:error]) {
        return NO;
    }
    *active = (value & 0x00000001) == 0;
    return YES;
}

- (BOOL)authenticationAccessPortErase:(NSError **)error
{
    if (![self.serialWireDebug writeAccessPort:SWD_DP_SELECT_APSEL_NRF52_CTRL_AP registerOffset:NRF52_AP_REG_ERASEALL value:0x00000001 error:error]) { // erase all
        return NO;
    }
    UInt32 value;
    NSDate *start = [NSDate date];
    do {
        [NSThread sleepForTimeInterval:0.025];
        if (![self.serialWireDebug readAccessPort:SWD_DP_SELECT_APSEL_NRF52_CTRL_AP registerOffset:NRF52_AP_REG_ERASEALLSTATUS value:&value error:error]) {
            return NO;
        }
        if ([[NSDate date] timeIntervalSinceDate:start] > SWD_NRF52_CTRL_AP_ERASE_TIMEOUT) {
            return FDErrorReturn(error, @{@"reason": @"timeout"});
        }
    } while (value != 0);
    if (![self.serialWireDebug writeAccessPort:SWD_DP_SELECT_APSEL_NRF52_CTRL_AP registerOffset:NRF52_AP_REG_ERASEALL value:0x00000000 error:error]) { // erase all off
        return NO;
    }

    return YES;
}

- (BOOL)authenticationAccessPortReset:(NSError **)error
{
    if (![self.serialWireDebug writeAccessPort:SWD_DP_SELECT_APSEL_NRF52_CTRL_AP registerOffset:NRF52_AP_REG_RESET value:0x00000001 error:error]) { // reset
        return NO;
    }
    if (![self.serialWireDebug writeAccessPort:SWD_DP_SELECT_APSEL_NRF52_CTRL_AP registerOffset:NRF52_AP_REG_RESET value:0x00000000 error:error]) { // reset off
        return NO;
    }
    return YES;
}

@end
