//
//  Interpreter.swift
//  quicklang
//
//  Created by Rob Patterson on 2/16/25.
//

struct Interpreter: ASTVisitor {
    
    func visitIdentifierExpression(_ expression: IdentifierExpression) {
        <#code#>
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
        <#code#>
    }
    
    func visitReturnStatement(_ statement: ReturnStatement) {
        <#code#>
    }
    
    
}
