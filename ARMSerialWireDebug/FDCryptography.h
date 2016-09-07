//
//  FDCryptography.h
//  ARMSerialWireDebug
//
//  Created by Denis Bohm on 9/7/16.
//  Copyright © 2016 Firefly Design LCC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FDCryptography : NSObject

+(NSData *)sha1:(NSData *)data;

@end
