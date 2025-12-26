//
//  Parser.swift
//  swift-student-challenge-2025
//
//  Created by Rob Patterson on 2/4/25.
//

final class Parser: CompilerPhase {
    
    typealias InputType = Lexer.SuccessfulResult
    typealias SuccessfulResult = ASTContext
    
    private let errorManager: CompilerErrorManager
    private var tokens = PeekableIterator<Token>(elements: [])
    
    private var context = ASTContext()
    
    private let recoveryEngine: any RecoveryEngine
    
    init(errorManager: CompilerErrorManager, settings: DriverSettings) {
        self.errorManager = errorManager
        recoveryEngine = settings.parserRecoveryStrategy
    }
    
    func begin(_ input: Lexer.SuccessfulResult) -> PhaseResult<Parser> {
        var nodes: [any RawTopLevelNode] = []
        self.tokens = PeekableIterator(elements: input)
        while !tokens.isEmpty() {
            let node = parseTopLevel()
            nodes.append(node)
        }
        
        context.rawTree = RawTopLevel(sections: nodes)
        if errorManager.hasErrors {
            return .failure
        }
        
        return .success(result: context)
    }
    
    private func error(_ error: ParserErrorType) -> RecoveryStrategy {
        
        let location = tokens.peekNext()?.location
        ?? tokens.peekPrev()?.location
        ?? .beginningOfFile
        
        let parserErrorInfo = error.buildInfo(at: location)
        let parserError = parserErrorInfo.getError(from: DefaultParserErrorCreator.shared)
        errorManager.addError(parserError)
        return recoveryEngine.recover(from: error)
    }
    
    private func expect(
        _ token: Token? = nil,
        else error: ParserErrorType,
        burnToken: Bool = false
    ) -> Result<Token, RecoveryStrategy> {
        
        let burnIfNeeded = {
            if burnToken {
                self.tokens.burn()
            }
        }
        
        // we just need something to exist next
        if token == nil, let currentToken = tokens.peekNext() {
            burnIfNeeded()
            return .success(currentToken)
        }
        
        // we need something to exist next and we have a token to compare to
        if let token, let currentToken = tokens.peekNext(), currentToken == token {
            burnIfNeeded()
            return .success(currentToken)
        }
        
        let strategy = self.error(error)
        return .failure(strategy)
    }
    
    private func consume(_ token: Token? = nil, else error: ParserErrorType) -> RecoveryStrategy? {
        switch expect(token, else: error, burnToken: true) {
        case .success:
            return nil
        case .failure(let strategy):
            return strategy
        }
    }
    
    private func handleUnrecoverable() {
        tokens.moveToEnd()
    }
    
    private func peek(comparing: Token, burn: Bool = false) -> Bool {
        guard let next = tokens.peekNext() else { return false }
        if next == comparing {
            tokens.burn()
            return true
        }
        
        return false
    }
    
    private func recover(using strategy: RecoveryStrategy) {
        
        func dropUntil(_ set: RecoveryStrategy.RecoverySet) {
            while let token = tokens.next() {
                if set.contains(token) {
                    return
                }
            }
        }
        
        switch strategy {
        case .dropUntil(let set):
            dropUntil(set)
            return
            
        case .add(let token):
            // MARK: Implement
            return
            
        case .ignore:
            return
            
        case .unrecoverable:
            handleUnrecoverable()
            
        case .override(with: let newStrategy):
            recover(using: newStrategy)
        }
    }
    
    private func parseTopLevel() -> any RawTopLevelNode {
        
        let currentToken: Token
        let result = expect(else: .expectedTopLevelStatement(got: .eof))
        switch result {
        case .success(let token):
            currentToken = token
        case .failure(let strategy):
            recover(using: strategy)
            return RawTopLevelNodeIncomplete.incomplete
        }
        
        switch currentToken {
        case .Keyword("func", _):
            return parseFunctionDefinition()
            
        case .Symbol("@", _):
            return parseAttributedConstruct()
            
        case .Boolean:
            let strategy = self.error(.expectedTopLevelStatement(got: .boolean))
            recover(using: strategy)
            return RawTopLevelNodeIncomplete.incomplete
            
        case .Number:
            let strategy =  self.error(.expectedTopLevelStatement(got: .number))
            recover(using: strategy)
            return RawTopLevelNodeIncomplete.incomplete
            
        case .Identifier(let val, _):
            let strategy = self.error(.expectedTopLevelStatement(got: .identifier(val)))
            recover(using: strategy)
            return RawTopLevelNodeIncomplete.incomplete
            
        case .Keyword(let val, _):
            let strategy = self.error(.expectedTopLevelStatement(got: .keyword(val)))
            recover(using: strategy)
            return RawTopLevelNodeIncomplete.incomplete
            
        case .Symbol(let val, _):
            let strategy = self.error(.expectedTopLevelStatement(got: .symbol(val)))
            recover(using: strategy)
            return RawTopLevelNodeIncomplete.incomplete
        }
    }
    
