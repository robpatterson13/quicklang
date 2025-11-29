//
//  Parser.swift
//  swift-student-challenge-2025
//
//  Created by Rob Patterson on 2/4/25.
//

/// A recursive-descent parser that builds the AST from a token stream.
///
/// ``Parser`` implements a hand-written, error-recovering recursive-descent parser
/// for the quicklang grammar. It consumes tokens produced by ``Lexer`` and builds
/// a ``TopLevel`` AST, inserting sentinel “incomplete” nodes where recovery occurs
/// so later phases can short-circuit or continue gracefully.
///
/// Features:
/// - Recovery-aware parsing using a pluggable ``RecoveryEngine``
/// - Production of incomplete sentinels to preserve tree shape under errors
/// - Precedence-climbing expression parsing
///
/// Pipeline role:
/// - Input: ``Lexer.SuccessfulResult`` (token stream)
/// - Output: ``TopLevel`` (AST root)
///
/// - SeeAlso: ``Lexer``, ``TopLevel``, ``ASTNodeIncompletable``, ``RecoveryEngine``
final class Parser: CompilerPhase {
    
    typealias InputType = Lexer.SuccessfulResult
    typealias SuccessfulResult = ASTContext
    
    private let errorManager: CompilerErrorManager
    private var tokens = PeekableIterator<Token>(elements: [])
    
    private var context = ASTContext()
    
    /// The active recovery engine used to suggest strategies when errors are encountered.
    ///
    /// - Note: Defaults to ``DefaultRecovery/shared``.
    private let recoveryEngine: any RecoveryEngine = DefaultRecovery.shared
    
    /// Creates a parser over a token stream with a shared error manager.
    ///
    /// The parser records diagnostics via the provided ``CompilerErrorManager`` and
    /// requests recovery strategies from the configured ``RecoveryEngine``.
    ///
    /// - Parameter errorManager: The shared error manager used to record diagnostics.
    init(errorManager: CompilerErrorManager) {
        self.errorManager = errorManager
    }
    
    /// Parses a full token stream into a ``TopLevel`` AST.
    ///
    /// The parser iterates until the token stream is exhausted, repeatedly invoking
    /// ``parseTopLevel()``. On errors, it records diagnostics, attempts recovery,
    /// and inserts incomplete sentinels to preserve the AST structure.
    ///
    /// - Parameter input: The tokens produced by the lexer.
    /// - Returns: ``PhaseResult/success(result:)`` with a ``TopLevel`` on success, or
    ///   ``PhaseResult/failure`` on unrecoverable error.
    func begin(_ input: Lexer.SuccessfulResult) -> PhaseResult<Parser> {
        var nodes: [any TopLevelNode] = []
        self.tokens = PeekableIterator(elements: input)
        while !tokens.isEmpty() {
            let node = parseTopLevel()
            nodes.append(node)
        }
        
        context.tree = TopLevel(sections: nodes)
        if errorManager.hasErrors {
            return .failure
        }
        
        return .success(result: context)
    }
    
    /// Records a diagnostic and requests a recovery strategy from the recovery engine.
    ///
    /// This utility captures the best-available source location from nearby tokens,
    /// builds a diagnostic using the error’s info builder, records it, and returns
    /// a suggested ``RecoveryStrategy``.
    ///
    /// - Parameter error: The parser error to report.
    /// - Returns: A recovery strategy suggested by the configured ``RecoveryEngine``.
    private func error(_ error: ParserErrorType) -> RecoveryStrategy {
        
        let location = tokens.peekNext()?.location
        ?? tokens.peekPrev()?.location
        ?? .beginningOfFile
        
        let parserErrorInfo = error.buildInfo(at: location)
        let parserError = parserErrorInfo.getError(from: DefaultParserErrorCreator.shared)
        errorManager.addError(parserError)
        return recoveryEngine.recover(from: error)
    }
    
