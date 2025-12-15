//
//  RawAST.swift
//  quicklang
//
//  Created by Rob Patterson on 12/13/25.
//

import Foundation

protocol RawASTVisitor {
    associatedtype VisitorResult
    associatedtype VisitorInfo
    
    func visitRawIdentifierExpression(
        _ expression: RawIdentifierExpression,
        _ info: VisitorInfo
    ) -> VisitorResult
    
    func visitRawBooleanExpression(
        _ expression: RawBooleanExpression,
        _ info: VisitorInfo
    ) -> VisitorResult
    
    func visitRawNumberExpression(
        _ expression: RawNumberExpression,
        _ info: VisitorInfo
    ) -> VisitorResult
    
    func visitRawUnaryOperation(
        _ operation: RawUnaryOperation,
        _ info: VisitorInfo
    ) -> VisitorResult
    
    func visitRawBinaryOperation(
        _ operation: RawBinaryOperation,
        _ info: VisitorInfo
    ) -> VisitorResult
    
    func visitRawLetDefinition(
        _ definition: RawLetDefinition,
        _ info: VisitorInfo
    ) -> VisitorResult
    
    func visitRawVarDefinition(
        _ definition: RawVarDefinition,
        _ info: VisitorInfo
    ) -> VisitorResult
    
    func visitRawFuncDefinition(
        _ definition: RawFuncDefinition,
        _ info: VisitorInfo
    ) -> VisitorResult
    
    func visitRawFuncApplication(
        _ expression: RawFuncApplication,
        _ info: VisitorInfo
    ) -> VisitorResult
    
    func visitRawIfStatement(
        _ statement: RawIfStatement,
        _ info: VisitorInfo
    ) -> VisitorResult
    
    func visitRawReturnStatement(
        _ statement: RawReturnStatement,
        _ info: VisitorInfo
    ) -> VisitorResult
    
    func visitRawAssignmentStatement(
        _ statement: RawAssignmentStatement,
        _ info: VisitorInfo
    ) -> VisitorResult
    
    func visitRawAttributedNode(
        _ attributedNode: RawAttributedNode,
        _ info: VisitorInfo
    ) -> VisitorResult
    
    func visitRawConditionalBlock(
        _ block: RawConditionalBlock,
        _ info: VisitorInfo
    ) -> VisitorResult
    
    func visitRawBlockStatement(
        _ block: RawBlockStatement,
        _ info: VisitorInfo
    ) -> VisitorResult
}

typealias RawIdentifiableName = (String, UUID)

final class RawASTScope {
    let isGlobal: Bool
    weak var parent: RawASTScope?
    var child: RawASTScope?
    var decls: [IntroducedBinding]
    
    enum IntroducedBinding {
        case funcParameter(RawFuncDefinition.Parameter)
        case function(RawFuncDefinition)
        case definition(any RawDefinitionNode)
        
        var identifiableName: RawIdentifiableName {
            switch self {
            case .funcParameter(let parameter):
                return (parameter.name, parameter.id)
            case .function(let funcDefinition):
                return (funcDefinition.name, funcDefinition.id)
            case .definition(let definitionNode):
                return (definitionNode.name, definitionNode.id)
            }
        }
        
        var scope: RawASTScope? {
            switch self {
            case .funcParameter(let parameter):
                return parameter.scope
            case .function(let funcDefinition):
                return funcDefinition.scope
            case .definition(let definitionNode):
                return definitionNode.scope
            }
        }
    }
    
    init(
        isGlobal: Bool,
        parent: RawASTScope? = nil,
        child: RawASTScope? = nil,
        decls: [IntroducedBinding] = []
    ) {
        self.isGlobal = isGlobal
        self.parent = parent
        self.child = child
        self.decls = decls
    }
    
    func newChild(with decl: IntroducedBinding) -> RawASTScope {
        let child = RawASTScope(isGlobal: false, parent: self, decls: [decl])
        self.child = child
        return child
    }
    
    func addDecls(_ newDecls: [IntroducedBinding]) {
        self.decls.append(contentsOf: newDecls)
    }
    
    func inScope(_ name: String) -> Bool {
        let names = decls.map { binding in
            switch binding {
            case .funcParameter(let parameter):
                return parameter.name
            case .function(let funcDefinition):
                return funcDefinition.name
            case .definition(let definitionNode):
                return definitionNode.name
            }
        }
        
        if names.contains(name) {
            return true
        }
        
        if let parent = parent {
            return parent.inScope(name)
        }
        
        return false
    }
    
