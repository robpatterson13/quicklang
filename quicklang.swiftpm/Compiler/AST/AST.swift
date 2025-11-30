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
    func acceptVisitor(_ visitor: any ASTVisitor)
    
    func acceptUpwardTransformer<T: ASTUpwardTransformer>(_ transformer: T, _ finished: @escaping T.OnTransformEnd<Self>)
    
    func acceptDownwardTransformer<T: ASTDownwardTransformer>(_ transformer: T, _ info: T.TransformationInfo)
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

struct TopLevel {
    var sections: [any TopLevelNode]
}

protocol BlockLevelNode: ASTNode {
    
}

struct BlockLevelNodeIncomplete: BlockLevelNode {
    let id = UUID()
    var isIncomplete: Bool
    
    static var incomplete: BlockLevelNodeIncomplete {
        BlockLevelNodeIncomplete()
    }
    
    private init() {
        self.isIncomplete = true
    }
    
    func acceptVisitor(_ visitor: any ASTVisitor) {
        fatalError("Attempted to visit incomplete block-level node")
    }
    
    func acceptUpwardTransformer<T: ASTUpwardTransformer>(_ transformer: T, _ finished: T.OnTransformEnd<Self>) {
        fatalError("Attempted to transform incomplete block-level node")
    }
    
    func acceptDownwardTransformer<T: ASTDownwardTransformer>(_ transformer: T, _ info: T.TransformationInfo) {
        fatalError("Attempted to transform incomplete block-level node")
    }
}

protocol TopLevelNode: BlockLevelNode { }

struct TopLevelNodeIncomplete: TopLevelNode {
    let id = UUID()
    static var incomplete: TopLevelNodeIncomplete {
        TopLevelNodeIncomplete()
    }
    
    private init() {
        self.isIncomplete = true
    }
    
    var isIncomplete: Bool
    
    func acceptVisitor(_ visitor: any ASTVisitor) {
        fatalError("Attempted to visit incomplete top-level node")
    }
    
    func acceptUpwardTransformer<T: ASTUpwardTransformer>(_ transformer: T, _ finished: T.OnTransformEnd<Self>) {
        fatalError("Attempted to transform incomplete top-level node")
    }
    
