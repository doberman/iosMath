//
//  MTLine.m
//  iosMath
//
//  Created by Kostub Deshmukh on 8/27/13.
//  Copyright (C) 2013 MathChat
//
//  This software may be modified and distributed under the terms of the
//  MIT license. See the LICENSE file for details.
//

#import <CoreText/CoreText.h>

#import "MTMathListDisplay.h"
#import "MTFontMathTable.h"
#import "MTFontManager.h"
#import "MTFont+Internal.h"
#import "MTMathListDisplayInternal.h"

static BOOL isIos6Supported() {
    static BOOL initialized = false;
    static BOOL supported = false;
    if (!initialized) {
        NSString *reqSysVer = @"6.0";
        NSString *currSysVer = [UIDevice currentDevice].systemVersion;
        if ([currSysVer compare:reqSysVer options:NSNumericSearch] != NSOrderedAscending) {
            supported = true;
        }
        initialized = true;
    }
    return supported;
}

#pragma mark MTDisplay

@implementation MTDisplay

- (void)draw:(CGContextRef)context
{
}

- (CGRect) displayBounds
{
    return CGRectMake(self.position.x, self.position.y - self.descent, self.width, self.ascent + self.descent);
}

- (id)debugQuickLookObject
{
    CGSize size = CGSizeMake(self.width, self.ascent + self.descent);
    UIGraphicsBeginImageContext(size);
    
    // get a reference to that context we created
    CGContextRef context = UIGraphicsGetCurrentContext();
    // translate/flip the graphics context (for transforming from CG* coords to UI* coords
    CGContextTranslateCTM(context, 0, size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    // move the position to (0,0)
    CGContextTranslateCTM(context, -self.position.x, -self.position.y);
    
    // Move the line up by self.descent
    CGContextTranslateCTM(context, 0, self.descent);
    // Draw self on context
    [self draw:context];
    
    // generate a new UIImage from the graphics context we drew onto
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    return img;
}

@end

#pragma mark - MTCTLine

@implementation MTCTLineDisplay

- (instancetype)initWithString:(NSAttributedString*) attrString position:(CGPoint)position range:(NSRange) range font:(MTFont*) font atoms:(NSArray<MTMathAtom*>*) atoms
{
    self = [super init];
    if (self) {
        self.position = position;
        self.attributedString = attrString;
        self.range = range;
        _atoms = atoms;
        // We can't use typographic bounds here as the ascent and descent returned are for the font and not for the line.
        self.width = CTLineGetTypographicBounds(_line, NULL, NULL, NULL);
        if (isIos6Supported()) {
            CGRect bounds = CTLineGetBoundsWithOptions(_line, kCTLineBoundsUseGlyphPathBounds);
            self.ascent = MAX(0, CGRectGetMaxY(bounds) - 0);
            self.descent = MAX(0, 0 - CGRectGetMinY(bounds)) + 7.0;
            // TODO: Should we use this width vs the typographic width? They are slightly different. Don't know why.
            // _width = CGRectGetMaxX(bounds);
        } else {
            // Our own implementation of the ios6 function to get glyph path bounds.
            [self computeDimensions:font];
        }
    }
    return self;
}

- (void) setAttributedString:(NSAttributedString*) attrString
{
    if (_line) {
        CFRelease(_line);
    }
    _attributedString = [attrString copy];
    _line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)(_attributedString));
}

- (void) setTextColor:(UIColor *)textColor
{
    [super setTextColor:textColor];
    NSMutableAttributedString* attrStr = self.attributedString.mutableCopy;
    [attrStr addAttribute:(NSString*)kCTForegroundColorAttributeName value:(id)self.textColor.CGColor
                    range:NSMakeRange(0, attrStr.length)];
    self.attributedString = attrStr;
}

- (void) computeDimensions:(MTFont*) font
{
    NSArray* runs = (__bridge NSArray *)(CTLineGetGlyphRuns(_line));
    for (id obj in runs) {
        CTRunRef run = (__bridge CTRunRef)(obj);
        CFIndex numGlyphs = CTRunGetGlyphCount(run);
        CGGlyph glyphs[numGlyphs];
        CTRunGetGlyphs(run, CFRangeMake(0, numGlyphs), glyphs);
        CGRect bounds = CTFontGetBoundingRectsForGlyphs(font.ctFont, kCTFontHorizontalOrientation, glyphs, NULL, numGlyphs);
        CGFloat ascent = MAX(0, CGRectGetMaxY(bounds) - 0);
        // Descent is how much the line goes below the origin. However if the line is all above the origin, then descent can't be negative.
        CGFloat descent = MAX(0, 0 - CGRectGetMinY(bounds));
        if (ascent > self.ascent) {
            self.ascent = ascent;
        }
        if (descent > self.descent) {
            self.descent = descent;
        }
    }
}

- (void)dealloc
{
    CFRelease(_line);
}

- (void)draw:(CGContextRef)context
{
    CGContextSaveGState(context);
    
    CGContextSetTextPosition(context, self.position.x, self.position.y);
    CTLineDraw(_line, context);
    
    CGContextRestoreGState(context);
}

@end

#pragma mark - MTLine

@implementation MTMathListDisplay {
    NSUInteger _index;
}
@synthesize shiftDown;

- (instancetype) initWithDisplays:(NSArray<MTDisplay*>*) displays range:(NSRange) range
{
    self = [super init];
    if (self) {
        _subDisplays = [displays copy];
        self.position = CGPointZero;
        _type = kMTLinePositionRegular;
        _index = NSNotFound;
        self.range = range;
        [self recomputeDimensions];
    }
    return self;
}

