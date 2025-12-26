//
//  GenerateFIR.swift
//  quicklang
//
//  Created by Rob Patterson on 12/25/25.
//

struct GenerateFIRVisitorInfo {
    let shouldLetBind: Bool
    let returnBranchName: String?
    
    enum NodeReturnType {
        case expression
        case statement
    }
    let nodeType: NodeReturnType
    
    func okayToLetBind() -> GenerateFIRVisitorInfo {
        .init(shouldLetBind: true, returnBranchName: returnBranchName, nodeType: nodeType)
    }
    
    func notOkayToLetBind() -> GenerateFIRVisitorInfo {
        .init(shouldLetBind: false, returnBranchName: returnBranchName, nodeType: nodeType)
    }
    
    func asStatement() -> GenerateFIRVisitorInfo {
        .init(shouldLetBind: shouldLetBind, returnBranchName: returnBranchName, nodeType: .statement)
    }
    
    func asExpression() -> GenerateFIRVisitorInfo {
        .init(shouldLetBind: shouldLetBind, returnBranchName: returnBranchName, nodeType: .expression)
    }
    
    static func none() -> GenerateFIRVisitorInfo {
        .init(shouldLetBind: false, returnBranchName: nil, nodeType: .statement)
    }
}

enum GenerateFIRVisitorResult {
    typealias ExpressionVisit = (expression: any FIRExpression, bindings: [FIRAssignment])
    case expressionVisit(ExpressionVisit)
    case notSafeToLetBind(ExpressionVisit)
    
    case terminator(any FIRTerminator, [FIRAssignment])
    case statement(any FIRBasicBlockItem, [FIRAssignment])
    
    case ifStatement(prelude: [FIRAssignment], condition: FIRTerminator, blocks: [FIRBasicBlock])
    
    case label(FIRLabel)
    
    case function(FIRFunction)
    
    func unwrapExpressionVisit() -> ExpressionVisit {
        switch self {
        case .expressionVisit(let expressionVisit),
                .notSafeToLetBind(let expressionVisit):
            return expressionVisit
        default:
            InternalCompilerError.unreachable("Only callable on expression visit results")
        }
    }
    
    func unwrapStatementVisit() -> (any FIRBasicBlockItem, [FIRAssignment]) {
        switch self {
        case .statement(let statement, let bindings):
            return (statement, bindings)
        default:
            InternalCompilerError.unreachable("Only callable on expression visit results")
        }
    }
}

final class GenerateFIR: CompilerPhase, ASTVisitor {
    
    typealias InputType = ASTContext
    typealias SuccessfulResult = FIRModule
    
    var context: ASTContext?
    var errorManager: CompilerErrorManager?
    
//    let shortCircuitingForIfStatementCondition = ShortCircuitingForIfStatementCondition()
    
    init(errorManager: CompilerErrorManager, settings: DriverSettings) {
        self.errorManager = errorManager
    }
    
    func begin(_ input: ASTContext) -> PhaseResult<GenerateFIR> {
        var nodes: [FIRFunction] = []
        context = input
        
        input.tree.sections.forEach { node in
            let result = node.acceptVisitor(self, .none())
            switch result {
            case .function(let function):
                nodes.append(function)
                
            default:
                fatalError("Not supported at the top level")
            }
        }
        
        let module = FIRModule(nodes: nodes)
//        shortCircuitingForIfStatementCondition.begin(module)
        return .success(result: module)
    }
    
    typealias VisitorInfo = GenerateFIRVisitorInfo
    typealias VisitorResult = GenerateFIRVisitorResult
    
    func visitIdentifierExpression(
        _ expression: IdentifierExpression,
        _ info: GenerateFIRVisitorInfo
    ) -> GenerateFIRVisitorResult {
        
        let newExpression = FIRIdentifier(name: expression.name)
        
        let result = (expression: newExpression, bindings: [] as [FIRAssignment])
        return .expressionVisit(result)
    }
    
