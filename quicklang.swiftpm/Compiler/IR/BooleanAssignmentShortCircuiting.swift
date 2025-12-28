//
//  BooleanAssignmentShortCircuiting.swift
//  quicklang
//
//  Created by Rob Patterson on 12/26/25.
//

struct BooleanAssignmentShortCircuitingInfo {
    var thn: String?
    var els: String?
    var returnBranch: String?
    var joinBlockName: String?
    
    var kind: Kind = .subexpression
    enum Kind {
        case subexpression
        case branch
    }
    
    func asSubexpression() -> Self {
        .init(thn: thn, els: els, returnBranch: returnBranch, joinBlockName: joinBlockName, kind: .subexpression)
    }
    
    func asBranch() -> Self {
        .init(thn: thn, els: els, returnBranch: returnBranch, joinBlockName: joinBlockName, kind: .subexpression)
    }
    
    func unwrapBranches() -> (thn: String?, els: String?) {
        return (thn: thn, els: els)
    }
}

enum BooleanAssignmentShortCircuitingResult {
    case branch(FIRConditionalBranch, [FIRBasicBlock])
    
    func unwrapBranch() -> (FIRConditionalBranch, [FIRBasicBlock]) {
        switch self {
        case .branch(let branch, let blocks):
            return (branch, blocks)
        @unknown default:
            InternalCompilerError.unreachable("Can't unwrap non-expression as expression")
        }
    }
}

// short circuiting for when we need an actual boolean value on
// assignment statements
final class BooleanAssignmentShortCircuiting: FIRVisitor {
    
    typealias VisitorInfo = BooleanAssignmentShortCircuitingInfo
    typealias VisitorResult = BooleanAssignmentShortCircuitingResult
    
    func begin(_ module: FIRModule) {
        for function in module.nodes {
            processFunction(function)
        }
    }
    
    private func processFunction(_ function: FIRFunction) {
        guard let returnBlock = function.returnBlock else {
            InternalCompilerError.unreachable(
                "We must have a return block at this point, even if synthesized as a type-incorrect void return"
            )
        }
        
        var newBlocks: [FIRBasicBlock] = []
        for block in function.blocks {
            // skip the return block, it doesn't need to be visited
            guard block !== returnBlock else {
                newBlocks.append(block)
                continue
            }
            
            let result = processBasicBlock(block, returnBranch: returnBlock.label.name)
            newBlocks.append(contentsOf: result)
        }
        
        function.blocks = newBlocks
    }
    
    private func processBasicBlock(
        _ block: FIRBasicBlock,
        returnBranch: String
    ) -> [FIRBasicBlock] {
        
        var newBlocks: [FIRBasicBlock] = []
        var builder = FIRBasicBlock.Builder()
        builder.addLabel(block.label)
        
        var info = BooleanAssignmentShortCircuitingInfo(returnBranch: returnBranch)
        for blockItem in block.statements {
            if blockItem.visitDuringValueProducingBooleanExpansion() {
                // if we have an instruction that saves a value, i.e. an assignment,
                // we need to come back and finish the rest of the basic block
                let joinBlockName = GenSymInfo.singleton.genSym(root: "join_block")
                info.joinBlockName = joinBlockName
                let joinLabel = FIRLabel(name: joinBlockName)
                
                let (visitBranch, visitBlocks) = blockItem.acceptVisitor(self, info).unwrapBranch()
                newBlocks.append(contentsOf: visitBlocks)
                builder.addTerminator(visitBranch)
                let newBlock = builder.build()
                newBlocks.append(newBlock)
                builder = .init()
                
                builder.addLabel(joinLabel.copy())
                
            } else {
                // just add the unprocessed statement here, it doesn't need to
                // be expanded
                builder.addStatement(blockItem)
            }
        }
        
        // handle the terminator here; we only have one possible case for expansion,
        // return statements with booleans as values
        if let returnStmt = block.terminator as? FIRReturn {
            let (visitBranch, visitBlocks) = returnStmt.acceptVisitor(self, info).unwrapBranch()
            newBlocks.append(contentsOf: visitBlocks)
            builder.addTerminator(visitBranch)
        } else {
            builder.addTerminator(block.terminator)
        }
        
        let newBlock = builder.build()
        newBlocks.append(newBlock)
        
        return newBlocks
    }
    
