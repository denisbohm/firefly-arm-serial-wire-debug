//
//  FDLogger.h
//  ARMSerialWireDebug
//
//  Created by Denis Bohm on 1/7/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol FDLoggerConsumer <NSObject>

- (void)logFile:(nonnull char *)file line:(NSUInteger)line class:(nonnull NSString *)class method:(nonnull NSString *)method message:(nonnull NSString *)message;

@end

@interface FDLogger : NSObject

@property (nullable) id<FDLoggerConsumer> consumer;

- (void)logFile:(nonnull char *)file line:(NSUInteger)line class:(nonnull NSString *)class method:(nonnull NSString *)method format:(nonnull NSString *)format, ...;

+ (nonnull NSString *)callStack:(nonnull NSException *)exception;

@end

#define FDLog(f, ...) [self.logger logFile:__FILE__ line:__LINE__ class:[self className] method:NSStringFromSelector(_cmd) format:f, ##__VA_ARGS__]