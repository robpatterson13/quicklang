//
//  Parser.swift
//  swift-student-challenge-2025
//
//  Created by Rob Patterson on 2/4/25.
//

struct Parser {
    
    var tokens: PeekableIterator<Token>
    
    init(for tokens: [Token]) {
        self.tokens = PeekableIterator(elements: tokens)
    }
    
    //\
    //  parser interface, main entry point from
    //   compiler driver.
    //
    //   loops on calls to parse if more tokens
    //\
    mutating func beginParse() throws -> [ASTNode] {
        
        var nodes: [ASTNode] = []
        
        while !tokens.isEmpty() {
            nodes.append(try parse())
        }
        
        return nodes
    }
    
    //\
    //  responsible for parsing function and variable definitions,
    //   in addition to function calls;
    //   everything else is unexpected and will throw.
    //
    //   you should never expect to parse a literal!
    //\
    mutating func parse() throws -> ASTNode {
        
        guard let currentToken = tokens.next() else {
            throw ParseError.internalParserError(location: nil, message: "beginParse should never be called with an empty token stream")
        }
        
        switch currentToken {
        // the interesting cases!
        case .Keyword("func", let loc):
            return try parseFunctionDefinition()
            
        case .Keyword("var", let loc), .Keyword("let", let loc):
            tokens.push(currentToken)
            return try parseDefinition()
            
        case .Identifier(_, let loc):
            tokens.push(currentToken)
            return try parseFunctionApplication()
            
        // the uninteresting cases
        case .Boolean(_, let loc):
            throw ParseError.unexpectedBoolean(location: loc)
        case .Number(_, let loc):
            throw ParseError.unexpectedNumber(location: loc)
        case .Keyword(let word, let loc):
            throw ParseError.unexpectedKeyword(location: loc)
        case .Symbol(_, let loc):
            throw ParseError.unexpectedSymbol(location: loc)
        }
    }
    
    mutating private func parseFunctionDefinition() throws -> Definition {
        
        let identifier = try self.parseIdentifier()
        
        guard let hopefullyOpenParen = tokens.next(),
              hopefullyOpenParen == .Symbol("(", location: SourceCodeLocation.dummySourceCodeLocation) else {
            throw ParseError.expectedToken(location: Token.getSourceCodeLocation(of: tokens.prev()!), expected: "(")
        }
        
        let parameters = try self.parseFunctionParameters()
        
        guard let hopefullyCloseParen = tokens.next(),
              hopefullyCloseParen == .Symbol(")", location: SourceCodeLocation.dummySourceCodeLocation) else {
            throw ParseError.expectedToken(location: Token.getSourceCodeLocation(of: tokens.prev()!), expected: "(")
        }
        
        return .FunctionDefinition(name: identifier, parameters: parameters, body: try parseFunctionBody())
    }
    
    mutating private func parseFunctionBody() throws -> [ASTNode] {
        
        var bodyParts: [ASTNode] = []
        
        guard let hopefullyOpenBrace = tokens.next(),
              hopefullyOpenBrace == .Symbol("{", location: SourceCodeLocation.dummySourceCodeLocation) else {
            throw ParseError.expectedToken(location: Token.getSourceCodeLocation(of: tokens.prev()!), expected: "{")
        }
        
        while let nextToken = tokens.next(),
              nextToken != .Symbol("}", location: SourceCodeLocation.dummySourceCodeLocation) {
            bodyParts.append(try parse())
        }
        
        if tokens.prev()! != .Symbol("}", location: SourceCodeLocation.dummySourceCodeLocation) {
            throw ParseError.expectedClosingBrace(location: Token.getSourceCodeLocation(of: hopefullyOpenBrace))
        }
        
        return bodyParts
    }
    
    //\
    //  parses var and let variable definitions.
    //
    //  > !! <
    //  invariant: parseDefinition is only called
    //   is only called right after a push onto
    //   tokens
    //\
    mutating private func parseDefinition() throws -> Definition {
        
        let identifier = try self.parseIdentifier()
        
        guard let hopefullyEquals = tokens.next(),
              hopefullyEquals == .Symbol("=", location: SourceCodeLocation.dummySourceCodeLocation) else {
            
            throw ParseError.expectedToken(location: Token.getSourceCodeLocation(of: tokens.prev()!), expected: "=")
        }
        
        let boundExpression = try parseExpression()
        
        guard let hopefullySemicolon = tokens.next(),
              hopefullySemicolon == .Symbol(";", location: SourceCodeLocation.dummySourceCodeLocation) else {
            
            throw ParseError.expectedToken(location: Token.getSourceCodeLocation(of: tokens.prev()!), expected: ";")
        }
        
        let keyword = tokens.next()!
        switch keyword {
        case .Keyword("var", _):
            return .VarDefinition(binding: (identifier, boundExpression))
        case .Keyword("let", _):
            return .VarDefinition(binding: (identifier, boundExpression))
        default:
            throw ParseError.internalParserError(location: Token.getSourceCodeLocation(of: keyword), message: "")
        }
    }
    