    private func parseAttributedConstruct() -> RawAttributedNode {
        let recoverFromAtMissing = consume(
            .AT,
            else: .internalParserError(type: .unreachable("Can only be called when @ is encountered"))
        )
        if let recoverFromAtMissing {
            recover(using: recoverFromAtMissing)
            return .incomplete
        }
        
        guard let identifier = parseIdentifier(in: .assignmentStatement) else {
            return .incomplete
        }
        
        let attribute: RawAttributedNode.AttributeName
        switch identifier {
        case "main":
            attribute = .main
            
        default:
            let recoverFromNonexistantAttribute = self.error(.expectedValidAttribute(in: .notAnAttribute(identifier)))
            recover(using: recoverFromNonexistantAttribute)
            return .incomplete
        }
        
        let result = expect(.FUNC, else: .expectedTopLevelStatement(got: .eof))
        switch result {
        case .success:
            break
        case .failure(let strategy):
            recover(using: strategy)
            return .incomplete
        }
        
        let functionDefinition = parseFunctionDefinition()
        guard !functionDefinition.anyIncomplete else {
            return .incomplete
        }
        
        return RawAttributedNode(attribute: attribute, node: functionDefinition)
    }
    
    private enum ParseIdentifierErrorType {
        case eof
        case boolean
        case number
        case keyword(String)
        case symbol(String)
        case identifier(String)
        
        var topLevel: ExpectedTopLevelStatementErrorInfo.ErrorType {
            switch self {
            case .eof:
                return .eof
            case .boolean:
                return .boolean
            case .number:
                return .number
            case .keyword(let string):
                return .keyword(string)
            case .symbol(let string):
                return .symbol(string)
            case .identifier(let string):
                return .identifier(string)
            }
        }
        
        var blockLevel: ExpectedBlockBodyPartErrorInfo.ErrorType {
            switch self {
            case .eof:
                return .eof
            case .boolean:
                return .boolean
            case .number:
                return .number
            case .keyword(let string):
                return .keyword(string)
            case .symbol(let string):
                return .symbol(string)
            case .identifier(let string):
                return .identifier(string)
            }
        }
    }
    
    private func errorFromParseIdentifierStart(
        got type: ParseIdentifierErrorType,
        at site: IdentifierSite
    ) -> any RawBlockLevelNode {
        
        let error: ParserErrorType
        switch site {
        case .topLevel:
            error = .expectedTopLevelStatement(got: type.topLevel)
        case .block:
            error = .expectedBlockBodyPart(got: type.blockLevel)
        }
        let strategy = self.error(error)
        recover(using: strategy)
        
        switch site {
        case .topLevel:
            return RawTopLevelNodeIncomplete.incomplete
        case .block:
            return RawBlockLevelNodeIncomplete.incomplete
        }
    }
    
    private enum IdentifierSite {
        case topLevel
        case block
    }
    
    private func parseIdentifierStart(in site: IdentifierSite) -> any RawBlockLevelNode {
        guard let twoAhead = tokens.peek(ahead: 2) else {
            return errorFromParseIdentifierStart(got: .eof, at: site)
        }
        
        switch twoAhead {
        case .LPAREN:
            switch site {
            case .topLevel:
                return parseTopLevelFunctionApplication()
            case .block:
                return parseFunctionApplication()
            }
            
        case .EQUAL:
            return parseAssignmentStatement()
            
        case .Identifier(let string, _):
            return errorFromParseIdentifierStart(got: .identifier(string), at: site)
            
        case .Keyword(let string, _):
            return errorFromParseIdentifierStart(got: .keyword(string), at: site)
            
        case .Number:
            return errorFromParseIdentifierStart(got: .number, at: site)
            
        case .Boolean:
            return errorFromParseIdentifierStart(got: .boolean, at: site)
            
        case .Symbol(let string, _):
            return errorFromParseIdentifierStart(got: .symbol(string), at: site)
        }
    }
    
