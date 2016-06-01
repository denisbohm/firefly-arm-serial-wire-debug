//
//  FDFireflyFlash.h
//  ARMSerialWireDebug
//
//  Created by Denis Bohm on 7/22/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDExecutable.h"

#import <ARMSerialWireDebug/FDCortexM.h>
#import <ARMSerialWireDebug/FDLogger.h>
#import <ARMSerialWireDebug/FDSerialWireDebug.h>

@interface FDFireflyFlash : NSObject

+ (nullable FDFireflyFlash *)fireflyFlash:(nonnull NSString *)processor error:(NSError * _Nullable * _Nullable)error;

@property (nullable) FDCortexM *cortexM;
@property (nullable) FDSerialWireDebug *serialWireDebug;
@property (nonnull) FDLogger *logger;

@property (nonnull) NSString *processor;
@property (nullable) NSString *directory;

@property uint32_t pageSize;
@property uint32_t ramAddress;
@property uint32_t ramSize;

@property uint32_t pagesPerWrite;

- (BOOL)initialize:(nonnull FDSerialWireDebug *)serialWireDebug error:(NSError * _Nullable * _Nullable)error;

- (BOOL)disableWatchdogByErasingIfNeeded:(nonnull BOOL *)erassed error:(NSError * _Nullable * _Nullable)error;

- (BOOL)massErase:(NSError * _Nullable * _Nullable)error;
- (BOOL)reset:(NSError * _Nullable * _Nullable)error;

- (BOOL)writePages:(uint32_t)address data:(nonnull NSData *)data error:(NSError * _Nullable * _Nullable)error;
- (BOOL)writePages:(uint32_t)address data:(nonnull NSData *)data erase:(BOOL)erase error:(NSError * _Nullable * _Nullable)error;
- (BOOL)program:(nonnull FDExecutable *)executable error:(NSError * _Nullable * _Nullable)error;

- (BOOL)setDebugLock:(NSError * _Nullable * _Nullable)error;
- (BOOL)getDebugLock:(nonnull BOOL *)debugLock error:(NSError * _Nullable * _Nullable)error;

// for use by subclasses
- (BOOL)setupCortexM:(NSError * _Nullable * _Nullable)error;
- (BOOL)loadFireflyFlashFirmwareIntoRAM:(NSError * _Nullable * _Nullable)error;

@end
