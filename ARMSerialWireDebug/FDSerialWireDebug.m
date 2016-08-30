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

@interface FDSerialWireDebug ()

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

        _ackWaitRetryCount = 3;
        _debugPortStatusRetryCount = 3;
        _registerRetryCount = 3;
        _recoveryRetryCount = 5;
        
        _tarIncrementBits = 0x3f;
//        _tarIncrementBits = 0x3ff;
    }
    return self;
}

- (void)skip:(NSUInteger)n
{
    [_serialWire shiftOutBits:0 bitCount:n];
}

- (void)turnToWriteAndSkip
{
    [_serialWire turnToWrite];
    [self skip:1];
}

- (void)turnToReadAndSkip
{
    [_serialWire turnToRead];
    [self skip:1];
}

- (void)detachDebugPort
{
    [_serialWire turnToWrite];
    UInt8 bytes[] = {
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
        0xff,
    };
    [_serialWire shiftOutData:[NSData dataWithBytes:bytes length:sizeof(bytes)]];
}

- (void)resetDebugPort
{
    [_serialWire turnToWrite];
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
    [_serialWire shiftOutData:[NSData dataWithBytes:bytes length:sizeof(bytes)]];
}

- (UInt8)getParityUInt8:(UInt8)v {
    return (0x6996 >> ((v ^ (v >> 4)) & 0xf)) & 1;
}

- (UInt8)getParityUInt32:(UInt32)v {
    v ^= v >> 16;
    v ^= v >> 8;
    return [self getParityUInt8:v];
}

- (UInt8)encodeRequestPort:(FDSerialWireDebugPort)port direction:(FDSerialWireDebugDirection)direction address:(UInt8)address
{
    UInt8 request = 0b10000001; // Start (bit 0) & Park (bit 7)
    if (port == FDSerialWireDebugPortAccess) {
        request |= 0b00000010;
    }
    if (direction == FDSerialWireDebugDirectionRead) {
        request |= 0b00000100;
    }
    request |= (address << 1) & 0b00011000;
    if ([self getParityUInt8:request]) {
        request |= 0b00100000;
    }
    return request;
}

typedef NS_ENUM(NSInteger, SWDAck) {
    SWDAckOK = 0b001,
    SWDAckWait = 0b010,
    SWDAckFault = 0b100,
};

- (void)shiftInTurnAndAck
{
    [_serialWire shiftInBits:4];
}

- (SWDAck)getTurnAndAck:(NSData *)data
{
    return ((UInt8 *)data.bytes)[0] >> 5;
}

- (BOOL)request:(UInt8)request ack:(SWDAck *)ack error:(NSError **)error
{
    [_serialWire shiftOutBits:request bitCount:8];
    [_serialWire turnToRead];
    [self shiftInTurnAndAck];
    NSData *data = [_serialWire readWithByteCount:1 error:error];
    if (data == nil) {
        return NO;
    }
    *ack = [self getTurnAndAck:data];
    return YES;
}

- (BOOL)readUInt32:(UInt32 *)value error:(NSError **)error
{
    [_serialWire shiftInData:4];
    [_serialWire shiftInBits:1]; // parity
    NSData *data = [_serialWire readWithByteCount:5 error:error];
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
    [_serialWire shiftOutData:[NSData dataWithBytes:bytes length:sizeof(bytes)]];
    UInt8 parity = [self getParityUInt32:value];
    [_serialWire shiftOutBits:parity bitCount:1];
}

- (BOOL)readPort:(FDSerialWireDebugPort)port registerOffset:(UInt8)registerOffset value:(UInt32 *)value error:(NSError **)error
{
//    NSLog(@"read  %@ %02x", port == FDSerialWireDebugPortDebug ? @"dp" : @"ap", registerOffset);
    SWDAck ack = SWDAckOK;
    NSError *deepError;
    UInt8 request = [self encodeRequestPort:port direction:FDSerialWireDebugDirectionRead address:registerOffset];
    for (NSUInteger retry = 0; retry < _ackWaitRetryCount; ++retry) {
        if (![self request:request ack:&ack error:&deepError]) {
            continue;
        }
        if (_overrunDetectionEnabled) {
            if (![self readUInt32:value error:&deepError]) {
                continue;
            }
            [self turnToWriteAndSkip];
        }
        if (ack == SWDAckOK) {
            if (!_overrunDetectionEnabled) {
                if (![self readUInt32:value error:&deepError]) {
                    continue;
                }
                [self turnToWriteAndSkip];
            }
//            NSLog(@"read  %@ %02x = %08x", port == FDSerialWireDebugPortDebug ? @"dp" : @"ap", registerOffset, value);
            return YES;
        }
        if (!_overrunDetectionEnabled) {
            [self turnToWriteAndSkip];
        }
        if (ack != SWDAckWait) {
            NSString *reason = [NSString stringWithFormat:@"unexpected ack %ld", (long)ack];
            return FDErrorReturn(error, @{@"reason": reason});
        }
    }
    if (ack == SWDAckWait) {
        return FDErrorReturn(error, @{@"reason": @"too many ack wait retries"});
    }
    if (error != nil) {
        *error = deepError;
    }
    return NO;
}

