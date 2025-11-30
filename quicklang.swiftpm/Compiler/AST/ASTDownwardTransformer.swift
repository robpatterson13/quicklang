//
//  ASTDownwardTransformer.swift
//  quicklang
//
//  Created by Rob Patterson on 11/17/25.
//

protocol ASTDownwardTransformer {
    
    associatedtype TransformationInfo
    
    func visitIdentifierExpression(_ expression: IdentifierExpression, _ info: TransformationInfo)
    
    func visitBooleanExpression(_ expression: BooleanExpression, _ info: TransformationInfo)
    
    func visitNumberExpression(_ expression: NumberExpression, _ info: TransformationInfo)
    
    func visitUnaryOperation(_ operation: UnaryOperation, _ info: TransformationInfo)
    
    func visitBinaryOperation(_ operation: BinaryOperation, _ info: TransformationInfo)
    
    func visitLetDefinition(_ definition: LetDefinition, _ info: TransformationInfo)
    
    func visitVarDefinition(_ definition: VarDefinition, _ info: TransformationInfo)
    
    func visitFuncDefinition(_ definition: FuncDefinition, _ info: TransformationInfo)
    
    func visitFuncApplication(_ expression: FuncApplication, _ info: TransformationInfo)
    
    func visitIfStatement(_ statement: IfStatement, _ info: TransformationInfo)
    
    func visitReturnStatement(_ statement: ReturnStatement, _ info: TransformationInfo)
    
    func visitAssignmentStatement(_ statement: AssignmentStatement, _ info: TransformationInfo)
}
