//
//  ParserError.swift
//  quicklang
//
//  Created by Rob Patterson on 7/19/25.
//

/// A token and its source location associated with a parse error site.
///
/// ``ParserErrorToken`` captures the concrete lexeme and where it appeared in the
/// source so diagnostics can present precise, actionable messages.
///
/// - SeeAlso: ``SourceCodeLocation``, ``ParserError``
struct ParserErrorToken {
    /// The token’s textual representation.
    var value: String
    /// The token’s location in the source file.
    var location: SourceCodeLocation
}

/// Structured classification of parser errors used for recovery and diagnostics.
///
/// Each case carries enough detail to construct a user-facing diagnostic (via
/// ``ParserErrorInfo``) and to choose a ``RecoveryStrategy``. Use
/// ``buildInfo(at:)`` to convert to a strongly typed info payload that a
/// ``ParserErrorCreator`` can format into a ``ParserError``.
///
/// Usage:
/// ```swift
/// let info = ParserErrorType.expectedExpression.buildInfo(at: location)
/// let error = info.getError(from: DefaultParserErrorCreator.shared)
/// errorManager.addError(error)
/// ```
///
/// - SeeAlso: ``ParserErrorInfo``, ``ParserErrorCreator``, ``RecoveryStrategy``
enum ParserErrorType: CompilerPhaseErrorType {
    // MARK: Expected identifier messages
    /// A type identifier was expected at a specific syntactic site.
    case expectedTypeIdentifier(where: ExpectedTypeIdentifierErrorInfo.ErrorType)
    /// A parameter type annotation was expected.
    case expectedParameterType
    /// An identifier was expected at a specific syntactic site.
    case expectedIdentifier(in: ExpectedIdentifierErrorInfo.ErrorType)

    // MARK: Expected function-related messages
    /// A function application was expected (e.g., `name(`).
    case expectedFunctionApplication
    /// A function argument was expected, but an invalid token was found.
    case expectedFunctionArgument(got: ExpectedFunctionArgumentErrorInfo.ErrorType)
    
    // MARK: Internal error messages
    /// An internal parser invariant was violated.
    case internalParserError(type: InternalParserErrorInfo.ErrorType)
    
    // MARK: Expected punctuation messages
    /// A left parenthesis was expected in a specific context.
    case expectedLeftParen(where: ExpectedLeftParenErrorInfo.ErrorType)
    /// A right parenthesis was expected in a specific context.
    case expectedRightParen(where: ExpectedRightParenErrorInfo.ErrorType)
    /// A left brace was expected in a specific context.
    case expectedLeftBrace(where: ExpectedLeftBraceErrorInfo.ErrorType)
    /// A right brace was expected in a specific context.
    case expectedRightBrace(where: ExpectedRightBraceErrorInfo.ErrorType)
    /// An arrow (`->`) was expected in a function definition.
    case expectedArrowInFunctionDefinition
    /// An equal sign (`=`) was expected in an assignment.
    case expectedEqualInAssignment
    /// A semicolon was expected to terminate a statement of a particular kind.
    case expectedSemicolonToEndStatement(of: ExpectedSemicolonToEndStatementErrorInfo.ErrorType)
    
    // MARK: Expected function-related grammar messages
    /// A semicolon was expected to terminate a function call used as a statement.
    case expectedSemicolonToEndFunctionCall
    
    // MARK: Expected grammar messages
    /// An operator was expected in an expression context.
    case expectedOperator
    /// An expression was expected.
    case expectedExpression
    
    // MARK: Expected "part" messages
    /// A top-level statement was expected.
    case expectedTopLevelStatement(got: ExpectedTopLevelStatementErrorInfo.ErrorType)
    /// A block-level element was expected.
    case expectedBlockBodyPart(got: ExpectedBlockBodyPartErrorInfo.ErrorType)
    