- (BOOL)writePort:(FDSerialWireDebugPort)port registerOffset:(UInt8)registerOffset value:(UInt32)value error:(NSError **)error
{
//    NSLog(@"write %@ %02x = %08x", port == FDSerialWireDebugPortDebug ? @"dp" : @"ap", registerOffset, value);
    SWDAck ack = SWDAckOK;
    NSError *deepError;
    UInt8 request = [self encodeRequestPort:port direction:FDSerialWireDebugDirectionWrite address:registerOffset];
    for (NSUInteger retry = 0; retry < _ackWaitRetryCount; ++retry) {
        if (![self request:request ack:&ack error:&deepError]) {
            continue;
        }
        [self turnToWriteAndSkip];
        if (_overrunDetectionEnabled) {
            [self writeUInt32:value];
        }
        if (ack == SWDAckOK) {
            if (!_overrunDetectionEnabled) {
                [self writeUInt32:value];
            }
//            NSLog(@"write %@ %02x = %08x done", port == FDSerialWireDebugPortDebug ? @"dp" : @"ap", registerOffset, value);
            return YES;
        }
        if (ack != SWDAckWait) {
            NSString *reason = [NSString stringWithFormat:@"unexpected ack %ld writing to port %ld, register offset %d, value 0x%08x", (long)ack, (long)port, registerOffset, value];
            return FDErrorReturn(error, @{@"reason": reason});
        }
    }
    if (ack == SWDAckWait) {
        return FDErrorReturn(error, @{@"reason": @"too many ack wait retries"});
    }
    if (error != nil) {
        *error = deepError;
    }
    return NO;
}

- (BOOL)readDebugPort:(UInt8)registerOffset value:(UInt32 *)value error:(NSError **)error
{
    return [self readPort:FDSerialWireDebugPortDebug registerOffset:registerOffset value:value error:error];
}

- (BOOL)writeDebugPort:(UInt8)registerOffset value:(UInt32)value error:(NSError **)error
{
    return [self writePort:FDSerialWireDebugPortDebug registerOffset:registerOffset value:value error:error];
}

- (BOOL)readDebugPortIDCode:(UInt32 *)value error:(NSError **)error
{
    return [self readDebugPort:SWD_DP_IDCODE value:value error:error];
}

- (BOOL)readTargetID:(UInt32 *)value error:(NSError **)error
{
    if (![self writePort:FDSerialWireDebugPortDebug registerOffset:SWD_DP_SELECT value:0x02 error:error]) {
        return NO;
    }
    return [self readDebugPort:0x04 value:value error:error];
}

