//
//  IR.swift
//  quicklang
//
//  Created by Rob Patterson on 11/13/25.
//

final class FIRModule {
    var nodes: [FIRNode]
    
    init(nodes: [FIRNode]) {
        self.nodes = nodes
    }
}

protocol FIRNode {
    
}

protocol FIRTerminator: FIRNode {
    
}

protocol FIRBasicBlockItem: FIRNode {
    
}

enum FIRType {
    case Int
    case Bool
    case String
    case Void
    
    static func convertFrom(_ type: TypeName) -> Self {
        switch type {
        case .Bool:
            return .Bool
        case .Int:
            return .Int
        case .String:
            return .String
        case .Void:
            return .Void
        case .Arrow(_, let to):
            return convertFrom(to)
        }
    }
}

final class FIRFunction: FIRNode {
    var blocks: [FIRBasicBlock]
    var parameters: [FIRParameter]?
    
    init(blocks: [FIRBasicBlock], parameters: [FIRParameter]? = nil) {
        self.blocks = blocks
        self.parameters = parameters
    }
}

final class FIRParameter {
    var name: String
    var type: FIRType
    
    init(name: String, type: FIRType) {
        self.name = name
        self.type = type
    }
}

final class FIRBasicBlock: FIRNode {
    var label: FIRLabel
    var statements: [FIRBasicBlockItem] = []
    var terminator: FIRTerminator
    
    init(label: FIRLabel, statements: [FIRBasicBlockItem], terminator: FIRTerminator) {
        self.label = label
        self.statements = statements
        self.terminator = terminator
    }
    
    func terminatorIsReturn() -> Bool {
        guard terminator is FIRReturn else {
            return false
        }
        
        return true
    }
    
    class Builder {
        var label: FIRLabel?
        var statements: [FIRBasicBlockItem]?
        var terminator: FIRTerminator?
        
        func build() -> FIRBasicBlock {
            guard let label else { fatalError("Basic block must have a label") }
            guard let terminator else { fatalError("Basic block must have a terminator") }
            
            return .init(
                label: label,
                statements: statements ?? [],
                terminator: terminator
            )
        }
        
        func addStatement(_ statement: FIRBasicBlockItem) {
            if statements == nil {
                statements = []
            }
            
            statements!.append(statement)
        }
    }
}

protocol FIRExpression: FIRNode {
    
}

final class FIRIdentifier: FIRExpression {
    var name: String
    
    init(name: String) {
        self.name = name
    }
}

final class FIRBoolean: FIRExpression {
    var value: Bool
    
    init(value: Bool) {
        self.value = value
    }
}

final class FIRInteger: FIRExpression {
    var value: Int
    
    init(value: Int) {
        self.value = value
    }
}

enum FIROperation {
    case and
    case or
    case not
    case neg
    case plus
    case minus
    case times
    
    static func convert(from op: UnaryOperation.Operator) -> FIROperation {
        switch op {
        case .not:
            return .not
        case .neg:
            return .neg
        }
    }
    
    static func convert(from op: BinaryOperation.Operator) -> FIROperation {
        switch op {
        case .plus:
            return .plus
        case .minus:
            return .minus
        case .times:
            return .times
        case .and:
            return .and
        case .or:
            return .or
        }
    }
}

final class FIRUnaryExpression: FIRExpression {
    var op: FIROperation
    var expr: FIRExpression
    
    init(op: FIROperation, expr: FIRExpression) {
        self.op = op
        self.expr = expr
    }
}

final class FIRBinaryExpression: FIRExpression {
    var op: FIROperation
    var lhs: FIRExpression
    var rhs: FIRExpression
    
    init(op: FIROperation, lhs: FIRExpression, rhs: FIRExpression) {
        self.op = op
        self.lhs = lhs
        self.rhs = rhs
    }
}

final class FIRAssignment: FIRBasicBlockItem {
    var name: String
    var value: FIRExpression
    
    init(name: String, value: FIRExpression) {
        self.name = name
        self.value = value
    }
}

final class FIRConditionalBranch: FIRTerminator {
    var condition: FIRExpression
    var thenBranch: FIRLabel
    var elseBranch: FIRLabel
    
    init(condition: FIRExpression, thenBranch: FIRLabel, elseBranch: FIRLabel) {
        self.condition = condition
        self.thenBranch = thenBranch
        self.elseBranch = elseBranch
    }
}

final class FIRBranch: FIRTerminator {
    var label: FIRLabel
    
    init(label: FIRLabel) {
        self.label = label
    }
}

final class FIRJump: FIRTerminator {
    var label: FIRLabelRepresentable
    
    init(label: FIRLabel) {
        self.label = label
    }
}

protocol FIRLabelRepresentable: FIRNode {
}

final class FIRLabel: FIRLabelRepresentable {
    var name: String
    
    init(name: String) {
        self.name = name
    }
}

final class FIRLabelHole: FIRLabelRepresentable {
    
}

final class FIRReturn: FIRTerminator {
    var value: FIRExpression
    
    init(value: FIRExpression) {
        self.value = value
    }
}

final class FIRFunctionCall: FIRExpression, FIRBasicBlockItem {
    var function: String
    var parameter: [FIRExpression]
    
    init(function: String, parameter: [FIRExpression]) {
        self.function = function
        self.parameter = parameter
    }
}
