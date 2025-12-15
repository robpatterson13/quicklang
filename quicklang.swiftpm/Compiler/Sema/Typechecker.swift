//
//  Typechecker.swift
//  quicklang
//
//  Created by Rob Patterson on 2/16/25.
//

class GetAllReturnStatements: ASTVisitor {
    typealias VisitorResult = [ReturnStatement]
    typealias VisitorInfo = Void
    
    func visitIdentifierExpression(
        _ expression: IdentifierExpression,
        _ info: Void
    ) -> [ReturnStatement] {
        []
    }
    
    func visitBooleanExpression(
        _ expression: BooleanExpression,
        _ info: Void
    ) -> [ReturnStatement] {
        []
    }
    
    func visitNumberExpression(
        _ expression: NumberExpression,
        _ info: Void
    ) -> [ReturnStatement] {
        []
    }
    
    func visitUnaryOperation(
        _ operation: UnaryOperation,
        _ info: Void
    ) -> [ReturnStatement] {
        []
    }
    
    func visitBinaryOperation(
        _ operation: BinaryOperation,
        _ info: Void
    ) -> [ReturnStatement] {
        []
    }
    
    func visitDefinition(
        _ definition: DefinitionNode,
        _ info: Void
    ) -> [ReturnStatement] {
        []
    }
    
    private func processBlock(
        _ block: [any BlockLevelNode]
    ) -> [ReturnStatement] {
        var returns: [ReturnStatement] = []
        for node in block {
            let returnStatements = node.acceptVisitor(self)
            returns.append(contentsOf: returnStatements)
        }
        
        return returns
    }
    
    func visitFuncDefinition(
        _ definition: FuncDefinition,
        _ info: Void
    ) -> [ReturnStatement] {
        processBlock(definition.body)
    }
    
    func visitFuncApplication(
        _ expression: FuncApplication,
        _ info: Void
    ) -> [ReturnStatement] {
        []
    }
    
    func visitIfStatement(
        _ statement: IfStatement,
        _ info: Void
    ) -> [ReturnStatement] {
        let thenBranchReturns = processBlock(statement.thenBranch)
        if let elseBranch = statement.elseBranch {
            let elseBranchReturns = processBlock(elseBranch)
            return thenBranchReturns + elseBranchReturns
        }
        
        return thenBranchReturns
        
    }
    
    func visitReturnStatement(
        _ statement: ReturnStatement,
        _ info: Void
    ) -> [ReturnStatement] {
        [statement]
    }
    
    func visitAssignmentStatement(
        _ statement: AssignmentStatement,
        _ info: Void
    ) -> [ReturnStatement] {
        []
    }
    
}

class InferType: ASTVisitor {
    typealias VisitorInfo = Void
    typealias VisitorResult = TypeName?
    
    var context: ASTContext
    
    init(context: ASTContext) {
        self.context = context
    }
    
    func visitIdentifierExpression(
        _ expression: IdentifierExpression,
        _ info: Void
    ) -> TypeName? {
        context.getTypeOf(symbol: expression.name)
    }
    
    func visitBooleanExpression(
        _ expression: BooleanExpression,
        _ info: Void
    ) -> TypeName? {
        .Bool
    }
    
    func visitNumberExpression(
        _ expression: NumberExpression,
        _ info: Void
    ) -> TypeName? {
        .Int
    }
    
    func visitUnaryOperation(
        _ operation: UnaryOperation,
        _ info: Void
    ) -> TypeName? {
        switch operation.op {
        case .not, .neg:
            return .Bool
        }
    }
    
    func visitBinaryOperation(
        _ operation: BinaryOperation,
        _ info: Void
    ) -> TypeName? {
        switch operation.op {
        case .plus, .times, .minus:
            return .Int
        case .and, .or:
            return .Bool
        }
    }
    
    func visitFuncApplication(
        _ expression: FuncApplication,
        _ info: Void
    ) -> TypeName? {
        context.getTypeOf(symbol: expression.name)?.returnType
    }
    
