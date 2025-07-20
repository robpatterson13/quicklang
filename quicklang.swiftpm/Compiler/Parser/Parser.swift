//
//  Parser.swift
//  swift-student-challenge-2025
//
//  Created by Rob Patterson on 2/4/25.
//

struct Parser {
    
    let errorManager: ParserErrorManager
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
    mutating func beginParse() throws -> TopLevel {
        
        var nodes: [any TopLevelNode] = []
        
        while !tokens.isEmpty() {
            nodes.append(try parse())
        }
        
        return TopLevel(sections: nodes)
    }
    
    private func error(_ token: Token, _ error: ParseErrorType) {
        guard let tokenLoc = Token.getSourceCodeLocation(of: token).startLineColumnLocation() as? (Int, Int) else {
            fatalError("Token should always have source location")
        }
        
        errorManager.add(ParseError(errorType: error, location: tokenLoc))
    }
    
    mutating private func expect(_ token: Token, _ errorToThrow: ParseErrorType) {
        guard let currentToken = tokens.next(),
            currentToken == token else {
            
                guard let tokenLoc = Token.getSourceCodeLocation(of: token).startLineColumnLocation() as? (Int, Int) else {
                    fatalError("Token should always have source location")
                }
            
            let error = ParseError(errorType: errorToThrow, location: tokenLoc)
            errorManager.add(error)
            
//                let (line, column) = Token.getSourceCodeLocation(of: tokens.prev()!).startLineColumnLocation()
//                let message = """
//                              Expected ';' to end top-level function call at line \(line), column \(column)
//                              """
//                throw ParseError(message: message, errorType: .unexpectedBoolean)
        }
    }
    
