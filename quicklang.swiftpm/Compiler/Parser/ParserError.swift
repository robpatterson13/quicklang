//
//  ParserError.swift
//  quicklang
//
//  Created by Rob Patterson on 7/19/25.
//

enum RecoveryStrategy: Error {
    
    typealias RecoverySet = Set<Token>
    case dropUntil(in: RecoverySet)
    
    static let dropUntilEndOfStatement = Self.dropUntil(in: [.SEMICOLON])
    static let dropUntilEndOfFunction = Self.dropUntil(in: [.RBRACE])
    
    case add(token: Token)
    
    case ignore
    
    case unrecoverable
    
    indirect case override(with: Self)
}


protocol RecoveryEngine {
    func recover(from error: ParserErrorType) -> RecoveryStrategy
}

class DefaultRecovery: RecoveryEngine {
    
    static var shared: DefaultRecovery {
        DefaultRecovery()
    }
    
    private init() {
        
    }
    
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
        case .valueDefinition, .functionApplication:
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
        case .boolean, .number, .symbol:
            return .dropUntilEndOfStatement
        case .keyword(let kw):
            // MARK: fix this, this is terrible and I already have the enum to do this properly
            return ["func", "if", "else"].contains(kw) ? .dropUntilEndOfFunction : .dropUntilEndOfStatement
        }
    }
    
    private func expectedBlockBodyPart(
        _ info: ExpectedBlockBodyPartErrorInfo.ErrorType
    ) -> RecoveryStrategy {
        
        switch info {
        case .boolean, .number, .keyword, .symbol:
            return .dropUntilEndOfFunction
        case .eof:
            return .unrecoverable
        }
    }
    
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

struct ParserErrorToken {
    
    var value: String
    var location: SourceCodeLocation
}

enum ParserErrorType {
    // MARK: Expected identifier messages
    case expectedTypeIdentifier(where: ExpectedTypeIdentifierErrorInfo.ErrorType)
    case expectedParameterType
    case expectedIdentifier(in: ExpectedIdentifierErrorInfo.ErrorType)

    // MARK: Expected function-related messages
    case expectedFunctionApplication
    case expectedFunctionArgument(got: ExpectedFunctionArgumentErrorInfo.ErrorType)
    
    // MARK: Internal error messages
    case internalParserError(type: InternalParserErrorInfo.ErrorType)
    
    // MARK: Expected punctuation messages
    case expectedLeftParen(where: ExpectedLeftParenErrorInfo.ErrorType)
    case expectedRightParen(where: ExpectedRightParenErrorInfo.ErrorType)
    case expectedLeftBrace(where: ExpectedLeftBraceErrorInfo.ErrorType)
    case expectedRightBrace(where: ExpectedRightBraceErrorInfo.ErrorType)
    case expectedArrowInFunctionDefinition
    case expectedEqualInAssignment
    case expectedSemicolonToEndStatement(of: ExpectedSemicolonToEndStatementErrorInfo.ErrorType)
    
    // MARK: Expected function-related grammar messages
    case expectedSemicolonToEndFunctionCall
    
    // MARK: Expected grammar messages
    case expectedOperator
    case expectedExpression
    
    // MARK: Expected "part" messages
    case expectedTopLevelStatement(got: ExpectedTopLevelStatementErrorInfo.ErrorType)
    case expectedBlockBodyPart(got: ExpectedBlockBodyPartErrorInfo.ErrorType)
    
