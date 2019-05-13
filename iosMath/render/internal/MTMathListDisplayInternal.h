//
//  MTMathListDisplay+Internal.h
//  iosMath
//
//  Created by Kostub Deshmukh on 6/21/16.
//
//  This software may be modified and distributed under the terms of the
//  MIT license. See the LICENSE file for details.
//

#import "MTMathListDisplay.h"

@interface MTDisplay ()

@property (nonatomic) CGFloat ascent;
@property (nonatomic) CGFloat descent;
@property (nonatomic) CGFloat width;
@property (nonatomic) NSRange range;
@property (nonatomic) BOOL hasScript;

@end

// The Downshift protocol allows an MTDisplay to be shifted down by a given amount.
@protocol DownShift <NSObject>

@property (nonatomic) CGFloat shiftDown;

@end

@interface MTMathListDisplay () <DownShift>

- (instancetype)init NS_UNAVAILABLE;

- (instancetype) initWithDisplays:(NSArray<MTDisplay*>*) displays range:(NSRange) range NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readwrite) MTLinePosition type;
@property (nonatomic, readwrite) NSUInteger index;

@end

@interface MTCTLineDisplay ()

- (instancetype)initWithString:(NSAttributedString*) attrString position:(CGPoint)position range:(NSRange) range font:(MTFont*) font atoms:(NSArray<MTMathAtom*>*) atoms NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

@interface MTFractionDisplay ()

- (instancetype)initWithNumerator:(MTMathListDisplay*) numerator denominator:(MTMathListDisplay*) denominator position:(CGPoint) position range:(NSRange) range NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic) CGFloat numeratorUp;
@property (nonatomic) CGFloat denominatorDown;
@property (nonatomic) CGFloat linePosition;
@property (nonatomic) CGFloat lineThickness;

@end

@interface MTOrderedPairDisplay ()

- (instancetype)initWithLeftOperand:(MTMathListDisplay*) leftOperand right:(MTMathListDisplay*) rightOperand delimiters:(NSMutableArray*)delimiters position:(CGPoint) position range:(NSRange) range NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic) CGFloat topKern;
@property (nonatomic) CGFloat lineThickness;

@end

@interface MTBinomialMatrixDisplay ()

- (instancetype)initWithDisplays:(NSMutableArray*) mathlistDisplays rowShiftUp:(CGFloat)shiftUp rowShiftDown:(CGFloat)shiftDown position:(CGPoint) position range:(NSRange) range;

- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic) CGFloat topKern;
@property (nonatomic) CGFloat lineThickness;
@property (nonatomic) CGFloat row1ShiftUp;
@property (nonatomic) CGFloat row2ShiftDown;

@end

@interface MTAbsoluteValueDisplay ()

- (instancetype)initWithValue:(MTMathListDisplay*) absHolder position:(CGPoint) position leftBoundary:(MTDisplay*) leftBoundary rightBoundary:(MTDisplay*)rightBoundary range:(NSRange) range

NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic) CGFloat topKern;
@property (nonatomic) CGFloat lineThickness;

@end


@interface MTRadicalDisplay ()

- (instancetype)initWitRadicand:(MTMathListDisplay*) radicand glpyh:(MTDisplay*) glyph position:(CGPoint) position range:(NSRange) range NS_DESIGNATED_INITIALIZER;

- (void) setDegree:(MTMathListDisplay *)degree fontMetrics:(MTFontMathTable*) fontMetrics;

@property (nonatomic) CGFloat topKern;
@property (nonatomic) CGFloat lineThickness;

@end

@interface MTExponentDisplay ()

@property (nonatomic) CGFloat subScriptDown;
@property (nonatomic) CGFloat superScriptUp;

- (instancetype)initWithExponentDisplays:(NSMutableDictionary*) displays shiftUp:(CGFloat)shiftUp shiftDown:(CGFloat)shiftDown position:(CGPoint) position range:(NSRange) range;

@property (nonatomic) CGFloat topKern;
@property (nonatomic) CGFloat lineThickness;

@end

// Rendering of an large glyph as an MTDisplay
@interface MTGlyphDisplay() <DownShift>

- (instancetype)initWithGlpyh:(CGGlyph) glyph range:(NSRange) range font:(MTFont*) font NS_DESIGNATED_INITIALIZER;

@end

// Rendering of a constructed glyph as an MTDisplay
@interface MTGlyphConstructionDisplay : MTDisplay<DownShift>

- (instancetype) init NS_UNAVAILABLE;
- (instancetype) initWithGlyphs:(NSArray<NSNumber*>*) glyphs offsets:(NSArray<NSNumber*>*) offsets font:(MTFont*) font NS_DESIGNATED_INITIALIZER;

@end

@interface MTLargeOpLimitsDisplay ()

- (instancetype) initWithNucleus:(MTDisplay*) nucleus upperLimit:(MTMathListDisplay*) upperLimit lowerLimit:(MTMathListDisplay*) lowerLimit limitShift:(CGFloat) limitShift extraPadding:(CGFloat) extraPadding boundaries:(NSMutableArray*)boundaries
NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic) CGFloat upperLimitGap;
@property (nonatomic) CGFloat lowerLimitGap;

@end

@interface MTLineDisplay ()

- (instancetype)initWithInner:(MTMathListDisplay*) inner position:(CGPoint) position range:(NSRange) range NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithInner:(MTMathListDisplay *)inner position:(CGPoint)position range:(NSRange)range lineColor:(UIColor *)lineColor NS_DESIGNATED_INITIALIZER;

// How much the line should be moved up.
@property (nonatomic) CGFloat lineShiftUp;
@property (nonatomic) CGFloat lineThickness;

@end

@interface MTAccentDisplay ()

- (instancetype)initWithAccent:(MTGlyphDisplay*) glyph accentee:(MTMathListDisplay*) accentee range:(NSRange) range NS_DESIGNATED_INITIALIZER;

@end


/// Rendering of an MTInnerDisplay as an MTDisplay
@interface MTInnerDisplay()

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithValue:(MTMathListDisplay*) innerList left:(MTDisplay *)left right:(MTDisplay *)right position:(CGPoint)position range:(NSRange)range;

@end

@interface MTUnderDisplay ()

- (instancetype)initWithPrimaryDisplay:(MTMathListDisplay*) primary secondaryDisplay:(MTMathListDisplay*) secondary position:(CGPoint) position range:(NSRange) range NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic) CGFloat denominatorDown;

@end
