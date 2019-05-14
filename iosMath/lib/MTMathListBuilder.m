//
//  MTMathListBuilder.m
//  iosMath
//
//  Created by Kostub Deshmukh on 8/28/13.
//  Copyright (C) 2013 MathChat
//
//  This software may be modified and distributed under the terms of the
//  MIT license. See the LICENSE file for details.
//

#import "MTMathListBuilder.h"
#import "MTMathAtomFactory.h"

NSString *const MTParseError = @"ParseError";

@interface MTEnvProperties : NSObject

@property (nonatomic, readonly) NSString* envName;
@property (nonatomic) BOOL ended;
@property (nonatomic) NSInteger numRows;

@end

@implementation MTEnvProperties

- (instancetype)initWithName:(NSString*) name
{
    self = [super init];
    if (self) {
        _envName = name;
        _numRows = 0;
        _ended = NO;
    }
    return self;
}

@end

@implementation MTMathListBuilder {
    unichar* _chars;
    int _currentChar;
    NSUInteger _length;
    MTInner* _currentInnerAtom;
    MTEnvProperties* _currentEnv;
    MTFontStyle _currentFontStyle;
    BOOL _spacesAllowed;
}

- (instancetype)initWithString:(NSString *)str
{
    self = [super init];
    if (self) {
        _error = nil;
        _chars = malloc(sizeof(unichar)*str.length);
        _length = str.length;
        [str getCharacters:_chars range:NSMakeRange(0, str.length)];
        _currentChar = 0;
        _currentFontStyle = kMTFontStyleDefault;
        _latexCommands = [MTMathAtomFactory supportedLatexSymbols];
    }
    return self;
}

- (void)dealloc
{
    free(_chars);
}

- (BOOL) hasCharacters
{
    return _currentChar < _length;
}

// gets the next character and moves the pointer ahead
- (unichar) getNextCharacter
{
    NSAssert([self hasCharacters], @"Retrieving character at index %d beyond length %lu", _currentChar, (unsigned long)_length);
    return _chars[_currentChar++];
}

- (void) unlookCharacter
{
    NSAssert(_currentChar > 0, @"Unlooking when at the first character.");
    _currentChar--;
}

- (MTMathList *)build
{
    MTMathList* list = [self buildInternal:false];
    //    if ([self hasCharacters] && !_error) {
    //        // something went wrong most likely braces mismatched
    //        NSString* errorMessage = [NSString stringWithFormat:@"Mismatched braces: %@", [NSString stringWithCharacters:_chars length:_length]];
    //        [self setError:MTParseErrorMismatchBraces message:errorMessage];
    //    }
    //    if (_error) {
    //        return nil;
    //    }
    return list;
}

- (MTMathList*) buildInternal:(BOOL) oneCharOnly
{
    return [self buildInternal:oneCharOnly stopChar:0];
}

- (MTMathList*)buildInternal:(BOOL) oneCharOnly stopChar:(unichar) stop
{
    MTMathList* list = [MTMathList new];
    NSAssert(!(oneCharOnly && (stop > 0)), @"Cannot set both oneCharOnly and stopChar.");
    MTMathAtom* prevAtom = nil;
    while([self hasCharacters]) {
        if (_error) {
            // If there is an error thus far then bail out.
            return nil;
        }
        MTMathAtom* atom = nil;
        unichar ch = [self getNextCharacter];
        if (oneCharOnly) {
            if (ch == '^' || ch == '}' || ch == '_' || ch == '&') {
                // this is not the character we are looking for.
                // They are meant for the caller to look at.
                [self unlookCharacter];
                return list;
            }
        }
        // If there is a stop character, keep scanning till we find it
        if (stop > 0 && ch == stop) {
            return list;
        }
        
        if (ch == '^') {
            if(atom == nil) {
                atom = [self buildSuperScriptWithList:list];
            }
        } else if (ch == '_') {
            if(atom == nil) {
                atom = [self buildSubScriptWithList:list];
            }
        } else if (ch == '{') {
            // this puts us in a recursive routine, and sets oneCharOnly to false and no stop character
            MTMathList* sublist = [self buildInternal:false stopChar:'}'];
            prevAtom = [sublist.atoms lastObject];
            [list append:sublist];
            if (oneCharOnly) {
                return list;
            }
            continue;
        }
//        else if (ch == '}') {
//            NSAssert(!oneCharOnly, @"This should have been handled before");
//            NSAssert(stop == 0, @"This should have been handled before");
//            // We encountered a closing brace when there is no stop set, that means there was no
//            // corresponding opening brace.
//            NSString* errorMessage = @"Mismatched braces.";
//            [self setError:MTParseErrorMismatchBraces message:errorMessage];
//            return nil;
//        }
        else if (ch == '\\') {
            // \ means a command
            NSString* command = [self readCommand];
            MTMathList* done = [self stopCommand:command list:list stopChar:stop];
            if (done) {
                return done;
            }
            else if (_error) {
                return nil;
            }
            atom = [self atomForCommand:command];
            /* For Large Operaor with Limits */
            if (atom.type == kMTMathAtomLargeOperator){
                [self buildLargeOpWithLimits:atom];
            }
            else if (atom.type == kMTMathAtomAccent) {
                [self buildAccent:atom];
            }
            //            if (atom == nil) {
            //                // this was an unknown command,
            //                // we flag an error and return
            //                // (note setError will not set the error if there is already one, so we flag internal error
            //                // in the odd case that an _error is not set.
            //                [self setError:MTParseErrorInternalError message:@"Internal error"];
            //                return nil;
            //            }
        } else if (ch == '&') {
            // used for column separation in tables
            NSAssert(!oneCharOnly, @"This should have been handled before");
            if (_currentEnv) {
                return list;
            } else {
                // Create a new table with the current list and a default env
                MTMathAtom* table = [self buildTable:nil firstList:list row:NO];
                return [MTMathList mathListWithAtoms:table, nil];
            }
        } else {
            atom = [MTMathAtomFactory atomForCharacter:ch];
            if (!atom) {
                // Not a recognized character
                continue;
            }
        }
        //NSAssert(atom != nil, @"Atom shouldn't be nil");
        if (atom != nil) {
            [list addAtom:atom];
        }
        prevAtom = atom;
        
        if (oneCharOnly) {
            // we consumed our onechar
            return list;
        }
    }
    if (stop > 0) {
        if (stop == '}') {
            // We did not find a corresponding closing brace.
            [self setError:MTParseErrorMismatchBraces message:@"Missing closing brace"];
        } else {
            // we never found our stop character
            NSString* errorMessage = [NSString stringWithFormat:@"Expected character not found: %d", stop];
            [self setError:MTParseErrorCharacterNotFound message:errorMessage];
        }
    }
    return list;
}

