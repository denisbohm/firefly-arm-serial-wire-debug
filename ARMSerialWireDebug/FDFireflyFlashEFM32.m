//
//  FDFireflyFlashEFM32.m
//  FireflyProduction
//
//  Created by Denis Bohm on 8/20/14.
//  Copyright (c) 2014 Firefly Design. All rights reserved.
//

#import "FDError.h"
#import "FDFireflyFlashEFM32.h"

// Authentication Access Port (AAP)

#define SWD_AAP_CMD 0x00
#define SWD_AAP_CMDKEY 0x04
#define SWD_AAP_STATUS 0x08
#define SWD_AAP_IDR 0xfc

#define SWD_AAP_CMD_SYSRESETREQ 0x00000002
#define SWD_AAP_CMD_DEVICEERASE 0x00000001

#define SWD_AAP_CMDKEY_WRITEEN 0xcfacc118

#define SWD_AAP_STATUS_ERASEBUSY 0x00000001

// Device is locked
#define SWD_AAP_ID 0x16e60001

@implementation FDFireflyFlashEFM32

- (BOOL)setupProcessor:(NSError **)error
{
    UInt8 value8;
    if (![self.serialWireDebug readMemoryUInt8:EFM32_PART_FAMILY value:&value8 error:error]) {
        return NO;
    }
    _family = value8;

    UInt16 value16;
    if (![self.serialWireDebug readMemoryUInt16:EFM32_MEM_INFO_FLASH value:&value16 error:error]) {
        return NO;
    }
    _flashSize = value16 * 1024;
    
    UInt8 mem_info_page_size;
    if (![self.serialWireDebug readMemoryUInt8:EFM32_MEM_INFO_PAGE_SIZE value:&mem_info_page_size error:error]) {
        return NO;
    }
    self.pageSize = 1 << ((mem_info_page_size + 10) & 0xff);
    
    self.ramAddress = EFM32_RAM_ADDRESS;
    if (![self.serialWireDebug readMemoryUInt16:EFM32_MEM_INFO_RAM value:&value16 error:error]) {
        return NO;
    }
    self.ramSize = value16 * 1024;
    return YES;
}

- (BOOL)feedWatchdog:(NSError **)error
{
    return [self.serialWireDebug writeMemory:EFM32_WDOG_CMD value:EFM32_WDOG_CMD_CLEAR error:error];
}

- (BOOL)disableWatchdogByErasingIfNeeded:(BOOL *)erased error:(NSError **)error
{
    uint32_t wdogCtrl;
    if (![self.serialWireDebug readMemory:EFM32_WDOG_CTRL value:&wdogCtrl error:error]) {
        return NO;
    }
    if ((wdogCtrl & EFM32_WDOG_CTRL_LOCK) == 0) {
        if (![self.serialWireDebug writeMemory:EFM32_WDOG_CTRL value:EFM32_WDOG_CTRL_DEFAULT error:error]) {
            return NO;
        }
        *erased = NO;
        return YES;
    }
    
    if ((wdogCtrl & EFM32_WDOG_CTRL_EN) == 0) {
        *erased = NO;
        return YES;
    }
    
    FDLog(@"watchdog is enabled and locked - erasing and resetting device to clear watchdog");
    if (![self massErase:error]) {
        return NO;
    }
    if (![self reset:error]) {
        return NO;
    }
    if (![self.serialWireDebug readMemory:EFM32_WDOG_CTRL value:&wdogCtrl error:error]) {
        return NO;
    }
    if (wdogCtrl & EFM32_WDOG_CTRL_EN) {
        FDLog(@"could not disable watchdog");
    }

    if (![self loadFireflyFlashFirmwareIntoRAM:error]) {
        return NO;
    }

    *erased = YES;
    return YES;
}

#define BIT(n) (1 << (n))

#define MSC 0x400c0000

#define MSC_WRITECTRL (MSC + 0x008)
#define MSC_WRITECMD  (MSC + 0x00c)
#define MSC_ADDRB     (MSC + 0x010)
#define MSC_WDATA     (MSC + 0x018)
#define MSC_STATUS    (MSC + 0x01c)
#define MSC_LOCK      (MSC + 0x03c)
#define MSC_MASSLOCK  (MSC + 0x054)

#define MSC_WRITECTRL_WREN BIT(0)

