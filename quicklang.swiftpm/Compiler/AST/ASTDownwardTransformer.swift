//
//  ASTDownwardTransformer.swift
//  quicklang
//
//  Created by Rob Patterson on 11/17/25.
//

/// Protocol for AST traversal/transformation with strictly downward information flow (parent → child).
///
/// Conforming transformers carry a `TransformationInfo` payload from parents to children
/// as they walk the tree. Parents may refine or extend this information and pass it to
/// their children, but children do not return information to their parents via this API.
/// This one-way design is useful for analyses that depend on ambient context such as
/// scope, symbol environments, or type expectations.
///
/// Typical uses include:
/// - Symbol resolution with a threaded scope (e.g., a set of in-scope bindings)
/// - Context-sensitive checks that rely on enclosing constructs
/// - Passes that annotate or validate nodes without needing child → parent feedback
protocol ASTDownwardTransformer {
    
    /// The per-visit context pushed from parents to children.
    ///
    /// Implementations choose an appropriate payload (e.g., a scope, constraints,
    /// or environment). Parents may derive a new `TransformationInfo` for a child,
    /// but children do not return information upward in this protocol.
    associatedtype TransformationInfo
    
    /// Visits an identifier expression with the current downward context.
    ///
    /// Use this to check that the referenced name is valid under the provided context
    /// (e.g., in-scope bindings) or to apply context-driven validation.
    func visitIdentifierExpression(_ expression: IdentifierExpression, _ info: TransformationInfo)
    
    /// Visits a boolean literal expression with the current downward context.
    ///
    /// Literal nodes typically do not consume contextual information, but the visit is
    /// provided for consistency and potential future needs.
    func visitBooleanExpression(_ expression: BooleanExpression, _ info: TransformationInfo)
    
    /// Visits a numeric literal expression with the current downward context.
    ///
    /// Literal nodes typically do not consume contextual information, but the visit is
    /// provided for consistency and potential future needs.
    func visitNumberExpression(_ expression: NumberExpression, _ info: TransformationInfo)
    
    /// Visits a unary operation with the current downward context.
    ///
    /// Implementations should propagate `info` to the operand before completing any
    /// context-dependent checks or transformations.
    func visitUnaryOperation(_ operation: UnaryOperation, _ info: TransformationInfo)
    
    /// Visits a binary operation with the current downward context.
    ///
    /// Implementations should propagate `info` to both `lhs` and `rhs` before completing
    /// any context-dependent checks or transformations.
    func visitBinaryOperation(_ operation: BinaryOperation, _ info: TransformationInfo)
    
    /// Visits a `let` definition with the current downward context.
    ///
    /// Implementations typically propagate `info` to the initializer expression and, if
    /// modeling scope, arrange for the declared name to be available to subsequent
    /// nodes in the same block (outside of this protocol).
    func visitLetDefinition(_ definition: LetDefinition, _ info: TransformationInfo)
    
    /// Visits a `var` definition with the current downward context.
    ///
    /// Implementations typically propagate `info` to the initializer expression and, if
    /// modeling scope, arrange for the declared name to be available to subsequent
    /// nodes in the same block (outside of this protocol).
    func visitVarDefinition(_ definition: VarDefinition, _ info: TransformationInfo)
    
    /// Visits a function definition with the current downward context.
    ///
    /// Implementations may extend the context for the function body (e.g., add the
    /// function name or parameters to scope) and then propagate that context to the
    /// body’s children.
    func visitFuncDefinition(_ definition: FuncDefinition, _ info: TransformationInfo)
    
    /// Visits a function application with the current downward context.
    ///
    /// Implementations typically validate the callee under `info` and propagate `info`
    /// to each argument expression.
    func visitFuncApplication(_ expression: FuncApplication, _ info: TransformationInfo)
    
    /// Visits an `if` statement with the current downward context.
    ///
    /// Implementations should propagate `info` to the condition and both branches.
    /// If modeling scope, branch-local bindings should not leak across branches or
    /// outward via this protocol.
    func visitIfStatement(_ statement: IfStatement, _ info: TransformationInfo)
    
    /// Visits a `return` statement with the current downward context.
    ///
    /// Implementations typically propagate `info` to the returned expression to perform
    /// any context-sensitive checks or transformations.
    func visitReturnStatement(_ statement: ReturnStatement, _ info: TransformationInfo)
}
