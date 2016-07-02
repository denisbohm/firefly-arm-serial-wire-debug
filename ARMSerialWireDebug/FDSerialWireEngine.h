//
//  FDSerialWireEngine.h
//  ARMSerialWireDebug
//
//  Created by Denis Bohm on 6/28/16.
//  Copyright © 2016 Firefly Design LCC. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "FDLogger.h"
#import "FDSerialEngine.h"
#import "FDSerialWire.h"

@interface FDSerialWireEngine : NSObject <FDSerialWire>

@property (nullable) FDSerialEngine *serialEngine;
@property (nonnull) FDLogger *logger;

@property UInt16 clockDivisor;

- (BOOL)initialize:(NSError * _Nullable * _Nullable)error;

@end
