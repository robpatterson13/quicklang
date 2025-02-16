//
//  AST.swift
//  quicklang
//
//  Created by Rob Patterson on 2/11/25.
//

protocol ASTVisitor {
    
    func visitIdentifierExpression(_ expression: IdentifierExpression)
    func visitBooleanExpression(_ expression: BooleanExpression)
    func visitNumberExpression(_ expression: NumberExpression)
    
    func visitUnaryOperation(_ operation: UnaryOperation)
    func visitBinaryOperation(_ operation: BinaryOperation)
    
    func visitLetDefinition(_ definition: LetDefinition)
    func visitVarDefinition(_ definition: VarDefinition)
    
    func visitFuncDefinition(_ definition: FuncDefinition)
    func visitFuncApplication(_ expression: FuncApplication)
    
    func visitIfStatement(_ statement: IfStatement)
    func visitReturnStatement(_ statement: ReturnStatement)
}

protocol ASTNode {
    func accept(visitor: ASTVisitor)
}

struct TopLevel {
    var sections: [TopLevelNode]
}

protocol BlockLevelNode: ASTNode { }
protocol TopLevelNode: BlockLevelNode { }

protocol ExpressionNode: ASTNode { }

protocol DefinitionNode: TopLevelNode {
    var name: String { get }
    var expression: any ExpressionNode { get }
}

protocol StatementNode: BlockLevelNode { }

struct IdentifierExpression: ExpressionNode {
    var name: String
    
    func accept(visitor: any ASTVisitor) {
        visitor.visitIdentifierExpression(self)
    }
}

struct BooleanExpression: ExpressionNode {
    var value: Bool
    
    func accept(visitor: any ASTVisitor) {
        visitor.visitBooleanExpression(self)
    }
}

struct NumberExpression: ExpressionNode {
    var value: Int
    
    func accept(visitor: any ASTVisitor) {
        visitor.visitNumberExpression(self)
    }
}

enum UnaryOperator {
    case not
    case neg
}

struct UnaryOperation: ExpressionNode {
    var op: UnaryOperator
    var expression: any ExpressionNode
    
    func accept(visitor: any ASTVisitor) {
        visitor.visitUnaryOperation(self)
    }
}

enum BinaryOperator {
    case plus
    case minus
    case times
    
    case and
    case or
}

struct BinaryOperation: ExpressionNode {
    var op: BinaryOperator
    var lhs, rhs: ExpressionNode
    
    func accept(visitor: any ASTVisitor) {
        visitor.visitBinaryOperation(self)
    }
}

struct LetDefinition: DefinitionNode  {
    var name: String
    var expression: any ExpressionNode
    
    func accept(visitor: any ASTVisitor) {
        visitor.visitLetDefinition(self)
    }
}

struct VarDefinition: DefinitionNode {
    var name: String
    var expression: any ExpressionNode
    
    func accept(visitor: any ASTVisitor) {
        visitor.visitVarDefinition(self)
    }
}

enum TypeName {
    case Bool
    case Int
    case String
}

struct FuncDefinition: TopLevelNode {
    typealias Parameter = (name: String, type: TypeName)
    
    var name: String
    var type: TypeName
    var parameters: [Parameter]
    var body: [any BlockLevelNode]
    
    func accept(visitor: any ASTVisitor) {
        visitor.visitFuncDefinition(self)
    }
}

struct FuncApplication: ExpressionNode, TopLevelNode {
    var name: String
    var arguments: [any ExpressionNode]
    
    func accept(visitor: any ASTVisitor) {
        visitor.visitFuncApplication(self)
    }
}

struct IfStatement: StatementNode, BlockLevelNode {
    var condition: any ExpressionNode
    var thenBranch: [any BlockLevelNode]
    var elseBranch: [any BlockLevelNode]
    
    func accept(visitor: any ASTVisitor) {
        visitor.visitIfStatement(self)
    }
}

struct ReturnStatement: StatementNode, BlockLevelNode {
    var expression: any ExpressionNode
    
    func accept(visitor: any ASTVisitor) {
        visitor.visitReturnStatement(self)
    }
}
