//
//  FDSerialWireDebug.h
//  ARMSerialWireDebug
//
//  Created by Denis Bohm on 1/7/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "FDLogger.h"
#import "FDSerialWire.h"

#define FDSerialWireDebugBit(n) (1 << (n))

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

#define SWD_DP_ABORT_ORUNERRCLR FDSerialWireDebugBit(4)
#define SWD_DP_ABORT_WDERRCLR FDSerialWireDebugBit(3)
#define SWD_DP_ABORT_STKERRCLR FDSerialWireDebugBit(2)
#define SWD_DP_ABORT_STKCMPCLR FDSerialWireDebugBit(1)
#define SWD_DP_ABORT_DAPABORT FDSerialWireDebugBit(0)

#define SWD_DP_CTRL_CSYSPWRUPACK FDSerialWireDebugBit(31)
#define SWD_DP_CTRL_CSYSPWRUPREQ FDSerialWireDebugBit(30)
#define SWD_DP_CTRL_CDBGPWRUPACK FDSerialWireDebugBit(29)
#define SWD_DP_CTRL_CDBGPWRUPREQ FDSerialWireDebugBit(28)
#define SWD_DP_CTRL_CDBGRSTACK FDSerialWireDebugBit(27)
#define SWD_DP_CTRL_CDBGRSTREQ FDSerialWireDebugBit(26)
#define SWD_DP_STAT_WDATAERR FDSerialWireDebugBit(7)
#define SWD_DP_STAT_READOK FDSerialWireDebugBit(6)
#define SWD_DP_STAT_STICKYERR FDSerialWireDebugBit(5)
#define SWD_DP_STAT_STICKYCMP FDSerialWireDebugBit(4)
#define SWD_DP_STAT_TRNMODE (FDSerialWireDebugBit(3) | FDSerialWireDebugBit(2))
#define SWD_DP_STAT_STICKYORUN FDSerialWireDebugBit(1)
#define SWD_DP_STAT_ORUNDETECT FDSerialWireDebugBit(0)

#define SWD_DP_SELECT_APSEL_APB_AP 0
#define SWD_DP_SELECT_APSEL_NRF52_CTRL_AP 1

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

#define SWD_IDR_CODE(id) (((id) >> 17) & 0x7ff)

#define SWD_AP_CSW_DBGSWENABLE FDSerialWireDebugBit(31)
#define SWD_AP_CSW_MASTER_DEBUG FDSerialWireDebugBit(29)
#define SWD_AP_CSW_HPROT FDSerialWireDebugBit(25)
#define SWD_AP_CSW_SPIDEN FDSerialWireDebugBit(23)
#define SWD_AP_CSW_TRIN_PROG FDSerialWireDebugBit(7)
#define SWD_AP_CSW_DEVICE_EN FDSerialWireDebugBit(6)
#define SWD_AP_CSW_INCREMENT_PACKED FDSerialWireDebugBit(5)
#define SWD_AP_CSW_INCREMENT_SINGLE FDSerialWireDebugBit(4)
#define SWD_AP_CSW_32BIT FDSerialWireDebugBit(1)
#define SWD_AP_CSW_16BIT FDSerialWireDebugBit(0)

#define SWD_MEMORY_CPUID 0xE000ED00
#define SWD_MEMORY_DFSR  0xE000ED30
#define SWD_MEMORY_DHCSR 0xE000EDF0
#define SWD_MEMORY_DCRSR 0xE000EDF4
#define SWD_MEMORY_DCRDR 0xE000EDF8
#define SWD_MEMORY_DEMCR 0xE000EDFC

#define SWD_DHCSR_DBGKEY 0xA05F0000
#define SWD_DHCSR_STAT_RESET_ST FDSerialWireDebugBit(25)
#define SWD_DHCSR_STAT_RETIRE_ST FDSerialWireDebugBit(24)
#define SWD_DHCSR_STAT_LOCKUP FDSerialWireDebugBit(19)
#define SWD_DHCSR_STAT_SLEEP FDSerialWireDebugBit(18)
#define SWD_DHCSR_STAT_HALT FDSerialWireDebugBit(17)
#define SWD_DHCSR_STAT_REGRDY FDSerialWireDebugBit(16)
#define SWD_DHCSR_CTRL_SNAPSTALL FDSerialWireDebugBit(5)
#define SWD_DHCSR_CTRL_MASKINTS FDSerialWireDebugBit(3)
#define SWD_DHCSR_CTRL_STEP FDSerialWireDebugBit(2)
#define SWD_DHCSR_CTRL_HALT FDSerialWireDebugBit(1)
#define SWD_DHCSR_CTRL_DEBUGEN FDSerialWireDebugBit(0)

