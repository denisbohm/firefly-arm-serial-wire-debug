//
//  FDExecutable.h
//  ARMSerialWireDebug
//
//  Created by Denis Bohm on 4/26/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FDExecutableSymbol : NSObject

@property (nonnull) NSString *name;
@property uint32_t address;

@end

@interface FDExecutableFunction : FDExecutableSymbol

@end

typedef NS_ENUM(NSInteger, FDExecutableSectionType) {
    FDExecutableSectionTypeProgram, FDExecutableSectionTypeData
};

@interface FDExecutableSection : NSObject

@property FDExecutableSectionType type;
@property uint32_t address;
@property (nonnull) NSData *data;

@end

@interface FDExecutable : NSObject

@property (nonnull) NSArray<FDExecutableSection *> *sections;
@property (nonnull) NSMutableDictionary<NSString *, FDExecutableFunction *> *functions;
@property (nonnull) NSMutableDictionary<NSString *, FDExecutableSymbol *> *globals;

- (BOOL)load:(nonnull NSString *)filename error:(NSError * _Nullable * _Nullable)error;

// combine sections withing the given address range into sections that
// start and stop on page boundaries
- (nonnull NSArray<FDExecutableSection *> *)combineSectionsType:(FDExecutableSectionType)type
                                                        address:(uint32_t)address
                                                         length:(uint32_t)length
                                                       pageSize:(uint32_t)pageSize;

- (nonnull NSArray<FDExecutableSection *> *)combineAllSectionsType:(FDExecutableSectionType)type
                                                           address:(uint32_t)address
                                                            length:(uint32_t)length
                                                          pageSize:(uint32_t)pageSize;

@end
