//
//  SPTextField.m
//  Sparrow
//
//  Created by Daniel Sperl on 29.06.09.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPTextField.h"
#import "SPTextField_Internal.h"
#import "SPImage.h"
#import "SPTexture.h"
#import "SPSubTexture.h"
#import "SPGLTexture.h"
#import "SPEnterFrameEvent.h"
#import "SPQuad.h"
#import "SPBitmapFont.h"
#import "SPStage.h"
#import "SparrowClass.h"

#import <UIKit/UIKit.h>

static NSMutableDictionary *bitmapFonts = nil;

// --- class implementation ------------------------------------------------------------------------

@implementation SPTextField
{
    float _fontSize;
    uint _color;
    NSString *_text;
    NSString *_fontName;
    SPHAlign _hAlign;
    SPVAlign _vAlign;
    BOOL _border;
    BOOL _requiresRedraw;
    BOOL _isRenderedText;
	BOOL _kerning;
    
    SPQuad *_hitArea;
    SPQuad *_textArea;
    SPDisplayObject *_contents;
}

@synthesize text = _text;
@synthesize fontName = _fontName;
@synthesize fontSize = _fontSize;
@synthesize hAlign = _hAlign;
@synthesize vAlign = _vAlign;
@synthesize border = _border;
@synthesize color = _color;
@synthesize kerning = _kerning;

- (id)initWithWidth:(float)width height:(float)height text:(NSString*)text fontName:(NSString*)name 
          fontSize:(float)size color:(uint)color 
{
    if ((self = [super init]))
    {        
        _text = [text copy];
        _fontSize = size;
        _color = color;
        _hAlign = SPHAlignCenter;
        _vAlign = SPVAlignCenter;
        _border = NO;        
		_kerning = YES;
        _requiresRedraw = YES;
        self.fontName = name;
        
        _hitArea = [[SPQuad alloc] initWithWidth:width height:height];
        _hitArea.alpha = 0.0f;
        [self addChild:_hitArea];
        
        _textArea = [[SPQuad alloc] initWithWidth:width height:height];
        _textArea.visible = NO;        
        [self addChild:_textArea];
        
        [self addEventListener:@selector(onFlatten:) atObject:self forType:SP_EVENT_TYPE_FLATTEN];
    }
    return self;
} 

- (id)initWithWidth:(float)width height:(float)height text:(NSString*)text
{
    return [self initWithWidth:width height:height text:text fontName:SP_DEFAULT_FONT_NAME
                     fontSize:SP_DEFAULT_FONT_SIZE color:SP_DEFAULT_FONT_COLOR];   
}

- (id)initWithWidth:(float)width height:(float)height
{
    return [self initWithWidth:width height:height text:@""];
}

- (id)initWithText:(NSString *)text
{
    return [self initWithWidth:128 height:128 text:text];
}

- (id)init
{
    return [self initWithText:@""];
}

- (void)onFlatten:(SPEvent *)event
{
    if (_requiresRedraw) [self redrawContents];
}

- (void)render:(SPRenderSupport *)support
{
    if (_requiresRedraw) [self redrawContents];    
    [super render:support];
}

- (SPRectangle *)textBounds
{
    if (_requiresRedraw) [self redrawContents];    
    return [_textArea boundsInSpace:self.parent];
}

- (SPRectangle *)boundsInSpace:(SPDisplayObject *)targetSpace
{
    return [_hitArea boundsInSpace:targetSpace];
}

- (void)setWidth:(float)width
{
    // other than in SPDisplayObject, changing the size of the object should not change the scaling;
    // changing the size should just make the texture bigger/smaller, 
    // keeping the size of the text/font unchanged. (this applies to setHeight:, as well.)
    
    _hitArea.width = width;
    _requiresRedraw = YES;
}

- (void)setHeight:(float)height
{
    _hitArea.height = height;
    _requiresRedraw = YES;
}

- (void)setText:(NSString *)text
{
    if (![text isEqualToString:_text])
    {
        _text = [text copy];
        _requiresRedraw = YES;
    }
}

- (void)setFontName:(NSString *)fontName
{
    if (![fontName isEqualToString:_fontName])
    {
        if ([fontName isEqualToString:SP_BITMAP_FONT_MINI] && ![bitmapFonts objectForKey:fontName])
            [SPTextField registerBitmapFont:[[SPBitmapFont alloc] initWithMiniFont]];
        
        _fontName = [fontName copy];
        _requiresRedraw = YES;        
        _isRenderedText = !bitmapFonts[_fontName];
    }
}

- (void)setFontSize:(float)fontSize
{
    if (fontSize != _fontSize)
    {
        _fontSize = fontSize;
        _requiresRedraw = YES;
    }
}
 
- (void)setBorder:(BOOL)border
{
    if (border != _border)
    {
        _border = border;
        _requiresRedraw = YES;
    }
}
 
- (void)setHAlign:(SPHAlign)hAlign
{
    if (hAlign != _hAlign)
    {
        _hAlign = hAlign;
        _requiresRedraw = YES;
    }
}

- (void)setVAlign:(SPVAlign)vAlign
{
    if (vAlign != _vAlign)
    {
        _vAlign = vAlign;
        _requiresRedraw = YES;
    }
}

- (void)setColor:(uint)color
{
    if (color != _color)
    {
        _color = color;
        _requiresRedraw = YES;
    }
}

