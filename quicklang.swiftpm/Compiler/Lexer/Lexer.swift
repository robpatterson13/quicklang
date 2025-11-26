//
//  Lexer.swift
//  swift-student-challenge-2025
//
//  Created by Rob Patterson on 2/4/25.
//

import Foundation

final class LexerSyntaxInfoManager {
    
    enum SyntaxType {
        case keyword
        case booleanLiteral
        case numLiteral
        case identifier
        case symbol
        
        static func getSyntaxType(from token: Token) -> SyntaxType {
            switch token {
            case .Identifier:
                return .identifier
            case .Keyword:
                return .keyword
            case .Number:
                return .numLiteral
            case .Boolean:
                return .booleanLiteral
            case .Symbol:
                return .symbol
            }
        }
    }
    
    typealias SyntaxInfo = (Token, NSRange)
    typealias SyntaxMapping = [SyntaxType : [SyntaxInfo]]
    
    var mapping: SyntaxMapping = .init()
    
    func addMapping(for token: Token, at loc: Int) {
        let info = buildSyntaxInfo(from: token, at: loc)
        let syntaxType = SyntaxType.getSyntaxType(from: token)
        
        mapping[syntaxType, default: []].append(info)
    }
    
    private func buildSyntaxInfo(from token: Token, at loc: Int) -> SyntaxInfo {
        let len = token.value.count
        let range = NSRange(location: loc - len, length: len)
        return (token, range)
    }
}

final class Lexer: CompilerPhase {
    
    typealias InputType = SourceCode
    typealias SuccessfulResult = Array<Token>
    
    typealias SourceCode = String
    typealias LexerLocation = (line: Int, column: Int)
    
    private var tokens: [Token] = []
    private var currentCharIndex: Int = 0
    private var location = LexerLocation(0, 0)
    private var sourceLength: Int = 0
    private var sourceCode: SourceCode = ""
    
    private let errorManager: CompilerErrorManager
    
    private let syntaxManager = LexerSyntaxInfoManager()
    
    init(errorManager: CompilerErrorManager) {
        self.errorManager = errorManager
    }
    
    func begin(_ input: SourceCode) -> PhaseResult<Lexer> {
        sourceCode = input
        sourceLength = sourceCode.count
        
        do {
            return .success(result: try tokenize())
        } catch let e as LexerErrorWrapper {
            errorManager.addError(e.error)
            return .failure
        } catch {
            fatalError("Unknown lexer error")
        }
    }
    
    private func peekNextCharacter() -> Character? {
        
        if self.currentCharIndex >= self.sourceLength {
            return nil
        }
        
        return self.sourceCode[self.sourceCode.index(self.sourceCode.startIndex, offsetBy: self.currentCharIndex)]
    }
    
    private func consumeCharacter() -> Character {
        
        let char = self.sourceCode[self.sourceCode.index(self.sourceCode.startIndex, offsetBy: self.currentCharIndex)]
        self.currentCharIndex += 1
        self.location.column += 1
        
        return char
    }
    
    private func consumeWhitespace(char: Character) {
        
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
    
    private func tokenize() throws -> SuccessfulResult {
        
        while self.currentCharIndex < self.sourceLength {
            
            var locationBuilder = SourceCodeLocationBuilder()
            locationBuilder.startLine = self.location.line
            locationBuilder.endLine = self.location.line
            locationBuilder.startColumn = self.location.column
            locationBuilder.endColumn = self.location.column + 1
            
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
                try throwError(.unknownCharacter(char: String(currentChar)), locationBuilder: locationBuilder)
            }
        }
        
        return self.tokens
    }
    
