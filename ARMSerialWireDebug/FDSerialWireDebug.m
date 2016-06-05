//
//  FDSerialWireDebug.m
//  ARMSerialWireDebug
//
//  Created by Denis Bohm on 1/7/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDError.h"
#import "FDLogger.h"
#import "FDSerialEngine.h"
#import "FDSerialWireDebug.h"

#define BIT(n) (1 << (n))

// Debug Port (DP)

// Cortex M4
#define SWD_DPID_CM4 0x0ba01477
// Cortex M3
#define SWD_DPID_CM3 0x2ba01477
// Cortex M0
#define SWD_DPID_CM0DAP1 0x0bb11477
// Cortex M0+
#define SWD_DPID_CM0DAP2 0x0bb12477

#define SWD_DP_IDCODE 0x00
#define SWD_DP_ABORT  0x00
#define SWD_DP_CTRL   0x04
#define SWD_DP_STAT   0x04
#define SWD_DP_SELECT 0x08
#define SWD_DP_RDBUFF 0x0c

#define SWD_DP_ABORT_ORUNERRCLR BIT(4)
#define SWD_DP_ABORT_WDERRCLR BIT(3)
#define SWD_DP_ABORT_STKERRCLR BIT(2)
#define SWD_DP_ABORT_STKCMPCLR BIT(1)
#define SWD_DP_ABORT_DAPABORT BIT(0)

#define SWD_DP_CTRL_CSYSPWRUPACK BIT(31)
#define SWD_DP_CTRL_CSYSPWRUPREQ BIT(30)
#define SWD_DP_CTRL_CDBGPWRUPACK BIT(29)
#define SWD_DP_CTRL_CDBGPWRUPREQ BIT(28)
#define SWD_DP_CTRL_CDBGRSTACK BIT(27)
#define SWD_DP_CTRL_CDBGRSTREQ BIT(26)
#define SWD_DP_STAT_WDATAERR BIT(7)
#define SWD_DP_STAT_READOK BIT(6)
#define SWD_DP_STAT_STICKYERR BIT(5)
#define SWD_DP_STAT_STICKYCMP BIT(4)
#define SWD_DP_STAT_TRNMODE BIT(3) | BIT(2)
#define SWD_DP_STAT_STICKYORUN BIT(1)
#define SWD_DP_STAT_ORUNDETECT BIT(0)

#define SWD_DP_SELECT_APSEL_APB_AP 0
#define SWD_DP_SELECT_APSEL_NRF52_CTRL_AP 1

#define SWD_AP_IDR 0xfc

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

// Advanced High-Performance Bus Access Port (AHB_AP or just AP)
#define SWD_AHB_AP_ID_V1 0x24770011
#define SWD_AHB_AP_ID_v2 0x04770021

#define SWD_AP_CSW 0x00
#define SWD_AP_TAR 0x04
#define SWD_AP_SBZ 0x08
#define SWD_AP_DRW 0x0c
#define SWD_AP_BD0 0x10
#define SWD_AP_BD1 0x14
#define SWD_AP_BD2 0x18
#define SWD_AP_BD3 0x1c
#define SWD_AP_DBGDRAR 0xf8
#define SWD_AP_IDR 0xfc

#define SWD_AP_CSW_DBGSWENABLE BIT(31)
#define SWD_AP_CSW_MASTER_DEBUG BIT(29)
#define SWD_AP_CSW_HPROT BIT(25)
#define SWD_AP_CSW_SPIDEN BIT(23)
#define SWD_AP_CSW_TRIN_PROG BIT(7)
#define SWD_AP_CSW_DEVICE_EN BIT(6)
#define SWD_AP_CSW_INCREMENT_PACKED BIT(5)
#define SWD_AP_CSW_INCREMENT_SINGLE BIT(4)
#define SWD_AP_CSW_32BIT BIT(1)
#define SWD_AP_CSW_16BIT BIT(0)

#define SWD_MEMORY_CPUID 0xE000ED00
#define SWD_MEMORY_DFSR  0xE000ED30
#define SWD_MEMORY_DHCSR 0xE000EDF0
#define SWD_MEMORY_DCRSR 0xE000EDF4
#define SWD_MEMORY_DCRDR 0xE000EDF8
#define SWD_MEMORY_DEMCR 0xE000EDFC

#define SWD_DHCSR_DBGKEY 0xA05F0000
#define SWD_DHCSR_STAT_RESET_ST BIT(25)
#define SWD_DHCSR_STAT_RETIRE_ST BIT(24)
#define SWD_DHCSR_STAT_LOCKUP BIT(19)
#define SWD_DHCSR_STAT_SLEEP BIT(18)
#define SWD_DHCSR_STAT_HALT BIT(17)
#define SWD_DHCSR_STAT_REGRDY BIT(16)
#define SWD_DHCSR_CTRL_SNAPSTALL BIT(5)
#define SWD_DHCSR_CTRL_MASKINTS BIT(3)
#define SWD_DHCSR_CTRL_STEP BIT(2)
#define SWD_DHCSR_CTRL_HALT BIT(1)
#define SWD_DHCSR_CTRL_DEBUGEN BIT(0)

@interface FDSerialWireDebug ()

@property UInt16 gpioInputs;
@property UInt16 gpioOutputs;
@property UInt16 gpioDirections;

@property NSUInteger gpioWriteBit;
@property NSUInteger gpioResetBit;
@property NSUInteger gpioIndicatorBit;
@property NSUInteger gpioDetectBit;

@property NSUInteger ackWaitRetryCount;
@property NSUInteger debugPortStatusRetryCount;
@property NSUInteger registerRetryCount;
@property NSUInteger recoveryRetryCount;

@property uint32_t dpid;
@property uint32_t apid;

@property BOOL overrunDetectionEnabled;
@property UInt32 tarIncrementBits;

@end

@implementation FDSerialWireDebug

// ADBUS0 OUT TCK
// ADBUS1 OUT TDI
// ADBUS2  IN TDO
// ADBUS3 OUT TMS
// ADBUS4 OUT ?
// ADBUS5  IN TARGET DETECT (target is present if 0)
// ADBUS6  IN TSRST
// ADBUS7  IN !RTCK
// ACBUS0 OUT !TRST
// ACBUS1 OUT !TSRST
// ACBUS2 OUT TRST
// ACBUS3 OUT LED

- (id)init
{
    if (self = [super init]) {
        _logger = [[FDLogger alloc] init];
        
        _clockDivisor = 5;
        
        _gpioDirections = 0b0000111100011011;
        _gpioOutputs = 0b0000001000000000;
        _gpioWriteBit = 3;
        _gpioResetBit = 9;
        _gpioIndicatorBit = 11;
        _gpioDetectBit = 5;
        
        _ackWaitRetryCount = 3;
        _debugPortStatusRetryCount = 3;
        _registerRetryCount = 3;
        _recoveryRetryCount = 5;
        
        _tarIncrementBits = 0x3f;
//        _tarIncrementBits = 0x3ff;
    }
    return self;
}

