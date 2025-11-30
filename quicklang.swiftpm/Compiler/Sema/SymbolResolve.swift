//
//  SymbolResolve.swift
//  quicklang
//
//  Created by Rob Patterson on 11/15/25.
//

class AllowsRecursiveDefinition: ASTUpwardTransformer {
    
    enum Verdict {
        case no
        case yes
        case notApplicable
    }
    
    typealias TransformerInfo = Verdict
    
    static var shared: AllowsRecursiveDefinition {
        AllowsRecursiveDefinition()
    }
    
    private init() {}
    
    func visitIdentifierExpression(
        _ expression: IdentifierExpression,
        _ finished: @escaping OnTransformEnd<IdentifierExpression>
    ) {
        finished(expression, .notApplicable)
    }
    
    func visitBooleanExpression(
        _ expression: BooleanExpression,
        _ finished: @escaping OnTransformEnd<BooleanExpression>
    ) {
        finished(expression, .notApplicable)
    }
    
    func visitNumberExpression(
        _ expression: NumberExpression,
        _ finished: @escaping OnTransformEnd<NumberExpression>
    ) {
        finished(expression, .notApplicable)
    }
    
    func visitUnaryOperation(
        _ operation: UnaryOperation,
        _ finished: @escaping OnTransformEnd<UnaryOperation>
    ) {
        finished(operation, .notApplicable)
    }
    
    func visitBinaryOperation(
        _ operation: BinaryOperation,
        _ finished: @escaping OnTransformEnd<BinaryOperation>
    ) {
        finished(operation, .notApplicable)
    }
    
    func visitLetDefinition(
        _ definition: LetDefinition,
        _ finished: @escaping OnTransformEnd<LetDefinition>
    ) {
        finished(definition, .no)
    }
    
    func visitVarDefinition(
        _ definition: VarDefinition,
        _ finished: @escaping OnTransformEnd<VarDefinition>
    ) {
        finished(definition, .no)
    }
    
    func visitFuncDefinition(
        _ definition: FuncDefinition,
        _ finished: @escaping OnTransformEnd<FuncDefinition>
    ) {
        finished(definition, .yes)
    }
    
    func visitFuncApplication(
        _ expression: FuncApplication,
        _ finished: @escaping OnTransformEnd<FuncApplication>
    ) {
        finished(expression, .notApplicable)
    }
    
    func visitIfStatement(
        _ statement: IfStatement,
        _ finished: @escaping OnTransformEnd<IfStatement>
    ) {
        finished(statement, .notApplicable)
    }
    
    func visitReturnStatement(
        _ statement: ReturnStatement,
        _ finished: @escaping OnTransformEnd<ReturnStatement>
    ) {
        finished(statement, .notApplicable)
    }
    
    func visitAssignmentStatement(_ statement: AssignmentStatement, _ finished: @escaping OnTransformEnd<AssignmentStatement>) {
        finished(statement, .yes)
    }
}

class SymbolGrabber: ASTUpwardTransformer {
    
    
    typealias Binding = String
    
    typealias TransformerInfo = [Binding]
    
    static var shared: SymbolGrabber {
        SymbolGrabber()
    }
    
    private init() {}
    
    func visitIdentifierExpression(
        _ expression: IdentifierExpression,
        _ finished: @escaping OnTransformEnd<IdentifierExpression>
    ) {
        finished(expression, [])
    }
    
    func visitBooleanExpression(
        _ expression: BooleanExpression,
        _ finished: @escaping OnTransformEnd<BooleanExpression>
    ) {
        finished(expression, [])
    }
    
    func visitNumberExpression(
        _ expression: NumberExpression,
        _ finished: @escaping OnTransformEnd<NumberExpression>
    ) {
        finished(expression, [])
    }
    
    func visitUnaryOperation(
        _ operation: UnaryOperation,
        _ finished: @escaping OnTransformEnd<UnaryOperation>
    ) {
        finished(operation, [])
    }
    
    func visitBinaryOperation(
        _ operation: BinaryOperation,
        _ finished: @escaping OnTransformEnd<BinaryOperation>
    ) {
        finished(operation, [])
    }
    
    func visitLetDefinition(
        _ definition: LetDefinition,
        _ finished: @escaping OnTransformEnd<LetDefinition>
    ) {
        finished(definition, [definition.name])
    }
    
    func visitVarDefinition(
        _ definition: VarDefinition,
        _ finished: @escaping OnTransformEnd<VarDefinition>
    ) {
        finished(definition, [definition.name])
    }
    
    func visitFuncDefinition(
        _ definition: FuncDefinition,
        _ finished: @escaping OnTransformEnd<FuncDefinition>
    ) {
        finished(definition, [definition.name])
    }
    
    func visitFuncApplication(
        _ expression: FuncApplication,
        _ finished: @escaping OnTransformEnd<FuncApplication>
    ) {
        finished(expression, [])
    }
    
