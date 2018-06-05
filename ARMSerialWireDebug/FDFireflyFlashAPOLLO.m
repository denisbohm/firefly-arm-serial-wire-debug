//
//  FDFireflyFlashAPOLLO.m
//  ARMSerialWireDebug
//
//  Created by Denis Bohm on 5/29/18.
//  Copyright © 2018 Firefly Design LCC. All rights reserved.
//

#import "FDFireflyFlashAPOLLO.h"

@implementation FDFireflyFlashAPOLLO

- (BOOL)setupProcessor:(NSError **)error
{
    self.pageSize = 8192;
    self.ramAddress = 0x10000000;
    self.ramSize = 0x00040000;
    self.pagesPerWrite = 4;
    return YES;
}

- (BOOL)massErase:(NSError **)error
{
    /*
    #define PROGRAM_KEY (0x12344321)
    int flash_info_plus_main_erase_both(uint32_t value);
    // flash_erase_main_plus_info_both_instances()
    ((int      (*)(uint32_t)) 0x08000091),
     */
    if (![self.serialWireDebug halt:error]) {
        return NO;
    }
    if (![self.serialWireDebug writeRegister:CORTEX_M_REGISTER_R0 value:0x12344321 error:error]) {
        return NO;
    }
    if (![self.serialWireDebug writeRegister:CORTEX_M_REGISTER_PC value:0x08000091 error:error]) {
        return NO;
    }
    uint32_t bkpt = 0b11100001001000000000000001110000; // BKPT #0
    uint32_t breakpoint = self.ramAddress;
    if (![self.serialWireDebug writeMemory:breakpoint value:bkpt error:error]) {
        return NO;
    }
    if (![self.serialWireDebug writeRegister:CORTEX_M_REGISTER_LR value:breakpoint error:error]) {
        return NO;
    }
    uint32_t sp = self.ramAddress + 0x1000;
    if (![self.serialWireDebug writeRegister:CORTEX_M_REGISTER_SP value:sp error:error]) {
        return NO;
    }
    
    /*
    BOOL halted = YES;
    do {
        [self.cortexM logDebugInfo];
        uint32_t pc = 0;
        if (![self.serialWireDebug readRegister:(UInt16)CORTEX_M_REGISTER_PC value:&pc error:error]) {
            return NO;
        }
        halted = pc >= breakpoint;
        if (![self.serialWireDebug step:error]) {
            return NO;
        }
    } while (!halted);
     */
    if (![self.serialWireDebug run:error]) {
        return NO;
    }
    UInt32 r0 = 0;
    if (![self.cortexM waitForHalt:30.0 resultR0:&r0 error:error]) {
        return NO;
    }

    return YES;
}

- (BOOL)isAuthenticationAccessPortActive:(BOOL *)value error:(NSError **)error
{
    *value = NO;
    return YES;
}

- (BOOL)authenticationAccessPortErase:(NSError **)error
{
    return YES;
}

- (BOOL)authenticationAccessPortReset:(NSError **)error
{
    return YES;
}

- (BOOL)disableWatchdogByErasingIfNeeded:(BOOL *)erased error:(NSError **)error
{
    return YES;
}

- (BOOL)feedWatchdog:(NSError **)error
{
    return YES;
}

- (BOOL)setDebugLock:(NSError **)error
{
    return YES;
}

- (BOOL)getDebugLock:(BOOL *)debugLock error:(NSError **)error
{
    *debugLock = NO;
    return YES;
}

@end