- (BOOL)initialize:(NSError **)error
{
    if (![_serialEngine read:error]) {
        FDLog(@"unexpected error: %@", error);
    }
    
    [_serialEngine setLoopback:false];
    [_serialEngine setClockDivisor:_clockDivisor];
    if (![_serialEngine write:error]) {
        return NO;
    }
    
    if (![_serialEngine setLatencyTimer:2 error:error]) {
        return NO;
    }
    if (![_serialEngine setMPSEEBitMode:error]) {
        return NO;
    }
    if (![_serialEngine reset:error]) {
        return NO;
    }
    
    [_serialEngine setLowByte:_gpioOutputs direction:_gpioDirections];
    [_serialEngine setHighByte:_gpioOutputs >> 8 direction:_gpioDirections >> 8];
    [_serialEngine sendImmediate];
    if (![_serialEngine write:error]) {
        return NO;
    }

    if (![self getGpios:error]) {
        return NO;
    }

    // reading detect seems flakey, the following seems to make it stable -denis
    [self setGpioBit:_gpioWriteBit value:true];
    if (![self getGpios:error]) {
        return NO;
    }

    return YES;
}

- (BOOL)getGpios:(NSError **)error
{
    [_serialEngine getLowByte];
    [_serialEngine getHighByte];
    [_serialEngine sendImmediate];
    if (![_serialEngine write:error]) {
        return NO;
    }
    NSData *data = [_serialEngine read:2 error:error];
    if (data == nil) {
        return NO;
    }
    UInt8 *bytes = (UInt8 *)data.bytes;
    _gpioInputs = (bytes[1] << 8) | bytes[0];
    return YES;
}

- (BOOL)getGpioDetect:(BOOL *)detect error:(NSError **)error
{
    if (![self getGpios:error]) {
        return NO;
    }
    *detect = _gpioInputs & (1 << _gpioDetectBit) ? NO : YES;
    return YES;
}

- (void)setGpioBit:(NSUInteger)bit value:(BOOL)value
{
    UInt16 mask = 1 << bit;
    UInt16 outputs = _gpioOutputs;
    if (value) {
        outputs |= mask;
    } else {
        outputs &= ~mask;
    }
    if (outputs == _gpioOutputs) {
        return;
    }
    _gpioOutputs = outputs;
    if (mask & 0x00ff) {
        [_serialEngine setLowByte:_gpioOutputs direction:_gpioDirections];
    } else {
        [_serialEngine setHighByte:_gpioOutputs >> 8 direction:_gpioDirections >> 8];
    }
}

- (void)setGpioIndicator:(BOOL)value
{
    [self setGpioBit:_gpioIndicatorBit value:value];
}

- (void)setGpioReset:(BOOL)value
{
    [self setGpioBit:_gpioResetBit value:value];
}

- (void)turnToWrite
{
    [self setGpioBit:_gpioWriteBit value:true];
}

- (void)turnToRead
{
    [self setGpioBit:_gpioWriteBit value:false];
}

- (void)skip:(NSUInteger)n
{
    [_serialEngine shiftOutBitsLSBFirstNegativeEdge:0 bitCount:n];
}

- (void)turnToWriteAndSkip
{
    [self turnToWrite];
    [self skip:1];
}

- (void)turnToReadAndSkip
{
    [self turnToRead];
    [self skip:1];
}

- (void)detachDebugPort
{
    [self turnToWrite];
    UInt8 bytes[] = {
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
    };
    [_serialEngine shiftOutDataLSBFirstNegativeEdge:[NSData dataWithBytes:bytes length:sizeof(bytes)]];
}

- (void)resetDebugPort
{
    [self turnToWrite];
    UInt8 bytes[] = {
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
        0x9e,
        0xe7,
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
        0x00,
    };
    [_serialEngine shiftOutDataLSBFirstNegativeEdge:[NSData dataWithBytes:bytes length:sizeof(bytes)]];
}

- (UInt8)getParityUInt8:(UInt8)v {
    return (0x6996 >> ((v ^ (v >> 4)) & 0xf)) & 1;
}

- (UInt8)getParityUInt32:(UInt32)v {
    v ^= v >> 16;
    v ^= v >> 8;
    return [self getParityUInt8:v];
}

typedef enum {
    SWDDebugPort,
    SWDAccessPort,
} SWDPort;

typedef enum {
    SWDWriteDirection,
    SWDReadDirection,
} SWDDirection;

- (UInt8)encodeRequestPort:(SWDPort)port direction:(SWDDirection)direction address:(UInt8)address
{
    UInt8 request = 0b10000001; // Start (bit 0) & Park (bit 7)
    if (port == SWDAccessPort) {
        request |= 0b00000010;
    }
    if (direction == SWDReadDirection) {
        request |= 0b00000100;
    }
    request |= (address << 1) & 0b00011000;
    if ([self getParityUInt8:request]) {
        request |= 0b00100000;
    }
    return request;
}

typedef enum {
    SWDOKAck = 0b001,
    SWDWaitAck = 0b010,
    SWDFaultAck = 0b100,
} SWDAck;

- (void)shiftInTurnAndAck
{
    [_serialEngine shiftInBitsLSBFirstPositiveEdge:4];
}

- (SWDAck)getTurnAndAck:(NSData *)data
{
    return ((UInt8 *)data.bytes)[0] >> 5;
}

- (BOOL)request:(UInt8)request ack:(SWDAck *)ack error:(NSError **)error
{
    [_serialEngine shiftOutBitsLSBFirstNegativeEdge:request bitCount:8];
    [self turnToRead];
    [self shiftInTurnAndAck];
    [_serialEngine sendImmediate];
    NSData *data = [_serialEngine read:1 error:error];
    if (data == nil) {
        return NO;
    }
    *ack = [self getTurnAndAck:data];
    return YES;
}

- (BOOL)readUInt32:(UInt32 *)value error:(NSError **)error
{
    [_serialEngine shiftInDataLSBFirstPositiveEdge:4];
    [_serialEngine shiftInBitsLSBFirstPositiveEdge:1]; // parity
    [_serialEngine sendImmediate];
    NSData *data = [_serialEngine read:5 error:error];
    if (data == nil) {
        return NO;
    }
    UInt8 *bytes = (UInt8 *)data.bytes;
    *value = (bytes[3] << 24) | (bytes[2] << 16) | (bytes[1] << 8) | bytes[0];
    BOOL parity = bytes[4] >> 7;
    if (parity != [self getParityUInt32:*value]) {
        return FDErrorReturn(error, @{@"reason": @"parity mismatch"});
    }
    return YES;
}

- (void)writeUInt32:(UInt32)value
{
    UInt8 bytes[] = {value, value >> 8, value >> 16, value >> 24};
    [_serialEngine shiftOutDataLSBFirstNegativeEdge:[NSData dataWithBytes:bytes length:sizeof(bytes)]];
    UInt8 parity = [self getParityUInt32:value];
    [_serialEngine shiftOutBitsLSBFirstNegativeEdge:parity bitCount:1];
}

