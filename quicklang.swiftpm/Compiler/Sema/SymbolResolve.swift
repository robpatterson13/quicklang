//
//  SymbolResolve.swift
//  quicklang
//
//  Created by Rob Patterson on 11/15/25.
//

fileprivate class SymbolGrabber: ASTUpwardTransformer {
    
    typealias Binding = String
    typealias TransformerInfo = [Binding]
    
    func visitIdentifierExpression(
        _ expression: IdentifierExpression,
        _ finished: @escaping OnTransformEnd<IdentifierExpression>
    ) {
        finished(expression, [])
    }
    
    func visitBooleanExpression(
        _ expression: BooleanExpression,
        _ finished: @escaping OnTransformEnd<BooleanExpression>
    ) {
        finished(expression, [])
    }
    
    func visitNumberExpression(
        _ expression: NumberExpression,
        _ finished: @escaping OnTransformEnd<NumberExpression>
    ) {
        finished(expression, [])
    }
    
    func visitUnaryOperation(
        _ operation: UnaryOperation,
        _ finished: @escaping OnTransformEnd<UnaryOperation>
    ) {
        finished(operation, [])
    }
    
    func visitBinaryOperation(
        _ operation: BinaryOperation,
        _ finished: @escaping OnTransformEnd<BinaryOperation>
    ) {
        finished(operation, [])
    }
    
    func visitLetDefinition(
        _ definition: LetDefinition,
        _ finished: @escaping OnTransformEnd<LetDefinition>
    ) {
        finished(definition, [definition.name])
    }
    
    func visitVarDefinition(
        _ definition: VarDefinition,
        _ finished: @escaping OnTransformEnd<VarDefinition>
    ) {
        finished(definition, [definition.name])
    }
    
    func visitFuncDefinition(
        _ definition: FuncDefinition,
        _ finished: @escaping OnTransformEnd<FuncDefinition>
    ) {
        finished(definition, [definition.name])
    }
    
    func visitFuncApplication(
        _ expression: FuncApplication,
        _ finished: @escaping OnTransformEnd<FuncApplication>
    ) {
        finished(expression, [])
    }
    
    func visitIfStatement(
        _ statement: IfStatement,
        _ finished: @escaping OnTransformEnd<IfStatement>
    ) {
        finished(statement, [])
    }
    
    func visitReturnStatement(
        _ statement: ReturnStatement,
        _ finished: @escaping OnTransformEnd<ReturnStatement>
    ) {
        finished(statement, [])
    }
    
}

class SymbolResolve: ASTDownwardTransformer {
    
    typealias BindingInScope = String
    
    private let grabber = SymbolGrabber()
    let context: ASTContext
    
    init(context: ASTContext) {
        self.context = context
    }
    
    func visitIdentifierExpression(
        _ expression: IdentifierExpression,
        _ info: [BindingInScope]
    ) {
        if !info.contains(where: { $0 == expression.name }) {
            // MARK: Unbound
        }
    }
    
    func visitBooleanExpression(
        _ expression: BooleanExpression,
        _ info: [BindingInScope]
    ) {
        // no-op
    }
    
    func visitNumberExpression(
        _ expression: NumberExpression,
        _ info: [BindingInScope]
    ) {
        // no-op
    }
    
    func visitUnaryOperation(
        _ operation: UnaryOperation,
        _ info: [BindingInScope]
    ) {
        operation.expression.acceptDownwardTransformer(self, info)
    }
    
    func visitBinaryOperation(
        _ operation: BinaryOperation,
        _ info: [BindingInScope]
    ) {
        operation.lhs.acceptDownwardTransformer(self, info)
        operation.rhs.acceptDownwardTransformer(self, info)
    }
    
    func visitLetDefinition(
        _ definition: LetDefinition,
        _ info: [BindingInScope]
    ) {
        definition.expression.acceptDownwardTransformer(self, info)
    }
    
    func visitVarDefinition(
        _ definition: VarDefinition,
        _ info: [BindingInScope]
    ) {
        definition.expression.acceptDownwardTransformer(self, info)
    }
    
    func visitFuncDefinition(
        _ definition: FuncDefinition,
        _ info: [BindingInScope]
    ) {
        var newInfo = info
        newInfo.append(definition.name)
        processBlock(definition.body, newInfo)
    }
    
    func visitFuncApplication(
        _ expression: FuncApplication,
        _ info: [BindingInScope]
    ) {
        if !info.contains(where: { $0 == expression.name }) {
            // MARK: Unbound
        }
        
        expression.arguments.forEach { $0.acceptDownwardTransformer(self, info) }
    }
    
    func visitIfStatement(
        _ statement: IfStatement,
        _ info: [BindingInScope]
    ) {
        statement.condition.acceptDownwardTransformer(self, info)
        processBlock(statement.thenBranch, info)
        if let elseBranch = statement.elseBranch {
            processBlock(elseBranch, info)
        }
    }
    
    func visitReturnStatement(
        _ statement: ReturnStatement,
        _ info: [BindingInScope]
    ) {
        statement.expression.acceptDownwardTransformer(self, info)
    }
    
    private func processBlock(
        _ block: [any BlockLevelNode],
        _ info: TransformationInfo
    ) {
        var mutInfo = info
        block.forEach { node in
            node.acceptDownwardTransformer(self, mutInfo)
            node.acceptUpwardTransformer(grabber) { _, bindings in
                mutInfo.append(contentsOf: bindings)
            }
        }
    }
    
}
