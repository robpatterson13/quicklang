//
//  ASTLinearize.swift
//  quicklang
//
//  Created by Rob Patterson on 11/16/25.
//

import Foundation

/// AST-to-AST transformer that rewrites expressions into a linearized form.
///
/// This pass preserves original semantics while introducing intermediate
/// bindings where needed so later phases can assume expressions are evaluated
/// in a simple, statement-like order.
class ASTLinearize: ASTTransformer {
    
    /// Per-visit auxiliary information produced during transformation.
    ///
    /// For linearization, this is the sequence of definition nodes (temporary
    /// bindings) that must appear before the returned node.
    typealias TransformerInfo = [any DefinitionNode]
    
    /// Pass-through for identifier references; no linearization needed.
    func visitIdentifierExpression(
        _ expression: IdentifierExpression,
        _ finished: @escaping OnTransformEnd<IdentifierExpression>
    ) {
        finished(expression, [])
    }
    
    /// Pass-through for boolean literals; no linearization needed.
    func visitBooleanExpression(
        _ expression: BooleanExpression,
        _ finished: @escaping OnTransformEnd<BooleanExpression>
    ) {
        finished(expression, [])
    }
    
    /// Pass-through for numeric literals; no linearization needed.
    func visitNumberExpression(
        _ expression: NumberExpression,
        _ finished: @escaping OnTransformEnd<NumberExpression>
    ) {
        finished(expression, [])
    }
    
    /// Linearizes the operand and introduces a binding for the unary operation result.
    ///
    /// Ensures the operand is processed first and any required temporaries precede
    /// the resulting operation.
    func visitUnaryOperation(
        _ operation: UnaryOperation,
        _ finished: @escaping OnTransformEnd<UnaryOperation>
    ) {
        var newBindings: [any DefinitionNode] = []
        var newExpr: (any ExpressionNode)? = nil
        operation.expression.acceptTransformer(self) { newExpression, bindings in
            newBindings.append(contentsOf: bindings)
            newExpr = newExpression
        }
        
        guard let operand = newExpr else {
            // Should not happen: child must synchronously invoke callback
            finished(operation, newBindings)
            return
        }
        
        let newName = genSym(root: "unary_op", id: operation.id)
        let newOperation = UnaryOperation(op: operation.op, expression: operand)
        let newBinding = LetDefinition(name: newName, expression: newOperation)
        newBindings.append(newBinding)
        
        finished(newOperation, newBindings)
    }
    
    /// Linearizes both operands and introduces a binding for the binary operation result.
    ///
    /// Guarantees left-to-right evaluation with any required temporaries emitted before
    /// the combined operation.
    func visitBinaryOperation(
        _ operation: BinaryOperation,
        _ finished: @escaping OnTransformEnd<BinaryOperation>
    ) {
        var newBindings: [any DefinitionNode] = []
        
        var newLhsExpr: (any ExpressionNode)? = nil
        operation.lhs.acceptTransformer(self) { newLhs, bindings in
            newBindings.append(contentsOf: bindings)
            newLhsExpr = newLhs
        }
        var newRhsExpr: (any ExpressionNode)? = nil
        operation.rhs.acceptTransformer(self) { newRhs, bindings in
            newBindings.append(contentsOf: bindings)
            newRhsExpr = newRhs
        }
        
        guard let lhs = newLhsExpr, let rhs = newRhsExpr else {
            finished(operation, newBindings)
            return
        }
        
        let newName = genSym(root: "binary_op", id: operation.id)
        let newOperation = BinaryOperation(op: operation.op, lhs: lhs, rhs: rhs)
        let newBinding = LetDefinition(name: newName, expression: newOperation)
        newBindings.append(newBinding)
        
        finished(newOperation, newBindings)
    }
    
    /// Linearizes the bound expression and preserves the definition shape.
    ///
    /// Any temporaries introduced by the initializer are emitted before the definition.
    func visitLetDefinition(
        _ definition: LetDefinition,
        _ finished: @escaping OnTransformEnd<LetDefinition>
    ) {
        var newBindings: [any DefinitionNode] = []
        var newBoundExpr: (any ExpressionNode)? = nil
        definition.expression.acceptTransformer(self) { newExpression, bindings in
            newBindings.append(contentsOf: bindings)
            newBoundExpr = newExpression
        }
        
        guard let bound = newBoundExpr else {
            finished(definition, newBindings)
            return
        }
        
        let newDefinition = LetDefinition(name: definition.name, expression: bound)
        finished(newDefinition, newBindings)
    }
    
    /// Linearizes the bound expression and preserves the variable definition.
    ///
    /// Any temporaries introduced by the initializer are emitted before the definition.
    func visitVarDefinition(
        _ definition: VarDefinition,
        _ finished: @escaping OnTransformEnd<VarDefinition>
    ) {
        var newBindings: [any DefinitionNode] = []
        var newBoundExpr: (any ExpressionNode)? = nil
        definition.expression.acceptTransformer(self) { newExpression, bindings in
            newBindings.append(contentsOf: bindings)
            newBoundExpr = newExpression
        }
        
        guard let bound = newBoundExpr else {
            finished(definition, newBindings)
            return
        }
        
        let newDefinition = VarDefinition(name: definition.name, expression: bound)
        finished(newDefinition, newBindings)
    }
    
