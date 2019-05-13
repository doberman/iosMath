//
//  MTLine.h
//  iosMath
//
//  Created by Kostub Deshmukh on 8/27/13.
//  Copyright (C) 2013 MathChat
//
//  This software may be modified and distributed under the terms of the
//  MIT license. See the LICENSE file for details.
//

@import Foundation;
@import QuartzCore;
@import UIKit;

#import "MTFont.h"
#import "MTMathList.h"

NS_ASSUME_NONNULL_BEGIN

/// The base class for rendering a math equation.
@interface MTDisplay : NSObject

/// Draws itself in the given graphics context.
- (void) draw:(CGContextRef) context;
/// Gets the bounding rectangle for the MTDisplay
- (CGRect) displayBounds;

/// For debugging. Shows the object in quick look in Xcode.
- (id) debugQuickLookObject;

/// The distance from the axis to the top of the display
@property (nonatomic, readonly) CGFloat ascent;
/// The distance from the axis to the bottom of the display
@property (nonatomic, readonly) CGFloat descent;
/// The width of the display
@property (nonatomic, readonly) CGFloat width;
/// Position of the display with respect to the parent view or display.
@property (nonatomic) CGPoint position;
/// The range of characters supported by this item
@property (nonatomic, readonly) NSRange range;
/// Whether the display has a subscript/superscript following it.
@property (nonatomic, readonly) BOOL hasScript;
/// The text color for this display
@property (nonatomic, nullable) UIColor* textColor;
// The local color, if the color was mutated local with the color
// command
@property (nonatomic, nullable) UIColor *localTextColor;

@end

/// A rendering of a single CTLine as an MTDisplay
@interface MTCTLineDisplay : MTDisplay

- (instancetype)init NS_UNAVAILABLE;

/// The CTLine being displayed
@property (nonatomic, readonly) CTLineRef line;
/// The attributed string used to generate the CTLineRef. Note setting this does not reset the dimensions of
/// the display. So set only when
@property (nonatomic) NSAttributedString* attributedString;

/// An array of MTMathAtoms that this CTLine displays. Used for indexing back into the MTMathList
@property (nonatomic, readonly) NSArray<MTMathAtom*>* atoms;

@end

/// An MTLine is a rendered form of MTMathList in one line.
/// It can render itself using the draw method.
@interface MTMathListDisplay : MTDisplay

- (instancetype)init NS_UNAVAILABLE;

/**
 @typedef MTLinePosition
 @brief The type of position for a line, i.e. subscript/superscript or regular.
 */
typedef NS_ENUM(unsigned int, MTLinePosition)  {
    /// Regular
    kMTLinePositionRegular,
    /// Positioned at a subscript
    kMTLinePositionSubscript,
    /// Positioned at a superscript
    kMTLinePositionSuperscript,
    kMTLinePositionBeforeSubscript
};

/// Where the line is positioned
@property (nonatomic, readonly) MTLinePosition type;
/// An array of MTDisplays which are positioned relative to the position of the
/// the current display.
@property (nonatomic, readonly) NSArray<MTDisplay*>* subDisplays;
/// If a subscript or superscript this denotes the location in the parent MTList. For a
/// regular list this is NSNotFound
@property (nonatomic, readonly) NSUInteger index;

- (CGFloat)shiftBottom;
@end

/// Rendering of an MTFraction as an MTDisplay
@interface MTFractionDisplay : MTDisplay

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithNumerator:(MTMathListDisplay*) numerator denominator:(MTMathListDisplay*) denominator whole:(MTMathListDisplay*) whole position:(CGPoint) position range:(NSRange) range;

/** A display representing the numerator of the fraction. It's position is relative
 to the parent and is not treated as a sub-display.
 */
@property (nonatomic, readonly) MTMathListDisplay* numerator;
/** A display representing the denominator of the fraction. It's position is relative
 to the parent is not treated as a sub-display.
 */
@property (nonatomic, readonly) MTMathListDisplay* denominator;

@property (nonatomic, readonly) MTMathListDisplay* whole;


@end

/// Rendering of an MTOrderedPair as an MTDisplay
@interface MTOrderedPairDisplay : MTDisplay

- (instancetype)init NS_UNAVAILABLE;

/** A display representing the left parameter of the ordered pair. It's position is relative
 to the parent is not treated as a sub-display.
 */

@property (nonatomic, readonly) MTMathListDisplay* leftPair;

/** A display representing the right parameter of the ordered pair. It's position is relative
 to the parent is not treated as a sub-display.
 */
@property (nonatomic, readonly) MTMathListDisplay* rightPair;

@property (nonatomic, readonly, nullable) MTDisplay* leftBoundary;

@property (nonatomic, readonly, nullable) MTDisplay* rightBoundary;

@property (nonatomic, readonly, nullable) MTDisplay* seperator;

@end

/// Rendering of an MTBinomialMatrix as an MTDisplay
@interface MTBinomialMatrixDisplay : MTDisplay

- (instancetype)init NS_UNAVAILABLE;

/** Displays representing the position of the 2x2 matrix. It's position is relative
 to the parent is not treated as a sub-display.
 */
@property (nonatomic, readonly) MTMathListDisplay* row0Column0;

@property (nonatomic, readonly) MTMathListDisplay* row0Column1;

@property (nonatomic, readonly) MTMathListDisplay* row1Column0;

@property (nonatomic, readonly) MTMathListDisplay* row1Column1;

@property (nonatomic, readonly, nullable) MTDisplay* leftBoundary;

@property (nonatomic, readonly, nullable) MTDisplay* rightBoundary;


@end