- (void) setType:(MTLinePosition) type
{
    _type = type;
}

- (void) setIndex:(NSUInteger) index
{
    _index = index;
}

- (void) setTextColor:(UIColor *)textColor
{
    // Set the color on all subdisplays
    [super setTextColor:textColor];
    for (MTDisplay* displayAtom in self.subDisplays) {
        // set the global color, if there is no local color
        if(displayAtom.localTextColor == nil) {
            displayAtom.textColor = textColor;
        } else {
            displayAtom.textColor = displayAtom.localTextColor;
        }

    }
}

- (CGFloat)shiftBottom {
    return self.shiftDown;
}
- (void)draw:(CGContextRef)context
{
    CGContextSaveGState(context);
    
    // Make the current position the origin as all the positions of the sub atoms are relative to the origin.
    CGContextTranslateCTM(context, self.position.x, self.position.y-self.shiftDown);
    CGContextSetTextPosition(context, 0, 0);
    
    // draw each atom separately
    for (MTDisplay* displayAtom in self.subDisplays) {
        [displayAtom draw:context];
    }
    
    CGContextRestoreGState(context);
}

- (void) recomputeDimensions
{
    CGFloat max_ascent = 0;
    CGFloat max_descent = 0;
    CGFloat max_width = 0;
    for (MTDisplay* atom in self.subDisplays) {
        CGFloat ascent = MAX(0, atom.position.y + atom.ascent);
        if (ascent > max_ascent) {
            max_ascent = ascent;
        }
        
        CGFloat descent = MAX(0, 0 - (atom.position.y - atom.descent));
        if (descent > max_descent) {
            max_descent = descent;
        }
        CGFloat width = atom.width + atom.position.x;
        if (width > max_width) {
            max_width = width;
        }
    }
    self.ascent = max_ascent;
    self.descent = max_descent;
    self.width = max_width;
}


@end

#pragma mark - MTFractionDisplay

@implementation MTFractionDisplay

- (instancetype)initWithNumerator:(MTMathListDisplay*) numerator denominator:(MTMathListDisplay*) denominator whole:(MTMathListDisplay*) whole position:(CGPoint) position range:(NSRange) range
{
    self = [super init];
    if (self) {
        _numerator = numerator;
        _denominator = denominator;
        _whole = whole;
        self.position = position;
        self.range = range;
        NSAssert(self.range.length == 1, @"Fraction range length not 1 - range (%lu, %lu)", (unsigned long)range.location, (unsigned long)range.length);
    }
    return self;
}

- (CGFloat)ascent
{
    return _whole.ascent+_numerator.ascent + self.numeratorUp;
}

- (CGFloat)descent
{
    return _whole.descent+_denominator.descent + self.denominatorDown;
}

- (CGFloat)width
{
    return MAX(_numerator.width, _denominator.width) + [self wholeWidth];
}

- (CGFloat)wholeWidth
{
    return _whole.width;
}

- (void)setDenominatorDown:(CGFloat)denominatorDown
{
    _denominatorDown = denominatorDown;
    [self updateDenominatorPosition];
}

- (void) setNumeratorUp:(CGFloat)numeratorUp
{
    _numeratorUp = numeratorUp;
    [self updateNumeratorPosition];
}

- (void) updateDenominatorPosition
{
    _denominator.position = CGPointMake(_whole.width + self.position.x + (self.width - [self wholeWidth] - _denominator.width)/2, self.position.y - self.denominatorDown);
}

- (void) updateNumeratorPosition
{
    _numerator.position = CGPointMake(_whole.width + self.position.x + (self.width - [self wholeWidth] - _numerator.width)/2, self.position.y + self.numeratorUp);
}

- (void) updateWholePosition
{
    _whole.position = CGPointMake(self.position.x, self.position.y);
}


- (void) setPosition:(CGPoint)position
{
    super.position = position;
    [self updateDenominatorPosition];
    [self updateNumeratorPosition];
    [self updateWholePosition];
}

- (void)setTextColor:(UIColor *)textColor
{
    [super setTextColor:textColor];
    _numerator.textColor = textColor;
    _denominator.textColor = textColor;
    _whole.textColor = textColor;
}

- (void)draw:(CGContextRef)context
{
    [_numerator draw:context];
    [_denominator draw:context];
    [_whole draw:context];
    
    CGContextSaveGState(context);
    
    [self.textColor setStroke];
    
    // draw the horizontal line
    UIBezierPath* path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(_whole.width + self.position.x, self.position.y + self.linePosition)];
    [path addLineToPoint:CGPointMake(_whole.width + self.position.x + self.width - [self wholeWidth], self.position.y + self.linePosition)];
    path.lineWidth = self.lineThickness;
    [path stroke];
    
    CGContextRestoreGState(context);
}

- (CGRect) displayBounds
{
    return CGRectMake(self.position.x, self.position.y - self.descent, self.width, self.ascent + self.descent);
}

@end

#pragma mark - MTRadicalDisplay

@implementation MTRadicalDisplay {
    MTDisplay* _radicalGlyph;
    CGFloat _radicalShift;
    BOOL drawTopLine;
}

- (instancetype)initWitRadicand:(MTMathListDisplay*) radicand glpyh:(MTDisplay*) glyph position:(CGPoint) position range:(NSRange) range
{
    self = [super init];
    if (self) {
        _radicand = radicand;
        _radicalGlyph = glyph;
        _radicalShift = 0;
        
        self.position = position;
        self.range = range;
    }
    return self;
}

