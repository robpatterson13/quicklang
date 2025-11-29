//
//  ASTLinearize.swift
//  quicklang
//
//  Created by Rob Patterson on 11/16/25.
//

import Foundation

class ASTLinearize: SemaPass, ASTUpwardTransformer {
    
    func begin(reportingTo: CompilerErrorManager) {
        context.tree = linearize(context.tree)
    }
    
    let context: ASTContext
    
    init(context: ASTContext) {
        self.context = context
    }
    
    typealias TransformerInfo = (IdentifierExpression?, [any DefinitionNode])
    
    func visitIdentifierExpression(
        _ expression: IdentifierExpression,
        _ finished: @escaping OnTransformEnd<IdentifierExpression>
    ) {
        finished(expression, (nil, []))
    }
    
    func visitBooleanExpression(
        _ expression: BooleanExpression,
        _ finished: @escaping OnTransformEnd<BooleanExpression>
    ) {
        finished(expression, (nil, []))
    }
    
    func visitNumberExpression(
        _ expression: NumberExpression,
        _ finished: @escaping OnTransformEnd<NumberExpression>
    ) {
        finished(expression, (nil, []))
    }
    
    func visitUnaryOperation(
        _ operation: UnaryOperation,
        _ finished: @escaping OnTransformEnd<UnaryOperation>
    ) {
        var newBindings: [any DefinitionNode] = []
        var newExpr: (any ExpressionNode)? = nil
        operation.expression.acceptUpwardTransformer(self) { newExpression, info in
            let (id, bindings) = info
            newBindings.append(contentsOf: bindings)
            
            // if a new binding was introduced in the subexpression,
            // use that in place of the operand
            if let id {
                newExpr = id
            } else {
                newExpr = newExpression
            }
        }
        
        let newName = GenSymInfo.singleton.genSym(root: "unary_op", id: operation.id)
        let newOperation = UnaryOperation(op: operation.op, expression: newExpr!)
        let newType = context.getType(of: newOperation)
        let newBinding = LetDefinition(name: newName, type: newType, expression: newOperation)
        newBindings.append(newBinding)
        
        let newIdentifierExpr = IdentifierExpression(name: newName)
        
        let result = (newIdentifierExpr, newBindings)
        finished(newOperation, result)
    }
    
    func visitBinaryOperation(
        _ operation: BinaryOperation,
        _ finished: @escaping OnTransformEnd<BinaryOperation>
    ) {
        var newBindings: [any DefinitionNode] = []
        
        var newLhsExpr: (any ExpressionNode)? = nil
        operation.lhs.acceptUpwardTransformer(self) { newLhs, info in
            let (id, bindings) = info
            
            if let id {
                newLhsExpr = id
            } else {
                newLhsExpr = newLhs
            }
            
            newBindings.append(contentsOf: bindings)
        }
        var newRhsExpr: (any ExpressionNode)? = nil
        operation.rhs.acceptUpwardTransformer(self) { newRhs, info in
            let (id, bindings) = info
            
            if let id {
                newRhsExpr = id
            } else {
                newRhsExpr = newRhs
            }
            
            newBindings.append(contentsOf: bindings)
        }
        
        let newName = GenSymInfo.singleton.genSym(root: "binary_op", id: operation.id)
        let newOperation = BinaryOperation(op: operation.op, lhs: newLhsExpr!, rhs: newRhsExpr!)
        let newType = context.getType(of: newOperation)
        let newBinding = LetDefinition(name: newName, type: newType, expression: newOperation)
        newBindings.append(newBinding)
        
        let newIdentifierExpr = IdentifierExpression(name: newName)
        
        let result = (newIdentifierExpr, newBindings)
        finished(newOperation, result)
    }
    
    func visitLetDefinition(
        _ definition: LetDefinition,
        _ finished: @escaping OnTransformEnd<LetDefinition>
    ) {
        var newBindings: [any DefinitionNode] = []
        var newBoundExpr: (any ExpressionNode)? = nil
        definition.expression.acceptUpwardTransformer(self) { newExpression, info in
            let (id, bindings) = info
            
            if let id {
                newBoundExpr = id
            } else {
                newBoundExpr = newExpression
            }
            
            newBindings.append(contentsOf: bindings)
        }
        
        let newType = context.getType(of: newBoundExpr!)
        let newDefinition = LetDefinition(name: definition.name, type: newType, expression: newBoundExpr!)
        finished(newDefinition, (nil, newBindings))
    }
    
