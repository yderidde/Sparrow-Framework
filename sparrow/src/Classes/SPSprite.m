//
//  SPSprite.m
//  Sparrow
//
//  Created by Daniel Sperl on 21.03.09.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPSprite.h"
#import "SPQuadBatch.h"
#import "SPRenderSupport.h"

@implementation SPSprite
{
    NSMutableArray *_flattenedContents;
    BOOL _flattenRequested;
}

- (void)flatten
{
    _flattenRequested = YES;
    [self broadcastEventWithType:SP_EVENT_TYPE_FLATTEN];
}

- (void)unflatten
{
    _flattenRequested = NO;
    _flattenedContents = nil;
}

- (BOOL)isFlattened
{
    return _flattenedContents || _flattenRequested;
}

- (void)render:(SPRenderSupport *)support
{
    if (_flattenRequested)
    {
        _flattenedContents = [SPQuadBatch compileObject:self intoArray:_flattenedContents];
        _flattenRequested = NO;
    }
    
    if (_flattenedContents)
    {
        [support finishQuadBatch];
        [support addDrawCalls:_flattenedContents.count];
        
        SPMatrix *mvpMatrix = support.mvpMatrix;
        float alpha = support.alpha;
        
        for (SPQuadBatch *quadBatch in _flattenedContents)
            [quadBatch renderWithAlpha:alpha matrix:mvpMatrix];
    }
    else [super render:support];
}

+ (id)sprite
{
    return [[self alloc] init];
}

@end