    func visitBooleanExpression(
        _ expression: BooleanExpression,
        _ info: GenerateFIRVisitorInfo
    ) -> GenerateFIRVisitorResult {
        
        let newExpression = FIRBoolean(value: expression.value)
        
        let result = (expression: newExpression, bindings: [] as [FIRAssignment])
        return .expressionVisit(result)
    }
    
    func visitNumberExpression(
        _ expression: NumberExpression,
        _ info: GenerateFIRVisitorInfo
    ) -> GenerateFIRVisitorResult {
        
        let newExpression = FIRInteger(value: expression.value)
        
        let result = (expression: newExpression, bindings: [] as [FIRAssignment])
        return .expressionVisit(result)
    }
    
    func visitUnaryOperation(
        _ operation: UnaryOperation,
        _ info: GenerateFIRVisitorInfo
    ) -> GenerateFIRVisitorResult {
        
        let subexpressionVisitResult = operation
            .expression
            .acceptVisitor(self, info)
        
        switch subexpressionVisitResult {
        case .expressionVisit((let expression, let bindings)):
            return createNewBindingForUnaryOperation(expression, bindings)
            
        case .notSafeToLetBind((let expression, let bindings)):
            return notSafeToLetBind(expression, bindings)
            
        default:
            InternalCompilerError.unreachable("Not possible")
        }
        
        func createNewBindingForUnaryOperation(
            _ identifier: any FIRExpression,
            _ newBindings: [FIRAssignment]
        ) -> GenerateFIRVisitorResult {
            
            let newOperator = FIROperation.from(op: operation.op)
            let newExpression = FIRUnaryExpression(op: newOperator, expr: identifier)
            let newBindingName = GenSymInfo.singleton.genSym(root: "let_un_op$", id: operation.id)
            let newAssignment = FIRAssignment(name: newBindingName, value: newExpression)
            let newUnaryIdentifier = FIRIdentifier(name: newBindingName)
            
            var newBindings = newBindings
            newBindings.append(newAssignment)
            
            let result = (expression: newUnaryIdentifier, bindings: newBindings)
            return .expressionVisit(result)
        }
        
        func notSafeToLetBind(
            _ expression: any FIRExpression,
            _ newBindings: [FIRAssignment]
        ) -> GenerateFIRVisitorResult {
            
            let newOperator = FIROperation.from(op: operation.op)
            let newUnaryExpression = FIRUnaryExpression(op: newOperator, expr: expression)
            
            let result = (expression: newUnaryExpression, bindings: [] as [FIRAssignment])
            return .notSafeToLetBind(result)
        }
    }
    