    /// Builds a strongly-typed info object for messaging and formatting.
    ///
    /// - Parameter location: The best-available source location for the error.
    /// - Returns: A ``ParserErrorInfo`` payload that can be turned into a ``ParserError``.
    func buildInfo(at location: SourceCodeLocation) -> any ParserErrorInfo {
        switch self {
        case .expectedTypeIdentifier(where: let type):
            return ExpectedTypeIdentifierErrorInfo(sourceLocation: location, type: type)
        case .expectedParameterType:
            return ExpectedParameterTypeErrorInfo(sourceLocation: location)
        case .expectedIdentifier(in: let type):
            return ExpectedIdentifierErrorInfo(sourceLocation: location, type: type)
        case .expectedFunctionApplication:
            return ExpectedFunctionApplicationErrorInfo(sourceLocation: location)
        case .expectedFunctionArgument(got: let type):
            return ExpectedFunctionArgumentErrorInfo(sourceLocation: location, type: type)
        case .internalParserError(type: let type):
            return InternalParserErrorInfo(sourceLocation: location, type: type)
        case .expectedLeftParen(where: let type):
            return ExpectedLeftParenErrorInfo(sourceLocation: location, type: type)
        case .expectedRightParen(where: let type):
            return ExpectedRightParenErrorInfo(sourceLocation: location, type: type)
        case .expectedLeftBrace(where: let type):
            return ExpectedLeftBraceErrorInfo(sourceLocation: location, type: type)
        case .expectedRightBrace(where: let type):
            return ExpectedRightBraceErrorInfo(sourceLocation: location, type: type)
        case .expectedSemicolonToEndFunctionCall:
            return ExpectedSemicolonToEndFunctionCallErrorInfo(sourceLocation: location)
        case .expectedOperator:
            return ExpectedOperatorErrorInfo(sourceLocation: location)
        case .expectedExpression:
            return ExpectedExpressionErrorInfo(sourceLocation: location)
        case .expectedTopLevelStatement(got: let type):
            return ExpectedTopLevelStatementErrorInfo(sourceLocation: location, type: type)
        case .expectedBlockBodyPart(got: let type):
            return ExpectedBlockBodyPartErrorInfo(sourceLocation: location, type: type)
        case .expectedSemicolonToEndStatement(of: let type):
            return ExpectedSemicolonToEndStatementErrorInfo(sourceLocation: location, type: type)
        case .expectedArrowInFunctionDefinition:
            return ExpectedArrowInFunctionDefinitionErrorInfo(sourceLocation: location)
        case .expectedEqualInAssignment:
            return ExpectedEqualInAssignmentErrorInfo(sourceLocation: location)
        }
    }
}

/// Marker protocol for parser error info payloads.
///
/// Types conforming to ``ParserErrorInfo`` carry structured data sufficient
/// to produce a formatted ``ParserError`` using a ``ParserErrorCreator``.
///
/// - SeeAlso: ``ParserError``, ``ParserErrorCreator``
protocol ParserErrorInfo: CompilerPhaseErrorInfo {
    /// Builds a ``ParserError`` using the provided message creator.
    ///
    /// - Parameter manager: The message creator that formats this info payload.
    /// - Returns: A concrete, formatted ``ParserError``.
    func getError(from manager: any ParserErrorCreator) -> ParserError
}

/// Error info for an expected identifier in various contexts.
///
/// - SeeAlso: ``ExpectedIdentifierErrorInfo/ErrorType``
struct ExpectedIdentifierErrorInfo: ParserErrorInfo {
    
    /// The source location associated with the error.
    let sourceLocation: SourceCodeLocation
    /// The syntactic context in which the identifier was expected.
    let type: ErrorType
    /// The site where an identifier was expected.
    enum ErrorType {
        case functionDefinition
        case valueDefinition
        case functionParameter
        case functionApplication
    }
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
        return manager.expectedIdentifier(info: self)
    }
}

/// Error info for internal parser errors.
///
/// Use this for invariant violations or unreachable states.
///
/// - Important: Internal errors typically indicate a bug in the parser rather than
///   a problem with the user’s source.
struct InternalParserErrorInfo: ParserErrorInfo {
    
    /// The source location associated with the error.
    let sourceLocation: SourceCodeLocation
    /// The kind of internal error.
    let type: ErrorType
    /// Supported internal error categories.
    enum ErrorType {
        case unreachable(_ note: String)
    }
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
        return manager.internalParserError(info: self)
    }
}

/// Error info when a top-level statement was expected.
struct ExpectedTopLevelStatementErrorInfo: ParserErrorInfo {
    
    /// The source location associated with the error.
    let sourceLocation: SourceCodeLocation
    /// The token kind actually encountered (or EOF).
    let type: ErrorType
    /// The unexpected token classification.
    enum ErrorType {
        case eof
        case boolean
        case number
        case keyword(String)
        case symbol(String)
    }
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
        return manager.expectedTopLevelStatement(info: self)
    }
}