- (void) setDegree:(MTMathListDisplay *)degree fontMetrics:(MTFontMathTable*) fontMetrics
{
    // sets up the degree of the radical
    CGFloat kernBefore = fontMetrics.radicalKernBeforeDegree;
    CGFloat kernAfter = fontMetrics.radicalKernAfterDegree;
    CGFloat raise = fontMetrics.radicalDegreeBottomRaisePercent * (self.ascent - self.descent);
    
    // The layout is:
    // kernBefore, raise, degree, kernAfter, radical
    _degree = degree;
    
    // the radical is now shifted by kernBefore + degree.width + kernAfter
    _radicalShift = kernBefore + degree.width + kernAfter;
    if (_radicalShift < 0) {
        // we can't have the radical shift backwards, so instead we increase the kernBefore such
        // that _radicalShift will be 0.
        kernBefore -= _radicalShift;
        _radicalShift = 0;
    }
    
    // Note: position of degree is relative to parent.
    self.degree.position = CGPointMake(self.position.x + kernBefore, self.position.y + raise);
    // Update the width by the _radicalShift
    self.width = _radicalShift + _radicalGlyph.width + self.radicand.width;
    // update the position of the radicand
    [self updateRadicandPosition];
}

- (void) setPosition:(CGPoint)position
{
    super.position = position;
    [self updateRadicandPosition];
}

- (void) updateRadicandPosition
{
    // The position of the radicand includes the position of the MTRadicalDisplay
    // This is to make the positioning of the radical consistent with fractions and
    // have the cursor position finding algorithm work correctly.
    // move the radicand by the width of the radical sign
    self.radicand.position = CGPointMake(self.position.x + _radicalShift + _radicalGlyph.width, self.position.y);
}

- (CGFloat)ascent
{
    if(drawTopLine == false){
        return _radicand.ascent+_degree.ascent;
    }
    return super.ascent;
}

- (CGFloat)descent
{
    return _radicand.descent+_degree.descent;
}

- (void)setTextColor:(UIColor *)textColor
{
    [super setTextColor:textColor];
    self.radicand.textColor = textColor;
    self.degree.textColor = textColor;
}

- (void)draw:(CGContextRef)context
{
    // draw the radicand & degree at its position
    [self.radicand draw:context];
    [self.degree draw:context];
    
    CGContextSaveGState(context);
    [self.textColor setStroke];
    [self.textColor setFill];
    
    // Make the current position the origin as all the positions of the sub atoms are relative to the origin.
    CGContextTranslateCTM(context, self.position.x + _radicalShift, self.position.y);
    CGContextSetTextPosition(context, 0, 0);
    
    // Draw the glyph.
    [_radicalGlyph draw:context];
    
    // Draw the VBOX
    // for the kern of, we don't need to draw anything.
    CGFloat heightFromTop = _topKern;
    
    // draw the horizontal line with the given thickness
    UIBezierPath* path = [UIBezierPath bezierPath];
    drawTopLine = true;
    CGPoint lineStart = CGPointMake(_radicalGlyph.width, self.ascent - heightFromTop - self.lineThickness / 2); // subtract half the line thickness to center the line
    drawTopLine = false;
    CGPoint lineEnd = CGPointMake(lineStart.x + self.radicand.width, lineStart.y);
    [path moveToPoint:lineStart];
    [path addLineToPoint:lineEnd];
    path.lineWidth = _lineThickness;
    path.lineCapStyle = kCGLineCapRound;
    [path stroke];
    
    CGContextRestoreGState(context);
}

@end

#pragma mark - MTExponentDisplay

@implementation MTExponentDisplay {
}

- (instancetype)initWithExponentDisplays:(NSMutableDictionary*) displays shiftUp:(CGFloat)shiftUp shiftDown:(CGFloat)shiftDown position:(CGPoint) position range:(NSRange) range;
{
    self = [super init];
    if (self) {
        _exponentBase =  [displays valueForKey:@"ExponentBase"];
        _expSuperscript = [displays valueForKey:@"ExponentSuperscript"];
        _expSubscript = [displays valueForKey:@"ExponentSubscript"];
        _prefixedSubscript = [displays valueForKey:@"ExponentBeforeSubscript"];
        _superScriptUp = shiftUp;
        _subScriptDown = shiftDown;
        self.position = position;
        self.range = range;
    }
    return self;
}

- (CGRect) displayBounds
{
    return CGRectMake(self.position.x + _prefixedSubscript.width, self.position.y, self.width, self.ascent + self.descent);
}

- (CGFloat)width
{
    if(_expSuperscript && _expSubscript){
        return _exponentBase.width + _expSuperscript.width + _prefixedSubscript.width;
    }
    return _exponentBase.width + _expSuperscript.width + _expSubscript.width + _prefixedSubscript.width;
}

- (CGFloat)ascent
{
    CGFloat maxAscentVal = MAX(self.expSuperscript.ascent, _superScriptUp);
    return _exponentBase.ascent+ maxAscentVal;
}

- (CGFloat)descent
{
    CGFloat maxDescentVal = MAX(self.prefixedSubscript.descent, self.expSubscript.descent);
    maxDescentVal = MAX(maxDescentVal, _subScriptDown);
    return _exponentBase.descent +maxDescentVal;
}

- (void) setPosition:(CGPoint)position
{
    super.position = position;
    [self updateExponentPosition];
    _expSuperscript.position = CGPointMake(self.position.x + _exponentBase.width , self.position.y + _superScriptUp);
    _expSubscript.position = CGPointMake(self.position.x + _exponentBase.width + _prefixedSubscript.width , self.position.y -_subScriptDown);
    _prefixedSubscript.position = CGPointMake(self.position.x , self.position.y - _subScriptDown);
}

