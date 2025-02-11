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
    mutating private func parse() throws -> ASTNode {
        
        guard let currentToken = tokens.next() else {
            let message = """
                          Expected input; file cannot be empty
                          """
            throw ParseError(message: message, errorType: .expectedToken)
        }
        
        switch currentToken {
        // the interesting cases!
        case .Keyword("func", _):
            return try parseFunctionDefinition()
            
        case .Keyword("var", _), .Keyword("let", _):
            tokens.push(currentToken)
            return try parseDefinition()
            
        case .Identifier(_, _):
            tokens.push(currentToken)
            return try parseFunctionApplication()
            
        // the uninteresting cases
        case .Boolean(let val, _):
            let (line, column) = Token.getSourceCodeLocation(of: tokens.prev()!).startLineColumnLocation()
            let message = """
                          Unexpected boolean "\(val)" at line \(line), column \(column)"
                          """
            throw ParseError(message: message, errorType: .unexpectedBoolean)
            
        case .Number(let val, _):
            let (line, column) = Token.getSourceCodeLocation(of: tokens.prev()!).startLineColumnLocation()
            let message = """
                          Unexpected number "\(val)" at line \(line), column \(column)"
                          """
            throw ParseError(message: message, errorType: .unexpectedNumber)
            
        case .Keyword(let val, _):
            let (line, column) = Token.getSourceCodeLocation(of: tokens.prev()!).startLineColumnLocation()
            let message = """
                          Unexpected keyword "\(val)" at line \(line), column \(column)"
                          """
            throw ParseError(message: message, errorType: .unexpectedKeyword)
            
        case .Symbol(let val, _):
            let (line, column) = Token.getSourceCodeLocation(of: tokens.prev()!).startLineColumnLocation()
            let message = """
                          Unexpected symbol "\(val)" at line \(line), column \(column)"
                          """
            throw ParseError(message: message, errorType: .unexpectedSymbol)
            
        }
    }
    
    mutating private func parseFunctionDefinition() throws -> Definition {
        
        let identifier = try self.parseIdentifier()
        
        guard let hopefullyOpenParen = tokens.next(),
              hopefullyOpenParen == .Symbol("(", location: SourceCodeLocation.dummySourceCodeLocation) else {
            
            let (line, column) = Token.getSourceCodeLocation(of: tokens.prev()!).startLineColumnLocation()
            let message = """
                          Expected '(' at line \(line), column \(column)
                          to begin signature of "\(identifier)"
                          """
            throw ParseError(message: message, errorType: .expectedToken)
        }
        
        let parameters = try self.parseFunctionParameters()
        
        return .FunctionDefinition(name: identifier, parameters: parameters, body: try parseFunctionBody())
    }
    
    mutating private func parseFunctionBody() throws -> [ASTNode] {
        
        var bodyParts: [ASTNode] = []
        
        guard let hopefullyOpenBrace = tokens.next(),
              hopefullyOpenBrace == .Symbol("{", location: SourceCodeLocation.dummySourceCodeLocation) else {
            
            let (line, column) = Token.getSourceCodeLocation(of: tokens.prev()!).startLineColumnLocation()
            let message = """
                          Expected '{' at line \(line), column \(column)
                          to begin function body definition
                          """
            throw ParseError(message: message, errorType: .expectedClosingBrace)
        }
        
        while let nextToken = tokens.peekNext(),
              nextToken != .Symbol("}", location: SourceCodeLocation.dummySourceCodeLocation) {
            
            if let bodyPart = try parseFunctionBodyPart() {
                bodyParts.append(bodyPart)
            }
        }
        
        guard let nextToken = tokens.next(),
           nextToken == .Symbol("}", location: SourceCodeLocation.dummySourceCodeLocation) else {
            
            let (line, column) = Token.getSourceCodeLocation(of: tokens.prev()!).startLineColumnLocation()
            let (openingLine, openingColumn) = Token.getSourceCodeLocation(of: hopefullyOpenBrace).startLineColumnLocation()
            let message = """
                          Expected '}' at line \(line), column \(column)
                          to close function definition started at line
                          \(openingLine), column \(openingColumn)
                          """
            throw ParseError(message: message, errorType: .expectedClosingBrace)
        }
        
        return bodyParts
    }
    
    mutating private func parseFunctionBodyPart() throws -> ASTNode? {
        
        guard let currentToken = tokens.peekNext() else {
            let (line, _) = Token.getSourceCodeLocation(of: tokens.prev()!).startLineColumnLocation()
            let message = """
                          Expected closing brace for function at line \(line + 1)"
                          """
            throw ParseError(message: message, errorType: .expectedToken)
        }
        
        switch currentToken {
        // the interesting cases!
        case .Keyword("var", _), .Keyword("let", _):
            tokens.push(currentToken)
            return try parseDefinition()
            
        case .Identifier(_, _):
            tokens.push(currentToken)
            return try parseFunctionApplication()
            
        case .Keyword("return", _):
            let _ = tokens.next()
            return Statement.ReturnStatement(value: try parseExpression())
            
        case .Symbol("}", _):
            let _ = tokens.next()
            return nil
            
        // the uninteresting cases
        case .Boolean(let val, _):
            let (line, column) = Token.getSourceCodeLocation(of: tokens.prev()!).startLineColumnLocation()
            let message = """
                          Unexpected boolean "\(val)" at line \(line), column \(column)"
                          """
            throw ParseError(message: message, errorType: .unexpectedBoolean)
            
        case .Number(let val, _):
            let (line, column) = Token.getSourceCodeLocation(of: tokens.prev()!).startLineColumnLocation()
            let message = """
                          Unexpected number "\(val)" at line \(line), column \(column)"
                          """
            throw ParseError(message: message, errorType: .unexpectedNumber)
            
        case .Keyword(let val, _):
            let (line, column) = Token.getSourceCodeLocation(of: tokens.prev()!).startLineColumnLocation()
            let message = """
                          Unexpected keyword "\(val)" at line \(line), column \(column)"
                          """
            throw ParseError(message: message, errorType: .unexpectedKeyword)
            
        case .Symbol(let val, _):
            let (line, column) = Token.getSourceCodeLocation(of: tokens.prev()!).startLineColumnLocation()
            let message = """
                          Unexpected symbol "\(val)" at line \(line), column \(column)"
                          """
            throw ParseError(message: message, errorType: .unexpectedSymbol)
            
        }
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
        
        let keyword = tokens.next()!
        
        let identifier = try self.parseIdentifier()
        
        guard let hopefullyEquals = tokens.next(),
              hopefullyEquals == .Symbol("=", location: SourceCodeLocation.dummySourceCodeLocation) else {
            
            let (line, column) = Token.getSourceCodeLocation(of: tokens.prev()!).startLineColumnLocation()
            let message = """
                          Expected '=' at line \(line), column \(column)
                          to begin definition of "\(identifier)"
                          """
            throw ParseError(message: message, errorType: .expectedToken)
        }
        
        let boundExpression = try parseExpression()
        
        guard let hopefullySemicolon = tokens.next(),
              hopefullySemicolon == .Symbol(";", location: SourceCodeLocation.dummySourceCodeLocation) else {
            
            let (line, column) = Token.getSourceCodeLocation(of: tokens.prev()!).startLineColumnLocation()
            let message = """
                          Expected ';' at line \(line), column \(column)
                          to end definition of "\(identifier)"
                          """
            throw ParseError(message: message, errorType: .expectedToken)
        }
        
        switch keyword {
        case .Keyword("var", _):
            return .VarDefinition(binding: (identifier, boundExpression))
        case .Keyword("let", _):
            return .LetDefinition(binding: (identifier, boundExpression))
        default:
            let (line, column) = Token.getSourceCodeLocation(of: keyword).startLineColumnLocation()
            let message = """
                          Keyword must be var or let,
                          received "\(Token.getValue(of: keyword))"
                          at line \(line), column \(column)
                          """
            throw ParseError(message: message, errorType: .internalParserError)
        }
    }
    
    mutating private func parseExpression() throws -> Expression {
        tokens.next()
        return .BooleanLiteral(value: true)
    }
    
    //\
    //  parses function and variable ids.
    //\
    mutating private func parseIdentifier() throws -> String {
        
        guard let nextToken = tokens.next() else {
            let (line, column) = Token.getSourceCodeLocation(of: tokens.prev()!).startLineColumnLocation()
            let message = """
                          Expected identifier at line \(line), column \(column),
                          after "\(Token.getValue(of: tokens.prev()!))"
                          """
            throw ParseError(message: message, errorType: .expectedIdentifier)
        }
        
        switch nextToken {
        case .Identifier(let name, _):
            return name
        default:
            let (line, column) = Token.getSourceCodeLocation(of: nextToken).startLineColumnLocation()
            let message = """
                          Expected identifier at line \(line), column \(column), 
                          got "\(Token.getValue(of: nextToken))" instead
                          """
            throw ParseError(message: message, errorType: .expectedIdentifier)
        }
    }
    
    //\
    //  parses function parameters; comes in a tuple of
    //   identifier and PrimType
    //\
    mutating private func parseFunctionParameters() throws -> Definition.Parameters {
        
        var parameters: Definition.Parameters = []
        
        while let nextToken = tokens.peekNext(),
                nextToken != .Symbol(")", location: SourceCodeLocation.dummySourceCodeLocation) {
            
            let identifier = try self.parseIdentifier()
            
            guard let hopefullyColon = tokens.next(),
                    hopefullyColon == .Symbol(":", location: SourceCodeLocation.dummySourceCodeLocation) else {
                
                let (line, column) = Token.getSourceCodeLocation(of: nextToken).startLineColumnLocation()
                let message = "Expected ':' to declare type after parameter name at line \(line), column \(column)"
                throw ParseError(message: message, errorType: .expectedParameterType)
            }
            
            let type = try parseType()
            
            parameters.append((identifier, type))
            
            if let maybeCloseParen = tokens.peekNext(),
                maybeCloseParen == .Symbol(")", location: SourceCodeLocation.dummySourceCodeLocation) {
                
                let _ = tokens.next()
                return parameters
                
            }
            
            if let hopefullyComma = tokens.next(),
                  hopefullyComma != .Symbol(",", location: SourceCodeLocation.dummySourceCodeLocation) {
                
                let (line, column) = Token.getSourceCodeLocation(of: nextToken).startLineColumnLocation()
                let message = "Expected a comma between function parameters at line \(line), column \(column)"
                throw ParseError(message: message, errorType: .expectedParameterType)
            }
                  
        }
        
        return parameters
    }
    
    //\
    //  returns individual arguments of a function application;
    //   ensures that arguments are expressions
    //\
    mutating private func parseFunctionApplicationArgument() throws -> Expression {
        
        guard let nextToken = tokens.peekNext() else {
            let (line, column) = Token.getSourceCodeLocation(of: tokens.prev()!).startLineColumnLocation()
            throw ParseError(message: """
                                      Expected a function application for the identifier "\(Token.getValue(of: tokens.prev()!))"
                                      at line \(line), column \(column)
                                      """,
                             errorType: .expectedFunctionArgument)
        }
        
        switch nextToken {
        case .Boolean(_, _), .Identifier(_, _), .Number(_, _):
            return try parseExpression()
            
        default:
            let (line, column) = Token.getSourceCodeLocation(of: nextToken).startLineColumnLocation()
            throw ParseError(message: """
                                      Expected an expression as an argument at 
                                      line \(line), column \(column), got "\(Token.getValue(of: nextToken))" instead
                                      """,
                             errorType: .expectedFunctionArgument)
        }
    }
    
    mutating private func parseFunctionApplication() throws -> Expression {
        
        let identifier = try parseIdentifier()
        
        guard let hopefullyOpenParen = tokens.next(),
                hopefullyOpenParen == .Symbol("(", location: SourceCodeLocation.dummySourceCodeLocation) else {
            
            let (line, column) = Token.getSourceCodeLocation(of: tokens.prev()!).startLineColumnLocation()
            throw ParseError(message: "Expected a function application to begin with an opening parenthesis at line \(line), column \(column)",
                             errorType: .expectedFunctionApplication)
        }
        
        var expressions: [Expression] = []
        
        while let nextToken = tokens.peekNext(),
                nextToken != .Symbol(")", location: SourceCodeLocation.dummySourceCodeLocation) {
            expressions.append(try parseFunctionApplicationArgument())
            
            guard let maybeComma = tokens.peekNext() else {
                break
            }
            
            if maybeComma == .Symbol(",", location: SourceCodeLocation.dummySourceCodeLocation) {
                let _ = tokens.next()
            }
        }
        
        guard let lastToken = tokens.next(),
              lastToken == .Symbol(")", location: SourceCodeLocation.dummySourceCodeLocation) else {
            let (line, column) = Token.getSourceCodeLocation(of: tokens.prev()!).startLineColumnLocation()
            throw ParseError(message: """
                                      Expected a closing paren, ")", at line \(line), column \(column),
                                      after the function application
                                      """,
                             errorType: .expectedClosingParen)
        }
        
        return .FunctionApplication(name: identifier, arguments: expressions)
    }
    
    mutating private func parseType() throws -> PrimType {
        
        guard let nextToken = tokens.next() else {
            
            // we can force unwrap; parseType will never be called
            //  at index 0 of iterator (i.e we never expect a type
            //  at the beginning of a file)
            let (line, column) = Token.getSourceCodeLocation(of: tokens.prev()!).startLineColumnLocation()
                                        
            throw ParseError(message: "Expected type identifier for parameter being defined at line \(line), column \(column)",
                             errorType: .expectedTypeIdentifier)
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
            let (line, column) = Token.getSourceCodeLocation(of: nextToken).startLineColumnLocation()
                                        
            throw ParseError(message: "Expected type identifier for parameter being defined at line \(line), column \(column)",
                             errorType: .expectedTypeIdentifier)
        }
    }
}

extension Parser {
    
    struct ParseError: Error {
        var message: String
        var errorType: ParseErrorType
    }
    
    enum ParseErrorType {
        case expectedTypeIdentifier
        case expectedParameterType
        case expectedIdentifier
        
        case expectedFunctionApplication
        case expectedFunctionArgument
        
        case unexpectedBoolean
        case unexpectedNumber
        case unexpectedString
        case unexpectedSymbol
        case unexpectedKeyword
        
        case internalParserError
        
        case expectedToken
        
        case expectedClosingBrace
        case expectedClosingParen
    }
}
