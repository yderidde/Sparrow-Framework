//
//  SPDelayedInvocationTest.m
//  Sparrow
//
//  Created by Daniel Sperl on 10.07.10.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import <Availability.h>
#ifdef __IPHONE_3_0

#import <SenTestingKit/SenTestingKit.h>
#import "SPDelayedInvocation.h"
#import "SPMacros.h"

// -------------------------------------------------------------------------------------------------

@interface SPDelayedInvocationTest : SenTestCase 
{
    int _callCount;
}

@end

// -------------------------------------------------------------------------------------------------

@implementation SPDelayedInvocationTest

- (void)setUp
{
    _callCount = 0;
}

- (void)simpleMethod
{
    ++_callCount;
}

- (void)testSimpleDelay
{    
    id delayedInv = [[SPDelayedInvocation alloc] initWithTarget:self delay:1.0f];
    [delayedInv simpleMethod];
    
    STAssertEquals(0, _callCount, @"Delayed Invocation triggered too soon");
    [delayedInv advanceTime:0.5f];
    
    STAssertEquals(0, _callCount, @"Delayed Invocation triggered too soon");
    [delayedInv advanceTime:0.49f];
    
    STAssertEquals(0, _callCount, @"Delayed Invocation triggered too soon");
    
    [delayedInv advanceTime:0.1f];
    STAssertEquals(1, _callCount, @"Delayed Invocation did not trigger");
    
    [delayedInv advanceTime:0.1f];
    STAssertEquals(1, _callCount, @"Delayed Invocation triggered too often");
    
}

@end

#endif