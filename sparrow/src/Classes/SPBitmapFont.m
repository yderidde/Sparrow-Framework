//
//  SPBitmapFont.m
//  Sparrow
//
//  Created by Daniel Sperl on 12.10.09.
//  Copyright 2011 Gamua. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the Simplified BSD License.
//

#import "SPBitmapFont.h"
#import "SPBitmapChar.h"
#import "SPTexture.h"
#import "SPRectangle.h"
#import "SPSubTexture.h"
#import "SPDisplayObject.h"
#import "SPSprite.h"
#import "SPImage.h"
#import "SPTextField.h"
#import "SPStage.h"
#import "SPUtils.h"
#import "SparrowClass.h"

#define CHAR_SPACE   32
#define CHAR_TAB      9
#define CHAR_NEWLINE 10

// --- private interface ---------------------------------------------------------------------------

@interface SPBitmapFont ()

- (void)parseFontXml:(NSString*)path;

@end

// --- class implementation ------------------------------------------------------------------------

@implementation SPBitmapFont
{
    SPTexture *_fontTexture;
    NSString *_name;
    NSString *_path;
    NSMutableDictionary *_chars;
    float _size;
    float _lineHeight;
}

@synthesize name = _name;
@synthesize lineHeight = _lineHeight;
@synthesize size = _size;

- (id)initWithContentsOfFile:(NSString *)path texture:(SPTexture *)texture
{
    if ((self = [super init]))
    {
        _name = @"unknown";
        _lineHeight = _size = SP_DEFAULT_FONT_SIZE;
        _fontTexture = texture;
        _chars = [[NSMutableDictionary alloc] init];
        
        [self parseFontXml:path];
    }
    return self;
}

- (id)initWithContentsOfFile:(NSString *)path
{
    return [self initWithContentsOfFile:path texture:nil];
}

- (id)init
{
    return nil;
}

- (void)parseFontXml:(NSString*)path
{
    if (!path) return;
    
    float scaleFactor = Sparrow.contentScaleFactor;
    _path = [SPUtils absolutePathToFile:path withScaleFactor:scaleFactor];
    if (!_path) [NSException raise:SP_EXC_FILE_NOT_FOUND format:@"file not found: %@", path];
    
    @autoreleasepool
    {
        NSData *xmlData = [[NSData alloc] initWithContentsOfFile:_path];
        NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:xmlData];
        
        xmlParser.delegate = self;
        BOOL success = [xmlParser parse];
        
        if (!success)
            [NSException raise:SP_EXC_FILE_INVALID 
                        format:@"could not parse bitmap font xml %@. Error code: %d, domain: %@", 
                               path, xmlParser.parserError.code, xmlParser.parserError.domain];
    }
}

- (void)parser:(NSXMLParser*)parser didStartElement:(NSString*)elementName 
  namespaceURI:(NSString*)namespaceURI 
 qualifiedName:(NSString*)qName 
    attributes:(NSDictionary*)attributeDict 
{
    if ([elementName isEqualToString:@"char"])
    {
        int charID = [[attributeDict valueForKey:@"id"] intValue];        
        float scale = _fontTexture.scale;
        
        SPRectangle *region = [[SPRectangle alloc] init];
        region.x = [[attributeDict valueForKey:@"x"] floatValue] / scale + _fontTexture.frame.x;
        region.y = [[attributeDict valueForKey:@"y"] floatValue] / scale + _fontTexture.frame.y;
        region.width = [[attributeDict valueForKey:@"width"] floatValue] / scale;
        region.height = [[attributeDict valueForKey:@"height"] floatValue] / scale;
        SPSubTexture *texture = [[SPSubTexture alloc] initWithRegion:region ofTexture:_fontTexture];
        
        float xOffset = [[attributeDict valueForKey:@"xoffset"] floatValue] / scale;
        float yOffset = [[attributeDict valueForKey:@"yoffset"] floatValue] / scale;
        float xAdvance = [[attributeDict valueForKey:@"xadvance"] floatValue] / scale;
        
        SPBitmapChar *bitmapChar = [[SPBitmapChar alloc] initWithID:charID texture:texture
                                                            xOffset:xOffset yOffset:yOffset 
                                                           xAdvance:xAdvance];
        
        _chars[@(charID)] = bitmapChar;
    }
	else if ([elementName isEqualToString:@"kerning"])
	{
		int first  = [[attributeDict valueForKey:@"first"] intValue];
        int second = [[attributeDict valueForKey:@"second"] intValue];
        float amount = [[attributeDict valueForKey:@"amount"] floatValue] / _fontTexture.scale;
		[[self charByID:second] addKerning:amount toChar:first];
	}
    else if ([elementName isEqualToString:@"info"])
    {
        _name = [[attributeDict valueForKey:@"face"] copy];
        _size = [[attributeDict valueForKey:@"size"] floatValue];
    }
    else if ([elementName isEqualToString:@"common"])
    {
        _lineHeight = [[attributeDict valueForKey:@"lineHeight"] floatValue];
    }
    else if ([elementName isEqualToString:@"page"])
    {
        int id = [[attributeDict valueForKey:@"id"] intValue];
        if (id != 0) [NSException raise:SP_EXC_FILE_INVALID 
                                 format:@"Bitmap fonts with multiple pages are not supported"];
        if (!_fontTexture)
        {
            NSString *filename = [attributeDict valueForKey:@"file"];
            NSString *folder = [_path stringByDeletingLastPathComponent];
            NSString *absolutePath = [folder stringByAppendingPathComponent:filename];
            _fontTexture = [[SPTexture alloc] initWithContentsOfFile:absolutePath];             
        }
        
        // update sizes, now that we know the scale setting
        _size /= _fontTexture.scale;
        _lineHeight /= _fontTexture.scale;
    }
}