    func visitDefinition(
        _ definition: DefinitionNode,
        _ info: Void
    ) -> TypeName? {
        nil
    }
    
    func visitFuncDefinition(
        _ definition: FuncDefinition,
        _ info: Void
    ) -> TypeName? {
        nil
    }
    
    func visitIfStatement(
        _ statement: IfStatement,
        _ info: Void
    ) -> TypeName? {
        nil
    }
    
    func visitReturnStatement(
        _ statement: ReturnStatement,
        _ info: Void
    ) -> TypeName? {
        nil
    }
    
    func visitAssignmentStatement(
        _ statement: AssignmentStatement,
        _ info: Void
    ) -> TypeName? {
        nil
    }
}

class Typechecker: SemaPass, ASTVisitor {
    typealias VisitorResult = Void
    typealias VisitorInfo = Void
    
    var errorManager: CompilerErrorManager?
    
    func begin(reportingTo: CompilerErrorManager) {
        errorManager = reportingTo
        let tree = context.tree
        
        tree.sections.forEach { node in
            node.acceptVisitor(self)
        }
    }
    
    let context: ASTContext
    lazy var typeInferrer: InferType = Self.initTypeInferrer(self)
    lazy var returnStatementGrabber: GetAllReturnStatements = .init()
    
    init(context: ASTContext) {
        self.context = context
    }
    
    private static func initTypeInferrer(_ self: Typechecker) -> InferType {
        .init(context: self.context)
    }
    
    private func addError(_ error: TypecheckerErrorType, at location: SourceCodeLocation) {
        let errorInfo = error.buildInfo(at: location)
        let error = errorInfo.getError(from: DefaultTypecheckerErrorCreator.shared)
        errorManager?.addError(error)
    }
    
    private func checkExpression(_ node: any ExpressionNode, is type: TypeName, error: TypecheckerErrorType) {
        let result = node.acceptVisitor(typeInferrer)
        if result != type {
            addError(error, at: .beginningOfFile)
        }
    }
    
    func visitIdentifierExpression(_ expression: IdentifierExpression, _ info: Void) {}
    
    func visitBooleanExpression(_ expression: BooleanExpression, _ info: Void) {}
    
    func visitNumberExpression(_ expression: NumberExpression, _ info: Void) {}
    
    func visitUnaryOperation(_ operation: UnaryOperation, _ info: Void) {
        switch operation.op {
        case .not, .neg:
            checkExpression(operation, is: .Bool, error: .operatorTypeMismatch(defined: .Bool))
        }
        
        operation.expression.acceptVisitor(self)
    }
    
    func visitBinaryOperation(_ operation: BinaryOperation, _ info: Void) {
        switch operation.op {
        case .plus, .minus, .times:
            let error = TypecheckerErrorType.operatorTypeMismatch(defined: .Int)
            checkExpression(operation.lhs, is: .Int, error: error)
            checkExpression(operation.rhs, is: .Int, error: error)
        case .and, .or:
            let error = TypecheckerErrorType.operatorTypeMismatch(defined: .Int)
            checkExpression(operation.lhs, is: .Bool, error: error)
            checkExpression(operation.rhs, is: .Bool, error: error)
        }
        
        operation.lhs.acceptVisitor(self)
        operation.rhs.acceptVisitor(self)
    }
    
    func visitDefinition(_ definition: DefinitionNode, _ info: Void) {
        let type = definition.type
        checkExpression(definition.expression, is: type, error: .typeMismatchInDefinition(defined: type))
        
        definition.expression.acceptVisitor(self)
    }
    
