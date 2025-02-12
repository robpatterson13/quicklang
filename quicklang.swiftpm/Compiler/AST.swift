//
//  AST.swift
//  quicklang
//
//  Created by Rob Patterson on 2/11/25.
//

struct Program {
    var sections: [TopLevelNode]
}

protocol FunctionLevelNode { }
protocol TopLevelNode: FunctionLevelNode { }

protocol SequenceableNode { }

protocol ExpressionNode { }

protocol DefinitionNode: TopLevelNode, SequenceableNode {
    var name: String { get }
    var expression: any ExpressionNode { get }
}

protocol StatementNode { }

struct IdentifierExpression: ExpressionNode {
    var name: String
}

struct BooleanExpression: ExpressionNode {
    var value: Bool
}

struct NumberExpression: ExpressionNode {
    var value: Int
}

enum UnaryOperator {
    case not
    case neg
}

struct UnaryOperation: ExpressionNode {
    var op: UnaryOperator
    var expression: any ExpressionNode
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
}

struct LetDefinition: DefinitionNode  {
    var name: String
    var expression: any ExpressionNode
}

struct VarDefinition: DefinitionNode {
    var name: String
    var expression: any ExpressionNode
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
    var body: [any FunctionLevelNode]
}

struct FuncApplication: ExpressionNode, TopLevelNode {
    var name: String
    var arguments: [any ExpressionNode]
}

struct IfStatement: StatementNode, FunctionLevelNode {
    var condition: any ExpressionNode
    var thenBranch: [any StatementNode]
    var elseBranch: [any StatementNode]
}

struct ReturnStatement: StatementNode, FunctionLevelNode {
    var expression: any ExpressionNode
}