- (void) updateExponentPosition
{
    if(self.prefixedSubscript){
        _exponentBase.position = CGPointMake(self.position.x + _prefixedSubscript.width, self.position.y);
    }
    else{
        _exponentBase.position = CGPointMake(self.position.x, self.position.y);
    }
}

- (void)setTextColor:(UIColor *)textColor
{
    [super setTextColor:textColor];
    self.exponentBase.textColor = textColor;
    self.expSuperscript.textColor = textColor;
    self.expSubscript.textColor = textColor;
    self.prefixedSubscript.textColor = textColor;
}

- (void)draw:(CGContextRef)context
{
    // draw the exponents at its position
    [self.exponentBase draw:context];
    if(self.expSuperscript){
        [self.expSuperscript draw:context];
    }
    if(self.expSubscript){
        [self.expSubscript draw:context];
    }
    if(self.prefixedSubscript){
        [self.prefixedSubscript draw:context];
    }
    CGContextSaveGState(context);
    [self.textColor setStroke];
    [self.textColor setFill];
    
    CGContextRestoreGState(context);
}

@end


#pragma mark - MTOrderedPairDisplay

@implementation MTOrderedPairDisplay

- (instancetype)initWithLeftOperand:(MTMathListDisplay*) leftOperand right:(MTMathListDisplay*) rightOperand delimiters:(NSMutableArray*)delimiters position:(CGPoint) position range:(NSRange) range
{
    self = [super init];
    if (self) {
        _leftPair = leftOperand;
        _rightPair = rightOperand;
        _leftBoundary = [delimiters objectAtIndex:0];
        _seperator = [delimiters objectAtIndex:1];
        _rightBoundary = [delimiters objectAtIndex:2];
        self.position = position;
        self.range = range;
    }
    return self;
}


- (CGFloat)width
{
    return self.boundaryWidth + _leftPair.width +_rightPair.width+5.0;
}

- (CGFloat)boundaryWidth{
    return _leftBoundary.width+_rightBoundary.width + _seperator.width;
}

- (void) updateRightOperandPosition
{
    _rightPair.position = CGPointMake(self.seperator.position.x+self.seperator.width+2.0, self.position.y);
}

- (void) updateLeftOperandPosition
{
    _leftPair.position = CGPointMake(self.leftBoundary.position.x+self.leftBoundary.width, self.position.y );
}

- (void) updateRightBoundaryPosition
{
    CGFloat maxXForRightBoundary =  self.rightPair.position.x+self.rightPair.width;
    _rightBoundary.position = CGPointMake(maxXForRightBoundary, self.position.y);
}

- (void) updateLeftBoundaryPosition
{
    _leftBoundary.position = CGPointMake(self.position.x, self.position.y);
}

- (void)updateSeperatorPosition {
    _seperator.position = CGPointMake(self.leftPair.position.x+self.leftPair.width+2.0, self.position.y-self.displayBounds.size.height-10.0);
}

- (void) setPosition:(CGPoint)position
{
    super.position = position;
    [self updateLeftBoundaryPosition];
    [self updateLeftOperandPosition];
    [self updateSeperatorPosition];
    [self updateRightOperandPosition];
    [self updateRightBoundaryPosition];
}

- (void)setTextColor:(UIColor *)textColor
{
    [super setTextColor:textColor];
    _leftPair.textColor = textColor;
    _rightPair.textColor = textColor;
}

- (void)draw:(CGContextRef)context
{
    if (self.leftBoundary != nil) [self.leftBoundary draw:context];
    [_leftPair draw:context];
    [_seperator draw:context];
    [_rightPair draw:context];
    if (self.rightBoundary != nil) [self.rightBoundary draw:context];
    
    CGContextSaveGState(context);
    CGAffineTransform save = CGContextGetTextMatrix(context);
    CGContextTranslateCTM(context, 0.0f, self.displayBounds.size.height);
    CGContextScaleCTM(context, 1.0f, -1.0f);
    CGContextSetTextMatrix(context, save);
    CGContextRestoreGState(context);
    
}

@end

#pragma mark - MTBinomialMatrixDisplay

@implementation MTBinomialMatrixDisplay

CGFloat interElementPadding = 10.0;

//- (instancetype)initWithDisplays:(NSMutableArray*) mathlistDisplays position:(CGPoint) position range:(NSRange) range
- (instancetype)initWithDisplays:(NSMutableArray*) mathlistDisplays rowShiftUp:(CGFloat)shiftUp rowShiftDown:(CGFloat)shiftDown position:(CGPoint) position range:(NSRange) range
{
    self = [super init];
    
    if (self) {
        _row0Column0 = [mathlistDisplays objectAtIndex:0];
        _row0Column1 = [mathlistDisplays objectAtIndex:1];
        _row1Column0 = [mathlistDisplays objectAtIndex:2];
        _row1Column1 = [mathlistDisplays objectAtIndex:3];
        _leftBoundary = [mathlistDisplays objectAtIndex:4];
        _rightBoundary = [mathlistDisplays objectAtIndex:5];
        _row1ShiftUp = shiftUp;
        _row2ShiftDown = shiftDown;
        self.position = position;
        self.range = range;
    }
    return self;
}


- (CGFloat)width
{
    NSArray *unsortedDisplayWidths = @[@((self.row0Column0.width)+(self.row0Column1.width) + self.boundaryWidth), @((self.row1Column0.width)+(self.row1Column1.width) + self.boundaryWidth), @((self.row0Column0.width)+(self.row1Column1.width) + self.boundaryWidth),@((self.row0Column1.width)+(self.row1Column0.width) + self.boundaryWidth)];
    NSNumber *maxWidthForDisplay = [unsortedDisplayWidths valueForKeyPath:@"@max.self"];
    return maxWidthForDisplay.floatValue;
}
- (CGFloat)boundaryWidth{
    return self.leftBoundary.width+self.rightBoundary.width+interElementPadding;
}
- (CGRect) displayBounds
{
    return CGRectMake(self.position.x, self.position.y - self.descent, self.width, self.ascent+self.descent);
}

