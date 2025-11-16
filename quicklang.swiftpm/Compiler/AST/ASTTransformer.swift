//
//  ASTTransformer.swift
//  quicklang
//
//  Created by Rob Patterson on 11/16/25.
//

protocol ASTTransformer {
    
    associatedtype TransformerInfo
    typealias OnTransformEnd<Node: ASTNode> = (Node, TransformerInfo) -> ()
    
    func visitIdentifierExpression(_ expression: IdentifierExpression, _ finished: @escaping OnTransformEnd<IdentifierExpression>)
    
    func visitBooleanExpression(_ expression: BooleanExpression, _ finished: @escaping OnTransformEnd<BooleanExpression>)
    
    func visitNumberExpression(_ expression: NumberExpression, _ finished: @escaping OnTransformEnd<NumberExpression>)
    
    func visitUnaryOperation(_ operation: UnaryOperation, _ finished: @escaping OnTransformEnd<UnaryOperation>)
    
    func visitBinaryOperation(_ operation: BinaryOperation, _ finished: @escaping OnTransformEnd<BinaryOperation>)
    
    func visitLetDefinition(_ definition: LetDefinition, _ finished: @escaping OnTransformEnd<LetDefinition>)
    
    func visitVarDefinition(_ definition: VarDefinition, _ finished: @escaping OnTransformEnd<VarDefinition>)
    
    func visitFuncDefinition(_ definition: FuncDefinition, _ finished: @escaping OnTransformEnd<FuncDefinition>)
    
    func visitFuncApplication(_ expression: FuncApplication, _ finished: @escaping OnTransformEnd<FuncApplication>)
    
    func visitIfStatement(_ statement: IfStatement, _ finished: @escaping OnTransformEnd<IfStatement>)
    
    func visitReturnStatement(_ statement: ReturnStatement, _ finished: @escaping OnTransformEnd<ReturnStatement>)
    
}