    func visitBinaryOperation(
        _ operation: BinaryOperation,
        _ info: GenerateFIRVisitorInfo
    ) -> GenerateFIRVisitorResult {
        
        let binaryOperator = FIROperation.from(op: operation.op)
        
        // if this operation is not a boolean (i.e. arithmetic),
        // we can try let binding the result of the expression.
        // if any of its subexpressions can't be let bound, then
        // we will leave this as is
        if !operation.op.isBoolean {
            
            // we will update this after the subexpressions;
            // if any of the subexpressions cannot be let bound,
            // we will not let bind the binary expression
            var canLetBindBinaryExpression: Bool = true
            var bindings = [] as [FIRAssignment]
            
            let lhsResult = operation.lhs.acceptVisitor(self, info)
            let lhsExpression: FIRExpression
            switch lhsResult {
            case .expressionVisit((let expression, let newBindings)):
                lhsExpression = expression
                bindings.append(contentsOf: newBindings)
                
            case .notSafeToLetBind((let expression, let newBindings)):
                canLetBindBinaryExpression = false
                lhsExpression = expression
                bindings.append(contentsOf: newBindings)
                
            default:
                InternalCompilerError.unreachable("Not possible")
            }
            
            let rhsResult = operation.rhs.acceptVisitor(self, info)
            let rhsExpression: FIRExpression
            switch rhsResult {
            case .expressionVisit((let expression, let newBindings)):
                rhsExpression = expression
                bindings.append(contentsOf: newBindings)
                
            case .notSafeToLetBind((let expression, let newBindings)):
                canLetBindBinaryExpression = false
                rhsExpression = expression
                bindings.append(contentsOf: newBindings)
                
            default:
                InternalCompilerError.unreachable("Not possible")
            }
            
            let binaryOperation = FIRBinaryExpression(
                op: binaryOperator,
                lhs: lhsExpression,
                rhs: rhsExpression
            )
            
            if canLetBindBinaryExpression {
                let result = (expression: binaryOperation, bindings: bindings)
                return .expressionVisit(result)
                
            } else {
                let result = (expression: binaryOperation, bindings: bindings)
                return .notSafeToLetBind(result)
            }
        }
        
        // if this operation is a boolean and it can be let bound,
        // we will allow the lhs to expand but not the rhs
        if info.shouldLetBind && operation.op.isBoolean {
            return handleBooleanBinaryExpression(shouldLetBindLHS: true)
        }
        
        // if we shouldn't let bind and the operation is a boolean,
        // leave this binary expression as is
        if !info.shouldLetBind && operation.op.isBoolean {
            return handleBooleanBinaryExpression(shouldLetBindLHS: false)
        }
        
        func handleBooleanBinaryExpression(shouldLetBindLHS: Bool) -> GenerateFIRVisitorResult {
            let lhsInfo = shouldLetBindLHS ? info.okayToLetBind() : info.notOkayToLetBind()
            let (lhsExpression, lhsBindings) = operation.lhs.acceptVisitor(
                self,
                lhsInfo
            ).unwrapExpressionVisit()
            
            let (rhsExpression, rhsBindings) = operation.lhs.acceptVisitor(
                self,
                info.notOkayToLetBind()
            ).unwrapExpressionVisit()
            
            let newBindings = lhsBindings + rhsBindings
            let binaryOperation = FIRBinaryExpression(
                op: binaryOperator,
                lhs: lhsExpression,
                rhs: rhsExpression
            )
            
            let result = (expression: binaryOperation, bindings: newBindings)
            return .notSafeToLetBind(result)
        }
        
        InternalCompilerError.unreachable("Not possible")
    }
    
    func visitDefinition(
        _ definition: DefinitionNode,
        _ info: GenerateFIRVisitorInfo
    ) -> GenerateFIRVisitorResult {
        
        let value = definition.expression.acceptVisitor(self, info.okayToLetBind())
        switch value {
        case .expressionVisit((let expression, let bindings)),
                .notSafeToLetBind((let expression, let bindings)):
            let assignment = FIRAssignment(name: definition.name, value: expression)
            return .statement(assignment, bindings)
            
        default:
            InternalCompilerError.unreachable("Not possible")
        }
    }
    
    func visitFuncDefinition(
        _ definition: FuncDefinition,
        _ info: GenerateFIRVisitorInfo
    ) -> GenerateFIRVisitorResult {
        
        let returnName = GenSymInfo.singleton.genSym(root: "return", id: nil)
        let info = GenerateFIRVisitorInfo(shouldLetBind: true, returnBranchName: returnName, nodeType: .statement)
        
        let bodyEntryName = GenSymInfo.singleton.genSym(root: "\(definition.name)_entry", id: nil)
        var body = processBlock(definition.body, info: info, startWithLabel: bodyEntryName)
        
        let returnLabel = FIRLabel(name: returnName)
        let returnParameterName = GenSymInfo.singleton.genSym(root: "return_val", id: nil)
        let returnParameter = FIRParameter(name: returnParameterName, type: .convertFrom(definition.type.returnType!))
        let returnParameterIdentifier = FIRIdentifier(name: returnParameterName)
        let returnAction = FIRReturn(value: returnParameterIdentifier)
        let returnBlock = FIRBasicBlock(
            label: returnLabel.copy(),
            statements: [],
            terminator: returnAction,
            parameter: returnParameter
        )
        
        body.append(returnBlock)
        let parameters = definition.parameters.map { parameter in
            FIRParameter(name: parameter.name, type: .convertFrom(parameter.type))
        }
        
        let function = FIRFunction(
            blocks: body,
            parameters: parameters
        )
        
        return .function(function)
    }
    
