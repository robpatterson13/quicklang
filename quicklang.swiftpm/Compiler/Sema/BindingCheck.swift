//
//  BindingCheck.swift
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
    
    func visitDefinition(
        _ definition: DefinitionNode,
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
    
    func visitControlFlowJumpStatement(_ statement: ControlFlowJumpStatement, _ info: Void) -> Verdict {
        InternalCompilerError.unreachable()
    }
    
    func visitLabelControlFlowStatement(_ statement: LabelControlFlowStatement, _ info: Void) -> Verdict {
        InternalCompilerError.unreachable()
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
    
    func visitDefinition(
        _ definition: DefinitionNode,
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
    
    func visitControlFlowJumpStatement(_ statement: ControlFlowJumpStatement, _ info: Void) -> [Binding] {
        InternalCompilerError.unreachable()
    }
    
    func visitLabelControlFlowStatement(_ statement: LabelControlFlowStatement, _ info: Void) -> [Binding] {
        InternalCompilerError.unreachable()
    }
    
}

class BindingCheck: SemaPass, ASTVisitor {
    
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
            node.acceptVisitor(self)
        }
    }
    
    private func addError(_ error: SymbolResolveErrorType, at location: SourceCodeLocation) {
        let errorInfo = error.buildInfo(at: location)
        let error = errorInfo.getError(from: DefaultSymbolResolveErrorCreator.shared)
        errorManager?.addError(error)
    }
    
    private func checkInScope(_ node: any ASTNode, name: String, error: SymbolResolveErrorType) {
        if !(node.scope?.inScope(name) ?? false) {
            addError(error, at: .beginningOfFile)
        }
    }
    
    func visitIdentifierExpression(
        _ expression: IdentifierExpression,
        _ info: Void
    ) {
        checkInScope(expression, name: expression.name, error: .identifierUnbound(name: expression.name))
    }
    
    func visitBooleanExpression(
        _ expression: BooleanExpression,
        _ info: Void
    ) {
        // no-op
    }
    
    func visitNumberExpression(
        _ expression: NumberExpression,
        _ info: Void
    ) {
        // no-op
    }
    
    func visitUnaryOperation(
        _ operation: UnaryOperation,
        _ info: Void
    ) {
        operation.expression.acceptVisitor(self, info)
    }
    
    func visitBinaryOperation(
        _ operation: BinaryOperation,
        _ info: Void
    ) {
        operation.lhs.acceptVisitor(self, info)
        operation.rhs.acceptVisitor(self, info)
    }
    
    func visitDefinition(
        _ definition: DefinitionNode,
        _ info: Void
    ) {
        enforceNoShadowing(for: .definition(definition))
        definition.expression.acceptVisitor(self, info)
    }
    
    func visitFuncDefinition(
        _ definition: FuncDefinition,
        _ info: Void
    ) {
        enforceNoShadowing(for: .function(definition))
        definition.parameters.forEach { param in
            enforceNoShadowing(for: .funcParameter(param))
        }
        
        enforceUniqueParameterNames(definition.parameters)
        
        processBlock(definition.body)
    }
    
    private func enforceUniqueParameterNames(_ params: [FuncDefinition.Parameter]) {
        guard !params.isEmpty else {
            return
        }
        
        for (idx, param) in params.enumerated() {
            let newArray = params.enumerated().filter { index, _ in
                return index != idx
            }.map { _, param in
                param
            }
            
            let set = Set(newArray)
            if set.contains(param) {
                addError(.parameterNamesNotUnique(repeated: param.name), at: .beginningOfFile)
                return
            }
        }
    }
    
    private func enforceNoShadowing(for binding: ASTScope.IntroducedBinding) {
        if let scope = binding.scope,
           scope.alreadyDeclared(binding) {
            addError(.shadowing(name: binding.identifiableName.0), at: .beginningOfFile)
        }
    }
    
    func visitFuncApplication(
        _ expression: FuncApplication,
        _ info: Void
    ) {
        checkInScope(expression, name: expression.name, error: .functionNotFound(name: expression.name))
        
        expression.arguments.forEach { $0.acceptVisitor(self, info) }
    }
    
    func visitIfStatement(
        _ statement: IfStatement,
        _ info: Void
    ) {
        statement.condition.acceptVisitor(self, info)
        processBlock(statement.thenBranch)
        if let elseBranch = statement.elseBranch {
            processBlock(elseBranch)
        }
    }
    
    func visitReturnStatement(
        _ statement: ReturnStatement,
        _ info: Void
    ) {
        statement.expression.acceptVisitor(self, info)
    }
    
    func visitAssignmentStatement(
        _ statement: AssignmentStatement,
        _ info: Void
    ) {
        checkInScope(statement, name: statement.name, error: .identifierUnbound(name: statement.name))
        
        statement.expression.acceptVisitor(self, info)
    }
    
    private func processBlock(
        _ block: [any BlockLevelNode]
    ) {
        block.forEach { node in
            node.acceptVisitor(self)
        }
    }
    
    func visitControlFlowJumpStatement(_ statement: ControlFlowJumpStatement, _ info: Void) {
        InternalCompilerError.unreachable()
    }
    
    func visitLabelControlFlowStatement(_ statement: LabelControlFlowStatement, _ info: Void) {
        InternalCompilerError.unreachable()
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