- (NSString*) readString
{
    // a string of all upper and lower case characters.
    NSMutableString* mutable = [NSMutableString string];
    while([self hasCharacters]) {
        unichar ch = [self getNextCharacter];
        if ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')) {
            if(_latexCommands[mutable] != nil){
                [self unlookCharacter];
                break;
            }
            [mutable appendString:[NSString stringWithCharacters:&ch length:1]];
        } else {
            // we went too far
            [self unlookCharacter];
            break;
        }
    }
    return mutable;
}

- (void) skipSpaces
{
    while ([self hasCharacters]) {
        unichar ch = [self getNextCharacter];
        if (ch < 0x21 || ch > 0x7E) {
            // skip non ascii characters and spaces
            continue;
        } else {
            [self unlookCharacter];
            return;
        }
    }
}

#define MTAssertNotSpace(ch) NSAssert((ch) >= 0x21 && (ch) <= 0x7E, @"Expected non space character %c", (ch));

- (BOOL) expectCharacter:(unichar) ch
{
    MTAssertNotSpace(ch);
    [self skipSpaces];
    
    if ([self hasCharacters]) {
        unichar c = [self getNextCharacter];
        MTAssertNotSpace(c);
        if (c == ch) {
            return YES;
        } else {
            [self unlookCharacter];
            return NO;
        }
    }
    return NO;
}

- (NSString*) readCommand
{
    static NSSet<NSNumber*>* singleCharCommands = nil;
    if (!singleCharCommands) {
        NSArray* singleChars = @[ @'{', @'}', @'$', @'#', @'%', @'_', @'|', @' ', @',', @'>', @';', @'!', @'\\' ];
        singleCharCommands = [[NSSet alloc] initWithArray:singleChars];
    }
    if ([self hasCharacters]) {
        // Check if we have a single character command.
        unichar ch = [self getNextCharacter];
        // Single char commands
        if ([singleCharCommands containsObject:@(ch)]) {
            return [NSString stringWithCharacters:&ch length:1];
        } else {
            // not a known single character command
            [self unlookCharacter];
        }
    }
    // otherwise a command is a string of all upper and lower case characters.
    return [self readString];
}

- (NSString*) readDelimiter
{
    // Ignore spaces and nonascii.
    [self skipSpaces];
    while([self hasCharacters]) {
        unichar ch = [self getNextCharacter];
        MTAssertNotSpace(ch);
        if (ch == '\\') {
            // \ means a command
            NSString* command = [self readCommand];
            if ([command isEqualToString:@"|"]) {
                // | is a command and also a regular delimiter. We use the || command to
                // distinguish between the 2 cases for the caller.
                return @"||";
            }
            return command;
        } else {
            return [NSString stringWithCharacters:&ch length:1];
        }
    }
    // We ran out of characters for delimiter
    return nil;
}

- (NSString*) readEnvironment
{
    if (![self expectCharacter:'{']) {
        // We didn't find an opening brace, so no env found.
        [self setError:MTParseErrorCharacterNotFound message:@"Missing {"];
        return nil;
    }
    
    // Ignore spaces and nonascii.
    [self skipSpaces];
    NSString* env = [self readString];
    
    if (![self expectCharacter:'}']) {
        // We didn't find an closing brace, so invalid format.
        [self setError:MTParseErrorCharacterNotFound message:@"Missing }"];
        return nil;
    }
    return env;
}

- (MTMathAtom*) getBoundaryAtom:(NSString*) delimiterType
{
    NSString* delim = [self readDelimiter];
    if (!delim) {
        NSString* errorMessage = [NSString stringWithFormat:@"Missing delimiter for \\%@", delimiterType];
        [self setError:MTParseErrorMissingDelimiter message:errorMessage];
        return nil;
    }
    MTMathAtom* boundary = [MTMathAtomFactory boundaryAtomForDelimiterName:delim];
    if (!boundary) {
        NSString* errorMessage = [NSString stringWithFormat:@"Invalid delimiter for \\%@: %@", delimiterType, delim];
        [self setError:MTParseErrorInvalidDelimiter message:errorMessage];
        return nil;
    }
    return boundary;
}