    func alreadyDeclared(_ binding: IntroducedBinding) -> Bool {
        let (name, id) = binding.identifiableName
        let namesAndIds = decls.map { $0.identifiableName }
        
        for (existingName, existingId) in namesAndIds {
            if name == existingName && id != existingId {
                return true
            }
        }
        
        return false
    }
}

protocol RawASTNodeIncompletable {
    var isIncomplete: Bool { get }
    var anyIncomplete: Bool { get }
    static var incomplete: Self { get }
}

protocol RawASTNode: Hashable, RawASTNodeIncompletable {
    var id: UUID { get }
    var scope: RawASTScope? { get set }
    func acceptVisitor<V: RawASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult
}

extension RawASTNode {
    func acceptVisitor<V: RawASTVisitor>(_ visitor: V) -> V.VisitorResult where V.VisitorInfo == Void {
        acceptVisitor(visitor, ())
    }
}

extension RawASTNode {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension RawASTNode {
    var anyIncomplete: Bool {
        if isIncomplete { return true }
        return Self._containsIncomplete(in: self)
    }
    
    private static func _containsIncomplete(in value: Any) -> Bool {
        
        if let node = value as? any RawASTNode {
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

final class RawTopLevel {
    var sections: [any RawTopLevelNode]
    
    init(sections: [any RawTopLevelNode]) {
        self.sections = sections
    }
}

protocol RawBlockLevelNode: RawASTNode { }

final class RawAttributedNode: RawTopLevelNode {
    let id = UUID()
    
    enum AttributeName {
        case main
        case never
    }
    var attribute: AttributeName
    var scope: RawASTScope?
    
    var node: any RawASTNode
    
    var isIncomplete: Bool
    static var incomplete: RawAttributedNode {
        RawAttributedNode()
    }
    private init() {
        self.attribute = .never
        self.isIncomplete = true
        self.node = RawTopLevelNodeIncomplete.incomplete
    }
    
    init(attribute: AttributeName, node: any RawASTNode) {
        self.attribute = attribute
        self.isIncomplete = false
        self.node = node
    }
    
    func acceptVisitor<V>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult where V : RawASTVisitor {
        visitor.visitRawAttributedNode(self, info)
    }
}

final class RawBlockLevelNodeIncomplete: RawBlockLevelNode {
    var scope: RawASTScope?
    
    let id = UUID()
    var isIncomplete: Bool
    
    static var incomplete: RawBlockLevelNodeIncomplete {
        RawBlockLevelNodeIncomplete()
    }
    
    private init() {
        self.isIncomplete = true
    }
    
    func acceptVisitor<V: RawASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        fatalError("Attempted to visit incomplete raw block-level node")
    }
}

protocol RawTopLevelNode: RawBlockLevelNode { }

final class RawTopLevelNodeIncomplete: RawTopLevelNode {
    var scope: RawASTScope?
    let id = UUID()
    static var incomplete: RawTopLevelNodeIncomplete {
        RawTopLevelNodeIncomplete()
    }
    
    private init() {
        self.isIncomplete = true
    }
    
    var isIncomplete: Bool
    
    func acceptVisitor<V: RawASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        fatalError("Attempted to visit incomplete raw top-level node")
    }
}

extension RawTopLevelNode {
    static var incomplete: RawFuncDefinition {
        RawFuncDefinition.incomplete
    }
}

protocol RawExpressionNode: RawASTNode { }

protocol RawDefinitionNode: RawBlockLevelNode {
    var name: String { get }
    var type: TypeName { get }
    var expression: any RawExpressionNode { get }
}

protocol RawStatementNode: RawBlockLevelNode { }

final class RawIdentifierExpression: RawExpressionNode, RawBlockLevelNode {
    let id = UUID()
    let name: String
    var scope: RawASTScope?
    
    let isIncomplete: Bool
    
    static var incomplete: RawIdentifierExpression {
        return RawIdentifierExpression()
    }
    
    private init() {
        self.name = ""
        self.isIncomplete = true
    }
    
    init(name: String) {
        self.name = name
        self.isIncomplete = false
    }
    
    func acceptVisitor<V: RawASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitRawIdentifierExpression(self, info)
    }
}

final class RawBooleanExpression: RawExpressionNode {
    let id = UUID()
    let value: Bool
    var scope: RawASTScope?
    
