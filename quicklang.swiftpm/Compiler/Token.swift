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
    
    static func getValue(of token: Token) -> String {
        switch token {
        case .Boolean(let v, _),
            .Identifier(let v, _),
            .Number(let v, _),
            .Keyword(let v, _),
            .Symbol(let v, _):
            return v
        }
    }
    
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

extension Token {
    
    static func isAtomic(_ token: Token) -> Bool {
        switch token {
        case .Boolean, .Identifier, .Number:
            return true
        default:
            return false
        }
    }
    
    static func isOp(_ token: Token) -> Bool {
        switch token {
        case let .Symbol(sym, _):
            return ["!", "+", "-", "*", "&&", "||"].contains { $0 == sym }
        default:
            return false
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
    
    func startLineColumnLocation() -> (Int, Int) {
        return (startLine, startColumn)
    }
    
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
