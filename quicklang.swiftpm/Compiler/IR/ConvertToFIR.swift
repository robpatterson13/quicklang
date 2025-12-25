//
//  ConvertToFIR.swift
//  quicklang
//
//  Created by Rob Patterson on 12/1/25.
//

import Foundation

struct FIRVisitInfo: @unchecked Sendable {
    // used for AST constructs that can appear
    // in both expression position and as a statement in a block
    // as an example, function application
    enum FIRVisitContext {
        case blockLevelItem
        case asAnExpression
        case fromTopLevel
    }
    
    let context: FIRVisitContext
    let parentBlockName: String?
    let endWithBranchToHere: String?
    
    typealias ReturnBranchInfo = String
    let returnBranch: ReturnBranchInfo?
    
    private init(
        context: FIRVisitContext,
        parentBlockName: String?,
        endWithBranchToHere: String? = nil,
        returnBranch: ReturnBranchInfo? = nil
    ) {
        self.context = context
        self.parentBlockName = parentBlockName
        self.endWithBranchToHere = endWithBranchToHere
        self.returnBranch = returnBranch
    }
    
    static let asAnExpression: Self = .init(context: .asAnExpression, parentBlockName: nil)
    static let blockLevelItem: Self = .init(context: .blockLevelItem, parentBlockName: nil)
    static let fromTopLevel: Self = .init(context: .fromTopLevel, parentBlockName: nil)
    
    func withParentBlock(name: String) -> FIRVisitInfo {
        .init(
            context: context,
            parentBlockName: name,
            endWithBranchToHere: endWithBranchToHere,
            returnBranch: returnBranch
        )
    }
    
    func addFinalBranchTo(name: String) -> FIRVisitInfo {
        .init(
            context: context,
            parentBlockName: parentBlockName,
            endWithBranchToHere: name,
            returnBranch: returnBranch
        )
    }
    
    func addReturnBranch(info: ReturnBranchInfo?) -> FIRVisitInfo {
        .init(
            context: context,
            parentBlockName: parentBlockName,
            endWithBranchToHere: endWithBranchToHere,
            returnBranch: info
        )
    }
}

enum FIRVisitResult {
    case statement(any FIRBasicBlockItem)
    case expression(any FIRExpression)
    case terminator(any FIRTerminator)
    case label(FIRLabel)
    case function(FIRFunction)
    
    indirect case ifStatement(
        terminator: any FIRTerminator,
        thenBlock: [FIRVisitResult],
        elseBlock: [FIRVisitResult]?,
        
        // optional because desugared if statements are already taken care of,
        // i.e. this join label has already been added at the top-most level;
        // keeping it in a desugared if statement visit result would mean that
        // we would add a new block with the join label for each non-else
        // (if/else if) branch in the sugared conditional
        joinLabel: FIRLabel?
    )
    
    func unwrapExpression() -> any FIRExpression {
        switch self {
        case .expression(let expression):
            return expression
        default:
            InternalCompilerError.unreachable("Cannot unwrap non-FIRExpression as FIRExpression")
        }
    }
}

final class ConvertToRawFIR: CompilerPhase, ASTVisitor {
    
    typealias InputType = ASTContext
    typealias SuccessfulResult = FIRModule
    
    var context: ASTContext?
    var errorManager: CompilerErrorManager?
    
    let shortCircuitingForIfStatementCondition = ShortCircuitingForIfStatementCondition()
    
    private var ifStatementEndBlockMapping: [String: String] = [:]
    
    func begin(_ input: ASTContext) -> PhaseResult<ConvertToRawFIR> {
        var nodes: [FIRFunction] = []
        self.context = input
        
        input.tree.sections.forEach { node in
            let result = node.acceptVisitor(self, .fromTopLevel)
            switch result {
            case .function(let function):
                nodes.append(function)
                
            default:
                fatalError("Not supported at the top level")
            }
        }
        
        addBasicBlocksToContext(nodes)
        let module = FIRModule(nodes: nodes)
        shortCircuitingForIfStatementCondition.begin(module)
        return .success(result: module)
    }
    
