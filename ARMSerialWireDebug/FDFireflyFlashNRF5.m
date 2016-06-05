//
//  FDFireflyFlashNRF5.m
//  ARMSerialWireDebug
//
//  Created by Denis Bohm on 8/19/15.
//  Copyright (c) 2015 Firefly Design. All rights reserved.
//

#import "FDFireflyFlashNRF5.h"

@implementation FDFireflyFlashNRF5

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

- (BOOL)nvmc:(UInt32)operation address:(UInt32)address value:(UInt32)value error:(NSError **)error
{
    if (![self.serialWireDebug writeMemory:NRF_NVMC_CONFIG value:operation error:error]) {
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
    return [self nvmc:NRF_NVMC_CONFIG_WEN_Een address:NRF_NVMC_ERASEALL value:NRF_NVMC_ERASEALL_ERASEALL_Erase error:error];
}

- (BOOL)eraseUICR:(NSError **)error
{
    return [self nvmc:NRF_NVMC_CONFIG_WEN_Een address:NRF_NVMC_ERASEUICR value:NRF_NVMC_ERASEALL_ERASEUICR_Erase error:error];
}

@end