    /// Expects a specific token (or any token) and optionally consumes it.
    ///
    /// Discussion:
    /// - If `token` is `nil`, any next token satisfies the expectation.
    /// - If `burnToken` is `true`, the token is consumed on success.
    /// - On failure, a diagnostic is recorded and a ``RecoveryStrategy`` is returned.
    ///
    /// - Parameters:
    ///   - token: The expected token, or `nil` to accept any token.
    ///   - error: The error to report on mismatch.
    ///   - burnToken: Whether to consume the token on success.
    /// - Returns: `.success(nextToken)` on success, or `.failure(strategy)` on error.
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
    
    /// Expects a token and consumes it on success.
    ///
    /// This is a convenience wrapper around ``expect(_:else:burnToken:)`` with `burnToken = true`.
    ///
    /// - Parameters:
    ///   - token: The expected token, or `nil` to accept any token.
    ///   - error: The error to report on mismatch.
    /// - Returns: `nil` on success, or a recovery strategy on failure.
    private func expectAndBurn(_ token: Token? = nil, else error: ParserErrorType) -> RecoveryStrategy? {
        switch expect(token, else: error, burnToken: true) {
            case .success:
                return nil
            case .failure(let strategy):
                return strategy
        }
    }
    
    /// Handles unrecoverable parse states by terminating the parse.
    ///
    /// - Note: This is a hard failure and will crash. Use sparingly and only for
    ///   invariant violations or exhausted recovery options.
    private func handleUnrecoverable() -> Never {
        fatalError()
    }
    
    /// Applies a recovery strategy to advance the parser to a stable state.
    ///
    /// Supported strategies:
    /// - ``RecoveryStrategy/dropUntil(_:)``: Skip tokens until a member of the recovery set is found
    /// - ``RecoveryStrategy/add(_:)``: Synthesize a token (not yet implemented)
    /// - ``RecoveryStrategy/ignore``: Continue without changes
    /// - ``RecoveryStrategy/unrecoverable``: Abort parsing
    /// - ``RecoveryStrategy/override(with:)``: Replace with another strategy
    ///
    /// - Parameter strategy: The recovery strategy to apply.
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
    