/// Error info for a missing or invalid type identifier.
///
/// - SeeAlso: ``ExpectedTypeIdentifierErrorInfo/ErrorType``
struct ExpectedTypeIdentifierErrorInfo: ParserErrorInfo {
    
    /// The source location associated with the error.
    let sourceLocation: SourceCodeLocation
    /// The context in which the type name was expected.
    let type: ErrorType
    /// Where the type was expected.
    enum ErrorType {
        case definitionType
        case functionType
        case functionParameterType
    }
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
        return manager.expectedTypeIdentifier(info: self)
    }
}

/// Error info for a missing parameter type.
struct ExpectedParameterTypeErrorInfo: ParserErrorInfo {
    
    /// The source location associated with the error.
    let sourceLocation: SourceCodeLocation
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
        return manager.expectedParameterType(info: self)
    }
}

/// Error info for a missing function application.
struct ExpectedFunctionApplicationErrorInfo: ParserErrorInfo {
    
    /// The source location associated with the error.
    let sourceLocation: SourceCodeLocation
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
        return manager.expectedFunctionApplication(info: self)
    }
}

/// Error info for a malformed function argument.
///
/// Indicates that an argument expression was expected but a different token kind
/// (or EOF) was encountered.
struct ExpectedFunctionArgumentErrorInfo: ParserErrorInfo {
    
    /// The source location associated with the error.
    let sourceLocation: SourceCodeLocation
    /// The token kind actually encountered.
    let type: ErrorType
    /// The unexpected token classification.
    enum ErrorType {
        case eof
        case keyword(String)
        case symbol(String)
    }
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
        return manager.expectedFunctionArgument(info: self)
    }
}

/// Error info for a missing left parenthesis.
struct ExpectedLeftParenErrorInfo: ParserErrorInfo {
    
    /// The source location associated with the error.
    let sourceLocation: SourceCodeLocation
    /// The context in which `(` was expected.
    let type: ErrorType
    /// Supported contexts for left parenthesis.
    enum ErrorType {
        case functionDefinition
        case ifStatement
    }
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
        return manager.expectedLeftParen(info: self)
    }
}

/// Error info for a missing right parenthesis.
struct ExpectedRightParenErrorInfo: ParserErrorInfo {
    
    /// The source location associated with the error.
    let sourceLocation: SourceCodeLocation
    /// The context in which `)` was expected.
    let type: ErrorType
    /// Supported contexts for right parenthesis.
    enum ErrorType {
        case functionDefinition
        case functionApplication
        case ifStatement
    }
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
        return manager.expectedRightParen(info: self)
    }
}

/// Error info for a missing left brace.
struct ExpectedLeftBraceErrorInfo: ParserErrorInfo {
    
    /// The source location associated with the error.
    let sourceLocation: SourceCodeLocation
    /// The context in which `{` was expected.
    let type: ErrorType
    /// Supported contexts for left brace.
    enum ErrorType {
        case ifStatement
        case functionBody
    }
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
        return manager.expectedLeftBrace(info: self)
    }
}

/// Error info for a missing right brace.
struct ExpectedRightBraceErrorInfo: ParserErrorInfo {
    
    /// The source location associated with the error.
    let sourceLocation: SourceCodeLocation
    /// The context in which `}` was expected.
    let type: ErrorType
    /// Supported contexts for right brace.
    enum ErrorType {
        case ifStatement
        case functionBody
    }
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
        return manager.expectedRightBrace(info: self)
    }
}

/// Error info for a missing semicolon after a function call used as a statement.
struct ExpectedSemicolonToEndFunctionCallErrorInfo: ParserErrorInfo {
    
    /// The source location associated with the error.
    let sourceLocation: SourceCodeLocation
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
        return manager.expectedSemicolonToEndFunctionCall(info: self)
    }
}

/// Error info for a missing operator in an expression context.
struct ExpectedOperatorErrorInfo: ParserErrorInfo {
    
    /// The source location associated with the error.
    let sourceLocation: SourceCodeLocation
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
        return manager.expectedOperator(info: self)
    }
}

/// Error info for a missing expression.
struct ExpectedExpressionErrorInfo: ParserErrorInfo {
    
    /// The source location associated with the error.
    let sourceLocation: SourceCodeLocation
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
        return manager.expectedExpression(info: self)
    }
}

/// Error info for an unexpected or missing block body part.
struct ExpectedBlockBodyPartErrorInfo: ParserErrorInfo {
    
