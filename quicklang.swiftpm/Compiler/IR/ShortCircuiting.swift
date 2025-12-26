//
//  ShortCircuiting.swift
//  quicklang
//
//  Created by Rob Patterson on 12/20/25.
//

final class ShortCircuitingForIfStatementCondition: FIRVisitor {
    
    struct ShortCircuitContext {
        var parentBlockName: String?
        var thenLabel: String
        var elseLabel: String
        var isNegated: Bool = false
        
        func extendParentBlockName(_ parentBlockName: String) -> Self {
            let name = if let existingName = self.parentBlockName {
                existingName + "$\(parentBlockName)"
            } else {
                parentBlockName
            }
            
            return .init(parentBlockName: name, thenLabel: self.thenLabel, elseLabel: self.elseLabel, isNegated: isNegated)
        }
        
        func changeLabels(thenLabel: String? = nil, elseLabel: String? = nil) -> Self {
            .init(thenLabel: thenLabel ?? self.thenLabel, elseLabel: elseLabel ?? self.elseLabel, isNegated: isNegated)
        }
        
        func getLabels() -> (thenLabel: String, elseLabel: String) {
            (thenLabel: thenLabel, elseLabel: elseLabel)
        }
        
        func negate() -> Self {
            .init(thenLabel: thenLabel, elseLabel: elseLabel, isNegated: !isNegated)
        }
    }
    
    struct ShortCircuitResult {
        var terminator: FIRTerminator? = nil
        let branchToConnectTo: String
        let prologue: [FIRBasicBlock]
    }
    
    typealias VisitorResult = ShortCircuitResult
    typealias VisitorInfo = ShortCircuitContext
    
    func begin(_ module: FIRModule) {
        for function in module.nodes {
            processFunction(function)
        }
    }
    
    private func processFunction(_ function: FIRFunction) {
        var prologue: [FIRBasicBlock] = []
        for block in function.blocks {
            guard let branch = block.terminator as? FIRConditionalBranch else {
                return
            }
            
            let labels: ShortCircuitContext = .init(
                thenLabel: branch.elseBranch,
                elseLabel: branch.thenBranch
            )
            let result = branch.acceptVisitor(self, labels)
            prologue.append(contentsOf: result.prologue)
            guard let terminator = result.terminator else {
                InternalCompilerError.unreachable("Must have a terminator at this point")
            }
            block.terminator = terminator
        }
        function.blocks.append(contentsOf: prologue)
    }
    
    func visitFIRConditionalBranch(
        _ definition: FIRConditionalBranch,
        _ info: ShortCircuitContext
    ) -> VisitorResult {
        let context: ShortCircuitContext = .init(
            parentBlockName: GenSymInfo.singleton.genSym(root: "cond_br", id: nil),
            thenLabel: definition.thenBranch,
            elseLabel: definition.elseBranch
        )
        let processedCond = definition.condition.acceptVisitor(self, context)
        
        let branch = FIRBranch(label: processedCond.branchToConnectTo)
        
        return .init(terminator: branch, branchToConnectTo: "n/a", prologue: processedCond.prologue)
    }
    
    func visitFIRUnaryExpression(
        _ operation: FIRUnaryExpression,
        _ info: ShortCircuitContext
    ) -> VisitorResult {
        switch operation.op {
        case .not:
            return operation.expr.acceptVisitor(self, info.negate())
        case .neg:
            InternalCompilerError.unreachable("Not possible at this point")
        default:
            InternalCompilerError.unreachable("Not possible to have a non-boolean expression")
        }
    }
    
    func visitFIRBinaryExpression(
        _ operation: FIRBinaryExpression,
        _ info: ShortCircuitContext
    ) -> VisitorResult {
        let (thenBranch, elseBranch) = info.getLabels()
        
        switch operation.op {
        case .and, .or:
            var prologue = [FIRBasicBlock]()
            let rhsThenLabel = info.isNegated ? elseBranch : thenBranch
            let rhsElseLabel = info.isNegated ? thenBranch : elseBranch
            
            let rhsInfo = info.changeLabels(thenLabel: rhsThenLabel, elseLabel: rhsElseLabel)
            let rhsResult = operation.rhs.acceptVisitor(self, rhsInfo.extendParentBlockName("rhs"))
            
            let lhsThenLabel = operation.op == .and ? rhsResult.branchToConnectTo : rhsThenLabel
            let lhsElseLabel = operation.op == .and ? rhsElseLabel : rhsResult.branchToConnectTo
            let lhsInfo = info.changeLabels(thenLabel: lhsThenLabel, elseLabel: lhsElseLabel)
            let lhsResult = operation.lhs.acceptVisitor(self, lhsInfo.extendParentBlockName("lhs"))
            
            prologue.append(contentsOf: lhsResult.prologue + rhsResult.prologue)
            
            return .init(
                branchToConnectTo: lhsResult.branchToConnectTo,
                prologue: prologue
            )
        default:
            InternalCompilerError.unreachable("Not possible; all non-boolean operations should be lifted out of the if statement condition")
        }
    }
    
