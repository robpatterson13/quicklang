//
//  AST.swift
//  quicklang
//
//  Created by Rob Patterson on 2/11/25.
//

import Foundation

/// Common behavior for AST nodes that can represent incomplete or recovered syntax.
///
/// Many parser entry points may return sentinel "incomplete" nodes when recovery occurs.
/// Conforming types expose an `isIncomplete` flag, a type-level `incomplete` value,
/// and a convenience `anyIncomplete` property (via ``ASTNode`` extension) to detect
/// incompleteness recursively within aggregates.
protocol ASTNodeIncompletable {
    /// Whether this concrete node instance is a placeholder produced by error recovery.
    var isIncomplete: Bool { get }
    /// Whether this node or any nested node is incomplete. Implemented in an extension for ``ASTNode``.
    var anyIncomplete: Bool { get }
    /// A sentinel incomplete node instance for this type.
    static var incomplete: Self { get }
}

/// Base protocol for all AST nodes.
///
/// Provides identity, hashing, and visitor support. Nodes conforming to this protocol
/// can be visited by an ``ASTVisitor`` and compared by unique `id`.
protocol ASTNode: Hashable, ASTNodeIncompletable {
    /// A stable unique identifier for this node instance.
    var id: UUID { get }
    /// Accepts a visitor that performs operations over the AST.
    ///
    /// - Parameter visitor: The visitor to dispatch to.
    func acceptVisitor(_ visitor: any ASTVisitor)
    
    func acceptUpwardTransformer<T: ASTUpwardTransformer>(_ transformer: T, _ finished: @escaping T.OnTransformEnd<Self>)
    
    func acceptDownwardTransformer<T: ASTDownwardTransformer>(_ transformer: T, _ info: T.TransformationInfo)
}

extension ASTNode {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension ASTNode {
    /// Returns true if this node or any nested node is incomplete.
    ///
    /// This method uses reflection to traverse child properties (including collections,
    /// optionals, tuples, and nested structs/classes) and checks each for the incomplete
    /// sentinel. It is useful for short-circuiting later compilation phases when recovery
    /// has taken place.
    var anyIncomplete: Bool {
        if isIncomplete { return true }
        return Self._containsIncomplete(in: self)
    }
    
    /// Recursively inspects an arbitrary value to determine whether it contains an incomplete AST node.
    private static func _containsIncomplete(in value: Any) -> Bool {
        
        if let node = value as? any ASTNode {
            if node.isIncomplete { return true }
        }
        
        let mirror = Mirror(reflecting: value)
        
        switch mirror.displayStyle {
        case .optional:
            if let child = mirror.children.first {
                return _containsIncomplete(in: child.value)
            }
            return false
            
        case .collection, .set, .dictionary, .tuple, .struct, .class, .enum:
            if _hasTrueIsIncompleteFlag(mirror) {
                return true
            }
            
            for child in mirror.children {
                if _containsIncomplete(in: child.value) {
                    return true
                }
            }
            return false
            
        case .none:
            return false
            
        default:
            return false
        }
    }
    
    /// Helper that checks for a stored property named `isIncomplete == true` on reflected values.
    private static func _hasTrueIsIncompleteFlag(_ mirror: Mirror) -> Bool {
        for (labelOpt, value) in mirror.children {
            if let label = labelOpt, label == "isIncomplete", let flag = value as? Bool, flag == true {
                return true
            }
        }
        return false
    }
}

/// Root container for a parsed program.
///
/// Holds all top-level constructs (function definitions, value definitions, and
/// top-level expressions that are permitted by the grammar).
struct TopLevel {
    /// The collection of top-level sections in the program.
    var sections: [any TopLevelNode]
}

/// Marker protocol for AST nodes valid at block scope.
///
/// Conforming nodes can appear within `{ ... }` blocks (e.g., statements or nested expressions).
protocol BlockLevelNode: ASTNode {
    
}

/// Placeholder for an incomplete block-level node produced by error recovery.
struct BlockLevelNodeIncomplete: BlockLevelNode {
    let id = UUID()
    var isIncomplete: Bool
    
    /// Returns a new incomplete block-level node sentinel.
    static var incomplete: BlockLevelNodeIncomplete {
        BlockLevelNodeIncomplete()
    }
    
    private init() {
        self.isIncomplete = true
    }
    
    func acceptVisitor(_ visitor: any ASTVisitor) {
        fatalError("Attempted to visit incomplete block-level node")
    }
    