- (BOOL)readPort:(SWDPort)port registerOffset:(UInt8)registerOffset value:(UInt32 *)value error:(NSError **)error
{
//    NSLog(@"read  %@ %02x", port == SWDDebugPort ? @"dp" : @"ap", registerOffset);
    NSError *deepError;
    UInt8 request = [self encodeRequestPort:port direction:SWDReadDirection address:registerOffset];
    for (NSUInteger retry = 0; retry < _ackWaitRetryCount; ++retry) {
        SWDAck ack;
        if (![self request:request ack:&ack error:&deepError]) {
            continue;
        }
        if (_overrunDetectionEnabled) {
            if (![self readUInt32:value error:&deepError]) {
                continue;
            }
            [self turnToWriteAndSkip];
        }
        if (ack == SWDOKAck) {
            if (!_overrunDetectionEnabled) {
                if (![self readUInt32:value error:&deepError]) {
                    continue;
                }
                [self turnToWriteAndSkip];
            }
//            NSLog(@"read  %@ %02x = %08x", port == SWDDebugPort ? @"dp" : @"ap", registerOffset, value);
            return YES;
        }
        if (!_overrunDetectionEnabled) {
            [self turnToWriteAndSkip];
        }
        if (ack != SWDWaitAck) {
            NSString *reason = [NSString stringWithFormat:@"unexpected ack %u", ack];
            return FDErrorReturn(error, @{@"reason": reason});
        }
    }
    if (error != nil) {
        *error = deepError;
    }
    return NO;
}

- (BOOL)writePort:(SWDPort)port registerOffset:(UInt8)registerOffset value:(UInt32)value error:(NSError **)error
{
//    NSLog(@"write %@ %02x = %08x", port == SWDDebugPort ? @"dp" : @"ap", registerOffset, value);
    NSError *deepError;
    UInt8 request = [self encodeRequestPort:port direction:SWDWriteDirection address:registerOffset];
    for (NSUInteger retry = 0; retry < _ackWaitRetryCount; ++retry) {
        SWDAck ack;
        if (![self request:request ack:&ack error:&deepError]) {
            continue;
        }
        [self turnToWriteAndSkip];
        if (_overrunDetectionEnabled) {
            [self writeUInt32:value];
        }
        if (ack == SWDOKAck) {
            if (!_overrunDetectionEnabled) {
                [self writeUInt32:value];
            }
//            NSLog(@"write %@ %02x = %08x done", port == SWDDebugPort ? @"dp" : @"ap", registerOffset, value);
            return YES;
        }
        if (ack != SWDWaitAck) {
            NSString *reason = [NSString stringWithFormat:@"unexpected ack %u writing to port %u, register offset %d, value 0x%08x", ack, port, registerOffset, value];
            return FDErrorReturn(error, @{@"reason": reason});
        }
    }
    if (error != nil) {
        *error = deepError;
    }
    return NO;
}

- (BOOL)readDebugPort:(UInt8)registerOffset value:(UInt32 *)value error:(NSError **)error
{
    return [self readPort:SWDDebugPort registerOffset:registerOffset value:value error:error];
}

- (BOOL)writeDebugPort:(UInt8)registerOffset value:(UInt32)value error:(NSError **)error
{
    return [self writePort:SWDDebugPort registerOffset:registerOffset value:value error:error];
}

- (BOOL)readDebugPortIDCode:(UInt32 *)value error:(NSError **)error
{
    return [self readDebugPort:SWD_DP_IDCODE value:value error:error];
}

- (BOOL)readTargetID:(UInt32 *)value error:(NSError **)error
{
    if (![self writePort:SWDDebugPort registerOffset:SWD_DP_SELECT value:0x02 error:error]) {
        return NO;
    }
    return [self readDebugPort:0x04 value:value error:error];
}

- (BOOL)waitForDebugPortStatus:(UInt32)mask error:(NSError **)error
{
    for (NSUInteger retry = 0; retry < _debugPortStatusRetryCount; ++ retry) {
        UInt32 status;
        if (![self readDebugPort:SWD_DP_STAT value:&status error:error]) {
            return NO;
        }
        if (status & mask) {
            return YES;
        }
    }
    return FDErrorReturn(error, @{@"reason": @"timeout"});
}

- (NSString *)getDebugPortStatusMessage:(UInt32)status
{
    NSMutableString *message = [NSMutableString string];
    if (status & SWD_DP_STAT_WDATAERR) {
        [message appendString:@"write data error, "];
    }
    if (status & SWD_DP_STAT_STICKYERR) {
        [message appendString:@"sticky error, "];
    }
    if (status & SWD_DP_STAT_STICKYORUN) {
        [message appendString:@"sticky overrun, "];
    }
    return [message substringToIndex:message.length - 2];
}

- (BOOL)checkDebugPortStatus:(NSError **)error
{
    UInt32 status;
    if (![self readDebugPort:SWD_DP_STAT value:&status error:error]) {
        return NO;
    }
    if (!(status & (SWD_DP_STAT_WDATAERR | SWD_DP_STAT_STICKYERR | SWD_DP_STAT_STICKYORUN))) {
        return YES;
    }
    
    FDLog(@"attempting to recover from debug port status: %@", [self getDebugPortStatusMessage:status]);
    if (self.minimalDebugPort) {
        if (![self writeDebugPort:SWD_DP_ABORT
                            value:SWD_DP_ABORT_ORUNERRCLR |
                                  SWD_DP_ABORT_WDERRCLR
                            error:error]
        ) {
            return NO;
        }
    } else {
        if (![self writeDebugPort:SWD_DP_ABORT
                            value:SWD_DP_ABORT_ORUNERRCLR |
                                  SWD_DP_ABORT_WDERRCLR |
                                  SWD_DP_ABORT_STKERRCLR |
                                  SWD_DP_ABORT_STKCMPCLR
                            error:error]
        ) {
            return NO;
        }
    }
    
    UInt32 recoveryStatus;
    if (![self readDebugPort:SWD_DP_STAT value:&recoveryStatus error:error]) {
        return NO;
    }
    if (recoveryStatus & (SWD_DP_STAT_WDATAERR | SWD_DP_STAT_STICKYERR | SWD_DP_STAT_STICKYORUN)) {
        FDLog(@"debug port status recovery failed: %@", [self getDebugPortStatusMessage:recoveryStatus]);
    }
    
    if (![self writeDebugPort:SWD_DP_SELECT value:0 error:error]) {
        return NO;
    }
    
    return [self writeAccessPort:SWD_DP_SELECT_APSEL_APB_AP registerOffset:SWD_AP_CSW
                    value:SWD_AP_CSW_DBGSWENABLE |
                          SWD_AP_CSW_MASTER_DEBUG |
                          SWD_AP_CSW_HPROT |
                          SWD_AP_CSW_INCREMENT_SINGLE |
                          SWD_AP_CSW_32BIT
                    error:error];
}

- (BOOL)recoverFromDebugPortError:(NSError **)error
{
    [self resetDebugPort];
    UInt32 debugPortIDCode;
    if (![self readDebugPortIDCode:&debugPortIDCode error:error]) {
        return NO;
    }
    NSLog(@"DPID = %08x", debugPortIDCode);
    return [self checkDebugPortStatus:error];
}

- (BOOL)accessPortBankSelect:(UInt8)accessPort registerOffset:(UInt8)registerOffset error:(NSError **)error
{
    UInt32 value = (accessPort << 24) | (registerOffset & 0xf0);
    return [self writePort:SWDDebugPort registerOffset:SWD_DP_SELECT value:value error:error];
}