    /// Linearizes a function body while preserving the function signature.
    ///
    /// The body is rewritten into a sequence of block-level nodes that reflect
    /// the linearized evaluation order.
    func visitFuncDefinition(
        _ definition: FuncDefinition,
        _ finished: @escaping OnTransformEnd<FuncDefinition>
    ) {
        let newBody = linearizeBlock(definition.body)
        let newFuncDef = FuncDefinition(
            name: definition.name,
            type: definition.type,
            parameters: definition.parameters,
            body: newBody
        )
        
        finished(newFuncDef, [])
    }
    
    /// Linearizes each argument and introduces a binding for the call result.
    ///
    /// Ensures arguments are evaluated in order before the application.
    func visitFuncApplication(
        _ expression: FuncApplication,
        _ finished: @escaping OnTransformEnd<FuncApplication>
    ) {
        var bindings = [any DefinitionNode]()
        var args = [any ExpressionNode]()
        expression.arguments.forEach { arg in
            arg.acceptTransformer(self) { newArg, newBindings in
                bindings.append(contentsOf: newBindings)
                args.append(newArg)
            }
        }
        
        let newName = genSym(root: "func_app", id: expression.id)
        let newExpr = FuncApplication(name: expression.name, arguments: args)
        let newBinding = LetDefinition(name: newName, expression: newExpr)
        bindings.append(newBinding)
        
        finished(newExpr, bindings)
    }
    
    /// Linearizes the condition and transforms both branches.
    ///
    /// Temporaries for the condition are emitted prior to the `if` statement.
    func visitIfStatement(
        _ statement: IfStatement,
        _ finished: @escaping OnTransformEnd<IfStatement>
    ) {
        var bindings = [any DefinitionNode]()
        var cond: (any ExpressionNode)? = nil
        statement.condition.acceptTransformer(self) { newCond, newBindings in
            cond = newCond
            bindings.append(contentsOf: newBindings)
        }
        
        guard let condition = cond else {
            finished(statement, bindings)
            return
        }
        
        let newThenBranch = linearizeBlock(statement.thenBranch)
        var newElseBranch: [any BlockLevelNode]? = nil
        if let elseBranch = statement.elseBranch {
            newElseBranch = linearizeBlock(elseBranch)
        }
        
        let newIfStatement = IfStatement(condition: condition, thenBranch: newThenBranch, elseBranch: newElseBranch)
        finished(newIfStatement, bindings)
    }
    
    /// Linearizes the returned expression and preserves the return statement.
    ///
    /// Any temporaries introduced by the return value are emitted before the return.
    func visitReturnStatement(
        _ statement: ReturnStatement,
        _ finished: @escaping OnTransformEnd<ReturnStatement>
    ) {
        // the only thing to worry about here is the returned expression;
        // we get the new return value (if necessary) and any new bindings
        // that the return expression introduced
        var newBindings: [any DefinitionNode] = []
        var newReturn: (any ExpressionNode)? = nil
        statement.expression.acceptTransformer(self) { newExpression, bindings in
            newBindings.append(contentsOf: bindings)
            newReturn = newExpression
        }
        
        guard let ret = newReturn else {
            finished(statement, newBindings)
            return
        }
        
        let newStatement = ReturnStatement(expression: ret)
        finished(newStatement, newBindings)
    }
    
    /// Rewrites a block into a flattened list of linearized nodes.
    ///
    /// Each node contributes its own preceding bindings, followed by the node itself.
    private func linearizeBlock(_ block: [any BlockLevelNode]) -> [any BlockLevelNode] {
        var newBlock = [any BlockLevelNode]()
        
        block.forEach { node in
            node.acceptTransformer(self) { newNode, newBindings in
                newBlock.append(contentsOf: newBindings)
                newBlock.append(newNode)
            }
        }
        
        return newBlock
    }
    
    /// Entry point to linearize a full program.
    ///
    /// Produces a new top-level with sections expanded to include any required
    /// temporaries ahead of transformed nodes.
    func linearize(_ ast: TopLevel) -> TopLevel {
        let sections = ast.sections
        var transformedSections: [any TopLevelNode] = []
        
        sections.forEach { section in
            section.acceptTransformer(self) { transformed, bindings in
                transformedSections.append(contentsOf: bindings)
                transformedSections.append(transformed)
            }
        }
        
        return TopLevel(sections: transformedSections)
    }
    
    /// Generates a stable, unique temporary name for synthesized bindings.
    private func genSym(root: String, id: UUID) -> String {
        return root + "$" + id.uuidString
    }
}
