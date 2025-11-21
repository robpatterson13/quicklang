//
//  SymbolResolve.swift
//  quicklang
//
//  Created by Rob Patterson on 11/15/25.
//

class AllowsRecursiveDefinition: ASTUpwardTransformer {
    
    enum Verdict {
        case no
        case yes
        case notApplicable
    }
    
    typealias TransformerInfo = Verdict
    
    static var shared: AllowsRecursiveDefinition {
        AllowsRecursiveDefinition()
    }
    
    private init() {}
    
    func visitIdentifierExpression(
        _ expression: IdentifierExpression,
        _ finished: @escaping OnTransformEnd<IdentifierExpression>
    ) {
        finished(expression, .notApplicable)
    }
    
    func visitBooleanExpression(
        _ expression: BooleanExpression,
        _ finished: @escaping OnTransformEnd<BooleanExpression>
    ) {
        finished(expression, .notApplicable)
    }
    
    func visitNumberExpression(
        _ expression: NumberExpression,
        _ finished: @escaping OnTransformEnd<NumberExpression>
    ) {
        finished(expression, .notApplicable)
    }
    
    func visitUnaryOperation(
        _ operation: UnaryOperation,
        _ finished: @escaping OnTransformEnd<UnaryOperation>
    ) {
        finished(operation, .notApplicable)
    }
    
    func visitBinaryOperation(
        _ operation: BinaryOperation,
        _ finished: @escaping OnTransformEnd<BinaryOperation>
    ) {
        finished(operation, .notApplicable)
    }
    
    func visitLetDefinition(
        _ definition: LetDefinition,
        _ finished: @escaping OnTransformEnd<LetDefinition>
    ) {
        finished(definition, .no)
    }
    
    func visitVarDefinition(
        _ definition: VarDefinition,
        _ finished: @escaping OnTransformEnd<VarDefinition>
    ) {
        finished(definition, .no)
    }
    
    func visitFuncDefinition(
        _ definition: FuncDefinition,
        _ finished: @escaping OnTransformEnd<FuncDefinition>
    ) {
        finished(definition, .yes)
    }
    
    func visitFuncApplication(
        _ expression: FuncApplication,
        _ finished: @escaping OnTransformEnd<FuncApplication>
    ) {
        finished(expression, .notApplicable)
    }
    
    func visitIfStatement(
        _ statement: IfStatement,
        _ finished: @escaping OnTransformEnd<IfStatement>
    ) {
        finished(statement, .notApplicable)
    }
    
    func visitReturnStatement(
        _ statement: ReturnStatement,
        _ finished: @escaping OnTransformEnd<ReturnStatement>
    ) {
        finished(statement, .notApplicable)
    }
    
}

/// Collects names introduced by AST nodes during an upward (child → parent) traversal.
///
/// ``SymbolGrabber`` is an implementation of ``ASTUpwardTransformer`` that does not
/// rewrite nodes. Instead, it reports which bindings a node introduces to its
/// enclosing scope. ``SymbolResolve`` uses this information to implement progressive
/// block scoping:
///
/// - After validating a statement against the current scope (downward traversal),
///   the resolver asks ``SymbolGrabber`` which names that statement declares (upward traversal).
/// - The resolver then extends the scope so subsequent statements in the same block
///   can see those names.
///
/// - Important: This transformer only reports bindings; it does not model visibility
///   across sibling branches of control flow. Branch-local bindings are handled by
///   the block-processing logic in ``SymbolResolve``.
///
/// - Returns: For declaration nodes, an array containing the declared name; for all
///   other nodes, an empty array.
class SymbolGrabber: ASTUpwardTransformer {
    
    /// A single binding introduced into the surrounding scope (variable or function name).
    typealias Binding = String
    
    /// The upward payload returned to parents: a list of introduced binding names.
    typealias TransformerInfo = [Binding]
    
    static var shared: SymbolGrabber {
        SymbolGrabber()
    }
    
    private init() {}
    
