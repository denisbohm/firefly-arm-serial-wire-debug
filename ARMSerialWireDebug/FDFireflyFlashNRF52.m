//
//  FDFireflyFlashNRF52.m
//  ARMSerialWireDebug
//
//  Created by Denis Bohm on 8/19/15.
//  Copyright (c) 2015 Firefly Design. All rights reserved.
//

#import "FDFireflyFlashNRF52.h"

@implementation FDFireflyFlashNRF52

- (BOOL)setupProcessor:(NSError **)error
{
    self.pageSize = 4096;
    self.ramAddress = 0x20000000;
    self.ramSize = 65536;
    return YES;
}

@end
