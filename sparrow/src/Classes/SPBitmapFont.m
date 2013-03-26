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
#import "SPNSExtensions.h"

#define CHAR_SPACE   32
#define CHAR_TAB      9
#define CHAR_NEWLINE 10

@implementation SPBitmapFont
{
    NSString *_name;
    SPTexture *_fontTexture;
    NSMutableDictionary *_chars;
    float _size;
    float _lineHeight;
}

@synthesize name = _name;
@synthesize lineHeight = _lineHeight;
@synthesize size = _size;

- (id)initWithContentsOfData:(NSData *)data texture:(SPTexture *)texture
{
    if ((self = [super init]))
    {
        _name = @"unknown";
        _lineHeight = _size = SP_DEFAULT_FONT_SIZE;
        _chars = [[NSMutableDictionary alloc] init];
        _fontTexture = texture ? texture : [self textureReferencedByXmlData:data];
        
        [self parseFontData:data];
    }
    
    return self;
}

- (id)initWithContentsOfData:(NSData *)data
{
    return [self initWithContentsOfData:data texture:nil];
}

- (id)initWithContentsOfFile:(NSString *)path texture:(SPTexture *)texture
{
    float scaleFactor = Sparrow.contentScaleFactor;
    NSString *absolutePath = [SPUtils absolutePathToFile:path withScaleFactor:scaleFactor];
    if (!absolutePath) [NSException raise:SP_EXC_FILE_NOT_FOUND format:@"file not found: %@", path];
    NSData *xmlData = [[NSData alloc] initWithContentsOfFile:absolutePath];

    if (!texture)
    {
        NSString *folder = [absolutePath stringByDeletingLastPathComponent];
        texture = [self textureReferencedByXmlData:xmlData inFolder:folder];
    }
    
    return [self initWithContentsOfData:xmlData texture:texture];
}

- (id)initWithContentsOfFile:(NSString *)path
{
    return [self initWithContentsOfFile:path texture:nil];
}

- (id)init
{
    return [self initWithMiniFont];
}

- (SPTexture *)textureReferencedByXmlData:(NSData *)data
{
    NSString *folder = [[NSBundle mainBundle] resourcePath];
    return [self textureReferencedByXmlData:data inFolder:folder];
}

- (SPTexture *)textureReferencedByXmlData:(NSData *)data inFolder:(NSString *)folder
{
    __block SPTexture *texture = nil;
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    
    BOOL success = [parser parseElementsWithBlock:^(NSString *elementName, NSDictionary *attributes)
    {
        if ([elementName isEqualToString:@"page"])
        {
            int id = [[attributes valueForKey:@"id"] intValue];
            if (id != 0) [NSException raise:SP_EXC_FILE_INVALID
                                     format:@"Bitmap fonts with multiple pages are not supported"];
            
            NSString *filename = [attributes valueForKey:@"file"];
            NSString *absolutePath = [folder stringByAppendingPathComponent:filename];
            texture = [[SPTexture alloc] initWithContentsOfFile:absolutePath];
            
            // that's all info we need at this time.
            [parser abortParsing];
        }
    }];
    
    if (!success)
        [NSException raise:SP_EXC_DATA_INVALID format:@"Error parsing font XML: %@",
         parser.parserError.localizedDescription];
    
    if (!texture)
        [NSException raise:SP_EXC_DATA_INVALID format:@"Font XML did not contain path to texture"];
    
    return texture;
}

- (BOOL)parseFontData:(NSData *)data
{
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    BOOL success = [parser parseElementsWithBlock:^(NSString *elementName, NSDictionary *attributes)
    {
        if ([elementName isEqualToString:@"char"])
        {
            int charID = [[attributes valueForKey:@"id"] intValue];
            float scale = _fontTexture.scale;
            
            SPRectangle *region = [[SPRectangle alloc] init];
            region.x = [[attributes valueForKey:@"x"] floatValue] / scale + _fontTexture.frame.x;
            region.y = [[attributes valueForKey:@"y"] floatValue] / scale + _fontTexture.frame.y;
            region.width = [[attributes valueForKey:@"width"] floatValue] / scale;
            region.height = [[attributes valueForKey:@"height"] floatValue] / scale;
            SPSubTexture *texture = [[SPSubTexture alloc] initWithRegion:region ofTexture:_fontTexture];
            
            float xOffset = [[attributes valueForKey:@"xoffset"] floatValue] / scale;
            float yOffset = [[attributes valueForKey:@"yoffset"] floatValue] / scale;
            float xAdvance = [[attributes valueForKey:@"xadvance"] floatValue] / scale;
            
            SPBitmapChar *bitmapChar = [[SPBitmapChar alloc] initWithID:charID texture:texture
                                                                xOffset:xOffset yOffset:yOffset
                                                               xAdvance:xAdvance];
            _chars[@(charID)] = bitmapChar;
        }
        else if ([elementName isEqualToString:@"kerning"])
        {
            int first  = [[attributes valueForKey:@"first"] intValue];
            int second = [[attributes valueForKey:@"second"] intValue];
            float amount = [[attributes valueForKey:@"amount"] floatValue] / _fontTexture.scale;
            [[self charByID:second] addKerning:amount toChar:first];
        }
        else if ([elementName isEqualToString:@"info"])
        {
            _name = [[attributes valueForKey:@"face"] copy];
            _size = [[attributes valueForKey:@"size"] floatValue] / _fontTexture.scale;
            
            if ([[attributes valueForKey:@"smooth"] isEqualToString:@"0"])
                self.smoothing = SPTextureSmoothingNone;
        }
        else if ([elementName isEqualToString:@"common"])
        {
            _lineHeight = [[attributes valueForKey:@"lineHeight"] floatValue] / _fontTexture.scale;
        }
    }];
    
    if (!success)
        [NSException raise:SP_EXC_DATA_INVALID format:@"Error parsing font XML: %@",
                     parser.parserError.localizedDescription];
    
    return success;
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
    
    SPSprite *outerContainer = [SPSprite sprite];
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
    
    [outerContainer flatten];
    return outerContainer;
}