- (BOOL)readAccessPort:(UInt8)accessPort registerOffset:(UInt8)registerOffset value:(UInt32 *)value error:(NSError **)error
{
//    NSLog(@"read access port %02x", registerOffset);
    if (![self accessPortBankSelect:accessPort registerOffset:registerOffset error:error]) {
        return NO;
    }
    UInt32 dummy;
    if (![self readPort:SWDAccessPort registerOffset:registerOffset value:&dummy error:error]) {
        return NO;
    }
    if (![self readPort:SWDDebugPort registerOffset:SWD_DP_RDBUFF value:value error:error]) {
        return NO;
    }
//    NSLog(@"read access port %02x = %08x", registerOffset, value);
    return YES;
}

- (void)flush
{
    [_serialEngine shiftOutBitsLSBFirstNegativeEdge:0x00 bitCount:8];
}

- (BOOL)writeAccessPort:(UInt8)accessPort registerOffset:(UInt8)registerOffset value:(UInt32)value error:(NSError **)error
{
//    NSLog(@"write access port %02x = %08x", registerOffset, value);
    if (![self accessPortBankSelect:accessPort registerOffset:registerOffset error:error]) {
        return NO;
    }
    if (![self writePort:SWDAccessPort registerOffset:registerOffset value:value error:error]) {
        return NO;
    }
    [self flush];
//    NSLog(@"write access port %02x = %08x done", registerOffset, value);
    return YES;
}

- (BOOL)recoverAndRetry:(BOOL (^)(NSError **))block error:(NSError **)error
{
    NSError *blockError;
    for (NSUInteger i = 0; i < _recoveryRetryCount; ++i) {
        blockError = nil;
        if (block(&blockError)) {
            break;
        }
        if (i == (_recoveryRetryCount - 1)) {
            break;
        }
        FDLog(@"unexpected exception (attempting recovery): %@", blockError);
        if (![self recoverFromDebugPortError:&blockError]) {
            break;
        }
    }
    if (error != nil) {
        *error = blockError;
    }
    return blockError == nil;
}

- (BOOL)readMemory:(UInt32)address value:(UInt32 *)value error:(NSError **)error
{
//    NSLog(@"read memory %08x", address);
    BOOL (^block)(NSError **) = ^(NSError **error) {
        if (![self writeAccessPort:SWD_DP_SELECT_APSEL_APB_AP registerOffset:SWD_AP_TAR value:address error:error]) {
            return NO;
        }
        return [self readAccessPort:SWD_DP_SELECT_APSEL_APB_AP registerOffset:SWD_AP_DRW value:value error:error];
    };
    return [self recoverAndRetry:block error:error];
}

- (BOOL)writeMemory:(UInt32)address value:(UInt32)value error:(NSError **)error
{
//    NSLog(@"write memory %08x = %08x", address, value);
    BOOL (^block)(NSError **) = ^(NSError **error) {
        if (![self writeAccessPort:SWD_DP_SELECT_APSEL_APB_AP registerOffset:SWD_AP_TAR value:address error:error]) {
            return NO;
        }
        return [self writeAccessPort:SWD_DP_SELECT_APSEL_APB_AP registerOffset:SWD_AP_DRW value:value error:error];
    };
    if (![self recoverAndRetry:block error:error]) {
        return NO;
    }
//    NSLog(@"write memory %08x = %08x done", address, value);
    return YES;
}

- (BOOL)setOverrunDetection:(BOOL)enabled error:(NSError **)error
{
    if (self.minimalDebugPort) {
        @throw [NSException exceptionWithName:@"overrun detection not supported"
                                       reason:@"overrun detection not supported in minimal debug port"
                                     userInfo:nil];
    }
    
    if (![self writeDebugPort:SWD_DP_ABORT
                        value:SWD_DP_ABORT_ORUNERRCLR |
                              SWD_DP_ABORT_WDERRCLR |
                              SWD_DP_ABORT_STKERRCLR |
                              SWD_DP_ABORT_STKCMPCLR
                        error:error]
    ) {
        return NO;
    }
    
    UInt32 value = SWD_DP_CTRL_CDBGPWRUPREQ | SWD_DP_CTRL_CSYSPWRUPREQ;
    if (enabled) {
        value |= SWD_DP_STAT_ORUNDETECT;
    }
    if (![self writeDebugPort:SWD_DP_CTRL value:value error:error]) {
        return NO;
    }
    
    _overrunDetectionEnabled = enabled;
    return YES;
}

static UInt32 unpackLittleEndianUInt32(uint8_t *bytes) {
    return (bytes[3] << 24) | (bytes[2] << 16) | (bytes[1] << 8) | bytes[0];
}

- (BOOL)beforeMemoryTransfer:(UInt32)address length:(NSUInteger)length error:(NSError **)error
{
    if ((address & 0x3) != 0) {
        NSString *reason = [NSString stringWithFormat:@"invalid address: %08x", address];
        return FDErrorReturn(error, @{@"reason": reason});
    }
    if ((length == 0) || ((length & 0x3) != 0)) {
        NSString *reason = [NSString stringWithFormat:@"invalid length: %lu", (unsigned long int)length];
        return FDErrorReturn(error, @{@"reason": reason});
    }
    // TAR auto increment is only guaranteed in the first 10-bits (beyond that is implementation defined)
    UInt32 endAddress = (UInt32) (address + length - 1);
    if ((address & ~_tarIncrementBits) != (endAddress & ~_tarIncrementBits)) {
        NSString *reason = [NSString stringWithFormat:@"invalid address range: %08x to %08x", address, endAddress];
        return FDErrorReturn(error, @{@"reason": reason});
    }
    
    if (![self writeAccessPort:SWD_DP_SELECT_APSEL_APB_AP registerOffset:SWD_AP_TAR value:address error:error]) {
        return NO;
    }
    if (![self accessPortBankSelect:SWD_DP_SELECT_APSEL_APB_AP registerOffset:SWD_AP_DRW error:error]) {
        return NO;
    }
    return [self setOverrunDetection:true error:error];
}

- (BOOL)afterMemoryTransfer:(NSError **)error
{
    uint32_t status;
    if (![self readDebugPort:SWD_DP_STAT value:&status error:error]) {
        return NO;
    }
    if (![self setOverrunDetection:false error:error]) {
        return NO;
    }
    if (status & (SWD_DP_STAT_WDATAERR | SWD_DP_STAT_STICKYERR | SWD_DP_STAT_STICKYORUN)) {
        NSString *reason = [NSString stringWithFormat:@"sticky error after block transfer: %@", [self getDebugPortStatusMessage:status]];
        return FDErrorReturn(error, @{@"reason": reason});
    }
    return YES;
}

- (void)requestWriteSkip:(UInt8)request value:(UInt32)value
{
    [_serialEngine shiftOutBitsLSBFirstNegativeEdge:request bitCount:8];
    [self turnToRead];
    [self skip:4]; // skip over turn and ack
    [self turnToWriteAndSkip];
    [self writeUInt32:value];
}