- (CGFloat)ascent
{
    CGFloat ascent =  MAX(self.row0Column1.ascent, self.row0Column0.ascent);
    return ascent + self.row1ShiftUp;
}

- (CGFloat)descent
{
    CGFloat descent =  MAX(self.row1Column0.descent, self.row1Column1.descent);
    return descent + self.row2ShiftDown;
}

- (void) updateRightBoundaryPosition
{
    CGFloat maxXForRightBoundary =  MAX(self.row0Column1.position.x+self.row0Column1.width, self.row1Column1.position.x+self.row1Column1.width);
    
    _rightBoundary.position = CGPointMake(maxXForRightBoundary, self.position.y);
    
}

- (void) updateLeftBoundaryPosition
{
    _leftBoundary.position = CGPointMake(self.position.x, self.position.y );
}


// Row 1 position
- (void) updateRow1Col1Position
{
    CGFloat maxXValueForCol1 = MAX(CGRectGetMaxX(self.row0Column0.displayBounds) ,CGRectGetMaxX(self.row1Column0.displayBounds) );
    _row1Column1.position = CGPointMake(maxXValueForCol1 + interElementPadding , self.position.y - self.row2ShiftDown);
    
}

- (void) updateRow1Col0Position
{
    _row1Column0.position = CGPointMake(self.position.x+self.leftBoundary.width , self.position.y - self.row2ShiftDown);
}

// Row 0 position
- (void) updateRow0Col0Position
{
    _row0Column0.position = CGPointMake(self.position.x+self.leftBoundary.width , self.position.y + self.row1ShiftUp);
}

- (void) updateRow0Col1Position
{
    CGFloat maxXValueForCol1 = MAX(CGRectGetMaxX(self.row0Column0.displayBounds) ,CGRectGetMaxX(self.row1Column0.displayBounds) );
    _row0Column1.position = CGPointMake(maxXValueForCol1+interElementPadding, self.position.y + self.row1ShiftUp);
}


- (void) setPosition:(CGPoint)position
{
    super.position = position;
    [self updateLeftBoundaryPosition];
    /* Column 0 Position */
    [self updateRow0Col0Position];
    [self updateRow1Col0Position];
    
    /* Column 1 Position */
    [self updateRow0Col1Position];
    [self updateRow1Col1Position];
    [self updateRightBoundaryPosition];
}

- (void)setTextColor:(UIColor *)textColor
{
    [super setTextColor:textColor];
    _row0Column0.textColor = _row0Column1.textColor = _row1Column0.textColor = _row1Column1.textColor = _leftBoundary.textColor = _rightBoundary.textColor = textColor;
}

- (void)draw:(CGContextRef)context
{
    if (self.leftBoundary != nil) [self.leftBoundary draw:context];
    [_row0Column0 draw:context];
    [_row0Column1 draw:context];
    [_row1Column0 draw:context];
    [_row1Column1 draw:context];
    if (self.rightBoundary != nil) [self.rightBoundary draw:context];
    
    CGContextSaveGState(context);
    
    CGContextRestoreGState(context);
    
}

@end

#pragma mark - MTAbsoluteValueDisplay

@implementation MTAbsoluteValueDisplay

- (instancetype)initWithValue:(MTMathListDisplay*) absHolder position:(CGPoint) position leftBoundary:(MTDisplay*) leftBoundary rightBoundary:(MTDisplay*)rightBoundary range:(NSRange) range
{
    self = [super init];
    if (self) {
        _absPlaceholder = absHolder;
        _leftBoundary = leftBoundary;
        _rightBoundary = rightBoundary;
        self.position = position;
        self.range = range;
    }
    return self;
}

- (CGFloat)width
{
    CGFloat valueWidth = self.boundaryWidth + _absPlaceholder.width;
    return valueWidth;
}

- (CGFloat)boundaryWidth{
    return _leftBoundary.width+_rightBoundary.width;
}

- (void) updateRightBoundaryPosition
{
    CGFloat maxXForRightBoundary =  _absPlaceholder.position.x+_absPlaceholder.width;
    _rightBoundary.position = CGPointMake(maxXForRightBoundary, self.position.y);
}

- (void) updateLeftBoundaryPosition
{
    _leftBoundary.position = CGPointMake(self.position.x, self.position.y);
}
- (void) setPosition:(CGPoint)position
{
    super.position = position;
    [self updateLeftBoundaryPosition];
    if(_leftBoundary != nil){
        _absPlaceholder.position = CGPointMake(_leftBoundary.position.x+_leftBoundary.width, self.position.y );
    }else{
        _absPlaceholder.position = CGPointMake(self.position.x, self.position.y);
    }
    [self updateRightBoundaryPosition];
}

- (void)setTextColor:(UIColor *)textColor
{
    [super setTextColor:textColor];
    _absPlaceholder.textColor = _leftBoundary.textColor = _rightBoundary.textColor = textColor;
}

- (void)draw:(CGContextRef)context
{
    [_leftBoundary draw:context];
    [_absPlaceholder draw:context];
    [_rightBoundary draw:context];
    CGContextSaveGState(context);
    
    CGAffineTransform save = CGContextGetTextMatrix(context);
    CGContextTranslateCTM(context, 0.0f, self.displayBounds.size.height);
    CGContextScaleCTM(context, 1.0f, -1.0f);
    CGContextSetTextMatrix(context, save);
    CGContextRestoreGState(context);
    
}

