//
//  ParserError.swift
//  quicklang
//
//  Created by Rob Patterson on 7/19/25.
//

struct ParserErrorToken {
    var value: String
    var location: SourceCodeLocation
}

enum ParserErrorType: CompilerPhaseErrorType {
    // MARK: Expected identifier messages
    case expectedTypeIdentifier(where: ExpectedTypeIdentifierErrorInfo.ErrorType)
    case expectedParameterType
    case expectedIdentifier(in: ExpectedIdentifierErrorInfo.ErrorType)
    case expectedValidAttribute(in: ExpectedValidAttributeErrorInfo.ErrorType)
    
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
        case .expectedValidAttribute(in: let type):
            return ExpectedValidAttributeErrorInfo(sourceLocation: location, type: type)
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

protocol ParserErrorInfo: CompilerPhaseErrorInfo {
    func getError(from manager: any ParserErrorCreator) -> ParserError
}

struct ExpectedIdentifierErrorInfo: ParserErrorInfo {
    
    let sourceLocation: SourceCodeLocation
    let type: ErrorType
    enum ErrorType {
        case functionDefinition
        case valueDefinition
        case functionParameter
        case functionApplication
        case assignmentStatement
        case attribute
    }
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
        return manager.expectedIdentifier(info: self)
    }
}

struct InternalParserErrorInfo: ParserErrorInfo {
    
    let sourceLocation: SourceCodeLocation
    let type: ErrorType
    enum ErrorType {
        case unreachable(_ note: String)
    }
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
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
        case identifier(String)
    }
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
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
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
        return manager.expectedTypeIdentifier(info: self)
    }
}

struct ExpectedParameterTypeErrorInfo: ParserErrorInfo {
    
    let sourceLocation: SourceCodeLocation
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
        return manager.expectedParameterType(info: self)
    }
}

struct ExpectedFunctionApplicationErrorInfo: ParserErrorInfo {
    
    let sourceLocation: SourceCodeLocation
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
        return manager.expectedFunctionApplication(info: self)
    }
}

struct ExpectedValidAttributeErrorInfo: ParserErrorInfo {
    
    let sourceLocation: SourceCodeLocation
    let type: ErrorType
    enum ErrorType {
        case notAnAttribute(String)
    }
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
        return manager.expectedValidAttribute(info: self)
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
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
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
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
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
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
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
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
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
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
        return manager.expectedRightBrace(info: self)
    }
}

struct ExpectedSemicolonToEndFunctionCallErrorInfo: ParserErrorInfo {
    
    let sourceLocation: SourceCodeLocation
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
        return manager.expectedSemicolonToEndFunctionCall(info: self)
    }
}

struct ExpectedOperatorErrorInfo: ParserErrorInfo {
    
    let sourceLocation: SourceCodeLocation
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
        return manager.expectedOperator(info: self)
    }
}

struct ExpectedExpressionErrorInfo: ParserErrorInfo {
    
    let sourceLocation: SourceCodeLocation
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
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
        case identifier(String)
        case eof
    }
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
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
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
        return manager.expectedSemicolonToEndStatement(info: self)
    }
}

struct ExpectedArrowInFunctionDefinitionErrorInfo: ParserErrorInfo {
    
    let sourceLocation: SourceCodeLocation
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
        return manager.expectedArrowInFunctionDefinition(info: self)
    }
}

struct ExpectedEqualInAssignmentErrorInfo: ParserErrorInfo {
    
    let sourceLocation: SourceCodeLocation
    
    func getError(from manager: any ParserErrorCreator) -> ParserError {
        return manager.expectedEqualInAssignment(info: self)
    }
}

struct ParserError: CompilerPhaseError {
    let location: SourceCodeLocation
    let message: String
}

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
    func expectedValidAttribute(info: ExpectedValidAttributeErrorInfo) -> ParserError
    
    // MARK: Expected function-related grammar messages
    func expectedSemicolonToEndFunctionCall(info: ExpectedSemicolonToEndFunctionCallErrorInfo) -> ParserError
    
    // MARK: Expected grammar messages
    func expectedOperator(info: ExpectedOperatorErrorInfo) -> ParserError
    func expectedExpression(info: ExpectedExpressionErrorInfo) -> ParserError
    
    // MARK: Expected "part" messages
    func expectedTopLevelStatement(info: ExpectedTopLevelStatementErrorInfo) -> ParserError
    func expectedBlockBodyPart(info: ExpectedBlockBodyPartErrorInfo) -> ParserError
}
