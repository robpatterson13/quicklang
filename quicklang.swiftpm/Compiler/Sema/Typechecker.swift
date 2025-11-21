//
//  Typechecker.swift
//  quicklang
//
//  Created by Rob Patterson on 2/16/25.
//

/// Performs static type checking over the AST.
struct Typechecker: SemaPass, ASTVisitor {
    
    func begin(reportingTo: CompilerErrorManager) {
        let tree = context.tree
        
        tree.sections.forEach { node in
            node.acceptVisitor(self)
        }
    }
    
    /// Collected type errors.
    private var errors: [Error] = []
    
    /// Context for querying types and symbols.
    let context: ASTContext
    
    init(context: ASTContext) {
        self.context = context
    }
    
    /// Checks whether an expression has an expected type.
    private func isExpression(_ expr: any ExpressionNode, type: TypeName) -> Bool {
        return type == context.getType(of: expr)
    }
    
    /// Validates a definition against an optional annotation.
    private func checkDefinition(_ definition: any DefinitionNode) {
        if let type = definition.type, !isExpression(definition.expression, type: type) {
            // MARK: Definition has type
        }
    }
    
    /// Visits an identifier expression.
    func visitIdentifierExpression(_ expression: IdentifierExpression) {}
    
    /// Visits a boolean literal expression.
    func visitBooleanExpression(_ expression: BooleanExpression) {}
    
    /// Visits a numeric literal expression.
    func visitNumberExpression(_ expression: NumberExpression) {}
    
    /// Validates a unary operation’s operand type.
    func visitUnaryOperation(_ operation: UnaryOperation) {
        switch operation.op {
        case .not, .neg:
            if !isExpression(operation.expression, type: .Bool) {
                // MARK: \(operation.op) can only be used with a Bool expression
            }
        }
        
        operation.expression.acceptVisitor(self)
    }
    
    /// Validates a binary operation’s operand types.
    func visitBinaryOperation(_ operation: BinaryOperation) {
        switch operation.op {
        case .plus, .minus, .times:
            if !isExpression(operation.lhs, type: .Int),
               !isExpression(operation.rhs, type: .Int) {
                // MARK: \(operation.op) can only be used with a Int expression
            }
        case .and, .or:
            if !isExpression(operation.lhs, type: .Bool),
               !isExpression(operation.rhs, type: .Bool) {
                // MARK: \(operation.op) can only be used with a Bool expression
            }
        }
        
        operation.lhs.acceptVisitor(self)
        operation.rhs.acceptVisitor(self)
    }
    
    /// Validates a `let` definition.
    func visitLetDefinition(_ definition: LetDefinition) {
        checkDefinition(definition)
    }
    
    /// Validates a `var` definition.
    func visitVarDefinition(_ definition: VarDefinition) {
        checkDefinition(definition)
    }
    
    /// Validates a function definition, including return semantics.
    func visitFuncDefinition(_ definition: FuncDefinition) {
        // do the body of the definition first
        definition.body.forEach { $0.acceptVisitor(self) }
        
        // then type check the function definition + returned value
        let returnType = definition.type
        let returnStmt = definition.body.first { $0 is ReturnStatement } as? ReturnStatement
        
        // if our function is void and we don't return anything, exit
        if definition.type == .Void && returnStmt == nil {
            return
        }
        
        // if our function isn't void and we don't return anything, add error
        // and exit
        guard let returnStmt else {
            // MARK: Must return a value of type from func definition
            return
        }
        
        // if our return type isn't void, add error and exit
        guard returnType != .Void else {
            // MARK: Cannot return a value from a void function
            return
        }
        
        if !isExpression(returnStmt.expression, type: returnType) {
            // MARK: Function must return <returnType>, returning <type of returnStmt.expression>
        }
    }
    
    /// Validates a function application’s argument types.
    func visitFuncApplication(_ expression: FuncApplication) {
        let params = context.getFuncParams(of: expression.name)
        
        for (idx, arg) in expression.arguments.enumerated()
        where !isExpression(arg, type: params[idx].type) {
            // MARK: Wrong arg type
        }
        
        expression.arguments.forEach { $0.acceptVisitor(self) }
    }
    
    /// Validates an `if` statement’s condition and branches.
    func visitIfStatement(_ statement: IfStatement) {
        if !isExpression(statement.condition, type: .Bool) {
            // MARK: Condition of if statement must be Bool, is <other type>
        }
        
        statement.thenBranch.forEach { $0.acceptVisitor(self) }
        statement.elseBranch?.forEach { $0.acceptVisitor(self) }
    }
    
    /// Visits a `return` statement.
    func visitReturnStatement(_ statement: ReturnStatement) {
        statement.expression.acceptVisitor(self)
    }
    
}
