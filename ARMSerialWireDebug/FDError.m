//
//  FDError.m
//  ARMSerialWireDebug
//
//  Created by Denis Bohm on 5/31/16.
//  Copyright © 2016 Firefly Design LCC. All rights reserved.
//

#import "FDError.h"

BOOL FDErrorCreate(NSError **error, const char *file, int line, NSString *className, NSString *methodName, NSDictionary *userInfo) {
    if (error != nil) {
        NSMutableDictionary *fullUserInfo;
        if (userInfo == nil) {
            fullUserInfo = [NSMutableDictionary dictionary];
        } else {
            fullUserInfo = [NSMutableDictionary dictionaryWithDictionary:userInfo];
        }
        NSString *description = [NSString stringWithFormat:@"ARMSerialWireDebug %s:%d %@.%@", file, line, className, methodName];
        [fullUserInfo setObject:description forKey:NSLocalizedDescriptionKey];
        NSString *domain = [NSString stringWithFormat:@"ARMSerialWireDebug.%@", className];
        *error = [NSError errorWithDomain:domain code:__LINE__ userInfo:fullUserInfo];
    }
    return NO;
}

@implementation FDError

@end
