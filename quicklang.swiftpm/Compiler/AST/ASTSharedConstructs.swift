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
}

enum BinaryOperator {
    case plus
    case minus
    case times
    
    case and
    case or
}
