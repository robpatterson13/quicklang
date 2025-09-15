//
//  Parser.swift
//  swift-student-challenge-2025
//
//  Created by Rob Patterson on 2/4/25.
//

class Parser {
    
    let errorManager: ParserErrorManager
    var tokens: PeekableIterator<Token>
    
    init(for tokens: [Token]) {
        self.tokens = PeekableIterator(elements: tokens)
    }
    
    func beginParse() -> TopLevel {
        
        var nodes: [any TopLevelNode] = []
        
        while !tokens.isEmpty() {
            nodes.append(parse())
        }
        
        return TopLevel(sections: nodes)
    }
    
    private func error(_ error: ParserErrorType) {
        
        let location = tokens.peekNext()?.location
        ?? tokens.peekPrev()?.location
        ?? .beginningOfFile
        
        errorManager.add(error, at: location)
    }
    
    @discardableResult
    private func expect(_ token: Token? = nil, else error: ParserErrorType, burnToken: Bool = false) -> Token {
        
        if token == nil, tokens.peekNext() == nil {
            self.error(error)
        }
            
        guard let token, let currentToken = tokens.peekNext(), currentToken == token else {
            self.error(error)
        }
        
        if burnToken {
            tokens.burn()
        }
        
        return currentToken
    }
    
    private func expectAndBurn(_ token: Token, else error: ParserErrorType) {
        expect(token, else: error, burnToken: true)
    }
    
    private func parse() -> TopLevelNode {
        
        let currentToken = expect(else: .expectedTopLevelStatement(got: .eof))
        
        switch currentToken {
        // the interesting cases!
        case .Keyword("func", _):
            return parseFunctionDefinition()
            
        case .Keyword("var", _), .Keyword("let", _):
            return parseDefinition()
            
        case .Identifier:
            return parseFunctionApplication()
            
        // the uninteresting cases
        case .Boolean:
            self.error(.expectedTopLevelStatement(got: .boolean))
            
        case .Number:
            self.error(.expectedTopLevelStatement(got: .number))
            
        case .Keyword(let val, _):
            self.error(.expectedTopLevelStatement(got: .keyword(val)))
            
        case .Symbol(let val, _):
            self.error(.expectedTopLevelStatement(got: .symbol(val)))
            
        }
    }

    private func parseFunctionDefinition() -> FuncDefinition {
        
        expectAndBurn(.FUNC, else: .internalParserError(type: .unreachable("Can only be called when func keyword is encountered")))
        
        let identifier = parseIdentifier(in: .functionDefinition)
        
        expectAndBurn(.LPAREN, else: .expectedLeftParen(where: .functionDefinition))
        let parameters = parseFunctionParameters()
        expectAndBurn(.RPAREN, else: .expectedRightParen(where: .functionDefinition))
        
        expectAndBurn(.ARROW, else: .expectedArrowInFunctionDefinition)
        
        let typeName = parseType()
        
        let body = parseBlock(in: .functionBody)
        
        return FuncDefinition(name: identifier, type: typeName, parameters: parameters, body: body)
    }
    
    private enum BlockContext {
        case ifStatement
        case functionBody
        
        var errorTypeForLeft: ExpectedLeftBraceErrorInfo.ErrorType {
            switch self {
            case .ifStatement:
                return .ifStatement
            case .functionBody:
                return .functionBody
            }
        }
        
        var errorTypeForRight: ExpectedRightBraceErrorInfo.ErrorType {
            switch self {
            case .ifStatement:
                return .ifStatement
            case .functionBody:
                return .functionBody
            }
        }
    }
    
    private func parseBlock(in usage: BlockContext) -> [any BlockLevelNode] {
        
        var bodyParts: [any BlockLevelNode] = []
        
        expectAndBurn(.LBRACE, else: .expectedLeftBrace(where: usage.errorTypeForLeft))
        
        while let nextToken = tokens.peekNext(), nextToken != .RBRACE {
            
            if let bodyPart = parseBlockBodyPart() {
                bodyParts.append(bodyPart)
            }
        }
        
        expect(.RBRACE, else: .expectedRightBrace(where: usage.errorTypeForRight))
        
        return bodyParts
    }
    