    let isIncomplete: Bool
    
    static var incomplete: RawBooleanExpression {
        return RawBooleanExpression()
    }
    
    private init() {
        self.value = false
        self.isIncomplete = true
    }
    
    init(value: Bool) {
        self.value = value
        self.isIncomplete = false
    }
    
    func acceptVisitor<V: RawASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitRawBooleanExpression(self, info)
    }
}

final class RawNumberExpression: RawExpressionNode {
    let id = UUID()
    let value: Int
    var scope: RawASTScope?
    
    let isIncomplete: Bool
    
    static var incomplete: RawNumberExpression {
        return RawNumberExpression()
    }
    
    private init() {
        self.value = 0
        self.isIncomplete = true
    }
    
    init(value: Int) {
        self.value = value
        self.isIncomplete = false
    }
    
    func acceptVisitor<V: RawASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitRawNumberExpression(self, info)
    }
}

final class RawUnaryOperation: RawExpressionNode {
    let id = UUID()
    
    let op: UnaryOperator
    let expression: any RawExpressionNode
    var scope: RawASTScope?
    
    let isIncomplete: Bool
    
    static var incomplete: RawUnaryOperation {
        return RawUnaryOperation()
    }
    
    private init() {
        self.op = .not
        self.expression = RawIdentifierExpression.incomplete
        self.isIncomplete = true
    }
    
    init(op: UnaryOperator, expression: any RawExpressionNode) {
        self.op = op
        self.expression = expression
        self.isIncomplete = false
    }
    
    func acceptVisitor<V: RawASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitRawUnaryOperation(self, info)
    }
}

final class RawBinaryOperation: RawExpressionNode {
    let id = UUID()
    let op: BinaryOperator
    let lhs, rhs: any RawExpressionNode
    var scope: RawASTScope?
    
    let isIncomplete: Bool
    
    static var incomplete: RawBinaryOperation {
        return RawBinaryOperation()
    }
    
    private init() {
        self.op = .plus
        self.lhs = RawIdentifierExpression.incomplete
        self.rhs = RawIdentifierExpression.incomplete
        self.isIncomplete = true
    }
    
    init(op: BinaryOperator, lhs: any RawExpressionNode, rhs: any RawExpressionNode) {
        self.op = op
        self.lhs = lhs
        self.rhs = rhs
        self.isIncomplete = false
    }
    
    func acceptVisitor<V: RawASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitRawBinaryOperation(self, info)
    }
}

final class RawBlockStatement: RawASTNode {
    let id = UUID()
    var statements: [any RawBlockLevelNode]
    var scope: RawASTScope?
    
    init(statements: [any RawBlockLevelNode]) {
        self.statements = statements
        self.isIncomplete = false
    }
    
    var isIncomplete: Bool
    static var incomplete: RawBlockStatement {
        return RawBlockStatement()
    }
    
    private init() {
        self.isIncomplete = true
        self.statements = []
    }
    
    func acceptVisitor<V: RawASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitRawBlockStatement(self, info)
    }
}

final class RawLetDefinition: RawDefinitionNode {
    let id = UUID()
    let name: String
    let type: TypeName
    let expression: any RawExpressionNode
    var scope: RawASTScope?
    
    let isIncomplete: Bool
    
    static var incomplete: RawLetDefinition {
        return RawLetDefinition()
    }
    
    private init() {
        self.name = ""
        self.type = .Int
        self.expression = RawIdentifierExpression.incomplete
        self.isIncomplete = true
    }
    
    init(name: String, type: TypeName, expression: any RawExpressionNode) {
        self.name = name
        self.type = type
        self.expression = expression
        self.isIncomplete = false
    }
    
    func acceptVisitor<V: RawASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitRawLetDefinition(self, info)
    }
}

final class RawVarDefinition: RawDefinitionNode {
    let id = UUID()
    let name: String
    let type: TypeName
    let expression: any RawExpressionNode
    var scope: RawASTScope?
    
    let isIncomplete: Bool
    
    static var incomplete: RawVarDefinition {
        return RawVarDefinition()
    }
    
    private init() {
        self.name = ""
        self.type = .Int
        self.expression = RawIdentifierExpression.incomplete
        self.isIncomplete = true
    }
    
    init(name: String, type: TypeName, expression: any RawExpressionNode) {
        self.name = name
        self.type = type
        self.expression = expression
        self.isIncomplete = false
    }
    
