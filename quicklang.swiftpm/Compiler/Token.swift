//
//  Token.swift
//  swift-student-challenge-2025
//
//  Created by Rob Patterson on 2/8/25.
//

enum Token {
    
    case Identifier(String, location: SourceCodeLocation)
    case Keyword(String, location: SourceCodeLocation)
    case Number(String, location: SourceCodeLocation)
    case Boolean(String, location: SourceCodeLocation)
    case Symbol(String, location: SourceCodeLocation)
}

extension Token {
    
    static func getSourceCodeLocation(of token: Token) -> SourceCodeLocation {
        switch token {
        case .Boolean(_, let l),
            .Identifier(_, let l),
            .Number(_, let l),
            .Keyword(_, let l),
            .Symbol(_, let l):
            return l
        }
    }
}

struct SourceCodeLocationBuilder {
    
    var startLine: Int?
    var startColumn: Int?
    var endLine: Int?
    var endColumn: Int?
    
    func build() -> SourceCodeLocation {
        guard let startLine = startLine, let startColumn = startColumn,
              let endLine = endLine, let endColumn = endColumn else {
            fatalError("Must set all properties")
        }
        
        return SourceCodeLocation(startLine: startLine,
                                  startColumn: startColumn,
                                  endLine: endLine,
                                  endColumn: endColumn)
    }
}

struct SourceCodeLocation {
    
    let startLine: Int
    let startColumn: Int
    let endLine: Int
    let endColumn: Int
    
    static let dummySourceCodeLocation = SourceCodeLocation(startLine: -1,
                                                            startColumn: -1,
                                                            endLine: -1,
                                                            endColumn: -1)
}

func ==(a: Token, b: Token) -> Bool {
    switch (a, b) {
    case (.Identifier(let aId, _), .Identifier(let bId, _)):
        return aId == bId
    case (.Keyword(let aKw, _), .Keyword(let bKw, _)):
        return aKw == bKw
    case (.Number(let aN, _), .Number(let bN, _)):
        return aN == bN
    case (.Boolean(let aB, _), .Boolean(let bB, _)):
        return aB == bB
    case (.Symbol(let aS, _), .Symbol(let bS, _)):
        return aS == bS
    default:
        return false
    }
}

func !=(a: Token, b: Token) -> Bool {
    return !(a == b)
}
