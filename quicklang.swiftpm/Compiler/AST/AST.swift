//
//  AST.swift
//  quicklang
//
//  Created by Rob Patterson on 2/11/25.
//

import Foundation

protocol ASTNode: Hashable {
    var id: UUID { get }
    var scope: ASTScope? { get set }
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

final class TopLevel {
    var sections: [any TopLevelNode]
    
    init(sections: [any TopLevelNode]) {
        self.sections = sections
    }
}

protocol BlockLevelNode: ASTNode { }

protocol TopLevelNode: BlockLevelNode { }

protocol ExpressionNode: ASTNode { }

final class DefinitionNode: BlockLevelNode {
    let id: UUID
    let name: String
    let type: TypeName
    let expression: any ExpressionNode
    let isImmutable: Bool
    var scope: ASTScope?
    
    init(id: UUID = UUID(), name: String, type: TypeName, expression: any ExpressionNode, isImmutable: Bool) {
        self.id = id
        self.name = name
        self.type = type
        self.expression = expression
        self.isImmutable = isImmutable
    }
    
    func acceptVisitor<V: ASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitDefinition(self, info)
    }
}

protocol StatementNode: BlockLevelNode { }

final class IdentifierExpression: ExpressionNode, BlockLevelNode {
    let id: UUID
    let name: String
    var scope: ASTScope?
    
    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
    
    func acceptVisitor<V: ASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitIdentifierExpression(self, info)
    }
}

final class BooleanExpression: ExpressionNode {
    let id: UUID
    let value: Bool
    var scope: ASTScope?
    
    init(id: UUID = UUID(), value: Bool) {
        self.id = id
        self.value = value
    }
    
    func acceptVisitor<V: ASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitBooleanExpression(self, info)
    }
}

final class NumberExpression: ExpressionNode {
    let id: UUID
    let value: Int
    var scope: ASTScope?
    
    init(id: UUID = UUID(), value: Int) {
        self.id = id
        self.value = value
    }
    
    func acceptVisitor<V: ASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitNumberExpression(self, info)
    }
}

final class UnaryOperation: ExpressionNode {
    let id: UUID
    
    let op: Operator
    enum Operator {
        case not
        case neg
    }
    let expression: any ExpressionNode
    var scope: ASTScope?
    
    init(id: UUID = UUID(), op: Operator, expression: any ExpressionNode) {
        self.id = id
        self.op = op
        self.expression = expression
    }
    
    func acceptVisitor<V: ASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitUnaryOperation(self, info)
    }
}

final class BinaryOperation: ExpressionNode {
    let id: UUID
    let op: Operator
    enum Operator {
        case plus
        case minus
        case times
        
        case and
        case or
    }
    let lhs, rhs: any ExpressionNode
    var scope: ASTScope?
    
    init(id: UUID = UUID(), op: Operator, lhs: any ExpressionNode, rhs: any ExpressionNode) {
        self.id = id
        self.op = op
        self.lhs = lhs
        self.rhs = rhs
    }
    
    func acceptVisitor<V: ASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitBinaryOperation(self, info)
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

final class FuncDefinition: TopLevelNode {
    
    final class Parameter {
        let id: UUID
        let name: String
        let type: TypeName
        var scope: ASTScope?
        
        init(id: UUID = UUID(), name: String, type: TypeName) {
            self.id = id
            self.name = name
            self.type = type
        }
    }
    
    let id: UUID
    let name: String
    let type: TypeName
    let parameters: [Parameter]
    let body: [any BlockLevelNode]
    var scope: ASTScope?
    let isEntry: Bool
    
    init(id: UUID = UUID(), name: String, type: TypeName, parameters: [Parameter], body: [any BlockLevelNode], isEntry: Bool) {
        self.id = id
        self.name = name
        self.type = type
        self.parameters = parameters
        self.body = body
        self.isEntry = isEntry
    }
    
    func acceptVisitor<V: ASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitFuncDefinition(self, info)
    }
}

final class FuncApplication: ExpressionNode, BlockLevelNode {
    let id: UUID
    let name: String
    let arguments: [any ExpressionNode]
    var scope: ASTScope?
    
    init(id: UUID = UUID(), name: String, arguments: [any ExpressionNode]) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
    
    func acceptVisitor<V: ASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitFuncApplication(self, info)
    }
}

final class IfStatement: StatementNode, BlockLevelNode {
    let id: UUID
    let condition: any ExpressionNode
    let thenBranch: [any BlockLevelNode]
    let elseBranch: [any BlockLevelNode]?
    var scope: ASTScope?
    
    init(id: UUID = UUID(), condition: any ExpressionNode, thenBranch: [any BlockLevelNode], elseBranch: [any BlockLevelNode]?) {
        self.id = id
        self.condition = condition
        self.thenBranch = thenBranch
        self.elseBranch = elseBranch
    }
    
    func acceptVisitor<V: ASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitIfStatement(self, info)
    }
}

final class ReturnStatement: StatementNode, BlockLevelNode {
    let id: UUID
    let expression: any ExpressionNode
    var scope: ASTScope?
    
    init(id: UUID = UUID(), expression: any ExpressionNode) {
        self.id = id
        self.expression = expression
    }
    
    func acceptVisitor<V: ASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitReturnStatement(self, info)
    }
}

final class AssignmentStatement: StatementNode, BlockLevelNode {
    let id: UUID
    let name: String
    let expression: any ExpressionNode
    var scope: ASTScope?
    
    init(id: UUID = UUID(), name: String, expression: any ExpressionNode) {
        self.id = id
        self.name = name
        self.expression = expression
    }
    
    func acceptVisitor<V: ASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitAssignmentStatement(self, info)
    }
    
}

