//
//  AST.swift
//  quicklang
//
//  Created by Rob Patterson on 2/11/25.
//

import Foundation

protocol ASTNodeIncompletable {
    var isIncomplete: Bool { get }
    var anyIncomplete: Bool { get }
    static var incomplete: Self { get }
}

protocol ASTNode: Hashable, ASTNodeIncompletable {
    var id: UUID { get }
    func acceptVisitor<V: ASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult
}

extension ASTNode {
    func acceptVisitor<V: ASTVisitor>(_ visitor: V) -> V.VisitorResult where V.VisitorInfo == Void {
        acceptVisitor(visitor, ())
    }
}

extension ASTNode {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension ASTNode {
    var anyIncomplete: Bool {
        if isIncomplete { return true }
        return Self._containsIncomplete(in: self)
    }
    
    private static func _containsIncomplete(in value: Any) -> Bool {
        
        if let node = value as? any ASTNode {
            if node.isIncomplete { return true }
        }
        
        let mirror = Mirror(reflecting: value)
        
        switch mirror.displayStyle {
        case .optional:
            if let child = mirror.children.first {
                return _containsIncomplete(in: child.value)
            }
            return false
            
        case .collection, .set, .dictionary, .tuple, .struct, .class, .enum:
            if _hasTrueIsIncompleteFlag(mirror) {
                return true
            }
            
            for child in mirror.children {
                if _containsIncomplete(in: child.value) {
                    return true
                }
            }
            return false
            
        case .none:
            return false
            
        default:
            return false
        }
    }
    
    private static func _hasTrueIsIncompleteFlag(_ mirror: Mirror) -> Bool {
        for (labelOpt, value) in mirror.children {
            if let label = labelOpt, label == "isIncomplete", let flag = value as? Bool, flag == true {
                return true
            }
        }
        return false
    }
}

final class TopLevel {
    var sections: [any TopLevelNode]
    
    init(sections: [any TopLevelNode]) {
        self.sections = sections
    }
}

protocol BlockLevelNode: ASTNode {
    
}

final class BlockLevelNodeIncomplete: BlockLevelNode {
    let id = UUID()
    var isIncomplete: Bool
    
    static var incomplete: BlockLevelNodeIncomplete {
        BlockLevelNodeIncomplete()
    }
    
    private init() {
        self.isIncomplete = true
    }
    
    func acceptVisitor<V: ASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        fatalError("Attempted to visit incomplete block-level node")
    }
}

protocol TopLevelNode: BlockLevelNode { }

final class TopLevelNodeIncomplete: TopLevelNode {
    let id = UUID()
    static var incomplete: TopLevelNodeIncomplete {
        TopLevelNodeIncomplete()
    }
    
    private init() {
        self.isIncomplete = true
    }
    
    var isIncomplete: Bool
    
    func acceptVisitor<V: ASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        fatalError("Attempted to visit incomplete top-level node")
    }
}

extension TopLevelNode {
    static var incomplete: FuncDefinition {
        FuncDefinition.incomplete
    }
}

protocol ExpressionNode: ASTNode {
    func acceptTypeQuery(_ context: ASTContext)
}

protocol DefinitionNode: TopLevelNode {
    var name: String { get }
    var type: TypeName? { get }
    var expression: any ExpressionNode { get }
}

protocol StatementNode: BlockLevelNode { }

final class IdentifierExpression: ExpressionNode, TopLevelNode {
    let id = UUID()
    let name: String
    
    let isIncomplete: Bool
    
    static var incomplete: IdentifierExpression {
        return IdentifierExpression()
    }
    
    private init() {
        self.name = ""
        self.isIncomplete = true
    }
    
    init(name: String) {
        self.name = name
        self.isIncomplete = false
    }
    
    func acceptVisitor<V: ASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitIdentifierExpression(self, info)
    }
    
    func acceptTypeQuery(_ context: ASTContext) {
        context.queryTypeOfIdentifierExpression(self)
    }
}

final class BooleanExpression: ExpressionNode {
    let id = UUID()
    let value: Bool
    