    mutating private func parseExpression() throws -> Expression {
        
    }
    
    //\
    //  parses function and variable ids.
    //\
    mutating private func parseIdentifier() throws -> String {
        
        guard let nextToken = tokens.next() else {
            throw ParseError.expectedIdentifier(location: nil)
        }
        
        switch nextToken {
        case .Identifier(let name, _):
            return name
        default:
            throw ParseError.expectedIdentifier(location: Token.getSourceCodeLocation(of: nextToken))
        }
    }
    
    //\
    //  parses function parameters; comes in a tuple of
    //   identifier and PrimType
    //\
    mutating private func parseFunctionParameters() throws -> Definition.Parameters {
        
        var parameters: Definition.Parameters = []
        
        while let nextToken = tokens.next(),
                nextToken != .Symbol(")", location: SourceCodeLocation.dummySourceCodeLocation) {
            let identifier = try parseIdentifier()
            
            guard let hopefullyColon = tokens.next(),
                    hopefullyColon == .Symbol(":", location: SourceCodeLocation.dummySourceCodeLocation) else {
                
                throw ParseError.expectedParameterType(location: Token.getSourceCodeLocation(of: tokens.prev()!))
            }
            
            let type = try parseType()
            
            parameters.append((identifier, type))
            
            if let maybeComma = tokens.next(),
               maybeComma != .Symbol(",", location: SourceCodeLocation.dummySourceCodeLocation) {
                
                tokens.push(maybeComma)
                return parameters
            }
        }
        
        return parameters
    }
    
    //\
    //  returns individual arguments of a function application;
    //   ensures that arguments are expressions
    //\
    mutating private func parseFunctionApplicationArgument() throws -> Expression {
        
        guard let nextToken = tokens.next() else {
            throw ParseError.expectedFunctionArgument(location: Token.getSourceCodeLocation(of: tokens.prev()!))
        }
        
        switch nextToken {
        case .Boolean(_, _), .Identifier(_, _), .Number(_, _):
            tokens.push(nextToken)
            return try parseExpression()
            
        default:
            throw ParseError.expectedFunctionArgument(location: Token.getSourceCodeLocation(of: nextToken))
        }
    }
    
    mutating private func parseFunctionApplication() throws -> Expression {
        
        let identifier = try parseIdentifier()
        
        guard let hopefullyOpenParen = tokens.next(),
                hopefullyOpenParen == .Symbol("(", location: SourceCodeLocation.dummySourceCodeLocation) else {
            throw ParseError.expectedFunctionApplication(location: Token.getSourceCodeLocation(of: tokens.prev()!))
        }
        
        var expressions: [Expression] = []
        
        while let nextToken = tokens.next(),
                nextToken != .Symbol(")", location: SourceCodeLocation.dummySourceCodeLocation) {
            
            expressions.append(try parseExpression())
            
            if let maybeComma = tokens.next(),
               maybeComma != .Symbol(",", location: SourceCodeLocation.dummySourceCodeLocation) {
                break
            }
        }
        
        let lastToken = tokens.prev()!
        guard lastToken == .Symbol(")", location: SourceCodeLocation.dummySourceCodeLocation) else {
            throw ParseError.expectedClosingParen(location: Token.getSourceCodeLocation(of: lastToken))
        }
        
        return .FunctionApplication(name: identifier, arguments: expressions)
    }
    
    mutating private func parseType() throws -> PrimType {
        
        guard let nextToken = tokens.next() else {
            
            // we can force unwrap; parseType will never be called
            //  at index 0 of iterator (i.e we never expect a type
            //  at the beginning of a file)
            throw ParseError.expectedTypeIdentifier(location: Token.getSourceCodeLocation(of: tokens.prev()!))
        }
        
        switch nextToken {
        case .Keyword(let kw, _):
            if kw == "Int" {
                return .TInt
            } else if kw == "Bool" {
                return .TBool
            } else if kw == "String" {
                return .TString
            } else {
                fallthrough
            }
        default:
            throw ParseError.expectedTypeIdentifier(location: Token.getSourceCodeLocation(of: nextToken))
        }
    }
}

extension Parser {
    
    enum ParseError: Error {
        case expectedTypeIdentifier(location: SourceCodeLocation?)
        case expectedParameterType(location: SourceCodeLocation)
        case expectedIdentifier(location: SourceCodeLocation?)
        
        case expectedFunctionApplication(location: SourceCodeLocation)
        case expectedFunctionArgument(location: SourceCodeLocation)
        
        case unexpectedBoolean(location: SourceCodeLocation)
        case unexpectedNumber(location: SourceCodeLocation)
        case unexpectedString(location: SourceCodeLocation)
        case unexpectedSymbol(location: SourceCodeLocation)
        case unexpectedKeyword(location: SourceCodeLocation)
        
        case internalParserError(location: SourceCodeLocation?, message: String)
        
        case expectedToken(location: SourceCodeLocation, expected: String)
        
        case expectedClosingBrace(location: SourceCodeLocation)
        case expectedClosingParen(location: SourceCodeLocation)
    }
}