    func acceptUpwardTransformer<T: ASTUpwardTransformer>(_ transformer: T, _ finished: T.OnTransformEnd<Self>) {
        fatalError("Attempted to transform incomplete block-level node")
    }
    
    func acceptDownwardTransformer<T: ASTDownwardTransformer>(_ transformer: T, _ info: T.TransformationInfo) {
        fatalError("Attempted to transform incomplete block-level node")
    }
}

/// Marker protocol for top-level AST nodes.
///
/// Top-level nodes are also block-level nodes and may include function definitions,
/// value definitions, and (in this language) function applications at the top level.
protocol TopLevelNode: BlockLevelNode { }

/// Placeholder for an incomplete top-level node produced by error recovery.
struct TopLevelNodeIncomplete: TopLevelNode {
    let id = UUID()
    static var incomplete: TopLevelNodeIncomplete {
        TopLevelNodeIncomplete()
    }
    
    private init() {
        self.isIncomplete = true
    }
    
    var isIncomplete: Bool
    
    func acceptVisitor(_ visitor: any ASTVisitor) {
        fatalError("Attempted to visit incomplete top-level node")
    }
    
    func acceptUpwardTransformer<T: ASTUpwardTransformer>(_ transformer: T, _ finished: T.OnTransformEnd<Self>) {
        fatalError("Attempted to transform incomplete top-level node")
    }
    
    func acceptDownwardTransformer<T: ASTDownwardTransformer>(_ transformer: T, _ info: T.TransformationInfo) {
        fatalError("Attempted to transform incomplete top-level node")
    }
}

extension TopLevelNode {
    /// Convenience incomplete value for top-level nodes, defaulting to an incomplete function definition.
    static var incomplete: FuncDefinition {
        FuncDefinition.incomplete
    }
}

/// Marker protocol for expression nodes.
///
/// Expression nodes are visitable and also support a specialized type query entry point
/// used by ``ASTContext`` during type inference and checking.
protocol ExpressionNode: ASTNode {
    /// Dispatches a type query to the given context.
    ///
    /// Nodes call the appropriate `ASTContext.queryTypeOf...` method within this function.
    /// - Parameter context: The context that computes and caches expression types.
    func acceptTypeQuery(_ context: ASTContext)
}

/// Marker protocol for definition nodes (`let`/`var`) that can appear at top level.
///
/// Provides common access to the declared name, optional type annotation, and bound expression.
protocol DefinitionNode: TopLevelNode {
    /// The declared identifier.
    var name: String { get }
    /// The optional explicit type annotation for the definition.
    var type: TypeName? { get }
    /// The initializing expression bound to this definition.
    var expression: any ExpressionNode { get }
}

/// Marker protocol for statement nodes that occur within blocks.
protocol StatementNode: BlockLevelNode { }

/// An identifier expression (variable or function name reference).
struct IdentifierExpression: ExpressionNode, TopLevelNode {
    let id = UUID()
    /// The referenced name.
    let name: String
    
    let isIncomplete: Bool
    
    /// Returns an incomplete sentinel for identifier expressions.
    static var incomplete: IdentifierExpression {
        return IdentifierExpression()
    }
    
    private init() {
        self.name = ""
        self.isIncomplete = true
    }
    
    /// Creates a fully-formed identifier expression.
    /// - Parameter name: The referenced symbol name.
    init(name: String) {
        self.name = name
        self.isIncomplete = false
    }
    
    func acceptVisitor(_ visitor: any ASTVisitor) {
        visitor.visitIdentifierExpression(self)
    }
    
    func acceptTypeQuery(_ context: ASTContext) {
        context.queryTypeOfIdentifierExpression(self)
    }
    
    func acceptUpwardTransformer<T: ASTUpwardTransformer>(
        _ transformer: T,
        _ finished: @escaping T.OnTransformEnd<IdentifierExpression>
    ) {
        transformer.visitIdentifierExpression(self, finished)
    }
    
    func acceptDownwardTransformer<T: ASTDownwardTransformer>(
        _ transformer: T,
        _ info: T.TransformationInfo
    ) {
        transformer.visitIdentifierExpression(self, info)
    }
}

/// A boolean literal expression.
struct BooleanExpression: ExpressionNode {
    let id = UUID()
    /// The literal boolean value.
    let value: Bool
    
    let isIncomplete: Bool
    