- (void)setKerning:(BOOL)kerning
{
	if (kerning != _kerning)
	{
		_kerning = kerning;
		_requiresRedraw = YES;
	}
}

+ (id)textFieldWithWidth:(float)width height:(float)height text:(NSString*)text
                          fontName:(NSString*)name fontSize:(float)size color:(uint)color
{
    return [[self alloc] initWithWidth:width height:height text:text fontName:name
                                     fontSize:size color:color];
}

+ (id)textFieldWithWidth:(float)width height:(float)height text:(NSString*)text
{
    return [[self alloc] initWithWidth:width height:height text:text];
}

+ (id)textFieldWithText:(NSString*)text
{
    return [[self alloc] initWithText:text];
}

+ (NSString *)registerBitmapFont:(SPBitmapFont *)font name:(NSString *)fontName
{
    if (!bitmapFonts) bitmapFonts = [[NSMutableDictionary alloc] init];
    if (!fontName) fontName = font.name;
    bitmapFonts[fontName] = font;
    return fontName;
}

+ (NSString *)registerBitmapFont:(SPBitmapFont *)font
{
    return [self registerBitmapFont:font name:nil];
}

+ (NSString *)registerBitmapFontFromFile:(NSString *)path name:(NSString *)fontName
{
    SPBitmapFont *font = [[SPBitmapFont alloc] initWithContentsOfFile:path];
    return [self registerBitmapFont:font name:fontName];
}

+ (NSString *)registerBitmapFontFromFile:(NSString *)path
{
    return [self registerBitmapFontFromFile:path name:nil];
}

+ (void)unregisterBitmapFont:(NSString *)name
{
    [bitmapFonts removeObjectForKey:name];
    
    if (bitmapFonts.count == 0)
        bitmapFonts = nil;
}

+ (SPBitmapFont *)registeredBitmapFont:(NSString *)name
{
    return bitmapFonts[name];
}

@end

@implementation SPTextField (Internal)

- (void)redrawContents
{
    [_contents removeFromParent];
    
    _contents = _isRenderedText ? [self createRenderedContents] : [self createComposedContents];
    _contents.touchable = NO;    
    _requiresRedraw = NO;
    
    [self addChild:_contents];
}

- (SPDisplayObject *)createRenderedContents
{
    float width = _hitArea.width;
    float height = _hitArea.height;    
    float fontSize = _fontSize == SP_NATIVE_FONT_SIZE ? SP_DEFAULT_FONT_SIZE : _fontSize;
    
  #if __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000
    NSLineBreakMode lbm = NSLineBreakByTruncatingTail;
  #else
    UILineBreakMode lbm = UILineBreakModeTailTruncation;
  #endif
    CGSize textSize = [_text sizeWithFont:[UIFont fontWithName:_fontName size:fontSize]
                        constrainedToSize:CGSizeMake(width, height) lineBreakMode:lbm];
    
    float xOffset = 0;
    if (_hAlign == SPHAlignCenter)      xOffset = (width - textSize.width) / 2.0f;
    else if (_hAlign == SPHAlignRight)  xOffset =  width - textSize.width;
    
    float yOffset = 0;
    if (_vAlign == SPVAlignCenter)      yOffset = (height - textSize.height) / 2.0f;
    else if (_vAlign == SPVAlignBottom) yOffset =  height - textSize.height;
    
    _textArea.x = xOffset; 
    _textArea.y = yOffset;
    _textArea.width = textSize.width; 
    _textArea.height = textSize.height;
    
    SPTexture *texture = [[SPTexture alloc] initWithWidth:width height:height generateMipmaps:YES
                                                     draw:^(CGContextRef context)
      {
          float red   = SP_COLOR_PART_RED(_color)   / 255.0f;
          float green = SP_COLOR_PART_GREEN(_color) / 255.0f;
          float blue  = SP_COLOR_PART_BLUE(_color)  / 255.0f;
          
          if (_border)
          {
              CGContextSetRGBStrokeColor(context, red, green, blue, 1.0f);
              CGContextSetLineWidth(context, 1.0f);
              CGContextStrokeRect(context, CGRectMake(0.5f, 0.5f, width-1, height-1));
          }
          
          CGContextSetRGBFillColor(context, red, green, blue, 1.0f);
          
          [_text drawInRect:CGRectMake(0, yOffset, width, height)
                   withFont:[UIFont fontWithName:_fontName size:fontSize] 
              lineBreakMode:lbm alignment:(UITextAlignment)_hAlign];
      }];
    
    return [SPImage imageWithTexture:texture];
}

- (SPDisplayObject *)createComposedContents
{
    SPBitmapFont *bitmapFont = bitmapFonts[_fontName];
    if (!bitmapFont)     
        [NSException raise:SP_EXC_INVALID_OPERATION 
                    format:@"bitmap font %@ not registered!", _fontName];       
    
    SPDisplayObject *contents = [bitmapFont createDisplayObjectWithWidth:_hitArea.width
        height:_hitArea.height text:_text fontSize:_fontSize color:_color
        hAlign:_hAlign vAlign:_vAlign border:_border kerning:_kerning];
    
    SPRectangle *textBounds = [(SPDisplayObjectContainer *)contents childAtIndex:0].bounds;
    _textArea.x = textBounds.x; _textArea.y = textBounds.y;
    _textArea.width = textBounds.width; _textArea.height = textBounds.height;    
    
    return contents;    
}

@end
