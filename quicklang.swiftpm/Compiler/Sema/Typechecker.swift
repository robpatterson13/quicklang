//
//  Typechecker.swift
//  quicklang
//
//  Created by Rob Patterson on 2/16/25.
//

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
    
    init(context: ASTContext) {
        self.context = context
    }
    
    private func addError(_ error: TypecheckerErrorType, at location: SourceCodeLocation) {
        let errorInfo = error.buildInfo(at: location)
        let error = errorInfo.getError(from: DefaultTypecheckerErrorCreator.shared)
        errorManager?.addError(error)
    }
    
    private func isExpression(_ expr: any ExpressionNode, type: TypeName) -> Bool {
        return type == context.getType(of: expr)
    }
    
    private func checkDefinition(_ definition: any DefinitionNode) {
        if let type = definition.type, !isExpression(definition.expression, type: type) {
            let actuallyIs = context.getType(of: definition.expression)
            addError(.typeMismatchInDefinition(defined: type, is: actuallyIs), at: .beginningOfFile)
        }
    }
    
    func visitIdentifierExpression(_ expression: IdentifierExpression, _ info: Void) {}
    
    func visitBooleanExpression(_ expression: BooleanExpression, _ info: Void) {}
    
    func visitNumberExpression(_ expression: NumberExpression, _ info: Void) {}
    
    func visitUnaryOperation(_ operation: UnaryOperation, _ info: Void) {
        switch operation.op {
        case .not, .neg:
            if !isExpression(operation.expression, type: .Bool) {
                addError(.operatorTypeMismatch(defined: .Bool), at: .beginningOfFile)
            }
        }
        
        operation.expression.acceptVisitor(self)
    }
    
    func visitBinaryOperation(_ operation: BinaryOperation, _ info: Void) {
        switch operation.op {
        case .plus, .minus, .times:
            if !isExpression(operation.lhs, type: .Int),
               !isExpression(operation.rhs, type: .Int) {
                addError(.operatorTypeMismatch(defined: .Int), at: .beginningOfFile)
            }
        case .and, .or:
            if !isExpression(operation.lhs, type: .Bool),
               !isExpression(operation.rhs, type: .Bool) {
                addError(.operatorTypeMismatch(defined: .Bool), at: .beginningOfFile)
            }
        }
        
        operation.lhs.acceptVisitor(self)
        operation.rhs.acceptVisitor(self)
    }
    
    func visitLetDefinition(_ definition: LetDefinition, _ info: Void) {
        checkDefinition(definition)
    }
    
    func visitVarDefinition(_ definition: VarDefinition, _ info: Void) {
        checkDefinition(definition)
    }
    
    func visitFuncDefinition(_ definition: FuncDefinition, _ info: Void) {
        // do the body of the definition first
        definition.body.forEach { $0.acceptVisitor(self) }
        
        // then type check the function definition + returned value
        let returnType = definition.type
        let returnStmt = definition.body.first { $0 is ReturnStatement } as? ReturnStatement
        
        // if our function is void and we don't return anything, exit
        if definition.type == .Void && returnStmt == nil {
            return
        }
        
        // if our function isn't void and we don't return anything, add error
        // and exit
        guard let returnStmt else {
            addError(.missingReturnInNonvoidFunc, at: .beginningOfFile)
            return
        }
        
        // if our return type isn't void, add error and exit
        guard returnType != .Void else {
            addError(.voidCannotReturnValue(returned: returnType), at: .beginningOfFile)
            return
        }
        
        if !isExpression(returnStmt.expression, type: returnType) {
            let actuallyIs = context.getType(of: returnStmt.expression)
            addError(.funcReturnTypeMismatch(defined: returnType, is: actuallyIs), at: .beginningOfFile)
        }
    }
    
    func visitFuncApplication(_ expression: FuncApplication, _ info: Void) {
        let params = context.getFuncParams(of: expression.name)
        
        for (idx, arg) in expression.arguments.enumerated()
        where !isExpression(arg, type: params[idx].type) {
            let actuallyIs = context.getType(of: arg)
            addError(.funcArgWrongType(defined: params[idx].type, is: actuallyIs), at: .beginningOfFile)
            return
        }
        
        expression.arguments.forEach { $0.acceptVisitor(self) }
    }
    
    func visitIfStatement(_ statement: IfStatement, _ info: Void) {
        if !isExpression(statement.condition, type: .Bool) {
            let actuallyIs = context.getType(of: statement.condition)
            addError(.ifConditionNotBool(is: actuallyIs), at: .beginningOfFile)
        }
        
        statement.thenBranch.forEach { $0.acceptVisitor(self) }
        statement.elseBranch?.forEach { $0.acceptVisitor(self) }
    }
    
    func visitReturnStatement(_ statement: ReturnStatement, _ info: Void) {
        statement.expression.acceptVisitor(self)
    }
    
    func visitAssignmentStatement(_ statement: AssignmentStatement, _ info: Void) {
        // MARK: NOT DONE
    }
    
}