    /// Returns an incomplete sentinel for boolean expressions.
    static var incomplete: BooleanExpression {
        return BooleanExpression()
    }
    
    private init() {
        self.value = false
        self.isIncomplete = true
    }
    
    /// Creates a boolean literal expression.
    /// - Parameter value: The literal value.
    init(value: Bool) {
        self.value = value
        self.isIncomplete = false
    }
    
    func acceptVisitor(_ visitor: any ASTVisitor) {
        visitor.visitBooleanExpression(self)
    }
    
    func acceptTypeQuery(_ context: ASTContext) {
        context.queryTypeOfBooleanExpression(self)
    }
    
    func acceptUpwardTransformer<T: ASTUpwardTransformer>(
        _ transformer: T,
        _ finished: @escaping T.OnTransformEnd<BooleanExpression>
    ) {
        transformer.visitBooleanExpression(self, finished)
    }
    
    func acceptDownwardTransformer<T: ASTDownwardTransformer>(
        _ transformer: T,
        _ info: T.TransformationInfo
    ) {
        transformer.visitBooleanExpression(self, info)
    }
}

/// A numeric literal expression (integer).
struct NumberExpression: ExpressionNode {
    let id = UUID()
    /// The literal integer value.
    let value: Int
    
    let isIncomplete: Bool
    
    /// Returns an incomplete sentinel for number expressions.
    static var incomplete: NumberExpression {
        return NumberExpression()
    }
    
    private init() {
        self.value = 0
        self.isIncomplete = true
    }
    
    /// Creates a numeric literal expression.
    /// - Parameter value: The integer value.
    init(value: Int) {
        self.value = value
        self.isIncomplete = false
    }
    
    func acceptVisitor(_ visitor: any ASTVisitor) {
        visitor.visitNumberExpression(self)
    }
    
    func acceptTypeQuery(_ context: ASTContext) {
        context.queryTypeOfNumberExpression(self)
    }
    
    func acceptUpwardTransformer<T: ASTUpwardTransformer>(
        _ transformer: T,
        _ finished: @escaping T.OnTransformEnd<NumberExpression>
    ) {
        transformer.visitNumberExpression(self, finished)
    }
    
    func acceptDownwardTransformer<T: ASTDownwardTransformer>(
        _ transformer: T,
        _ info: T.TransformationInfo
    ) {
        transformer.visitNumberExpression(self, info)
    }
}

/// A unary operation expression.
struct UnaryOperation: ExpressionNode {
    let id = UUID()
    
    /// The operator applied to `expression`.
    let op: Operator
    enum Operator {
        case not
        case neg
    }
    /// The operand expression.
    let expression: any ExpressionNode
    
    let isIncomplete: Bool
    
    /// Returns an incomplete sentinel for unary operations.
    static var incomplete: UnaryOperation {
        return UnaryOperation()
    }
    
    private init() {
        self.op = .not
        self.expression = IdentifierExpression.incomplete
        self.isIncomplete = true
    }
    
    /// Creates a unary operation.
    /// - Parameters:
    ///   - op: The unary operator.
    ///   - expression: The operand expression.
    init(op: Operator, expression: any ExpressionNode) {
        self.op = op
        self.expression = expression
        self.isIncomplete = false
    }
    
    func acceptVisitor(_ visitor: any ASTVisitor) {
        visitor.visitUnaryOperation(self)
    }
    
    func acceptTypeQuery(_ context: ASTContext) {
        context.queryTypeOfUnaryOperation(self)
    }
    
    func acceptUpwardTransformer<T: ASTUpwardTransformer>(
        _ transformer: T,
        _ finished: @escaping T.OnTransformEnd<UnaryOperation>
    ) {
        transformer.visitUnaryOperation(self, finished)
    }
    
    func acceptDownwardTransformer<T: ASTDownwardTransformer>(
        _ transformer: T,
        _ info: T.TransformationInfo
    ) {
        transformer.visitUnaryOperation(self, info)
    }
}

/// A binary operation expression.
struct BinaryOperation: ExpressionNode {
    let id = UUID()
    /// The operator applied between `lhs` and `rhs`.
    let op: Operator
    enum Operator {
        case plus
        case minus
        case times
        
        case and
        case or
    }
    /// The left-hand operand.
    let lhs, rhs: any ExpressionNode
    
    let isIncomplete: Bool
    
