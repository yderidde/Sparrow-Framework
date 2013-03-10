//
//  SPDelayedInvocation.m
//  Sparrow
//
//  Created by Daniel Sperl on 11.07.09.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPDelayedInvocation.h"


@implementation SPDelayedInvocation
{
    id _target;
    NSMutableSet *_invocations;
    double _totalTime;
    double _currentTime;
}

@synthesize totalTime = _totalTime;
@synthesize currentTime = _currentTime;
@synthesize target = _target;

- (id)initWithTarget:(id)target delay:(double)time
{
    if (!target) return nil;
    else if ((self = [super init]))
    {
        _totalTime = MAX(0.0001, time); // zero is not allowed
        _currentTime = 0;
        _target = target;
        _invocations = [[NSMutableSet alloc] init];
    }
    return self;
}

- (id)init
{
    return nil;
}

- (NSMethodSignature*)methodSignatureForSelector:(SEL)aSelector
{
    NSMethodSignature *sig = [[self class] instanceMethodSignatureForSelector:aSelector];
    if (!sig) sig = [_target methodSignatureForSelector:aSelector];
    return sig;
}

- (void)forwardInvocation:(NSInvocation*)anInvocation
{
    if ([_target respondsToSelector:[anInvocation selector]])
    {
        anInvocation.target = _target;
        [anInvocation retainArguments];
        [_invocations addObject:anInvocation];
    }
}

- (void)advanceTime:(double)seconds
{
    self.currentTime = _currentTime + seconds;
}

- (void)setCurrentTime:(double)currentTime
{
    double previousTime = _currentTime;    
    _currentTime = MIN(_totalTime, currentTime);
    
    if (previousTime < _totalTime && _currentTime >= _totalTime)
    {
        [_invocations makeObjectsPerformSelector:@selector(invoke)];
        [self dispatchEventWithType:SP_EVENT_TYPE_REMOVE_FROM_JUGGLER];
    }
}

- (BOOL)isComplete
{
    return _currentTime >= _totalTime;
}

+ (id)invocationWithTarget:(id)target delay:(double)time
{
    return [[self alloc] initWithTarget:target delay:time];
}

@end
