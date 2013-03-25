//
//  SPRenderSupport.m
//  Sparrow
//
//  Created by Daniel Sperl on 28.09.09.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPRenderSupport.h"
#import "SPDisplayObject.h"
#import "SPVertexData.h"
#import "SPQuadBatch.h"
#import "SPTexture.h"
#import "SPMacros.h"
#import "SPQuad.h"

#import <GLKit/GLKit.h>

@implementation SPRenderSupport
{
    SPMatrix *_projectionMatrix;
    SPMatrix *_modelviewMatrix;
    SPMatrix *_mvpMatrix;
    NSMutableArray *_matrixStack;
    int _matrixStackSize;
    
    float *_alphaStack;
    int _alphaStackSize;
    
    GLKBaseEffect *_baseEffect;
    uint _boundTextureName;
    
    NSMutableArray *_quadBatches;
    int _currentQuadBatchID;
}

@synthesize usingPremultipliedAlpha = _premultipliedAlpha;
@synthesize modelviewMatrix = _modelviewMatrix;
@synthesize projectionMatrix = _projectionMatrix;

- (id)init
{
    if ((self = [super init]))
    {
        _projectionMatrix = [[SPMatrix alloc] init];
        _modelviewMatrix  = [[SPMatrix alloc] init];
        _mvpMatrix        = [[SPMatrix alloc] init];
        
        _matrixStack = [[NSMutableArray alloc] initWithCapacity:16];
        _matrixStackSize = 0;
        
        _alphaStack = calloc(SP_MAX_DISPLAY_TREE_DEPTH, sizeof(float));
        _alphaStack[0] = 1.0f;
        _alphaStackSize = 1;
        
        _baseEffect = [[GLKBaseEffect alloc] init];
        
        _quadBatches = [[NSMutableArray alloc] initWithObjects:[[SPQuadBatch alloc] init], nil];
        _currentQuadBatchID = 0;
        
        [self loadIdentity];
        [self setupOrthographicProjectionWithLeft:0 right:320 top:0 bottom:480];
    }
    return self;
}

- (void)dealloc
{
    free(_alphaStack);
}

- (void)nextFrame
{
    [self resetMatrix];
    _currentQuadBatchID = 0;
}

- (void)purgeBuffers
{
    [_quadBatches removeAllObjects];
    [_quadBatches addObject:[[SPQuadBatch alloc] init]];
     _currentQuadBatchID = 0;
}

+ (void)clearWithColor:(uint)color alpha:(float)alpha;
{
    float red   = SP_COLOR_PART_RED(color)   / 255.0f;
    float green = SP_COLOR_PART_GREEN(color) / 255.0f;
    float blue  = SP_COLOR_PART_BLUE(color)  / 255.0f;
    
    glClearColor(red, green, blue, alpha);
    glClear(GL_COLOR_BUFFER_BIT);
}

+ (uint)checkForOpenGLError
{
    GLenum error = glGetError();
    if (error != 0) NSLog(@"There was an OpenGL error: 0x%x", error);
    return error;
}

#pragma mark - alpha stack

- (float)pushAlpha:(float)alpha
{
    if (_alphaStackSize < SP_MAX_DISPLAY_TREE_DEPTH)
    {
        float newAlpha = _alphaStack[_alphaStackSize-1] * alpha;
        _alphaStack[_alphaStackSize++] = newAlpha;
        return newAlpha;
    }
    else
    {
        [NSException raise:SP_EXC_INVALID_OPERATION format:@"The display tree is too deep"];
        return 0.0f;
    }
}

- (float)popAlpha
{
    if (_alphaStackSize > 0)
        --_alphaStackSize;
    
    return _alphaStack[_alphaStackSize-1];
}

- (float)alpha
{
    return _alphaStack[_alphaStackSize-1];
}

#pragma mark - matrix manipulation

- (void)loadIdentity
{
    [_modelviewMatrix identity];
}

- (void)resetMatrix
{
    _matrixStackSize = 0;
    [self loadIdentity];
}

- (void)pushMatrix
{
    if (_matrixStack.count < _matrixStackSize + 1)
        [_matrixStack addObject:[SPMatrix matrixWithIdentity]];
    
    SPMatrix *currentMatrix = _matrixStack[_matrixStackSize++];
    [currentMatrix copyFromMatrix:_modelviewMatrix];
}

- (void)popMatrix
{
    SPMatrix *currentMatrix = _matrixStack[--_matrixStackSize];
    [_modelviewMatrix copyFromMatrix:currentMatrix];
}

- (void)setupOrthographicProjectionWithLeft:(float)left right:(float)right
                                        top:(float)top bottom:(float)bottom;
{
    [_projectionMatrix setA:2.0f/(right-left) b:0.0f c:0.0f d:2.0f/(top-bottom)
                         tx:-(right+left) / (right-left)
                         ty:-(top+bottom) / (top-bottom)];
    
    _baseEffect.transform.projectionMatrix = [_projectionMatrix convertToGLKMatrix4];
}

- (void)prependMatrix:(SPMatrix *)matrix
{
    [_modelviewMatrix prependMatrix:matrix];
}

- (SPMatrix *)mvpMatrix
{
    [_mvpMatrix copyFromMatrix:_modelviewMatrix];
    [_mvpMatrix appendMatrix:_projectionMatrix];
    return _mvpMatrix;
}

#pragma mark - rendering

- (void)batchQuad:(SPQuad *)quad
{
    float alpha = self.alpha;
    
    if ([self.currentQuadBatch isStateChangeWithTinted:quad.tinted texture:quad.texture alpha:alpha
                                    premultipliedAlpha:quad.premultipliedAlpha numQuads:1])
    {
        [self finishQuadBatch];
    }
    
    [self.currentQuadBatch addQuad:quad alpha:alpha matrix:_modelviewMatrix];
}

- (void)finishQuadBatch
{
    SPQuadBatch *currentBatch = self.currentQuadBatch;
    
    if (currentBatch.numQuads)
    {
        [currentBatch renderWithAlpha:1.0f matrix:_projectionMatrix];
        [currentBatch reset];
        
        ++_currentQuadBatchID;
        
        if (_quadBatches.count <= _currentQuadBatchID)
            [_quadBatches addObject:[[SPQuadBatch alloc] init]];
    }
}

- (SPQuadBatch *)currentQuadBatch
{
    return _quadBatches[_currentQuadBatchID];
}

@end