    /// Returns an incomplete sentinel for binary operations.
    static var incomplete: BinaryOperation {
        return BinaryOperation()
    }
    
    private init() {
        self.op = .plus
        self.lhs = IdentifierExpression.incomplete
        self.rhs = IdentifierExpression.incomplete
        self.isIncomplete = true
    }
    
    /// Creates a binary operation.
    /// - Parameters:
    ///   - op: The binary operator.
    ///   - lhs: The left-hand operand.
    ///   - rhs: The right-hand operand.
    init(op: Operator, lhs: any ExpressionNode, rhs: any ExpressionNode) {
        self.op = op
        self.lhs = lhs
        self.rhs = rhs
        self.isIncomplete = false
    }
    
    func acceptVisitor(_ visitor: any ASTVisitor) {
        visitor.visitBinaryOperation(self)
    }
    
    func acceptTypeQuery(_ context: ASTContext) {
        context.queryTypeOfBinaryOperation(self)
    }
    
    func acceptUpwardTransformer<T: ASTUpwardTransformer>(
        _ transformer: T,
        _ finished: @escaping T.OnTransformEnd<BinaryOperation>
    ) {
        transformer.visitBinaryOperation(self, finished)
    }
    
    func acceptDownwardTransformer<T: ASTDownwardTransformer>(
        _ transformer: T,
        _ info: T.TransformationInfo
    ) {
        transformer.visitBinaryOperation(self, info)
    }
}

/// A `let` constant definition.
struct LetDefinition: DefinitionNode  {
    let id = UUID()
    /// The defined name.
    let name: String
    /// Optional explicit type annotation.
    let type: TypeName?
    /// The initializing expression.
    let expression: any ExpressionNode
    
    let isIncomplete: Bool
    
    /// Returns an incomplete sentinel for `let` definitions.
    static var incomplete: LetDefinition {
        return LetDefinition()
    }
    
    private init() {
        self.name = ""
        self.type = nil
        self.expression = IdentifierExpression.incomplete
        self.isIncomplete = true
    }
    
    /// Creates a `let` definition without an explicit type annotation.
    /// - Parameters:
    ///   - name: The declared identifier.
    ///   - expression: The initializer expression.
    init(name: String, type: TypeName, expression: any ExpressionNode) {
        self.name = name
        self.type = type
        self.expression = expression
        self.isIncomplete = false
    }
    
    func acceptVisitor(_ visitor: any ASTVisitor) {
        visitor.visitLetDefinition(self)
    }
    
    func acceptUpwardTransformer<T: ASTUpwardTransformer>(
        _ transformer: T,
        _ finished: @escaping T.OnTransformEnd<LetDefinition>
    ) {
        transformer.visitLetDefinition(self, finished)
    }
    
    func acceptDownwardTransformer<T: ASTDownwardTransformer>(
        _ transformer: T,
        _ info: T.TransformationInfo
    ) {
        transformer.visitLetDefinition(self, info)
    }
}

/// A `var` variable definition.
struct VarDefinition: DefinitionNode {
    let id = UUID()
    /// The defined name.
    let name: String
    /// Optional explicit type annotation.
    let type: TypeName?
    /// The initializing expression.
    let expression: any ExpressionNode
    
    let isIncomplete: Bool
    
    /// Returns an incomplete sentinel for `var` definitions.
    static var incomplete: VarDefinition {
        return VarDefinition()
    }
    
    private init() {
        self.name = ""
        self.type = nil
        self.expression = IdentifierExpression.incomplete
        self.isIncomplete = true
    }
    
    /// Creates a `var` definition without an explicit type annotation.
    /// - Parameters:
    ///   - name: The declared identifier.
    ///   - expression: The initializer expression.
    init(name: String, type: TypeName, expression: any ExpressionNode) {
        self.name = name
        self.type = type
        self.expression = expression
        self.isIncomplete = false
    }
    
    func acceptVisitor(_ visitor: any ASTVisitor) {
        visitor.visitVarDefinition(self)
    }
    
    func acceptUpwardTransformer<T: ASTUpwardTransformer>(
        _ transformer: T,
        _ finished: @escaping T.OnTransformEnd<VarDefinition>
    ) {
        transformer.visitVarDefinition(self, finished)
    }
    