- (void)makeChildAtom:(NSArray *)atomsArr {
    for (MTMathAtom* atom in atomsArr) {
        atom.isChildAtom = true;
    }
}

- (MTMathAtom*) atomForCommand:(NSString*) command
{
    MTMathAtom* atom = [MTMathAtomFactory atomForLatexSymbolName:command];
    if (atom) {
        return atom;
    }
    MTAccent* accent = [MTMathAtomFactory accentWithName:command];
    if (accent) {
        // The command is an accent
        accent.innerList = [self buildInternal:true];
        return accent;
    } else if ([command isEqualToString:@"frac"]) {
        // A fraction command has 2 arguments
        MTFraction* frac = [MTFraction new];
        frac.numerator = [self buildInternal:true];
        frac.denominator = [self buildInternal:true];
        [self makeChildAtom: frac.numerator.atoms];
        [self makeChildAtom: frac.denominator.atoms];
        return frac;
    }
    else if ([command isEqualToString:@"tfrac"]) {
        // A fraction command has 2 arguments
        MTMixedFraction* frac = [MTMixedFraction new];
        frac.numerator = [self buildInternal:true];
        frac.denominator = [self buildInternal:true];
        frac.whole = [self buildInternal:true];
        return frac;
    } else if ([command isEqualToString:@"binom"]) {
        // A binom command has 2 arguments
        MTFraction* frac = [[MTFraction alloc] initWithRule:NO];
        frac.numerator = [self buildInternal:true];
        frac.denominator = [self buildInternal:true];
        frac.leftDelimiter = @"(";
        frac.rightDelimiter = @")";
        [self makeChildAtom: frac.numerator.atoms];
        [self makeChildAtom: frac.denominator.atoms];
        return frac;
    } else if ([command isEqualToString:@"sqrt"]) {
        // A sqrt command with one argument
        MTRadical* rad = [MTRadical new];
        unichar ch = [self getNextCharacter];
        if (ch == '[') {
            // special handling for sqrt[degree]{radicand}
            rad.degree = [self buildInternal:false stopChar:']'];
            rad.radicand = [self buildInternal:true];
        } else {
            [self unlookCharacter];
            rad.radicand = [self buildInternal:true];
        }
        NSArray * atomsArr = rad.radicand.atoms;
        for (MTMathAtom* atom in atomsArr) {
            atom.isChildAtom = true;
        }
        return rad;
    } else if ([command isEqualToString:@"left"] || [command isEqualToString:@"lCurlyBrace"]) {
        // Save the current inner while a new one gets built.
        MTInner* oldInner = _currentInnerAtom;
        _currentInnerAtom = [MTInner new];
        _currentInnerAtom.leftBoundary = [self getBoundaryAtom:@"left"];
        if (!_currentInnerAtom.leftBoundary) {
            return nil;
        }
        _currentInnerAtom.innerList = [self buildInternal:false];
        //        if (!_currentInnerAtom.rightBoundary) {
        //            // A right node would have set the right boundary so we must be missing the right node.
        //            NSString* errorMessage = @"Missing \\right";
        //            [self setError:MTParseErrorMissingRight message:errorMessage];
        //            return nil;
        //        }
        // reinstate the old inner atom.
        [self makeChildAtom:_currentInnerAtom.innerList.atoms];
        MTInner* newInner = _currentInnerAtom;
        _currentInnerAtom = oldInner;
        return newInner;
    } else if ([command isEqualToString:@"right"]) {
        _currentInnerAtom = [MTInner new];
        _currentInnerAtom.rightBoundary = [self getBoundaryAtom:@"right"];
        return _currentInnerAtom;
    } else if ([command isEqualToString:@"overline"]) {
        // The overline command has 1 arguments
        MTOverLine* over = [MTOverLine new];
        over.innerList = [self buildInternal:true];
        return over;
    } else if ([command containsString:@"underline"]) {
        NSArray* components = [command componentsSeparatedByString:@"underline"];
        if (components.count > 1) {
            // The underline command has 1 arguments
            MTUnderLine* under = [MTUnderLine new];
            under.innerList = [self buildInternal:true];
            NSString *color = [components objectAtIndex:1];
            if ([color isEqualToString:@"Blue"]) {
                under.lineColor = [UIColor colorWithRed:4/255.0 green:122/255.0 blue:156/255.0 alpha:1.0];
            } else if ([color isEqualToString:@"Gray"]) {
                under.lineColor = [UIColor colorWithRed:199/255.0 green:199/255.0 blue:199/255.0 alpha:1.0];
            } else if ([color isEqualToString:@"Green"]) {
                under.lineColor = [UIColor colorWithRed:16/255.0 green:114/255.0 blue:42/255.0 alpha:1.0];
                MTImage *imageAtom = [MTImage new];
                imageAtom.image = [UIImage imageNamed:@"FR_Correct" inBundle:[self getTDXBundle] compatibleWithTraitCollection:nil];
                [under.innerList addAtom:imageAtom];
            } else if ([color isEqualToString:@"Red"]) {
                under.lineColor = [UIColor colorWithRed:204/255.0 green:78/255.0 blue:76/255.0 alpha:1.0];
                MTImage *imageAtom = [MTImage new];
                imageAtom.image = [UIImage imageNamed:@"FR_Incorrect" inBundle:[self getTDXBundle] compatibleWithTraitCollection:nil];
                [under.innerList addAtom:imageAtom];
            }
            return under;
        } else {
            // The underline command has 1 arguments
            MTUnderLine* under = [MTUnderLine new];
            under.innerList = [self buildInternal:true];
            return under;
        }
    } else if ([command isEqualToString:@"abs"] || [command isEqualToString:@"absl"] || [command isEqualToString:@"absr"]) {
        MTAbsoluteValue* absValue = [MTAbsoluteValue new];
        absValue.open = absValue.close = @"|";
        if( [command isEqualToString:@"absl"]) {
            absValue.close = nil;
        } else if ( [command isEqualToString:@"absr"]){
            absValue.open = nil;
        }
        absValue.absHolder = [self buildInternal:true];
        return absValue;
    }
    else if ([command isEqualToString:@"begin"]) {
        NSString* env = [self readEnvironment];
        if (!env) {
            return nil;
        }
        MTMathAtom* table = [self buildTable:env firstList:nil row:NO];
        return table;
    } else if ([command isEqualToString:@"bmatrix"] || [command isEqualToString:@"vmatrix"]) {
        MTBinomialMatrix *matrix = [MTBinomialMatrix new];
        if([command isEqualToString:@"vmatrix"]){
            matrix.open = @"|";
            matrix.close = @"|";
        }
        else if([command isEqualToString:@"bmatrix"]){
            matrix.open = @"[";
            matrix.close = @"]";
        }
        matrix.row0Col0 = [self buildInternal:true];
        matrix.row0Col1 = [self buildInternal:true];
        matrix.row1Col0 = [self buildInternal:true];
        matrix.row1Col1 = [self buildInternal:true];
        return matrix;
    }
    else if ([command isEqualToString:@"undr"]) {
        MTUnder* under = [MTUnder new];
        under.primary = [self buildInternal:true];
        under.secondary = [self buildInternal:true];
        return under;
    }
    else {
        //        NSString* errorMessage = [NSString stringWithFormat:@"Invalid command \\%@", command];
        //        [self setError:MTParseErrorInvalidCommand message:errorMessage];
        return nil;
    }
}


