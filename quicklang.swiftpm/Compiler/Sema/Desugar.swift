//
//  Desugar.swift
//  quicklang
//
//  Created by Rob Patterson on 12/13/25.
//

final class Desugar: CompilerPhase, RawASTVisitor {
    
    typealias InputType = ASTContext
    typealias SuccessfulResult = ASTContext
    
    var errorManager: CompilerErrorManager?
    
    init(errorManager: CompilerErrorManager, settings: DriverSettings) {
        self.errorManager = errorManager
    }
    
    func begin(_ input: ASTContext) -> PhaseResult<Desugar> {
        let desugared = input.rawTree.sections.map { node in
            node.acceptVisitor(self, .nothing).unwrapTopLevel()
        }
        
        let topLevel = TopLevel(sections: desugared)
        input.finishDesugaredAST(tree: topLevel)
        return .success(result: input)
    }
    
    enum DesugaringBridgeToAST {
        case generic(any ASTNode)
        case expression(any ExpressionNode)
        case blockLevel(any BlockLevelNode)
        case topLevel(any TopLevelNode)
        
        func unwrapExpression() -> any ExpressionNode {
            guard case .expression(let node) = self else {
                fatalError("Cannot unwrap non-expression as expression")
            }
            
            return node
        }
        
        func unwrapBlockLevel() -> any BlockLevelNode {
            guard case .blockLevel(let node) = self else {
                fatalError("Cannot unwrap non-block-level as block-level")
            }
            
            return node
        }
        
        func unwrapTopLevel() -> any TopLevelNode {
            guard case .topLevel(let node) = self else {
                fatalError("Cannot unwrap non-top-level as top-level")
            }
            
            return node
        }
    }
    
    struct DesugaringContext {
        let funcIsEntryPoint: Bool?
        
        private init(funcIsEntryPoint: Bool? = nil) {
            self.funcIsEntryPoint = funcIsEntryPoint
        }
        
        static let nothing: Self = .init()
        static let funcIsEntryPoint: Self = .init(funcIsEntryPoint: true)
    }
    
    func visitRawIdentifierExpression(
        _ expression: RawIdentifierExpression,
        _ info: DesugaringContext
    ) -> DesugaringBridgeToAST {
        let identifier = IdentifierExpression(name: expression.name)
        return .expression(identifier)
    }
    
    func visitRawBooleanExpression(
        _ expression: RawBooleanExpression,
        _ info: DesugaringContext
    ) -> DesugaringBridgeToAST {
        let boolean = BooleanExpression(value: expression.value)
        return .expression(boolean)
    }
    
    func visitRawNumberExpression(
        _ expression: RawNumberExpression,
        _ info: DesugaringContext
    ) -> DesugaringBridgeToAST {
        let number = NumberExpression(value: expression.value)
        return .expression(number)
    }
    
    func visitRawUnaryOperation(
        _ operation: RawUnaryOperation,
        _ info: DesugaringContext
    ) -> DesugaringBridgeToAST {
        let expression = operation.expression.acceptVisitor(self, .nothing)
        let operation = UnaryOperation(op: operation.op, expression: expression.unwrapExpression())
        return .expression(operation)
    }
    
    func visitRawBinaryOperation(
        _ operation: RawBinaryOperation,
        _ info: DesugaringContext
    ) -> DesugaringBridgeToAST {
        let lhs = operation.lhs.acceptVisitor(self, .nothing)
        let rhs = operation.rhs.acceptVisitor(self, .nothing)
        let operation = BinaryOperation(op: operation.op, lhs: lhs.unwrapExpression(), rhs: rhs.unwrapExpression())
        return .expression(operation)
    }
    
    private func visitRawDefinition<T: RawDefinitionNode>(
        _ definition: T,
        _ isImmutable: Bool
    ) -> DesugaringBridgeToAST {
        let expression = definition.expression.acceptVisitor(self, .nothing)
        let definition = DefinitionNode(
            name: definition.name,
            type: definition.type,
            expression: expression.unwrapExpression(),
            isImmutable: isImmutable
        )
        return .blockLevel(definition)
    }
    
    func visitRawLetDefinition(
        _ definition: RawLetDefinition,
        _ info: DesugaringContext
    ) -> DesugaringBridgeToAST {
        visitRawDefinition(definition, true)
    }
    
    func visitRawVarDefinition(
        _ definition: RawVarDefinition,
        _ info: DesugaringContext
    ) -> DesugaringBridgeToAST {
        visitRawDefinition(definition, false)
    }
    
    func processBlock(
        _ block: [any RawBlockLevelNode]
    ) -> [any BlockLevelNode] {
        block.map { node in
            node.acceptVisitor(self, .nothing).unwrapBlockLevel()
        }
    }
    
    func visitRawFuncDefinition(
        _ definition: RawFuncDefinition,
        _ info: DesugaringContext
    ) -> DesugaringBridgeToAST {
        let parameters = definition.parameters.map { param in
            FuncDefinition.Parameter(name: param.name, type: param.type)
        }
        let body = processBlock(definition.body)
        let function = FuncDefinition(
            name: definition.name,
            type: definition.type,
            parameters: parameters,
            body: body,
            isEntry: info.funcIsEntryPoint ?? false
        )
        
        return .topLevel(function)
    }
    
    func visitRawFuncApplication(
        _ expression: RawFuncApplication,
        _ info: DesugaringContext
    ) -> DesugaringBridgeToAST {
        let args = expression.arguments.map { expr in
            expr.acceptVisitor(self, .nothing).unwrapExpression()
        }
        let application = FuncApplication(
            name: expression.name,
            arguments: args
        )
        
        return .expression(application)
    }
    
    func visitRawIfStatement(
        _ statement: RawIfStatement,
        _ info: DesugaringContext
    ) -> DesugaringBridgeToAST {
        let condition = statement.condition.acceptVisitor(self, .nothing)
        let thenBranch = processBlock(statement.thenBranch)
        var elseBranch: [any BlockLevelNode]? = nil
        if let elseBlock = statement.elseBranch {
            elseBranch = processBlock(elseBlock)
        }
        let ifStatment = IfStatement(
            condition: condition.unwrapExpression(),
            thenBranch: thenBranch,
            elseBranch: elseBranch
        )
        
        return .blockLevel(ifStatment)

    }
    
    func visitRawReturnStatement(
        _ statement: RawReturnStatement,
        _ info: DesugaringContext
    ) -> DesugaringBridgeToAST {
        let expression = statement.expression.acceptVisitor(self, .nothing)
        let returnStatement = ReturnStatement(expression: expression.unwrapExpression())
        return .blockLevel(returnStatement)
    }
    
    func visitRawAssignmentStatement(
        _ statement: RawAssignmentStatement,
        _ info: DesugaringContext
    ) -> DesugaringBridgeToAST {
        let expression = statement.expression.acceptVisitor(self, .nothing)
        let assignmentStatement = AssignmentStatement(name: statement.name, expression: expression.unwrapExpression())
        return .blockLevel(assignmentStatement)
    }
    
    func visitRawAttributedNode(
        _ attributedNode: RawAttributedNode,
        _ info: DesugaringContext
    ) -> DesugaringBridgeToAST {
        var node = attributedNode.node.acceptVisitor(self, .funcIsEntryPoint)
        switch node {
        case .topLevel:
            return node
        default:
            fatalError("Raw attributed nodes can only appear at the top level")
        }
    }
    
}