@end

#pragma mark - MTInnerDisplay

@implementation MTInnerDisplay

- (instancetype)initWithValue:(MTMathListDisplay*) innerList left:(MTDisplay *)left right:(MTDisplay *)right position:(CGPoint)position range:(NSRange)range
{
    self = [super init];
    if (self) {
        _innerList = innerList;
        _left = left;
        _right = right;
        self.position = position;
        self.range = range;
    }
    return self;
}

- (void)draw:(CGContextRef)context
{
    CGContextSaveGState(context);
    
    if (self.left != nil) [self.left draw:context];
    [self.innerList draw:context];
    if (self.right != nil) [self.right draw:context];
    
    
    CGContextRestoreGState(context);
    
}

- (void)setTextColor:(UIColor *)textColor
{
    [super setTextColor:textColor];
    _innerList.textColor = textColor;
    _left.textColor = textColor;
    _right.textColor = textColor;
}

- (void) setPosition:(CGPoint)position
{
    super.position = position;
    [self updateLeftOperatorPosition];
    [self updateInnerPosition];
    [self updateRightOperatorPosition];
}

- (void) updateInnerPosition
{
    if (_left == nil && _right != nil){
        self.innerList.position = CGPointMake(self.position.x, self.position.y);
    }
    else{
        self.innerList.position = CGPointMake(self.position.x + _left.width, self.position.y);
    }
}
- (void) updateRightOperatorPosition
{
    if (_right != nil) {
        _right.position = CGPointMake(self.innerList.width+self.innerList.position.x , self.position.y );
    }
}

- (void) updateLeftOperatorPosition
{
    _left.position = CGPointMake(self.position.x, self.position.y );
}

/*- (CGFloat)ascent
{
    CGFloat ascentValue = 0.0;
    if(self.left){
        ascentValue = self.left.ascent;
    } else if(self.right){
        ascentValue = self.right.ascent;
    }
    return ascentValue;
}

- (CGFloat)descent
{
    CGFloat descentValue = 0.0;
    if(self.left){
        descentValue = self.left.descent;
    } else if(self.right){
        descentValue = self.right.descent;
    }
    return descentValue;
}*/

@end

#pragma mark - MTGlyphDisplay

@implementation MTGlyphDisplay {
    CGGlyph _glyph;
    MTFont* _font;
}

@synthesize shiftDown;

- (instancetype)initWithGlpyh:(CGGlyph) glyph range:(NSRange) range font:(MTFont*) font
{
    self = [super init];
    if (self) {
        _font = font;
        _glyph = glyph;
        
        self.position = CGPointZero;
        self.range = range;
    }
    return self;
}

- (void)draw:(CGContextRef)context
{
    CGContextSaveGState(context);
    
    [self.textColor setFill];
    
    // Make the current position the origin as all the positions of the sub atoms are relative to the origin.
    CGContextTranslateCTM(context, self.position.x, self.position.y - self.shiftDown);
    CGContextSetTextPosition(context, 0, 0);
    
    CTFontDrawGlyphs(_font.ctFont, &_glyph, &CGPointZero, 1, context);
    
    CGContextRestoreGState(context);
}

- (CGFloat)ascent
{
    return super.ascent - self.shiftDown;
}

- (CGFloat)descent
{
    return super.descent + self.shiftDown;
}

@end

#pragma mark - MTGlyphConstructionDisplay

@implementation MTGlyphConstructionDisplay {
    CGGlyph *_glyphs;
    CGPoint *_positions;
    MTFont* _font;
    NSInteger _numGlyphs;
}

@synthesize shiftDown;

- (instancetype)initWithGlyphs:(NSArray<NSNumber *> *)glyphs offsets:(NSArray<NSNumber *> *)offsets font:(MTFont *)font
{
    self = [super init];
    if (self) {
        NSAssert(glyphs.count == offsets.count, @"Glyphs and offsets need to match");
        _numGlyphs = glyphs.count;
        _glyphs = malloc(sizeof(CGGlyph) * _numGlyphs);
        _positions = malloc(sizeof(CGPoint) * _numGlyphs);
        for (int i = 0; i < _numGlyphs; i++) {
            _glyphs[i] = glyphs[i].shortValue;
            _positions[i] = CGPointMake(0, offsets[i].floatValue);
        }
        _font = font;
        self.position = CGPointZero;
    }
    return self;
}

- (void)draw:(CGContextRef)context
{
    CGContextSaveGState(context);
    
    [self.textColor setFill];
    
    // Make the current position the origin as all the positions of the sub atoms are relative to the origin.
    CGContextTranslateCTM(context, self.position.x, self.position.y - self.shiftDown);
    CGContextSetTextPosition(context, 0, 0);
    
    // Draw the glyphs.
    CTFontDrawGlyphs(_font.ctFont, _glyphs, _positions, _numGlyphs, context);
    
    CGContextRestoreGState(context);
}

- (CGFloat)ascent
{
    return super.ascent - self.shiftDown;
}

- (CGFloat)descent
{
    return super.descent + self.shiftDown;
}

- (void)dealloc
{
    free(_glyphs);
    free(_positions);
}

@end

#pragma mark - MTLargeOpLimitsDisplay

@implementation MTLargeOpLimitsDisplay {
    CGFloat _limitShift;
    CGFloat _upperLimitGap;
    CGFloat _lowerLimitGap;
    CGFloat _extraPadding;
    
    MTDisplay *_nucleus;
}

