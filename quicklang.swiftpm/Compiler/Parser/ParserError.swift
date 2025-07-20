//
//  ParserError.swift
//  quicklang
//
//  Created by Rob Patterson on 7/19/25.
//

struct ParseError: Error {
    
    let value: String?
    let errorType: ParseErrorType
    let location: SourceCodeLocation
}

extension ParseError {
    
    func getDescription(from manager: ParserErrorMessageManager) -> String {
        errorType.getMessage(from: manager)(self)
    }
}

enum ParseErrorType {
    
    case expectedTypeIdentifier
    case expectedParameterType
    case expectedIdentifier
    
    case expectedFunctionApplication
    case expectedFunctionArgument
    
    case unexpectedBoolean
    case unexpectedNumber
    case unexpectedString
    case unexpectedSymbol
    case unexpectedKeyword
    
    case internalParserError
    
    case expectedToken
    
    case expectedClosingBrace
    case expectedClosingParen
    
    case expectedSemicolonToEndFunctionCall
    
    case expectedOperator
    case expectedExpression
    case expectedAtomic
    
    func getMessage(from manager: ParserErrorMessageManager) -> (ParseError) -> String {
        
        switch self {
        
        // MARK: Unexpected token dispatch
        case .unexpectedBoolean: manager.unexpectedBoolean
        case .unexpectedNumber: manager.unexpectedNumber
        case .unexpectedSymbol: manager.unexpectedSymbol
        case .unexpectedKeyword: manager.unexpectedKeyword
        }
    }
}

class ParserErrorManager {
    
    private var errors: [ParseError] = []
    private var errorMessageManager: ParserErrorMessageManager
    
    init(errorMessageManager: ParserErrorMessageManager) {
        self.errorMessageManager = errorMessageManager
    }
    
    func add(_ error: ParseError) {
        errors.append(error)
    }
}

protocol ParserErrorMessageManager {
    
    // MARK: Unexpected token messages
    func unexpectedBoolean(error: ParseError) -> String
    func unexpectedNumber(error: ParseError) -> String
    func unexpectedSymbol(error: ParseError) -> String
    func unexpectedKeyword(error: ParseError) -> String
    func unexpectedString(error: ParseError) -> String
    
    // MARK: Expected identifier messages
    func expectedTypeIdentifier(error: ParseError) -> String
    func expectedParameterType(error: ParseError) -> String
    func expectedIdentifier(error: ParseError) -> String

    // MARK: Expected function-related messages
    func expectedFunctionApplication(error: ParseError) -> String
    func expectedFunctionArgument(error: ParseError) -> String
    
    // MARK: Internal error messages
    func internalParserError(error: ParseError) -> String
    
    // MARK: Expected token messages
    func expectedToken(error: ParseError) -> String
    
    // MARK: Expected punctuation messages
    func expectedClosingBrace(error: ParseError) -> String
    func expectedClosingParen(error: ParseError) -> String
    
    // MARK: Expected function-related grammar messages
    func expectedSemicolonToEndFunctionCall(error: ParseError) -> String
    
    // MARK: Expected grammar messages
    func expectedOperator(error: ParseError) -> String
    func expectedExpression(error: ParseError) -> String
    func expectedAtomic(error: ParseError) -> String
    
}

class DefaultParserErrorMessageManager: ParserErrorMessageManager {
    
}

// MARK: Unexpected token messages
extension DefaultParserErrorMessageManager {
    
    func unexpectedBoolean(error: ParseError) -> String {
        let (line, column) = error.location.startLineColumnLocation()
        return "Unexpected boolean \"\(error.value!)\" at line \(line), column \(column)"
    }
    
    func unexpectedNumber(error: ParseError) -> String {
        let (line, column) = error.location.startLineColumnLocation()
        return "Unexpected number \"\(error.value!)\" at line \(line), column \(column)"
    }
    
    func unexpectedKeyword(error: ParseError) -> String {
        let (line, column) = error.location.startLineColumnLocation()
        return "Unexpected keyword \"\(error.value!)\" at line \(line), column \(column)"
    }
    
    func unexpectedSymbol(error: ParseError) -> String {
        let (line, column) = error.location.startLineColumnLocation()
        return "Unexpected symbol \"\(error.value!)\" at line \(line), column \(column)"
    }
    
}