- (MTMathList*) stopCommand:(NSString*) command list:(MTMathList*) list stopChar:(unichar) stopChar
{
    static NSDictionary<NSString*, NSArray*>* fractionCommands = nil;
    if (!fractionCommands) {
        fractionCommands = @{ @"over" : @[],
                              @"atop" : @[],
                              @"choose" : @[ @"(", @")"],
                              @"brack" : @[ @"[", @"]"],
                              @"brace" : @[ @"{", @"}"]};
    }
    if ([command isEqualToString:@"right"]) {
        if (!_currentInnerAtom) {
            //NSString* errorMessage = @"Missing \\left";
            //            _currentInnerAtom = [MTInner new];
            //            _currentInnerAtom.rightBoundary = [self getBoundaryAtom:@"right"];
            // [self setError:MTParseErrorMissingLeft message:errorMessage];
            return nil;
        }
        _currentInnerAtom.rightBoundary = [self getBoundaryAtom:@"right"];
        if (!_currentInnerAtom.rightBoundary) {
            return nil;
        }
        // return the list read so far.
        return list;
    } else if ([command isEqualToString:@"rCurlyBrace"]) {
        if(_currentInnerAtom && _currentInnerAtom.rightBoundary == nil) {
            _currentInnerAtom.rightBoundary = [MTMathAtom atomWithType:kMTMathAtomBoundary value:@"}"];
        }
        return list;
    }
    else if ([fractionCommands objectForKey:command]) {
        MTFraction* frac = nil;
        if ([command isEqualToString:@"over"]) {
            frac = [[MTFraction alloc] init];
        } else {
            frac = [[MTFraction alloc] initWithRule:NO];
        }
        NSArray* delims = [fractionCommands objectForKey:command];
        if (delims.count == 2) {
            frac.leftDelimiter = delims[0];
            frac.rightDelimiter = delims[1];
        }
        frac.numerator = list;
        frac.denominator = [self buildInternal:NO stopChar:stopChar];
        if (_error) {
            return nil;
        }
        MTMathList* fracList = [MTMathList new];
        [fracList addAtom:frac];
        return fracList;
    } else if ([command isEqualToString:@"\\"] || [command isEqualToString:@"cr"]) {
        if (_currentEnv) {
            // Stop the current list and increment the row count
            _currentEnv.numRows++;
            return list;
        } else {
            // Create a new table with the current list and a default env
            MTMathAtom* table = [self buildTable:nil firstList:list row:YES];
            return [MTMathList mathListWithAtoms:table, nil];
        }
    } else if ([command isEqualToString:@"end"]) {
        if (!_currentEnv) {
            NSString* errorMessage = @"Missing \\begin";
            [self setError:MTParseErrorMissingBegin message:errorMessage];
            return nil;
        }
        NSString* env = [self readEnvironment];
        if (!env) {
            return nil;
        }
        if (![env isEqualToString:_currentEnv.envName])
        {
            NSString* errorMessage = [NSString stringWithFormat:@"Begin environment name %@ does not match end name: %@", _currentEnv.envName, env];
            [self setError:MTParseErrorInvalidEnv message:errorMessage];
            return nil;
        }
        // Finish the current environment.
        _currentEnv.ended = YES;
        return list;
    }
    return nil;
}

