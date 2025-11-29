//
//  ParserRecovery.swift
//  quicklang
//
//  Created by Rob Patterson on 11/20/25.
//

/// Strategy for recovering from a parse error.
///
/// Encodes how the parser should proceed (drop tokens, synthesize tokens, ignore,
/// or abort recovery) and allows layering via `override`.
enum RecoveryStrategy: Error {
    
    /// A set of tokens that signal a safe resynchronization point.
    typealias RecoverySet = Set<Token>
    
    /// Discard tokens until one in the provided recovery set is found.
    case dropUntil(in: RecoverySet)
    
    /// Convenience: drop until end-of-statement (`;`).
    static let dropUntilEndOfStatement = Self.dropUntil(in: [.SEMICOLON])
    /// Convenience: drop until end-of-function (`}`).
    static let dropUntilEndOfFunction = Self.dropUntil(in: [.RBRACE])
    
    /// Synthesize a missing token to continue.
    case add(token: Token)
    
    /// Do nothing (continue parsing from current position).
    case ignore
    
    /// Abort recovery for this error (escalate).
    case unrecoverable
    
    /// Replace this strategy with a different one (allows late overrides).
    indirect case override(with: Self)
}

/// Component that maps a parser error to a recovery strategy.
protocol RecoveryEngine {
    /// Returns a recovery strategy for the given parse error.
    func recover(from error: ParserErrorType) -> RecoveryStrategy
}

/// Default recovery policy mapping specific parser errors to strategies.
///
/// Encapsulates heuristics for resynchronizing the parser after common syntax errors.
class DefaultRecovery: RecoveryEngine {
    
    /// Shared default instance.
    static var shared: DefaultRecovery {
        DefaultRecovery()
    }
    
    private init() { }
    
    private func expectedTypeIdentifier(
        _ info: ExpectedTypeIdentifierErrorInfo.ErrorType
    ) -> RecoveryStrategy {
        switch info {
        case .definitionType:
            return .dropUntilEndOfStatement
        case .functionType, .functionParameterType:
            return .dropUntilEndOfFunction
        }
    }
    
    private func expectedParameterType() -> RecoveryStrategy {
        .dropUntilEndOfFunction
    }
    
    private func expectedIdentifier(
        _ info: ExpectedIdentifierErrorInfo.ErrorType
    ) -> RecoveryStrategy {
        switch info {
        case .functionDefinition, .functionParameter:
            return .dropUntilEndOfFunction
        case .valueDefinition, .functionApplication, .assignmentStatement:
            return .dropUntilEndOfStatement
        }
    }
    
    private func expectedFunctionApplication() -> RecoveryStrategy {
        .dropUntilEndOfStatement
    }
    
    private func expectedFunctionArgument(
        _ info: ExpectedFunctionArgumentErrorInfo.ErrorType
    ) -> RecoveryStrategy {
        switch info {
        case .eof:
            return .unrecoverable
        case .symbol, .keyword:
            return .dropUntilEndOfStatement
        }
    }
    
    private func internalParserError(
        _ info: InternalParserErrorInfo.ErrorType
    ) -> RecoveryStrategy {
        switch info {
        case .unreachable:
            return .unrecoverable
        }
    }
    
    private func expectedLeftParen(
        _ info: ExpectedLeftParenErrorInfo.ErrorType
    ) -> RecoveryStrategy {
        switch info {
        case .functionDefinition, .ifStatement:
            return .dropUntilEndOfFunction
        }
    }
    
    private func expectedRightParen(
        _ info: ExpectedRightParenErrorInfo.ErrorType
    ) -> RecoveryStrategy {
        switch info {
        case .functionDefinition, .ifStatement:
            return .dropUntilEndOfFunction
        case .functionApplication:
            return .dropUntilEndOfStatement
        }
    }
    
    private func expectedLeftBrace(
        _ info: ExpectedLeftBraceErrorInfo.ErrorType
    ) -> RecoveryStrategy {
        switch info {
        case .ifStatement, .functionBody:
            return .dropUntilEndOfFunction
        }
    }
    
    private func expectedRightBrace(
        _ info: ExpectedRightBraceErrorInfo.ErrorType
    ) -> RecoveryStrategy {
        switch info {
        case .ifStatement, .functionBody:
            return .dropUntilEndOfFunction
        }
    }
    
    private func expectedArrowInFunctionDefinition() -> RecoveryStrategy {
        .dropUntilEndOfFunction
    }
    
    private func expectedEqualInAssignment() -> RecoveryStrategy {
        .dropUntilEndOfStatement
    }
    
    private func expectedSemicolonToEndStatement(
        _ info: ExpectedSemicolonToEndStatementErrorInfo.ErrorType
    ) -> RecoveryStrategy {
        switch info {
        case .return, .definition:
            return .ignore
        }
    }
    
    private func expectedSemicolonToEndFunctionCall() -> RecoveryStrategy {
        .ignore
    }
    
    private func expectedOperator() -> RecoveryStrategy {
        .ignore
    }
    
    private func expectedExpression() -> RecoveryStrategy {
        .unrecoverable
    }
    
    private func expectedTopLevelStatement(
        _ info: ExpectedTopLevelStatementErrorInfo.ErrorType
    ) -> RecoveryStrategy {
        switch info {
        case .eof:
            return .unrecoverable
        case .boolean, .number, .symbol, .identifier:
            return .dropUntilEndOfStatement
        case .keyword(let kw):
            // TODO: Replace ad-hoc keyword list with a proper enum-based classification.
            return ["func", "if", "else"].contains(kw) ? .dropUntilEndOfFunction : .dropUntilEndOfStatement
        }
    }
    
    private func expectedBlockBodyPart(
        _ info: ExpectedBlockBodyPartErrorInfo.ErrorType
    ) -> RecoveryStrategy {
        switch info {
        case .boolean, .number, .keyword, .symbol, .identifier:
            return .dropUntilEndOfFunction
        case .eof:
            return .unrecoverable
        }
    }
    
    /// Computes a recovery strategy for the given parser error.
    func recover(from error: ParserErrorType) -> RecoveryStrategy {
        switch error {
        case .expectedTypeIdentifier(where: let info):
            return expectedTypeIdentifier(info)
        case .expectedParameterType:
            return expectedParameterType()
        case .expectedIdentifier(in: let info):
            return expectedIdentifier(info)
        case .expectedFunctionApplication:
            return expectedFunctionApplication()
        case .expectedFunctionArgument(got: let info):
            return expectedFunctionArgument(info)
        case .internalParserError(type: let info):
            return internalParserError(info)
        case .expectedLeftParen(where: let info):
            return expectedLeftParen(info)
        case .expectedRightParen(where: let info):
            return expectedRightParen(info)
        case .expectedLeftBrace(where: let info):
            return expectedLeftBrace(info)
        case .expectedRightBrace(where: let info):
            return expectedRightBrace(info)
        case .expectedArrowInFunctionDefinition:
            return expectedArrowInFunctionDefinition()
        case .expectedEqualInAssignment:
            return expectedEqualInAssignment()
        case .expectedSemicolonToEndStatement(of: let info):
            return expectedSemicolonToEndStatement(info)
        case .expectedSemicolonToEndFunctionCall:
            return expectedSemicolonToEndFunctionCall()
        case .expectedOperator:
            return expectedOperator()
        case .expectedExpression:
            return expectedExpression()
        case .expectedTopLevelStatement(got: let info):
            return expectedTopLevelStatement(info)
        case .expectedBlockBodyPart(got: let info):
            return expectedBlockBodyPart(info)
        }
    }
}