- (SPBitmapChar *)charByID:(int)charID
{
    return (SPBitmapChar *)_chars[@(charID)];
}

- (SPDisplayObject *)createDisplayObjectWithWidth:(float)width height:(float)height
                                             text:(NSString *)text fontSize:(float)size color:(uint)color 
                                           hAlign:(SPHAlign)hAlign vAlign:(SPVAlign)vAlign
                                           border:(BOOL)border kerning:(BOOL)kerning
{    
    SPSprite *lineContainer = [SPSprite sprite];
    
    if (size < 0) size *= -_size;
    
    float scale = size / _size;
    lineContainer.scaleX = lineContainer.scaleY = scale;        
    float containerWidth = width / scale;
    float containerHeight = height / scale;    
    
    int lastWhiteSpace = -1;
    int lastCharID = -1;
    float currentX = 0;
    SPSprite *currentLine = [SPSprite sprite];
    
    for (int i=0; i<text.length; i++)
    {        
        BOOL lineFull = NO;

        int charID = [text characterAtIndex:i];    
        if (charID == CHAR_NEWLINE)        
        {
            lineFull = YES;
        }            
        else 
        {        
            if (charID == CHAR_SPACE || charID == CHAR_TAB)        
                lastWhiteSpace = i;        
            
            SPBitmapChar *bitmapChar = [self charByID:charID];
            if (!bitmapChar) bitmapChar = [self charByID:CHAR_SPACE];
            SPImage *charImage = [bitmapChar createImage];
            
            if (kerning) 
                currentX += [bitmapChar kerningToChar:lastCharID];
            
            charImage.x = currentX + bitmapChar.xOffset;
            charImage.y = bitmapChar.yOffset;

            charImage.color = color;
            [currentLine addChild:charImage];
            
            currentX += bitmapChar.xAdvance;
			lastCharID = charID;
            
            if (currentX > containerWidth)        
            {
                // remove characters and add them again to next line
                int numCharsToRemove = lastWhiteSpace == -1 ? 1 : i - lastWhiteSpace;
                int removeIndex = currentLine.numChildren - numCharsToRemove;
                
                for (int i=0; i<numCharsToRemove; ++i)
                    [currentLine removeChildAtIndex:removeIndex];
                
                if (currentLine.numChildren == 0)
                    break;
                
                SPDisplayObject *lastChar = [currentLine childAtIndex:currentLine.numChildren-1];
                currentX = lastChar.x + lastChar.width;
                
                i -= numCharsToRemove;
                lineFull = YES;
            }
        }
        
        if (lineFull || i == text.length - 1)
        {
            float nextLineY = currentLine.y + _lineHeight;             
            [lineContainer addChild:currentLine];                        
            
            if (nextLineY + _lineHeight <= containerHeight)
            {
                currentLine = [SPSprite sprite];
                currentLine.y = nextLineY;            
                currentX = 0;
                lastWhiteSpace = -1;
                lastCharID = -1;
            }
            else
            {
                break;
            }
        }
    }
    
    // hAlign
    if (hAlign != SPHAlignLeft)
    {
        for (SPSprite *line in lineContainer)
        {
            if (line.numChildren == 0) continue;
            SPDisplayObject *lastChar = [line childAtIndex:line.numChildren-1];
            float lineWidth = lastChar.x + lastChar.width;
            float widthDiff = containerWidth - lineWidth;
            line.x = (int) (hAlign == SPHAlignRight ? widthDiff : widthDiff / 2);
        }
    }
    
    SPSprite *outerContainer = [SPSprite sprite]; // [SPCompiledSprite sprite]; // TODO: flatten
    [outerContainer addChild:lineContainer];    
    
    if (vAlign != SPVAlignTop)
    {
        float contentHeight = lineContainer.numChildren * _lineHeight * scale;
        float heightDiff = height - contentHeight;
        lineContainer.y = (int)(vAlign == SPVAlignBottom ? heightDiff : heightDiff / 2.0f);
    }
    
    if (border)
    {
        SPQuad *topBorder = [SPQuad quadWithWidth:width height:1];
        SPQuad *bottomBorder = [SPQuad quadWithWidth:width height:1];
        SPQuad *leftBorder = [SPQuad quadWithWidth:1 height:height-2];
        SPQuad *rightBorder = [SPQuad quadWithWidth:1 height:height-2];
        
        topBorder.color = bottomBorder.color = leftBorder.color = rightBorder.color = color;
        bottomBorder.y = height - 1;
        leftBorder.y = rightBorder.y = 1;
        rightBorder.x = width - 1;
        
        [outerContainer addChild:topBorder];
        [outerContainer addChild:bottomBorder];
        [outerContainer addChild:leftBorder];
        [outerContainer addChild:rightBorder];        
    }    
    
    return outerContainer;
}

@end