    private func parseIfStatement() -> IfStatement {
        
        expectAndBurn(.IF, else: .internalParserError(type: .unreachable("This should never be reached without an if being parsed")))
        
        expectAndBurn(.LPAREN, else: .expectedLeftParen(where: .ifStatement))
        let condition = parseExpression(until: ")", min: 0)
        expectAndBurn(.RPAREN, else: .expectedRightParen(where: .ifStatement))
        
        let thnBlock = parseBlock(in: .ifStatement)
        
        guard let token = tokens.next(), token == .ELSE else {
            return IfStatement(condition: condition, thenBranch: thnBlock, elseBranch: nil)
        }
        
        let elsBlock = parseBlock(in: .ifStatement)
        
        return IfStatement(condition: condition, thenBranch: thnBlock, elseBranch: elsBlock)
    }
    
    private func parseReturnStatement() -> ReturnStatement {
        
        expectAndBurn(.RETURN, else: .internalParserError(type: .unreachable("We should never get here without first parsing a return token")))
        
        let node = ReturnStatement(expression: parseExpression(until: ";", min: 0))
        
        expectAndBurn(.SEMICOLON, else: .expectedSemicolonToEndStatement(of: .return))
        
        return node
    }
    
    private func parseBlockBodyPart() -> BlockLevelNode? {
        
        let currentToken = expect(else: .expectedBlockBodyPart(got: .eof))
        
        switch currentToken {
        // the interesting cases!
        case .Keyword("var", _), .Keyword("let", _):
            return parseDefinition()
            
        case .Identifier:
            return parseFunctionApplication()
            
        case .Keyword("return", _):
            return parseReturnStatement()
            
        case .Keyword("if", _):
            return parseIfStatement()
            
        case .Symbol("}", _):
            return nil
            
        // the uninteresting cases
        case .Boolean:
            self.error(.expectedBlockBodyPart(got: .boolean))
            
        case .Number:
            self.error(.expectedBlockBodyPart(got: .number))
            
        case .Keyword(let val, _):
            self.error(.expectedBlockBodyPart(got: .keyword(val)))
            
        case .Symbol(let val, _):
            self.error(.expectedBlockBodyPart(got: .symbol(val)))
            
        }
    }
    
    private func parseDefinition() -> any DefinitionNode {
        
        let keyword = expect(else: .internalParserError(type: .unreachable("There should be a keyword here")))
        
        let identifier = self.parseIdentifier(in: .valueDefinition)
        
        expectAndBurn(.EQUAL, else: .expectedEqualInAssignment)
        
        let boundExpression = parseExpression(until: ";", min: 0)
        
        expectAndBurn(.SEMICOLON, else: .expectedSemicolonToEndStatement(of: .definition))
        
        switch keyword {
        case .Keyword("var", _):
            return VarDefinition(name: identifier, expression: boundExpression)
        case .Keyword("let", _):
            return LetDefinition(name: identifier, expression: boundExpression)
        default:
            self.error(
                .internalParserError(
                    type: .unreachable("Keyword must be let or var in definition, got \(keyword.value)")
                )
            )
        }
    }
    
    private func parseAtomic(_ token: Token) -> any ExpressionNode {
        switch token {
        case let .Identifier(id, _):
            if let maybeParen = tokens.peekNext(), maybeParen == .LPAREN {
                return parseFunctionApplication()
            } else {
                return IdentifierExpression(name: id)
            }
            
        case let .Number(n, _):
            return NumberExpression(value: Int(n)!)
            
        case let .Boolean(b, _):
            return BooleanExpression(value: Bool(b)!)
            
        default:
            self.error(.expectedAtomic)
        }
    }
    