    private func giveBackExpressionWithNegationConsidered(
        _ expression: any FIRExpression,
        _ info: ShortCircuitContext,
        root: String
    ) -> ShortCircuitResult {
        let (thenLabel, elseLabel) = info.getLabels()
        let thenBranch = FIRLabel(name: info.isNegated ? elseLabel : thenLabel)
        let elseBranch = FIRLabel(name: info.isNegated ? thenLabel : elseLabel)
        var expression = expression
        if info.isNegated {
            expression = FIRUnaryExpression(op: .not, expr: expression)
        }
        
        let newTerminator = FIRConditionalBranch(
            condition: expression,
            thenBranch: thenBranch.name,
            elseBranch: elseBranch.name
        )
        let gensym = GenSymInfo.singleton.genSym(root: root, id: nil)
        let newBlockName = info.extendParentBlockName(gensym).parentBlockName!
        let newBlock = FIRBasicBlock(
            label: FIRLabel(name: newBlockName),
            statements: [],
            terminator: newTerminator
        )
        
        return .init(branchToConnectTo: newBlockName, prologue: [newBlock])
    }
    
    func visitFIRIdentifier(
        _ expression: FIRIdentifier,
        _ info: ShortCircuitContext
    ) -> VisitorResult {
        giveBackExpressionWithNegationConsidered(expression, info, root: expression.name)
    }
    
    func visitFIRBoolean(
        _ expression: FIRBoolean,
        _ info: ShortCircuitContext
    ) -> VisitorResult {
        giveBackExpressionWithNegationConsidered(expression, info, root: "boolean")
    }
    
    func visitFIRFunctionCall(
        _ statement: FIRFunctionCall,
        _ info: ShortCircuitContext
    ) -> VisitorResult {
        giveBackExpressionWithNegationConsidered(statement, info, root: "call$\(statement.function)")
    }
    
}

// unreachables
extension ShortCircuitingForIfStatementCondition {
    
    func visitFIRAssignment(
        _ definition: FIRAssignment,
        _ info: ShortCircuitContext
    ) -> VisitorResult {
        
        InternalCompilerError.unreachable(
            "FIR assignments cannot appear in a short-circuiting operation"
        )
    }
    
    func visitFIRBranch(
        _ expression: FIRBranch,
        _ info: ShortCircuitContext
    ) -> VisitorResult {
        
        InternalCompilerError.unreachable(
            "FIR branches cannot appear in a short-circuiting operation"
        )
    }
    
    func visitFIRInteger(
        _ expression: FIRInteger,
        _ info: ShortCircuitContext
    ) -> VisitorResult {
        
        InternalCompilerError.unreachable(
            "FIR integers cannot appear in a short-circuiting operation"
        )
    }
    
    func visitFIRJump(
        _ statement: FIRJump,
        _ info: ShortCircuitContext
    ) -> VisitorResult {
        
        InternalCompilerError.unreachable(
            "FIR jumps cannot appear in a short-circuiting operation"
        )
    }
    
    func visitFIRLabel(
        _ statement: FIRLabel,
        _ info: ShortCircuitContext
    ) -> VisitorResult {
        
        InternalCompilerError.unreachable(
            "FIR labels cannot appear in a short-circuiting operation"
        )
    }
    
    func visitFIRReturn(
        _ statement: FIRReturn,
        _ info: ShortCircuitContext
    ) -> VisitorResult {
        
        InternalCompilerError.unreachable(
            "FIR return statements cannot appear in a short-circuiting operation"
        )
    }
    
    func visitFIREmptyTuple(
        _ empty: FIREmptyTuple,
        _ info: ShortCircuitContext
    ) -> ShortCircuitResult {
        
        InternalCompilerError.unreachable(
            "FIR void values cannot appear in a short-circuiting operation"
        )
    }
}