    /// The source location associated with the error.
    let sourceLocation: SourceCodeLocation
    /// The token kind actually encountered (or EOF).
    let type: ErrorType
    /// The unexpected token classification.
    enum ErrorType {
        case boolean
        case number
        case keyword(String)
        case symbol(String)
        case eof
    }
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
        return manager.expectedBlockBodyPart(info: self)
    }
}

/// Error info for a missing semicolon at the end of a statement.
///
/// The statement kind is included to tailor messaging (e.g., after `return` or a definition).
struct ExpectedSemicolonToEndStatementErrorInfo: ParserErrorInfo {
    
    /// The source location associated with the error.
    let sourceLocation: SourceCodeLocation
    /// The statement kind that requires a semicolon terminator.
    let type: ErrorType
    /// Supported statement kinds for this diagnostic.
    enum ErrorType {
        case `return`
        case definition
    }
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
        return manager.expectedSemicolonToEndStatement(info: self)
    }
}

/// Error info for a missing arrow (`->`) in a function definition.
struct ExpectedArrowInFunctionDefinitionErrorInfo: ParserErrorInfo {
    
    /// The source location associated with the error.
    let sourceLocation: SourceCodeLocation
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
        return manager.expectedArrowInFunctionDefinition(info: self)
    }
}

/// Error info for a missing equal sign (`=`) in an assignment.
struct ExpectedEqualInAssignmentErrorInfo: ParserErrorInfo {
    
    /// The source location associated with the error.
    let sourceLocation: SourceCodeLocation
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
        return manager.expectedEqualInAssignment(info: self)
    }
}

/// A concrete, formatted parser error.
///
/// ``ParserError`` pairs a human-readable message with a source location.
/// Instances are produced by a ``ParserErrorCreator`` using an associated
/// ``ParserErrorInfo`` payload.
///
/// - SeeAlso: ``ParserErrorCreator``, ``ParserErrorInfo``
struct ParserError: CompilerPhaseError {
    /// Where in the source this error applies.
    let location: SourceCodeLocation
    /// The human-readable diagnostic message.
    let message: String
}

/// Produces ``ParserError`` messages for specific error info payloads.
///
/// Implementations encapsulate localized strings or message templates, mapping
/// each info payload to a concrete, formatted diagnostic.
///
/// - SeeAlso: ``ParserErrorInfo``, ``ParserError``
protocol ParserErrorCreator {
    
    // MARK: Expected identifier messages
    func expectedTypeIdentifier(info: ExpectedTypeIdentifierErrorInfo) -> ParserError
    func expectedParameterType(info: ExpectedParameterTypeErrorInfo) -> ParserError
    func expectedIdentifier(info: ExpectedIdentifierErrorInfo) -> ParserError

    // MARK: Expected function-related messages
    func expectedFunctionApplication(info: ExpectedFunctionApplicationErrorInfo) -> ParserError
    func expectedFunctionArgument(info: ExpectedFunctionArgumentErrorInfo) -> ParserError
    
    // MARK: Internal error messages
    func internalParserError(info: InternalParserErrorInfo) -> ParserError
    
    // MARK: Expected punctuation messages
    func expectedLeftParen(info: ExpectedLeftParenErrorInfo) -> ParserError
    func expectedRightParen(info: ExpectedRightParenErrorInfo) -> ParserError
    func expectedLeftBrace(info: ExpectedLeftBraceErrorInfo) -> ParserError
    func expectedRightBrace(info: ExpectedRightBraceErrorInfo) -> ParserError
    func expectedArrowInFunctionDefinition(info: ExpectedArrowInFunctionDefinitionErrorInfo) -> ParserError
    func expectedEqualInAssignment(info: ExpectedEqualInAssignmentErrorInfo) -> ParserError
    func expectedSemicolonToEndStatement(info: ExpectedSemicolonToEndStatementErrorInfo) -> ParserError
    
    // MARK: Expected function-related grammar messages
    func expectedSemicolonToEndFunctionCall(info: ExpectedSemicolonToEndFunctionCallErrorInfo) -> ParserError
    
    // MARK: Expected grammar messages
    func expectedOperator(info: ExpectedOperatorErrorInfo) -> ParserError
    func expectedExpression(info: ExpectedExpressionErrorInfo) -> ParserError
    
    // MARK: Expected "part" messages
    func expectedTopLevelStatement(info: ExpectedTopLevelStatementErrorInfo) -> ParserError
    func expectedBlockBodyPart(info: ExpectedBlockBodyPartErrorInfo) -> ParserError
}
