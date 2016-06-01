//
//  FDFireflyFlashNRF5.h
//  ARMSerialWireDebug
//
//  Created by Denis Bohm on 8/19/15.
//  Copyright (c) 2015 Firefly Design. All rights reserved.
//

#import "FDFireflyFlash.h"

@interface FDFireflyFlashNRF5 : FDFireflyFlash

- (BOOL)eraseUICR:(NSError * _Nullable * _Nullable)error;

@end