typedef NS_ENUM(NSInteger, FDSerialWireDebugPort) {
    FDSerialWireDebugPortDebug,
    FDSerialWireDebugPortAccess,
};

typedef NS_ENUM(NSInteger, FDSerialWireDebugDirection) {
    FDSerialWireDebugDirectionWrite,
    FDSerialWireDebugDirectionRead,
};

typedef NS_ENUM(NSInteger, FDSerialWireDebugTransferType) {
    FDSerialWireDebugTransferTypeReadRegister,
    FDSerialWireDebugTransferTypeWriteRegister,
    FDSerialWireDebugTransferTypeReadMemory,
    FDSerialWireDebugTransferTypeWriteMemory,
};

@interface FDSerialWireDebugTransfer : NSObject

+ (nonnull FDSerialWireDebugTransfer *)readRegister:(uint16_t)registerID;
+ (nonnull FDSerialWireDebugTransfer *)writeRegister:(uint16_t)registerID value:(uint32_t)value;
+ (nonnull FDSerialWireDebugTransfer *)readMemory:(uint32_t)address length:(uint32_t)length;
+ (nonnull FDSerialWireDebugTransfer *)writeMemory:(uint32_t)address data:(nonnull NSData *)data;
+ (nonnull FDSerialWireDebugTransfer *)writeMemory:(uint32_t)address value:(uint32_t)value;

@property FDSerialWireDebugTransferType type;

// register read/write
@property uint16_t registerID;
@property uint32_t value;

// memory read/write
@property uint32_t address;
@property (nullable) NSData *data;
@property uint32_t length;

@end

@protocol FDSerialWireDebugTransport

- (BOOL)writeMemory:(UInt32)address data:(nonnull NSData *)data error:(NSError * _Nullable * _Nullable)error;
- (nullable NSData *)readMemory:(UInt32)address length:(UInt32)length error:(NSError * _Nullable * _Nullable)error;

- (BOOL)transfer:(nonnull NSArray<FDSerialWireDebugTransfer *> *)transfers error:(NSError * _Nullable * _Nullable)error;

@end

@interface FDSerialWireDebug : NSObject <FDSerialWireDebugTransport>

@property (nullable) id<FDSerialWire> serialWire;
@property (nonnull) FDLogger *logger;

@property BOOL maskInterrupts;

@property BOOL minimalDebugPort;

- (void)detachDebugPort;
- (void)resetDebugPort;
- (BOOL)readDebugPort:(UInt8)registerOffset value:(nonnull UInt32 *)value error:(NSError * _Nullable * _Nullable)error;
- (BOOL)writeDebugPort:(UInt8)registerOffset value:(UInt32)value error:(NSError * _Nullable * _Nullable)error;
- (BOOL)readDebugPortIDCode:(nonnull UInt32 *)value error:(NSError * _Nullable * _Nullable)error;
- (BOOL)readTargetID:(nonnull UInt32 *)value error:(NSError * _Nullable * _Nullable)error;
- (BOOL)initializeDebugPort:(NSError * _Nullable * _Nullable)error;

- (BOOL)readAccessPortID:(UInt8)accessPort value:(nonnull UInt32 *)value error:(NSError * _Nullable * _Nullable)error;
- (BOOL)initializeAccessPort:(NSError * _Nullable * _Nullable)error;

- (BOOL)readCPUID:(nonnull UInt32 *)value error:(NSError * _Nullable * _Nullable)error;

- (BOOL)checkDebugPortStatus:(NSError * _Nullable * _Nullable)error;

- (BOOL)readMemory:(UInt32)address value:(nonnull UInt32 *)value error:(NSError * _Nullable * _Nullable)error;
- (BOOL)writeMemory:(UInt32)address value:(UInt32)value error:(NSError * _Nullable * _Nullable)error;

