//
//  DefaultParserErrorMessageManager.swift
//  quicklang
//
//  Created by Rob Patterson on 9/14/25.
//

class DefaultParserErrorCreator: ParserErrorCreator {
    
    static var shared: DefaultParserErrorCreator {
        DefaultParserErrorCreator()
    }
    
    private init() {}
    
    func expectedTypeIdentifier(info: ExpectedTypeIdentifierErrorInfo) -> ParserError {
        let specific: String
        switch info.type {
        case .definitionType:
            specific = "variable definition"
        case .functionType:
            specific = "function return following `->`"
        case .functionParameterType:
            specific = "function parameter"
        }
        
        let message = "Expected a type identifier in \(specific)"
        return ParserError(location: info.sourceLocation, message: message)
    }
    
    func expectedParameterType(info: ExpectedParameterTypeErrorInfo) -> ParserError {
        let message = "Expected a type for parameter in function definition"
        return ParserError(location: info.sourceLocation, message: message)
    }
    
    func expectedIdentifier(info: ExpectedIdentifierErrorInfo) -> ParserError {
        let specific: String
        switch info.type {
        case .functionDefinition:
            specific = "function definition"
        case .valueDefinition:
            specific = "variable definition"
        case .functionParameter:
            specific = "function parameter"
        case .functionApplication:
            specific = "function application"
        }
        
        let message = "Expected an identifier in \(specific)"
        return ParserError(location: info.sourceLocation, message: message)
    }
    
    func expectedFunctionApplication(info: ExpectedFunctionApplicationErrorInfo) -> ParserError {
        let message = "Expected function application"
        return ParserError(location: info.sourceLocation, message: message)
    }
    
    func expectedFunctionArgument(info: ExpectedFunctionArgumentErrorInfo) -> ParserError {
        let specific: String
        switch info.type {
        case .eof:
            specific = "reached the end of the file"
        case .keyword(let string):
            specific = "got keyword `\(string)`"
        case .symbol(let string):
            specific = "got symbol `\(string)`"
        }
        
        let message = "Expected a function argument, but \(specific)"
        return ParserError(location: info.sourceLocation, message: message)
    }
    
    func internalParserError(info: InternalParserErrorInfo) -> ParserError {
        let specific: String
        switch info.type {
        case .unreachable(let note):
            specific = note
        }
        
        let message = "Internal parser error; note: \(specific)"
        return ParserError(location: info.sourceLocation, message: message)
    }
    
    func expectedLeftParen(info: ExpectedLeftParenErrorInfo) -> ParserError {
        let specific: String
        switch info.type {
        case .functionDefinition:
            specific = "parameter list of function definition"
        case .ifStatement:
            specific = "condition of if statement"
        }
        
        let message = "Expected a left paren `(` to begin \(specific)"
        return ParserError(location: info.sourceLocation, message: message)
    }
    
    func expectedRightParen(info: ExpectedRightParenErrorInfo) -> ParserError {
        let specific: String
        switch info.type {
        case .functionDefinition:
            specific = "parameter list of function definition"
        case .ifStatement:
            specific = "condition of if statement"
        case .functionApplication:
            specific = "function application"
        }
        
        let message = "Expected a right paren `)` to end \(specific)"
        return ParserError(location: info.sourceLocation, message: message)
    }
    
    func expectedLeftBrace(info: ExpectedLeftBraceErrorInfo) -> ParserError {
        let specific: String
        switch info.type {
        case .ifStatement:
            specific = "body of if statement"
        case .functionBody:
            specific = "body of function"
        }
        
        let message = "Expected a left brace `{` to begin \(specific)"
        return ParserError(location: info.sourceLocation, message: message)
    }
    
    func expectedRightBrace(info: ExpectedRightBraceErrorInfo) -> ParserError {
        let specific: String
        switch info.type {
        case .ifStatement:
            specific = "body of if statement"
        case .functionBody:
            specific = "body of function"
        }
        
        let message = "Expected a right brace `}` to end \(specific)"
        return ParserError(location: info.sourceLocation, message: message)
    }
    
    func expectedArrowInFunctionDefinition(info: ExpectedArrowInFunctionDefinitionErrorInfo) -> ParserError {
        let message = "Expected an arrow `->` to specify the return type of function"
        return ParserError(location: info.sourceLocation, message: message)
    }
    
    func expectedEqualInAssignment(info: ExpectedEqualInAssignmentErrorInfo) -> ParserError {
        let message = "Expected an equals sign `=` in assignment statement"
        return ParserError(location: info.sourceLocation, message: message)
    }
    
    func expectedSemicolonToEndStatement(info: ExpectedSemicolonToEndStatementErrorInfo) -> ParserError {
        let specific: String
        switch info.type {
        case .return:
            specific = "return statement"
        case .definition:
            specific = "variable definition"
        }
        
        let message = "Expected a semicolon `;` to end \(specific)"
        return ParserError(location: info.sourceLocation, message: message)
    }
    
    func expectedSemicolonToEndFunctionCall(info: ExpectedSemicolonToEndFunctionCallErrorInfo) -> ParserError {
        let message = "Expected a semicolon `;` to end function call expression"
        return ParserError(location: info.sourceLocation, message: message)
    }
    
    func expectedOperator(info: ExpectedOperatorErrorInfo) -> ParserError {
        let message = "Expected an operator in this expression"
        return ParserError(location: info.sourceLocation, message: message)
    }
    
    func expectedExpression(info: ExpectedExpressionErrorInfo) -> ParserError {
        let message = "Expected an expression here"
        return ParserError(location: info.sourceLocation, message: message)
    }
    
    func expectedTopLevelStatement(info: ExpectedTopLevelStatementErrorInfo) -> ParserError {
        let specific: String
        switch info.type {
        case .eof:
            specific = "reached end of the file"
        case .boolean:
            specific = "got boolean value"
        case .number:
            specific = "got number"
        case .keyword(let string):
            specific = "got keyword `\(string)`"
        case .symbol(let string):
            specific = "got symbol `\(string)`"
        }
        
        let message = "Expected a top level construct, but \(specific)"
        return ParserError(location: info.sourceLocation, message: message)
    }
    
    func expectedBlockBodyPart(info: ExpectedBlockBodyPartErrorInfo) -> ParserError {
        let specific: String
        switch info.type {
        case .boolean:
            specific = "got boolean value"
        case .number:
            specific = "got number"
        case .keyword(let string):
            specific = "got keyword `\(string)`"
        case .symbol(let string):
            specific = "got symbol `\(string)`"
        case .eof:
            specific = "reached end of the file"
        }
        
        let message = "Expected some block-level construct, but \(specific)"
        return ParserError(location: info.sourceLocation, message: message)
    }
}
