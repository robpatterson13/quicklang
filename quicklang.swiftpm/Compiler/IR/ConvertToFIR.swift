//
//  ConvertToFIR.swift
//  quicklang
//
//  Created by Rob Patterson on 12/1/25.
//

final class ConvertToRawFIR: CompilerPhase, ASTVisitor {
    
    typealias InputType = ASTContext
    typealias SuccessfulResult = FIRModule
    
    var errorManager: CompilerErrorManager?
    
    func begin(_ input: ASTContext) -> PhaseResult<ConvertToRawFIR> {
        var nodes: [any FIRNode] = []
        
        input.tree.sections.forEach { node in
            let result = node.acceptVisitor(self, .fromTopLevel)
            switch result {
            case .statement(let statement):
                nodes.append(statement)
            case .function(let function):
                nodes.append(function)
                
            default:
                fatalError("Not supported at the top level")
            }
        }
        
        return .success(result: FIRModule(nodes: nodes))
    }
    
    init(errorManager: CompilerErrorManager, settings: DriverSettings) {
        self.errorManager = errorManager
    }
    
    
    struct FIRVisitInfo {
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
        
        private init(context: FIRVisitContext, parentBlockName: String?) {
            self.context = context
            self.parentBlockName = parentBlockName
        }
        
        static let asAnExpression: Self = .init(context: .asAnExpression, parentBlockName: nil)
        static let blockLevelItem: Self = .init(context: .blockLevelItem, parentBlockName: nil)
        static let fromTopLevel: Self = .init(context: .fromTopLevel, parentBlockName: nil)
        
        func withParentBlock(name: String) -> FIRVisitInfo {
            .init(context: context, parentBlockName: name)
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
            joinLabel: FIRLabel
        )
        
        func unwrapExpression() -> any FIRExpression {
            switch self {
            case .expression(let expression):
                return expression
            default:
                fatalError("Cannot unwrap non-FIRExpression as FIRExpression")
            }
        }
    }
    
    func visitIdentifierExpression(
        _ expression: IdentifierExpression,
        _ info: FIRVisitInfo
    ) -> FIRVisitResult {
        let expression = FIRIdentifier(name: expression.name)
        return .expression(expression)
    }
    
    func visitBooleanExpression(
        _ expression: BooleanExpression,
        _ info: FIRVisitInfo
    ) -> FIRVisitResult {
        let expression = FIRBoolean(value: expression.value)
        return .expression(expression)
    }
    
    func visitNumberExpression(
        _ expression: NumberExpression,
        _ info: FIRVisitInfo
    ) -> FIRVisitResult {
        let expression = FIRInteger(value: expression.value)
        return .expression(expression)
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
        
        return .expression(unaryExpression)
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
        
        return .expression(binaryExpression)
    }
    
    private func visitDefinition<D: DefinitionNode>(
        _ statement: D,
        _ info: FIRVisitInfo
    ) -> FIRVisitResult {
        let value = statement.expression.acceptVisitor(self, info)
        let definition = FIRAssignment(name: statement.name, value: value.unwrapExpression())
        
        return .statement(definition)
    }
    
    func visitLetDefinition(
        _ definition: LetDefinition,
        _ info: FIRVisitInfo
    ) -> FIRVisitResult {
        visitDefinition(definition, info)
    }
    
    func visitVarDefinition(
        _ definition: VarDefinition,
        _ info: FIRVisitInfo
    ) -> FIRVisitResult {
        visitDefinition(definition, info)
    }
    
