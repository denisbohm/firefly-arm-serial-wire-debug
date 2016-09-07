//
//  FDCryptography.m
//  ARMSerialWireDebug
//
//  Created by Denis Bohm on 9/7/16.
//  Copyright © 2016 Firefly Design LCC. All rights reserved.
//

#import "FDCryptography.h"

#import <CommonCrypto/CommonCrypto.h>

@implementation FDCryptography

+(NSData *)sha1:(NSData *)data {
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(data.bytes, (int)data.length, digest);
    return [NSData dataWithBytes:digest length:sizeof(digest)];
}

@end