- (SPTextureSmoothing)smoothing
{
    return _fontTexture.smoothing;
}

- (void)setSmoothing:(SPTextureSmoothing)smoothing
{
    _fontTexture.smoothing = smoothing;
}

#pragma mark - Mini Font

NSString *MiniFontXmlDataBase64 =
   @"H4sIAAAAAAAAA7Wc3XIbKRCF7/MUKt2nPM0/VXau8wZ7rbXlWLW2lFp5f7JPvxpxxgHBiEGhb1yyYn0+6Qb60DC+fz7s37"
    "98Wq3ud/vnw+p587h9WL/t9rv16rj77/TarVe/H16fHtbDerV737zuHs8vj2+Hw/vL+PLu/OnHw9vbYb963e23X7e7by/v"
    "4ZOb4wlhTz/+uHnd/vawJuHwzdeHtVHr1ffNt+3x9P746vGP7VNEfNn8eVw9Hv7an1jkaT2+i/dXu6fxPb1e/Xv+7I/z13"
    "92T6Ok07svkOBPP3B4fj5u38+if0yvP4vTP2ye/t7sx/+uCb8xZovBn9mWg00y6JYccA24v4CrOnyI2brEDgEXqj+bvAjs"
    "S91RUNxcUKgSFPIhKFKzwNUZrq6Mw1+A2wC/MhBvhothOMP1lYH4C3AKcI6EiiGMFsORUEEhLJYjoYJCWCxLQimExbEklM"
    "JQdCwJJXeGe56EhsWcBpaMCgKdZ46aQM+qhSzTR+IMXpTwCvhL8aIPHiVaDMvw87Ep0OUpNJEBKAbezsDrC6+JDUATe6iy"
    "fWIAmuB155IagK7KBYXhIjQHXIR1V96Szzo8KJdZQlUjvGSMRBjmSrDATWIBOsPDoq5ZlMtQjjSLchnGueFRHkaL4VEeRo"
    "tlUa5Sf9EZDn/Bozwk1PEoDwn1PMpDQj2P8sm8sEjXQ2peOtNhjYhH+4V3aaKLCp0E6qjItMtGe6FK9KR34buyDdZ0BrYY"
    "AtsvZCd2MUlowc/R5HXlJV005lPmcIWBbm5gU41NieXqyvaBPY3CvmyZuLmubILhGht+KZzKcGoYhi4ERQ6X7MgpmhsNNB"
    "k0i7KRsgBe3VZYmzjFvsoRFpWFfAFc1uDYV2h1CVeN8NJii8aFzmZQFzicIoty7P4Ni3ITwmJvUV4rcEKElou9RTlV4cG1"
    "uFuUV+EyxNxxxFygUHgW5SpUOM8Scy3g5XiC7kC/Vvtj+ufZFb1Q+zVc7tXavyinJdcipybatep/s3YhLfDXDMCiwJdckX"
    "eRVRz362D7n2y9ZA2goQSHLcrorpHuC1U6hAW9v4htG9muVOtcbC96w31sAfrCMY+UumSbRrYtFYxgunSWzg5wMQTlOgt5"
    "B7iTkI4jnb50k3RcIrZuZBeMkUGjOItKD7aNq2hnNk5cstnZgx3mj8/mTwe2nToWHMm001kORzYt6jNxpNOmJy2d4TYqQW"
    "PjtSMaLpQDnRyz9GU7jELPwcZVCM3BxuaWI5UuOWLpzMYJC0succDCkkvUTJZchvFtOHIJX2g4comes+XIJTrOliOX2F85"
    "jlzi2pbnyCX65J4ll9hZDSzJtMmWsy9cYVtFHOlUUC448gmnDHSxy3fztBdxNe6KnjbJkoGtkjsPnXXrpBr31S2SatyVTd"
    "j0SI5kEhy+4sgmWZUU5L5wuCvNkU9BJinJfeFYVAxHQhFym+VTNbILrUOb7JD7stEccxy6CfdjHYdwws07z6Mcx7QcynEL"
    "/KPkd4Xj8G3agHcOi5/uI3BIF2La33NoFx/3EVgGDBausG6N91ny3v4idqH7bsIs0hzoEHHPgKapzyQ54Nhy4uZKX7iQoT"
    "aLpclMDjsSevGSRtKdiOiiUXrpIgWUOwa2TTofEZsa2cWgwGtlg6ULPNQ4mUW8Axy3KGU2EGfYs0OldAXE4JpGNj9bhRfh"
    "6Nrw5DOxtxE8OgBSM/DkNLJ0uoTHEXSmvANcSKy2Wcw7wH1iQCO2amSXjBweuBMMbBqSS7Gd4XhcyLEox+NCjkd5WLU8j3"
    "JYUB7l02UEFuliOmJi0f5hEzm0C+SUcmvRgz41zQTPkIkbW7p44XYRu2jnXORC29h1q+gjG9qZjYMP2NAITo3wQplDfaYs"
    "KFFDQS4JeLGJQ7EL7Q2HCbU3wFUNjnsrMgt5F+Um9kTlwTIHrw0WPOSgMuGizjYVv6VxbcVcGYcxmxom5/QEtbtkR4uKWL"
    "RhKV61DxHXWVRm6C1LFp4T0plyWWfXhOMJRDzgVM7mInbJPeP82mRTvwscV3myqCyA2wocm1ubLSvUKLywHuIPSthrE5+W"
    "6C61+sHO5r2qs1VlFBL2trgn1BmOi0Lu2ooVw2cnZ1E5LGgW8hl403JoYgdaHipzbFMZKoSLFD6LygK4qsDx3CSWWvOBHn"
    "6ihxk0idIEur8b2ccvn+7vzn/v5X/zg7A/9kUAAA==";