    //\
    //  responsible for parsing function and variable definitions,
    //   in addition to function calls;
    //   everything else is unexpected and will throw.
    //
    //   you should never expect to parse a literal!
    mutating private func parse() throws -> TopLevelNode {
        
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
            let val = try parseFunctionApplication()
            
            expect(Token.SEMICOLON, .expectedSemicolonToEndFunctionCall)
            
            guard let hopefullySemicolon = tokens.next(),
                  Token.getValue(of: hopefullySemicolon) == ";" else {
                let (line, column) = Token.getSourceCodeLocation(of: tokens.prev()!).startLineColumnLocation()
                let message = """
                              Expected ';' to end top-level function call at line \(line), column \(column)
                              """
                throw ParseError(message: message, errorType: .unexpectedBoolean)
            }
            return val
            
        // the uninteresting cases
        case .Boolean(let val, _):
            error(tokens.prev()!, .unexpectedBoolean)
            
//            let (line, column) = Token.getSourceCodeLocation(of: tokens.prev()!).startLineColumnLocation()
//            let message = """
//                          Unexpected boolean "\(val)" at line \(line), column \(column)"
//                          """
//            throw ParseError(message: message, errorType: .unexpectedBoolean)
            
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
    //  responsible for parsing the function identifier and signature
    //   passes off calls for function params and body
    //\
    mutating private func parseFunctionDefinition() throws -> FuncDefinition {
        
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
        
        guard let hopefullyOpenParen = tokens.next(),
              hopefullyOpenParen == .Symbol(")", location: SourceCodeLocation.dummySourceCodeLocation) else {
            
            let (line, column) = Token.getSourceCodeLocation(of: tokens.prev()!).startLineColumnLocation()
            let message = """
                          Expected ')' at line \(line), column \(column)
                          to close signature of "\(identifier)"
                          """
            throw ParseError(message: message, errorType: .expectedToken)
        }
        
        guard let hopefullyArrow = tokens.next(),
              hopefullyArrow == .Symbol("->", location: SourceCodeLocation.dummySourceCodeLocation) else {
            
            let (line, column) = Token.getSourceCodeLocation(of: tokens.prev()!).startLineColumnLocation()
            let message = """
                          Expected '->' at line \(line), column \(column)
                          to begin signature of "\(identifier)"
                          """
            throw ParseError(message: message, errorType: .expectedToken)
        }
        
        let typeName = try self.parseType()
        
        return FuncDefinition(name: identifier, type: typeName, parameters: parameters, body: try parseBlock())
    }
    
    //\
    //  responsible for parsing a braced block (ex. function bodies, if statements)
    //\
    mutating private func parseBlock() throws -> [any BlockLevelNode] {
        
        var bodyParts: [any BlockLevelNode] = []
        
        guard let hopefullyOpenBrace = tokens.next(),
              hopefullyOpenBrace == .Symbol("{", location: SourceCodeLocation.dummySourceCodeLocation) else {
            
            let (line, column) = Token.getSourceCodeLocation(of: tokens.prev()!).startLineColumnLocation()
            let message = """
                          Expected '{' at line \(line), column \(column)
                          to begin block definition
                          """
            throw ParseError(message: message, errorType: .expectedClosingBrace)
        }
        
        while let nextToken = tokens.peekNext(),
              nextToken != .Symbol("}", location: SourceCodeLocation.dummySourceCodeLocation) {
            
            if let bodyPart = try parseBlockBodyPart() {
                bodyParts.append(bodyPart)
            }
        }
        
        guard let nextToken = tokens.next(),
           nextToken == .Symbol("}", location: SourceCodeLocation.dummySourceCodeLocation) else {
            
            let (line, column) = Token.getSourceCodeLocation(of: tokens.prev()!).startLineColumnLocation()
            let (openingLine, openingColumn) = Token.getSourceCodeLocation(of: hopefullyOpenBrace).startLineColumnLocation()
            let message = """
                          Expected '}' at line \(line), column \(column)
                          to close block definition started at line
                          \(openingLine), column \(openingColumn)
                          """
            throw ParseError(message: message, errorType: .expectedClosingBrace)
        }
        
        return bodyParts
    }
    
    //\
    //  responsible for parsing if statements
    //\
    mutating private func parseIfStatement() throws -> IfStatement {
        
        let keyword = tokens.next()!
        
        guard let hopefullyParen = tokens.next(),
              hopefullyParen == .Symbol("(", location: SourceCodeLocation.dummySourceCodeLocation) else {
            let (line, column) = Token.getSourceCodeLocation(of: tokens.prev()!).startLineColumnLocation()
            let message = """
                          Expected condition for if statement at line \(line), column \(column)"
                          """
            throw ParseError(message: message, errorType: .expectedToken)
        }
        
        let condition = try parseExpression(until: ")", min: 0)
        
        guard let hopefullyCloseParen = tokens.next(),
              hopefullyCloseParen == .Symbol(")", location: SourceCodeLocation.dummySourceCodeLocation) else {
            let (line, column) = Token.getSourceCodeLocation(of: tokens.prev()!).startLineColumnLocation()
            let message = """
                          Expected ')' to close condition at line \(line), column \(column)"
                          """
            throw ParseError(message: message, errorType: .expectedToken)
        }
        
        let thnBlock = try parseBlock()
        
        guard let hopefullyElse = tokens.next(),
              hopefullyElse == .Keyword("else", location: SourceCodeLocation.dummySourceCodeLocation) else {
            let (line, column) = Token.getSourceCodeLocation(of: keyword).startLineColumnLocation()
            let message = """
                          Expected else branch of if statement at line \(line), column \(column)"
                          """
            throw ParseError(message: message, errorType: .expectedToken)
        }
        
        let elsBlock = try parseBlock()
        
        return IfStatement(condition: condition, thenBranch: thnBlock, elseBranch: elsBlock)
    }
    
    //\
    //  parses a return statement
    //\
    mutating private func parseReturnStatement() throws -> ReturnStatement {
        
        let node = ReturnStatement(expression: try parseExpression(until: ";", min: 0))
        
        guard let hopefullySemicolon = tokens.next(),
              Token.getValue(of: hopefullySemicolon) == ";" else {
            let (line, column) = Token.getSourceCodeLocation(of: tokens.prev()!).startLineColumnLocation()
            let message = """
                          Expected ';' at line \(line), column \(column)
                          to end return statement"
                          """
            throw ParseError(message: message, errorType: .expectedToken)
        }
        
        return node
    }
    
    //\
    //  responsible for parsing block level parts (statements, definitions, etc.)
    //\
    mutating private func parseBlockBodyPart() throws -> BlockLevelNode? {
        
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
            return try parseDefinition()
            
        case .Identifier(_, _):
            return try parseFunctionApplication()
            
        case .Keyword("return", _):
            let _ = tokens.next()
            return try parseReturnStatement()
            
        case .Keyword("if", _):
            return try parseIfStatement()
            
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
    mutating private func parseDefinition() throws -> any DefinitionNode {
        
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
        
        let boundExpression = try parseExpression(until: ";", min: 0)
        
        guard let hopefullySemicolon = tokens.next(),
              Token.getValue(of: hopefullySemicolon) == ";" else {
            
            let (line, column) = Token.getSourceCodeLocation(of: tokens.prev()!).startLineColumnLocation()
            let message = """
                          Expected ';' at line \(line), column \(column)
                          to end definition of "\(identifier)"
                          """
            throw ParseError(message: message, errorType: .expectedToken)
        }
        
        switch keyword {
        case .Keyword("var", _):
            return VarDefinition(name: identifier, expression: boundExpression)
        case .Keyword("let", _):
            return LetDefinition(name: identifier, expression: boundExpression)
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
    
    //\
    //  parses an atomic expression (identifier, function call, boolean, number)
    //\
    mutating private func parseAtomic(_ token: Token) throws -> any ExpressionNode {
        switch token {
        case let .Identifier(id, _):
            if let maybeParen = tokens.peekNext(),
               Token.getValue(of: maybeParen) == "(" {
                tokens.push(token)
                return try parseFunctionApplication()
            } else {
                return IdentifierExpression(name: id)
            }
            
        case let .Number(n, _):
            return NumberExpression(value: Int(n)!)
            
        case let .Boolean(b, _):
            return BooleanExpression(value: Bool(b)!)
            
        default:
            let (line, column) = Token.getSourceCodeLocation(of: tokens.prev()!).startLineColumnLocation()
            let message = """
                          Expected an atom at line \(line), column \(column)
                          """
            throw ParseError(message: message, errorType: .expectedAtomic)
        }
    }
    
    //\
    //  parses an expression.
    //
    //  infinite thank you to https://matklad.github.io/2020/04/13/simple-but-powerful-pratt-parsing.html
    //\
    mutating private func parseExpression(until end: String, min: Int) throws -> any ExpressionNode {
        guard let lhs = tokens.next(),
              Token.isAtomic(lhs) else {
            let (line, column) = Token.getSourceCodeLocation(of: tokens.prev()!).startLineColumnLocation()
            let message = """
                          Expected expression at line \(line), column \(column)
                          """
            throw ParseError(message: message, errorType: .expectedExpression)
        }
        
        var lhsNode = try parseAtomic(lhs)
        
        while true {
            if let maybeEnd = tokens.peekNext(),
               Token.getValue(of: maybeEnd) == end {
                break
            }
            
            guard let op = tokens.peekNext(),
                  Token.isOp(op) else {
                let (line, column) = Token.getSourceCodeLocation(of: tokens.prev()!).startLineColumnLocation()
                let message = """
                              Expected operator at line \(line), column \(column)
                              """
                throw ParseError(message: message, errorType: .expectedOperator)
            }
            
            let (lBp, rBp) = bindingPower(of: op)!
            
            guard lBp >= min else {
                break
            }
            
            let _ = tokens.next()
            let rhsNode = try parseExpression(until: end, min: rBp)
            
            var opVal: BinaryOperator
            switch Token.getValue(of: op) {
            case "+":
                opVal = BinaryOperator.plus
            case "-":
                opVal = BinaryOperator.minus
            case "*":
                opVal = BinaryOperator.times
            case "&&":
                opVal = BinaryOperator.and
            case "||":
                opVal = BinaryOperator.or
            default:
                fatalError() // TODO
            }
            
            lhsNode = BinaryOperation(op: opVal, lhs: lhsNode, rhs: rhsNode)
        }
        
        return lhsNode
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
    mutating private func parseFunctionParameters() throws -> [FuncDefinition.Parameter] {
        
        var parameters: [FuncDefinition.Parameter] = []
        
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
    mutating private func parseFunctionApplicationArgument() throws -> any ExpressionNode {
        
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
            return try parseExpression(until: ")", min: 0)
            
        default:
            let (line, column) = Token.getSourceCodeLocation(of: nextToken).startLineColumnLocation()
            throw ParseError(message: """
                                      Expected an expression as an argument at 
                                      line \(line), column \(column), got "\(Token.getValue(of: nextToken))" instead
                                      """,
                             errorType: .expectedFunctionArgument)
        }
    }
    
    //\
    //  parses a function application (ex. id(param1, param2, ...))
    //\
    mutating private func parseFunctionApplication() throws -> FuncApplication {
        
        let identifier = try parseIdentifier()
        
        guard let hopefullyOpenParen = tokens.next(),
                hopefullyOpenParen == .Symbol("(", location: SourceCodeLocation.dummySourceCodeLocation) else {
            
            let (line, column) = Token.getSourceCodeLocation(of: tokens.prev()!).startLineColumnLocation()
            throw ParseError(message: "Expected a function application to begin with an opening parenthesis at line \(line), column \(column)",
                             errorType: .expectedFunctionApplication)
        }
        
        var expressions: [any ExpressionNode] = []
        
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
        
        return FuncApplication(name: identifier, arguments: expressions)
    }
    
    //\
    //  parses a type identifier; used for parameter declarations in
    //   function signatures
    //\
    mutating private func parseType() throws -> TypeName {
        
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
                return .Int
            } else if kw == "Bool" {
                return .Bool
            } else if kw == "String" {
                return .String
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
    
    // gets binding power of an expression symbol
    private func bindingPower(of token: Token) -> (Int, Int)? {
        var op: String
        
        switch token {
        case let .Symbol(symbol, _):
            op = symbol
        default:
            return nil
        }
        
        switch op {
        case "+", "-":
            return (1, 2)
        case "*", "/":
            return (3, 4)
        default:
            return nil
        }
    }
}