    private func tokenizeWord() -> Token {
        
        var locationBuilder = SourceCodeLocationBuilder()
        locationBuilder.startLine = self.location.line
        locationBuilder.startColumn = self.location.column
        var lexeme = String(self.consumeCharacter())
        
        while let nextChar = self.peekNextCharacter(), nextChar.isLetter || nextChar.isNumber {
            lexeme += String(self.consumeCharacter())
        }
        
        locationBuilder.endLine = self.location.line
        locationBuilder.endColumn = self.location.column
            
        let token: Token
        switch lexeme {
        case "true", "false":
            token = .Boolean(lexeme, location: locationBuilder.build())
            syntaxManager.addMapping(for: token, at: currentCharIndex)
        case "for", "while":
            fallthrough
        case "func", "return":
            fallthrough
        case "Int", "Bool", "String":
            fallthrough
        case "let", "var":
            fallthrough
        case "if", "else":
            token = .Keyword(lexeme, location: locationBuilder.build())
            syntaxManager.addMapping(for: token, at: currentCharIndex)
        default:
            token = .Identifier(lexeme, location: locationBuilder.build())
        }
        
        return token
    }
    
    private func tokenizeNumber() throws -> Token {
        
        var locationBuilder = SourceCodeLocationBuilder()
        locationBuilder.startLine = self.location.line
        locationBuilder.startColumn = self.location.column
        
        var lexeme = String(self.consumeCharacter())
        
        locationBuilder.endLine = self.location.line
        locationBuilder.endColumn = self.location.column
        
        while let nextChar = self.peekNextCharacter(), nextChar.isNumber {
            guard nextChar != "." else {
                try throwError(.floatsNotSupported, locationBuilder: locationBuilder)
            }
            
            lexeme += String(self.consumeCharacter())
        }
        
        let token = Token.Number(lexeme, location: locationBuilder.build())
        syntaxManager.addMapping(for: token, at: currentCharIndex)
        return token
    }
    
    private func tokenizePunctuation() throws -> Token {
        
        var locationBuilder = SourceCodeLocationBuilder()
        locationBuilder.startLine = self.location.line
        locationBuilder.startColumn = self.location.column
        
        var lexeme = String(self.consumeCharacter())
        
        locationBuilder.endLine = self.location.line
        locationBuilder.endColumn = self.location.column
        
        switch lexeme {
        case "-":
            if self.peekNextCharacter() == ">" {
                lexeme += String(self.consumeCharacter())
            }
            fallthrough
        case "+", "=", "<", ">":
            guard let nextChar = self.peekNextCharacter(),
                    nextChar == "=" else {
                break
            }
            
            lexeme += String(self.consumeCharacter())
        default:
            guard ["*", "(", ")", ":", "{", "}", "!", ",", ";"].contains(lexeme) else {
                try throwError(.unknownCharacter(char: lexeme), locationBuilder: locationBuilder)
            }
        }
        return Token.Symbol(lexeme, location: locationBuilder.build())
    }
    
    private func throwError(
        _ type: LexerError.ErrorType,
        locationBuilder: SourceCodeLocationBuilder
    ) throws -> Never {
        
        let location = locationBuilder.build()
        let error = LexerError(type: type, location: location)
        throw LexerErrorWrapper(error: error)
    }
    
    func getSyntaxMapping() -> LexerSyntaxInfoManager.SyntaxMapping {
        return syntaxManager.mapping
    }
}

struct LexerErrorWrapper: Error {
    let error: LexerError
}

struct LexerError: CompilerPhaseError {
    let location: SourceCodeLocation
    let message: String
    private let type: ErrorType
    
    enum ErrorType {
        case expectedWhitespace
        case unknownCharacter(char: String)
        case floatsNotSupported
    }
    
    init(type: ErrorType, location: SourceCodeLocation) {
        self.type = type
        self.location = location
        self.message = Self.makeMessage(from: type)
    }
    
    private static func makeMessage(from type: ErrorType) -> String {
        switch type {
        case .expectedWhitespace:
            "Expected whitespace"
        case .unknownCharacter(let char):
            "Character \(char) not supported in Quick"
        case .floatsNotSupported:
            "Floats are not supported in Quick"
        }
    }
}
