//
//  AST.swift
//  swift-student-challenge-2025
//
//  Created by Rob Patterson on 2/5/25.
//

typealias Binding = (name: String, body: Expression)

struct Program {
    var nodes: [ASTNode]
}

protocol ASTNode {
    
}

enum PrimType {
    case TInt
    case TBool
    case TString
}

indirect enum Expression: ASTNode {
    
    // literals
    case NumberLiteral(value: Int)
    case BooleanLiteral(value: Bool)
    
    // compound expressions
    case UnaryOperation(op: UnaryOperator, lhs: Expression, rhs: Expression)
    case BinaryOperation(op: BinaryOperator, lhs: Expression, rhs: Expression)
    
    case FunctionApplication(name: String, arguments: [Expression])
}

enum BinaryOperator {
    
    // arithmetic operators
    case Add
    case Sub
    case Mul
    
    // boolean operators
    case And
    case Or
}

enum UnaryOperator {
    
    // arithmetic operators
    case Not
    
    // boolean operators
    case Neg
}

enum Statement: ASTNode {
    
    case IfStatement(cond: ASTNode, thn: [ASTNode], els: [ASTNode])
    
    case ReturnStatement(value: Expression)
}

enum Definition: ASTNode {
    
    case VarDefinition(binding: Binding)
    case LetDefinition(binding: Binding)
    
    typealias Parameters = [(name: String, type: PrimType)]
    case FunctionDefinition(name: String, parameters: Parameters, body: [ASTNode])
}
