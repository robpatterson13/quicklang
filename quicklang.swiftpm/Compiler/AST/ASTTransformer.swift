//
//  ASTTransformer.swift
//  quicklang
//
//  Created by Rob Patterson on 11/16/25.
//

/// Protocol for AST-to-AST transformation with upward information flow.
///
/// Conforming types walk nodes and may produce synthesized information while
/// transforming children. Each visit method receives a completion callback
/// (`OnTransformEnd`) that must be invoked with the (possibly rewritten) node
/// and a `TransformerInfo` payload. This design lets information flow back up
/// the tree from children to their parents (e.g., introducing temporaries or
/// collecting diagnostics) before the parent finalizes its own result.
protocol ASTTransformer {
    
    /// The per-visit information synthesized during transformation.
    ///
    /// Implementations choose the payload type (e.g., arrays of new bindings,
    /// diagnostics, or metadata) to pass upward from children to parents.
    associatedtype TransformerInfo
    /// Completion callback type used by nodes to return their transformed self
    /// along with any synthesized `TransformerInfo` for the parent to consume.
    typealias OnTransformEnd<Node: ASTNode> = (Node, TransformerInfo) -> ()
    
    /// Visits an identifier expression and reports the result via the callback.
    func visitIdentifierExpression(_ expression: IdentifierExpression, _ finished: @escaping OnTransformEnd<IdentifierExpression>)
    
    /// Visits a boolean literal expression and reports the result via the callback.
    func visitBooleanExpression(_ expression: BooleanExpression, _ finished: @escaping OnTransformEnd<BooleanExpression>)
    
    /// Visits a numeric literal expression and reports the result via the callback.
    func visitNumberExpression(_ expression: NumberExpression, _ finished: @escaping OnTransformEnd<NumberExpression>)
    
    /// Visits a unary operation and reports the result via the callback.
    ///
    /// Children should be transformed first so their `TransformerInfo` can be
    /// propagated upward to inform the parent’s result.
    func visitUnaryOperation(_ operation: UnaryOperation, _ finished: @escaping OnTransformEnd<UnaryOperation>)
    
    /// Visits a binary operation and reports the result via the callback.
    ///
    /// Transformations typically combine children’s results and aggregate their
    /// `TransformerInfo` before finalizing the parent node.
    func visitBinaryOperation(_ operation: BinaryOperation, _ finished: @escaping OnTransformEnd<BinaryOperation>)
    
    /// Visits a `let` definition and reports the result via the callback.
    func visitLetDefinition(_ definition: LetDefinition, _ finished: @escaping OnTransformEnd<LetDefinition>)
    
    /// Visits a `var` definition and reports the result via the callback.
    func visitVarDefinition(_ definition: VarDefinition, _ finished: @escaping OnTransformEnd<VarDefinition>)
    
    /// Visits a function definition and reports the result via the callback.
    func visitFuncDefinition(_ definition: FuncDefinition, _ finished: @escaping OnTransformEnd<FuncDefinition>)
    
    /// Visits a function application and reports the result via the callback.
    func visitFuncApplication(_ expression: FuncApplication, _ finished: @escaping OnTransformEnd<FuncApplication>)
    
    /// Visits an `if` statement and reports the result via the callback.
    func visitIfStatement(_ statement: IfStatement, _ finished: @escaping OnTransformEnd<IfStatement>)
    
    /// Visits a `return` statement and reports the result via the callback.
    func visitReturnStatement(_ statement: ReturnStatement, _ finished: @escaping OnTransformEnd<ReturnStatement>)
    
}