    private func addBasicBlocksToContext(_ functions: [FIRFunction]) {
        for function in functions {
            for block in function.blocks {
                context?.addCFGMapping(block.label.name, block)
            }
        }
    }
    
    init(errorManager: CompilerErrorManager, settings: DriverSettings) {
        self.errorManager = errorManager
    }
    
    func visitIdentifierExpression(
        _ expression: IdentifierExpression,
        _ info: FIRVisitInfo
    ) -> FIRVisitResult {
        let expression = FIRIdentifier(name: expression.name)
        return .expression(expression.copy())
    }
    
    func visitBooleanExpression(
        _ expression: BooleanExpression,
        _ info: FIRVisitInfo
    ) -> FIRVisitResult {
        let expression = FIRBoolean(value: expression.value)
        return .expression(expression.copy())
    }
    
    func visitNumberExpression(
        _ expression: NumberExpression,
        _ info: FIRVisitInfo
    ) -> FIRVisitResult {
        let expression = FIRInteger(value: expression.value)
        return .expression(expression.copy())
    }
    
    func visitUnaryOperation(
        _ operation: UnaryOperation,
        _ info: FIRVisitInfo
    ) -> FIRVisitResult {
        let expression = operation.expression.acceptVisitor(self, info)
        let unaryExpression = FIRUnaryExpression(
            op: FIROperation.convert(from: operation.op),
            expr: expression.unwrapExpression()
        )
        
        return .expression(unaryExpression.copy())
    }
    
    func visitBinaryOperation(
        _ operation: BinaryOperation,
        _ info: FIRVisitInfo
    ) -> FIRVisitResult {
        let lhs = operation.lhs.acceptVisitor(self, info)
        let rhs = operation.rhs.acceptVisitor(self, info)
        let binaryExpression = FIRBinaryExpression(
            op: FIROperation.convert(from: operation.op),
            lhs: lhs.unwrapExpression(),
            rhs: rhs.unwrapExpression()
        )
        
        return .expression(binaryExpression.copy())
    }
    
    func visitDefinition(
        _ definition: DefinitionNode,
        _ info: FIRVisitInfo
    ) -> FIRVisitResult {
        let value = definition.expression.acceptVisitor(self, .asAnExpression.withParentBlock(name: info.parentBlockName!))
        let assignment = FIRAssignment(name: definition.name, value: value.unwrapExpression())
        
        return .statement(assignment.copy())
    }
    
    func visitFuncDefinition(
        _ definition: FuncDefinition,
        _ info: FIRVisitInfo
    ) -> FIRVisitResult {
        let returnName = "$0$return"
        let returnLabel = FIRLabel(name: "\(definition.name)$return")
        let visitInfo = FIRVisitInfo
            .blockLevelItem
            .withParentBlock(name: definition.name)
            .addReturnBranch(info: returnName)
        
        let body = processBlock(
            definition.body,
            visitInfo
        )
        let parameters: [FIRParameter] = definition.parameters.map { param in
            return .init(name: param.name, type: .convertFrom(param.type))
        }
        
        let entryLabel = FIRLabel(name: "\(definition.name)$entry")
        var parsedBody = parseIntoBasicBlocks(body, entryLabel)
        
        let returnParameter = FIRParameter(name: returnName, type: .convertFrom(definition.type.returnType!))
        let returnIdentifier = FIRIdentifier(name: returnName)
        let returnInstruction = FIRReturn(value: returnIdentifier)
        let returnBlock = FIRBasicBlock(
            label: returnLabel,
            statements: [],
            terminator: returnInstruction,
            parameter: returnParameter
        )
        
        parsedBody.append(returnBlock)
        
        return .function(
            FIRFunction(blocks: parsedBody, parameters: parameters)
        )
    }
    