- (BOOL)writeMemoryTransfer:(UInt32)address data:(NSData *)data error:(NSError **)error
{
    if (![self beforeMemoryTransfer:address length:data.length error:error]) {
        return NO;
    }
    
    uint8_t request = [self encodeRequestPort:SWDAccessPort direction:SWDWriteDirection address:SWD_AP_DRW];
    uint8_t *bytes = (uint8_t *)data.bytes;
    NSUInteger length = data.length;
    for (NSUInteger i = 0; i < length; i += 4) {
        [self requestWriteSkip:request value:unpackLittleEndianUInt32(&bytes[i])];
    }
    
    return [self afterMemoryTransfer:error];
}

- (NSData *)readMemoryTransfer:(UInt32)address length:(UInt32)length error:(NSError **)error
{
    if (![self beforeMemoryTransfer:address length:length error:error]) {
        return nil;
    }
    
    NSMutableData *data = [NSMutableData dataWithCapacity:length];

    uint8_t request = [self encodeRequestPort:SWDAccessPort direction:SWDReadDirection address:SWD_AP_DRW];
    uint32_t words = length / 4;
    // note: 1 extra iteration because of 1 read delay in getting data out
    for (NSUInteger i = 0; i <= words; ++i) {
        [_serialEngine shiftOutBitsLSBFirstNegativeEdge:request bitCount:8];
        [self turnToRead];
        [self skip:4]; // skip over turn and ack
        [_serialEngine shiftInDataLSBFirstPositiveEdge:4]; // data
        [_serialEngine shiftInBitsLSBFirstPositiveEdge:1]; // parity
        [self turnToWriteAndSkip];
    }
    [_serialEngine sendImmediate];
    
    NSData *output = [_serialEngine read:5 * (words + 1) error:error];
    if (output == nil) {
        return nil;
    }
    UInt8 *outputBytes = (UInt8 *)output.bytes;
    outputBytes += 5; // skip extra read data
    for (NSUInteger i = 0; i < words; ++i) {
        UInt8 *bytes = &outputBytes[i * 5];
        UInt32 value = (bytes[3] << 24) | (bytes[2] << 16) | (bytes[1] << 8) | bytes[0];
        BOOL parity = bytes[4] >> 7;
        BOOL actual = [self getParityUInt32:value];
        if (parity != actual) { // This happens inconsistently... -denis
             // flush any pending data... -denis
            if (![_serialEngine read:error]) {
                return nil;
            }
            FDErrorReturn(error, @{@"reason": @"parity mismatch"});
        }
        [data appendBytes:bytes length:4];
    }

    if (![self afterMemoryTransfer:error]) {
        return nil;
    }

    return data;
}

- (BOOL)paginate:(UInt32)incrementBits
         address:(UInt32)address
          length:(UInt32)length
           block:(BOOL (^)(UInt32 subaddress, UInt32 offset, UInt32 sublength, NSError **error))block
           error:(NSError **)error
{
    NSError *blockError;
    UInt32 offset = 0;
    while (length > 0) {
        UInt32 sublength = (incrementBits + 1) - (address & incrementBits);
        if (length < sublength) {
            sublength = length;
        }
        
        for (NSUInteger i = 0; i < 3; ++i) {
            blockError = nil;
            if (block(address, offset, sublength, &blockError)) {
                break;
            }
            if (i == 2) {
                break;
            }
            if (![self recoverFromDebugPortError:&blockError]) {
                break;
            }
        }
        
        address += sublength;
        length -= sublength;
        offset += sublength;
    }
    if (error != nil) {
        *error = blockError;
    }
    return blockError == nil;
}

- (BOOL)writeMemory:(UInt32)address data:(NSData *)data error:(NSError **)error
{
    if (self.minimalDebugPort) {
        uint32_t wordAddress = address;
        uint32_t endAddress = address + (uint32_t)data.length;
        uint8_t *bytes = (uint8_t *)data.bytes;
        NSUInteger index = 0;
        while (wordAddress < endAddress) {
            uint32_t value = bytes[index] | (bytes[index + 1] << 8) | (bytes[index + 2] << 16) | (bytes[index + 3] << 24);
            if (![self writeMemory:wordAddress value:value error:error]) {
                return NO;
            }
            wordAddress += 4;
            index += 4;
        }
        return YES;
    } else {
        BOOL (^block)(UInt32, UInt32, UInt32, NSError **) = ^(UInt32 subaddress, UInt32 offset, UInt32 sublength, NSError **error) {
            return [self writeMemoryTransfer:subaddress data:[data subdataWithRange:NSMakeRange(offset, sublength)] error:error];
        };
        return [self paginate:_tarIncrementBits address:address length:(UInt32)data.length block:block error:error];
    }
}

- (NSData *)readMemory:(UInt32)address length:(UInt32)length error:(NSError **)error
{
    uint32_t readAddress = address & ~0x03;
    uint32_t readLength = length + (address & 0x03);
    readLength += (4 - (readLength & 0x3)) & 0x03;
    NSMutableData *data = [NSMutableData dataWithCapacity:readLength];
    if (self.minimalDebugPort) {
        uint32_t wordAddress = readAddress;
        uint32_t endAddress = readAddress + readLength;
        while (wordAddress < endAddress) {
            uint32_t value;
            if (![self readMemory:wordAddress value:&value error:error]) {
                return nil;
            }
            uint8_t bytes[4] = {value, value >> 8, value >> 16, value >> 24};
            [data appendBytes:bytes length:4];
            wordAddress += 4;
        }
    } else {
        BOOL (^block)(UInt32, UInt32, UInt32, NSError **) = ^(UInt32 subaddress, UInt32 offset, UInt32 sublength, NSError **error) {
            NSData *subdata = [self readMemoryTransfer:subaddress length:sublength error:error];
            if (subdata == nil) {
                return NO;
            }
            [data appendData:subdata];
            return YES;
        };
        if (![self paginate:_tarIncrementBits address:readAddress length:readLength block:block error:error]) {
            return nil;
        }
    }
    return [data subdataWithRange:NSMakeRange(address - readAddress, length)];
}

- (BOOL)readMemoryUInt8:(UInt32)address value:(UInt8 *)value error:(NSError **)error
{
    UInt32 word;
    if (![self readMemory:address & ~0x3 value:&word error:error]) {
        return NO;
    }
    *value = (word >> ((address & 0x3) * 8)) & 0xff;
    return YES;
}

- (BOOL)readMemoryUInt16:(UInt32)address value:(UInt16 *)value error:(NSError **)error
{
    UInt32 word;
    if (![self readMemory:address & ~0x3 value:&word error:error]) {
        return NO;
    }
    *value = (word >> ((address & 0x2) * 8)) & 0xffff;
    return YES;
}

#define MSC 0x400c0000

#define MSC_WRITECTRL (MSC + 0x008)
#define MSC_WRITECMD  (MSC + 0x00c)
#define MSC_ADDRB     (MSC + 0x010)
#define MSC_WDATA     (MSC + 0x018)
#define MSC_STATUS    (MSC + 0x01c)
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

#define MSC_STATUS_BUSY       BIT(0)
#define MSC_STATUS_LOCKED     BIT(1)
#define MSC_STATUS_INVADDR    BIT(2)
#define MSC_STATUS_WDATAREADY BIT(3)

