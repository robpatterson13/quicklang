//
//  ASTVisitor.swift
//  quicklang
//
//  Created by Rob Patterson on 11/15/25.
//

/// Protocol for read-only AST traversal using double-dispatch.
///
/// Conforming types implement per-node visit methods. Nodes call back into the
/// appropriate method via `acceptVisitor`, enabling operations like analysis,
/// printing, or metrics without modifying the tree.
protocol ASTVisitor {
    
    /// Visits an identifier expression.
    ///
    /// Use to inspect referenced names or collect usage information.
    func visitIdentifierExpression(_ expression: IdentifierExpression)
    
    /// Visits a boolean literal expression.
    ///
    /// Use to collect literals or validate usage context.
    func visitBooleanExpression(_ expression: BooleanExpression)
    
    /// Visits a numeric literal expression.
    ///
    /// Use to collect literals or validate usage context.
    func visitNumberExpression(_ expression: NumberExpression)
    
    /// Visits a unary operation.
    ///
    /// Use to analyze the operator and its operand.
    func visitUnaryOperation(_ operation: UnaryOperation)
    
    /// Visits a binary operation.
    ///
    /// Use to analyze the operator and both operands.
    func visitBinaryOperation(_ operation: BinaryOperation)
    
    /// Visits a `let` definition.
    ///
    /// Use to inspect declared names, optional annotations, and initializers.
    func visitLetDefinition(_ definition: LetDefinition)
    
    /// Visits a `var` definition.
    ///
    /// Use to inspect declared names, optional annotations, and initializers.
    func visitVarDefinition(_ definition: VarDefinition)
    
    /// Visits a function definition.
    ///
    /// Use to inspect the name, parameters, return type, and body.
    func visitFuncDefinition(_ definition: FuncDefinition)
    
    /// Visits a function application.
    ///
    /// Use to inspect the callee and its arguments.
    func visitFuncApplication(_ expression: FuncApplication)
    
    /// Visits an `if` statement.
    ///
    /// Use to inspect the condition and both branches.
    func visitIfStatement(_ statement: IfStatement)
    
    /// Visits a `return` statement.
    ///
    /// Use to inspect the returned expression.
    func visitReturnStatement(_ statement: ReturnStatement)
    
    func visitAssignmentStatement(_ statement: AssignmentStatement)
}