enum TypecheckerErrorType: CompilerPhaseErrorType {
    
    case typeMismatchInDefinition(defined: TypeName, is: TypeName)
    case ifConditionNotBool(is: TypeName)
    case funcArgWrongType(defined: TypeName, is: TypeName)
    case funcReturnTypeMismatch(defined: TypeName, is: TypeName)
    case voidCannotReturnValue(returned: TypeName)
    case missingReturnInNonvoidFunc
    case operatorTypeMismatch(defined: TypeName)
    
    func buildInfo(at location: SourceCodeLocation) -> any TypecheckPhaseErrorInfo {
        switch self {
        case .typeMismatchInDefinition(let defined, let actuallyIs):
            return TypeMismatchInDefinitionErrorInfo(location: location, definedAs: defined, actuallyIs: actuallyIs)
        case .ifConditionNotBool(let actuallyIs):
            return IfConditionNotBoolErrorInfo(location: location, actuallyIs: actuallyIs)
        case .funcArgWrongType(let defined, let actuallyIs):
            return FuncArgWrongTypeErrorInfo(location: location, definedAs: defined, actuallyIs: actuallyIs)
        case .funcReturnTypeMismatch(let defined, let actuallyIs):
            return FuncArgWrongTypeErrorInfo(location: location, definedAs: defined, actuallyIs: actuallyIs)
        case .voidCannotReturnValue(let returned):
            return VoidCannotReturnValueErrorInfo(location: location, actuallyIs: returned)
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
    let actuallyIs: TypeName
    
    func getError(from manager: any TypecheckerErrorCreator) -> TypecheckerError {
        manager.typeMismatchInDefinition(info: self)
    }
}

struct IfConditionNotBoolErrorInfo: TypecheckPhaseErrorInfo {
    let location: SourceCodeLocation
    let actuallyIs: TypeName
    
    func getError(from manager: any TypecheckerErrorCreator) -> TypecheckerError {
        manager.ifConditionNotBool(info: self)
    }
}

struct FuncArgWrongTypeErrorInfo: TypecheckPhaseErrorInfo {
    let location: SourceCodeLocation
    let definedAs: TypeName
    let actuallyIs: TypeName
    
    func getError(from manager: any TypecheckerErrorCreator) -> TypecheckerError {
        manager.funcArgWrongType(info: self)
    }
}

struct FuncReturnTypeMismatchErrorInfo: TypecheckPhaseErrorInfo {
    let location: SourceCodeLocation
    let definedAs: TypeName
    let actuallyIs: TypeName
    
    func getError(from manager: any TypecheckerErrorCreator) -> TypecheckerError {
        manager.funcReturnTypeMismatch(info: self)
    }
}

struct VoidCannotReturnValueErrorInfo: TypecheckPhaseErrorInfo {
    let location: SourceCodeLocation
    let actuallyIs: TypeName
    
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