// Applies the modifier to the atom. Returns true if modifier applied.
- (BOOL) applyModifier:(NSString*) modifier atom:(MTMathAtom*) atom
{
    if ([modifier isEqualToString:@"limits"]) {
        if (atom.type != kMTMathAtomLargeOperator) {
            NSString* errorMessage = [NSString stringWithFormat:@"limits can only be applied to an operator."];
            [self setError:MTParseErrorInvalidLimits message:errorMessage];
        } else {
            MTLargeOperator* op = (MTLargeOperator*) atom;
            op.limits = YES;
        }
        return true;
    } else if ([modifier isEqualToString:@"nolimits"]) {
        if (atom.type != kMTMathAtomLargeOperator) {
            NSString* errorMessage = [NSString stringWithFormat:@"nolimits can only be applied to an operator."];
            [self setError:MTParseErrorInvalidLimits message:errorMessage];
            return YES;
        } else {
            MTLargeOperator* op = (MTLargeOperator*) atom;
            op.limits = NO;
        }
        return true;
    }
    return false;
}

- (void) setError:(MTParseErrors) code message:(NSString*) message
{
    // Only record the first error.
    if (!_error) {
        _error = [NSError errorWithDomain:MTParseError code:code userInfo:@{ NSLocalizedDescriptionKey : message }];
    }
}

- (MTMathAtom*) buildTable:(NSString*) env firstList:(MTMathList*) firstList row:(BOOL) isRow
{
    // Save the current env till an new one gets built.
    MTEnvProperties* oldEnv = _currentEnv;
    _currentEnv = [[MTEnvProperties alloc] initWithName:env];
    NSInteger currentRow = 0;
    NSInteger currentCol = 0;
    NSMutableArray<NSMutableArray<MTMathList*>*>* rows = [NSMutableArray array];
    rows[0] = [NSMutableArray array];
    if (firstList) {
        rows[currentRow][currentCol] = firstList;
        if (isRow) {
            _currentEnv.numRows++;
            currentRow++;
            rows[currentRow] = [NSMutableArray array];
        } else {
            currentCol++;
        }
    }
    while (!_currentEnv.ended && [self hasCharacters]) {
        MTMathList* list = [self buildInternal:NO];
        if (!list) {
            // If there is an error building the list, bail out early.
            return nil;
        }
        rows[currentRow][currentCol] = list;
        currentCol++;
        if (_currentEnv.numRows > currentRow) {
            currentRow = _currentEnv.numRows;
            rows[currentRow] = [NSMutableArray array];
            currentCol = 0;
        }
    }
    if (!_currentEnv.ended && _currentEnv.envName) {
        [self setError:MTParseErrorMissingEnd message:@"Missing \\end"];
        return nil;
    }
    NSError* error;
    MTMathAtom* table = [MTMathAtomFactory tableWithEnvironment:_currentEnv.envName rows:rows error:&error];
    if (!table && !_error) {
        _error = error;
        return nil;
    }
    // reinstate the old env.
    _currentEnv = oldEnv;
    return table;
}

+ (NSDictionary*) spaceToCommands
{
    static NSDictionary* spaceToCommands = nil;
    if (!spaceToCommands) {
        spaceToCommands = @{
                            @3 : @",",
                            @4 : @">",
                            @5 : @";",
                            @(-3) : @"!",
                            @18 : @"quad",
                            @36 : @"qquad",
                            };
    }
    return spaceToCommands;
}

+ (NSDictionary*) styleToCommands
{
    static NSDictionary* styleToCommands = nil;
    if (!styleToCommands) {
        styleToCommands = @{
                            @(kMTLineStyleDisplay) : @"displaystyle",
                            @(kMTLineStyleText) : @"textstyle",
                            @(kMTLineStyleScript) : @"scriptstyle",
                            @(kMTLineStyleScriptScript) : @"scriptscriptstyle",
                            };
    }
    return styleToCommands;
}

+ (MTMathList *)buildFromString:(NSString *)str
{
    MTMathListBuilder* builder = [[MTMathListBuilder alloc] initWithString:str];
    return builder.build;
}

+ (MTMathList *)buildFromString:(NSString *)str error:(NSError *__autoreleasing *)error
{
    MTMathListBuilder* builder = [[MTMathListBuilder alloc] initWithString:str];
    MTMathList* output = [builder build];
    if (builder.error) {
        if (error) {
            *error = builder.error;
        }
        return nil;
    }
    return output;
}

+ (NSString*) delimToString:(MTMathAtom*) delim
{
    NSString* command = [MTMathAtomFactory delimiterNameForBoundaryAtom:delim];
    if (command) {
        NSArray<NSString*>* singleChars = @[ @"(", @")", @"[", @"]", @"<", @">", @"|", @".", @"/"];
        if ([singleChars containsObject:command]) {
            return command;
        } else if ([command isEqualToString:@"||"]) {
            return @"\\|"; // special case for ||
        } else {
            return [NSString stringWithFormat:@"%@", command];
        }
    }
    return @"";
}

+ (NSArray *) trignometrySymbols
{
    return @[@"cot", @"sec", @"sin", @"arcsin", @"cos", @"tan", @"csc", @"sinh", @"cosh", @"tanh", @"csch", @"sech", @"coth", @"arccos", @"arctan", @"arccsc", @"arcsec", @"arccot"];
}