    fileprivate func buildInfo(at location: SourceCodeLocation) -> any ParserErrorInfo {
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

protocol PhaseErrorInfo {
    associatedtype PhaseErrorMessageManager
    associatedtype PhaseError
    
    var sourceLocation: SourceCodeLocation { get }
    
    func getError(from manager: PhaseErrorMessageManager) -> PhaseError
}

protocol ParserErrorInfo: PhaseErrorInfo {
    
    func getError(from manager: any ParserErrorMessageManager) -> ParserError
}

struct ExpectedIdentifierErrorInfo: ParserErrorInfo {
    
    let sourceLocation: SourceCodeLocation
    let type: ErrorType
    enum ErrorType {
        case functionDefinition
        case valueDefinition
        case functionParameter
        case functionApplication
    }
    
    func getError(from manager: any ParserErrorMessageManager) -> ParserError {
        return manager.expectedIdentifier(info: self)
    }
}

struct InternalParserErrorInfo: ParserErrorInfo {
    
    let sourceLocation: SourceCodeLocation
    let type: ErrorType
    enum ErrorType {
        case unreachable(_ note: String)
    }
    
    func getError(from manager: any ParserErrorMessageManager) -> ParserError {
        return manager.internalParserError(info: self)
    }
}

struct ExpectedTopLevelStatementErrorInfo: ParserErrorInfo {
    
    let sourceLocation: SourceCodeLocation
    let type: ErrorType
    enum ErrorType {
        case eof
        case boolean
        case number
        case keyword(String)
        case symbol(String)
    }
    
    func getError(from manager: any ParserErrorMessageManager) -> ParserError {
        return manager.expectedTopLevelStatement(info: self)
    }
}

struct ExpectedTypeIdentifierErrorInfo: ParserErrorInfo {
    
    let sourceLocation: SourceCodeLocation
    let type: ErrorType
    enum ErrorType {
        case definitionType
        case functionType
        case functionParameterType
    }
    
    func getError(from manager: any ParserErrorMessageManager) -> ParserError {
        return manager.expectedTypeIdentifier(info: self)
    }
}

struct ExpectedParameterTypeErrorInfo: ParserErrorInfo {
    
    let sourceLocation: SourceCodeLocation
    
    func getError(from manager: any ParserErrorMessageManager) -> ParserError {
        return manager.expectedParameterType(info: self)
    }
}

struct ExpectedFunctionApplicationErrorInfo: ParserErrorInfo {
    
    let sourceLocation: SourceCodeLocation
    
    func getError(from manager: any ParserErrorMessageManager) -> ParserError {
        return manager.expectedFunctionApplication(info: self)
    }
}

struct ExpectedFunctionArgumentErrorInfo: ParserErrorInfo {
    
    let sourceLocation: SourceCodeLocation
    let type: ErrorType
    enum ErrorType {
        case eof
        case keyword(String)
        case symbol(String)
    }
    
    func getError(from manager: any ParserErrorMessageManager) -> ParserError {
        return manager.expectedFunctionArgument(info: self)
    }
}

struct ExpectedLeftParenErrorInfo: ParserErrorInfo {
    
    let sourceLocation: SourceCodeLocation
    let type: ErrorType
    enum ErrorType {
        case functionDefinition
        case ifStatement
    }
    
    func getError(from manager: any ParserErrorMessageManager) -> ParserError {
        return manager.expectedLeftParen(info: self)
    }
}

struct ExpectedRightParenErrorInfo: ParserErrorInfo {
    
    let sourceLocation: SourceCodeLocation
    let type: ErrorType
    enum ErrorType {
        case functionDefinition
        case functionApplication
        case ifStatement
    }
    
    func getError(from manager: any ParserErrorMessageManager) -> ParserError {
        return manager.expectedRightParen(info: self)
    }
}

struct ExpectedLeftBraceErrorInfo: ParserErrorInfo {
    
    let sourceLocation: SourceCodeLocation
    let type: ErrorType
    enum ErrorType {
        case ifStatement
        case functionBody
    }
    
    func getError(from manager: any ParserErrorMessageManager) -> ParserError {
        return manager.expectedLeftBrace(info: self)
    }
}

struct ExpectedRightBraceErrorInfo: ParserErrorInfo {
    
    let sourceLocation: SourceCodeLocation
    let type: ErrorType
    enum ErrorType {
        case ifStatement
        case functionBody
    }
    
    func getError(from manager: any ParserErrorMessageManager) -> ParserError {
        return manager.expectedRightBrace(info: self)
    }
}

struct ExpectedSemicolonToEndFunctionCallErrorInfo: ParserErrorInfo {
    
    let sourceLocation: SourceCodeLocation
    
    func getError(from manager: any ParserErrorMessageManager) -> ParserError {
        return manager.expectedSemicolonToEndFunctionCall(info: self)
    }
}

struct ExpectedOperatorErrorInfo: ParserErrorInfo {
    
    let sourceLocation: SourceCodeLocation
    
    func getError(from manager: any ParserErrorMessageManager) -> ParserError {
        return manager.expectedOperator(info: self)
    }
}

struct ExpectedExpressionErrorInfo: ParserErrorInfo {
    
    let sourceLocation: SourceCodeLocation
    
    func getError(from manager: any ParserErrorMessageManager) -> ParserError {
        return manager.expectedExpression(info: self)
    }
}

struct ExpectedBlockBodyPartErrorInfo: ParserErrorInfo {
    
    let sourceLocation: SourceCodeLocation
    let type: ErrorType
    enum ErrorType {
        case boolean
        case number
        case keyword(String)
        case symbol(String)
        case eof
    }
    
    func getError(from manager: any ParserErrorMessageManager) -> ParserError {
        return manager.expectedBlockBodyPart(info: self)
    }
}

struct ExpectedSemicolonToEndStatementErrorInfo: ParserErrorInfo {
    
    let sourceLocation: SourceCodeLocation
    let type: ErrorType
    enum ErrorType {
        case `return`
        case definition
    }
    
    func getError(from manager: any ParserErrorMessageManager) -> ParserError {
        return manager.expectedSemicolonToEndStatement(info: self)
    }
}

struct ExpectedArrowInFunctionDefinitionErrorInfo: ParserErrorInfo {
    
    let sourceLocation: SourceCodeLocation
    
    func getError(from manager: any ParserErrorMessageManager) -> ParserError {
        return manager.expectedArrowInFunctionDefinition(info: self)
    }
}

struct ExpectedEqualInAssignmentErrorInfo: ParserErrorInfo {
    
    let sourceLocation: SourceCodeLocation
    
    func getError(from manager: any ParserErrorMessageManager) -> ParserError {
        return manager.expectedEqualInAssignment(info: self)
    }
}

protocol ParserErrorManagerDelegate: DiagnosticEngineDelegate {
}

class ParserErrorManager {
    
    static var `default`: ParserErrorManager {
        ParserErrorManager(errorMessageManager: DefaultParserErrorMessageManager(), errorFormatter: DefaultParserErrorFormatter())
    }
    
    weak var delegate: ParserErrorManagerDelegate?
    
    var errors: [any ParserErrorInfo] = []
    private var errorMessageManager: any ParserErrorMessageManager
    private var errorFormatter: any ParserErrorFormatter
    
    private init(errorMessageManager: any ParserErrorMessageManager, errorFormatter: any ParserErrorFormatter) {
        self.errorMessageManager = errorMessageManager
        self.errorFormatter = errorFormatter
    }
    
    func add(_ error: ParserErrorType, at location: SourceCodeLocation) {
        errors.append(error.buildInfo(at: location))
        delegate?.onError()
    }
}

protocol ParserErrorFormatter {
    func format(_ error: ParserError) -> String
}

struct ParserError {
    let location: SourceCodeLocation
    let message: String
    
    func getDescription(from formatter: any ParserErrorFormatter) -> String {
        return formatter.format(self)
    }
}

protocol ParserErrorMessageManager {
    
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

