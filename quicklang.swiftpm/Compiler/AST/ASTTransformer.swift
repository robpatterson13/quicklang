//
//  ASTTransformer.swift
//  quicklang
//
//  Created by Rob Patterson on 11/16/25.
//

protocol ASTTransformer {
    
    associatedtype TransformerInfo
    typealias OnTransformEnd = (any ASTNode, TransformerInfo) -> ()
    
    func visitIdentifierExpression(_ expression: IdentifierExpression, _ finished: @escaping OnTransformEnd)
    
    func visitBooleanExpression(_ expression: BooleanExpression, _ finished: @escaping OnTransformEnd)
    
    func visitNumberExpression(_ expression: NumberExpression, _ finished: @escaping OnTransformEnd)
    
    func visitUnaryOperation(_ operation: UnaryOperation, _ finished: @escaping OnTransformEnd)
    
    func visitBinaryOperation(_ operation: BinaryOperation, _ finished: @escaping OnTransformEnd)
    
    func visitLetDefinition(_ definition: LetDefinition, _ finished: @escaping OnTransformEnd)
    
    func visitVarDefinition(_ definition: VarDefinition, _ finished: @escaping OnTransformEnd)
    
    func visitFuncDefinition(_ definition: FuncDefinition, _ finished: @escaping OnTransformEnd)
    
    func visitFuncApplication(_ expression: FuncApplication, _ finished: @escaping OnTransformEnd)
    
    func visitIfStatement(_ statement: IfStatement, _ finished: @escaping OnTransformEnd)
    
    func visitReturnStatement(_ statement: ReturnStatement, _ finished: @escaping OnTransformEnd)
    
}
