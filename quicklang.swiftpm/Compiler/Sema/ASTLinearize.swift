//
//  ASTLinearize.swift
//  quicklang
//
//  Created by Rob Patterson on 11/16/25.
//

import Foundation

/// This class takes all constant subexpressions (i.e., arithmetic on numbers) and promotes them to bindings **above** the expression in which they are used.
///
/// For example, we transform `let a: Int = 10 + 10 + 40;` into
/// ```
/// let x: Int = 10 + 10;
/// let y: Int = x + 40;
/// let a: Int = y
/// ```
/// We keep boolean expressions as they are; this is so we can implement short circuiting later when we construct the CFG.
/// In short, this means that we take boolean expressions and convert them into control flow. If we were to let bind boolean expressions, then we would evaluate
/// all subexpressions in a boolean operation (bad!)
///
/// - SeeAlso: ``ConvertToRawFIR``
class ASTLinearize: SemaPass, ASTVisitor {
    typealias NewBindingInfo = (LinearizedNodeResult, [DefinitionNode], SafeToIntroduceBinding)
    
    func begin(reportingTo: CompilerErrorManager) {
        let linearized = linearize(context.tree)
        context.changeAST(linearized)
    }
    
    let context: ASTContext
    
    init(context: ASTContext) {
        self.context = context
    }
    
    // passed to a subexpression's parent expr;
    // tells the parent expression whether it should
    // let bind
    //
    // "spoiling" semantics; if any of an expression's
    // subexpressions cannot be let bound, then the
    // expression cannot be let bound!
    enum SafeToIntroduceBinding {
        case yes
        case no
    }
    
    enum LinearizedNodeResult {
        case node(any ASTNode)
        case id(IdentifierExpression)
    }
    
    struct LinearizeContext: Equatable {
        enum ShouldLetBindExpression {
            case letBindEverything
            case onlyLetBindConstantExpressions
        }
        
        let shouldLetBindExpression: ShouldLetBindExpression?
        
        private init(shouldLetBindExpression: ShouldLetBindExpression?) {
            self.shouldLetBindExpression = shouldLetBindExpression
        }
        