    let isIncomplete: Bool
    
    static var incomplete: BooleanExpression {
        return BooleanExpression()
    }
    
    private init() {
        self.value = false
        self.isIncomplete = true
    }
    
    init(value: Bool) {
        self.value = value
        self.isIncomplete = false
    }
    
    func acceptVisitor<V: ASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitBooleanExpression(self, info)
    }
    
    func acceptTypeQuery(_ context: ASTContext) {
        context.queryTypeOfBooleanExpression(self)
    }
}

final class NumberExpression: ExpressionNode {
    let id = UUID()
    let value: Int
    
    let isIncomplete: Bool
    
    static var incomplete: NumberExpression {
        return NumberExpression()
    }
    
    private init() {
        self.value = 0
        self.isIncomplete = true
    }
    
    init(value: Int) {
        self.value = value
        self.isIncomplete = false
    }
    
    func acceptVisitor<V: ASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitNumberExpression(self, info)
    }
    
    func acceptTypeQuery(_ context: ASTContext) {
        context.queryTypeOfNumberExpression(self)
    }
}

final class UnaryOperation: ExpressionNode {
    let id = UUID()
    
    let op: Operator
    enum Operator {
        case not
        case neg
    }
    let expression: any ExpressionNode
    
    let isIncomplete: Bool
    
    static var incomplete: UnaryOperation {
        return UnaryOperation()
    }
    
    private init() {
        self.op = .not
        self.expression = IdentifierExpression.incomplete
        self.isIncomplete = true
    }
    
    init(op: Operator, expression: any ExpressionNode) {
        self.op = op
        self.expression = expression
        self.isIncomplete = false
    }
    
    func acceptVisitor<V: ASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitUnaryOperation(self, info)
    }
    
    func acceptTypeQuery(_ context: ASTContext) {
        context.queryTypeOfUnaryOperation(self)
    }
}

final class BinaryOperation: ExpressionNode {
    let id = UUID()
    let op: Operator
    enum Operator {
        case plus
        case minus
        case times
        
        case and
        case or
    }
    let lhs, rhs: any ExpressionNode
    
    let isIncomplete: Bool
    
    static var incomplete: BinaryOperation {
        return BinaryOperation()
    }
    
    private init() {
        self.op = .plus
        self.lhs = IdentifierExpression.incomplete
        self.rhs = IdentifierExpression.incomplete
        self.isIncomplete = true
    }
    
    init(op: Operator, lhs: any ExpressionNode, rhs: any ExpressionNode) {
        self.op = op
        self.lhs = lhs
        self.rhs = rhs
        self.isIncomplete = false
    }
    
    func acceptVisitor<V: ASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitBinaryOperation(self, info)
    }
    
    func acceptTypeQuery(_ context: ASTContext) {
        context.queryTypeOfBinaryOperation(self)
    }
}

final class LetDefinition: DefinitionNode  {
    let id = UUID()
    let name: String
    let type: TypeName?
    let expression: any ExpressionNode
    
    let isIncomplete: Bool
    
    static var incomplete: LetDefinition {
        return LetDefinition()
    }
    
    private init() {
        self.name = ""
        self.type = nil
        self.expression = IdentifierExpression.incomplete
        self.isIncomplete = true
    }
    
    init(name: String, type: TypeName, expression: any ExpressionNode) {
        self.name = name
        self.type = type
        self.expression = expression
        self.isIncomplete = false
    }
    
    func acceptVisitor<V: ASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitLetDefinition(self, info)
    }
}

final class VarDefinition: DefinitionNode {
    let id = UUID()
    let name: String
    let type: TypeName?
    let expression: any ExpressionNode
    
    let isIncomplete: Bool
    
    static var incomplete: VarDefinition {
        return VarDefinition()
    }
    
    private init() {
        self.name = ""
        self.type = nil
        self.expression = IdentifierExpression.incomplete
        self.isIncomplete = true
    }
    
    init(name: String, type: TypeName, expression: any ExpressionNode) {
        self.name = name
        self.type = type
        self.expression = expression
        self.isIncomplete = false
    }
    
