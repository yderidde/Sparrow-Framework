//
//  SPQuadBatch.m
//  Sparrow
//
//  Created by Daniel Sperl on 01.03.13.
//  Copyright 2013 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPQuadBatch.h"
#import "SPTexture.h"
#import "SPImage.h"
#import "SPRenderSupport.h"

#import <GLKit/GLKit.h>

@implementation SPQuadBatch
{
    int _numQuads;
    BOOL _syncRequired;
    
    SPTexture *_texture;
    BOOL _premultipliedAlpha;
    
    GLKBaseEffect *_baseEffect;
    SPVertexData *_vertexData;
    uint _vertexBufferName;
    ushort *_indexData;
    uint _indexBufferName;
}

@synthesize numQuads = _numQuads;

- (id)init
{
    if ((self = [super init]))
    {
        _numQuads = 0;
        _syncRequired = NO;
        _vertexData = [[SPVertexData alloc] init];
        _baseEffect = [[GLKBaseEffect alloc] init];
        _baseEffect.transform.projectionMatrix = GLKMatrix4Identity;
    }
    
    return self;
}

- (void)dealloc
{
    free(_indexData);
    
    glDeleteBuffers(1, &_vertexBufferName);
    glDeleteBuffers(1, &_indexBufferName);
}

- (void)reset
{
    _numQuads = 0;
    _texture = nil;
    _syncRequired = YES;
}

- (void)expand
{
    int oldCapacity = self.capacity;
    int newCapacity = oldCapacity ? oldCapacity * 2 : 16;
    int numVertices = newCapacity * 4;
    int numIndices  = newCapacity * 6;
    
    _vertexData.numVertices = numVertices;
    
    if (!_indexData) _indexData = malloc(sizeof(ushort) * numIndices);
    else             _indexData = realloc(_indexData, sizeof(ushort) * numIndices);
    
    for (int i=oldCapacity; i<newCapacity; ++i)
    {
        _indexData[i*6  ] = i*4;
        _indexData[i*6+1] = i*4 + 1;
        _indexData[i*6+2] = i*4 + 2;
        _indexData[i*6+3] = i*4 + 1;
        _indexData[i*6+4] = i*4 + 3;
        _indexData[i*6+5] = i*4 + 2;
    }
    
    [self createBuffers];
}

- (void)createBuffers
{
    int numVertices = _vertexData.numVertices;
    int numIndices = numVertices / 4 * 6;
    
    if (_vertexBufferName) glDeleteBuffers(1, &_vertexBufferName);
    if (_indexBufferName)  glDeleteBuffers(1, &_indexBufferName);
    if (numVertices == 0)  return;
    
    glGenBuffers(1, &_vertexBufferName);
    glGenBuffers(1, &_indexBufferName);
    
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBufferName);
    glBufferData(GL_ARRAY_BUFFER, sizeof(SPVertex) * numVertices, _vertexData.vertices, GL_STATIC_DRAW);
    
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBufferName);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(ushort) * numIndices, _indexData, GL_STATIC_DRAW);
    
    _syncRequired = NO;
}

- (void)syncBuffers
{
    if (!_vertexBufferName)
        [self createBuffers];
    else
    {
        int numVertices = _numQuads * 4;
        glBindBuffer(GL_ARRAY_BUFFER, _vertexBufferName);
        glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(SPVertex) * numVertices, _vertexData.vertices);
        _syncRequired = NO;
    }
}

- (void)addQuad:(SPQuad *)quad
{
    [self addQuad:quad texture:nil];
}

- (void)addQuad:(SPQuad *)quad texture:(SPTexture *)texture
{
    [self addQuad:quad texture:texture alpha:quad.alpha];
}

- (void)addQuad:(SPQuad *)quad texture:(SPTexture *)texture alpha:(float)alpha
{
    [self addQuad:quad texture:texture alpha:alpha matrix:nil];
}

- (void)addQuad:(SPQuad *)quad texture:(SPTexture *)texture alpha:(float)alpha matrix:(SPMatrix *)matrix
{
    if (!matrix) matrix = quad.transformationMatrix;
    if (_numQuads + 1 > self.capacity) [self expand];
    if (_numQuads == 0)
    {
        _texture = texture;
        _premultipliedAlpha = quad.premultipliedAlpha;
        [_vertexData setPremultipliedAlpha:quad.premultipliedAlpha updateVertices:NO];
    }
    
    int vertexID = _numQuads * 4;
    
    [quad copyVertexDataTo:_vertexData atIndex:vertexID];
    [_vertexData transformVerticesWithMatrix:matrix atIndex:vertexID numVertices:4];
    
    if (alpha != 1.0f)
        [_vertexData scaleAlphaBy:alpha atIndex:vertexID numVertices:4];
    
    _syncRequired = YES;
    ++_numQuads;
}

- (BOOL)isStateChangeWithQuad:(SPQuad *)quad texture:(SPTexture *)texture numQuads:(int)numQuads
{
    if (_numQuads == 0) return NO;
    else if (_numQuads + numQuads > 8192) return YES; // maximum buffer size
    else if (!_texture && !texture) return _premultipliedAlpha != quad.premultipliedAlpha;
    else if (_texture && texture)
        return _texture.name != texture.name ||
               _texture.repeat != texture.repeat ||
               _texture.smoothing != texture.smoothing;
    else return YES;
}

- (SPRectangle *)boundsInSpace:(SPDisplayObject *)targetSpace
{
    SPMatrix *matrix = targetSpace == self ? nil : [self transformationMatrixToSpace:targetSpace];
    return [_vertexData boundsAfterTransformation:matrix];
}

- (void)render:(SPRenderSupport *)support
{
    if (_numQuads)
    {
        [support finishQuadBatch];
        [self renderWithAlpha:support.alpha matrix:support.mvpMatrix];
    }
}

- (void)renderWithAlpha:(float)alpha matrix:(SPMatrix *)matrix
{
    if (!_numQuads) return;
    if (_syncRequired) [self syncBuffers];
    
    // TODO: alpha
    
    _baseEffect.texture2d0.enabled = (_texture != nil);
    _baseEffect.texture2d0.name = _texture.name;
    _baseEffect.transform.modelviewMatrix = [matrix convertToGLKMatrix4];

    [_baseEffect prepareToDraw];

    if (_premultipliedAlpha) glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    else                     glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glEnableVertexAttribArray(GLKVertexAttribColor);
    
    if (_texture)
        glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    else
        glDisableVertexAttribArray(GLKVertexAttribTexCoord0);
    
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBufferName);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBufferName);
    
    glVertexAttribPointer(GLKVertexAttribPosition, 2, GL_FLOAT, GL_FALSE, sizeof(SPVertex),
                          (void *)(offsetof(SPVertex, position)));
    
    glVertexAttribPointer(GLKVertexAttribColor, 4, GL_UNSIGNED_BYTE, GL_TRUE, sizeof(SPVertex),
                          (void *)(offsetof(SPVertex, color)));
    
    if (_texture)
    {
        glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, sizeof(SPVertex),
                              (void *)(offsetof(SPVertex, texCoords)));
    }
    
    int numIndices = _numQuads * 6;
    glDrawElements(GL_TRIANGLES, numIndices, GL_UNSIGNED_SHORT, 0);
}

- (int)capacity
{
    return _vertexData.numVertices / 4;
}

@end