    func visitFuncApplication(
        _ expression: FuncApplication,
        _ info: FIRVisitInfo
    ) -> FIRVisitResult {
        let arguments = expression.arguments.map { node in
            let newExpression = node.acceptVisitor(self, .asAnExpression)
            return newExpression.unwrapExpression()
        }
        
        let callExpression = FIRFunctionCall(function: expression.name, parameter: arguments)
        
        switch info.context {
        case .blockLevelItem, .fromTopLevel:
            return .statement(callExpression.copy())
        case .asAnExpression:
            return .expression(callExpression.copy())
        }
    }
    
    func visitReturnStatement(
        _ statement: ReturnStatement,
        _ info: FIRVisitInfo
    ) -> FIRVisitResult {
        let value = statement.expression.acceptVisitor(self, .asAnExpression)
        let label = FIRLabel(name: info.returnBranch!)
        let branch = FIRBranch(label: label.copy(), value: value.unwrapExpression())
        
        return .terminator(branch.copy())
    }
    
    func visitAssignmentStatement(
        _ statement: AssignmentStatement,
        _ info: FIRVisitInfo
    ) -> FIRVisitResult {
        let value = statement.expression.acceptVisitor(self, .asAnExpression)
        let definition = FIRAssignment(name: statement.name, value: value.unwrapExpression().copy())
        
        return .statement(definition.copy())
    }
    
    private func genName(from node: any ASTNode, root: String, with contextName: String?) -> String {
        var newName = "\(GenSymInfo.singleton.genSym(root: root, id: node.id))"
        if let contextName {
            newName = "\(contextName)$\(newName)"
        }
        
        return newName
    }
    
    func visitIfStatement(
        _ statement: IfStatement,
        _ info: FIRVisitInfo
    ) -> FIRVisitResult {
        
        let ifName = genName(from: statement, root: "if", with: info.parentBlockName)
        
        // we want to know if this if statement is the result of a desugaring; if it
        // is, then we have already cached the join label that we will use instead
        // of making a new one
        let joinLabel: FIRLabel
        if let desugaredFrom = statement.desugaredFrom {
            // guaranteed that this will be here; any desugared derived if statements
            // must be processed after the if statement they were desugared from
            let endBlockName = ifStatementEndBlockMapping[desugaredFrom]!
            joinLabel = FIRLabel(name: endBlockName)
        } else {
            let endBlockName = "\(ifName)$end"
            joinLabel = FIRLabel(name: endBlockName)
            ifStatementEndBlockMapping[statement.id.uuidString] = endBlockName
        }
        
        let condition = statement.condition.acceptVisitor(self, .asAnExpression)
            .unwrapExpression()
        
        let thenName = "\(ifName)$then"
        let thenLabel = FIRLabel(name: thenName)
        let processedThen = processBlock(
            statement.thenBranch,
            .blockLevelItem
                .withParentBlock(name: thenName)
                .addReturnBranch(info: info.returnBranch)
        )
        
        var processedElse: [FIRVisitResult]? = nil
        let elseName = "\(ifName)$else"
        let elseLabel = FIRLabel(name: elseName)
        if let elseBranch = statement.elseBranch {
            processedElse = processBlock(
                elseBranch,
                .blockLevelItem
                    .withParentBlock(name: elseName)
                    .addReturnBranch(info: info.returnBranch)
            )
        }
        
        let branch = FIRConditionalBranch(
            condition: condition.copy(),
            thenBranch: thenLabel.copy(),
            elseBranch: (processedElse == nil ? joinLabel : elseLabel).copy()
        )
        
        let branchToJoin = FIRBranch(label: joinLabel)
        
        let finalThen = [.label(thenLabel)] + processedThen + [.terminator(branchToJoin)]
        var finalElse: [FIRVisitResult]? = nil
        if let processedElse {
            finalElse = [.label(elseLabel)] + processedElse + [.terminator(branchToJoin)]
        }
        
        return .ifStatement(
            terminator: branch.copy(),
            thenBlock: finalThen,
            elseBlock: finalElse,
            joinLabel: statement.isResultOfDesugaring() ? nil : joinLabel.copy()
        )
    }
    