    /// Identifiers do not introduce new bindings.
    ///
    /// - Parameters:
    ///   - expression: The identifier expression being visited.
    ///   - finished: The upward-only completion callback that must be invoked with the
    ///     original node and the empty binding list.
    func visitIdentifierExpression(
        _ expression: IdentifierExpression,
        _ finished: @escaping OnTransformEnd<IdentifierExpression>
    ) {
        finished(expression, [])
    }
    
    /// Boolean literals do not introduce new bindings.
    ///
    /// - Parameters:
    ///   - expression: The boolean literal being visited.
    ///   - finished: The upward-only completion callback that must be invoked with the
    ///     original node and the empty binding list.
    func visitBooleanExpression(
        _ expression: BooleanExpression,
        _ finished: @escaping OnTransformEnd<BooleanExpression>
    ) {
        finished(expression, [])
    }
    
    /// Number literals do not introduce new bindings.
    ///
    /// - Parameters:
    ///   - expression: The number literal being visited.
    ///   - finished: The upward-only completion callback that must be invoked with the
    ///     original node and the empty binding list.
    func visitNumberExpression(
        _ expression: NumberExpression,
        _ finished: @escaping OnTransformEnd<NumberExpression>
    ) {
        finished(expression, [])
    }
    
    /// Unary operations do not introduce new bindings.
    ///
    /// - Parameters:
    ///   - operation: The unary operation being visited.
    ///   - finished: The upward-only completion callback that must be invoked with the
    ///     original node and the empty binding list.
    func visitUnaryOperation(
        _ operation: UnaryOperation,
        _ finished: @escaping OnTransformEnd<UnaryOperation>
    ) {
        finished(operation, [])
    }
    
    /// Binary operations do not introduce new bindings.
    ///
    /// - Parameters:
    ///   - operation: The binary operation being visited.
    ///   - finished: The upward-only completion callback that must be invoked with the
    ///     original node and the empty binding list.
    func visitBinaryOperation(
        _ operation: BinaryOperation,
        _ finished: @escaping OnTransformEnd<BinaryOperation>
    ) {
        finished(operation, [])
    }
    
    /// A `let` definition introduces an immutable binding for its name.
    ///
    /// - Parameters:
    ///   - definition: The ``LetDefinition`` being visited.
    ///   - finished: The upward-only completion callback with the original node and
    ///     `[definition.name]`.
    /// - Returns: `[definition.name]`.
    func visitLetDefinition(
        _ definition: LetDefinition,
        _ finished: @escaping OnTransformEnd<LetDefinition>
    ) {
        finished(definition, [definition.name])
    }
    
    /// A `var` definition introduces a mutable binding for its name.
    ///
    /// - Parameters:
    ///   - definition: The ``VarDefinition`` being visited.
    ///   - finished: The upward-only completion callback with the original node and
    ///     `[definition.name]`.
    /// - Returns: `[definition.name]`.
    func visitVarDefinition(
        _ definition: VarDefinition,
        _ finished: @escaping OnTransformEnd<VarDefinition>
    ) {
        finished(definition, [definition.name])
    }
    
    /// A function definition introduces a binding for the function name in the enclosing scope.
    ///
    /// This allows the function to be referenced by name in subsequent statements in the
    /// same block and enables recursion (when combined with the resolver’s body analysis).
    ///
    /// - Parameters:
    ///   - definition: The ``FuncDefinition`` being visited.
    ///   - finished: The upward-only completion callback with the original node and
    ///     `[definition.name]`.
    /// - Returns: `[definition.name]`.
    func visitFuncDefinition(
        _ definition: FuncDefinition,
        _ finished: @escaping OnTransformEnd<FuncDefinition>
    ) {
        finished(definition, [definition.name])
    }
    