    func visitIfStatement(
        _ statement: IfStatement,
        _ finished: @escaping OnTransformEnd<IfStatement>
    ) {
        finished(statement, [])
    }
    
    func visitReturnStatement(
        _ statement: ReturnStatement,
        _ finished: @escaping OnTransformEnd<ReturnStatement>
    ) {
        finished(statement, [])
    }
    
    func visitAssignmentStatement(
        _ statement: AssignmentStatement,
        _ finished: @escaping OnTransformEnd<AssignmentStatement>
    ) {
        finished(statement, [])
    }
    
}

class SymbolResolve: SemaPass, ASTDownwardTransformer {
    
    typealias BindingInScope = String
    let context: ASTContext
    var errorManager: CompilerErrorManager?
    
    init(context: ASTContext) {
        self.context = context
    }
    
    func begin(reportingTo: CompilerErrorManager) {
        errorManager = reportingTo
        
        let tree = context.tree
        
        tree.sections.forEach { node in
            var canBeRecursive: AllowsRecursiveDefinition.Verdict? = nil
            node.acceptUpwardTransformer(AllowsRecursiveDefinition.shared) { _, verdict in
                canBeRecursive = verdict
            }
            
            var exclude: String? = nil
            switch canBeRecursive {
            case .no:
                node.acceptUpwardTransformer(SymbolGrabber.shared) { _, binding in
                    exclude = binding.first
                }
            case .yes, .notApplicable:
                break
            case nil:
                fatalError("Not possible")
            }
            
            let globals = context.getGlobalSymbols(excluding: exclude)
            node.acceptDownwardTransformer(self, globals)
        }
    }
    
    private func addError(_ error: SymbolResolveErrorType, at location: SourceCodeLocation) {
        let errorInfo = error.buildInfo(at: location)
        let error = errorInfo.getError(from: DefaultSymbolResolveErrorCreator.shared)
        errorManager?.addError(error)
    }
    
    func visitIdentifierExpression(
        _ expression: IdentifierExpression,
        _ info: [BindingInScope]
    ) {
        if !info.contains(where: { $0 == expression.name }) {
            addError(.identifierUnbound(name: expression.name), at: .beginningOfFile)
        }
    }
    
    func visitBooleanExpression(
        _ expression: BooleanExpression,
        _ info: [BindingInScope]
    ) {
        // no-op
    }
    
    func visitNumberExpression(
        _ expression: NumberExpression,
        _ info: [BindingInScope]
    ) {
        // no-op
    }
    
    func visitUnaryOperation(
        _ operation: UnaryOperation,
        _ info: [BindingInScope]
    ) {
        operation.expression.acceptDownwardTransformer(self, info)
    }
    
    func visitBinaryOperation(
        _ operation: BinaryOperation,
        _ info: [BindingInScope]
    ) {
        operation.lhs.acceptDownwardTransformer(self, info)
        operation.rhs.acceptDownwardTransformer(self, info)
    }
    
    func visitLetDefinition(
        _ definition: LetDefinition,
        _ info: [BindingInScope]
    ) {
        enforceNoShadowing(for: definition.name, scope: info)
        definition.expression.acceptDownwardTransformer(self, info)
    }
    
    func visitVarDefinition(
        _ definition: VarDefinition,
        _ info: [BindingInScope]
    ) {
        enforceNoShadowing(for: definition.name, scope: info)
        definition.expression.acceptDownwardTransformer(self, info)
    }
    
    func visitFuncDefinition(
        _ definition: FuncDefinition,
        _ info: [BindingInScope]
    ) {
        enforceNoShadowing(for: definition.name, scope: info)
        definition.parameters.forEach { param in
            enforceNoShadowing(for: param.name, scope: info)
        }
        
        enforceUniqueParameterNames(definition.parameters)
        
        var newInfo = info
        newInfo.append(definition.name)
        let parameters = definition.parameters.map { $0.name }
        newInfo.append(contentsOf: parameters)
        processBlock(definition.body, newInfo)
    }
    
    private func enforceUniqueParameterNames(_ params: [FuncDefinition.Parameter]) {
        let paramNames = params.map { $0.name }
        let paramSet = Set(arrayLiteral: paramNames)
        
        guard paramSet.count == paramNames.count else {
            addError(.parameterNamesNotUnique(repeated: "you gotta do this one"), at: .beginningOfFile)
            return
        }
    }
    
    private func enforceNoShadowing(for binding: String, scope: [BindingInScope]) {
        guard !scope.contains(binding) else {
            addError(.shadowing(name: binding), at: .beginningOfFile)
            return
        }
    }
    
    func visitFuncApplication(
        _ expression: FuncApplication,
        _ info: [BindingInScope]
    ) {
        if !info.contains(expression.name) {
            addError(.functionNotFound(name: expression.name), at: .beginningOfFile)
        }
        
        expression.arguments.forEach { $0.acceptDownwardTransformer(self, info) }
    }
    