NSString *MiniFontImgDataBase64 =
   @"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"
    "4Y5y93IvdO/2kPMI9Sj3eOKp6cnzrPec8LLyWuvV4Y3x9vXe6T3AVGWymbXMCR8bn/U+l33JvsG+5b5P/Qz9RH7ty+HlPs"
    "t3LR9cobNCsKLFH/gz/Xf5Pw7QC0gN+DUQGxgQWBH4LMg8aF1QVzA1eE1wXfBUiGvI9pBHofqh4tDOMOmw6LDasA/h7uEl"
    "4UMRSyLWR9yMVI7kR7ZG4aLCoo5FTa70WLln5Wi0VXRBdP8qvVVZq66vVl6dtPrcGuk1rDWnYzAx4TF1MV9Y/qwq1mQsM3"
    "Z/7ATbjb2X/YrjzNnNGeM6cEu4z+Mc4kriXvAceLt4Y/FO8aXx43w3fjn/TYJ3wqGED4n+idWJM0nhSY3J+OSY5DaBnCBR"
    "cDlFLSUrpVdoJCwQDqXape5JnRD5io6lQWmr0lrT5RExc0usL/5BPJzhmFGR8TEzLPN0lmyWIOtWtmH21uznOZ45P69Fr2"
    "Wv7VynsW7TuuH1LusrN0AbYjd0btTamL9xNNcrt2YTcVPipt/yzPJK8t5vDt/cnq+an5s/8oPXD/UFUgWigoEt9lsO/Yj+"
    "kf9j91bLrfu2fivkFN4oMisqLfpSzC6+8ZP5T2U/zWyL29a93Xr7wR3YHYId/TuddtaUyJbklIzsWr6reTd9d+Hu93vW7L"
    "leurT00F7iXvHeoTK/stZ92vt27PtSHl/eV+Fa0bhfZf/W/R8OcA7cOeh8sOGQ6qGiQ58P8w/fr/SqbK7SrSo9gj2SceTZ"
    "0bCjXT8zfq49pnys6NjXakH1UE1QzeVam9raOpW67fVwvbh+7Hj08Z4T7idaG0waKhtpjUUnwUnxyZe/xPzSf8r3VOdpxu"
    "mGMzpn9jdRmwqboebs5omW+Jah1sjW3jafts52+/amX01/rT6rcbbinMK57eeJ5/PPz1zIuTDZIewYv8i7ONK5pvPRpYhL"
    "9y4HXu6+4nvl2lXPq5e6XLouXHO4dva63fW2G4wbLTetbzbfsrrV9JvVb03d1t3Nt21ut/bY9rT3Lus9f8fpzsW77nev3m"
    "Peu9m3oq+3P7T//kD0wNB9zv0XD5IevHmY8XD6Ue4gZrDwsczj0icqT6p+N/i9cch66Nyw+/Ctp8FPH42wR179kfbHl9H8"
    "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"
    "5ErkJggg==";

- (id)initWithMiniFont
{
    NSData *xmlData = [[NSData dataWithBase64EncodedString:MiniFontXmlDataBase64] gzipInflate];
    NSData *imgData =  [NSData dataWithBase64EncodedString:MiniFontImgDataBase64];
    SPTexture *texture = [[SPTexture alloc] initWithContentsOfImage:[UIImage imageWithData:imgData]];
    return [self initWithContentsOfData:xmlData texture:texture];
}

@end
