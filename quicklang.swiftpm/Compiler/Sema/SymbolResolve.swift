//
//  SymbolResolve.swift
//  quicklang
//
//  Created by Rob Patterson on 11/15/25.
//

class SymbolResolve: ASTVisitor {
    
    let context: ASTContext
    
    func visitIdentifierExpression(_ expression: IdentifierExpression) {
        
    }
    
    func visitBooleanExpression(_ expression: BooleanExpression) {
        <#code#>
    }
    
    func visitNumberExpression(_ expression: NumberExpression) {
        <#code#>
    }
    
    func visitUnaryOperation(_ operation: UnaryOperation) {
        <#code#>
    }
    
    func visitBinaryOperation(_ operation: BinaryOperation) {
        <#code#>
    }
    
    func visitLetDefinition(_ definition: LetDefinition) {
        <#code#>
    }
    
    func visitVarDefinition(_ definition: VarDefinition) {
        <#code#>
    }
    
    func visitFuncDefinition(_ definition: FuncDefinition) {
        <#code#>
    }
    
    func visitFuncApplication(_ expression: FuncApplication) {
        <#code#>
    }
    
    func visitIfStatement(_ statement: IfStatement) {
        
        
        statement.condition.acceptVisitor(self)
        statement.thenBranch.forEach { $0.acceptVisitor(self) }
        statement.elseBranch?.forEach { $0.acceptVisitor(self) }
    }
    
    func visitReturnStatement(_ statement: ReturnStatement) {
        statement.expression.acceptVisitor(self)
    }
    
    
}
