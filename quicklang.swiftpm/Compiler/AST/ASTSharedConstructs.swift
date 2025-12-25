//
//  ASTOperations.swift
//  quicklang
//
//  Created by Rob Patterson on 12/14/25.
//

enum TypeName: Equatable {
    case Bool
    case Int
    case String
    case Void
    indirect case Arrow(from: [TypeName], to: TypeName)
    
    static func == (lhs: TypeName, rhs: TypeName) -> Bool {
        switch (lhs, rhs) {
        case (.Bool, .Bool),
            (.Int, .Int),
            (.String, .String),
            (.Void, .Void):
            return true
        case (.Arrow(let lhsFrom, let lhsTo), .Arrow(let rhsFrom, let rhsTo)):
            return (lhsFrom == rhsFrom) && (lhsTo == rhsTo)
        default:
            return false
        }
    }
    
    var returnType: TypeName? {
        switch self {
        case .Arrow(from: _, to: let to):
            return to
        default:
            return nil
        }
    }
    
    var paramTypes: [TypeName]? {
        switch self {
        case .Arrow(from: let from, to: _):
            return from
        default:
            return nil
        }
    }
}

enum UnaryOperator {
    case not
    case neg
    
    var isBoolean: Bool {
        return self == .not
    }
    
    static func from(token: Token) -> UnaryOperator? {
        switch token {
        case .NOT: return .not
        case .MINUS: return .neg
        default:
            return nil
        }
    }
}

enum BinaryOperator {
    case plus
    case minus
    case times
    
    case and
    case or
    
    var isBoolean: Bool {
        switch self {
        case .and, .or:
            return true
        default:
            return false
        }
    }
    
    static func from(token: Token) -> BinaryOperator? {
        switch token {
        case .AND: return .and
        case .OR: return .or
        case .PLUS: return .plus
        case .MINUS: return .minus
        case .STAR: return .times
        default:
            return nil
        }
    }
}