- (BOOL)waitForDebugPortStatus:(UInt32)mask error:(NSError **)error
{
    for (NSUInteger retry = 0; retry < _debugPortStatusRetryCount; ++retry) {
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
    return [self writePort:FDSerialWireDebugPortDebug registerOffset:SWD_DP_SELECT value:value error:error];
}

- (BOOL)readAccessPort:(UInt8)accessPort registerOffset:(UInt8)registerOffset value:(UInt32 *)value error:(NSError **)error
{
//    NSLog(@"read access port %02x", registerOffset);
    if (![self accessPortBankSelect:accessPort registerOffset:registerOffset error:error]) {
        return NO;
    }
    UInt32 dummy;
    if (![self readPort:FDSerialWireDebugPortAccess registerOffset:registerOffset value:&dummy error:error]) {
        return NO;
    }
    if (![self readPort:FDSerialWireDebugPortDebug registerOffset:SWD_DP_RDBUFF value:value error:error]) {
        return NO;
    }
//    NSLog(@"read access port %02x = %08x", registerOffset, value);
    return YES;
}

- (void)flush
{
    [_serialWire shiftOutBits:0x00 bitCount:8];
}

- (BOOL)writeAccessPort:(UInt8)accessPort registerOffset:(UInt8)registerOffset value:(UInt32)value error:(NSError **)error
{
//    NSLog(@"write access port %02x = %08x", registerOffset, value);
    if (![self accessPortBankSelect:accessPort registerOffset:registerOffset error:error]) {
        return NO;
    }
    if (![self writePort:FDSerialWireDebugPortAccess registerOffset:registerOffset value:value error:error]) {
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
    [_serialWire shiftOutBits:request bitCount:8];
    [_serialWire turnToRead];
    [self skip:4]; // skip over turn and ack
    [self turnToWriteAndSkip];
    [self writeUInt32:value];
}

- (BOOL)writeMemoryTransfer:(UInt32)address data:(NSData *)data error:(NSError **)error
{
    if ([_serialWire conformsToProtocol:@protocol(FDSerialWireDebugTransfer)]) {
        id<FDSerialWireDebugTransfer> transfer = (id<FDSerialWireDebugTransfer>)_serialWire;
        return [transfer writeMemory:address data:data error:error];
    }

    if (![self beforeMemoryTransfer:address length:data.length error:error]) {
        return NO;
    }
    
    uint8_t request = [self encodeRequestPort:FDSerialWireDebugPortAccess direction:FDSerialWireDebugDirectionWrite address:SWD_AP_DRW];
    uint8_t *bytes = (uint8_t *)data.bytes;
    NSUInteger length = data.length;
    for (NSUInteger i = 0; i < length; i += 4) {
        [self requestWriteSkip:request value:unpackLittleEndianUInt32(&bytes[i])];
    }
    
    return [self afterMemoryTransfer:error];
}

- (NSData *)readMemoryTransfer:(UInt32)address length:(UInt32)length error:(NSError **)error
{
    if ([_serialWire conformsToProtocol:@protocol(FDSerialWireDebugTransfer)]) {
        id<FDSerialWireDebugTransfer> transfer = (id<FDSerialWireDebugTransfer>)_serialWire;
        return [transfer readMemory:address length:length error:error];
    }

    if (![self beforeMemoryTransfer:address length:length error:error]) {
        return nil;
    }
    
    NSMutableData *data = [NSMutableData dataWithCapacity:length];

    uint8_t request = [self encodeRequestPort:FDSerialWireDebugPortAccess direction:FDSerialWireDebugDirectionRead address:SWD_AP_DRW];
    uint32_t words = length / 4;
    // note: 1 extra iteration because of 1 read delay in getting data out
    for (NSUInteger i = 0; i <= words; ++i) {
        [_serialWire shiftOutBits:request bitCount:8];
        [_serialWire turnToRead];
        [self skip:4]; // skip over turn and ack
        [_serialWire shiftInData:4]; // data
        [_serialWire shiftInBits:1]; // parity
        [self turnToWriteAndSkip];
    }
    
    NSData *output = [_serialWire readWithByteCount:5 * (words + 1) error:error];
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
            if (![_serialWire read:error]) {
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

#define FP_CTRL_KEY    FDSerialWireDebugBit(1)
#define FP_CTRL_ENABLE FDSerialWireDebugBit(0)

#define FP_COMP_REPLACE_U 0x80000000
#define FP_COMP_REPLACE_L 0x40000000
#define FP_COMP_ADDRESS 0x1ffffffc
#define FP_COMP_ENABLE FDSerialWireDebugBit(0)

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
    UInt32 stat;
    if (![self readDebugPort:SWD_DP_STAT value:&stat error:error]) {
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

    if (![self readDebugPort:SWD_DP_STAT value:&stat error:error]) {
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

    if (![self readDebugPort:SWD_DP_STAT value:&stat error:error]) {
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

+ (NSString *)debugPortIDCodeDescription:(uint32_t)debugPortIDCode
{
    return [NSString stringWithFormat:@"IDCODE %08x", debugPortIDCode];
}

+ (NSString *)cpuIDDescription:(uint32_t)cpuID
{
    unsigned implementer = (cpuID >> 24) & 0xff;
    unsigned partno = (cpuID >> 4) & 0xfff;
    NSString *implementerName = @"unknown";
    switch (implementer) {
        case 0x41: implementerName = @"ARM"; break;
    }
    NSString *partnoName = @"";
    switch (partno) {
        case 0xC20: partnoName = @"Cortex-M0"; break;
        case 0xC60: partnoName = @"Cortex-M0+"; break;
        case 0xC21: partnoName = @"Cortex-M1"; break;
        case 0xC23: partnoName = @"Cortex-M3"; break;
        case 0xC24: partnoName = @"Cortex-M4"; break;
    }
    if ((cpuID & 0xfffffff0) == 0x410fc240) {
        uint32_t n = cpuID & 0x0000000f;
        return [NSString stringWithFormat:@"ARM Cortex-M4 r2p%d", n];
    }
    if ((cpuID & 0xfffffff0) == 0x412fc230) {
        uint32_t n = cpuID & 0x0000000f;
        return [NSString stringWithFormat:@"ARM Cortex-M3 r2p%d", n];
    }
    if ((cpuID & 0xfffffff0) == 0x410cc200) {
        uint32_t n = cpuID & 0x0000000f;
        return [NSString stringWithFormat:@"ARM Cortex-M0 r0p%d", n];
    }
    return [NSString stringWithFormat:@"CPUID = %08x", cpuID];
}

@end
