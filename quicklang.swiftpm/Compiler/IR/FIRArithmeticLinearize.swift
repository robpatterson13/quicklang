//
//  FIRArithmeticLinearize.swift
//  quicklang
//
//  Created by Rob Patterson on 12/27/25.
//

typealias FIRArithmeticLinearizeInfo = Void

enum FIRArithmeticLinearizeResult {
    case expression(any FIRExpression, context: [FIRAssignment])
    case statement(any FIRBasicBlockItem, context: [FIRAssignment])
    case terminator(any FIRTerminator, context: [FIRAssignment])
    
    func unwrapExpression() -> (any FIRExpression, [FIRAssignment]) {
        switch self {
        case .expression(let expr, let context):
            return (expr, context)
        case .statement:
            InternalCompilerError.unreachable()
        case .terminator:
            InternalCompilerError.unreachable()
        }
    }
    
    func unwrapStatement() -> (any FIRBasicBlockItem, [FIRAssignment]) {
        switch self {
        case .statement(let stmt, let context):
            return (stmt, context)
        case .expression:
            InternalCompilerError.unreachable()
        case .terminator:
            InternalCompilerError.unreachable()
        }
    }
    
    func unwrapTerminator() -> (any FIRTerminator, [FIRAssignment]) {
        switch self {
        case .terminator(let terminator, let context):
            return (terminator, context)
        case .expression:
            InternalCompilerError.unreachable()
        case .statement:
            InternalCompilerError.unreachable()
        }
    }
}

final class FIRArithmeticLinearize: FIRVisitor {
    
    typealias VisitorInfo = FIRArithmeticLinearizeInfo
    typealias VisitorResult = FIRArithmeticLinearizeResult
    
    func begin(_ module: FIRModule) {
        for function in module.nodes {
            processFunction(function)
        }
    }
    
    private func processFunction(_ function: FIRFunction) {
        var newBlocks: [FIRBasicBlock] = []
        for block in function.blocks {
            // skip the return block, it doesn't need to be visited
            guard let returnBlock = function.returnBlock,
                  block !== returnBlock else {
                newBlocks.append(block)
                continue
            }
            
            let result = processBasicBlock(block)
            newBlocks.append(result)
        }
        
        function.blocks = newBlocks
    }
    
    private func processBasicBlock(
        _ block: FIRBasicBlock
    ) -> FIRBasicBlock {
        
        let builder = FIRBasicBlock.Builder()
        builder.addLabel(block.label)
        
        for blockItem in block.statements {
            let (stmt, stmtCtx) = blockItem.acceptVisitor(self, ()).unwrapStatement()
            builder.addStatements(stmtCtx)
            builder.addStatement(stmt)
        }
        
        let (terminator, terminatorCtx) = block.terminator.acceptVisitor(self, ()).unwrapTerminator()
        builder.addStatements(terminatorCtx)
        builder.addTerminator(terminator)
        
        let newBlock = builder.build()
        return newBlock
    }
    
    func visitFIRIdentifier(
        _ expression: FIRIdentifier,
        _ info: FIRArithmeticLinearizeInfo
    ) -> FIRArithmeticLinearizeResult {
        
        .expression(expression, context: [])
    }
    
    func visitFIRBoolean(
        _ expression: FIRBoolean,
        _ info: FIRArithmeticLinearizeInfo
    ) -> FIRArithmeticLinearizeResult {
        
        .expression(expression, context: [])
    }
    
    func visitFIRInteger(
        _ expression: FIRInteger,
        _ info: FIRArithmeticLinearizeInfo
    ) -> FIRArithmeticLinearizeResult {
        
        .expression(expression, context: [])
    }
    
