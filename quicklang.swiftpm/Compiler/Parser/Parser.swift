//
//  Parser.swift
//  swift-student-challenge-2025
//
//  Created by Rob Patterson on 2/4/25.
//

class Parser {
    
    private let errorManager: ParserErrorManager
    private var tokens: PeekableIterator<Token>
    
    private let recoveryEngine: any RecoveryEngine
    
    init(for tokens: [Token], manager: ParserErrorManager, recoverer: any RecoveryEngine) {
        self.tokens = PeekableIterator(elements: tokens)
        self.errorManager = manager
        self.recoveryEngine = recoverer
    }
    
    func begin() -> TopLevel {
        
        var nodes: [any TopLevelNode] = []
        while !tokens.isEmpty() {
            let node = parseTopLevel()
            nodes.append(node)
        }
        
        return TopLevel(sections: nodes)
    }
    
    private func error(_ error: ParserErrorType) -> RecoveryStrategy {
        
        let location = tokens.peekNext()?.location
        ?? tokens.peekPrev()?.location
        ?? .beginningOfFile
        
        errorManager.add(error, at: location)
        return recoveryEngine.recover(from: error)
    }
    
    private func expect(
        _ token: Token? = nil,
        else error: ParserErrorType,
        burnToken: Bool = false,
        onRecovery: (() -> ASTNode)? = nil
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
    
    private func expectAndBurn(_ token: Token? = nil, else error: ParserErrorType) -> RecoveryStrategy? {
        switch expect(token, else: error, burnToken: true) {
        case .success:
            return nil
        case .failure(let strategy):
            return strategy
        }
    }
    
    private func handleUnrecoverable() -> Never {
        fatalError()
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
    
    /// Parses a top level grammar.
    ///
    /// Top level grammar inludes function definitions (marked `func`, processed by ``parseFunctionDefinition()``),
    /// value definitions (marked `let` or `var`, processed by ``parseDefinition()``),
    /// and function applications (`foo()`, processed by ``parseTopLevelFunctionApplication()``).
    /// This corresponds to all ``ASTNode`` that conforms to the ``TopLevelNode`` protocol.
    ///
    /// - Returns: some ``TopLevelNode`` corresponding to the concrete top level language construct
    private func parseTopLevel() -> TopLevelNode {
        
        let currentToken: Token
        let result = expect(else: .expectedTopLevelStatement(got: .eof))
        switch result {
        case .success(let token):
            currentToken = token
        case .failure(let strategy):
            recover(using: strategy)
            return TopLevelNodeIncomplete.incomplete
        }
        
        switch currentToken {
        // the interesting cases!
        case .Keyword("func", _):
            return parseFunctionDefinition()
            
        case .Keyword("var", _), .Keyword("let", _):
            return parseDefinition()
            
        case .Identifier:
            return parseTopLevelFunctionApplication()
            
        // the uninteresting cases
        case .Boolean:
            let strategy = self.error(.expectedTopLevelStatement(got: .boolean))
            recover(using: strategy)
            return TopLevelNodeIncomplete.incomplete
            
        case .Number:
            let strategy =  self.error(.expectedTopLevelStatement(got: .number))
            recover(using: strategy)
            return TopLevelNodeIncomplete.incomplete
            
        case .Keyword(let val, _):
            let strategy = self.error(.expectedTopLevelStatement(got: .keyword(val)))
            recover(using: strategy)
            return TopLevelNodeIncomplete.incomplete
            
        case .Symbol(let val, _):
            let strategy = self.error(.expectedTopLevelStatement(got: .symbol(val)))
            recover(using: strategy)
            return TopLevelNodeIncomplete.incomplete
        }
    }

    /// Parses a function definition.
    ///
    /// #Example:
    /// ```
    /// func foo(bar: Int) -> Int {
    ///     return bar;
    /// }
    /// ```
    ///
    /// becomes
    /// ```
    /// FuncDefinition("foo", TypeName.Int, [("bar", TypeName.Int)], [ReturnStatement(...)]
    /// ```
    private func parseFunctionDefinition() -> FuncDefinition {
        
        let recoverFromFuncKeywordMissing = expectAndBurn(
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
        
        let recoverFromLParenMissing = expectAndBurn(.LPAREN, else: .expectedLeftParen(where: .functionDefinition))
        if let recoverFromLParenMissing {
            recover(using: recoverFromLParenMissing)
            return .incomplete
        }
        
        let parameters = parseFunctionParameters()
        if parameters.anyIncomplete {
            return .incomplete
        }
        
        let recoverFromRParenMissing = expectAndBurn(.RPAREN, else: .expectedRightParen(where: .functionDefinition))
        if let recoverFromRParenMissing {
            recover(using: recoverFromRParenMissing)
            return .incomplete
        }
        
        let recoverFromArrowMissing = expectAndBurn(.ARROW, else: .expectedArrowInFunctionDefinition)
        if let recoverFromArrowMissing {
            recover(using: recoverFromArrowMissing)
            return .incomplete
        }
        
        guard let typeName = parseType(at: .functionType) else {
            return .incomplete
        }
        
        let body = parseBlock(in: .functionBody)
        if body.anyIncomplete {
            return .incomplete
        }
        
        return FuncDefinition(name: identifier, type: typeName, parameters: parameters, body: body)
    }
    
    /// Describes a context in which this block is being constructed.
    private enum BlockContext {
        case ifStatement
        case functionBody
        
        /// Calculates the equivalent ``ExpectedLeftBraceErrorInfo.ErrorType``.
        var errorTypeForLeft: ExpectedLeftBraceErrorInfo.ErrorType {
            switch self {
            case .ifStatement:
                return .ifStatement
            case .functionBody:
                return .functionBody
            }
        }
        
        /// Calculates the equivalent ``ExpectedRightBraceErrorInfo.ErrorType``.
        var errorTypeForRight: ExpectedRightBraceErrorInfo.ErrorType {
            switch self {
            case .ifStatement:
                return .ifStatement
            case .functionBody:
                return .functionBody
            }
        }
    }
    
    /// Parses a block.
    ///
    /// A block is any piece of the language surrounded by curly braces (`{` and `}`).
    ///
    /// - Parameter usage: the context in which this block is connected to
    ///                    (for example, an `if` statement)
    private func parseBlock(in usage: BlockContext) -> [BlockLevelNode] {
        
        var bodyParts: [BlockLevelNode] = []
        
        let recoverFromLBraceMissing = expectAndBurn(.LBRACE, else: .expectedLeftBrace(where: usage.errorTypeForLeft))
        if let recoverFromLBraceMissing {
            recover(using: recoverFromLBraceMissing)
            return [FuncApplication.incomplete]
        }
        
        while let nextToken = tokens.peekNext(), nextToken != .RBRACE {
            
            if let bodyPart = parseBlockBodyPart() {
                bodyParts.append(bodyPart)
            }
        }
        
        let recoverFromRBraceMissing = expectAndBurn(.RBRACE, else: .expectedRightBrace(where: usage.errorTypeForRight))
        if let recoverFromRBraceMissing {
            recover(using: recoverFromRBraceMissing)
            bodyParts.append(FuncApplication.incomplete)
        }
        
        return bodyParts
    }
    
    /// Parses an `if` statement.
    ///
    /// Includes those with `else` clauses:
    /// ```
    /// if (foo) {
    ///     bar();
    /// }
    /// ```
    ///
    /// and those without them::
    /// ```
    /// if (foo) {
    ///     bar(true);
    /// } else {
    ///     bar(false);
    /// }
    /// ```
    ///
    /// The first example will become
    /// ```
    /// IfStatement(IdentifierExpression(...), [FunctionApplication(...)], nil)
    /// ```
    private func parseIfStatement() -> IfStatement {
        
        let recoverFromIfKeywordMissing = expectAndBurn(
            .IF,
            else: .internalParserError(type: .unreachable("This should never be reached without an if being parsed"))
        )
        if let recoverFromIfKeywordMissing {
            recover(using: recoverFromIfKeywordMissing)
            return .incomplete
        }
        
        let recoverFromLParenMissing = expectAndBurn(.LPAREN, else: .expectedLeftParen(where: .ifStatement))
        if let recoverFromLParenMissing {
            recover(using: recoverFromLParenMissing)
            return .incomplete
        }
        
        let condition = parseExpression(until: ")", min: 0)
        guard !condition.isIncomplete else {
            return .incomplete
        }
        
        let recoverFromRParenMissing = expectAndBurn(.RPAREN, else: .expectedRightParen(where: .ifStatement))
        if let recoverFromRParenMissing {
            recover(using: recoverFromRParenMissing)
            return .incomplete
        }
        
        let thnBlock = parseBlock(in: .ifStatement)
        guard !thnBlock.anyIncomplete else {
            return .incomplete
        }
        
        guard let token = tokens.peekNext(), token == .ELSE else {
            return IfStatement(condition: condition, thenBranch: thnBlock, elseBranch: nil)
        }
        
        tokens.burn() // else
        
        let elsBlock = parseBlock(in: .ifStatement)
        guard !elsBlock.anyIncomplete else {
            return .incomplete
        }
        
        return IfStatement(condition: condition, thenBranch: thnBlock, elseBranch: elsBlock)
    }
    
    private func parseReturnStatement() -> ReturnStatement {
        
        let recoverFromReturnKeywordMissing = expectAndBurn(
            .RETURN,
            else: .internalParserError(type: .unreachable("We should never get here without first parsing a return token"))
        )
        if let recoverFromReturnKeywordMissing {
            recover(using: recoverFromReturnKeywordMissing)
            return .incomplete
        }
        
        let node = ReturnStatement(expression: parseExpression(until: ";", min: 0))
        
        let recoverFromSemicolonMissing = expectAndBurn(.SEMICOLON, else: .expectedSemicolonToEndStatement(of: .return))
        if let recoverFromSemicolonMissing {
            // we can add semicolon and continue, no need to return .incomplete if
            // it isn't there
            recover(using: recoverFromSemicolonMissing)
        }
        
        return node
    }
    
    /// Parses a single block-level construct.
    ///
    /// This function looks at the next token within a `{ ... }` block and
    /// attempts to parse one valid block element (such as a statement or
    /// expression that is permitted inside a block). If the next token
    /// indicates the end of the block, or does not form a valid block
    /// element, the function returns `nil` after reporting an error when
    /// appropriate.
    ///
    /// - Returns: A ``BlockLevelNode`` representing the parsed construct, or
    ///            `nil` if the block should end or no valid construct can be parsed.
    private func parseBlockBodyPart() -> BlockLevelNode? {
        
        let currentToken: Token
        let result = expect(else: .expectedBlockBodyPart(got: .eof))
        switch result {
        case .success(let token):
            currentToken = token
        case .failure(let strategy):
            recover(using: strategy)
            return BlockLevelNodeIncomplete.incomplete
        }
        
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
            let strategy = self.error(.expectedBlockBodyPart(got: .boolean))
            recover(using: strategy)
            return BlockLevelNodeIncomplete.incomplete
            
        case .Number:
            let strategy = self.error(.expectedBlockBodyPart(got: .number))
            recover(using: strategy)
            return BlockLevelNodeIncomplete.incomplete
            
        case .Keyword(let val, _):
            let strategy = self.error(.expectedBlockBodyPart(got: .keyword(val)))
            recover(using: strategy)
            return BlockLevelNodeIncomplete.incomplete
            
        case .Symbol(let val, _):
            let strategy = self.error(.expectedBlockBodyPart(got: .symbol(val)))
            recover(using: strategy)
            return BlockLevelNodeIncomplete.incomplete
            
        }
    }
    
    private func parseDefinition() -> any DefinitionNode {
        
        let keyword: Token
        let result = expect(else: .internalParserError(type: .unreachable("There should be a keyword here")), burnToken: true)
        switch result {
        case .success(let token):
            keyword = token
        case .failure(let strategy):
            recover(using: strategy)
            return LetDefinition.incomplete
        }
        
        // we need this just so we can early exit if keyword is not there as expected
        let definitionType: DefinitionType
        enum DefinitionType {
            case `let`
            case `var`
        }
        
        // here is where we early exit
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
            return LetDefinition.incomplete
        }
        
        guard let identifier = parseIdentifier(in: .valueDefinition) else {
            return LetDefinition.incomplete
        }
        
        let recoverFromEqualMissing = expectAndBurn(.EQUAL, else: .expectedEqualInAssignment)
        if let recoverFromEqualMissing {
            recover(using: recoverFromEqualMissing)
            return LetDefinition.incomplete
        }
        
        let boundExpression = parseExpression(until: ";", min: 0)
        
        let recoverFromSemicolonMissing = expectAndBurn(.SEMICOLON, else: .expectedSemicolonToEndStatement(of: .definition))
        if let recoverFromSemicolonMissing {
            // we can add semicolon and continue, no need to return .incomplete if
            // it isn't there
            recover(using: recoverFromSemicolonMissing)
        }
        
        // if we got here, we know that we have a valid definition,
        // I like this solution with the `DefinitionType` enum
        switch definitionType {
        case .var:
            return VarDefinition(name: identifier, expression: boundExpression)
        case .let:
            return LetDefinition(name: identifier, expression: boundExpression)
        }
    }
    
    private func parseExpressionBeginning() -> any ExpressionNode {
        
        let currentToken: Token
        let result = expect(else: .expectedExpression)
        switch result {
        case .success(let token):
            currentToken = token
        case .failure(let strategy):
            recover(using: strategy)
            return NumberExpression.incomplete
        }
        
        switch currentToken {
        case let .Identifier(id, _):
            if let maybeParen = tokens.peek(ahead: 2), maybeParen == .LPAREN {
                return parseFunctionApplication()
            } else {
                tokens.burn()
                return IdentifierExpression(name: id)
            }
            
        case let .Number(n, _):
            tokens.burn()
            return NumberExpression(value: Int(n)!)
            
        case let .Boolean(b, _):
            tokens.burn()
            return BooleanExpression(value: Bool(b)!)
            
        default:
            let strategy = self.error(.expectedExpression)
            recover(using: strategy)
            return NumberExpression.incomplete
        }
    }
    
    private func parseExpression(until end: String, min: Int) -> any ExpressionNode {
        
        var lhsNode = parseExpressionBeginning()
        if lhsNode.isIncomplete {
            return lhsNode
        }
        
        while true {
            if let maybeEnd = tokens.peekNext(), maybeEnd.value == end {
                break
            }
            
            guard let op = tokens.peekNext(), op.isOp() else {
                let strategy = self.error(.expectedOperator)
                recover(using: strategy)
                return NumberExpression.incomplete
            }
            
            let (lBp, rBp) = op.bindingPower
            
            guard lBp >= min else {
                break
            }
            
            tokens.burn()
            let rhsNode = parseExpression(until: end, min: rBp)
            if rhsNode.isIncomplete {
                return rhsNode
            }
            
            var opVal: BinaryOperation.Operator
            switch op.value {
            case "+":
                opVal = BinaryOperation.Operator.plus
            case "-":
                opVal = BinaryOperation.Operator.minus
            case "*":
                opVal = BinaryOperation.Operator.times
            case "&&":
                opVal = BinaryOperation.Operator.and
            case "||":
                opVal = BinaryOperation.Operator.or
            default:
                fatalError() // TODO
            }
            
            lhsNode = BinaryOperation(op: opVal, lhs: lhsNode, rhs: rhsNode)
        }
        
        return lhsNode
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
    
    private func parseFunctionParameters() -> [FuncDefinition.Parameter] {
        
        var parameters: [FuncDefinition.Parameter] = []
        
        while let nextToken = tokens.peekNext(), nextToken != .RPAREN {
            
            let identifier = parseIdentifier(in: .functionParameter)
            guard let identifier else {
                parameters.append(.incomplete)
                return parameters
            }
            
            let recoverFromColonMissing = expectAndBurn(.COLON, else: .expectedParameterType)
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
            
            // MARK: shouldn't add another incomplete parameter here (we're still parsing the
            // MARK: last one), refactor to change this
            let recoverFromCommaMissing = expectAndBurn(.COMMA, else: .expectedParameterType)
            if let recoverFromCommaMissing {
                recover(using: recoverFromCommaMissing)
                parameters.append(.incomplete)
                return parameters
            }
                  
        }
        
        return parameters
    }
    
    private func parseFunctionApplicationArgument() -> any ExpressionNode {
        
        let nextToken: Token
        let result = expect(else: .expectedFunctionArgument(got: .eof))
        switch result {
        case .success(let token):
            nextToken = token
        case .failure(let strategy):
            recover(using: strategy)
            return NumberExpression.incomplete
        }
        
        switch nextToken {
        case .Boolean, .Identifier, .Number:
            return parseExpression(until: ")", min: 0)
        case .Keyword(let kw, _):
            let strategy = self.error(.expectedFunctionArgument(got: .keyword(kw)))
            recover(using: strategy)
            return NumberExpression.incomplete
        case .Symbol(let s, _):
            let strategy = self.error(.expectedFunctionArgument(got: .symbol(s)))
            recover(using: strategy)
            return NumberExpression.incomplete
        }
    }
    
    private func parseTopLevelFunctionApplication() -> FuncApplication {
        let functionApplication = parseFunctionApplication()
        
        let recoverFromSemicolonMissing = expectAndBurn(.SEMICOLON, else: .expectedSemicolonToEndFunctionCall)
        if let recoverFromSemicolonMissing {
            // we can add semicolon and continue, no need to return .incomplete if
            // it isn't there
            recover(using: recoverFromSemicolonMissing)
        }
        
        return functionApplication
    }
    
    private func parseFunctionApplication() -> FuncApplication {
        
        let identifier = parseIdentifier(in: .functionApplication)
        guard let identifier else {
            return .incomplete
        }
        
        let recoverFromLParenMissing = expectAndBurn(.LPAREN, else: .expectedFunctionApplication)
        if let recoverFromLParenMissing {
            recover(using: recoverFromLParenMissing)
            return .incomplete
        }
        
        var expressions: [any ExpressionNode] = []
        
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
        
        let recoverFromRParenMissing = expectAndBurn(.RPAREN, else: .expectedRightParen(where: .functionApplication))
        if let recoverFromRParenMissing {
            recover(using: recoverFromRParenMissing)
            return .incomplete
        }
        
        return FuncApplication(name: identifier, arguments: expressions)
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
        case .Keyword(let kw, _) where kw == "Int":
            return .Int
        case .Keyword(let kw, _) where kw == "Bool":
            return .Bool
        case .Keyword(let kw, _) where kw == "String":
            return .String
        default:
            let strategy = self.error(.expectedTypeIdentifier(where: location))
            recover(using: strategy)
            return nil
        }
    }
}