    /// Function applications do not introduce new bindings.
    ///
    /// - Parameters:
    ///   - expression: The ``FuncApplication`` being visited.
    ///   - finished: The upward-only completion callback with the original node and `[]`.
    func visitFuncApplication(
        _ expression: FuncApplication,
        _ finished: @escaping OnTransformEnd<FuncApplication>
    ) {
        finished(expression, [])
    }
    
    /// If statements do not introduce bindings at the statement boundary.
    ///
    /// - Important: Any bindings created inside branches are local to those branches and
    ///   are handled by block processing, not by this grabber directly.
    ///
    /// - Parameters:
    ///   - statement: The ``IfStatement`` being visited.
    ///   - finished: The upward-only completion callback with the original node and `[]`.
    func visitIfStatement(
        _ statement: IfStatement,
        _ finished: @escaping OnTransformEnd<IfStatement>
    ) {
        finished(statement, [])
    }
    
    /// Return statements do not introduce new bindings.
    ///
    /// - Parameters:
    ///   - statement: The ``ReturnStatement`` being visited.
    ///   - finished: The upward-only completion callback with the original node and `[]`.
    func visitReturnStatement(
        _ statement: ReturnStatement,
        _ finished: @escaping OnTransformEnd<ReturnStatement>
    ) {
        finished(statement, [])
    }
    
}

/// Performs symbol resolution with progressive block-level scoping using a downward (parent → child) traversal.
///
/// ``SymbolResolve`` implements ``ASTDownwardTransformer`` and validates name usage by
/// threading a scope (an ordered list of visible names) down the AST:
///
/// - References (``IdentifierExpression`` and ``FuncApplication``) are checked against the current scope.
/// - Within a block, each statement is analyzed with the scope produced by all prior statements.
/// - Function bodies are analyzed in a scope extended with the function’s own name (to enable recursion)
///   and all parameter names.
/// - Branch-local bindings in ``IfStatement`` do not leak between branches or to the outer scope.
///
/// Implementation details:
/// - Downward validation: each node is visited with the current scope.
/// - Progressive scoping: after each block-level node, an upward pass using ``SymbolGrabber``
///   discovers newly introduced names, which are appended to the scope for subsequent nodes.
///
/// - Note: Diagnostics emission is stubbed out in this file and can be integrated with
///   ``CompilerErrorManager`` as needed.
class SymbolResolve: SemaPass, ASTDownwardTransformer {
    
    /// Entry point for this semantic pass.
    ///
    /// Implementations should traverse the program and report diagnostics to the provided
    /// ``CompilerErrorManager``. This stub ensures conformance to ``SemaPass``.
    ///
    /// - Parameter reportingTo: The compiler’s error manager used to record diagnostics.
    func begin(reportingTo: CompilerErrorManager) {
        let tree = context.tree
        
        tree.sections.forEach { node in
            var canBeRecursive: AllowsRecursiveDefinition.Verdict? = nil
            node.acceptUpwardTransformer(AllowsRecursiveDefinition.shared) { _, verdict in
                canBeRecursive = verdict
            }
            
            var exclude: String? = nil
            switch canBeRecursive {
            case .no:
                node.acceptUpwardTransformer(SymbolGrabber.shared) { _, binding in
                    exclude = binding.first
                }
            case .yes, .notApplicable:
                break
            case nil:
                fatalError("Not possible")
            }
            
            let globals = context.getGlobalSymbols(excluding: exclude)
            node.acceptDownwardTransformer(self, globals)
        }
    }
    
    /// A single binding name currently visible at a program point.
    ///
    /// Bindings are tracked as simple strings (variable and function names).
    typealias BindingInScope = String
    
    /// Shared semantic context (types, symbol metadata, etc.).
    ///
    /// Currently unused by this pass but available for integration with other phases.
    let context: ASTContext
    
    /// Creates a symbol resolver bound to the shared semantic context.
    ///
    /// - Parameter context: The shared ``ASTContext`` for semantic analysis.
    init(context: ASTContext) {
        self.context = context
    }
    
    // MARK: - Expressions
    