+ (NSString *)mathListToString:(MTMathList *)ml
{
    BOOL isTrignometry = false;
    NSMutableString* str = [NSMutableString string];
    MTFontStyle currentfontStyle = kMTFontStyleDefault;
    for (MTMathAtom* atom in ml.atoms) {
        if (currentfontStyle != atom.fontStyle) {
            if (currentfontStyle != kMTFontStyleDefault) {
                // close the previous font style.
                [str appendString:@"}"];
            }
            if (atom.fontStyle != kMTFontStyleDefault) {
                // open new font style
                NSString* fontStyleName = [MTMathAtomFactory fontNameForStyle:atom.fontStyle];
                [str appendFormat:@"\\%@{", fontStyleName];
            }
            currentfontStyle = atom.fontStyle;
        }
//        if (atom.beforeSubScript) {
//            [str appendFormat:@"{%@}_", [self mathListToString:atom.beforeSubScript]];
//        }
        if (atom.type == kMTMathAtomFraction) {
            MTFraction* frac = (MTFraction*) atom;
            if (frac.hasRule) {
                if(frac.whole != nil) {
                    [str appendFormat:@"{%@}\\frac{%@}{%@}", [self mathListToString:frac.whole],[self mathListToString:frac.numerator], [self mathListToString:frac.denominator]];
                } else {
                    [str appendFormat:@"\\frac{%@}{%@}", [self mathListToString:frac.numerator], [self mathListToString:frac.denominator]];
                }
            } else {
                NSString* command = nil;
                if (!frac.leftDelimiter && !frac.rightDelimiter) {
                    command = @"atop";
                } else if ([frac.leftDelimiter isEqualToString:@"("] && [frac.rightDelimiter isEqualToString:@")"]) {
                    command = @"choose";
                } else if ([frac.leftDelimiter isEqualToString:@"{"] && [frac.rightDelimiter isEqualToString:@"}"]) {
                    command = @"brace";
                } else if ([frac.leftDelimiter isEqualToString:@"["] && [frac.rightDelimiter isEqualToString:@"]"]) {
                    command = @"brack";
                } else {
                    command = [NSString stringWithFormat:@"atopwithdelims%@%@", frac.leftDelimiter, frac.rightDelimiter];
                }
                [str appendFormat:@"{%@ \\%@ %@}", [self mathListToString:frac.numerator], command, [self mathListToString:frac.denominator]];
            }
        } else if (atom.type == kMTMathAtomRadical) {
            [str appendString:@"\\sqrt"];
            MTRadical* rad = (MTRadical*) atom;
            if (rad.degree) {
                [str appendFormat:@"[%@]", [self mathListToString:rad.degree]];
            }
            [str appendFormat:@"{%@}", [self mathListToString:rad.radicand]];
        } else if (atom.type == kMTMathAtomInner) {
            MTInner* inner = (MTInner*) atom;
            if (inner.leftBoundary || inner.rightBoundary) {
                if (inner.leftBoundary) {
                    [str appendFormat:@"\\left%@", [self delimToString:inner.leftBoundary]];
                }
                if (inner.innerList != nil)
                {
                    [str appendFormat:@"{%@}", [self mathListToString:inner.innerList]];
                } else {
                    [str appendString:@"{}"];
                }
                if (inner.rightBoundary) {
                    [str appendFormat:@"\\right%@", [self delimToString:inner.rightBoundary]];
                }
                
            } else {
                [str appendFormat:@"{%@}", [self mathListToString:inner.innerList]];
            }
        } else if (atom.type == kMTMathAtomTable) {
            MTMathTable* table = (MTMathTable*) atom;
            if (table.environment) {
                [str appendFormat:@"\\begin{%@}", table.environment];
            }
            for (int i = 0; i < table.numRows; i++) {
                NSArray<MTMathList*>* row = table.cells[i];
                for (int j = 0; j < row.count; j++) {
                    MTMathList* cell = row[j];
                    if ([table.environment isEqualToString:@"matrix"]) {
                        if (cell.atoms.count >= 1 && cell.atoms[0].type == kMTMathAtomStyle) {
                            // remove the first atom.
                            NSArray* atoms = [cell.atoms subarrayWithRange:NSMakeRange(1, cell.atoms.count-1)];
                            cell = [MTMathList mathListWithAtomsArray:atoms];
                        }
                    }
                    if ([table.environment isEqualToString:@"eqalign"] || [table.environment isEqualToString:@"aligned"] || [table.environment isEqualToString:@"split"]) {
                        if (j == 1 && cell.atoms.count >= 1 && cell.atoms[0].type == kMTMathAtomOrdinary && cell.atoms[0].nucleus.length == 0) {
                            // Empty nucleus added for spacing. Remove it.
                            NSArray* atoms = [cell.atoms subarrayWithRange:NSMakeRange(1, cell.atoms.count-1)];
                            cell = [MTMathList mathListWithAtomsArray:atoms];
                        }
                    }
                    [str appendString:[self mathListToString:cell]];
                    if (j < row.count - 1) {
                        [str appendString:@"&"];
                    }
                }
                if (i < table.numRows - 1) {
                    [str appendString:@"\\\\ "];
                }
            }
            if (table.environment) {
                [str appendFormat:@"\\end{%@}", table.environment];
            }
        } else if (atom.type == kMTMathAtomOverline) {
            [str appendString:@"\\overline"];
            MTOverLine* over = (MTOverLine*) atom;
            [str appendFormat:@"{%@}", [self mathListToString:over.innerList]];
        } else if (atom.type == kMTMathAtomBinomialMatrix) {
            MTBinomialMatrix *matrix = (MTBinomialMatrix *)atom;
            if([matrix.open isEqualToString:@"["]){
                [str appendFormat:@"\\bmatrix{%@}{%@}{%@}{%@}", [self mathListToString:matrix.row0Col0],[self mathListToString:matrix.row0Col1],[self mathListToString:matrix.row1Col0],[self mathListToString:matrix.row1Col1]];
            }
            else{
                [str appendFormat:@"\\vmatrix{%@}{%@}{%@}{%@}", [self mathListToString:matrix.row0Col0],[self mathListToString:matrix.row0Col1],[self mathListToString:matrix.row1Col0],[self mathListToString:matrix.row1Col1]];
            }
        }
        else if (atom.type == kMTMathAtomUnderline) {
            [str appendString:@"\\underline"];
            MTUnderLine* under = (MTUnderLine*) atom;
            [str appendFormat:@"{%@}", [self mathListToString:under.innerList]];
        } else if (atom.type == kMTMathAtomAccent) {
            MTAccent* accent = (MTAccent*) atom;
            [str appendFormat:@"\\%@{%@}", [MTMathAtomFactory accentName:accent], [self mathListToString:accent.innerList]];
        } else if (atom.type == kMTMathAtomSpace) {
            MTMathSpace* space = (MTMathSpace*) atom;
            NSDictionary* spaceToCommands = [MTMathListBuilder spaceToCommands];
            NSString* command = spaceToCommands[@(space.space)];
            if (command) {
                [str appendFormat:@"\\%@ ", command];
            } else {
                [str appendFormat:@"\\mkern%.1fmu", space.space];
            }
        } else if (atom.type == kMTMathAtomStyle) {
            MTMathStyle* style = (MTMathStyle*) atom;
            NSDictionary* styleToCommands = [MTMathListBuilder styleToCommands];
            NSString* command = styleToCommands[@(style.style)];
            [str appendFormat:@"\\%@", command];
        } else if (atom.type == kMTMathAtomOrderedPair) {
            MTOrderedPair* pair = (MTOrderedPair*) atom;
            [str appendFormat:@"(%@,%@)", [self mathListToString:pair.leftOperand ], [self mathListToString:pair.rightOperand]];
            //Below line can be uncommented for ordered pair
            //            [str appendFormat:@"\\left(%@,%@\\right)", [self mathListToString:pair.leftOperand ], [self mathListToString:pair.rightOperand]];
        }
        else if (atom.type == kMTMathAtomAbsoluteValue) {
            MTAbsoluteValue* absValue = (MTAbsoluteValue*) atom;
            [str appendFormat:@"\\abs{%@}", [self mathListToString:absValue.absHolder]];
        }
        else if (atom.type == kMTMathAtomExponentBase) {
            MTExponent* exp = (MTExponent*) atom;
            if(exp.prefixedSubScript){
                [str appendFormat:@"%@_", [self mathListToString:exp.prefixedSubScript]];
            }
            [str appendFormat:@"%@", [self mathListToString:exp.exponent]];
          
            if(exp.expSubScript){
                [str appendFormat:@"_{%@}", [self mathListToString:exp.expSubScript]];
            }
            if (exp.expSuperScript) {
                [str appendFormat:@"^{%@}", [self mathListToString:exp.expSuperScript]];
            }
        }
        else if (atom.nucleus.length == 0) {
            [str appendString:@"{}"];
        } else if ([atom.nucleus isEqualToString:@"\u2236"]) {
            // math colon
            [str appendString:@":"];
        } else if ([atom.nucleus isEqualToString:@"\u2212"]) {
            // math minus
            [str appendString:@"-"];
        }
        else if ([atom.nucleus isEqualToString:@"\u2211"]) {
            // math sum
            [str appendString:@"\\sum"];
        }
        else if ([atom.nucleus isEqualToString:@"\u222b"]) {
            // math integral
            [str appendString:@"\\int"];
        }
        else if(atom.type == kMTMathAtomLargeOperator){
            MTLargeOperator* operator = (MTLargeOperator*) atom;
            if([operator.nucleus isEqualToString:@"int"] && !operator.limits) {
                [str appendFormat:@"\\%@{}", operator.nucleus];
            } else if([operator.nucleus isEqualToString:@"log"] && !operator.limits) {
              [str appendFormat:@"\\%@", operator.nucleus];
            }
            else {
                if([[self trignometrySymbols] containsObject: operator.nucleus]) {
                    isTrignometry = true;
                  [str appendFormat:@"\\%@", operator.nucleus];
                } else {
                    isTrignometry = false;
                    [str appendString:operator.nucleus];
                }
                if(operator.holder) {
                  // TODO: make sure stringValue knows how to render it's own symbols latex so it can be used instead of calling mathListToString recursevely here
                  // [str appendFormat:@"\\left(%@\\right)", operator.holder.stringValue];
                  [str appendFormat:@"\\left(%@\\right)", [self mathListToString:operator.holder]];
                }
                
                //            if (operator.subScript) {
                //                [str appendFormat:@"_{%@}", operator.subScript.stringValue];
                //            }
                //            if (operator.superScript) {
                //                [str appendFormat:@"^{%@}", operator.superScript.stringValue];
                //            }
            }
            
        }
        else if (atom.type == kMTMathAtomUnder) {
            MTUnder* under = (MTUnder*) atom;
            [str appendFormat:@"\\undr{%@}{%@}", [self mathListToString:under.primary], [self mathListToString:under.secondary]];
        }
        else {
            NSString* command = [MTMathAtomFactory latexSymbolNameForAtom:atom];
            if (command) {
                [str appendFormat:@"\\%@", command];
            } else {
                [str appendString:atom.nucleus];
            }
        }
        
        if (atom.subScript) {
            [str appendFormat:@"_{%@}", [self mathListToString:atom.subScript]];
        }
        
        if (atom.superScript) {
            [str appendFormat:@"^{%@}", [self mathListToString:atom.superScript]];
        }
        
    }
    return [str copy];
}

