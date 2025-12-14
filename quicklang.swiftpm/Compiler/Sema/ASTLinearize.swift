//
//  ASTLinearize.swift
//  quicklang
//
//  Created by Rob Patterson on 11/16/25.
//

import Foundation

class ASTLinearize: SemaPass, ASTVisitor {
    
    func begin(reportingTo: CompilerErrorManager) {
        let linearized = linearize(context.tree)
        context.changeAST(linearized)
    }
    
    let context: ASTContext
    
    init(context: ASTContext) {
        self.context = context
    }
    
    enum LinearizedNodeResult {
        case node(any ASTNode)
        case id(IdentifierExpression)
    }
    typealias NewBindingInfo = (LinearizedNodeResult, [DefinitionNode])
    
    private func unwrap(linearized: LinearizedNodeResult) -> (any ASTNode) {
        switch linearized {
        case .node(let node):
            return node
        case .id(let id):
            return id
        }
    }
    
    private func getNodeAndBindings<N: ExpressionNode>(
        expression: N,
        _ existingBindings: [DefinitionNode]? = nil
    ) -> ((any ExpressionNode), [DefinitionNode]) {
        
        let (linearized, bindings) = expression.acceptVisitor(self)
        let newExpr = unwrap(linearized: linearized)
        
        let newBindings: [DefinitionNode]
        if let existingBindings {
            newBindings = bindings + existingBindings
        } else {
            newBindings = bindings
        }
        
        // we can force unwrap as node has to be an expression
        // it'll either be itself, or an IdentifierExpression
        return (newExpr as! any ExpressionNode, newBindings)
    }
    
    func visitIdentifierExpression(
        _ expression: IdentifierExpression,
        _ info: Void
    ) -> NewBindingInfo {
        return (.node(expression), [])
    }
    
    func visitBooleanExpression(
        _ expression: BooleanExpression,
        _ info: Void
    ) -> NewBindingInfo {
        return (.node(expression), [])
    }
    
    func visitNumberExpression(
        _ expression: NumberExpression,
        _ info: Void
    ) -> NewBindingInfo {
        return (.node(expression), [])
    }
    
    func visitUnaryOperation(
        _ operation: UnaryOperation,
        _ info: Void
    ) -> NewBindingInfo {
        var (newExpr, newBindings) = getNodeAndBindings(expression: operation.expression)
        
        let newName = GenSymInfo.singleton.genSym(root: "unary_op", id: operation.id)
        let newOperation = UnaryOperation(op: operation.op, expression: newExpr)
        let newBinding = DefinitionNode(name: newName, type: .Bool, expression: newOperation, isImmutable: true)
        newBindings.append(newBinding)
        
        let newIdentifierExpr = IdentifierExpression(name: newName)
        
        let result = LinearizedNodeResult.id(newIdentifierExpr)
        return (result, newBindings)
    }
    
    func visitBinaryOperation(
        _ operation: BinaryOperation,
        _ info: Void
    ) -> NewBindingInfo {
        let (newLhs, lhsBindings) = getNodeAndBindings(expression: operation.lhs)
        var (newRhs, newBindings) = getNodeAndBindings(expression: operation.rhs, lhsBindings)
        
        let newName = GenSymInfo.singleton.genSym(root: "binary_op", id: operation.id)
        let newOperation = BinaryOperation(op: operation.op, lhs: newLhs, rhs: newRhs)
        let newBinding = DefinitionNode(name: newName, type: .Bool, expression: newOperation, isImmutable: true)
        newBindings.append(newBinding)
        
        let newIdentifierExpr = IdentifierExpression(name: newName)
        
        let result = LinearizedNodeResult.id(newIdentifierExpr)
        return (result, newBindings)
    }
    
    func visitDefinition(
        _ definition: DefinitionNode,
        _ info: Void
    ) -> NewBindingInfo {
        let (newExpr, newBindings) = getNodeAndBindings(expression: definition.expression)
        
        let newDefinition = DefinitionNode(name: definition.name, type: .Bool, expression: newExpr, isImmutable: true)
        
        let result = LinearizedNodeResult.node(newDefinition)
        return (result, newBindings)
    }
    