#define MSC_MASSLOCK_UNLOCK 0x631a

- (BOOL)memorySystemControllerStatusWait:(UInt32)mask value:(UInt32)value error:(NSError **)error
{
    NSTimeInterval timeout = 0.250;
    NSDate *start = [NSDate date];
    NSDate *now;
    do {
        UInt32 status;
        if (![self readMemory:MSC_STATUS value:&status error:error]) {
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
    if (![self writeMemory:MSC_WRITECTRL value:MSC_WRITECTRL_WREN error:error]) {
        return NO;
    }
    if (![self writeMemory:MSC_ADDRB value:address error:error]) {
        return NO;
    }
    if (![self writeMemory:MSC_WRITECMD value:MSC_WRITECMD_LADDRIM error:error]) {
        return NO;
    }
    UInt32 status;
    if (![self readMemory:MSC_STATUS value:&status error:error]) {
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
        if (![self writeMemory:MSC_WRITECMD value:MSC_WRITECMD_ERASEPAGE error:error]) {
            return NO;
        }
        return [self memorySystemControllerStatusWait:MSC_STATUS_BUSY value:MSC_STATUS_BUSY error:error];
    };
    return [self recoverAndRetry:block error:error];
}

- (BOOL)massErase:(NSError **)error
{
    BOOL (^block)(NSError **) = ^(NSError **error) {
        if (![self writeMemory:MSC_WRITECTRL value:MSC_WRITECTRL_WREN error:error]) {
            return NO;
        }
        if (![self writeMemory:MSC_MASSLOCK value:MSC_MASSLOCK_UNLOCK error:error]) {
            return NO;
        }
        if (![self writeMemory:MSC_WRITECMD value:MSC_WRITECMD_ERASEMAIN0 error:error]) {
            return NO;
        }
        return [self memorySystemControllerStatusWait:MSC_STATUS_BUSY value:MSC_STATUS_BUSY error:error];
    };
    return [self recoverAndRetry:block error:error];
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

    BOOL fast = NO;
    if (fast) {
        if (![self accessPortBankSelect:SWD_DP_SELECT_APSEL_APB_AP registerOffset:0x00 error:error]) {
            return NO;
        }
        if (![self setOverrunDetection:true error:error]) {
            return NO;
        }
    }
    
    UInt8 apTarRequest = [self encodeRequestPort:SWDAccessPort direction:SWDWriteDirection address:SWD_AP_TAR];
    UInt8 apDrwRequest = [self encodeRequestPort:SWDAccessPort direction:SWDWriteDirection address:SWD_AP_DRW];
    UInt8 *bytes = (UInt8 *)data.bytes;
    for (NSUInteger i = 0; i < length; i += 4) {
        UInt32 value = unpackLittleEndianUInt32(&bytes[i]);
        if (fast) {
// We don't need the two way status waits, because going over USB via FTDI, etc
// is slower than the operations take. -denis
            [self requestWriteSkip:apTarRequest value:MSC_WDATA];
            [self requestWriteSkip:apDrwRequest value:value];
            [self requestWriteSkip:apTarRequest value:MSC_WRITECMD];
            [self requestWriteSkip:apDrwRequest value:MSC_WRITECMD_WRITETRIG];
        } else {
            if (![self loadAddress:(uint32_t)(address + i) error:error]) {
                return NO;
            }
            if (![self memorySystemControllerStatusWait:MSC_STATUS_WDATAREADY value:0 error:error]) {
                return NO;
            }
            if (![self writeMemory:MSC_WDATA value:value error:error]) {
                return NO;
            }
            if (![self writeMemory:MSC_WRITECMD value:MSC_WRITECMD_WRITEONCE error:error]) {
                return NO;
            }
            return [self memorySystemControllerStatusWait:MSC_STATUS_BUSY value:MSC_STATUS_BUSY error:error];
        }
    }
    
    if (fast) {
        [self flush];
        if (![self afterMemoryTransfer:error]) {
            return NO;
        }
    }
    return YES;
}

- (BOOL)flash:(UInt32)address data:(NSData *)data error:(NSError **)error
{
    BOOL (^block)(UInt32, UInt32, UInt32, NSError **) = ^(UInt32 subaddress, UInt32 offset, UInt32 sublength, NSError **error) {
        return [self flashTransfer:subaddress data:[data subdataWithRange:NSMakeRange(offset, sublength)] error:error];
    };
    return [self paginate:0x7ff address:address length:(UInt32)data.length block:block error:error];
}

#define FP_CTRL 0xE0002000
#define FP_REMAP 0xE0002004
#define FP_COMP0 0xE0002008
#define FP_COMP1 0xE000200C
#define FP_COMP2 0xE0002010
#define FP_COMP3 0xE0002014
#define FP_COMP4 0xE0002018
#define FP_COMP5 0xE000201C
#define FP_COMP6 0xE0002020
#define FP_COMP7 0xE0002024
#define PID4 0xE0002FD0
#define PID5 0xE0002FD4
#define PID6 0xE0002FD8
#define PID7 0xE0002FDC
#define PID0 0xE0002FE0
#define PID1 0xE0002FE4
#define PID2 0xE0002FE8
#define PID3 0xE0002FEC
#define CID0 0xE0002FF0
#define CID1 0xE0002FF4
#define CID2 0xE0002FF8
#define CID3 0xE0002FFC

#define FP_CTRL_KEY    BIT(1)
#define FP_CTRL_ENABLE BIT(0)

#define FP_COMP_REPLACE_U 0x80000000
#define FP_COMP_REPLACE_L 0x40000000
#define FP_COMP_ADDRESS 0x1ffffffc
#define FP_COMP_ENABLE BIT(0)

- (BOOL)breakpointCount:(UInt32 *)numCode error:(NSError **)error
{
    uint32_t value;
    if (![self readMemory:FP_CTRL value:&value error:error]) {
        return NO;
    }
    *numCode = ((value >> 8) & 0x70) | ((value >> 4) & 0xf);
    return YES;
}

- (BOOL)enableBreakpoints:(BOOL)enable error:(NSError **)error
{
    return [self writeMemory:FP_CTRL value:FP_CTRL_KEY | (enable ? FP_CTRL_ENABLE : 0) error:error];
}

- (BOOL)getBreakpoint:(uint32_t)n address:(UInt32 *)address enabled:(BOOL *)enabled error:(NSError **)error
{
    uint32_t value;
    if (![self readMemory:FP_COMP0 + n * 4 value:&value error:error]) {
        return NO;
    }
    if (value & FP_COMP_ENABLE) {
        *address = (value & FP_COMP_ADDRESS) | ((value & FP_COMP_REPLACE_U) ? 0x2 : 0x0);
        *enabled = true;
    } else {
        *enabled = false;
    }
    return YES;
}

- (BOOL)setBreakpoint:(uint32_t)n address:(uint32_t)address error:(NSError **)error
{
    uint32_t value = ((address & 0x2) ? FP_COMP_REPLACE_U : FP_COMP_REPLACE_L) | (address & ~0x3) | FP_COMP_ENABLE;
    return [self writeMemory:FP_COMP0 + n * 4 value:value error:error];
}

- (BOOL)disableBreakpoint:(uint32_t)n error:(NSError **)error
{
    return [self writeMemory:FP_COMP0 + n * 4 value:0 error:error];
}

- (BOOL)disableAllBreakpoints:(NSError **)error
{
    uint32_t count;
    if (![self breakpointCount:&count error:error]) {
        return NO;
    }
    for (uint32_t i = 0; i < count; ++i) {
        if (![self disableBreakpoint:i error:error]) {
            return NO;
        }
    }
    return YES;
}

#define SCB 0xE000ED00

#define SCB_ICSR (SCB + 0x004)
#define SCB_ICSR_PENDSTCLR 0x04000000
#define SCB_ICSR_PENDSVCLR 0x08000000

#define SCB_VTOR (SCB + 0x008)

#define SCB_AIRCR (SCB + 0x00C)
#define SCB_AIRCR_VECTKEY     0x05FA0000
#define SCB_AIRCR_VECTRESET   0x00000001
#define SCB_AIRCR_SYSRESETREQ 0x05FA0004

#define DEMCR 0xE000EDFC
#define DEMCR_DWTENA       0x01000000
#define DEMCR_VC_HARDERR   0x00000400
#define DEMCR_VC_CORERESET 0x00000001

- (BOOL)reset:(NSError **)error
{
    if (![self halt:error]) {
        return NO;
    }
    if (![self writeMemory:DEMCR value:DEMCR_DWTENA | DEMCR_VC_HARDERR | DEMCR_VC_CORERESET error:error]) {
        return NO;
    }
    if (![self writeMemory:SCB_ICSR value:SCB_ICSR_PENDSTCLR | SCB_ICSR_PENDSVCLR error:error]) {
        return NO;
    }
    if (![self writeMemory:SCB_AIRCR value:SCB_AIRCR_VECTKEY | SCB_AIRCR_SYSRESETREQ error:error]) {
        return NO;
    }
    if (![self halt:error]) {
        return NO;
    }
    return YES;
}

- (BOOL)setVectorTable:(uint32_t)address error:(NSError **)error
{
    return [self writeMemory:SCB_VTOR value:address error:error];
}

- (BOOL)readCPUID:(UInt32 *)value error:(NSError **)error
{
    return [self readMemory:SWD_MEMORY_CPUID value:value error:error];
}

- (BOOL)writeDHCSR:(uint32_t)value error:(NSError **)error
{
    value |= SWD_DHCSR_DBGKEY | SWD_DHCSR_CTRL_DEBUGEN;
    if (_maskInterrupts) {
        value |= SWD_DHCSR_CTRL_MASKINTS;
    }
    return [self writeMemory:SWD_MEMORY_DHCSR value:value error:error];
}

- (BOOL)halt:(NSError **)error
{
    return [self writeMemory:SWD_MEMORY_DHCSR value:SWD_DHCSR_DBGKEY | SWD_DHCSR_CTRL_DEBUGEN |
            SWD_DHCSR_CTRL_HALT error:error];
}

- (BOOL)step:(NSError **)error
{
    return [self writeDHCSR:SWD_DHCSR_CTRL_STEP error:error];
}

- (BOOL)run:(NSError **)error
{
    return [self writeDHCSR:0 error:error];
}

- (BOOL)isHalted:(BOOL *)halted error:(NSError **)error
{
    UInt32 dhcsr;
    if (![self readMemory:SWD_MEMORY_DHCSR value:&dhcsr error:error]) {
        return NO;
    }
    *halted = dhcsr & SWD_DHCSR_STAT_HALT ? YES : NO;
    return YES;
}

- (BOOL)waitForHalt:(NSTimeInterval)timeout error:(NSError **)error
{
    NSDate *start = [NSDate date];
    NSDate *now;
    do {
        BOOL halted;
        if (![self isHalted:&halted error:error]) {
            return NO;
        }
        if (halted) {
            return YES;
        }
        
        [NSThread sleepForTimeInterval:0.1];
        now = [NSDate date];
    } while ([now timeIntervalSinceDate:start] < timeout);
    return FDErrorReturn(error, @{@"reason": @"timeout"});
}

- (BOOL)waitForRegisterReady:(NSError **)error
{
    for (NSUInteger retry = 0; retry < _registerRetryCount; ++retry) {
        UInt32 dhscr;
        if (![self readMemory:SWD_MEMORY_DHCSR value:&dhscr error:error]) {
            return NO;
        }
        if (dhscr & SWD_DHCSR_STAT_REGRDY) {
            return YES;
        }
    }
    return FDErrorReturn(error, @{@"reason": @"not ready"});
}

- (BOOL)readRegister:(UInt16)registerID value:(UInt32 *)value error:(NSError **)error
{
//    NSLog(@"read register %04x", registerID);
    if (![self writeMemory:SWD_MEMORY_DCRSR value:registerID error:error]) {
        return NO;
    }
    if (![self waitForRegisterReady:error]) {
        return NO;
    }
    if (![self readMemory:SWD_MEMORY_DCRDR value:value error:error]) {
        return NO;
    }
//    NSLog(@"read register %04x = %08x", registerID, value);
    return YES;
}

- (BOOL)writeRegister:(UInt16)registerID value:(UInt32)value error:(NSError **)error
{
//    NSLog(@"write register %04x = %08x", registerID, value);
    if (![self writeMemory:SWD_MEMORY_DCRDR value:value error:error]) {
        return NO;
    }
    if (![self writeMemory:SWD_MEMORY_DCRSR value:0x00010000 | registerID error:error]) {
        return NO;
    }
    if (![self waitForRegisterReady:error]) {
        return NO;
    }
//    NSLog(@"write register %04x = %08x done", registerID, value);
    return YES;
}

- (BOOL)readAccessPortID:(UInt8)accessPort value:(UInt32 *)value error:(NSError **)error
{
    return [self readAccessPort:accessPort registerOffset:SWD_AP_IDR value:value error:error];
}

- (BOOL)initializeDebugPort:(NSError **)error
{
    UInt32 dummy;
    if (![self readDebugPort:SWD_DP_STAT value:&dummy error:error]) {
        return NO;
    }
    
    if (![self writeDebugPort:SWD_DP_ABORT
                        value:SWD_DP_ABORT_ORUNERRCLR |
                              SWD_DP_ABORT_WDERRCLR |
                              SWD_DP_ABORT_STKERRCLR |
                              SWD_DP_ABORT_STKCMPCLR
                        error:error]
    ) {
        return NO;
    }

    if (![self readDebugPort:SWD_DP_STAT value:&dummy error:error]) {
        return NO;
    }

    if (![self writeDebugPort:SWD_DP_CTRL value:SWD_DP_CTRL_CDBGPWRUPREQ | SWD_DP_CTRL_CSYSPWRUPREQ error:error]) {
        return NO;
    }
    
    if (![self waitForDebugPortStatus:SWD_DP_CTRL_CSYSPWRUPACK error:error]) {
        return NO;
    }
    if (![self waitForDebugPortStatus:SWD_DP_CTRL_CDBGPWRUPACK error:error]) {
        return NO;
    }
    
    if (![self writeDebugPort:SWD_DP_SELECT value:0 error:error]) {
        return NO;
    }

    if (![self readDebugPort:SWD_DP_STAT value:&dummy error:error]) {
        return NO;
    }
    
    // cache values needed for various higher level routines (such as reading and writing to memory in bulk)
    if (![self readDebugPortIDCode:&_dpid error:error]) {
        return NO;
    }
    if (![self readAccessPortID:SWD_DP_SELECT_APSEL_APB_AP value:&_apid error:error]) {
        return NO;
    }

    return YES;
}

#define IDR_CODE(id) (((id) >> 17) & 0x7ff)

#define NRF52_AP_REG_RESET 0x00
#define NRF52_AP_REG_ERASEALL 0x04
#define NRF52_AP_REG_ERASEALLSTATUS 0x08
#define NRF52_AP_REG_APPROTECTSTATUS 0x0c
#define NRF52_AP_REG_IDR 0xfc

#define NRF52_CTRL_AP_ID 0x02880000

#define SWD_NRF52_CTRL_AP_ERASE_TIMEOUT 10.0


- (BOOL)isAuthenticationAccessPortActive:(BOOL *)active error:(NSError **)error
{
    uint32_t dpid;
    if (![self readDebugPort:0 value:&dpid error:error]) {
        return NO;
    }
    if ((dpid != SWD_DPID_CM4) && (dpid != SWD_DPID_CM3) && (dpid != SWD_DPID_CM0DAP1) && (dpid != SWD_DPID_CM0DAP2)){
        NSString *reason = [NSString stringWithFormat:@"DPID 0x%08x not recognized", dpid];
        return FDErrorReturn(error, @{@"reason": reason});
    }

    // EFM32G
    uint32_t apid;
    if (![self readAccessPortID:SWD_DP_SELECT_APSEL_APB_AP value:&apid error:error]) {
        return NO;
    }
    *active = IDR_CODE(apid) == IDR_CODE(SWD_AAP_ID);

    // NRF52
    if (![self readAccessPort:SWD_DP_SELECT_APSEL_NRF52_CTRL_AP registerOffset:NRF52_AP_REG_IDR value:&apid error:error]) {
        return NO;
    }
    if (IDR_CODE(apid) == IDR_CODE(NRF52_CTRL_AP_ID)) {
        UInt32 value;
        if (![self readAccessPort:SWD_DP_SELECT_APSEL_NRF52_CTRL_AP registerOffset:NRF52_AP_REG_APPROTECTSTATUS value:&value error:error]) {
            return NO;
        }
        *active = (value & 0x00000001) == 0;
    }

    return YES;
}

#define SWD_AAP_ERASE_TIMEOUT 0.200 // erase takes 125 ms

- (BOOL)authenticationAccessPortEraseEFM32G:(NSError **)error
{
    if (![self writeAccessPort:SWD_DP_SELECT_APSEL_APB_AP registerOffset:SWD_AAP_CMDKEY value:SWD_AAP_CMDKEY_WRITEEN error:error]) {
        return NO;
    }
    if (![self writeAccessPort:SWD_DP_SELECT_APSEL_APB_AP registerOffset:SWD_AAP_CMD value:SWD_AAP_CMD_DEVICEERASE error:error]) {
        return NO;
    }
    NSDate *start = [NSDate date];
    do {
        [NSThread sleepForTimeInterval:0.025];
        uint32_t status;
        if (![self readAccessPort:SWD_DP_SELECT_APSEL_APB_AP registerOffset:SWD_AAP_STATUS value:&status error:error]) {
            return NO;
        }
        if ((status & SWD_AAP_STATUS_ERASEBUSY) == 0) {
            return YES;
        }
    } while ([[NSDate date] timeIntervalSinceDate:start] < SWD_AAP_ERASE_TIMEOUT);
    return FDErrorReturn(error, @{@"reason": @"timeout"});
}

- (BOOL)authenticationAccessPortEraseNRF52:(NSError **)error
{
    if (![self writeAccessPort:SWD_DP_SELECT_APSEL_NRF52_CTRL_AP registerOffset:NRF52_AP_REG_ERASEALL value:0x00000001 error:error]) { // erase all
        return NO;
    }
    UInt32 value;
    NSDate *start = [NSDate date];
    do {
        [NSThread sleepForTimeInterval:0.025];
        if (![self readAccessPort:SWD_DP_SELECT_APSEL_NRF52_CTRL_AP registerOffset:NRF52_AP_REG_ERASEALLSTATUS value:&value error:error]) {
            return NO;
        }
        if ([[NSDate date] timeIntervalSinceDate:start] > SWD_NRF52_CTRL_AP_ERASE_TIMEOUT) {
            return FDErrorReturn(error, @{@"reason": @"timeout"});
        }
    } while (value != 0);
    if (![self writeAccessPort:SWD_DP_SELECT_APSEL_NRF52_CTRL_AP registerOffset:NRF52_AP_REG_ERASEALL value:0x00000000 error:error]) { // erase all off
        return NO;
    }
    if (![self writeAccessPort:SWD_DP_SELECT_APSEL_NRF52_CTRL_AP registerOffset:NRF52_AP_REG_RESET value:0x00000001 error:error]) { // reset
        return NO;
    }
    if (![self writeAccessPort:SWD_DP_SELECT_APSEL_NRF52_CTRL_AP registerOffset:NRF52_AP_REG_RESET value:0x00000000 error:error]) { // reset off
        return NO;
    }

    return YES;
}

- (BOOL)authenticationAccessPortErase:(NSError **)error
{
    return [self authenticationAccessPortEraseNRF52:error];
}

- (BOOL)authenticationAccessPortResetEFM32G:(NSError **)error
{
    return [self writeAccessPort:SWD_DP_SELECT_APSEL_APB_AP registerOffset:SWD_AAP_CMD value:SWD_AAP_CMD_SYSRESETREQ error:error];
}

- (BOOL)authenticationAccessPortResetNRF52:(NSError **)error
{
    if (![self writeAccessPort:SWD_DP_SELECT_APSEL_NRF52_CTRL_AP registerOffset:NRF52_AP_REG_RESET value:0x00000001 error:error]) { // reset
        return NO;
    }
    if (![self writeAccessPort:SWD_DP_SELECT_APSEL_NRF52_CTRL_AP registerOffset:NRF52_AP_REG_RESET value:0x00000000 error:error]) { // reset off
        return NO;
    }
    return YES;
}

- (BOOL)authenticationAccessPortReset:(NSError **)error
{
    return [self authenticationAccessPortResetNRF52:error];
}

- (BOOL)initializeAccessPort:(NSError **)error
{
    if (![self writeAccessPort:SWD_DP_SELECT_APSEL_APB_AP
                registerOffset:SWD_AP_CSW
                         value:SWD_AP_CSW_DBGSWENABLE |
                               SWD_AP_CSW_MASTER_DEBUG |
                               SWD_AP_CSW_HPROT |
                               SWD_AP_CSW_INCREMENT_SINGLE |
                               SWD_AP_CSW_32BIT
                         error:error]
    ) {
        return NO;
    }
    
    return [self checkDebugPortStatus:error];
}

@end