    func visitFuncDefinition(_ definition: FuncDefinition, _ info: Void) {
        definition.body.forEach { node in
            node.acceptVisitor(self)
        }
        
        guard let returnType = definition.type.returnType else {
            fatalError("All funcs should have a return type at this point")
        }
        let returns = definition.body.flatMap { $0.acceptVisitor(returnStatementGrabber) }
        
        for returnStmt in returns {
            checkExpression(returnStmt.expression, is: returnType, error: .funcReturnTypeMismatch(defined: returnType))
        }
    }
    
    func visitFuncApplication(_ expression: FuncApplication, _ info: Void) {
        let funcType = context.getTypeOf(symbol: expression.name)
        let paramTypes = funcType!.paramTypes!
        
        for (idx, arg) in expression.arguments.enumerated() {
            checkExpression(arg, is: paramTypes[idx], error: .funcArgWrongType(defined: paramTypes[idx]))
        }
        
        expression.arguments.forEach { $0.acceptVisitor(self) }
    }
    
    func visitIfStatement(_ statement: IfStatement, _ info: Void) {
        checkExpression(statement.condition, is: .Bool, error: .ifConditionNotBool)
        
        statement.thenBranch.forEach { $0.acceptVisitor(self) }
        statement.elseBranch?.forEach { $0.acceptVisitor(self) }
    }
    
    func visitReturnStatement(_ statement: ReturnStatement, _ info: Void) {
        statement.expression.acceptVisitor(self)
    }
    
    func visitAssignmentStatement(_ statement: AssignmentStatement, _ info: Void) {
        let type = context.getTypeOf(symbol: statement.name)
        if let type {
            checkExpression(statement.expression, is: type, error: .typeMismatchInDefinition(defined: type))
        }
    }
    
}

enum TypecheckerErrorType: CompilerPhaseErrorType {
    
    case typeMismatchInDefinition(defined: TypeName)
    case ifConditionNotBool
    case funcArgWrongType(defined: TypeName)
    case funcReturnTypeMismatch(defined: TypeName)
    case voidCannotReturnValue
    case missingReturnInNonvoidFunc
    case operatorTypeMismatch(defined: TypeName)
    
    func buildInfo(at location: SourceCodeLocation) -> any TypecheckPhaseErrorInfo {
        switch self {
        case .typeMismatchInDefinition(let defined):
            return TypeMismatchInDefinitionErrorInfo(location: location, definedAs: defined)
        case .ifConditionNotBool:
            return IfConditionNotBoolErrorInfo(location: location)
        case .funcArgWrongType(let defined):
            return FuncArgWrongTypeErrorInfo(location: location, definedAs: defined)
        case .funcReturnTypeMismatch(let defined):
            return FuncReturnTypeMismatchErrorInfo(location: location, definedAs: defined)
        case .voidCannotReturnValue:
            return VoidCannotReturnValueErrorInfo(location: location)
        case .missingReturnInNonvoidFunc:
            return MissingReturnInNonvoidFuncErrorInfo(location: location)
        case .operatorTypeMismatch(let defined):
            return OperatorTypeMismatchErrorInfo(location: location, definedAs: defined)
        }
    }
    
}

protocol TypecheckerErrorCreator {
    func typeMismatchInDefinition(info: TypeMismatchInDefinitionErrorInfo) -> TypecheckerError
    func ifConditionNotBool(info: IfConditionNotBoolErrorInfo) -> TypecheckerError
    func funcArgWrongType(info: FuncArgWrongTypeErrorInfo) -> TypecheckerError
    func funcReturnTypeMismatch(info: FuncReturnTypeMismatchErrorInfo) -> TypecheckerError
    func voidCannotReturnValue(info: VoidCannotReturnValueErrorInfo) -> TypecheckerError
    func missingReturnInNonvoidFunc(info: MissingReturnInNonvoidFuncErrorInfo) -> TypecheckerError
    func operatorTypeMismatch(info: OperatorTypeMismatchErrorInfo) -> TypecheckerError
}

protocol TypecheckPhaseErrorInfo: CompilerPhaseErrorInfo {
    var location: SourceCodeLocation { get }
    
