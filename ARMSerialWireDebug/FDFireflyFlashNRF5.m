//
//  FDFireflyFlashNRF5X.m
//  FireflyProduction
//
//  Created by Denis Bohm on 8/19/15.
//  Copyright (c) 2015 Firefly Design. All rights reserved.
//

#import "FDFireflyFlashNRF5.h"

@implementation FDFireflyFlashNRF5

#define NRF_NVMC 0x4001E000U
#define NRF_NVMC_READY     (NRF_NVMC + 0x400U)
#define NRF_NVMC_CONFIG    (NRF_NVMC + 0x504U)
#define NRF_NVMC_ERASEALL  (NRF_NVMC + 0x50CU)
#define NRF_NVMC_ERASEUICR (NRF_NVMC + 0x514U)

#define NRF_NVMC_READY_READY 0x00000001
#define NRF_NVMC_READY_READY_Busy  0x00000000
#define NRF_NVMC_READY_READY_Ready 0x00000001

#define NRF_NVMC_CONFIG_WEN 0x00000003
#define NRF_NVMC_CONFIG_WEN_Ren 0x00000000
#define NRF_NVMC_CONFIG_WEN_Wen 0x00000001
#define NRF_NVMC_CONFIG_WEN_Een 0x00000002

#define NRF_NVMC_ERASEALL_ERASEALL_Erase 0x00000001

#define NRF_NVMC_ERASEALL_ERASEUICR_Erase 0x00000001

- (BOOL)setupCortexM:(NSError **)error
{
    if (![super setupCortexM:error]) {
        return NO;
    }
    if (self.pagesPerWrite > 4) {
        self.pagesPerWrite = 4;
    }
    return YES;
}

- (BOOL)wait:(NSError **)error
{
    UInt32 status;
    do {
        if (![self.serialWireDebug readMemory:NRF_NVMC_READY value:&status error:error]) {
            return NO;
        }
    } while ((status & NRF_NVMC_READY_READY) == NRF_NVMC_READY_READY_Busy);
    return YES;
}

- (BOOL)erase:(UInt32)address value:(UInt32)value error:(NSError **)error
{
    if (![self.serialWireDebug writeMemory:NRF_NVMC_CONFIG value:NRF_NVMC_CONFIG_WEN_Een error:error]) {
        return NO;
    }
    if (![self wait:error]) {
        return NO;
    }

    if (![self.serialWireDebug writeMemory:address value:value error:error]) {
        return NO;
    }
    if (![self wait:error]) {
        return NO;
    }
    return YES;
}

- (BOOL)massErase:(NSError **)error
{
    return [self erase:NRF_NVMC_ERASEALL value:NRF_NVMC_ERASEALL_ERASEALL_Erase error:error];
}

- (BOOL)eraseUICR:(NSError **)error
{
    return [self erase:NRF_NVMC_ERASEUICR value:NRF_NVMC_ERASEALL_ERASEUICR_Erase error:error];
}

@end