    func visitIfStatement(
        _ statement: IfStatement,
        _ info: [BindingInScope]
    ) {
        statement.condition.acceptDownwardTransformer(self, info)
        processBlock(statement.thenBranch, info)
        if let elseBranch = statement.elseBranch {
            processBlock(elseBranch, info)
        }
    }
    
    func visitReturnStatement(
        _ statement: ReturnStatement,
        _ info: [BindingInScope]
    ) {
        statement.expression.acceptDownwardTransformer(self, info)
    }
    
    func visitAssignmentStatement(
        _ statement: AssignmentStatement,
        _ info: [BindingInScope]
    ) {
        if !info.contains(statement.name) {
            addError(.identifierUnbound(name: statement.name), at: .beginningOfFile)
        }
        
        statement.expression.acceptDownwardTransformer(self, info)
    }
    
    private func processBlock(
        _ block: [any BlockLevelNode],
        _ info: TransformationInfo
    ) {
        var mutInfo = info
        block.forEach { node in
            node.acceptDownwardTransformer(self, mutInfo)
            node.acceptUpwardTransformer(SymbolGrabber.shared) { _, bindings in
                mutInfo.append(contentsOf: bindings)
            }
        }
    }
    
}

enum SymbolResolveErrorType: CompilerPhaseErrorType {
    
    case functionNotFound(name: String)
    case shadowing(name: String)
    case parameterNamesNotUnique(repeated: String)
    case identifierUnbound(name: String)
    
    func buildInfo(at location: SourceCodeLocation) -> any SymbolResolvePhaseErrorInfo {
        switch self {
        case .functionNotFound(let name):
            return FunctionNotFoundErrorInfo(location: location, name: name)
        case .shadowing(let name):
            return ShadowingErrorInfo(location: location, name: name)
        case .parameterNamesNotUnique(let repeated):
            return ParameterNamesNotUniqueErrorInfo(location: location, repeated: repeated)
        case .identifierUnbound(let name):
            return IdentifierUnboundErrorInfo(location: location, name: name)
        }
    }
    
}

protocol SymbolResolveErrorCreator {
    func functionNotFound(info: FunctionNotFoundErrorInfo) -> SymbolResolveError
    func shadowing(info: ShadowingErrorInfo) -> SymbolResolveError
    func parameterNamesNotUnique(info: ParameterNamesNotUniqueErrorInfo) -> SymbolResolveError
    func identifierUnbound(info: IdentifierUnboundErrorInfo) -> SymbolResolveError
}

protocol SymbolResolvePhaseErrorInfo: CompilerPhaseErrorInfo {
    var location: SourceCodeLocation { get }
    
    func getError(from manager: any SymbolResolveErrorCreator) -> SymbolResolveError
}

struct SymbolResolveError: CompilerPhaseError {
    let location: SourceCodeLocation
    let message: String
}

struct FunctionNotFoundErrorInfo: SymbolResolvePhaseErrorInfo {
    
    let location: SourceCodeLocation
    let name: String
    
    func getError(from manager: any SymbolResolveErrorCreator) -> SymbolResolveError {
        manager.functionNotFound(info: self)
    }
}

struct ShadowingErrorInfo: SymbolResolvePhaseErrorInfo {
    let location: SourceCodeLocation
    let name: String
    
    func getError(from manager: any SymbolResolveErrorCreator) -> SymbolResolveError {
        manager.shadowing(info: self)
    }
}

struct ParameterNamesNotUniqueErrorInfo: SymbolResolvePhaseErrorInfo {
    let location: SourceCodeLocation
    let repeated: String
    
    func getError(from manager: any SymbolResolveErrorCreator) -> SymbolResolveError {
        manager.parameterNamesNotUnique(info: self)
    }
}

struct IdentifierUnboundErrorInfo: SymbolResolvePhaseErrorInfo {
    let location: SourceCodeLocation
    let name: String
    
    func getError(from manager: any SymbolResolveErrorCreator) -> SymbolResolveError {
        manager.identifierUnbound(info: self)
    }
}

class DefaultSymbolResolveErrorCreator: SymbolResolveErrorCreator {
    static var shared: DefaultSymbolResolveErrorCreator {
        DefaultSymbolResolveErrorCreator()
    }
    
    private init() {}
    
    func functionNotFound(info: FunctionNotFoundErrorInfo) -> SymbolResolveError {
        SymbolResolveError(location: info.location, message: "Function \(info.name) is not defined")
    }
    
    func shadowing(info: ShadowingErrorInfo) -> SymbolResolveError {
        SymbolResolveError(location: info.location, message: "Name \(info.name) is already defined")
    }
    
    func parameterNamesNotUnique(info: ParameterNamesNotUniqueErrorInfo) -> SymbolResolveError {
        SymbolResolveError(location: info.location, message: "Parameter name \(info.repeated) is not unique")
    }
    
    func identifierUnbound(info: IdentifierUnboundErrorInfo) -> SymbolResolveError {
        SymbolResolveError(location: info.location, message: "Variable \(info.name) is not defined")
    }
}