    func getError(from manager: any TypecheckerErrorCreator) -> TypecheckerError
}

struct TypecheckerError: CompilerPhaseError {
    let location: SourceCodeLocation
    let message: String
}

struct TypeMismatchInDefinitionErrorInfo: TypecheckPhaseErrorInfo {
    
    let location: SourceCodeLocation
    let definedAs: TypeName
    
    func getError(from manager: any TypecheckerErrorCreator) -> TypecheckerError {
        manager.typeMismatchInDefinition(info: self)
    }
}

struct IfConditionNotBoolErrorInfo: TypecheckPhaseErrorInfo {
    let location: SourceCodeLocation
    
    func getError(from manager: any TypecheckerErrorCreator) -> TypecheckerError {
        manager.ifConditionNotBool(info: self)
    }
}

struct FuncArgWrongTypeErrorInfo: TypecheckPhaseErrorInfo {
    let location: SourceCodeLocation
    let definedAs: TypeName
    
    func getError(from manager: any TypecheckerErrorCreator) -> TypecheckerError {
        manager.funcArgWrongType(info: self)
    }
}

struct FuncReturnTypeMismatchErrorInfo: TypecheckPhaseErrorInfo {
    let location: SourceCodeLocation
    let definedAs: TypeName
    
    func getError(from manager: any TypecheckerErrorCreator) -> TypecheckerError {
        manager.funcReturnTypeMismatch(info: self)
    }
}

struct VoidCannotReturnValueErrorInfo: TypecheckPhaseErrorInfo {
    let location: SourceCodeLocation
    
    func getError(from manager: any TypecheckerErrorCreator) -> TypecheckerError {
        manager.voidCannotReturnValue(info: self)
    }
}

struct MissingReturnInNonvoidFuncErrorInfo: TypecheckPhaseErrorInfo {
    let location: SourceCodeLocation
    
    func getError(from manager: any TypecheckerErrorCreator) -> TypecheckerError {
        manager.missingReturnInNonvoidFunc(info: self)
    }
}

struct OperatorTypeMismatchErrorInfo: TypecheckPhaseErrorInfo {
    let location: SourceCodeLocation
    let definedAs: TypeName
    
    func getError(from manager: any TypecheckerErrorCreator) -> TypecheckerError {
        manager.operatorTypeMismatch(info: self)
    }
}

class DefaultTypecheckerErrorCreator: TypecheckerErrorCreator {
    
    static var shared: DefaultTypecheckerErrorCreator {
        DefaultTypecheckerErrorCreator()
    }
    
    private init() {}
    
    func typeMismatchInDefinition(info: TypeMismatchInDefinitionErrorInfo) -> TypecheckerError {
        TypecheckerError(location: .beginningOfFile, message: "1")
    }
    
    func ifConditionNotBool(info: IfConditionNotBoolErrorInfo) -> TypecheckerError {
        TypecheckerError(location: .beginningOfFile, message: "2")
    }
    
    func funcArgWrongType(info: FuncArgWrongTypeErrorInfo) -> TypecheckerError {
        TypecheckerError(location: .beginningOfFile, message: "3")
    }
    
    func funcReturnTypeMismatch(info: FuncReturnTypeMismatchErrorInfo) -> TypecheckerError {
        TypecheckerError(location: .beginningOfFile, message: "4")
    }
    
    func voidCannotReturnValue(info: VoidCannotReturnValueErrorInfo) -> TypecheckerError {
        TypecheckerError(location: .beginningOfFile, message: "5")
    }
    
    func missingReturnInNonvoidFunc(info: MissingReturnInNonvoidFuncErrorInfo) -> TypecheckerError {
        TypecheckerError(location: .beginningOfFile, message: "6")
    }
    
    func operatorTypeMismatch(info: OperatorTypeMismatchErrorInfo) -> TypecheckerError {
        TypecheckerError(location: .beginningOfFile, message: "7")
    }
    
    
}