    func visitFIRUnaryExpression(
        _ operation: FIRUnaryExpression,
        _ info: FIRArithmeticLinearizeInfo
    ) -> FIRArithmeticLinearizeResult {
        
        switch operation.op {
        case .neg:
            let (visitBranch, visitPrologue) = operation.expr.acceptVisitor(self, ()).unwrapExpression()
            
            let newExpr = FIRUnaryExpression(op: .neg, expr: visitBranch)
            let newName = GenSymInfo.singleton.genSym(root: "neg")
            let newAssignment = FIRAssignment(name: newName, value: newExpr)
            let newContext: [FIRAssignment] = visitPrologue + [newAssignment]
            let newIdentifier = FIRIdentifier(name: newName)
            
            return .expression(newIdentifier, context: newContext)
            
        default:
            InternalCompilerError.unreachable()
        }
    }
    
    func visitFIRBinaryExpression(
        _ operation: FIRBinaryExpression,
        _ info: FIRArithmeticLinearizeInfo
    ) -> FIRArithmeticLinearizeResult {
        
        let (lhsExpr, lhsContext) = operation.lhs.acceptVisitor(self, info).unwrapExpression()
        let (rhsExpr, rhsContext) = operation.rhs.acceptVisitor(self, info).unwrapExpression()
        
        let newExpr = FIRBinaryExpression(
            op: operation.op,
            lhs: lhsExpr,
            rhs: rhsExpr
        )
        let newName = GenSymInfo.singleton.genSym(root: "bin_op")
        let newAssignment = FIRAssignment(name: newName, value: newExpr)
        let newContext = lhsContext + rhsContext + [newAssignment]
        let newIdentifier = FIRIdentifier(name: newName)
        
        return .expression(newIdentifier, context: newContext)
    }
    
    func visitFIRAssignment(
        _ definition: FIRAssignment,
        _ info: FIRArithmeticLinearizeInfo
    ) -> FIRArithmeticLinearizeResult {
        
        let (expr, context) = definition.value.acceptVisitor(self, info).unwrapExpression()
        let newAssignment = FIRAssignment(name: definition.name, value: expr)
        
        return .statement(newAssignment, context: context)
    }
    
    func visitFIRConditionalBranch(
        _ definition: FIRConditionalBranch,
        _ info: FIRArithmeticLinearizeInfo
    ) -> FIRArithmeticLinearizeResult {
        
        let (expr, context) = definition.condition.acceptVisitor(self, info).unwrapExpression()
        let newCondBranch = FIRConditionalBranch(
            condition: expr,
            thenBranch: definition.thenBranch,
            elseBranch: definition.elseBranch
        )
        
        return .terminator(newCondBranch, context: context)
    }
    
    func visitFIRBranch(
        _ expression: FIRBranch,
        _ info: FIRArithmeticLinearizeInfo
    ) -> FIRArithmeticLinearizeResult {
        
        let (expr, context) = expression.value?.acceptVisitor(self, info).unwrapExpression() ?? (nil, nil)
        let newBranch = FIRBranch(
            label: expression.label,
            value: expr
        )
        
        return .terminator(newBranch, context: context ?? [])
    }
    
    func visitFIRJump(
        _ statement: FIRJump,
        _ info: FIRArithmeticLinearizeInfo
    ) -> FIRArithmeticLinearizeResult {
        
        return .terminator(statement, context: [])
    }
    
    func visitFIRFunctionCall(
        _ statement: FIRFunctionCall,
        _ info: FIRArithmeticLinearizeInfo
    ) -> FIRArithmeticLinearizeResult {
        
        .expression(statement, context: [])
    }
    
    func visitFIREmptyTuple(
        _ empty: FIREmptyTuple,
        _ info: FIRArithmeticLinearizeInfo
    ) -> FIRArithmeticLinearizeResult {
        
        .expression(empty, context: [])
    }
    
}

// unreachables
extension FIRArithmeticLinearize {
    
    func visitFIRLabel(
        _ statement: FIRLabel,
        _ info: FIRArithmeticLinearizeInfo
    ) -> FIRArithmeticLinearizeResult {
        InternalCompilerError.unreachable()
    }
    
    func visitFIRReturn(
        _ statement: FIRReturn,
        _ info: FIRArithmeticLinearizeInfo
    ) -> FIRArithmeticLinearizeResult {
        InternalCompilerError.unreachable()
    }
}