- (instancetype) initWithNucleus:(MTDisplay*) nucleus upperLimit:(MTMathListDisplay*) upperLimit lowerLimit:(MTMathListDisplay*) lowerLimit limitShift:(CGFloat) limitShift extraPadding:(CGFloat) extraPadding boundaries:(NSMutableArray*)boundaries
{
    self = [super init];
    if (self) {
        _upperLimit = upperLimit;
        _upperLimit.type = kMTLinePositionSuperscript;
        _lowerLimit = lowerLimit;
        _lowerLimit.type = kMTLinePositionSubscript;
        _nucleus = nucleus;

        CGFloat maxWidth = MAX(nucleus.width, upperLimit.width);
        maxWidth = MAX(maxWidth, lowerLimit.width);

        if(boundaries.count > 0){
            _leftBoundary = [boundaries objectAtIndex:0];
            _holder = [boundaries objectAtIndex:1];
            _rightBoundary = [boundaries objectAtIndex:2];
        }
        _limitShift = limitShift;
        _upperLimitGap = 0;
        _lowerLimitGap = 0;
        _extraPadding = extraPadding;  // corresponds to \xi_13 in TeX
        self.width = maxWidth;
    }
    return self;
}

- (CGFloat)width {
    if(self.holder != nil){
        CGFloat maxWidth = _holder.width+self.boundaryWidth+_nucleus.width;
        return maxWidth;
    }
    CGFloat maxWidth = MAX(_nucleus.width, _upperLimit.width);
    maxWidth = MAX(maxWidth, _lowerLimit.width);
    return maxWidth;
}

- (CGFloat)boundaryWidth{
    return _leftBoundary.width+_rightBoundary.width;
}
- (CGFloat)ascent
{
    if (self.upperLimit) {
        return _nucleus.ascent + _extraPadding + self.upperLimit.ascent + _upperLimitGap + self.upperLimit.descent;
    } else {
        CGFloat maxAscent = MAX(_holder.ascent, _leftBoundary.ascent);
        return maxAscent;
    }
}

- (CGFloat)descent
{
    if (self.lowerLimit) {
        return _nucleus.descent + _extraPadding + _lowerLimitGap + self.lowerLimit.descent + self.lowerLimit.ascent;
    } else {
        CGFloat maxDescent = MAX(_holder.descent, _leftBoundary.descent);
        return maxDescent;
    }
}

- (void) updateRightBoundaryPosition
{
    CGFloat maxXForRightBoundary =  self.holder.position.x+self.holder.width;
    _rightBoundary.position = CGPointMake(maxXForRightBoundary, self.position.y);
}

- (void) updateLeftBoundaryPosition
{
    _leftBoundary.position = CGPointMake(_nucleus.position.x+_nucleus.width, self.position.y);
}

- (void)updateHolderPosition {
    
    _holder.position = CGPointMake(self.leftBoundary.position.x+self.leftBoundary.width, self.position.y);
}
- (void)setLowerLimitGap:(CGFloat)lowerLimitGap
{
    _lowerLimitGap = lowerLimitGap;
    [self updateLowerLimitPosition];
}

- (void) setUpperLimitGap:(CGFloat)upperLimitGap
{
    _upperLimitGap = upperLimitGap;
    [self updateUpperLimitPosition];
}

- (void)setPosition:(CGPoint)position
{
    super.position = position;
    [self updateLowerLimitPosition];
    [self updateUpperLimitPosition];
    [self updateNucleusPosition];
    [self updateLeftBoundaryPosition];
    [self updateHolderPosition];
    [self updateRightBoundaryPosition];
}

- (void) updateLowerLimitPosition
{
    if (self.lowerLimit) {
        // The position of the lower limit includes the position of the MTLargeOpLimitsDisplay
        // This is to make the positioning of the radical consistent with fractions and radicals
        // Move the starting point to below the nucleus leaving a gap of _lowerLimitGap and subtract
        // the ascent to to get the baseline. Also center and shift it to the left by _limitShift.
        self.lowerLimit.position = CGPointMake(self.position.x - _limitShift + (self.width - _lowerLimit.width)/2,
                                               self.position.y - _nucleus.descent - _lowerLimitGap - self.lowerLimit.ascent);
    }
}

- (void) updateUpperLimitPosition
{
    if (self.upperLimit) {
        // The position of the upper limit includes the position of the MTLargeOpLimitsDisplay
        // This is to make the positioning of the radical consistent with fractions and radicals
        // Move the starting point to above the nucleus leaving a gap of _upperLimitGap and add
        // the descent to to get the baseline. Also center and shift it to the right by _limitShift.
        self.upperLimit.position = CGPointMake(self.position.x + _limitShift + (self.width - self.upperLimit.width)/2,
                                               self.position.y + _nucleus.ascent + _upperLimitGap + self.upperLimit.descent);
    }
}

- (void) updateNucleusPosition
{
    // Center the nucleus
    if(_holder == nil){
    _nucleus.position = CGPointMake(self.position.x + (self.width - _nucleus.width)/2, self.position.y);
    } else {
        _nucleus.position = CGPointMake(self.position.x, self.position.y);
    }
}

- (void)setTextColor:(UIColor *)textColor
{
    [super setTextColor:textColor];
    self.upperLimit.textColor = self.lowerLimit.textColor = _nucleus.textColor = self.holder.textColor = self.leftBoundary.textColor = self.rightBoundary.textColor = textColor;
}

- (void)draw:(CGContextRef)context
{
    // Draw the elements.
    [self.upperLimit draw:context];
    [self.lowerLimit draw:context];
    [_nucleus draw:context];
    [self.leftBoundary draw:context];
    [self.holder draw:context];
    [self.rightBoundary draw:context];
}