#define MSC_WRITECMD_LADDRIM    BIT(0)
#define MSC_WRITECMD_ERASEPAGE  BIT(1)
#define MSC_WRITECMD_WRITEEND   BIT(2)
#define MSC_WRITECMD_WRITEONCE  BIT(3)
#define MSC_WRITECMD_WRITETRIG  BIT(4)
#define MSC_WRITECMD_ERASEABORT BIT(5)
#define MSC_WRITECMD_ERASEMAIN0 BIT(8)
#define MSC_WRITECMD_ERASEMAIN1 BIT(9)
#define MSC_WRITECMD_CLEARWDATA BIT(12)

#define MSC_STATUS_BUSY         BIT(0)
#define MSC_STATUS_LOCKED       BIT(1)
#define MSC_STATUS_INVADDR      BIT(2)
#define MSC_STATUS_WDATAREADY   BIT(3)
#define MSC_STATUS_WORDTIMEOUT  BIT(4)
#define MSC_STATUS_ERASEABORTED BIT(5)

#define MSC_LOCK_UNLOCK_CODE 0x1B71

#define MSC_MASSLOCK_UNLOCK 0x631a

- (BOOL)memorySystemControllerStatusWait:(UInt32)mask value:(UInt32)value error:(NSError **)error
{
    NSTimeInterval timeout = 0.250;
    NSDate *start = [NSDate date];
    NSDate *now;
    do {
        UInt32 status;
        if (![self.serialWireDebug readMemory:MSC_STATUS value:&status error:error]) {
            return NO;
        }
        if ((status & mask) != value) {
            return YES;
        }

        [NSThread sleepForTimeInterval:0.0001];
        now = [NSDate date];
    } while ([now timeIntervalSinceDate:start] < timeout);
    return FDErrorReturn(error, @{@"reason": @"timeout"});
}

- (BOOL)loadAddress:(UInt32)address error:(NSError **)error
{
    if (![self.serialWireDebug writeMemory:MSC_WRITECTRL value:MSC_WRITECTRL_WREN error:error]) {
        return NO;
    }
    if (![self.serialWireDebug writeMemory:MSC_ADDRB value:address error:error]) {
        return NO;
    }
    if (![self.serialWireDebug writeMemory:MSC_WRITECMD value:MSC_WRITECMD_LADDRIM error:error]) {
        return NO;
    }
    UInt32 status;
    if (![self.serialWireDebug readMemory:MSC_STATUS value:&status error:error]) {
        return NO;
    }
    if (status & (MSC_STATUS_INVADDR | MSC_STATUS_LOCKED)) {
        NSLog(@"fail");
    }
    return YES;
}

- (BOOL)erase:(UInt32)address error:(NSError **)error
{
    BOOL (^block)(NSError **) = ^(NSError **error) {
        if (![self loadAddress:address error:error]) {
            return NO;
        }
        if (![self.serialWireDebug writeMemory:MSC_WRITECMD value:MSC_WRITECMD_ERASEPAGE error:error]) {
            return NO;
        }
        return [self memorySystemControllerStatusWait:MSC_STATUS_BUSY value:MSC_STATUS_BUSY error:error];
    };
    return [self.serialWireDebug recoverAndRetry:block error:error];
}

- (BOOL)massEraseLeopard:(NSError **)error
{
    BOOL (^block)(NSError **) = ^(NSError **error) {
        if (![self.serialWireDebug writeMemory:MSC_WRITECTRL value:MSC_WRITECTRL_WREN error:error]) {
            return NO;
        }
        if (![self.serialWireDebug writeMemory:MSC_MASSLOCK value:MSC_MASSLOCK_UNLOCK error:error]) {
            return NO;
        }
        if (![self.serialWireDebug writeMemory:MSC_WRITECMD value:MSC_WRITECMD_ERASEMAIN0 error:error]) {
            return NO;
        }
        return [self memorySystemControllerStatusWait:MSC_STATUS_BUSY value:MSC_STATUS_BUSY error:error];
    };
    return [self.serialWireDebug recoverAndRetry:block error:error];
}