    func visitFIRIdentifier(
        _ expression: FIRIdentifier,
        _ info: BooleanAssignmentShortCircuitingInfo)
    -> BooleanAssignmentShortCircuitingResult {
        
        let condition = FIRConditionalBranch(
            condition: expression,
            thenBranch: info.thn!,
            elseBranch: info.els!
        )
        return .branch(condition, [])
    }
    
    func visitFIRBoolean(
        _ expression: FIRBoolean,
        _ info: BooleanAssignmentShortCircuitingInfo
    ) -> BooleanAssignmentShortCircuitingResult {
        
        let condition = FIRConditionalBranch(
            condition: expression,
            thenBranch: info.thn!,
            elseBranch: info.els!
        )
        return .branch(condition, [])
    }
    
    func visitFIRUnaryExpression(
        _ operation: FIRUnaryExpression,
        _ info: BooleanAssignmentShortCircuitingInfo
    ) -> BooleanAssignmentShortCircuitingResult {
        
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
        
        InternalCompilerError.unreachable()
    }
    
    func visitFIRBinaryExpression(
        _ operation: FIRBinaryExpression,
        _ info: BooleanAssignmentShortCircuitingInfo
    ) -> BooleanAssignmentShortCircuitingResult {
        let (thnBranch, elsBranch) = info.unwrapBranches()
        
        if operation.op.isBoolean() {
            
            let (rhsBranch, rhsBlocks) = operation.rhs.acceptVisitor(self, info).unwrapBranch()
            
            let midName = GenSymInfo.singleton.genSym(root: "short_circuit_mid", id: nil)
            let thenLabel = operation.op == .and ? midName : thnBranch
            let elseLabel = operation.op == .and ? elsBranch : midName
            
            let lhsInfo = BooleanAssignmentShortCircuitingInfo(thn: thenLabel, els: elseLabel)
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
                thenBranch: info.thn!,
                elseBranch: info.els!
            )
            
            return .branch(condBranch, [])
        }
    }
    
    func visitFIRFunctionCall(
        _ statement: FIRFunctionCall,
        _ info: BooleanAssignmentShortCircuitingInfo
    ) -> BooleanAssignmentShortCircuitingResult {
        
        let (thnLabel, elsLabel) = info.unwrapBranches()
        let branch = FIRConditionalBranch(
            condition: statement,
            thenBranch: thnLabel!,
            elseBranch: elsLabel!
        )
        
        return .branch(branch, [])
    }
    
    // the below all give us some boolean value that we need
    // to short circuit and assign to a value, then join
    // with a block argument
    func visitFIRAssignment(
        _ definition: FIRAssignment,
        _ info: BooleanAssignmentShortCircuitingInfo
    ) -> BooleanAssignmentShortCircuitingResult {
        
        let basicBlockWithArgName = GenSymInfo.singleton.genSym(root: "bool_assign")
        let basicBlockWithArgLabel = FIRLabel(name: basicBlockWithArgName)
        let argName = GenSymInfo.singleton.genSym(root: "bool_value")
        let argIdentifier = FIRIdentifier(name: argName)
        let assignment = FIRAssignment(name: definition.name, value: argIdentifier)
        let basicBlockWithArg = FIRBasicBlock(
            label: basicBlockWithArgLabel.copy(),
            statements: [assignment],
            terminator: FIRBranch(label: info.joinBlockName!),
            parameter: FIRParameter(name: argName, type: .Bool)
        )
        
        let trueLabelName = GenSymInfo.singleton.genSym(root: "true_path")
        let trueLabel = FIRLabel(name: trueLabelName)
        let trueBranch = FIRBranch(label: basicBlockWithArgName, value: FIRBoolean(value: true))
        let trueLabelBlock = FIRBasicBlock(
            label: trueLabel.copy(),
            statements: [],
            terminator: trueBranch
        )
        
        let falseLabelName = GenSymInfo.singleton.genSym(root: "false_path")
        let falseLabel = FIRLabel(name: falseLabelName)
        let falseBranch = FIRBranch(label: basicBlockWithArgName, value: FIRBoolean(value: false))
        let falseLabelBlock = FIRBasicBlock(
            label: falseLabel.copy(),
            statements: [],
            terminator: falseBranch
        )
        
        let info = BooleanAssignmentShortCircuitingInfo(thn: trueLabelName, els: falseLabelName, returnBranch: info.returnBranch)
        var (visitBranch, visitBlocks) = definition.value.acceptVisitor(self, info).unwrapBranch()
        
        visitBlocks.append(contentsOf: [trueLabelBlock, falseLabelBlock, basicBlockWithArg])
        
        let result = BooleanAssignmentShortCircuitingResult.branch(visitBranch, visitBlocks)
        return result
    }
    
    func visitFIRReturn(
        _ statement: FIRReturn,
        _ info: BooleanAssignmentShortCircuitingInfo
    ) -> BooleanAssignmentShortCircuitingResult {
        
        let trueLabelName = GenSymInfo.singleton.genSym(root: "true_path")
        let trueLabel = FIRLabel(name: trueLabelName)
        let trueBranch = FIRBranch(label: info.returnBranch!, value: FIRBoolean(value: true))
        let trueLabelBlock = FIRBasicBlock(
            label: trueLabel.copy(),
            statements: [],
            terminator: trueBranch
        )
        
        let falseLabelName = GenSymInfo.singleton.genSym(root: "false_path")
        let falseLabel = FIRLabel(name: falseLabelName)
        let falseBranch = FIRBranch(label: info.returnBranch!, value: FIRBoolean(value: false))
        let falseLabelBlock = FIRBasicBlock(
            label: falseLabel.copy(),
            statements: [],
            terminator: falseBranch
        )
        
        let info = BooleanAssignmentShortCircuitingInfo(thn: trueLabelName, els: falseLabelName, returnBranch: info.returnBranch)
        var (visitBranch, visitBlocks) = statement.value.acceptVisitor(self, info).unwrapBranch()
        
        visitBlocks.append(contentsOf: [trueLabelBlock, falseLabelBlock])
        
        let result = BooleanAssignmentShortCircuitingResult.branch(visitBranch, visitBlocks)
        return result
    }
    
}