    func visitFuncDefinition(
        _ definition: FuncDefinition,
        _ info: FIRVisitInfo
    ) -> FIRVisitResult {
        let body = processBlock(
            definition.body,
            .blockLevelItem.withParentBlock(name: definition.name)
        )
        let parameters: [FIRParameter] = definition.parameters.map { param in
            return .init(name: param.name, type: .convertFrom(param.type))
        }
        
        let entryLabel = FIRLabel(name: "\(definition)$entry_")
        let parsedBody = parseIntoBasicBlocks(body, nil, entryLabel)
        
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
            return .statement(callExpression)
        case .asAnExpression:
            return .expression(callExpression)
        }
    }
    
    func visitReturnStatement(
        _ statement: ReturnStatement,
        _ info: FIRVisitInfo
    ) -> FIRVisitResult {
        let value = statement.expression.acceptVisitor(self, .asAnExpression)
        let returnStatement = FIRReturn(value: value.unwrapExpression())
        
        return .terminator(returnStatement)
    }
    
    func visitAssignmentStatement(
        _ statement: AssignmentStatement,
        _ info: FIRVisitInfo
    ) -> FIRVisitResult {
        let value = statement.expression.acceptVisitor(self, .asAnExpression)
        let definition = FIRAssignment(name: statement.name, value: value.unwrapExpression())
        
        return .statement(definition)
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
        
        let condition = statement.condition.acceptVisitor(self, .asAnExpression)
            .unwrapExpression()
        
        let thenName = "\(ifName)$then"
        let thenLabel = FIRLabel(name: thenName)
        let processedThen = processBlock(
            statement.thenBranch,
            .blockLevelItem.withParentBlock(name: thenName)
        )
        
        var processedElse: [FIRVisitResult]? = nil
        let elseName = "\(ifName)$else"
        let elseLabel = FIRLabel(name: elseName)
        if let elseBranch = statement.elseBranch {
            processedElse = processBlock(
                elseBranch,
                .blockLevelItem.withParentBlock(name: elseName)
            )
        }
        
        let joinLabel = FIRLabel(name: "\(ifName)$end")
        
        let branch = FIRConditionalBranch(
            condition: condition,
            thenBranch: thenLabel,
            elseBranch: processedElse == nil ? joinLabel : elseLabel
        )
        
        let branchToJoin = FIRBranch(label: joinLabel)
        
        let finalThen = [.label(thenLabel)] + processedThen + [.terminator(branchToJoin)]
        var finalElse: [FIRVisitResult]? = nil
        if let processedElse {
            finalElse = [.label(elseLabel)] + processedElse + [.terminator(branchToJoin)]
        }
        
        return .ifStatement(
            terminator: branch,
            thenBlock: finalThen,
            elseBlock: finalElse,
            joinLabel: joinLabel
        )
    }
    
    private func processBlock(
        _ block: [any BlockLevelNode],
        _ info: FIRVisitInfo
    ) -> [FIRVisitResult] {
        var nodes: [FIRVisitResult] = []
        for node in block {
            nodes.append(node.acceptVisitor(self, info))
        }
        
        return nodes
    }
    
    enum Expectation {
        case nextIsLabel
    }
    
    private func parseIntoBasicBlocks(
        _ result: [FIRVisitResult],
        _ anyExpectation: Expectation? = nil,
        _ initialLabel: FIRLabelRepresentable = FIRLabelHole()
    ) -> [FIRBasicBlock] {
        
        var expectation: Expectation? = anyExpectation
        var blocks: [FIRBasicBlock] = []
        var currentBlockItems: [FIRBasicBlockItem] = []
        var currentLabel: FIRLabelRepresentable = initialLabel
        var shouldDropTerminator = false
        
        let finishCurrentBlock: (FIRTerminator, Expectation?) -> Void = { [self] terminator, newExpectation in
            let block = onParseTerminator(terminator, label: currentLabel, items: currentBlockItems)
            blocks.append(block)
            
            currentBlockItems = []
            currentLabel = FIRLabelHole()
            expectation = newExpectation
            shouldDropTerminator = true
        }
        
        let markLabel: (FIRLabelRepresentable) -> Void = { label in
            guard case .nextIsLabel = expectation else {
                fatalError("Expectation must be that the next thing is a label in order to parse a label")
            }
            currentLabel = label
            expectation = nil
        }
        
        let handleIf: (
            _ terminator: FIRTerminator,
            _ thenBlock: [FIRVisitResult],
            _ elseBlock: [FIRVisitResult]?,
            _ joinLabel: FIRLabelRepresentable
        ) -> Void = { [self] terminator, thenBlock, elseBlock, joinLabel in
            finishCurrentBlock(terminator, nil)
            let thenBasicBlock = parseIntoBasicBlocks(thenBlock, .nextIsLabel)
            blocks.append(contentsOf: thenBasicBlock)
            if let elseBlockRaw = elseBlock {
                let elseBasicBlock = parseIntoBasicBlocks(elseBlockRaw, .nextIsLabel)
                blocks.append(contentsOf: elseBasicBlock)
            }
            expectation = .nextIsLabel
            markLabel(joinLabel)
        }
        
        result.forEach { node in
            switch node {
            case .statement(let statement):
                shouldDropTerminator = false
                currentBlockItems.append(statement)
                
            case .terminator(let terminator):
                if shouldDropTerminator { return }
                finishCurrentBlock(terminator, .nextIsLabel)
                
            case .label(let label):
                shouldDropTerminator = false
                markLabel(label)
                
            case .ifStatement(let terminator, let thenBlock, let elseBlock, let joinLabel):
                shouldDropTerminator = false
                handleIf(terminator, thenBlock, elseBlock, joinLabel)
                
            case .expression:
                fatalError("Expressions cannot be in basic blocks")
            case .function:
                fatalError("Functions cannot be nested")
            }
        }
        
        return blocks
    }
    
    private func onParseTerminator(
        _ terminator: FIRTerminator,
        label: FIRLabelRepresentable,
        items: [FIRBasicBlockItem]
    ) -> FIRBasicBlock {
        guard let label = label as? FIRLabel else {
            fatalError("Cannot finish a block with a label hole")
        }
        
        return .init(label: label, statements: items, terminator: terminator)
    }
}