- (BOOL)massErase:(NSError **)error
{
    switch (_family) {
        case 0: {
            UInt32 pages = _flashSize / self.pageSize;
            for (UInt32 page = 0; page < pages; ++page) {
                UInt32 address = page * self.pageSize;
                if (![self erase:address error:error]) {
                    return NO;
                }
            }
        } break;
        case EFM32_PART_FAMILY_Gecko: {
            UInt32 pages = _flashSize / self.pageSize;
            for (UInt32 page = 0; page < pages; ++page) {
                UInt32 address = page * self.pageSize;
                if (![self.serialWireDebug writeMemory:EFM32_WDOG_CMD value:EFM32_WDOG_CMD_CLEAR error:error]) {
                    return NO;
                }
                if (![self erase:address error:error]) {
                    return NO;
                }
            }
        } break;
        case EFM32_PART_FAMILY_Leopard_Gecko: {
            if (![self massEraseLeopard:error]) {
                return NO;
            }
        } break;
        default:
            return FDErrorReturn(error, @{@"reason": @"unknown family"});
    }
    return YES;
}

#define SWD_DP_SELECT_APSEL_APB_AP 0

static UInt32 unpackLittleEndianUInt32(uint8_t *bytes) {
    return (bytes[3] << 24) | (bytes[2] << 16) | (bytes[1] << 8) | bytes[0];
}

- (BOOL)flashTransfer:(UInt32)address data:(NSData *)data error:(NSError **)error
{
    if ((address & 0x3) != 0) {
        NSString *reason = [NSString stringWithFormat:@"invalid address: %08x", address];
        return FDErrorReturn(error, @{@"reason": reason});
    }
    UInt32 length = (UInt32)data.length;
    if ((length == 0) || ((length & 0x3) != 0)) {
        NSString *reason = [NSString stringWithFormat:@"invalid length: %lu", (unsigned long int)length];
        return FDErrorReturn(error, @{@"reason": reason});
    }

    if (![self.serialWireDebug writeMemory:MSC_LOCK value:MSC_LOCK_UNLOCK_CODE error:error]) {
        return NO;
    }

    BOOL fast = NO;
    if (fast) {
        if (![self.serialWireDebug accessPortBankSelect:SWD_DP_SELECT_APSEL_APB_AP registerOffset:0x00 error:error]) {
            return NO;
        }
        if (![self.serialWireDebug setOverrunDetection:true error:error]) {
            return NO;
        }
    }

    UInt8 apTarRequest = [self.serialWireDebug encodeRequestPort:FDSerialWireDebugPortAccess direction:FDSerialWireDebugDirectionWrite address:SWD_AP_TAR];
    UInt8 apDrwRequest = [self.serialWireDebug encodeRequestPort:FDSerialWireDebugPortAccess direction:FDSerialWireDebugDirectionWrite address:SWD_AP_DRW];
    UInt8 *bytes = (UInt8 *)data.bytes;
    for (NSUInteger i = 0; i < length; i += 4) {
        UInt32 value = unpackLittleEndianUInt32(&bytes[i]);
        if (fast) {
            // We don't need the two way status waits, because going over USB via FTDI, etc
            // is slower than the operations take. -denis
            [self.serialWireDebug requestWriteSkip:apTarRequest value:MSC_WDATA];
            [self.serialWireDebug requestWriteSkip:apDrwRequest value:value];
            [self.serialWireDebug requestWriteSkip:apTarRequest value:MSC_WRITECMD];
            [self.serialWireDebug requestWriteSkip:apDrwRequest value:MSC_WRITECMD_WRITETRIG];
        } else {
            if (![self loadAddress:(uint32_t)(address + i) error:error]) {
                return NO;
            }
            if (![self memorySystemControllerStatusWait:MSC_STATUS_WDATAREADY value:0 error:error]) {
                return NO;
            }
            if (![self.serialWireDebug writeMemory:MSC_WDATA value:value error:error]) {
                return NO;
            }
            if (![self.serialWireDebug writeMemory:MSC_WRITECMD value:MSC_WRITECMD_WRITEONCE error:error]) {
                return NO;
            }
            if (![self memorySystemControllerStatusWait:MSC_STATUS_BUSY value:MSC_STATUS_BUSY error:error]) {
                return NO;
            }
            UInt32 status;
            if (![self.serialWireDebug readMemory:MSC_STATUS value:&status error:error]) {
                return NO;
            }
            if (status & (MSC_STATUS_LOCKED | MSC_STATUS_WORDTIMEOUT | MSC_STATUS_ERASEABORTED)) {
                NSString *reason = [NSString stringWithFormat:@"BAD MSC STATUS: %08lx", (unsigned long int)status];
                return FDErrorReturn(error, @{@"reason": reason});
            }
        }
    }

    if (fast) {
        [self.serialWireDebug flush];
        if (![self.serialWireDebug afterMemoryTransfer:error]) {
            return NO;
        }
    }

    if (![self.serialWireDebug writeMemory:MSC_LOCK value:0 error:error]) {
        return NO;
    }

    return YES;
}

