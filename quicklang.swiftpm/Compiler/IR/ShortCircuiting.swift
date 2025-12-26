//
//  ShortCircuiting.swift
//  quicklang
//
//  Created by Rob Patterson on 12/20/25.
//

struct ShortCircuitInfo {
    let thn: String
    let els: String
    
    var kind: Kind = .subexpression
    enum Kind {
        case subexpression
        case branch
    }
    
    func asSubexpression() -> Self {
        .init(thn: thn, els: els, kind: .subexpression)
    }
    
    func asBranch() -> Self {
        .init(thn: thn, els: els, kind: .branch)
    }
    
    func unwrapBranches() -> (thn: String, els: String) {
        return (thn: thn, els: els)
    }
}

enum ShortCircuitResult {
    case subexpression(any FIRExpression, [FIRAssignment])
    case branch(FIRConditionalBranch, [FIRBasicBlock])
    
    func unwrapSubexpression() -> (any FIRExpression, [FIRAssignment]) {
        switch self {
        case .subexpression(let expression, let bindings):
            return (expression, bindings)
        @unknown default:
            InternalCompilerError.unreachable("Can't unwrap non-expression as expression")
        }
    }
    
    func unwrapBranch() -> (FIRConditionalBranch, [FIRBasicBlock]) {
        switch self {
        case .branch(let branch, let blocks):
            return (branch, blocks)
        @unknown default:
            InternalCompilerError.unreachable("Can't unwrap non-expression as expression")
        }
    }
}

final class ShortCircuitingForIfStatementCondition: FIRVisitor {
    
    typealias VisitorInfo = ShortCircuitInfo
    typealias VisitorResult = ShortCircuitResult
    
    func begin(_ module: FIRModule) {
        for function in module.nodes {
            processFunction(function)
        }
    }
    
    private func processFunction(_ function: FIRFunction) {
        var newBlocks: [FIRBasicBlock] = []
        for block in function.blocks {
            if let branch = block.terminator as? FIRConditionalBranch {
                let (branch, blocks) = branch.acceptVisitor(self, .init(thn: "", els: "")).unwrapBranch()
                block.terminator = branch
                newBlocks.append(contentsOf: blocks)
            }
        }
        
        function.blocks.append(contentsOf: newBlocks)
    }
    
    func visitFIRConditionalBranch(
        _ definition: FIRConditionalBranch,
        _ info: ShortCircuitInfo)
    -> ShortCircuitResult {
        
        let info = ShortCircuitInfo(thn: definition.thenBranch, els: definition.elseBranch)
        
        let result = definition.condition.acceptVisitor(self, info)
        return result
    }
    
    func visitFIRIdentifier(
        _ expression: FIRIdentifier,
        _ info: ShortCircuitInfo
    ) -> ShortCircuitResult {
        
        let (thnLabel, elsLabel) = info.unwrapBranches()
        let branch = FIRConditionalBranch(
            condition: expression,
            thenBranch: thnLabel,
            elseBranch: elsLabel
        )
        
        return .branch(branch, [])
    }
    
    func visitFIRBoolean(
        _ expression: FIRBoolean,
        _ info: ShortCircuitInfo
    ) -> ShortCircuitResult {
        
        let (thnLabel, elsLabel) = info.unwrapBranches()
        let branch = FIRConditionalBranch(
            condition: expression,
            thenBranch: thnLabel,
            elseBranch: elsLabel
        )
        
        return .branch(branch, [])
    }
    
    func visitFIRUnaryExpression(
        _ operation: FIRUnaryExpression,
        _ info: ShortCircuitInfo
    ) -> ShortCircuitResult {
        
        if operation.op == .not {
            let result = operation.expr.acceptVisitor(self, info)
            let (branch, newBlocks) = result.unwrapBranch()
            
            let newBranch = FIRConditionalBranch(
                condition: branch.condition,
                thenBranch: branch.elseBranch,
                elseBranch: branch.thenBranch
            )
            
            return .branch(newBranch, newBlocks)
        }
        
        let (newSubexpr, newPrologue) = operation.expr.acceptVisitor(self, info).unwrapSubexpression()
        let newBoundExpr = FIRUnaryExpression(op: operation.op, expr: newSubexpr)
        let newBinding = GenSymInfo.singleton.genSym(root: "un_op_subexpr", id: nil)
        let newAssignment = FIRAssignment(name: newBinding, value: newBoundExpr)
        let newIdentifier = FIRIdentifier(name: newBinding)
        return .subexpression(newIdentifier, newPrologue + [newAssignment])
    }
    
