//
//  FDFireflyFlashNRF5.h
//  ARMSerialWireDebug
//
//  Created by Denis Bohm on 8/19/15.
//  Copyright (c) 2015 Firefly Design. All rights reserved.
//

#import "FDFireflyFlash.h"

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

@interface FDFireflyFlashNRF5 : FDFireflyFlash

- (BOOL)eraseUICR:(NSError * _Nullable * _Nullable)error;

- (BOOL)nvmc:(UInt32)operation address:(UInt32)address value:(UInt32)value error:(NSError * _Nullable * _Nullable)error;

@end
