//
//  SymbolResolve.swift
//  quicklang
//
//  Created by Rob Patterson on 11/15/25.
//

class AllowsRecursiveDefinition: ASTVisitor {
    
    enum Verdict {
        case no
        case yes
        case notApplicable
    }
    
    typealias VisitorResult = Verdict
    
    static var shared: AllowsRecursiveDefinition {
        AllowsRecursiveDefinition()
    }
    
    private init() {}
    
    func visitIdentifierExpression(
        _ expression: IdentifierExpression,
        _ info: Void
    ) -> Verdict {
        .notApplicable
    }
    
    func visitBooleanExpression(
        _ expression: BooleanExpression,
        _ info: Void
    ) -> Verdict {
        .notApplicable
    }
    
    func visitNumberExpression(
        _ expression: NumberExpression,
        _ info: Void
    ) -> Verdict {
        .notApplicable
    }
    
    func visitUnaryOperation(
        _ operation: UnaryOperation,
        _ info: Void
    ) -> Verdict {
        .notApplicable
    }
    
    func visitBinaryOperation(
        _ operation: BinaryOperation,
        _ info: Void
    ) -> Verdict {
        .notApplicable
    }
    
    func visitLetDefinition(
        _ definition: LetDefinition,
        _ info: Void
    ) -> Verdict {
        .no
    }
    
    func visitVarDefinition(
        _ definition: VarDefinition,
        _ info: Void
    ) -> Verdict {
        .no
    }
    
    func visitFuncDefinition(
        _ definition: FuncDefinition,
        _ info: Void
    ) -> Verdict {
        .yes
    }
    
    func visitFuncApplication(
        _ expression: FuncApplication,
        _ info: Void
    ) -> Verdict {
        .notApplicable
    }
    
    func visitIfStatement(
        _ statement: IfStatement,
        _ info: Void
    ) -> Verdict {
        .notApplicable
    }
    
    func visitReturnStatement(
        _ statement: ReturnStatement,
        _ info: Void
    ) -> Verdict {
        .notApplicable
    }
    
    func visitAssignmentStatement(
        _ statement: AssignmentStatement,
        _ info: Void
    ) -> Verdict {
        .yes
    }
}

class SymbolGrabber: ASTVisitor {
    
    typealias Binding = String
    typealias VisitorInfo = Void
    typealias VisitorResult = [Binding]
    
    static var shared: SymbolGrabber {
        SymbolGrabber()
    }
    
    private init() {}
    
    func visitIdentifierExpression(
        _ expression: IdentifierExpression,
        _ info: Void
    ) -> [Binding] {
        return []
    }
    
    func visitBooleanExpression(
        _ expression: BooleanExpression,
        _ info: Void
    ) -> [Binding] {
        return []
    }
    
    func visitNumberExpression(
        _ expression: NumberExpression,
        _ info: Void
    ) -> [Binding] {
        return []
    }
    
    func visitUnaryOperation(
        _ operation: UnaryOperation,
        _ info: Void
    ) -> [Binding] {
        return []
    }
    
    func visitBinaryOperation(
        _ operation: BinaryOperation,
        _ info: Void
    ) -> [Binding] {
        return []
    }
    
    func visitLetDefinition(
        _ definition: LetDefinition,
        _ info: Void
    ) -> [Binding] {
        return [definition.name]
    }
    
    func visitVarDefinition(
        _ definition: VarDefinition,
        _ info: Void
    ) -> [Binding] {
        return [definition.name]
    }
    
    func visitFuncDefinition(
        _ definition: FuncDefinition,
        _ info: Void
    ) -> [Binding] {
        return [definition.name]
    }
    
    func visitFuncApplication(
        _ expression: FuncApplication,
        _ info: Void
    ) -> [Binding] {
        return []
    }
    
    func visitIfStatement(
        _ statement: IfStatement,
        _ info: Void
    ) -> [Binding] {
        return []
    }
    
    func visitReturnStatement(
        _ statement: ReturnStatement,
        _ info: Void
    ) -> [Binding] {
        return []
    }
    
    func visitAssignmentStatement(
        _ statement: AssignmentStatement,
        _ info: Void
    ) -> [Binding] {
        return []
    }
    
}

class SymbolResolve: SemaPass, ASTVisitor {
    
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
            let canBeRecursive = node.acceptVisitor(AllowsRecursiveDefinition.shared)
            
            var exclude: String? = nil
            switch canBeRecursive {
            case .no:
                let result = node.acceptVisitor(SymbolGrabber.shared)
                exclude = result.first
            case .yes, .notApplicable:
                break
            }
            
            let globals = context.getGlobalSymbols(excluding: exclude)
            node.acceptVisitor(self, globals)
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
        operation.expression.acceptVisitor(self, info)
    }
    
    func visitBinaryOperation(
        _ operation: BinaryOperation,
        _ info: [BindingInScope]
    ) {
        operation.lhs.acceptVisitor(self, info)
        operation.rhs.acceptVisitor(self, info)
    }
    
    func visitLetDefinition(
        _ definition: LetDefinition,
        _ info: [BindingInScope]
    ) {
        enforceNoShadowing(for: definition.name, scope: info)
        definition.expression.acceptVisitor(self, info)
    }
    
    func visitVarDefinition(
        _ definition: VarDefinition,
        _ info: [BindingInScope]
    ) {
        enforceNoShadowing(for: definition.name, scope: info)
        definition.expression.acceptVisitor(self, info)
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
        
        expression.arguments.forEach { $0.acceptVisitor(self, info) }
    }
    
    func visitIfStatement(
        _ statement: IfStatement,
        _ info: [BindingInScope]
    ) {
        statement.condition.acceptVisitor(self, info)
        processBlock(statement.thenBranch, info)
        if let elseBranch = statement.elseBranch {
            processBlock(elseBranch, info)
        }
    }
    
    func visitReturnStatement(
        _ statement: ReturnStatement,
        _ info: [BindingInScope]
    ) {
        statement.expression.acceptVisitor(self, info)
    }
    
    func visitAssignmentStatement(
        _ statement: AssignmentStatement,
        _ info: [BindingInScope]
    ) {
        if !info.contains(statement.name) {
            addError(.identifierUnbound(name: statement.name), at: .beginningOfFile)
        }
        
        statement.expression.acceptVisitor(self, info)
    }
    
    private func processBlock(
        _ block: [any BlockLevelNode],
        _ info: [BindingInScope]
    ) {
        var mutInfo = info
        block.forEach { node in
            node.acceptVisitor(self, mutInfo)
            let bindings = node.acceptVisitor(SymbolGrabber.shared)
            mutInfo.append(contentsOf: bindings)
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

