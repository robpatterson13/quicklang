//
//  ExplicitJumpInsertion.swift
//  quicklang
//
//  Created by Rob Patterson on 12/25/25.
//

import Foundation

struct ExplicitJumpInsertionInfo {
    let continuationLabel: String?
    
    static let noInsertionYet: Self = .init(continuationLabel: nil)
}

enum ExplicitJumpInsertionResult {
    
    case blockLevelNode(any BlockLevelNode)
    case function(FuncDefinition)
    
    func unwrapBlockLevelNode() -> any BlockLevelNode {
        switch self {
        case .blockLevelNode(let node):
            return node
            
        default:
            InternalCompilerError.unreachable("Unable to unwrap non-block level node as block level node")
        }
    }
    
    func unwrapFunction() -> FuncDefinition {
        switch self {
        case .function(let funcDef):
            return funcDef
            
        default:
            InternalCompilerError.unreachable("Unable to unwrap non-function as function")
        }
    }
}

final class ExplicitJumpInsertion: SemaPass, ASTVisitor {
    
    typealias Result = Void
    
    typealias VisitorInfo = ExplicitJumpInsertionInfo
    typealias VisitorResult = ExplicitJumpInsertionResult
    
    let context: ASTContext
    
    func begin(reportingTo: CompilerErrorManager) -> Void {
        
        let functions = context.tree.sections.map { node in
            node.acceptVisitor(self, .noInsertionYet).unwrapFunction()
        }
        
        context.tree.sections = functions
    }
    
    init(context: ASTContext) {
        self.context = context
    }
    
    func visitFuncDefinition(
        _ definition: FuncDefinition,
        _ info: ExplicitJumpInsertionInfo
    ) -> ExplicitJumpInsertionResult {
        
        let body = processBlock(definition.body, info: .noInsertionYet)
        let newFunction = FuncDefinition(
            name: definition.name,
            type: definition.type,
            parameters: definition.parameters,
            body: body,
            isEntry: definition.isEntry
        )
        
        return .function(newFunction)
    }
    
    func visitIfStatement(
        _ statement: IfStatement,
        _ info: ExplicitJumpInsertionInfo
    ) -> ExplicitJumpInsertionResult {
        
        let thenBlock = processBlock(statement.thenBranch, info: info)
        // we want to add a continuation point even if we don't have any
        // else block
        let elseBlock = processBlock(statement.elseBranch ?? [], info: info)
        
        let newIf = statement.initFromOld(
            condition: statement.condition,
            thenBranch: thenBlock,
            elseBranch: elseBlock
        )
        
        return .blockLevelNode(newIf)
    }
    
    private func processBlock(
        _ block: [any BlockLevelNode],
        info: ExplicitJumpInsertionInfo
    ) -> [any BlockLevelNode] {
        
        var newBlock = [] as [any BlockLevelNode]
        for node in block {
            // if we know this node doesn't need a continuation point,
            // we don't need to visit it
            guard node.needsContinuationPoint() else {
                newBlock.append(node)
                continue
            }
        
            // at this point, we know we need to add a continuation point
            let continuationLabel = GenSymInfo.singleton.genSym(root: "continuation", id: nil)
            let info = ExplicitJumpInsertionInfo(continuationLabel: continuationLabel)
            let result = node.acceptVisitor(self, info).unwrapBlockLevelNode()
            
            let continuationPoint = LabelControlFlowStatement(label: continuationLabel)
            
            newBlock.append(result)
            newBlock.append(continuationPoint)
        }
        
        // if we are in a block that needs a jump insertion, add it now
        if let label = info.continuationLabel {
            let jump = ControlFlowJumpStatement(label: label)
            newBlock.append(jump)
        }
        
        return newBlock
    }
    
}

// unreachables
extension ExplicitJumpInsertion {
    
    func visitFuncApplication(_ expression: FuncApplication, _ info: ExplicitJumpInsertionInfo) -> ExplicitJumpInsertionResult {
        InternalCompilerError.unreachable()
    }
    
    func visitIdentifierExpression(_ expression: IdentifierExpression, _ info: ExplicitJumpInsertionInfo) -> ExplicitJumpInsertionResult {
        InternalCompilerError.unreachable()
    }
    
    func visitBooleanExpression(_ expression: BooleanExpression, _ info: ExplicitJumpInsertionInfo) -> ExplicitJumpInsertionResult {
        InternalCompilerError.unreachable()
    }
    
    func visitNumberExpression(_ expression: NumberExpression, _ info: ExplicitJumpInsertionInfo) -> ExplicitJumpInsertionResult {
        InternalCompilerError.unreachable()
    }
    
    func visitUnaryOperation(_ operation: UnaryOperation, _ info: ExplicitJumpInsertionInfo) -> ExplicitJumpInsertionResult {
        InternalCompilerError.unreachable()
    }
    
    func visitBinaryOperation(_ operation: BinaryOperation, _ info: ExplicitJumpInsertionInfo) -> ExplicitJumpInsertionResult {
        InternalCompilerError.unreachable()
    }
    
    func visitDefinition(_ definition: DefinitionNode, _ info: ExplicitJumpInsertionInfo) -> ExplicitJumpInsertionResult {
        InternalCompilerError.unreachable()
    }
    
    func visitReturnStatement(_ statement: ReturnStatement, _ info: ExplicitJumpInsertionInfo) -> ExplicitJumpInsertionResult {
        InternalCompilerError.unreachable()
    }
    
    func visitAssignmentStatement(_ statement: AssignmentStatement, _ info: ExplicitJumpInsertionInfo) -> ExplicitJumpInsertionResult {
        InternalCompilerError.unreachable()
    }
    
    func visitControlFlowJumpStatement(_ statement: ControlFlowJumpStatement, _ info: ExplicitJumpInsertionInfo) -> ExplicitJumpInsertionResult {
        InternalCompilerError.unreachable()
    }
    
    func visitLabelControlFlowStatement(_ statement: LabelControlFlowStatement, _ info: ExplicitJumpInsertionInfo) -> ExplicitJumpInsertionResult {
        InternalCompilerError.unreachable()
    }
}