    private func parseTopLevelIdentifier() -> any RawTopLevelNode {
        return parseIdentifierStart(in: .topLevel) as! any RawTopLevelNode
    }
    
    private func parseBlockLevelIdentifier() -> any RawBlockLevelNode {
        return parseIdentifierStart(in: .block)
    }
    
    private func parseAssignmentStatement() -> RawAssignmentStatement {
        guard let identifier = parseIdentifier(in: .assignmentStatement) else {
            return RawAssignmentStatement.incomplete
        }
        
        let recoverFromEqualMissing = consume(.EQUAL, else: .expectedEqualInAssignment)
        if let recoverFromEqualMissing {
            recover(using: recoverFromEqualMissing)
            return RawAssignmentStatement.incomplete
        }
        
        let expressionNode = parseExpression(min: 0)
        
        let recoverFromSemicolonMissing = consume(.SEMICOLON, else: .expectedSemicolonToEndStatement(of: .definition))
        if let recoverFromSemicolonMissing {
            recover(using: recoverFromSemicolonMissing)
        }
        
        return RawAssignmentStatement(name: identifier, expression: expressionNode)
    }
    
    private func parseFunctionDefinition() -> RawFuncDefinition {
        
        let recoverFromFuncKeywordMissing = consume(
            .FUNC,
            else: .internalParserError(type: .unreachable("Can only be called when func keyword is encountered"))
        )
        if let recoverFromFuncKeywordMissing {
            recover(using: recoverFromFuncKeywordMissing)
            return .incomplete
        }
        
        guard let identifier = parseIdentifier(in: .functionDefinition) else {
            return .incomplete
        }
        
        let recoverFromLParenMissing = consume(.LPAREN, else: .expectedLeftParen(where: .functionDefinition))
        if let recoverFromLParenMissing {
            recover(using: recoverFromLParenMissing)
            return .incomplete
        }
        
        let parameters = parseFunctionParameters()
        if parameters.anyIncomplete {
            return .incomplete
        }
        
        let recoverFromRParenMissing = consume(.RPAREN, else: .expectedRightParen(where: .functionDefinition))
        if let recoverFromRParenMissing {
            recover(using: recoverFromRParenMissing)
            return .incomplete
        }
        
        var typeName: TypeName = .Void
        if peek(comparing: .ARROW, burn: true) {
            guard let foundTypeName = parseType(at: .functionType) else {
                return .incomplete
            }
            
            typeName = foundTypeName
        }
        
        let parameterTypes = parameters.map { $0.type }
        let funcType: TypeName = .Arrow(from: parameterTypes, to: typeName)
        
        let body = parseBlock(in: .functionBody)
        if body.anyIncomplete {
            return .incomplete
        }
        
        return RawFuncDefinition(name: identifier, type: funcType, parameters: parameters, body: body)
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
    
    private func parseBlock(in usage: BlockContext) -> RawBlockStatement {
        
        var bodyParts: [any RawBlockLevelNode] = []
        
        let recoverFromLBraceMissing = consume(.LBRACE, else: .expectedLeftBrace(where: usage.errorTypeForLeft))
        if let recoverFromLBraceMissing {
            recover(using: recoverFromLBraceMissing)
            return .incomplete
        }
        
        while let nextToken = tokens.peekNext(), nextToken != .RBRACE {
            
            if let bodyPart = parseBlockBodyPart() {
                bodyParts.append(bodyPart)
            }
        }
        
        let recoverFromRBraceMissing = consume(.RBRACE, else: .expectedRightBrace(where: usage.errorTypeForRight))
        if let recoverFromRBraceMissing {
            recover(using: recoverFromRBraceMissing)
            bodyParts.append(RawFuncApplication.incomplete)
        }
        
        let block = RawBlockStatement(statements: bodyParts)
        return block
    }
    
    private func parseConditionalBlock() -> RawConditionalBlock {
        let condition = parseExpression(min: 0)
        guard !condition.isIncomplete else {
            return .incomplete
        }
        
        let block = parseBlock(in: .ifStatement)
        guard !block.anyIncomplete else {
            return .incomplete
        }
        
        return RawConditionalBlock(condition: condition, body: block)
    }
    
    private func parseIfStatement() -> RawIfStatement {
        
        let recoverFromIfKeywordMissing = consume(
            .IF,
            else: .internalParserError(type: .unreachable("This should never be reached without an if being parsed"))
        )
        if let recoverFromIfKeywordMissing {
            recover(using: recoverFromIfKeywordMissing)
            return .incomplete
        }
        
        let firstBlock = parseConditionalBlock()
        guard !firstBlock.isIncomplete else {
            return .incomplete
        }
        
        var blocks = [firstBlock]
        while true {
            guard let token = tokens.peekNext(), token == .ELSE else {
                return RawIfStatement(conditionalBlocks: blocks)
            }
            
            tokens.burn()
            
            guard let token = tokens.peekNext(), token == .IF else {
                let elsBlock = parseBlock(in: .ifStatement)
                guard !elsBlock.anyIncomplete else {
                    return .incomplete
                }
                
                return RawIfStatement(conditionalBlocks: blocks, elseBranch: elsBlock)
            }
            
            tokens.burn()
            
            let newBlock = parseConditionalBlock()
            guard !newBlock.anyIncomplete else {
                return .incomplete
            }
            
            blocks.append(newBlock)
        }
        
        return RawIfStatement(conditionalBlocks: blocks)
    }
    
    private func parseReturnStatement() -> RawReturnStatement {
        
        let recoverFromReturnKeywordMissing = consume(
            .RETURN,
            else: .internalParserError(type: .unreachable("We should never get here without first parsing a return token"))
        )
        if let recoverFromReturnKeywordMissing {
            recover(using: recoverFromReturnKeywordMissing)
            return .incomplete
        }
        
        let node = RawReturnStatement(expression: parseExpression(min: 0))
        
        let recoverFromSemicolonMissing = consume(.SEMICOLON, else: .expectedSemicolonToEndStatement(of: .return))
        if let recoverFromSemicolonMissing {
            recover(using: recoverFromSemicolonMissing)
        }
        
        return node
    }
    
    private func parseBlockBodyPart() -> (any RawBlockLevelNode)? {
        
        let currentToken: Token
        let result = expect(else: .expectedBlockBodyPart(got: .eof))
        switch result {
        case .success(let token):
            currentToken = token
        case .failure(let strategy):
            recover(using: strategy)
            return RawBlockLevelNodeIncomplete.incomplete
        }
        
        switch currentToken {
        case .Keyword("var", _), .Keyword("let", _):
            return parseDefinition()
            
        case .Identifier:
            return parseBlockLevelIdentifier()
            
        case .Keyword("return", _):
            return parseReturnStatement()
            
        case .Keyword("if", _):
            return parseIfStatement()
            
        case .Symbol("}", _):
            return nil
            
        case .Boolean:
            let strategy = self.error(.expectedBlockBodyPart(got: .boolean))
            recover(using: strategy)
            return RawBlockLevelNodeIncomplete.incomplete
            
        case .Number:
            let strategy = self.error(.expectedBlockBodyPart(got: .number))
            recover(using: strategy)
            return RawBlockLevelNodeIncomplete.incomplete
            
        case .Keyword(let val, _):
            let strategy = self.error(.expectedBlockBodyPart(got: .keyword(val)))
            recover(using: strategy)
            return RawBlockLevelNodeIncomplete.incomplete
            
        case .Symbol(let val, _):
            let strategy = self.error(.expectedBlockBodyPart(got: .symbol(val)))
            recover(using: strategy)
            return RawBlockLevelNodeIncomplete.incomplete
            
        }
    }
    
    private func parseDefinition() -> any RawDefinitionNode {
        
        let keyword: Token
        let result = expect(else: .internalParserError(type: .unreachable("There should be a keyword here")), burnToken: true)
        switch result {
        case .success(let token):
            keyword = token
        case .failure(let strategy):
            recover(using: strategy)
            return RawLetDefinition.incomplete
        }
        
        let definitionType: DefinitionType
        enum DefinitionType {
            case `let`
            case `var`
        }
        
        switch keyword {
        case .Keyword("var", _):
            definitionType = .var
        case .Keyword("let", _):
            definitionType = .let
        default:
            let strategy = self.error(
                .internalParserError(
                    type: .unreachable("Keyword must be let or var in definition, got \(keyword.value)")
                )
            )
            recover(using: strategy)
            return RawLetDefinition.incomplete
        }
        
        guard let identifier = parseIdentifier(in: .valueDefinition) else {
            return RawLetDefinition.incomplete
        }
        
        let recoverFromColonMissing = consume(.COLON, else: .expectedTypeIdentifier(where: .definitionType))
        if let recoverFromColonMissing {
            recover(using: recoverFromColonMissing)
            return RawLetDefinition.incomplete
        }
        
        let type = parseType(at: .definitionType)
        guard let type else {
            return RawLetDefinition.incomplete
        }
        
        let recoverFromEqualMissing = consume(.EQUAL, else: .expectedEqualInAssignment)
        if let recoverFromEqualMissing {
            recover(using: recoverFromEqualMissing)
            return RawLetDefinition.incomplete
        }
        
        let boundExpression = parseExpression(min: 0)
        
        let recoverFromSemicolonMissing = consume(.SEMICOLON, else: .expectedSemicolonToEndStatement(of: .definition))
        if let recoverFromSemicolonMissing {
            recover(using: recoverFromSemicolonMissing)
        }
        
        switch definitionType {
        case .var:
            return RawVarDefinition(name: identifier, type: type, expression: boundExpression)
        case .let:
            return RawLetDefinition(name: identifier, type: type, expression: boundExpression)
        }
    }
    
    typealias OperatorInfo = (precedence: Int, associativity: OperatorAssociativity)
    enum OperatorAssociativity {
        case left
        case right
    }
    let operatorInfoMap: [Token: OperatorInfo] = [
        .NOT:      (7, .right),
        .STAR:     (6, .left),
        .PLUS:     (5, .left),
        .MINUS:    (5, .left),
        .GT:       (4, .left),
        .GTE:      (4, .left),
        .LT:       (4, .left),
        .LTE:      (4, .left),
        .EQUALTO:  (3, .left),
        .NEQUALTO: (3, .left),
        .AND:      (2, .left),
        .OR:       (1, .left)
    ]
    
    private func parseAtom() -> any RawExpressionNode {
        let currentTokenPeeked = tokens.peekNext()
        if let currentTokenPeeked, currentTokenPeeked == .LPAREN {
            tokens.burn()
            let value = parseExpression(min: 1)
            
            let recoverFromRParenMissing = consume(.RPAREN, else: .expectedRightParen(where: .functionApplication))
            if let recoverFromRParenMissing {
                recover(using: recoverFromRParenMissing)
                return RawNumberExpression.incomplete
            }
            
            return value
            
        } else if let currentTokenPeeked, currentTokenPeeked.isUnaryOp() {
            tokens.burn()
            let value = parseExpression(min: operatorInfoMap[currentTokenPeeked]!.precedence)
            
            return RawUnaryOperation(op: .from(token: currentTokenPeeked)!, expression: value)
            
        } else {
            switch tokens.next() {
            case let .Identifier(id, _):
                if let maybeParen = tokens.peek(ahead: 2), maybeParen == .LPAREN {
                    return parseFunctionApplication()
                } else {
                    return RawIdentifierExpression(name: id)
                }
                
            case let .Number(n, _):
                return RawNumberExpression(value: Int(n)!)
                
            case let .Boolean(b, _):
                return RawBooleanExpression(value: Bool(b)!)
                
            default:
                let strategy = self.error(.expectedExpression)
                recover(using: strategy)
                return RawNumberExpression.incomplete
            }
        }
    }
    
    private func parseExpression(min: Int) -> any RawExpressionNode {
        var atomLhs: any RawExpressionNode = parseAtom()
        
        while true {
            let currentTokenPeeked = tokens.peekNext()
            
            guard let currentTokenPeeked, currentTokenPeeked.isBinaryOp(),
                  let (precedence, associativity) = operatorInfoMap[currentTokenPeeked],
                  precedence >= min else {
                break
            }
            
            let nextMinPrecedence = associativity == .left ? precedence + 1 : precedence
            let currentToken = tokens.next()!
            let atomRhs = parseExpression(min: nextMinPrecedence)
            atomLhs = RawBinaryOperation(
                op: .from(token: currentToken)!,
                lhs: atomLhs,
                rhs: atomRhs
            )
        }
        
        return atomLhs
    }
    
    private typealias IdentifierUsage = ExpectedIdentifierErrorInfo.ErrorType
    
    private func parseIdentifier(in usage: IdentifierUsage) -> String? {
        
        let currentToken: Token
        let result = expect(else: .expectedIdentifier(in: usage), burnToken: true)
        switch result {
        case .success(let token):
            currentToken = token
        case .failure(let strategy):
            recover(using: strategy)
            return nil
        }
        
        switch currentToken {
        case .Identifier(let name, _):
            return name
        default:
            let recovery = error(.expectedIdentifier(in: usage))
            recover(using: recovery)
            return nil
        }
    }
    
    private func parseFunctionParameters() -> [RawFuncDefinition.Parameter] {
        
        var parameters: [RawFuncDefinition.Parameter] = []
        
        while let nextToken = tokens.peekNext(), nextToken != .RPAREN {
            
            let identifier = parseIdentifier(in: .functionParameter)
            guard let identifier else {
                parameters.append(.incomplete)
                return parameters
            }
            
            let recoverFromColonMissing = consume(.COLON, else: .expectedParameterType)
            if let recoverFromColonMissing {
                recover(using: recoverFromColonMissing)
                parameters.append(.incomplete)
                return parameters
            }
            
            let type = parseType(at: .functionParameterType)
            guard let type else {
                parameters.append(.incomplete)
                return parameters
            }
            
            parameters.append(.init(name: identifier, type: type))
            
            if let maybeCloseParen = tokens.peekNext(), maybeCloseParen == .RPAREN {
                return parameters
            }
            
            let recoverFromCommaMissing = consume(.COMMA, else: .expectedParameterType)
            if let recoverFromCommaMissing {
                recover(using: recoverFromCommaMissing)
                parameters.append(.incomplete)
                return parameters
            }
            
        }
        
        return parameters
    }
    
    private func parseFunctionApplicationArgument() -> any RawExpressionNode {
        
        let nextToken: Token
        let result = expect(else: .expectedFunctionArgument(got: .eof))
        switch result {
        case .success(let token):
            nextToken = token
        case .failure(let strategy):
            recover(using: strategy)
            return RawNumberExpression.incomplete
        }
        
        switch nextToken {
        case .Boolean, .Identifier, .Number:
            return parseExpression(min: 0)
        case .Keyword(let kw, _):
            let strategy = self.error(.expectedFunctionArgument(got: .keyword(kw)))
            recover(using: strategy)
            return RawNumberExpression.incomplete
        case .Symbol(let s, _):
            let strategy = self.error(.expectedFunctionArgument(got: .symbol(s)))
            recover(using: strategy)
            return RawNumberExpression.incomplete
        }
    }
    
    private func parseTopLevelFunctionApplication() -> RawFuncApplication {
        let functionApplication = parseFunctionApplication()
        
        let recoverFromSemicolonMissing = consume(.SEMICOLON, else: .expectedSemicolonToEndFunctionCall)
        if let recoverFromSemicolonMissing {
            recover(using: recoverFromSemicolonMissing)
        }
        
        return functionApplication
    }
    
    private func parseFunctionApplication() -> RawFuncApplication {
        
        let identifier = parseIdentifier(in: .functionApplication)
        guard let identifier else {
            return .incomplete
        }
        
        let recoverFromLParenMissing = consume(.LPAREN, else: .expectedFunctionApplication)
        if let recoverFromLParenMissing {
            recover(using: recoverFromLParenMissing)
            return .incomplete
        }
        
        var expressions: [any RawExpressionNode] = []
        
        while let nextToken = tokens.peekNext(), nextToken != .RPAREN {
            let argument = parseFunctionApplicationArgument()
            if argument.isIncomplete {
                return .incomplete
            }
            
            expressions.append(argument)
            
            guard let maybeComma = tokens.peekNext() else {
                break
            }
            
            if maybeComma == .COMMA {
                tokens.burn()
            }
        }
        
        let recoverFromRParenMissing = consume(.RPAREN, else: .expectedRightParen(where: .functionApplication))
        if let recoverFromRParenMissing {
            recover(using: recoverFromRParenMissing)
            return .incomplete
        }
        
        return RawFuncApplication(name: identifier, arguments: expressions)
    }
    
    typealias TypeLocation = ExpectedTypeIdentifierErrorInfo.ErrorType
    
    private func parseType(at location: TypeLocation) -> TypeName? {
        
        let nextToken: Token
        let result = expect(else: .expectedTypeIdentifier(where: location), burnToken: true)
        switch result {
        case .success(let token):
            nextToken = token
        case .failure(let strategy):
            recover(using: strategy)
            return nil
        }
        
        switch nextToken {
        case .INTTYPE:
            return .Int
        case .BOOLTYPE:
            return .Bool
        case .STRINGTYPE:
            return .String
        case .VOIDTYPE:
            return .Void
        default:
            let strategy = self.error(.expectedTypeIdentifier(where: location))
            recover(using: strategy)
            return nil
        }
    }
}