@end

#pragma mark - MTLineDisplay

@implementation MTLineDisplay

- (instancetype)initWithInner:(MTMathListDisplay *)inner position:(CGPoint) position range:(NSRange)range
{
    self = [super init];
    if (self) {
        _inner = inner;
        
        self.position = position;
        self.range = range;
    }
    return self;
}

- (instancetype)initWithInner:(MTMathListDisplay *)inner position:(CGPoint)position range:(NSRange)range lineColor:(UIColor *)lineColor {
    self = [super init];
    if (self) {
        _inner = inner;
        
        self.position = position;
        self.range = range;
        
        _lineColor = lineColor;
    }
    return self;
}

- (void)setTextColor:(UIColor *)textColor
{
    [super setTextColor:textColor];
    _inner.textColor = textColor;
}

- (void)draw:(CGContextRef)context
{
    [self.inner draw:context];
    
    CGContextSaveGState(context);
    
    if (_lineColor != nil) {
        [_lineColor setStroke];
    } else {
        [self.textColor setStroke];
    }
    
    // draw the horizontal line
    UIBezierPath* path = [UIBezierPath bezierPath];
    CGPoint lineStart = CGPointMake(self.position.x, self.position.y + self.lineShiftUp);
    CGPoint lineEnd = CGPointMake(lineStart.x + self.inner.width, lineStart.y);
    [path moveToPoint:lineStart];
    [path addLineToPoint:lineEnd];
    path.lineWidth = self.lineThickness;
    [path stroke];
    
    CGContextRestoreGState(context);
}

- (void) setPosition:(CGPoint)position
{
    super.position = position;
    [self updateInnerPosition];
}

- (void) updateInnerPosition
{
    self.inner.position = CGPointMake(self.position.x, self.position.y);
}

@end

#pragma mark - MTAccentDisplay

@implementation MTAccentDisplay

- (instancetype)initWithAccent:(MTGlyphDisplay*) glyph accentee:(MTMathListDisplay*) accentee range:(NSRange) range
{
    self = [super init];
    if (self) {
        _accent = glyph;
        _accentee = accentee;
        _accentee.position = CGPointZero;
        self.range = range;
    }
    return self;
}

- (void)setTextColor:(UIColor *)textColor
{
    [super setTextColor:textColor];
    _accentee.textColor = textColor;
    _accent.textColor = textColor;
}

- (void) setPosition:(CGPoint)position
{
    super.position = position;
    [self updateAccenteePosition];
}

- (void) updateAccenteePosition
{
    self.accentee.position = CGPointMake(self.position.x, self.position.y);
}

- (void)draw:(CGContextRef)context
{
    [self.accentee draw:context];
    
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, self.position.x, self.position.y);
    CGContextSetTextPosition(context, 0, 0);
    
    [self.accent draw:context];
    
    CGContextRestoreGState(context);
}
@end

#pragma mark - MTImageDisplay

@implementation MTImageDisplay

- (instancetype)initWithImage:(UIImage *)image range:(NSRange)range {
    self = [super init];
    if (self) {
        _image = image;
        self.range = range;
    }
    return self;
}

- (CGFloat)width {
    return _image.size.width;
}

- (void)setPosition:(CGPoint)position {
    super.position = position;
}

- (void)setTextColor:(UIColor *)textColor {
    [super setTextColor:textColor];
}

- (void)draw:(CGContextRef)context {
    //[_image drawAtPoint:self.position];
    CGContextDrawImage(context, CGRectMake(self.position.x, self.position.y - 2, _image.size.width, _image.size.height), _image.CGImage);
}

@end

#pragma mark - MTUnderDisplay

@implementation MTUnderDisplay

- (instancetype)initWithPrimaryDisplay:(MTMathListDisplay *)primary secondaryDisplay:(MTMathListDisplay *)secondary position:(CGPoint)position range:(NSRange)range
{
    self = [super init];
    if (self) {
        _primary = primary;
        _secondary = secondary;
        self.position = position;
        self.range = range;
        NSAssert(self.range.length == 1, @"Under range length not 1 - range (%lu, %lu)", (unsigned long)range.location, (unsigned long)range.length);
    }
    return self;
}

- (CGFloat)ascent
{
    return _primary.ascent;
}

- (CGFloat)descent
{
    return _secondary.descent + self.denominatorDown;
}

- (CGFloat)width
{
    return MAX(_primary.width, _secondary.width);
}


- (void)setDenominatorDown:(CGFloat)denominatorDown
{
    _denominatorDown = denominatorDown;
    [self updateSecondaryPosition];
}


- (void) updateSecondaryPosition
{
    _secondary.position = CGPointMake(self.position.x, self.position.y - self.denominatorDown);
}

- (void) updatePrimaryPosition
{
    _primary.position = CGPointMake(self.position.x+(self.width - _primary.width)/2 , self.position.y);
}

- (void) setPosition:(CGPoint)position
{
    super.position = position;
    [self updateSecondaryPosition];
    [self updatePrimaryPosition];
}

- (void)setTextColor:(UIColor *)textColor
{
    [super setTextColor:textColor];
    _primary.textColor = textColor;
    _secondary.textColor = textColor;
}

- (void)draw:(CGContextRef)context
{
    [_secondary draw:context];
    [_primary draw:context];
    
    CGContextSaveGState(context);
    [self.textColor setStroke];
    CGContextRestoreGState(context);
}

- (CGRect) displayBounds
{
    return CGRectMake(self.position.x, self.position.y - self.descent, self.width, self.ascent + self.descent);
}

@end