    func visitFuncApplication(
        _ expression: FuncApplication,
        _ info: GenerateFIRVisitorInfo
    ) -> GenerateFIRVisitorResult {
        
        guard info.shouldLetBind else {
            let argumentVisitResults = expression.arguments
                .map {
                    $0.acceptVisitor(self, info)
                }
                .map {
                    $0.unwrapExpressionVisit().expression
                }
            
            let funcApplication = FIRFunctionCall(function: expression.name, parameter: argumentVisitResults)
            
            if info.nodeType == .expression {
                let result = (expression: funcApplication, bindings: [] as [FIRAssignment])
                return .notSafeToLetBind(result)
                
            } else {
                let assignment = FIRAssignment(name: "_", value: funcApplication)
                return .statement(assignment, [])
            }
        }
        
        var canLetBindFuncApplication: Bool = true
        var bindings = [] as [FIRAssignment]
        let visitedParameters = expression.arguments.enumerated().map { (idx, argument) in
            
            let visitedArgument = argument.acceptVisitor(self, info)
            switch visitedArgument {
            case .expressionVisit((let expression, let newBindings)):
                bindings.append(contentsOf: newBindings)
                return expression
                
            case .notSafeToLetBind((let expression, _)):
                canLetBindFuncApplication = false
                return expression
                
            default:
                InternalCompilerError.unreachable("Not possible")
            }
        }
        
        if canLetBindFuncApplication {
            let newFuncApplication = FIRFunctionCall(function: expression.name, parameter: visitedParameters)
            let newBindingName = GenSymInfo.singleton.genSym(root: "let_fun_call$", id: expression.id)
            let newAssignment = FIRAssignment(name: newBindingName, value: newFuncApplication)
            let newIdentifier = FIRIdentifier(name: newBindingName)
            bindings.append(newAssignment)
            
            if info.nodeType == .expression {
                let result = (expression: newIdentifier, bindings: bindings)
                return .expressionVisit(result)
                
            } else {
                let assignment = FIRAssignment(name: "_", value: newIdentifier)
                return .statement(assignment, bindings)
            }
            
        } else {
            let newFuncApplication = FIRFunctionCall(function: expression.name, parameter: visitedParameters)
            
            if info.nodeType == .expression {
                let result = (expression: newFuncApplication, bindings: bindings)
                return .notSafeToLetBind(result)
                
            } else {
                let assignment = FIRAssignment(name: "_", value: newFuncApplication)
                return .statement(assignment, bindings)
            }
        }
    }
    
    func visitIfStatement(
        _ statement: IfStatement,
        _ info: GenerateFIRVisitorInfo
    ) -> GenerateFIRVisitorResult {
        
        let (condExpr, condBindings) = statement.condition.acceptVisitor(self, info.notOkayToLetBind()).unwrapExpressionVisit()
        let thenLabel = GenSymInfo.singleton.genSym(root: "thn_blck", id: nil)
        let elseLabel = GenSymInfo.singleton.genSym(root: "els_blck", id: nil)
        
        var blocks = [] as [FIRBasicBlock]
        let thenBlock = processBlock(statement.thenBranch, info: info.asStatement(), startWithLabel: thenLabel)
        blocks.append(contentsOf: thenBlock)
        if let rawElseBlock = statement.elseBranch {
            let elseBlock = processBlock(rawElseBlock, info: info.asStatement(), startWithLabel: elseLabel)
            blocks.append(contentsOf: elseBlock)
        }
        
        let condBranch = FIRConditionalBranch(
            condition: condExpr,
            thenBranch: thenLabel,
            elseBranch: elseLabel
        )
        
        return .ifStatement(prelude: condBindings, condition: condBranch, blocks: blocks)
    }
    
