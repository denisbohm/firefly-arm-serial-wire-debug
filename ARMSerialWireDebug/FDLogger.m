//
//  FDLogger.m
//  ARMSerialWireDebug
//
//  Created by Denis Bohm on 1/7/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDLogger.h"

@implementation FDLogger

- (void)logFile:(char *)file line:(NSUInteger)line class:(NSString *)class method:(NSString *)method format:(NSString *)format, ...
{
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    if (_consumer) {
        [_consumer logFile:file line:line class:class method:method message:message];
    } else {
        NSLog(@"log: %s:%lu %@.%@ %@", file, line, class, method, message);
    }
}

+ (NSString *)callStack:(NSException *)exception {
    NSMutableString* text = [[NSMutableString alloc] init];
    [text appendString:[exception name]];
    [text appendString:@": "];
    [text appendString:[exception reason]];
    if ([exception respondsToSelector:@selector(callStackSymbols)]) {
        NSArray* symbols = [exception performSelector:@selector(callStackSymbols)];
        NSUInteger count = symbols.count;
        for (NSUInteger i = 0; i < count; ++i) {
            [text appendFormat:@"\n%@", [symbols objectAtIndex:i]];
        }
    } else {
        [text appendString: @"\n*** call stack not available ***"];
    }
    return text;
}

@end