- (BOOL)writeMemory:(UInt32)address data:(nonnull NSData *)data error:(NSError * _Nullable * _Nullable)error;
- (nullable NSData *)readMemory:(UInt32)address length:(UInt32)length error:(NSError * _Nullable * _Nullable)error;

- (BOOL)readMemoryUInt8:(UInt32)address value:(nonnull UInt8 *)value error:(NSError * _Nullable * _Nullable)error;
- (BOOL)readMemoryUInt16:(UInt32)address value:(nonnull UInt16 *)value error:(NSError * _Nullable * _Nullable)error;

- (BOOL)setVectorTable:(uint32_t)address error:(NSError * _Nullable * _Nullable)error;

- (BOOL)accessPortBankSelect:(UInt8)accessPort registerOffset:(UInt8)registerOffset error:(NSError * _Nullable * _Nullable)error;
- (BOOL)readAccessPort:(UInt8)accessPort registerOffset:(UInt8)registerOffset value:(nonnull UInt32 *)value error:(NSError * _Nullable * _Nullable)error;
- (BOOL)writeAccessPort:(UInt8)accessPort registerOffset:(UInt8)registerOffset value:(UInt32)value error:(NSError * _Nullable * _Nullable)error;

- (void)flush;
- (BOOL)recoverAndRetry:(nonnull BOOL (^)(NSError * _Nullable * _Nullable))block error:(NSError * _Nullable * _Nullable)error;

- (BOOL)setOverrunDetection:(BOOL)enabled error:(NSError * _Nullable * _Nullable)error;
- (UInt8)encodeRequestPort:(FDSerialWireDebugPort)port direction:(FDSerialWireDebugDirection)direction address:(UInt8)address;
- (void)requestWriteSkip:(UInt8)request value:(UInt32)value;

- (BOOL)beforeMemoryTransfer:(UInt32)address length:(NSUInteger)length error:(NSError * _Nullable * _Nullable)error;
- (BOOL)afterMemoryTransfer:(NSError * _Nullable * _Nullable)error;
- (BOOL)paginate:(UInt32)incrementBits
         address:(UInt32)address
          length:(UInt32)length
           block:(nonnull BOOL (^)(UInt32 subaddress, UInt32 offset, UInt32 sublength, NSError * _Nullable * _Nullable error))block
           error:(NSError * _Nullable * _Nullable)error;

- (BOOL)reset:(NSError * _Nullable * _Nullable)error;

- (BOOL)readRegister:(UInt16)registerID value:(nonnull UInt32 *)value error:(NSError * _Nullable * _Nullable)error;
- (BOOL)writeRegister:(UInt16)registerID value:(UInt32)value error:(NSError * _Nullable * _Nullable)error;

- (BOOL)halt:(NSError * _Nullable * _Nullable)error;
- (BOOL)step:(NSError * _Nullable * _Nullable)error;
- (BOOL)run:(NSError * _Nullable * _Nullable)error;

- (BOOL)isHalted:(nonnull BOOL *)halted error:(NSError * _Nullable * _Nullable)error;
- (BOOL)waitForHalt:(NSTimeInterval)timeout error:(NSError * _Nullable * _Nullable)error;

- (BOOL)breakpointCount:(nonnull UInt32 *)count error:(NSError * _Nullable * _Nullable)error;
- (BOOL)enableBreakpoints:(BOOL)enable error:(NSError * _Nullable * _Nullable)error;
- (BOOL)getBreakpoint:(uint32_t)n address:(nonnull uint32_t *)address enabled:(nonnull BOOL *)enabled error:(NSError * _Nullable * _Nullable)error;
- (BOOL)setBreakpoint:(uint32_t)n address:(uint32_t)address error:(NSError * _Nullable * _Nullable)error;
- (BOOL)disableBreakpoint:(uint32_t)n error:(NSError * _Nullable * _Nullable)error;
- (BOOL)disableAllBreakpoints:(NSError * _Nullable * _Nullable)error;

- (BOOL)transfer:(nonnull NSArray<FDSerialWireDebugTransfer *> *)transfers error:(NSError * _Nullable * _Nullable)error;

+ (nonnull NSString *)debugPortIDCodeDescription:(uint32_t)debugPortIDCode;
+ (nonnull NSString *)cpuIDDescription:(uint32_t)cpuID;

@end