#pragma mark - TDX Bundle

- (NSBundle *)getTDXBundle {
    NSString *mainBundlePath = [[NSBundle mainBundle] resourcePath];
    NSString *frameworkBundlePath = [mainBundlePath stringByAppendingPathComponent:@"Frameworks/TDXLib.framework/TDXLib.bundle"];
    NSBundle *frameworkBundle = [NSBundle bundleWithPath:frameworkBundlePath];
    return frameworkBundle;
}

#pragma mark Exponents

- (MTExponent*)buildSuperScriptWithList:(MTMathList*)sublist {
    MTExponent *exponent = [MTExponent new];
    if(exponent.exponent == nil){
        exponent.exponent = [MTMathList mathListWithAtoms:[sublist.atoms lastObject], nil];
        [self makeChildAtom:exponent.exponent.atoms];
        [sublist removeLastAtom];
    }
    exponent.expSuperScript = [self buildInternal:true];
    [self makeChildAtom:exponent.expSuperScript.atoms];
    BOOL yes = [self expectCharacter:'_'];
    if (yes) {
        exponent.expSubScript = [self buildInternal:true];
        [self makeChildAtom:exponent.expSubScript.atoms];
    }
    return exponent;
}

- (MTExponent*)buildSubScriptWithList:(MTMathList*)sublist {
    MTExponent *exponent = [MTExponent new];
    if(exponent.exponent == nil){
        exponent.exponent = [MTMathList mathListWithAtoms:[sublist.atoms lastObject], nil];
        [sublist removeLastAtom];
        [self makeChildAtom:exponent.exponent.atoms];
    }
    exponent.expSubScript = [self buildInternal:true];
    [self makeChildAtom:exponent.expSubScript.atoms];
    BOOL isBeforeSubscript = [self expectCharacter:'_'];
    if (isBeforeSubscript) {
        exponent.prefixedSubScript = [MTMathList mathListWithAtomsArray:exponent.exponent.atoms];
        [exponent.exponent removeAtoms];
        [self makeChildAtom:exponent.prefixedSubScript.atoms];
        exponent.exponent = nil;
        exponent.exponent = [MTMathList mathListWithAtomsArray:exponent.expSubScript.atoms];
        [exponent.expSubScript removeAtoms];
        [self makeChildAtom:exponent.exponent.atoms];
        exponent.expSubScript = nil;
        exponent.expSubScript = [self buildInternal:true];
        [self makeChildAtom:exponent.expSubScript.atoms];
    }
    BOOL isSuperScript = [self expectCharacter:'^'];
    if (isSuperScript) {
        exponent.expSuperScript = [self buildInternal:true];
        [self makeChildAtom:exponent.expSuperScript.atoms];
    }
    return exponent;
}
#pragma mark Integral and Summation with Limits

