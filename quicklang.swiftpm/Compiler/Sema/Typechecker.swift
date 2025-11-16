//
//  Typechecker.swift
//  quicklang
//
//  Created by Rob Patterson on 2/16/25.
//

struct Typechecker: ASTVisitor {
    
    var errors: [Error] = []
    let context: ASTContext
    
    private func isExpression(_ expr: any ExpressionNode, type: TypeName) -> Bool {
        return type == context.getType(of: expr)
    }
    
    private func checkDefinition(_ definition: any DefinitionNode) {
        if let type = definition.type, !isExpression(definition.expression, type: type) {
            // MARK: Definition has type
        }
    }
    
    func visitIdentifierExpression(_ expression: IdentifierExpression) {}
    
    func visitBooleanExpression(_ expression: BooleanExpression) {}
    
    func visitNumberExpression(_ expression: NumberExpression) {}
    
    func visitUnaryOperation(_ operation: UnaryOperation) {
        switch operation.op {
        case .not, .neg:
            if !isExpression(operation.expression, type: .Bool) {
                // MARK: \(operation.op) can only be used with a Bool expression
            }
        }
        
        operation.expression.accept(self)
    }
    
    func visitBinaryOperation(_ operation: BinaryOperation) {
        switch operation.op {
        case .plus, .minus, .times:
            if !isExpression(operation.lhs, type: .Int),
               !isExpression(operation.rhs, type: .Int) {
                // MARK: \(operation.op) can only be used with a Int expression
            }
        case .and, .or:
            if !isExpression(operation.lhs, type: .Bool),
               !isExpression(operation.rhs, type: .Bool) {
                // MARK: \(operation.op) can only be used with a Bool expression
            }
        }
        
        operation.lhs.accept(self)
        operation.rhs.accept(self)
    }
    
    func visitLetDefinition(_ definition: LetDefinition) {
        checkDefinition(definition)
    }
    
    func visitVarDefinition(_ definition: VarDefinition) {
        checkDefinition(definition)
    }
    
    func visitFuncDefinition(_ definition: FuncDefinition) {
        // do the body of the definition first
        definition.body.forEach { $0.accept(self) }
        
        // then type check the function definition + returned value
        let returnType = definition.type
        let returnStmt = definition.body.first { $0 is ReturnStatement } as? ReturnStatement
        
        // if our function is void and we don't return anything, exit
        if definition.type == .Void && returnStmt == nil {
            return
        }
        
        // if our function isn't void and we don't return anything, add error
        // and exit
        guard let returnStmt else {
            // MARK: Must return a value of type from func definition
            return
        }
        
        // if our return type isn't void, add error and exit
        guard returnType != .Void else {
            // MARK: Cannot return a value from a void function
            return
        }
        
        if !isExpression(returnStmt.expression, type: returnType) {
            // MARK: Function must return <returnType>, returning <type of returnStmt.expression>
        }
    }
    
    func visitFuncApplication(_ expression: FuncApplication) {
        let funcDef = context.getFuncParams(of: expression.name)
        
        expression.arguments.forEach { $0.accept(self) }
    }
    
    func visitIfStatement(_ statement: IfStatement) {
        if !isExpression(statement.condition, type: .Bool) {
            // MARK: Condition of if statement must be Bool, is <other type>
        }
        
        statement.thenBranch.forEach { $0.accept(self) }
        statement.elseBranch?.forEach { $0.accept(self) }
    }
    
    func visitReturnStatement(_ statement: ReturnStatement) {
        statement.expression.accept(self)
    }
    
    
}