    func acceptDownwardTransformer<T: ASTDownwardTransformer>(_ transformer: T, _ info: T.TransformationInfo) {
        fatalError("Attempted to transform incomplete top-level node")
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

struct IdentifierExpression: ExpressionNode, TopLevelNode {
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
    
    func acceptVisitor(_ visitor: any ASTVisitor) {
        visitor.visitIdentifierExpression(self)
    }
    
    func acceptTypeQuery(_ context: ASTContext) {
        context.queryTypeOfIdentifierExpression(self)
    }
    
    func acceptUpwardTransformer<T: ASTUpwardTransformer>(
        _ transformer: T,
        _ finished: @escaping T.OnTransformEnd<IdentifierExpression>
    ) {
        transformer.visitIdentifierExpression(self, finished)
    }
    
    func acceptDownwardTransformer<T: ASTDownwardTransformer>(
        _ transformer: T,
        _ info: T.TransformationInfo
    ) {
        transformer.visitIdentifierExpression(self, info)
    }
}

struct BooleanExpression: ExpressionNode {
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
    
    func acceptVisitor(_ visitor: any ASTVisitor) {
        visitor.visitBooleanExpression(self)
    }
    
    func acceptTypeQuery(_ context: ASTContext) {
        context.queryTypeOfBooleanExpression(self)
    }
    
    func acceptUpwardTransformer<T: ASTUpwardTransformer>(
        _ transformer: T,
        _ finished: @escaping T.OnTransformEnd<BooleanExpression>
    ) {
        transformer.visitBooleanExpression(self, finished)
    }
    
    func acceptDownwardTransformer<T: ASTDownwardTransformer>(
        _ transformer: T,
        _ info: T.TransformationInfo
    ) {
        transformer.visitBooleanExpression(self, info)
    }
}

struct NumberExpression: ExpressionNode {
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
    
    func acceptVisitor(_ visitor: any ASTVisitor) {
        visitor.visitNumberExpression(self)
    }
    
    func acceptTypeQuery(_ context: ASTContext) {
        context.queryTypeOfNumberExpression(self)
    }
    
    func acceptUpwardTransformer<T: ASTUpwardTransformer>(
        _ transformer: T,
        _ finished: @escaping T.OnTransformEnd<NumberExpression>
    ) {
        transformer.visitNumberExpression(self, finished)
    }
    
    func acceptDownwardTransformer<T: ASTDownwardTransformer>(
        _ transformer: T,
        _ info: T.TransformationInfo
    ) {
        transformer.visitNumberExpression(self, info)
    }
}

struct UnaryOperation: ExpressionNode {
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
    
    func acceptVisitor(_ visitor: any ASTVisitor) {
        visitor.visitUnaryOperation(self)
    }
    
    func acceptTypeQuery(_ context: ASTContext) {
        context.queryTypeOfUnaryOperation(self)
    }
    
    func acceptUpwardTransformer<T: ASTUpwardTransformer>(
        _ transformer: T,
        _ finished: @escaping T.OnTransformEnd<UnaryOperation>
    ) {
        transformer.visitUnaryOperation(self, finished)
    }
    
    func acceptDownwardTransformer<T: ASTDownwardTransformer>(
        _ transformer: T,
        _ info: T.TransformationInfo
    ) {
        transformer.visitUnaryOperation(self, info)
    }
}

struct BinaryOperation: ExpressionNode {
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
    
    func acceptVisitor(_ visitor: any ASTVisitor) {
        visitor.visitBinaryOperation(self)
    }
    
    func acceptTypeQuery(_ context: ASTContext) {
        context.queryTypeOfBinaryOperation(self)
    }
    
    func acceptUpwardTransformer<T: ASTUpwardTransformer>(
        _ transformer: T,
        _ finished: @escaping T.OnTransformEnd<BinaryOperation>
    ) {
        transformer.visitBinaryOperation(self, finished)
    }
    
    func acceptDownwardTransformer<T: ASTDownwardTransformer>(
        _ transformer: T,
        _ info: T.TransformationInfo
    ) {
        transformer.visitBinaryOperation(self, info)
    }
}

struct LetDefinition: DefinitionNode  {
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
    
    func acceptVisitor(_ visitor: any ASTVisitor) {
        visitor.visitLetDefinition(self)
    }
    
    func acceptUpwardTransformer<T: ASTUpwardTransformer>(
        _ transformer: T,
        _ finished: @escaping T.OnTransformEnd<LetDefinition>
    ) {
        transformer.visitLetDefinition(self, finished)
    }
    
    func acceptDownwardTransformer<T: ASTDownwardTransformer>(
        _ transformer: T,
        _ info: T.TransformationInfo
    ) {
        transformer.visitLetDefinition(self, info)
    }
}

struct VarDefinition: DefinitionNode {
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
    
    func acceptVisitor(_ visitor: any ASTVisitor) {
        visitor.visitVarDefinition(self)
    }
    
    func acceptUpwardTransformer<T: ASTUpwardTransformer>(
        _ transformer: T,
        _ finished: @escaping T.OnTransformEnd<VarDefinition>
    ) {
        transformer.visitVarDefinition(self, finished)
    }
    
    func acceptDownwardTransformer<T: ASTDownwardTransformer>(
        _ transformer: T,
        _ info: T.TransformationInfo
    ) {
        transformer.visitVarDefinition(self, info)
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

struct FuncDefinition: TopLevelNode {
    
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
    
    func acceptVisitor(_ visitor: any ASTVisitor) {
        visitor.visitFuncDefinition(self)
    }
    
    func acceptUpwardTransformer<T: ASTUpwardTransformer>(
        _ transformer: T,
        _ finished: @escaping T.OnTransformEnd<FuncDefinition>
    ) {
        transformer.visitFuncDefinition(self, finished)
    }
    
    func acceptDownwardTransformer<T: ASTDownwardTransformer>(
        _ transformer: T,
        _ info: T.TransformationInfo
    ) {
        transformer.visitFuncDefinition(self, info)
    }
}

struct FuncApplication: ExpressionNode, TopLevelNode {
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
    
    func acceptVisitor(_ visitor: any ASTVisitor) {
        visitor.visitFuncApplication(self)
    }
    
    func acceptTypeQuery(_ context: ASTContext) {
        context.queryTypeOfFuncApplication(self)
    }
    
    func acceptUpwardTransformer<T: ASTUpwardTransformer>(
        _ transformer: T,
        _ finished: @escaping T.OnTransformEnd<FuncApplication>
    ) {
        transformer.visitFuncApplication(self, finished)
    }
    
    func acceptDownwardTransformer<T: ASTDownwardTransformer>(
        _ transformer: T,
        _ info: T.TransformationInfo
    ) {
        transformer.visitFuncApplication(self, info)
    }
}

struct IfStatement: StatementNode, BlockLevelNode {
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
    
    func acceptVisitor(_ visitor: any ASTVisitor) {
        visitor.visitIfStatement(self)
    }
    
    func acceptUpwardTransformer<T: ASTUpwardTransformer>(
        _ transformer: T,
        _ finished: @escaping T.OnTransformEnd<IfStatement>
    ) {
        transformer.visitIfStatement(self, finished)
    }
    
    func acceptDownwardTransformer<T: ASTDownwardTransformer>(
        _ transformer: T,
        _ info: T.TransformationInfo
    ) {
        transformer.visitIfStatement(self, info)
    }
}

struct ReturnStatement: StatementNode, BlockLevelNode {
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
    
    func acceptVisitor(_ visitor: any ASTVisitor) {
        visitor.visitReturnStatement(self)
    }
    
    func acceptUpwardTransformer<T: ASTUpwardTransformer>(
        _ transformer: T,
        _ finished: @escaping T.OnTransformEnd<ReturnStatement>
    ) {
        transformer.visitReturnStatement(self, finished)
    }
    
    func acceptDownwardTransformer<T: ASTDownwardTransformer>(
        _ transformer: T,
        _ info: T.TransformationInfo
    ) {
        transformer.visitReturnStatement(self, info)
    }
}

struct AssignmentStatement: StatementNode, TopLevelNode {
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
    
    func acceptVisitor(_ visitor: any ASTVisitor) {
        visitor.visitAssignmentStatement(self)
    }
    
    func acceptUpwardTransformer<T>(_ transformer: T, _ finished: @escaping T.OnTransformEnd<AssignmentStatement>) where T : ASTUpwardTransformer {
        transformer.visitAssignmentStatement(self, finished)
    }
    
    func acceptDownwardTransformer<T>(_ transformer: T, _ info: T.TransformationInfo) where T : ASTDownwardTransformer {
        transformer.visitAssignmentStatement(self, info)
    }
    
}