    func visitFIRBinaryExpression(
        _ operation: FIRBinaryExpression,
        _ info: ShortCircuitInfo
    ) -> ShortCircuitResult {
        let (thnBranch, elsBranch) = info.unwrapBranches()
        
        if operation.op.isBoolean() {
            
            let (rhsBranch, rhsBlocks) = operation.rhs.acceptVisitor(self, info).unwrapBranch()
            
            let midName = GenSymInfo.singleton.genSym(root: "short_circuit_mid", id: nil)
            let thenLabel = operation.op == .and ? midName : thnBranch
            let elseLabel = operation.op == .and ? elsBranch : midName
            
            let lhsInfo = ShortCircuitInfo(thn: thenLabel, els: elseLabel)
            let (lhsBranch, lhsBlocks) = operation.lhs.acceptVisitor(self, lhsInfo).unwrapBranch()
            
            let midLabel = FIRLabel(name: midName)
            let midBlock = FIRBasicBlock(
                label: midLabel,
                statements: [],
                terminator: rhsBranch
            )
            
            let newBlocks: [FIRBasicBlock] = lhsBlocks + [midBlock] + rhsBlocks
            return .branch(lhsBranch, newBlocks)
            
        } else {
            
            let condBranch = FIRConditionalBranch(
                condition: operation,
                thenBranch: info.thn,
                elseBranch: info.els
            )
            
            return .branch(condBranch, [])
        }
    }
    
    func visitFIRFunctionCall(
        _ statement: FIRFunctionCall,
        _ info: ShortCircuitInfo
    ) -> ShortCircuitResult {
        
        let (thnLabel, elsLabel) = info.unwrapBranches()
        let branch = FIRConditionalBranch(
            condition: statement,
            thenBranch: thnLabel,
            elseBranch: elsLabel
        )
        
        return .branch(branch, [])
    }
    
}

// unreachables
extension ShortCircuitingForIfStatementCondition {
    
    func visitFIRInteger(
        _ expression: FIRInteger,
        _ info: ShortCircuitInfo
    ) -> ShortCircuitResult {
        
        InternalCompilerError.unreachable(
            "FIR integers cannot appear in a short-circuiting operation"
        )
    }
    
    func visitFIRAssignment(
        _ definition: FIRAssignment,
        _ info: ShortCircuitInfo
    ) -> VisitorResult {
        
        InternalCompilerError.unreachable(
            "FIR assignments cannot appear in a short-circuiting operation"
        )
    }
    
    func visitFIRBranch(
        _ expression: FIRBranch,
        _ info: ShortCircuitInfo
    ) -> VisitorResult {
        
        InternalCompilerError.unreachable(
            "FIR branches cannot appear in a short-circuiting operation"
        )
    }
    
    func visitFIRJump(
        _ statement: FIRJump,
        _ info: ShortCircuitInfo
    ) -> VisitorResult {
        
        InternalCompilerError.unreachable(
            "FIR jumps cannot appear in a short-circuiting operation"
        )
    }
    
    func visitFIRLabel(
        _ statement: FIRLabel,
        _ info: ShortCircuitInfo
    ) -> VisitorResult {
        
        InternalCompilerError.unreachable(
            "FIR labels cannot appear in a short-circuiting operation"
        )
    }
    
    func visitFIRReturn(
        _ statement: FIRReturn,
        _ info: ShortCircuitInfo
    ) -> VisitorResult {
        
        InternalCompilerError.unreachable(
            "FIR return statements cannot appear in a short-circuiting operation"
        )
    }
    
    func visitFIREmptyTuple(
        _ empty: FIREmptyTuple,
        _ info: ShortCircuitInfo
    ) -> ShortCircuitResult {
        
        InternalCompilerError.unreachable(
            "FIR void values cannot appear in a short-circuiting operation"
        )
    }
}