- (void)buildLargeOpWithLimits:(MTMathAtom*)atom {
    BOOL yesUnderscore = [self expectCharacter:'_'];
    NSArray *trigEquivalents = @[@"sin", @"cos", @"tan", @"csc", @"sec", @"cot"];
    if (yesUnderscore) {
        MTLargeOperator *largeOp = (MTLargeOperator*)atom;
        [largeOp setLimits:true];
        unichar ch1 = [self getNextCharacter];
        if (ch1 == '{') {
            MTMathList* sublist = [self buildInternal:false stopChar:'}'];
            largeOp.subScript = sublist;
        }
        BOOL yesSuperscript = [self expectCharacter:'^'];
        if (yesSuperscript) {
            unichar ch2 = [self getNextCharacter];
            if (ch2 == '{') {
                MTMathList* sublist = [self buildInternal:false stopChar:'}'];
                largeOp.superScript = sublist;
                [self makeChildAtom: sublist.atoms];
            }
        }
    } else if ([[MTMathListBuilder trignometrySymbols] containsObject: atom.nucleus] || [trigEquivalents containsObject:atom.nucleus]) {
        MTLargeOperator *trigOp = (MTLargeOperator*)atom;
        MTMathList* sublist = [self buildInternal:false stopChar:')'];
        [sublist removeAtomAtIndex:0];
        trigOp.holder = sublist;
        [self makeChildAtom:sublist.atoms];
        atom.isChildAtom = true;
    }
}

- (void)buildAccent:(MTMathAtom*)atom {
    if([atom.nucleus isEqualToString:@"\u0307"]) {
        unichar ch = [self getNextCharacter];
        if (ch == '{') {
            MTMathList* sublist = [self buildInternal:false stopChar:'}'];
            MTAccent *accent = (MTAccent*)atom;
            accent.innerList = sublist;
        }
    }
}

@end