    private func processBlock(
        _ block: [any BlockLevelNode],
        _ info: FIRVisitInfo
    ) -> [FIRVisitResult] {
        var nodes: [FIRVisitResult] = []
        for node in block {
            // we need a continuation point if we have some scope that is implicitly dropped,
            // eg. we are in an if statement within a function and we need jump back out
            // of the if statement and into the function body. this isn't made explicit by
            // the syntax of the program, so it needs to be done when we are processing a block
            // (aka scope)
            if node.needsContinuationPoint() {
                let continuationName = GenSymInfo.singleton.genSym(root: "needs$continuation$", id: nil)
                let result = node.acceptVisitor(self, info)
                let continuationLabel = FIRLabel(name: continuationName)
                let branch = FIRBranch(label: continuationLabel.copy())
                nodes.append(result)
                nodes.append(.terminator(branch.copy()))
                nodes.append(.label(continuationLabel))
            } else {
                let result = node.acceptVisitor(self, info)
                nodes.append(result)
            }
        }
        
        return nodes
    }
    
    private func parseIntoBasicBlocks(
        _ result: [FIRVisitResult],
        _ initialLabel: FIRLabelRepresentable = FIRLabelHole()
    ) -> [FIRBasicBlock] {
        
        var blocks: [FIRBasicBlock] = []
        var currentBlockItems: [FIRBasicBlockItem] = []
        var currentLabel: FIRLabelRepresentable = initialLabel
        var shouldDropTerminator = false
        
        let finishCurrentBlock: (FIRTerminator) -> Void = { [self] terminator in
            guard let currentLabelCast = currentLabel as? FIRLabel else {
                InternalCompilerError.unreachable("Can't finish a block without a label")
            }
            let block = onParseTerminator(terminator, label: currentLabelCast.copy(), items: currentBlockItems)
            blocks.append(block)
            
            currentBlockItems = []
            currentLabel = FIRLabelHole()
            shouldDropTerminator = true
        }
        
        let markLabel: (FIRLabelRepresentable) -> Void = { label in
            currentLabel = label.copy()
        }
        
        let handleIf: (
            _ terminator: FIRTerminator,
            _ thenBlock: [FIRVisitResult],
            _ elseBlock: [FIRVisitResult]?,
            _ joinLabel: FIRLabelRepresentable?
        ) -> Void = { [self] terminator, thenBlock, elseBlock, joinLabel in
            finishCurrentBlock(terminator)
            let thenBasicBlock = parseIntoBasicBlocks(thenBlock)
            blocks.append(contentsOf: thenBasicBlock)
            if let elseBlockRaw = elseBlock {
                let elseBasicBlock = parseIntoBasicBlocks(elseBlockRaw)
                blocks.append(contentsOf: elseBasicBlock)
            }
            if let joinLabel {
                markLabel(joinLabel)
            }
        }
        
        for node in result {
            switch node {
            case .statement(let statement):
                shouldDropTerminator = false
                currentBlockItems.append(statement)
                
            case .terminator(let terminator):
                if shouldDropTerminator && currentLabel is FIRLabelHole {
                    if let lastBlock = blocks.last {
                        lastBlock.unreachableTerminators.append(terminator.copy())
                    } else {
                        continue
                    }
                } else {
                    finishCurrentBlock(terminator.copy())
                }
                
            case .label(let label):
                shouldDropTerminator = false
                markLabel(label.copy())
                
            case .ifStatement(let terminator, let thenBlock, let elseBlock, let joinLabel):
                shouldDropTerminator = false
                handleIf(terminator.copy(), thenBlock, elseBlock, joinLabel)
                
            case .expression:
                InternalCompilerError.unreachable("Expressions cannot be in basic blocks")
            case .function:
                InternalCompilerError.unreachable("Functions cannot be nested")
            }
        }
        
        return blocks
    }
    
    private func onParseTerminator(
        _ terminator: FIRTerminator,
        label: FIRLabel,
        items: [FIRBasicBlockItem]
    ) -> FIRBasicBlock {
        return .init(label: label.copy(), statements: items, terminator: terminator.copy())
    }
}