    /// Validates that an identifier reference is bound in the current scope.
    ///
    /// - Parameters:
    ///   - expression: The ``IdentifierExpression`` being visited.
    ///   - info: The current scope as an ordered list of visible names.
    /// - Important: If the identifier is not found, a diagnostic should be recorded via
    ///   ``CompilerErrorManager`` (not implemented here).
    func visitIdentifierExpression(
        _ expression: IdentifierExpression,
        _ info: [BindingInScope]
    ) {
        if !info.contains(where: { $0 == expression.name }) {
            // MARK: Unbound
            // Intention: record or emit a diagnostic for an unbound identifier.
        }
    }
    
    /// Boolean literals require no symbol validation.
    ///
    /// - Parameters:
    ///   - expression: The ``BooleanExpression`` being visited.
    ///   - info: The current scope (unused).
    func visitBooleanExpression(
        _ expression: BooleanExpression,
        _ info: [BindingInScope]
    ) {
        // no-op
    }
    
    /// Number literals require no symbol validation.
    ///
    /// - Parameters:
    ///   - expression: The ``NumberExpression`` being visited.
    ///   - info: The current scope (unused).
    func visitNumberExpression(
        _ expression: NumberExpression,
        _ info: [BindingInScope]
    ) {
        // no-op
    }
    
    /// Validates a unary operation by resolving its operand under the current scope.
    ///
    /// - Parameters:
    ///   - operation: The ``UnaryOperation`` being visited.
    ///   - info: The current scope.
    func visitUnaryOperation(
        _ operation: UnaryOperation,
        _ info: [BindingInScope]
    ) {
        operation.expression.acceptDownwardTransformer(self, info)
    }
    
    /// Validates a binary operation by resolving both operands under the current scope.
    ///
    /// - Parameters:
    ///   - operation: The ``BinaryOperation`` being visited.
    ///   - info: The current scope.
    func visitBinaryOperation(
        _ operation: BinaryOperation,
        _ info: [BindingInScope]
    ) {
        operation.lhs.acceptDownwardTransformer(self, info)
        operation.rhs.acceptDownwardTransformer(self, info)
    }
    
    // MARK: - Definitions
    
    /// Checks a `let` definition for shadowing and validates its initializer under the current scope.
    ///
    /// The new binding becomes visible to subsequent statements in the same block via
    /// progressive scoping (see ``processBlock(_:_: )``).
    ///
    /// - Parameters:
    ///   - definition: The ``LetDefinition`` being visited.
    ///   - info: The current scope.
    func visitLetDefinition(
        _ definition: LetDefinition,
        _ info: [BindingInScope]
    ) {
        enforceNoShadowing(for: definition.name, scope: info)
        definition.expression.acceptDownwardTransformer(self, info)
    }
    
    /// Checks a `var` definition for shadowing and validates its initializer under the current scope.
    ///
    /// The new binding becomes visible to subsequent statements in the same block via
    /// progressive scoping (see ``processBlock(_:_: )``).
    ///
    /// - Parameters:
    ///   - definition: The ``VarDefinition`` being visited.
    ///   - info: The current scope.
    func visitVarDefinition(
        _ definition: VarDefinition,
        _ info: [BindingInScope]
    ) {
        enforceNoShadowing(for: definition.name, scope: info)
        definition.expression.acceptDownwardTransformer(self, info)
    }
    
    /// Analyzes a function definition with a scope extended by the function name and its parameters.
    ///
    /// Steps:
    /// 1. Disallow shadowing of the function name and parameter names.
    /// 2. Enforce unique parameter names.
    /// 3. Analyze the body using a scope that includes the function’s own name (enables recursion)
    ///    and all parameter names.
    ///
    /// - Parameters:
    ///   - definition: The ``FuncDefinition`` being visited.
    ///   - info: The incoming scope.
    func visitFuncDefinition(
        _ definition: FuncDefinition,
        _ info: [BindingInScope]
    ) {
        enforceNoShadowing(for: definition.name, scope: info)
        definition.parameters.forEach { param in
            enforceNoShadowing(for: param.name, scope: info)
        }
        
        enforceUniqueParameterNames(definition.parameters)
        
        var newInfo = info
        newInfo.append(definition.name)
        let parameters = definition.parameters.map { $0.name }
        newInfo.append(contentsOf: parameters)
        processBlock(definition.body, newInfo)
    }
    
