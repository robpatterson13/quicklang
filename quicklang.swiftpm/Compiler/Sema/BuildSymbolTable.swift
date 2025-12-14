//
//  BuildSymbolTable.swift
//  quicklang
//
//  Created by Rob Patterson on 11/30/25.
//

final class BuildSymbolTable: SemaPass {
    
    typealias VisitorInfo = Void
    typealias VisitorResult = Void
    
    var context: ASTContext
    
    init(context: ASTContext) {
        self.context = context
    }
    
    func begin(reportingTo: CompilerErrorManager) -> Void {
        context.tree.sections.forEach { node in
            node.acceptVisitor(self)
        }
    }
    
    func visitIdentifierExpression(
        _ expression: IdentifierExpression,
        _ info: Void
    ) {}
    
    func visitBooleanExpression(
        _ expression: BooleanExpression,
        _ info: Void
    ) {}
    
    func visitNumberExpression(
        _ expression: NumberExpression,
        _ info: Void
    ) {}
    
    func visitUnaryOperation(
        _ operation: UnaryOperation,
        _ info: Void
    ) {}
    
    func visitBinaryOperation(
        _ operation: BinaryOperation,
        _ info: Void
    ) {}
    
    func visitDefinition(
        _ definition: DefinitionNode,
        _ info: Void
    ) {
        context.assignTypeOf(definition.type, to: definition.name)
    }
    
    func visitFuncDefinition(
        _ definition: FuncDefinition,
        _ info: Void
    ) {
        context.assignTypeOf(definition.type, to: definition.name)
        
        processBlock(definition.body)
    }
    
    func visitFuncApplication(
        _ expression: FuncApplication,
        _ info: Void
    ) {}
    
    func visitIfStatement(
        _ statement: IfStatement,
        _ info: Void
    ) {
        processBlock(statement.thenBranch)
        if let elseBranch = statement.elseBranch {
            processBlock(elseBranch)
        }
    }
    
    func visitReturnStatement(
        _ statement: ReturnStatement,
        _ info: Void
    ) {}
    
    func visitAssignmentStatement(
        _ statement: AssignmentStatement,
        _ info: Void
    ) {}
    
    private func processBlock(_ block: [any BlockLevelNode]) {
        block.forEach {
            $0.acceptVisitor(self)
        }
    }
}
