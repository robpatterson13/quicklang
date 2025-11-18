//
//  ASTUpwardTransformer.swift
//  quicklang
//
//  Created by Rob Patterson on 11/16/25.
//

/// Protocol for AST-to-AST transformation with strictly upward information flow (child → parent).
///
/// Conforming transformers traverse nodes and may synthesize auxiliary information while
/// transforming children. Each visit method receives a completion callback
/// (`OnTransformEnd`) that must be invoked with the (possibly rewritten) node and a
/// `TransformerInfo` payload. Parents receive only what children return via this callback;
/// no information is pushed downward. This one-way design enables parents to aggregate
/// results from their children (for example, to insert temporaries or collect diagnostics)
/// before finalizing their own transformed node.
protocol ASTUpwardTransformer {
    
    /// The per-visit information synthesized by children and propagated upward to parents.
    ///
    /// Implementations choose an appropriate payload (e.g., a list of synthesized
    /// bindings, diagnostics, or metadata). Parents receive only the information
    /// explicitly returned by their children; nothing is pushed from parent to child.
    associatedtype TransformerInfo
    
    /// Completion callback type used by a node to return its transformed self along with
    /// the synthesized `TransformerInfo` that must flow upward to its parent.
    ///
    /// The callback must be invoked exactly once per visit, and it must carry all
    /// information the parent needs. Because the flow is strictly upward, parents
    /// cannot provide additional context back to children.
    typealias OnTransformEnd<Node: ASTNode> = (Node, TransformerInfo) -> ()
    
    /// Visits an identifier expression and reports the result via the upward-only callback.
    ///
    /// Implementations should return the transformed identifier (often unchanged) and
    /// any information that should be propagated to the parent.
    func visitIdentifierExpression(_ expression: IdentifierExpression, _ finished: @escaping OnTransformEnd<IdentifierExpression>)
    
    /// Visits a boolean literal expression and reports the result via the upward-only callback.
    ///
    /// Literal nodes typically propagate no additional information, but they must still
    /// complete by calling `finished`.
    func visitBooleanExpression(_ expression: BooleanExpression, _ finished: @escaping OnTransformEnd<BooleanExpression>)
    
    /// Visits a numeric literal expression and reports the result via the upward-only callback.
    ///
    /// Literal nodes typically propagate no additional information, but they must still
    /// complete by calling `finished`.
    func visitNumberExpression(_ expression: NumberExpression, _ finished: @escaping OnTransformEnd<NumberExpression>)
    
    /// Visits a unary operation and reports the result via the upward-only callback.
    ///
    /// Children must be transformed first so their `TransformerInfo` can be aggregated
    /// by the parent. Any synthesized information from the operand is combined and
    /// returned upward together with the transformed unary node.
    func visitUnaryOperation(_ operation: UnaryOperation, _ finished: @escaping OnTransformEnd<UnaryOperation>)
    
    /// Visits a binary operation and reports the result via the upward-only callback.
    ///
    /// Implementations transform `lhs` and `rhs`, aggregate their `TransformerInfo`,
    /// and then return the transformed binary operation and the combined information
    /// strictly upward to the parent.
    func visitBinaryOperation(_ operation: BinaryOperation, _ finished: @escaping OnTransformEnd<BinaryOperation>)
    
    /// Visits a `let` definition and reports the result via the upward-only callback.
    ///
    /// Any information introduced while transforming the initializer must be included
    /// in the callback so the parent can place synthesized constructs before the
    /// transformed definition.
    func visitLetDefinition(_ definition: LetDefinition, _ finished: @escaping OnTransformEnd<LetDefinition>)
    
    /// Visits a `var` definition and reports the result via the upward-only callback.
    ///
    /// Any information introduced while transforming the initializer must be included
    /// in the callback so the parent can place synthesized constructs before the
    /// transformed definition.
    func visitVarDefinition(_ definition: VarDefinition, _ finished: @escaping OnTransformEnd<VarDefinition>)
    
    /// Visits a function definition and reports the result via the upward-only callback.
    ///
    /// Implementations should transform the body by visiting its children first, collect
    /// and aggregate their `TransformerInfo`, and then return the transformed function
    /// along with any information that must appear before it in the parent context.
    func visitFuncDefinition(_ definition: FuncDefinition, _ finished: @escaping OnTransformEnd<FuncDefinition>)
    
    /// Visits a function application and reports the result via the upward-only callback.
    ///
    /// Arguments must be transformed first. Any synthesized information from arguments
    /// is aggregated and returned upward together with the transformed call expression.
    func visitFuncApplication(_ expression: FuncApplication, _ finished: @escaping OnTransformEnd<FuncApplication>)
    
    /// Visits an `if` statement and reports the result via the upward-only callback.
    ///
    /// The condition and both branches should be transformed first. Any synthesized
    /// information from these children is aggregated and returned upward with the
    /// transformed `if` statement, allowing the parent to order any required
    /// constructs before the statement.
    func visitIfStatement(_ statement: IfStatement, _ finished: @escaping OnTransformEnd<IfStatement>)
    
    /// Visits a `return` statement and reports the result via the upward-only callback.
    ///
    /// The returned expression should be transformed first; any synthesized information
    /// from that transformation is aggregated and returned upward with the transformed
    /// `return` statement.
    func visitReturnStatement(_ statement: ReturnStatement, _ finished: @escaping OnTransformEnd<ReturnStatement>)
    
}