    func visitVarDefinition(
        _ definition: VarDefinition,
        _ finished: @escaping OnTransformEnd<VarDefinition>
    ) {
        var newBindings: [any DefinitionNode] = []
        var newBoundExpr: (any ExpressionNode)? = nil
        definition.expression.acceptUpwardTransformer(self) { newExpression, info in
            let (id, bindings) = info
            
            if let id {
                newBoundExpr = id
            } else {
                newBoundExpr = newExpression
            }
            
            newBindings.append(contentsOf: bindings)
        }
        
        let newType = context.getType(of: newBoundExpr!)
        let newDefinition = VarDefinition(name: definition.name, type: newType, expression: newBoundExpr!)
        finished(newDefinition, (nil, newBindings))
    }
    
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
        
        finished(newFuncDef, (nil, []))
    }
    
    func visitFuncApplication(
        _ expression: FuncApplication,
        _ finished: @escaping OnTransformEnd<FuncApplication>
    ) {
        var bindings = [any DefinitionNode]()
        var args = [any ExpressionNode]()
        expression.arguments.forEach { arg in
            arg.acceptUpwardTransformer(self) { newArg, info in
                let (id, newBindings) = info
                bindings.append(contentsOf: newBindings)
                args.append(id != nil ? id! : newArg)
            }
        }
        
        let newName = GenSymInfo.singleton.genSym(root: "func_app", id: expression.id)
        let newExpr = FuncApplication(name: expression.name, arguments: args)
        let newType = context.getType(of: newExpr)
        let newBinding = LetDefinition(name: newName, type: newType, expression: newExpr)
        bindings.append(newBinding)
        
        let newIdentifierExpr = IdentifierExpression(name: newName)
        
        let result = (newIdentifierExpr, bindings)
        finished(newExpr, result)
    }
    
    func visitIfStatement(
        _ statement: IfStatement,
        _ finished: @escaping OnTransformEnd<IfStatement>
    ) {
        var bindings = [any DefinitionNode]()
        var cond: (any ExpressionNode)? = nil
        statement.condition.acceptUpwardTransformer(self) { newCond, info in
            let (id, newBindings) = info
            
            if let id {
                cond = id
            } else {
                cond = newCond
            }
            
            bindings.append(contentsOf: newBindings)
        }
        
        let newThenBranch = linearizeBlock(statement.thenBranch)
        var newElseBranch: [any BlockLevelNode]? = nil
        if let elseBranch = statement.elseBranch {
            newElseBranch = linearizeBlock(elseBranch)
        }
        
        let newIfStatement = IfStatement(condition: cond!, thenBranch: newThenBranch, elseBranch: newElseBranch)
        finished(newIfStatement, (nil, bindings))
    }
    
    func visitReturnStatement(
        _ statement: ReturnStatement,
        _ finished: @escaping OnTransformEnd<ReturnStatement>
    ) {
        // the only thing to worry about here is the returned expression;
        // we get the new return value (if necessary) and any new bindings
        // that the return expression introduced
        var newBindings: [any DefinitionNode] = []
        var newReturn: (any ExpressionNode)? = nil
        statement.expression.acceptUpwardTransformer(self) { newExpression, info in
            let (id, bindings) = info
            
            if let id {
                newReturn = id
            } else {
                newReturn = newExpression
            }
            
            newBindings.append(contentsOf: bindings)
        }
        
        let newStatement = ReturnStatement(expression: newReturn!)
        finished(newStatement, (nil, newBindings))
    }
    
    func visitAssignmentStatement(
        _ statement: AssignmentStatement,
        _ finished: @escaping OnTransformEnd<AssignmentStatement>
    ) {
        // MARK: NOT DONE
    }
    
    private func linearizeBlock(_ block: [any BlockLevelNode]) -> [any BlockLevelNode] {
        var newBlock = [any BlockLevelNode]()
        
        block.forEach { node in
            node.acceptUpwardTransformer(self) { newNode, info in
                let (id, newBindings) = info
                newBlock.append(contentsOf: newBindings)
                
                if let id {
                    newBlock.append(id)
                } else {
                    newBlock.append(newNode)
                }
            }
        }
        
        return newBlock
    }
    
    func linearize(_ ast: TopLevel) -> TopLevel {
        let sections = ast.sections
        var transformedSections: [any TopLevelNode] = []
        
        sections.forEach { section in
            section.acceptUpwardTransformer(self) { transformed, info in
                let (id, bindings) = info
                transformedSections.append(contentsOf: bindings)
                
                if let id {
                    transformedSections.append(id)
                } else {
                    transformedSections.append(transformed)
                }
            }
        }
        
        return TopLevel(sections: transformedSections)
    }
}

fileprivate final class GenSymInfo: @unchecked Sendable {
    static let singleton = GenSymInfo()
    
    private let lock = NSLock()
    
    private var _tag = 0
    private var tag: Int {
        get {
            lock.lock()
            defer { lock.unlock() }
            _tag += 1
            return _tag
        }
    }
    
    func genSym(root: String, id: UUID) -> String {
        return root + "$\(tag)$" + id.uuidString
    }
    
    private init() {}
}