// unreachables
extension BooleanAssignmentShortCircuiting {
    
    func visitFIRBranch(
        _ expression: FIRBranch,
        _ info: BooleanAssignmentShortCircuitingInfo
    ) -> BooleanAssignmentShortCircuitingResult {
        InternalCompilerError.unreachable()
    }
    
    func visitFIRConditionalBranch(
        _ definition: FIRConditionalBranch,
        _ info: BooleanAssignmentShortCircuitingInfo
    ) -> BooleanAssignmentShortCircuitingResult {
        InternalCompilerError.unreachable()
    }
    
    func visitFIRJump(
        _ statement: FIRJump,
        _ info: BooleanAssignmentShortCircuitingInfo
    ) -> BooleanAssignmentShortCircuitingResult {
        InternalCompilerError.unreachable()
    }
    
    func visitFIRLabel(
        _ statement: FIRLabel,
        _ info: BooleanAssignmentShortCircuitingInfo
    ) -> BooleanAssignmentShortCircuitingResult {
        InternalCompilerError.unreachable()
    }
    
    func visitFIREmptyTuple(
        _ empty: FIREmptyTuple,
        _ info: BooleanAssignmentShortCircuitingInfo
    ) -> BooleanAssignmentShortCircuitingResult {
        InternalCompilerError.unreachable()
    }
    
    func visitFIRInteger(
        _ expression: FIRInteger,
        _ info: BooleanAssignmentShortCircuitingInfo
    ) -> BooleanAssignmentShortCircuitingResult {
        InternalCompilerError.unreachable()
    }
}
