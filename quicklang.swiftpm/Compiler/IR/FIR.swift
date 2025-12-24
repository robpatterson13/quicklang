//
//  FIR.swift
//  quicklang
//
//  Created by Rob Patterson on 11/13/25.
//

final class FIRModule {
    var nodes: [FIRFunction]
    
    init(nodes: [FIRFunction]) {
        self.nodes = nodes
    }
}

protocol FIRNode {
    func copy() -> Self
    func acceptVisitor<V: FIRVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult
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

final class FIRFunction {
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

final class FIRBasicBlock {
    var label: FIRLabel
    var statements: [FIRBasicBlockItem] = []
    var terminator: FIRTerminator
    var unreachableTerminators: [FIRTerminator] = []
    var parameter: FIRParameter? = nil
    
    init(label: FIRLabel, statements: [FIRBasicBlockItem], terminator: FIRTerminator, parameter: FIRParameter? = nil) {
        self.label = label
        self.statements = statements
        self.terminator = terminator
        self.parameter = parameter
    }
    
    func terminatorIsReturn() -> Bool {
        terminator is FIRReturn
    }
    
    func addUnreachableTerminator(_ terminator: FIRTerminator) {
        unreachableTerminators.append(terminator)
    }
}

protocol FIRExpression: FIRNode {
    
}

final class FIREmptyTuple: FIRExpression {
    
    func acceptVisitor<V>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult where V : FIRVisitor {
        visitor.visitFIREmptyTuple(self, info)
    }
    
    func copy() -> Self {
        .init()
    }
    
}

final class FIRIdentifier: FIRExpression {
    var name: String
    
    init(name: String) {
        self.name = name
    }
    
    func acceptVisitor<V: FIRVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitFIRIdentifier(self, info)
    }
    
    func copy() -> Self {
        .init(name: name)
    }
}

final class FIRBoolean: FIRExpression {
    var value: Bool
    
    init(value: Bool) {
        self.value = value
    }
    
    func acceptVisitor<V: FIRVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitFIRBoolean(self, info)
    }
    
    func copy() -> Self {
        .init(value: value)
    }
}

final class FIRInteger: FIRExpression {
    var value: Int
    
    init(value: Int) {
        self.value = value
    }
    
    func acceptVisitor<V: FIRVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitFIRInteger(self, info)
    }
    
    func copy() -> Self {
        .init(value: value)
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
    
    static func convert(from op: UnaryOperator) -> FIROperation {
        switch op {
        case .not:
            return .not
        case .neg:
            return .neg
        }
    }
    
    static func convert(from op: BinaryOperator) -> FIROperation {
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
    
    func acceptVisitor<V: FIRVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitFIRUnaryExpression(self, info)
    }
    
    func copy() -> Self {
        .init(op: op, expr: expr)
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
    
    func acceptVisitor<V: FIRVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitFIRBinaryExpression(self, info)
    }
    
    func copy() -> Self {
        .init(op: op, lhs: lhs, rhs: rhs)
    }
}

final class FIRAssignment: FIRBasicBlockItem {
    var name: String
    var value: FIRExpression
    
    init(name: String, value: FIRExpression) {
        self.name = name
        self.value = value
    }
    
    func acceptVisitor<V: FIRVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitFIRAssignment(self, info)
    }
    
    func copy() -> Self {
        .init(name: name, value: value)
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
    
    func copyFrom(_ branch: FIRConditionalBranch) {
        self.condition = branch.condition
        self.thenBranch = branch.thenBranch
        self.elseBranch = branch.elseBranch
    }
    
    func acceptVisitor<V: FIRVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitFIRConditionalBranch(self, info)
    }
    
    func copy() -> Self {
        .init(condition: condition, thenBranch: thenBranch, elseBranch: elseBranch)
    }
}

final class FIRBranch: FIRTerminator {
    var label: FIRLabel
    // argument
    var value: FIRExpression?
    
    init(label: FIRLabel, value: FIRExpression? = nil) {
        self.label = label
        self.value = value
    }
    
    func acceptVisitor<V: FIRVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitFIRBranch(self, info)
    }
    
    func copy() -> Self {
        .init(label: label, value: value)
    }
}

final class FIRJump: FIRTerminator {
    var label: FIRLabel
    
    init(label: FIRLabel) {
        self.label = label
    }
    
    func acceptVisitor<V: FIRVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitFIRJump(self, info)
    }
    
    func copy() -> Self {
        .init(label: label)
    }
}

protocol FIRLabelRepresentable: FIRNode {
}

final class FIRLabel: FIRLabelRepresentable {
    var name: String
    
    init(name: String) {
        self.name = name
    }
    
    // had an issue where the labels weren't being retained
    // copy lets us make a new one that the block can own
    // this keeps it from being collected during parsing the
    // basic blocks in ConvertToFIR
    func copy() -> Self {
        .init(name: name)
    }
    
    func acceptVisitor<V: FIRVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitFIRLabel(self, info)
    }
}

final class FIRLabelHole: FIRLabelRepresentable {
    
    func acceptVisitor<V>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult where V : FIRVisitor {
        fatalError("Cannot visit label hole")
    }
    
    func copy() -> Self {
        .init()
    }
}

final class FIRReturn: FIRTerminator {
    var value: FIRExpression
    
    init(value: FIRExpression) {
        self.value = value
    }
    
    func acceptVisitor<V: FIRVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitFIRReturn(self, info)
    }
    
    func copy() -> Self {
        .init(value: value)
    }
}

final class FIRFunctionCall: FIRExpression, FIRBasicBlockItem {
    var function: String
    var parameter: [FIRExpression]
    
    init(function: String, parameter: [FIRExpression]) {
        self.function = function
        self.parameter = parameter
    }
    
    func acceptVisitor<V: FIRVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitFIRFunctionCall(self, info)
    }
    
    func copy() -> Self {
        .init(function: function, parameter: parameter)
    }
}
