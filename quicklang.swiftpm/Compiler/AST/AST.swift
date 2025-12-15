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
    
    let op: UnaryOperator
    let expression: any ExpressionNode
    var scope: ASTScope?
    
    init(id: UUID = UUID(), op: UnaryOperator, expression: any ExpressionNode) {
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
    let op: BinaryOperator
    let lhs, rhs: any ExpressionNode
    var scope: ASTScope?
    
    init(id: UUID = UUID(), op: BinaryOperator, lhs: any ExpressionNode, rhs: any ExpressionNode) {
        self.id = id
        self.op = op
        self.lhs = lhs
        self.rhs = rhs
    }
    
    func acceptVisitor<V: ASTVisitor>(_ visitor: V, _ info: V.VisitorInfo) -> V.VisitorResult {
        visitor.visitBinaryOperation(self, info)
    }
}

final class FuncDefinition: TopLevelNode {
    
    final class Parameter: Hashable {
        let id: UUID
        let name: String
        let type: TypeName
        var scope: ASTScope?
        
        init(id: UUID = UUID(), name: String, type: TypeName) {
            self.id = id
            self.name = name
            self.type = type
        }
        
        static func == (lhs: FuncDefinition.Parameter, rhs: FuncDefinition.Parameter) -> Bool {
            return lhs.name == rhs.name
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(name)
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
