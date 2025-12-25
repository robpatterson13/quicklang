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
    
    var value: String {
        switch self {
        case .Boolean(let v, _),
                .Identifier(let v, _),
                .Number(let v, _),
                .Keyword(let v, _),
                .Symbol(let v, _):
            return v
        }
    }
    
    var location: SourceCodeLocation {
        switch self {
        case .Boolean(_, let l),
                .Identifier(_, let l),
                .Number(_, let l),
                .Keyword(_, let l),
                .Symbol(_, let l):
            return l
        }
    }
    
    typealias BindingPower = (Int, Int)
    var bindingPower: BindingPower {
        let op: String
        switch self {
        case .Symbol(let s, _):
            op = s
        default:
            fatalError("Can only call binding power on symbol")
        }
        
        switch op {
        case "&&", "||":
            return (1, 2)
        case "+", "-":
            return (3, 4)
        case "*", "/":
            return (5, 6)
        case "!":
            return (7, 8)
        default:
            fatalError("Binding power of \(op) not yet implemented")
        }
    }
    
    func isOp() -> Bool {
        switch self {
        case .Symbol(let s, _):
            return Self.isSymbolOp(s)
        default:
            return false
        }
    }
    
    func isUnaryOp() -> Bool {
        switch self {
        case .NOT: // add minus
            return true
        default:
            return false
        }
    }
    
    func isBinaryOp() -> Bool {
        switch self {
        case .PLUS,
                .MINUS,
                .STAR,
                .AND,
                .OR:
            return true
        default:
            return false
        }
    }
    
    private static func isSymbolOp(_ symbol: String) -> Bool {
        switch symbol {
        case Token.PLUS.value,
            Token.MINUS.value,
            Token.STAR.value,
            Token.AND.value,
            Token.OR.value,
            Token.NOT.value:
            return true
        default:
            return false
        }
    }
}

extension Token {
    
    static let AT: Token = .buildSymbol("@")
    
    static let PLUS: Token = .buildSymbol("+")
    static let MINUS: Token = .buildSymbol("-")
    static let STAR: Token = .buildSymbol("*")
    
    static let AND: Token = .buildSymbol("&&")
    static let OR: Token = .buildSymbol("||")
    static let NOT: Token = .buildSymbol("!")
    
    static let COLON: Token = .buildSymbol(":")
    static let SEMICOLON: Token = .buildSymbol(";")
    static let LPAREN: Token = .buildSymbol("(")
    static let RPAREN: Token = .buildSymbol(")")
    
    static let LBRACE: Token = .buildSymbol("{")
    static let RBRACE: Token = .buildSymbol("}")
    
    static let ARROW: Token = .buildSymbol("->")
    static let COMMA: Token = .buildSymbol(",")
    static let EQUAL: Token = .buildSymbol("=")
    
    static let NEWLINE: Token = .buildSymbol("\n")
    
    private static func buildSymbol(_ symbol: String) -> Token {
        return .Symbol(symbol, location: .dummySourceCodeLocation)
    }
    
}

extension Token {
    
    static let IF: Token = .buildKeyword("if")
    static let ELSE: Token = .buildKeyword("else")
    
    static let RETURN: Token = .buildKeyword("return")
    
    static let FUNC: Token = .buildKeyword("func")
    
    static let LET: Token = .buildKeyword("let")
    static let VAR: Token = .buildKeyword("var")
    
    static let INTTYPE: Token = .buildKeyword("Int")
    static let BOOLTYPE: Token = .buildKeyword("Bool")
    static let STRINGTYPE: Token = .buildKeyword("String")
    static let VOIDTYPE: Token = .buildKeyword("Void")
    
    private static func buildKeyword(_ keyword: String) -> Token {
        return .Keyword(keyword, location: .dummySourceCodeLocation)
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
    
    typealias StartLineColumnLocation = (Int, Int)
    var startLineColumnLocation: StartLineColumnLocation {
        return (startLine, startColumn)
    }
    
    fileprivate static let dummySourceCodeLocation = SourceCodeLocation(startLine: -1,
                                                                        startColumn: -1,
                                                                        endLine: -1,
                                                                        endColumn: -1)
    
    static let beginningOfFile = Self.init(startLine: 0, startColumn: 0, endLine: 0, endColumn: 0)
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

// Hashable conformance consistent with the custom == above (ignores location)
extension Token: Hashable {
    func hash(into hasher: inout Hasher) {
        switch self {
        case .Identifier(let s, _):
            hasher.combine(0)
            hasher.combine(s)
        case .Keyword(let s, _):
            hasher.combine(1)
            hasher.combine(s)
        case .Number(let s, _):
            hasher.combine(2)
            hasher.combine(s)
        case .Boolean(let s, _):
            hasher.combine(3)
            hasher.combine(s)
        case .Symbol(let s, _):
            hasher.combine(4)
            hasher.combine(s)
        }
    }
}