    /// Ensures parameter names are unique within the function’s parameter list.
    ///
    /// - Parameter params: The parameter list from a ``FuncDefinition``.
    /// - Important: Duplicate parameter names would be ambiguous when referenced inside the body.
    private func enforceUniqueParameterNames(_ params: [FuncDefinition.Parameter]) {
        let paramNames = params.map { $0.name }
        let paramSet = Set(arrayLiteral: paramNames)
        
        guard paramSet.count == paramNames.count else {
            // MARK: Param names must be unique
            return
        }
    }
    
    /// Disallows declaring a binding that is already visible in the current scope.
    ///
    /// - Parameters:
    ///   - binding: The name being introduced.
    ///   - scope: The current list of visible names.
    /// - Important: Shadowing makes references ambiguous and is rejected by this pass.
    private func enforceNoShadowing(for binding: String, scope: [BindingInScope]) {
        guard !scope.contains(binding) else {
            // MARK: Shadowing not allowed
            return
        }
    }
    
    // MARK: - Applications and Control Flow
    
    /// Validates a function application by checking the callee is bound and resolving all arguments.
    ///
    /// - Parameters:
    ///   - expression: The ``FuncApplication`` being visited.
    ///   - info: The current scope.
    func visitFuncApplication(
        _ expression: FuncApplication,
        _ info: [BindingInScope]
    ) {
        if !info.contains(where: { $0 == expression.name }) {
            // MARK: Unbound
            // Intention: record or emit a diagnostic for an unbound function name.
        }
        
        expression.arguments.forEach { $0.acceptDownwardTransformer(self, info) }
    }
    
    /// Validates an `if` statement by checking the condition and analyzing both branches independently.
    ///
    /// - Parameters:
    ///   - statement: The ``IfStatement`` being visited.
    ///   - info: The current scope.
    /// - Important: Both branches are visited with the same incoming scope. Bindings declared
    ///   within one branch do not leak to the other branch or the outer scope.
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
    
    /// Validates a `return` statement by resolving its expression under the current scope.
    ///
    /// - Parameters:
    ///   - statement: The ``ReturnStatement`` being visited.
    ///   - info: The current scope.
    func visitReturnStatement(
        _ statement: ReturnStatement,
        _ info: [BindingInScope]
    ) {
        statement.expression.acceptDownwardTransformer(self, info)
    }
    
    // MARK: - Block Processing
    
    /// Processes a block with progressive scoping: each statement sees bindings introduced by prior statements.
    ///
    /// Algorithm per statement:
    /// 1. Validate the statement under the current accumulated scope (downward traversal).
    /// 2. Ask ``SymbolGrabber`` which bindings this statement introduces (upward traversal).
    /// 3. Append those bindings to the scope for subsequent statements.
    ///
    /// Example:
    /// ```swift
    /// let x = 10        // x becomes available
    /// let y = x + 5     // can see x; y becomes available
    /// func f() { ... }  // can see x, y; f becomes available
    /// var z = f()       // can see x, y, f
    /// ```
    ///
    /// - Parameters:
    ///   - block: The sequence of block-level nodes to analyze.
    ///   - info: The initial scope inherited from outer contexts.
    private func processBlock(
        _ block: [any BlockLevelNode],
        _ info: TransformationInfo
    ) {
        var mutInfo = info
        block.forEach { node in
            node.acceptDownwardTransformer(self, mutInfo)
            node.acceptUpwardTransformer(SymbolGrabber.shared) { _, bindings in
                mutInfo.append(contentsOf: bindings)
            }
        }
    }
    
}
