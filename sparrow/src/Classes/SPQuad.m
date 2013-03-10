//
//  SPQuad.m
//  Sparrow
//
//  Created by Daniel Sperl on 15.03.09.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPQuad.h"
#import "SPRectangle.h"
#import "SPMacros.h"
#import "SPPoint.h"
#import "SPRenderSupport.h"
#import "SPVertexData.h"

@implementation SPQuad

- (id)initWithWidth:(float)width height:(float)height color:(uint)color premultipliedAlpha:(BOOL)pma;
{
    if ((self = [super init]))
    {
        _vertexData = [[SPVertexData alloc] initWithSize:4 premultipliedAlpha:pma];
        
        _vertexData.vertices[1].position.x = width;
        _vertexData.vertices[2].position.y = height;
        _vertexData.vertices[3].position.x = width;
        _vertexData.vertices[3].position.y = height;
        
        for (int i=0; i<4; ++i)
            _vertexData.vertices[i].color = SPVertexColorMakeWithColorAndAlpha(color, 1.0f);
        
        [self vertexDataDidChange];
    }
    return self;
}

- (id)initWithWidth:(float)width height:(float)height color:(uint)color
{
    return [self initWithWidth:width height:height color:color premultipliedAlpha:YES];
}

- (id)initWithWidth:(float)width height:(float)height
{
    return [self initWithWidth:width height:height color:SP_WHITE];
}

- (id)init
{    
    return [self initWithWidth:32 height:32];
}

- (SPRectangle*)boundsInSpace:(SPDisplayObject*)targetSpace
{
    SPMatrix *transformationMatrix = targetSpace == self ?
        nil : [self transformationMatrixToSpace:targetSpace];
    
    return [_vertexData boundsAfterTransformation:transformationMatrix];
}

- (void)setColor:(uint)color ofVertex:(int)vertexID
{
    [_vertexData setColor:color atIndex:vertexID];
    [self vertexDataDidChange];
}

- (uint)colorOfVertex:(int)vertexID
{
    return [_vertexData colorAtIndex:vertexID];
}

- (void)setColor:(uint)color
{
    for (int i=0; i<4; ++i) [self setColor:color ofVertex:i];
}

- (uint)color
{
    return [self colorOfVertex:0];
}

- (void)setAlpha:(float)alpha ofVertex:(int)vertexID
{
    [_vertexData setAlpha:alpha atIndex:vertexID];
    [self vertexDataDidChange];
}

- (float)alphaOfVertex:(int)vertexID
{
    return [_vertexData alphaAtIndex:vertexID];
}

- (void)vertexDataDidChange
{
    // override in subclass
}

- (void)copyVertexDataTo:(SPVertexData *)targetData atIndex:(int)targetIndex
{
    [_vertexData copyToVertexData:targetData atIndex:targetIndex];
}

- (BOOL)premultipliedAlpha
{
    return _vertexData.premultipliedAlpha;
}

- (void)render:(SPRenderSupport *)support
{
    [support batchQuad:self texture:nil];
}

+ (id)quadWithWidth:(float)width height:(float)height
{
    return [[self alloc] initWithWidth:width height:height];
}

+ (id)quadWithWidth:(float)width height:(float)height color:(uint)color
{
    return [[self alloc] initWithWidth:width height:height color:color];
}

+ (id)quad
{
    return [[self alloc] init];
}

@end