/// Rendering of an MTInnerDisplay as an MTDisplay
@interface MTInnerDisplay : MTDisplay

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithValue:(MTMathListDisplay*) innerList left:(MTDisplay *)left right:(MTDisplay *)right position:(CGPoint) position range:(NSRange) range;

//- (instancetype)initWithValue:(MTMathListDisplay*) innerList position:(CGPoint) position range:(NSRange) range;
/** A display representing the inner list for paranthesis. It's position is relative
 to the parent is not treated as a sub-display.
 */
@property (nonatomic, readonly) MTMathListDisplay* innerList;
@property (nonatomic, readonly, nullable) MTDisplay* left;
@property (nonatomic, readonly, nullable) MTDisplay* right;


@end

/// Rendering of an MTAbsoluteValue as an MTDisplay
@interface MTAbsoluteValueDisplay : MTDisplay

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithValue:(MTMathListDisplay*) absHolder position:(CGPoint) position leftBoundary:(MTDisplay*) leftBoundary rightBoundary:(MTDisplay*)rightBoundary range:(NSRange) range;

/** A display representing the numerator of the fraction. It's position is relative
 to the parent and is not treated as a sub-display.
 */
@property (nonatomic, readonly) MTMathListDisplay* absPlaceholder;
@property (nonatomic, readonly, nullable) MTDisplay* leftBoundary;
@property (nonatomic, readonly, nullable) MTDisplay* rightBoundary;

@end



/// Rendering of an MTRadical as an MTDisplay
@interface MTRadicalDisplay : MTDisplay

- (instancetype)init NS_UNAVAILABLE;

/** A display representing the radicand of the radical. It's position is relative
 to the parent is not treated as a sub-display.
 */
@property (nonatomic, readonly) MTMathListDisplay* radicand;
/** A display representing the degree of the radical. It's position is relative
 to the parent is not treated as a sub-display.
 */
@property (nonatomic, readonly, nullable) MTMathListDisplay* degree;

@end

/// Rendering of an MTExponent as an MTDisplay
@interface MTExponentDisplay : MTDisplay

- (instancetype)init NS_UNAVAILABLE;

/** A display representing the base exponent . It's position is relative
 to the parent is not treated as a sub-display.
 */
@property (nonatomic, readonly) MTMathListDisplay* exponentBase;
/** A display representing the superscript of the exponent. It's position is relative
 to the parent is not treated as a sub-display.
 */
@property (nonatomic, readonly, nullable) MTMathListDisplay* expSuperscript;
/** A display representing the subscript of the exponent. It's position is relative
 to the parent is not treated as a sub-display.
 */
@property (nonatomic, readonly, nullable) MTMathListDisplay* expSubscript;
/** A display representing the prefixed subscript of the exponent. It's position is relative
 to the parent is not treated as a sub-display.
 */
@property (nonatomic, readonly, nullable) MTMathListDisplay* prefixedSubscript;

@end


/// Rendering a glyph as a display
@interface MTGlyphDisplay : MTDisplay

- (instancetype)init NS_UNAVAILABLE;

@end

/// Rendering a large operator with limits as an MTDisplay
@interface MTLargeOpLimitsDisplay : MTDisplay

- (instancetype)init NS_UNAVAILABLE;

/** A display representing the upper limit of the large operator. It's position is relative
 to the parent is not treated as a sub-display.
 */
@property (nonatomic, readonly, nullable) MTMathListDisplay* upperLimit;
/** A display representing the lower limit of the large operator. It's position is relative
 to the parent is not treated as a sub-display.
 */
@property (nonatomic, readonly, nullable) MTMathListDisplay* lowerLimit;
@property (nonatomic, readonly) MTMathListDisplay *holder;
@property (nonatomic, readonly, nullable) MTDisplay* leftBoundary;
@property (nonatomic, readonly, nullable) MTDisplay* rightBoundary;

@end

/// Rendering of an list with an overline or underline
@interface MTLineDisplay : MTDisplay

- (instancetype)init NS_UNAVAILABLE;

/** A display representing the inner list that is underlined. It's position is relative
 to the parent is not treated as a sub-display.
 */
@property (nonatomic, readonly) MTMathListDisplay* inner;

@property (nonatomic, nullable) UIColor *lineColor;

@end

/// Rendering an accent as a display
@interface MTAccentDisplay : MTDisplay

- (instancetype)init NS_UNAVAILABLE;

/** A display representing the inner list that is accented. It's position is relative
 to the parent is not treated as a sub-display.
 */
@property (nonatomic, readonly) MTMathListDisplay* accentee;

/** A display representing the accent. It's position is relative to the current display.
 */
@property (nonatomic, readonly) MTGlyphDisplay* accent;

@end

/// Rendering of an MTImage as an MTDisplay
@interface MTImageDisplay : MTDisplay

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithImage:(UIImage *)imgage range:(NSRange)range;

@property (nonatomic, readonly) UIImage* image;

@end

/// Rendering of an MTUnder as an MTDisplay
@interface MTUnderDisplay : MTDisplay

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithPrimaryDisplay:(MTMathListDisplay*) primary secondaryDisplay:(MTMathListDisplay*) secondary position:(CGPoint) position range:(NSRange) range;

/** A display representing the primary of the UNDER. It's position is relative
 to the parent and is not treated as a sub-display.
 */
@property (nonatomic, readonly) MTMathListDisplay* primary;
/** A display representing the secondary atom of the Under. It's position is relative
 to the parent is not treated as a sub-display.
 */
@property (nonatomic, readonly) MTMathListDisplay* secondary;

@end

NS_ASSUME_NONNULL_END

