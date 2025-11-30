//
//  ASTVisitor.swift
//  quicklang
//
//  Created by Rob Patterson on 11/15/25.
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
    
    func visitAssignmentStatement(_ statement: AssignmentStatement)
}