        static let onlyBindConstants: Self = .init(shouldLetBindExpression: .onlyLetBindConstantExpressions)
        static let letBindEverything: Self = .init(shouldLetBindExpression: .letBindEverything)
    }
    
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
        context: LinearizeContext,
        _ existingBindings: [DefinitionNode]? = nil
    ) -> ((any ExpressionNode), [DefinitionNode], SafeToIntroduceBinding) {
        
        let (linearized, bindings, safeToIntroduceBinding) = expression.acceptVisitor(self, context)
        let newExpr = unwrap(linearized: linearized)
        
        let newBindings: [DefinitionNode]
        if let existingBindings {
            newBindings = bindings + existingBindings
        } else {
            newBindings = bindings
        }
        
        // we can force unwrap as node has to be an expression
        // it'll either be itself, or an IdentifierExpression
        return (newExpr as! any ExpressionNode, newBindings, safeToIntroduceBinding)
    }
    
    func visitIdentifierExpression(
        _ expression: IdentifierExpression,
        _ info: LinearizeContext
    ) -> NewBindingInfo {
        return (.node(expression), [], .yes)
    }
    
    func visitBooleanExpression(
        _ expression: BooleanExpression,
        _ info: LinearizeContext
    ) -> NewBindingInfo {
        return (.node(expression), [], .yes)
    }
    
    func visitNumberExpression(
        _ expression: NumberExpression,
        _ info: LinearizeContext
    ) -> NewBindingInfo {
        return (.node(expression), [], .yes)
    }
    
    func visitUnaryOperation(
        _ operation: UnaryOperation,
        _ info: LinearizeContext
    ) -> NewBindingInfo {
        var (newExpr, newBindings, safeToIntroduceBinding) = getNodeAndBindings(expression: operation.expression, context: info)
        
        if safeToIntroduceBinding == .yes {
            let newName = GenSymInfo.singleton.genSym(root: "unary_op", id: operation.id)
            let newOperation = UnaryOperation(op: operation.op, expression: newExpr)
            let newBinding = DefinitionNode(name: newName, type: .Bool, expression: newOperation, isImmutable: true)
            newBindings.append(newBinding)
            
            let newIdentifierExpr = IdentifierExpression(name: newName)
            
            let result = LinearizedNodeResult.id(newIdentifierExpr)
            return (result, newBindings, .yes)
        } else {
            let newOperation = UnaryOperation(op: operation.op, expression: newExpr)
            let result = LinearizedNodeResult.node(newOperation)
            return (result, newBindings, .no)
        }
    }
    
    func visitBinaryOperation(
        _ operation: BinaryOperation,
        _ info: LinearizeContext
    ) -> NewBindingInfo {
        let (newLhs, lhsBindings, safeToIntroduceBinding) = getNodeAndBindings(expression: operation.lhs, context: info)
        
        let needToShortCircuit = operation.op.isBoolean || info == .onlyBindConstants
        if safeToIntroduceBinding == .no || needToShortCircuit {
            let (newRhs, newBindings, _) = getNodeAndBindings(expression: operation.rhs, context: .onlyBindConstants, lhsBindings)
            let newOperation = BinaryOperation(op: operation.op, lhs: newLhs, rhs: newRhs)
            
            let result = LinearizedNodeResult.node(newOperation)
            return (result, newBindings, .no)
        }
        
        var (newRhs, newBindings, safeToIntroduceBindingFromRhs) = getNodeAndBindings(expression: operation.rhs, context: .letBindEverything, lhsBindings)
        if safeToIntroduceBindingFromRhs == .yes {
            let newOperation = BinaryOperation(op: operation.op, lhs: newLhs, rhs: newRhs)
            
            let newName = GenSymInfo.singleton.genSym(root: "binary_op", id: operation.id)
            let newBinding = DefinitionNode(name: newName, type: .Bool, expression: newOperation, isImmutable: true)
            newBindings.append(newBinding)
            
            let newIdentifierExpr = IdentifierExpression(name: newName)
            
            let result = LinearizedNodeResult.id(newIdentifierExpr)
            return (result, newBindings, .yes)
        } else {
            let newOperation = BinaryOperation(op: operation.op, lhs: newLhs, rhs: newRhs)
            
            let result = LinearizedNodeResult.node(newOperation)
            return (result, newBindings, .no)
        }
    }
    
    func visitDefinition(
        _ definition: DefinitionNode,
        _ info: LinearizeContext
    ) -> NewBindingInfo {
        // we dont care about let binding this because definitions can't be let bound
        let (newExpr, newBindings, _) = getNodeAndBindings(expression: definition.expression, context: .letBindEverything)
        
        let newDefinition = DefinitionNode(name: definition.name, type: .Bool, expression: newExpr, isImmutable: true)
        
        let result = LinearizedNodeResult.node(newDefinition)
        return (result, newBindings, .yes)
    }
    
    func visitFuncDefinition(
        _ definition: FuncDefinition,
        _ info: LinearizeContext
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
        return (result, [], .yes)
    }
    
    func visitFuncApplication(
        _ expression: FuncApplication,
        _ info: LinearizeContext
    ) -> NewBindingInfo {
        
        // if we're short circuiting, don't let bind arguments or function call
        guard info == .letBindEverything else {
            return (.node(expression), [], .no)
        }
        
        var bindings = [DefinitionNode]()
        var args = [any ExpressionNode]()
        var safeToBind: [SafeToIntroduceBinding] = []
        expression.arguments.forEach { arg in
            let (newArg, newArgBindings, safeToIntroduceBinding) = getNodeAndBindings(expression: arg, context: info, bindings)
            args.append(newArg)
            bindings = newArgBindings
            safeToBind.append(safeToIntroduceBinding)
        }
        
        guard safeToBind.allSatisfy({ $0 == .yes }) else {
            let newExpr = FuncApplication(name: expression.name, arguments: args)
            let newApplication = LinearizedNodeResult.node(newExpr)
            
            return (newApplication, bindings, .no)
        }
        
        let newName = GenSymInfo.singleton.genSym(root: "func_app", id: expression.id)
        let newExpr = FuncApplication(name: expression.name, arguments: args)
        let newBinding = DefinitionNode(name: newName, type: .Bool, expression: newExpr, isImmutable: true)
        bindings.append(newBinding)
        
        let newIdentifierExpr = LinearizedNodeResult.id(IdentifierExpression(name: newName))
        
        return (newIdentifierExpr, bindings, .yes)
    }
    
    func visitIfStatement(
        _ statement: IfStatement,
        _ info: LinearizeContext
    ) -> NewBindingInfo {
        let (newCond, bindings, _) = getNodeAndBindings(expression: statement.condition, context: .letBindEverything)
        
        let newThenBranch = linearizeBlock(statement.thenBranch)
        var newElseBranch: [any BlockLevelNode]? = nil
        if let elseBranch = statement.elseBranch {
            newElseBranch = linearizeBlock(elseBranch)
        }
        
        let newIfStatement = IfStatement(condition: newCond, thenBranch: newThenBranch, elseBranch: newElseBranch)
        let result = LinearizedNodeResult.node(newIfStatement)
        return (result, bindings, .yes)
    }
    
    func visitReturnStatement(
        _ statement: ReturnStatement,
        _ info: LinearizeContext
    ) -> NewBindingInfo {
        let (newReturn, newBindings, _) = getNodeAndBindings(expression: statement.expression, context: .letBindEverything)
        
        let newStatement = ReturnStatement(expression: newReturn)
        let result = LinearizedNodeResult.node(newStatement)
        return (result, newBindings, .yes)
    }
    
    func visitAssignmentStatement(
        _ statement: AssignmentStatement,
        _ info: LinearizeContext
    ) -> NewBindingInfo {
        let (newBoundExpr, newBindings, _) = getNodeAndBindings(expression: statement.expression, context: .letBindEverything)
        
        let newStatement = AssignmentStatement(name: statement.name, expression: newBoundExpr)
        let result = LinearizedNodeResult.node(newStatement)
        return (result, newBindings, .yes)

    }
    
    private func linearizeBlock(_ block: [any BlockLevelNode]) -> [any BlockLevelNode] {
        var newBlock = [any BlockLevelNode]()
        
        block.forEach { node in
            let (linearized, newBindings, _) = node.acceptVisitor(self, .letBindEverything)
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
            let (linearized, _, _) = section.acceptVisitor(self, .letBindEverything)
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
        return root + "_$\(tag)$"
    }
    
    private init() {}
}