    func acceptVisitor<V: ASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitVarDefinition(self, info)
    }
}

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
}

final class FuncDefinition: TopLevelNode {
    
    struct Parameter {
        let name: String
        let type: TypeName
        let isIncomplete: Bool
        static var incomplete: Parameter {
            return Parameter()
        }
        
        private init() {
            self.name = ""
            self.type = .Int
            self.isIncomplete = true
        }
        
        init(name: String, type: TypeName) {
            self.name = name
            self.type = type
            self.isIncomplete = false
        }
    }
    
    let id = UUID()
    let name: String
    let type: TypeName
    let parameters: [Parameter]
    let body: [any BlockLevelNode]
    
    let isIncomplete: Bool
    
    static var incomplete: FuncDefinition {
        return FuncDefinition()
    }
    
    private init() {
        self.name = ""
        self.type = .Int
        self.parameters = []
        self.body = []
        self.isIncomplete = true
    }
    
    init(name: String, type: TypeName, parameters: [Parameter], body: [any BlockLevelNode]) {
        self.name = name
        self.type = type
        self.parameters = parameters
        self.body = body
        self.isIncomplete = false
    }
    
    func acceptVisitor<V: ASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitFuncDefinition(self, info)
    }
}

final class FuncApplication: ExpressionNode, TopLevelNode {
    let id = UUID()
    let name: String
    let arguments: [any ExpressionNode]
    
    let isIncomplete: Bool
    
    static var incomplete: FuncApplication {
        return FuncApplication()
    }
    
    private init() {
        self.name = ""
        self.arguments = []
        self.isIncomplete = true
    }
    
    init(name: String, arguments: [any ExpressionNode]) {
        self.name = name
        self.arguments = arguments
        self.isIncomplete = false
    }
    
    func acceptVisitor<V: ASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitFuncApplication(self, info)
    }
    
    func acceptTypeQuery(_ context: ASTContext) {
        context.queryTypeOfFuncApplication(self)
    }
}

final class IfStatement: StatementNode, BlockLevelNode {
    let id = UUID()
    let condition: any ExpressionNode
    let thenBranch: [any BlockLevelNode]
    let elseBranch: [any BlockLevelNode]?
    
    let isIncomplete: Bool
    
    static var incomplete: IfStatement {
        return IfStatement()
    }
    
    private init() {
        self.condition = IdentifierExpression.incomplete
        self.thenBranch = []
        self.elseBranch = nil
        self.isIncomplete = true
    }
    
    init(condition: any ExpressionNode, thenBranch: [any BlockLevelNode], elseBranch: [any BlockLevelNode]?) {
        self.condition = condition
        self.thenBranch = thenBranch
        self.elseBranch = elseBranch
        self.isIncomplete = false
    }
    
    func acceptVisitor<V: ASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitIfStatement(self, info)
    }
}

final class ReturnStatement: StatementNode, BlockLevelNode {
    let id = UUID()
    let expression: any ExpressionNode
    
    let isIncomplete: Bool
    static var incomplete: ReturnStatement {
        return ReturnStatement()
    }
    
    private init() {
        self.expression = IdentifierExpression.incomplete
        self.isIncomplete = true
    }
    
    init(expression: any ExpressionNode) {
        self.expression = expression
        self.isIncomplete = false
    }
    
    func acceptVisitor<V: ASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitReturnStatement(self, info)
    }
}

final class AssignmentStatement: StatementNode, TopLevelNode {
    let id = UUID()
    let name: String
    let expression: any ExpressionNode
    
    var isIncomplete: Bool
    static var incomplete: AssignmentStatement {
        return AssignmentStatement()
    }
    
    init(name: String, expression: any ExpressionNode) {
        self.name = name
        self.expression = expression
        self.isIncomplete = false
    }
    
    private init() {
        self.name = ""
        self.expression = IdentifierExpression.incomplete
        self.isIncomplete = true
    }
    
    func acceptVisitor<V: ASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitAssignmentStatement(self, info)
    }
    
}

