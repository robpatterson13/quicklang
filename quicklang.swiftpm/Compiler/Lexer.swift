//
//  Lexer.swift
//  swift-student-challenge-2025
//
//  Created by Rob Patterson on 2/4/25.
//

struct Lexer {
    
    typealias SourceCode = String
    typealias LexerLocation = (line: Int, column: Int)
    
    private var tokens: [Token] = []
    private var currentCharIndex: Int = 0
    private var location = LexerLocation(0, 0)
    private var sourceLength: Int
    private var sourceCode: SourceCode
    
    init(for sourceCode: SourceCode) {
        self.sourceCode = sourceCode
        self.sourceLength = sourceCode.count
    }
    
    mutating private func peekNextCharacter() -> Character? {
        
        if self.currentCharIndex >= self.sourceLength {
            return nil
        }
        
        return self.sourceCode[self.sourceCode.index(self.sourceCode.startIndex, offsetBy: self.currentCharIndex)]
    }
    
    mutating private func consumeCharacter() -> Character {
        
        let char = self.sourceCode[self.sourceCode.index(self.sourceCode.startIndex, offsetBy: self.currentCharIndex)]
        self.currentCharIndex += 1
        self.location.column += 1
        
        return char
    }
    
    mutating private func consumeWhitespace(char: Character) {
        
        self.currentCharIndex += 1
        
        switch char {
        case "\n":
            self.location.line += 1
            self.location.column = 0
        case "\t":
            self.location.column += 4 // XCode
        case " ":
            self.location.column += 1
        default:
            break // unreachable
        }
    }
    
    mutating func tokenize() throws -> Array<Token> {
        
        while self.currentCharIndex < self.sourceLength {
            let currentChar = self.sourceCode[self.sourceCode.index(self.sourceCode.startIndex, offsetBy: self.currentCharIndex)]
            
            if currentChar.isLetter {
                self.tokens.append(self.tokenizeWord())
            } else if currentChar.isNumber {
                self.tokens.append(try self.tokenizeNumber())
            } else if currentChar.isPunctuation || currentChar.isSymbol {
                self.tokens.append(try self.tokenizePunctuation())
            } else if currentChar.isWhitespace {
                self.consumeWhitespace(char: currentChar)
            } else {
                throw LexerError.unknownCharacter
            }
        }
        
        return self.tokens
    }
    
    mutating private func tokenizeWord() -> Token {
        
        var locationBuilder = SourceCodeLocationBuilder()
        locationBuilder.startLine = self.location.line
        locationBuilder.startColumn = self.location.column
        var lexeme = String(self.consumeCharacter())
        
        while let nextChar = self.peekNextCharacter(), nextChar.isLetter || nextChar.isNumber {
            lexeme += String(self.consumeCharacter())
        }
        
        locationBuilder.endLine = self.location.line
        locationBuilder.endColumn = self.location.column
            
        switch lexeme {
        case "true", "false":
            return .Boolean(lexeme, location: locationBuilder.build())
        case "for", "while":
            fallthrough
        case "func", "return":
            fallthrough
        case "Int", "Bool", "String":
            fallthrough
        case "let", "var":
            fallthrough
        case "if", "else":
            return .Keyword(lexeme, location: locationBuilder.build())
        default:
            return .Identifier(lexeme, location: locationBuilder.build())
        }
    }
    
    mutating private func tokenizeNumber() throws -> Token {
        
        var locationBuilder = SourceCodeLocationBuilder()
        locationBuilder.startLine = self.location.line
        locationBuilder.startColumn = self.location.column
        var lexeme = String(self.consumeCharacter())
        
        while let nextChar = self.peekNextCharacter(), nextChar.isNumber {
            guard nextChar != "." else {
                throw LexerError.floatsNotSupported
            }
            
            lexeme += String(self.consumeCharacter())
        }
        
        locationBuilder.endLine = self.location.line
        locationBuilder.endColumn = self.location.column
        return Token.Number(lexeme, location: locationBuilder.build())
    }
    
    mutating private func tokenizePunctuation() throws -> Token {
        
        var locationBuilder = SourceCodeLocationBuilder()
        locationBuilder.startLine = self.location.line
        locationBuilder.startColumn = self.location.column
        var lexeme = String(self.consumeCharacter())
        
        switch lexeme {
        case "+", "=", "<", ">":
            guard let nextChar = self.peekNextCharacter(),
                    nextChar == "=" else {
                break
            }
            
            lexeme += String(self.consumeCharacter())
        default:
            guard ["-", "*", "(", ")", ":", "{", "}", "!", ","].contains(lexeme) else {
                throw LexerError.unknownCharacter
            }
        }
        
        locationBuilder.endLine = self.location.line
        locationBuilder.endColumn = self.location.column
        return Token.Symbol(lexeme, location: locationBuilder.build())
    }
}

extension Lexer {
    
    enum LexerError: Error {
        case expectedWhitespace
        case unknownCharacter
        case floatsNotSupported
    }
}
