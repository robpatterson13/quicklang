//
//  ASTLinearize.swift
//  quicklang
//
//  Created by Rob Patterson on 11/16/25.
//

import Foundation

class ASTLinearize: ASTTransformer {
    
    typealias TransformerInfo = [any DefinitionNode]
    
    func visitIdentifierExpression(_ expression: IdentifierExpression, _ finished: @escaping OnTransformEnd) {
        finished(expression, [])
    }
    
    func visitBooleanExpression(_ expression: BooleanExpression, _ finished: @escaping OnTransformEnd) {
        finished(expression, [])
    }
    
    func visitNumberExpression(_ expression: NumberExpression, _ finished: @escaping OnTransformEnd) {
        finished(expression, [])
    }
    
    func visitUnaryOperation(_ operation: UnaryOperation, _ finished: @escaping OnTransformEnd) {
        var newBindings: [any DefinitionNode]
        var newExpr: any ExpressionNode
        operation.expression.acceptTransformer(self) { newExpression, bindings in
            newBindings.append(contentsOf: bindings)
            newExpr = newExpression
        }
        
        let newName = genSym(root: "unary_op", id: operation.id)
        let newOperation = UnaryOperation(op: operation.op, expression: newExpr)
        let newBinding = LetDefinition(name: newName, expression: newOperation)
        newBindings.append(newBinding)
        
        finished(newOperation, newBindings)
    }
    
    func visitBinaryOperation(_ operation: BinaryOperation, _ finished: @escaping OnTransformEnd) {
        var newBindings: [any DefinitionNode]
        
        var newLhsExpr: any ExpressionNode
        operation.lhs.acceptTransformer(self) { newLhs, bindings in
            newBindings.append(contentsOf: bindings)
            newLhsExpr = newLhs
        }
        var newRhsExpr: any ExpressionNode
        operation.lhs.acceptTransformer(self) { newRhs, bindings in
            newBindings.append(contentsOf: bindings)
            newRhsExpr = newRhs
        }
        
        let newName = genSym(root: "binary_op", id: operation.id)
        let newOperation = BinaryOperation(op: operation.op, lhs: newLhsExpr, rhs: newRhsExpr)
        let newBinding = LetDefinition(name: newName, expression: newOperation)
        newBindings.append(newBinding)
        
        finished(newOperation, newBindings)
    }
    
    func visitLetDefinition(_ definition: LetDefinition, _ finished: @escaping OnTransformEnd) {
        linearizeValDefinition(definition, finished)
    }
    
    func visitVarDefinition(_ definition: VarDefinition, _ finished: @escaping OnTransformEnd) {
        linearizeValDefinition(definition, finished)
    }
    
    private func linearizeValDefinition(_ definition: any DefinitionNode, _ finished: @escaping OnTransformEnd) {
        var newBindings: [any DefinitionNode]
        var newBoundExpr: any ExpressionNode
        definition.expression.acceptTransformer(self) { newExpression, bindings in
            newBindings.append(contentsOf: bindings)
            newBoundExpr = newExpression
        }
        
        let newDefinition = LetDefinition(name: definition.name, expression: newBoundExpr)
        finished(newDefinition, newBindings)
    }
    
    func visitFuncDefinition(_ definition: FuncDefinition, _ finished: @escaping OnTransformEnd) {
        <#code#>
    }
    
    func visitFuncApplication(_ expression: FuncApplication, _ finished: @escaping OnTransformEnd) {
        <#code#>
    }
    
    func visitIfStatement(_ statement: IfStatement, _ finished: @escaping OnTransformEnd) {
        <#code#>
    }
    
    func visitReturnStatement(_ statement: ReturnStatement, _ finished: @escaping OnTransformEnd) {
        // the only thing to worry about here is the returned expression;
        // we get the new return value (if necessary) and any new bindings
        // that the return expression introduced
        var newBindings: [any DefinitionNode]
        var newReturn: any ExpressionNode
        statement.expression.acceptTransformer(self) { newExpression, bindings in
            newBindings.append(contentsOf: bindings)
            newReturn = newExpression
        }
        
        let newStatement = ReturnStatement(expression: newReturn)
        finished(newStatement, newBindings)
    }
    
    func linearize(_ ast: TopLevel) -> TopLevel {
        let sections = ast.sections
        var transformedSections: [any TopLevelNode]
        
        sections.forEach { section in
            section.acceptTransformer(self) { tranformed in
                transformedSections.append(tranformed)
            }
        }
        
        return TopLevel(sections: transformedSections)
    }
    
    private func genSym(root: String, id: UUID) -> String {
        return root + "$" + id.uuidString
    }
}