    func visitReturnStatement(
        _ statement: ReturnStatement,
        _ info: GenerateFIRVisitorInfo
    ) -> GenerateFIRVisitorResult {
        
        let value = statement.expression.acceptVisitor(self, info.okayToLetBind())
        switch value {
        case .expressionVisit((let expression, let bindings)):
            let branch = FIRBranch(label: info.returnBranchName!, value: expression)
            return .terminator(branch, bindings)
            
        case .notSafeToLetBind((let expression, let bindings)):
            let returnTerminator = FIRReturn(value: expression)
            return .terminator(returnTerminator, bindings)
            
        default:
            InternalCompilerError.unreachable("Not possible")
        }
    }
    
    func visitAssignmentStatement(
        _ statement: AssignmentStatement,
        _ info: GenerateFIRVisitorInfo
    ) -> GenerateFIRVisitorResult {
        
        let value = statement.expression.acceptVisitor(self, info.okayToLetBind())
        switch value {
        case .expressionVisit((let expression, let bindings)),
                .notSafeToLetBind((let expression, let bindings)):
            let assignment = FIRAssignment(name: statement.name, value: expression)
            return .statement(assignment, bindings)
            
        default:
            InternalCompilerError.unreachable("Not possible")
        }
    }
    
    func visitControlFlowJumpStatement(
        _ statement: ControlFlowJumpStatement,
        _ info: GenerateFIRVisitorInfo
    ) -> GenerateFIRVisitorResult {
        
        let result = FIRBranch(label: statement.label)
        return .terminator(result, [])
    }
    
    func visitLabelControlFlowStatement(
        _ statement: LabelControlFlowStatement,
        _ info: GenerateFIRVisitorInfo
    ) -> GenerateFIRVisitorResult {
        
        let label = FIRLabel(name: statement.label)
        return .label(label)
    }
    
    private func processBlock(
        _ block: [any BlockLevelNode],
        info: GenerateFIRVisitorInfo,
        startWithLabel: String? = nil
    ) -> [FIRBasicBlock] {
        
        var blocks: [FIRBasicBlock] = []
        var builder = FIRBasicBlock.Builder()
        
        if let startWithLabel {
            let label = FIRLabel(name: startWithLabel)
            builder.addLabel(label.copy())
        }
        
        for node in block {
            
            let info = info.asStatement()
            let result = node.acceptVisitor(self, info)
            switch result {
            case .statement(let statement, let prelude):
                builder.addStatements(prelude)
                builder.addStatement(statement)
                
            case .terminator(let terminator, let prelude):
                builder.addStatements(prelude)
                builder.addTerminator(terminator)
                
            case .label(let label):
                builder.addLabel(label)
                
            case .ifStatement(prelude: let prelude, condition: let condition, blocks: let newBlocks):
                builder.addStatements(prelude)
                builder.addTerminator(condition)
                let block = builder.build()
                blocks.append(block)
                blocks.append(contentsOf: newBlocks)
                builder = .init()
                
            case .expressionVisit, .notSafeToLetBind:
                InternalCompilerError.unreachable("Unexpected expression visit in block")
            case .function:
                InternalCompilerError.unreachable("Functions cannot be nested in functions")
            }
        }
        
        if builder.isNew() {
            return blocks
        } else if let terminators = builder.onlyTerminators() {
            let lastBlock = blocks.last!
            for terminator in terminators {
                lastBlock.addUnreachableTerminator(terminator)
            }
            return blocks
        } else {
            let block = builder.build()
            blocks.append(block)
            return blocks
        }
    }
}