- (BOOL)flash:(UInt32)address data:(NSData *)data error:(NSError **)error
{
    BOOL (^block)(UInt32, UInt32, UInt32, NSError **) = ^(UInt32 subaddress, UInt32 offset, UInt32 sublength, NSError **error) {
        return [self flashTransfer:subaddress data:[data subdataWithRange:NSMakeRange(offset, sublength)] error:error];
    };
    return [self.serialWireDebug paginate:0x7ff address:address length:(UInt32)data.length block:block error:error];
}

- (BOOL)setDebugLock:(NSError **)error
{
    uint8_t bytes[] = {0, 0, 0, 0};
    return [self flash:EFM32_LB_DLW data:[NSData dataWithBytes:bytes length:4] error:error];
}

- (BOOL)getDebugLock:(BOOL *)debugLock error:(NSError **)error
{
    uint32_t value;
    if (![self.serialWireDebug readMemory:EFM32_LB_DLW value:&value error:error]) {
        return NO;
    }
    *debugLock = (value & 0x0000000f) != 0x0000000f;
    return YES;
}

- (BOOL)isAuthenticationAccessPortActive:(BOOL *)active error:(NSError **)error
{
    uint32_t dpid;
    if (![self.serialWireDebug readDebugPort:0 value:&dpid error:error]) {
        return NO;
    }
    if ((dpid != SWD_DPID_CM4) && (dpid != SWD_DPID_CM3) && (dpid != SWD_DPID_CM0DAP1) && (dpid != SWD_DPID_CM0DAP2)){
        NSString *reason = [NSString stringWithFormat:@"DPID 0x%08x not recognized", dpid];
        return FDErrorReturn(error, @{@"reason": reason});
    }

    // EFM32G
    uint32_t apid;
    if (![self.serialWireDebug readAccessPortID:SWD_DP_SELECT_APSEL_APB_AP value:&apid error:error]) {
        return NO;
    }
    *active = SWD_IDR_CODE(apid) == SWD_IDR_CODE(SWD_AAP_ID);
    return YES;
}

#define SWD_AAP_ERASE_TIMEOUT 0.200 // erase takes 125 ms

- (BOOL)authenticationAccessPortErase:(NSError **)error
{
    if (![self.serialWireDebug writeAccessPort:SWD_DP_SELECT_APSEL_APB_AP registerOffset:SWD_AAP_CMDKEY value:SWD_AAP_CMDKEY_WRITEEN error:error]) {
        return NO;
    }
    if (![self.serialWireDebug writeAccessPort:SWD_DP_SELECT_APSEL_APB_AP registerOffset:SWD_AAP_CMD value:SWD_AAP_CMD_DEVICEERASE error:error]) {
        return NO;
    }
    NSDate *start = [NSDate date];
    do {
        [NSThread sleepForTimeInterval:0.025];
        uint32_t status;
        if (![self.serialWireDebug readAccessPort:SWD_DP_SELECT_APSEL_APB_AP registerOffset:SWD_AAP_STATUS value:&status error:error]) {
            return NO;
        }
        if ((status & SWD_AAP_STATUS_ERASEBUSY) == 0) {
            return YES;
        }
    } while ([[NSDate date] timeIntervalSinceDate:start] < SWD_AAP_ERASE_TIMEOUT);
    return FDErrorReturn(error, @{@"reason": @"timeout"});
}

- (BOOL)authenticationAccessPortReset:(NSError **)error
{
    return [self.serialWireDebug writeAccessPort:SWD_DP_SELECT_APSEL_APB_AP registerOffset:SWD_AAP_CMD value:SWD_AAP_CMD_SYSRESETREQ error:error];
}


@end
