//
//  BuildScopes.swift
//  quicklang
//
//  Created by Rob Patterson on 11/30/25.
//

class BuildScopes: SemaPass {
    
    var context: ASTContext
    var errorManager: CompilerErrorManager?
    
    init(context: ASTContext) {
        self.context = context
    }
    
    func begin(reportingTo: CompilerErrorManager) {
        errorManager = reportingTo
        
        context.tree.sections.forEach { node in
            let scope = buildGlobals(for: node)
            _ = node.acceptVisitor(self, scope)
        }
    }
    
    private func buildGlobals(for node: any TopLevelNode) -> ASTScope {
        let canBeRecursive = node.acceptVisitor(AllowsRecursiveDefinition.shared)
        switch canBeRecursive {
        case .yes:
            return ASTScope(isGlobal: true, decls: context.allGlobals())
        case .no, .notApplicable:
            return ASTScope(isGlobal: true, decls: context.allGlobals(excluding: node))
        }
    }
    
    enum WillIntroduceNewDecl {
        case yes(DefinitionNode)
        case no
    }
    
    func visitIdentifierExpression(
        _ expression: IdentifierExpression,
        _ info: ASTScope
    ) -> WillIntroduceNewDecl {
        expression.scope = info
        return .no
    }
    
    func visitBooleanExpression(
        _ expression: BooleanExpression,
        _ info: ASTScope
    ) -> WillIntroduceNewDecl {
        expression.scope = info
        return .no
    }
    
    func visitNumberExpression(
        _ expression: NumberExpression,
        _ info: ASTScope
    ) -> WillIntroduceNewDecl {
        expression.scope = info
        return .no
    }
    
    func visitUnaryOperation(
        _ operation: UnaryOperation,
        _ info: ASTScope
    ) -> WillIntroduceNewDecl {
        operation.scope = info
        
        _ = operation.expression.acceptVisitor(self, info)
        return .no
    }
    
    func visitBinaryOperation(
        _ operation: BinaryOperation,
        _ info: ASTScope
    ) -> WillIntroduceNewDecl {
        operation.scope = info
        
        _ = operation.lhs.acceptVisitor(self, info)
        _ = operation.rhs.acceptVisitor(self, info)
        return .no
    }
    
    func visitDefinition(
        _ definition: DefinitionNode,
        _ info: ASTScope)
    -> WillIntroduceNewDecl {
        definition.scope = info
        
        _ = definition.expression.acceptVisitor(self, info)
        return .yes(definition)
    }
    
    func visitFuncDefinition(
        _ definition: FuncDefinition,
        _ info: ASTScope
    ) -> WillIntroduceNewDecl {
        definition.scope = info
        
        let newScope = info.newChild(with: .function(definition))
        let paramDecls = definition.parameters.map({ ASTScope.IntroducedBinding.funcParameter($0) })
        newScope.addDecls(paramDecls)
        processBlock(definition.body, with: newScope)
        return .no
    }
    
    func visitFuncApplication(
        _ expression: FuncApplication,
        _ info: ASTScope
    ) -> WillIntroduceNewDecl {
        expression.scope = info
        
        expression.arguments.forEach {
            _ = $0.acceptVisitor(self, info)
        }
        return .no
    }
    
    func visitIfStatement(
        _ statement: IfStatement,
        _ info: ASTScope
    ) -> WillIntroduceNewDecl {
        statement.scope = info
        
        _ = statement.condition.acceptVisitor(self, info)
        processBlock(statement.thenBranch, with: info)
        if let elseBranch = statement.elseBranch {
            processBlock(elseBranch, with: info)
        }
        return .no
    }
    
    func visitReturnStatement(
        _ statement: ReturnStatement,
        _ info: ASTScope
    ) -> WillIntroduceNewDecl {
        statement.scope = info
        
        _ = statement.expression.acceptVisitor(self, info)
        return .no
    }
    
    func visitAssignmentStatement(
        _ statement: AssignmentStatement,
        _ info: ASTScope
    ) -> WillIntroduceNewDecl {
        statement.scope = info
        
        _ = statement.expression.acceptVisitor(self, info)
        return .no
    }
    
    private func processBlock(_ block: [any BlockLevelNode], with info: ASTScope) {
        var progressiveScope = info
        block.forEach { node in
            let result = node.acceptVisitor(self, progressiveScope)
            switch result {
            case .yes(let newDecl):
                let newScope = progressiveScope.newChild(with: .definition(newDecl))
                progressiveScope = newScope
            case .no:
                return
            }
        }
    }
    
    func visitControlFlowJumpStatement(_ statement: ControlFlowJumpStatement, _ info: ASTScope) -> WillIntroduceNewDecl {
        InternalCompilerError.unreachable()
    }
    
    func visitLabelControlFlowStatement(_ statement: LabelControlFlowStatement, _ info: ASTScope) -> WillIntroduceNewDecl {
        InternalCompilerError.unreachable()
    }
    
}