    /// Parses a top-level construct.
    ///
    /// Grammar (simplified):
    /// - function definition
    /// - value definition (`let`/`var`)
    /// - top-level function application (terminated by `;`)
    ///
    /// - Returns: A ``TopLevelNode`` (or an incomplete sentinel on error).
    private func parseTopLevel() -> any TopLevelNode {
        
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
        case .Keyword("func", _):
            return parseFunctionDefinition()
            
        case .Keyword("var", _), .Keyword("let", _):
            return parseDefinition()
            
        case .Identifier:
            return parseTopLevelIdentifier()
            
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
    ) -> any BlockLevelNode {
        
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
            return TopLevelNodeIncomplete.incomplete
        case .block:
            return BlockLevelNodeIncomplete.incomplete
        }
    }
    
    private enum IdentifierSite {
        case topLevel
        case block
    }
    
    private func parseIdentifierStart(in site: IdentifierSite) -> any BlockLevelNode {
        guard let twoAhead = tokens.peek(ahead: 2) else {
            return errorFromParseIdentifierStart(got: .eof, at: site)
        }
        
        switch twoAhead {
        case .RPAREN:
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
    
    private func parseTopLevelIdentifier() -> any TopLevelNode {
        return parseIdentifierStart(in: .topLevel) as! any TopLevelNode
    }
    
    private func parseBlockLevelIdentifier() -> any BlockLevelNode {
        return parseIdentifierStart(in: .block)
    }
    
    private func parseAssignmentStatement() -> AssignmentStatement {
        guard let identifier = parseIdentifier(in: .assignmentStatement) else {
            return AssignmentStatement.incomplete
        }
        
        let recoverFromEqualMissing = expectAndBurn(.EQUAL, else: .expectedEqualInAssignment)
        if let recoverFromEqualMissing {
            recover(using: recoverFromEqualMissing)
            return AssignmentStatement.incomplete
        }
        
        let expressionNode = parseExpression(until: ";", min: 0)
        
        let recoverFromSemicolonMissing = expectAndBurn(.SEMICOLON, else: .expectedSemicolonToEndStatement(of: .definition))
        if let recoverFromSemicolonMissing {
            recover(using: recoverFromSemicolonMissing)
        }
        
        return AssignmentStatement(name: identifier, expression: expressionNode)
    }

    /// Parses a function definition.
    ///
    /// Grammar (simplified):
    /// ```text
    /// func <identifier>(<params>) -> <type> { <block> }
    /// ```
    ///
    /// - Returns: A ``FuncDefinition``, or ``FuncDefinition/incomplete`` on error.
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
        
        context.addParamsTo(func: identifier, parameters)
        
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
        
        let parameterTypes = parameters.map { $0.type }
        let funcType: TypeName = .Arrow(from: parameterTypes, to: typeName)
        context.assignTypeOf(funcType, to: identifier)
        
        let body = parseBlock(in: .functionBody)
        if body.anyIncomplete {
            return .incomplete
        }
        
        return FuncDefinition(name: identifier, type: typeName, parameters: parameters, body: body)
    }
    
    /// Describes the syntactic context in which a block appears.
    ///
    /// Used to specialize diagnostics for missing braces.
    private enum BlockContext {
        case ifStatement
        case functionBody
        
        /// Maps to the left-brace error type for this context.
        var errorTypeForLeft: ExpectedLeftBraceErrorInfo.ErrorType {
            switch self {
            case .ifStatement:
                return .ifStatement
            case .functionBody:
                return .functionBody
            }
        }
        
        /// Maps to the right-brace error type for this context.
        var errorTypeForRight: ExpectedRightBraceErrorInfo.ErrorType {
            switch self {
            case .ifStatement:
                return .ifStatement
            case .functionBody:
                return .functionBody
            }
        }
    }
    
    /// Parses a block delimited by `{` and `}`.
    ///
    /// The block body consists of zero or more block-level nodes. On brace errors,
    /// diagnostics are emitted and incomplete sentinels are inserted to preserve structure.
    ///
    /// - Parameter usage: The syntactic context in which the block appears.
    /// - Returns: The parsed block elements (may include incomplete sentinels).
    private func parseBlock(in usage: BlockContext) -> [any BlockLevelNode] {
        
        var bodyParts: [any BlockLevelNode] = []
        
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
    
    /// Parses an `if` statement with an optional `else` branch.
    ///
    /// Grammar (simplified):
    /// ```text
    /// if (<expr>) { <block> } [else { <block> }]
    /// ```
    ///
    /// - Returns: An ``IfStatement``, or ``IfStatement/incomplete`` on error.
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
    
    /// Parses a `return` statement terminated by a semicolon.
    ///
    /// Grammar (simplified):
    /// ```text
    /// return <expr> ;
    /// ```
    ///
    /// - Returns: A ``ReturnStatement`` (may be incomplete on error).
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
            recover(using: recoverFromSemicolonMissing)
        }
        
        return node
    }
    
    /// Parses a single block-level element.
    ///
    /// Recognized constructs:
    /// - value definitions (`let` / `var`)
    /// - function application
    /// - `return` statement
    /// - `if` statement
    ///
    /// - Returns: A ``BlockLevelNode``, or `nil` when the block ends (`}`).
    private func parseBlockBodyPart() -> (any BlockLevelNode)? {
        
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
            return LetDefinition.incomplete
        }
        
        guard let identifier = parseIdentifier(in: .valueDefinition) else {
            return LetDefinition.incomplete
        }
        
        let recoverFromColonMissing = expectAndBurn(.COLON, else: .expectedTypeIdentifier(where: .definitionType))
        if let recoverFromColonMissing {
            recover(using: recoverFromColonMissing)
            return LetDefinition.incomplete
        }
        
        let type = parseType(at: .definitionType)
        guard let type else {
            return LetDefinition.incomplete
        }
        
        context.assignTypeOf(type, to: identifier)
        
        let recoverFromEqualMissing = expectAndBurn(.EQUAL, else: .expectedEqualInAssignment)
        if let recoverFromEqualMissing {
            recover(using: recoverFromEqualMissing)
            return LetDefinition.incomplete
        }
        
        let boundExpression = parseExpression(until: ";", min: 0)
        
        let recoverFromSemicolonMissing = expectAndBurn(.SEMICOLON, else: .expectedSemicolonToEndStatement(of: .definition))
        if let recoverFromSemicolonMissing {
            recover(using: recoverFromSemicolonMissing)
        }
        
        switch definitionType {
        case .var:
            return VarDefinition(name: identifier, type: type, expression: boundExpression)
        case .let:
            return LetDefinition(name: identifier, type: type, expression: boundExpression)
        }
    }
    
    /// Parses the beginning (prefix) of an expression.
    ///
    /// Recognized starts:
    /// - identifier (may form a function application if followed by `(`)
    /// - number literal
    /// - boolean literal
    ///
    /// - Returns: An ``ExpressionNode``, or an incomplete sentinel on error.
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
    
    /// Parses an expression using precedence climbing.
    ///
    /// Operator precedence and associativity are derived from the token’s binding power.
    ///
    /// - Parameters:
    ///   - end: The terminating delimiter to stop at (e.g., `")"` or `";"`).
    ///   - min: The minimum left binding power for continuing the parse loop.
    /// - Returns: A parsed ``ExpressionNode``, or an incomplete sentinel on error.
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
                fatalError() // TODO: unreachable with current grammar
            }
            
            lhsNode = BinaryOperation(op: opVal, lhs: lhsNode, rhs: rhsNode)
        }
        
        return lhsNode
    }
    
    private typealias IdentifierUsage = ExpectedIdentifierErrorInfo.ErrorType
    
    /// Parses an identifier and returns its name.
    ///
    /// - Parameter usage: The syntactic context in which the identifier is expected,
    ///   used to tailor diagnostics.
    /// - Returns: The identifier name, or `nil` on error (after recovery).
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
    
    /// Parses a function’s parameter list.
    ///
    /// Grammar (simplified):
    /// ```text
    /// (<identifier> : <type> [, <identifier> : <type>]*)
    /// ```
    ///
    /// - Returns: The parsed parameters. If an error occurs, an incomplete sentinel
    ///   is appended and the partial list is returned.
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
            
            let recoverFromCommaMissing = expectAndBurn(.COMMA, else: .expectedParameterType)
            if let recoverFromCommaMissing {
                recover(using: recoverFromCommaMissing)
                parameters.append(.incomplete)
                return parameters
            }
                  
        }
        
        return parameters
    }
    
    /// Parses a single function application argument.
    ///
    /// - Returns: The parsed argument expression, or an incomplete sentinel on error.
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
    
    /// Parses a top-level function application and its terminating semicolon.
    ///
    /// - Returns: The parsed ``FuncApplication`` (may be incomplete on error).
    private func parseTopLevelFunctionApplication() -> FuncApplication {
        let functionApplication = parseFunctionApplication()
        
        let recoverFromSemicolonMissing = expectAndBurn(.SEMICOLON, else: .expectedSemicolonToEndFunctionCall)
        if let recoverFromSemicolonMissing {
            recover(using: recoverFromSemicolonMissing)
        }
        
        return functionApplication
    }
    
    /// Parses a function application expression.
    ///
    /// Grammar (simplified):
    /// ```text
    /// <identifier>(<expr-list>)
    /// ```
    ///
    /// - Returns: A ``FuncApplication``, or ``FuncApplication/incomplete`` on error.
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
    
    /// Parses a type identifier.
    ///
    /// Supported types:
    /// - ``TypeName/Int``
    /// - ``TypeName/Bool``
    /// - ``TypeName/String``
    ///
    /// - Parameter location: The syntactic context used to specialize diagnostics.
    /// - Returns: The parsed ``TypeName``, or `nil` on error (after recovery).
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