    func acceptDownwardTransformer<T: ASTDownwardTransformer>(
        _ transformer: T,
        _ info: T.TransformationInfo
    ) {
        transformer.visitVarDefinition(self, info)
    }
}

/// The set of built-in type names in the language.
enum TypeName: Equatable {
    case Bool
    case Int
    case String
    case Void
    indirect case Arrow(from: [TypeName], to: TypeName)
    
    static func == (lhs: TypeName, rhs: TypeName) -> Bool {
        switch (lhs, rhs) {
        case (.Bool, .Bool),
            (.Int, .Int),
            (.String, .String),
            (.Void, .Void):
            return true
        case (.Arrow(let lhsFrom, let lhsTo), .Arrow(let rhsFrom, let rhsTo)):
            return (lhsFrom == rhsFrom) && (lhsTo == rhsTo)
        default:
            return false
        }
    }
}

/// A function definition.
struct FuncDefinition: TopLevelNode {
    
    /// A single function parameter.
    struct Parameter {
        /// The parameter name.
        let name: String
        /// The parameter type.
        let type: TypeName
        /// Whether this parameter entry was synthesized during recovery.
        let isIncomplete: Bool
        /// Returns an incomplete sentinel for parameters.
        static var incomplete: Parameter {
            return Parameter()
        }
        
        private init() {
            self.name = ""
            self.type = .Int
            self.isIncomplete = true
        }
        
        /// Creates a fully-formed parameter.
        /// - Parameters:
        ///   - name: The parameter name.
        ///   - type: The parameter type.
        init(name: String, type: TypeName) {
            self.name = name
            self.type = type
            self.isIncomplete = false
        }
    }
    
    let id = UUID()
    /// The function name.
    let name: String
    /// The declared return type.
    let type: TypeName
    /// The ordered parameter list.
    let parameters: [Parameter]
    /// The function body as a sequence of block-level nodes.
    let body: [any BlockLevelNode]
    
    let isIncomplete: Bool
    
    /// Returns an incomplete sentinel for function definitions.
    static var incomplete: FuncDefinition {
        return FuncDefinition()
    }
    
    private init() {
        self.name = ""
        self.type = .Int
        self.parameters = []
        self.body = []
        self.isIncomplete = true
    }
    
    /// Creates a fully-formed function definition.
    /// - Parameters:
    ///   - name: The function name.
    ///   - type: The declared return type.
    ///   - parameters: The ordered parameter list.
    ///   - body: The function body.
    init(name: String, type: TypeName, parameters: [Parameter], body: [any BlockLevelNode]) {
        self.name = name
        self.type = type
        self.parameters = parameters
        self.body = body
        self.isIncomplete = false
    }
    
    func acceptVisitor(_ visitor: any ASTVisitor) {
        visitor.visitFuncDefinition(self)
    }
    
    func acceptUpwardTransformer<T: ASTUpwardTransformer>(
        _ transformer: T,
        _ finished: @escaping T.OnTransformEnd<FuncDefinition>
    ) {
        transformer.visitFuncDefinition(self, finished)
    }
    
    func acceptDownwardTransformer<T: ASTDownwardTransformer>(
        _ transformer: T,
        _ info: T.TransformationInfo
    ) {
        transformer.visitFuncDefinition(self, info)
    }
}

/// A function application expression, which is also permitted as a top-level statement.
struct FuncApplication: ExpressionNode, TopLevelNode {
    let id = UUID()
    /// The callee name.
    let name: String
    /// The ordered actual arguments.
    let arguments: [any ExpressionNode]
    
    let isIncomplete: Bool
    
    /// Returns an incomplete sentinel for function applications.
    static var incomplete: FuncApplication {
        return FuncApplication()
    }
    
    private init() {
        self.name = ""
        self.arguments = []
        self.isIncomplete = true
    }
    
    /// Creates a function application.
    /// - Parameters:
    ///   - name: The callee name.
    ///   - arguments: The ordered list of argument expressions.
    init(name: String, arguments: [any ExpressionNode]) {
        self.name = name
        self.arguments = arguments
        self.isIncomplete = false
    }
    
    func acceptVisitor(_ visitor: any ASTVisitor) {
        visitor.visitFuncApplication(self)
    }
    
    func acceptTypeQuery(_ context: ASTContext) {
        context.queryTypeOfFuncApplication(self)
    }
    
    func acceptUpwardTransformer<T: ASTUpwardTransformer>(
        _ transformer: T,
        _ finished: @escaping T.OnTransformEnd<FuncApplication>
    ) {
        transformer.visitFuncApplication(self, finished)
    }
    