    //  infinite thank you to https://matklad.github.io/2020/04/13/simple-but-powerful-pratt-parsing.html
    private func parseExpression(until end: String, min: Int) -> any ExpressionNode {
        let lhs = expect(else: .expectedExpression)
        
        var lhsNode = parseAtomic(lhs)
        
        while true {
            if let maybeEnd = tokens.peekNext(), maybeEnd.value == end {
                break
            }
            
            guard let op = tokens.peekNext(), op.isOp() else {
                self.error(.expectedOperator)
            }
            
            let (lBp, rBp) = op.bindingPower
            
            guard lBp >= min else {
                break
            }
            
            tokens.burn()
            let rhsNode = parseExpression(until: end, min: rBp)
            
            var opVal: BinaryOperator
            switch op.value {
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
    
    private enum IdentifierUsage {
        case functionDefinition
        case valueDefinition
        case functionParameter
        case functionApplication
        
        var errorType: ExpectedIdentifierErrorInfo.ErrorType {
            switch self {
            case .functionDefinition:
                return .functionDefinition
            case .valueDefinition:
                return .valueDefinition
            case .functionParameter:
                return .functionParameter
            case .functionApplication:
                return .functionApplication
            }
        }
    }
    
    private func parseIdentifier(in usage: IdentifierUsage) -> String {
        
        let currentToken = expect(else: .expectedIdentifier(in: usage.errorType), burnToken: true)
        
        switch currentToken {
        case .Identifier(let name, _):
            return name
        default:
            error(.expectedIdentifier(in: usage.errorType))
        }
    }
    
    private func parseFunctionParameters() -> [FuncDefinition.Parameter] {
        
        var parameters: [FuncDefinition.Parameter] = []
        
        while let nextToken = tokens.peekNext(), nextToken != .RPAREN {
            
            let identifier = parseIdentifier(in: .functionParameter)
            
            expectAndBurn(.SEMICOLON, else: .expectedParameterType)
            
            let type = parseType()
            
            parameters.append((identifier, type))
            
            if let maybeCloseParen = tokens.peekNext(), maybeCloseParen == .RPAREN {
                return parameters
            }
            
            expectAndBurn(.COMMA, else: .expectedParameterType)
                  
        }
        
        return parameters
    }
    
    private func parseFunctionApplicationArgument() -> any ExpressionNode {
        
        let nextToken = expect(else: .expectedFunctionArgument(got: .eof))
        
        switch nextToken {
        case .Boolean(_, _), .Identifier(_, _), .Number(_, _):
            return parseExpression(until: ")", min: 0)
        case .Keyword(let kw, _):
            self.error(.expectedFunctionArgument(got: .keyword(kw)))
        case .Symbol(let s, _):
            self.error(.expectedFunctionArgument(got: .symbol(s)))
        }
    }
    
    private func parseFunctionApplication() -> FuncApplication {
        
        let identifier = parseIdentifier(in: .functionApplication)
        
        expectAndBurn(.LPAREN, else: .expectedFunctionApplication)
        
        var expressions: [any ExpressionNode] = []
        
        while let nextToken = tokens.peekNext(), nextToken != .RPAREN {
            expressions.append(parseFunctionApplicationArgument())
            
            guard let maybeComma = tokens.peekNext() else {
                break
            }
            
            if maybeComma == .COMMA {
                tokens.burn()
            }
        }
        
        expectAndBurn(.RPAREN, else: .expectedRightParen(where: .functionApplication))
        
        expectAndBurn(.SEMICOLON, else: .expectedSemicolonToEndFunctionCall)
        
        return FuncApplication(name: identifier, arguments: expressions)
    }
    
    private func parseType() -> TypeName {
        
        let nextToken = expect(else: .expectedTypeIdentifier)
        
        switch nextToken {
        case .Keyword(let kw, _) where kw == "Int":
            return .Int
        case .Keyword(let kw, _) where kw == "Bool":
            return .Bool
        case .Keyword(let kw, _) where kw == "String":
            return .String
        default:
            self.error(.expectedTypeIdentifier)
        }
    }
}