    func visitFuncDefinition(
        _ definition: FuncDefinition,
        _ info: Void
    ) -> NewBindingInfo {
        let newBody = linearizeBlock(definition.body)
        let newFuncDef = FuncDefinition(
            name: definition.name,
            type: definition.type,
            parameters: definition.parameters,
            body: newBody,
            isEntry: definition.isEntry
        )
        
        let result = LinearizedNodeResult.node(newFuncDef)
        return (result, [])
    }
    
    func visitFuncApplication(
        _ expression: FuncApplication,
        _ info: Void
    ) -> NewBindingInfo {
        var bindings = [DefinitionNode]()
        var args = [any ExpressionNode]()
        expression.arguments.forEach { arg in
            let (newArg, newArgBindings) = getNodeAndBindings(expression: arg, bindings)
            args.append(newArg)
            bindings = newArgBindings
        }
        
        let newName = GenSymInfo.singleton.genSym(root: "func_app", id: expression.id)
        let newExpr = FuncApplication(name: expression.name, arguments: args)
        let newBinding = DefinitionNode(name: newName, type: .Bool, expression: newExpr, isImmutable: true)
        bindings.append(newBinding)
        
        let newIdentifierExpr = LinearizedNodeResult.id(IdentifierExpression(name: newName))
        
        return (newIdentifierExpr, bindings)
    }
    
    func visitIfStatement(
        _ statement: IfStatement,
        _ info: Void
    ) -> NewBindingInfo {
        let (newCond, bindings) = getNodeAndBindings(expression: statement.condition)
        
        let newThenBranch = linearizeBlock(statement.thenBranch)
        var newElseBranch: [any BlockLevelNode]? = nil
        if let elseBranch = statement.elseBranch {
            newElseBranch = linearizeBlock(elseBranch)
        }
        
        let newIfStatement = IfStatement(condition: newCond, thenBranch: newThenBranch, elseBranch: newElseBranch)
        let result = LinearizedNodeResult.node(newIfStatement)
        return (result, bindings)
    }
    
    func visitReturnStatement(
        _ statement: ReturnStatement,
        _ info: Void
    ) -> NewBindingInfo {
        let (newReturn, newBindings) = getNodeAndBindings(expression: statement.expression)
        
        let newStatement = ReturnStatement(expression: newReturn)
        let result = LinearizedNodeResult.node(newStatement)
        return (result, newBindings)
    }
    
    func visitAssignmentStatement(
        _ statement: AssignmentStatement,
        _ info: Void
    ) -> NewBindingInfo {
        let (newBoundExpr, newBindings) = getNodeAndBindings(expression: statement.expression)
        
        let newStatement = AssignmentStatement(name: statement.name, expression: newBoundExpr)
        let result = LinearizedNodeResult.node(newStatement)
        return (result, newBindings)

    }
    
    private func linearizeBlock(_ block: [any BlockLevelNode]) -> [any BlockLevelNode] {
        var newBlock = [any BlockLevelNode]()
        
        block.forEach { node in
            let (linearized, newBindings) = node.acceptVisitor(self)
            let result = unwrap(linearized: linearized) as! any BlockLevelNode
            newBlock.append(contentsOf: newBindings)
            newBlock.append(result)
        }
        
        return newBlock
    }
    
    func linearize(_ ast: TopLevel) -> TopLevel {
        let sections = ast.sections
        var transformedSections: [any TopLevelNode] = []
        
        sections.forEach { section in
            let (linearized, _) = section.acceptVisitor(self)
            let result = unwrap(linearized: linearized) as! any TopLevelNode
            transformedSections.append(result)
        }
        
        return TopLevel(sections: transformedSections)
    }
}

final class GenSymInfo: @unchecked Sendable {
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