    func acceptDownwardTransformer<T: ASTDownwardTransformer>(
        _ transformer: T,
        _ info: T.TransformationInfo
    ) {
        transformer.visitFuncApplication(self, info)
    }
}

/// An `if` statement with optional `else` branch.
struct IfStatement: StatementNode, BlockLevelNode {
    let id = UUID()
    /// The boolean condition expression.
    let condition: any ExpressionNode
    /// The then-branch body.
    let thenBranch: [any BlockLevelNode]
    /// The else-branch body, if present.
    let elseBranch: [any BlockLevelNode]?
    
    let isIncomplete: Bool
    
    /// Returns an incomplete sentinel for `if` statements.
    static var incomplete: IfStatement {
        return IfStatement()
    }
    
    private init() {
        self.condition = IdentifierExpression.incomplete
        self.thenBranch = []
        self.elseBranch = nil
        self.isIncomplete = true
    }
    
    /// Creates an `if` statement.
    /// - Parameters:
    ///   - condition: The condition expression (expected to be boolean).
    ///   - thenBranch: The then-branch body.
    ///   - elseBranch: The optional else-branch body.
    init(condition: any ExpressionNode, thenBranch: [any BlockLevelNode], elseBranch: [any BlockLevelNode]?) {
        self.condition = condition
        self.thenBranch = thenBranch
        self.elseBranch = elseBranch
        self.isIncomplete = false
    }
    
    func acceptVisitor(_ visitor: any ASTVisitor) {
        visitor.visitIfStatement(self)
    }
    
    func acceptUpwardTransformer<T: ASTUpwardTransformer>(
        _ transformer: T,
        _ finished: @escaping T.OnTransformEnd<IfStatement>
    ) {
        transformer.visitIfStatement(self, finished)
    }
    
    func acceptDownwardTransformer<T: ASTDownwardTransformer>(
        _ transformer: T,
        _ info: T.TransformationInfo
    ) {
        transformer.visitIfStatement(self, info)
    }
}

/// A `return` statement.
struct ReturnStatement: StatementNode, BlockLevelNode {
    let id = UUID()
    /// The returned expression.
    let expression: any ExpressionNode
    
    let isIncomplete: Bool
    /// Returns an incomplete sentinel for `return` statements.
    static var incomplete: ReturnStatement {
        return ReturnStatement()
    }
    
    private init() {
        self.expression = IdentifierExpression.incomplete
        self.isIncomplete = true
    }
    
    /// Creates a `return` statement.
    /// - Parameter expression: The expression to return.
    init(expression: any ExpressionNode) {
        self.expression = expression
        self.isIncomplete = false
    }
    
    func acceptVisitor(_ visitor: any ASTVisitor) {
        visitor.visitReturnStatement(self)
    }
    
    func acceptUpwardTransformer<T: ASTUpwardTransformer>(
        _ transformer: T,
        _ finished: @escaping T.OnTransformEnd<ReturnStatement>
    ) {
        transformer.visitReturnStatement(self, finished)
    }
    
    func acceptDownwardTransformer<T: ASTDownwardTransformer>(
        _ transformer: T,
        _ info: T.TransformationInfo
    ) {
        transformer.visitReturnStatement(self, info)
    }
}

struct AssignmentStatement: StatementNode, TopLevelNode {
    let id = UUID()
    let name: String
    let expression: any ExpressionNode
    
    var isIncomplete: Bool
    static var incomplete: AssignmentStatement {
        return AssignmentStatement()
    }
    
    init(name: String, expression: any ExpressionNode) {
        self.name = name
        self.expression = expression
        self.isIncomplete = false
    }
    
    private init() {
        self.name = ""
        self.expression = IdentifierExpression.incomplete
        self.isIncomplete = true
    }
    
    func acceptVisitor(_ visitor: any ASTVisitor) {
        visitor.visitAssignmentStatement(self)
    }
    
    func acceptUpwardTransformer<T>(_ transformer: T, _ finished: @escaping T.OnTransformEnd<AssignmentStatement>) where T : ASTUpwardTransformer {
        transformer.visitAssignmentStatement(self, finished)
    }
    
    func acceptDownwardTransformer<T>(_ transformer: T, _ info: T.TransformationInfo) where T : ASTDownwardTransformer {
        transformer.visitAssignmentStatement(self, info)
    }
    
    
}

