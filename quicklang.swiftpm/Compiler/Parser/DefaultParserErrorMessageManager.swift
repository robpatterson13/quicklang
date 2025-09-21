//
//  DefaultParserErrorMessageManager.swift
//  quicklang
//
//  Created by Rob Patterson on 9/14/25.
//

class DefaultParserErrorFormatter: ParserErrorFormatter {
    func format(_ error: ParserError) -> String {
        let locationInfo = "On line \(error.location.startLine), column \(error.location.startColumn):\n"
        
        return locationInfo + error.message
    }
}

class DefaultParserErrorMessageManager: ParserErrorMessageManager {
    
    func expectedTypeIdentifier(info: ExpectedTypeIdentifierErrorInfo) -> ParserError {
        return ParserError(location: .beginningOfFile, message: "")
    }
    
    func expectedParameterType(info: ExpectedParameterTypeErrorInfo) -> ParserError {
        return ParserError(location: .beginningOfFile, message: "")
    }
    
    func expectedIdentifier(info: ExpectedIdentifierErrorInfo) -> ParserError {
        return ParserError(location: .beginningOfFile, message: "")
    }
    
    func expectedFunctionApplication(info: ExpectedFunctionApplicationErrorInfo) -> ParserError {
        return ParserError(location: .beginningOfFile, message: "")
    }
    
    func expectedFunctionArgument(info: ExpectedFunctionArgumentErrorInfo) -> ParserError {
        return ParserError(location: .beginningOfFile, message: "")
    }
    
    func internalParserError(info: InternalParserErrorInfo) -> ParserError {
        return ParserError(location: .beginningOfFile, message: "")
    }
    
    func expectedLeftParen(info: ExpectedLeftParenErrorInfo) -> ParserError {
        return ParserError(location: .beginningOfFile, message: "")
    }
    
    func expectedRightParen(info: ExpectedRightParenErrorInfo) -> ParserError {
        return ParserError(location: .beginningOfFile, message: "")
    }
    
    func expectedLeftBrace(info: ExpectedLeftBraceErrorInfo) -> ParserError {
        return ParserError(location: .beginningOfFile, message: "")
    }
    
    func expectedRightBrace(info: ExpectedRightBraceErrorInfo) -> ParserError {
        return ParserError(location: .beginningOfFile, message: "")
    }
    
    func expectedArrowInFunctionDefinition(info: ExpectedArrowInFunctionDefinitionErrorInfo) -> ParserError {
        return ParserError(location: .beginningOfFile, message: "")
    }
    
    func expectedEqualInAssignment(info: ExpectedEqualInAssignmentErrorInfo) -> ParserError {
        return ParserError(location: .beginningOfFile, message: "")
    }
    
    func expectedSemicolonToEndStatement(info: ExpectedSemicolonToEndStatementErrorInfo) -> ParserError {
        return ParserError(location: .beginningOfFile, message: "")
    }
    
    func expectedSemicolonToEndFunctionCall(info: ExpectedSemicolonToEndFunctionCallErrorInfo) -> ParserError {
        return ParserError(location: .beginningOfFile, message: "")
    }
    
    func expectedOperator(info: ExpectedOperatorErrorInfo) -> ParserError {
        return ParserError(location: .beginningOfFile, message: "")
    }
    
    func expectedExpression(info: ExpectedExpressionErrorInfo) -> ParserError {
        return ParserError(location: .beginningOfFile, message: "")
    }
    
    func expectedTopLevelStatement(info: ExpectedTopLevelStatementErrorInfo) -> ParserError {
        return ParserError(location: .beginningOfFile, message: "")
    }
    
    func expectedBlockBodyPart(info: ExpectedBlockBodyPartErrorInfo) -> ParserError {
        return ParserError(location: .beginningOfFile, message: "")
    }
}