    func acceptVisitor<V: RawASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitRawVarDefinition(self, info)
    }
}

final class RawFuncDefinition: RawTopLevelNode {
    
    final class Parameter {
        let id = UUID()
        let name: String
        let type: TypeName
        let isIncomplete: Bool
        var scope: RawASTScope?
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
    let body: RawBlockStatement
    var scope: RawASTScope?
    
    let isIncomplete: Bool
    
    static var incomplete: RawFuncDefinition {
        return RawFuncDefinition()
    }
    
    private init() {
        self.name = ""
        self.type = .Int
        self.parameters = []
        self.body = .incomplete
        self.isIncomplete = true
    }
    
    init(name: String, type: TypeName, parameters: [Parameter], body: RawBlockStatement) {
        self.name = name
        self.type = type
        self.parameters = parameters
        self.body = body
        self.isIncomplete = false
    }
    
    func acceptVisitor<V: RawASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitRawFuncDefinition(self, info)
    }
}

final class RawFuncApplication: RawExpressionNode, RawBlockLevelNode {
    let id = UUID()
    let name: String
    let arguments: [any RawExpressionNode]
    var scope: RawASTScope?
    
    let isIncomplete: Bool
    
    static var incomplete: RawFuncApplication {
        return RawFuncApplication()
    }
    
    private init() {
        self.name = ""
        self.arguments = []
        self.isIncomplete = true
    }
    
    init(name: String, arguments: [any RawExpressionNode]) {
        self.name = name
        self.arguments = arguments
        self.isIncomplete = false
    }
    
    func acceptVisitor<V: RawASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitRawFuncApplication(self, info)
    }
}

final class RawConditionalBlock: RawASTNode {
    var id = UUID()
    let condition: any RawExpressionNode
    let body: RawBlockStatement
    var scope: RawASTScope?
    
    init(condition: any RawExpressionNode, body: RawBlockStatement) {
        self.condition = condition
        self.body = body
        self.isIncomplete = false
    }
    
    var isIncomplete: Bool
    static var incomplete: RawConditionalBlock {
        RawConditionalBlock()
    }
    
    private init() {
        self.isIncomplete = true
        self.condition = RawBooleanExpression.incomplete
        self.body = .incomplete
    }
    
    func acceptVisitor<V: RawASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitRawConditionalBlock(self, info)
    }
}

final class RawIfStatement: RawStatementNode, RawBlockLevelNode {
    let id = UUID()
    let conditionalBlocks: [RawConditionalBlock]
    let elseBranch: RawBlockStatement?
    var scope: RawASTScope?
    
    init(conditionalBlocks: [RawConditionalBlock], elseBranch: RawBlockStatement? = nil) {
        self.conditionalBlocks = conditionalBlocks
        self.elseBranch = elseBranch
        self.isIncomplete = false
    }
    
    let isIncomplete: Bool
    static var incomplete: RawIfStatement {
        return RawIfStatement()
    }
    
    private init() {
        self.conditionalBlocks = []
        self.elseBranch = nil
        self.isIncomplete = true
    }
    
    func acceptVisitor<V: RawASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitRawIfStatement(self, info)
    }
}

final class RawReturnStatement: RawStatementNode, RawBlockLevelNode {
    let id = UUID()
    let expression: any RawExpressionNode
    var scope: RawASTScope?
    
    init(expression: any RawExpressionNode) {
        self.expression = expression
        self.isIncomplete = false
    }
    
    let isIncomplete: Bool
    static var incomplete: RawReturnStatement {
        return RawReturnStatement()
    }
    
    private init() {
        self.expression = RawIdentifierExpression.incomplete
        self.isIncomplete = true
    }
    
    func acceptVisitor<V: RawASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitRawReturnStatement(self, info)
    }
}

final class RawAssignmentStatement: RawStatementNode, RawBlockLevelNode {
    let id = UUID()
    let name: String
    let expression: any RawExpressionNode
    var scope: RawASTScope?
    
    init(name: String, expression: any RawExpressionNode) {
        self.name = name
        self.expression = expression
        self.isIncomplete = false
    }
    
    var isIncomplete: Bool
    static var incomplete: RawAssignmentStatement {
        return RawAssignmentStatement()
    }
    
    private init() {
        self.name = ""
        self.expression = RawIdentifierExpression.incomplete
        self.isIncomplete = true
    }
    
    func acceptVisitor<V: RawASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitRawAssignmentStatement(self, info)
    }
}

