//
//  AST.swift
//  quicklang
//
//  Created by Rob Patterson on 2/11/25.
//

protocol ASTVisitor {
    associatedtype ASTVisitResult
    
    func visitIdentifierExpression(_ expression: IdentifierExpression) -> ASTVisitResult
    func visitBooleanExpression(_ expression: BooleanExpression) -> ASTVisitResult
    func visitNumberExpression(_ expression: NumberExpression) -> ASTVisitResult
    
    func visitUnaryOperation(_ operation: UnaryOperation) -> ASTVisitResult
    func visitBinaryOperation(_ operation: BinaryOperation) -> ASTVisitResult
    
    func visitLetDefinition(_ definition: LetDefinition) -> ASTVisitResult
    func visitVarDefinition(_ definition: VarDefinition) -> ASTVisitResult
    
    func visitFuncDefinition(_ definition: FuncDefinition) -> ASTVisitResult
    func visitFuncApplication(_ expression: FuncApplication) -> ASTVisitResult
    
    func visitIfStatement(_ statement: IfStatement) -> ASTVisitResult
    func visitReturnStatement(_ statement: ReturnStatement) -> ASTVisitResult
}

protocol ASTNode: ~Copyable {
    var isIncomplete: Bool { get }
    var anyIncomplete: Bool { get }
    static var incomplete: Self { get }
    
    consuming func accept(_ visitor: any ASTVisitor)
}

extension ASTNode {
    var anyIncomplete: Bool {
        if isIncomplete { return true }
        return Self._containsIncomplete(in: self)
    }
    
    private static func _containsIncomplete(in value: Any) -> Bool {
        
        if let node = value as? any ASTNode {
            if node.isIncomplete { return true }
        }
        
        let mirror = Mirror(reflecting: value)
        
        switch mirror.displayStyle {
        case .optional:
            if let child = mirror.children.first {
                return _containsIncomplete(in: child.value)
            }
            return false
            
        case .collection, .set, .dictionary, .tuple, .struct, .class, .enum:
            if _hasTrueIsIncompleteFlag(mirror) {
                return true
            }
            
            for child in mirror.children {
                if _containsIncomplete(in: child.value) {
                    return true
                }
            }
            return false
            
        case .none:
            return false
            
        default:
            return false
        }
    }
    
    private static func _hasTrueIsIncompleteFlag(_ mirror: Mirror) -> Bool {
        for (labelOpt, value) in mirror.children {
            if let label = labelOpt, label == "isIncomplete", let flag = value as? Bool, flag == true {
                return true
            }
        }
        return false
    }
}

struct TopLevel {
    var sections: [TopLevelNode]
}

protocol BlockLevelNode: ASTNode { }

struct BlockLevelNodeIncomplete: BlockLevelNode {
    var isIncomplete: Bool
    
    static var incomplete: BlockLevelNodeIncomplete {
        BlockLevelNodeIncomplete()
    }
    
    private init() {
        self.isIncomplete = true
    }
    
    consuming func accept(_ visitor: any ASTVisitor) {
    }
}

protocol TopLevelNode: BlockLevelNode { }

struct TopLevelNodeIncomplete: TopLevelNode {
    static var incomplete: TopLevelNodeIncomplete {
        TopLevelNodeIncomplete()
    }
    
    private init() {
        self.isIncomplete = true
    }
    
    var isIncomplete: Bool
    
    func accept(_ visitor: any ASTVisitor) {
        
    }
}

extension TopLevelNode {
    
    static var incomplete: FuncDefinition {
        FuncDefinition.incomplete
    }
}

protocol ExpressionNode: ASTNode { }

protocol DefinitionNode: TopLevelNode {
    var name: String { get }
    var expression: any ExpressionNode { get }
}

protocol StatementNode: BlockLevelNode { }

struct IdentifierExpression: ExpressionNode {
    let name: String
    
    let isIncomplete: Bool
    
    static var incomplete: IdentifierExpression {
        return IdentifierExpression()
    }
    
    private init() {
        self.name = ""
        self.isIncomplete = true
    }
    
    init(name: String) {
        self.name = name
        self.isIncomplete = false
    }
    
    func accept(_ visitor: any ASTVisitor) {
        visitor.visitIdentifierExpression(self)
    }
}

struct BooleanExpression: ExpressionNode {
    let value: Bool
    
    let isIncomplete: Bool
    
    static var incomplete: BooleanExpression {
        return BooleanExpression()
    }
    
    private init() {
        self.value = false
        self.isIncomplete = true
    }
    
    init(value: Bool) {
        self.value = value
        self.isIncomplete = false
    }
    
    func accept(_ visitor: any ASTVisitor) {
        visitor.visitBooleanExpression(self)
    }
}

struct NumberExpression: ExpressionNode {
    let value: Int
    
    let isIncomplete: Bool
    
    static var incomplete: NumberExpression {
        return NumberExpression()
    }
    
    private init() {
        self.value = 0
        self.isIncomplete = true
    }
    
    init(value: Int) {
        self.value = value
        self.isIncomplete = false
    }
    
    func accept(_ visitor: any ASTVisitor) {
        visitor.visitNumberExpression(self)
    }
}

struct UnaryOperation: ExpressionNode {
    let op: Operator
    enum Operator {
        case not
        case neg
    }
    let expression: any ExpressionNode
    
    let isIncomplete: Bool
    
    static var incomplete: UnaryOperation {
        return UnaryOperation()
    }
    
    private init() {
        self.op = .not
        self.expression = IdentifierExpression.incomplete
        self.isIncomplete = true
    }
    
    init(op: Operator, expression: any ExpressionNode) {
        self.op = op
        self.expression = expression
        self.isIncomplete = false
    }
    
    func accept(_ visitor: any ASTVisitor) {
        visitor.visitUnaryOperation(self)
    }
}

struct BinaryOperation: ExpressionNode {
    let op: Operator
    enum Operator {
        case plus
        case minus
        case times
        
        case and
        case or
    }
    let lhs, rhs: ExpressionNode
    
    let isIncomplete: Bool
    
    static var incomplete: BinaryOperation {
        return BinaryOperation()
    }
    
    private init() {
        self.op = .plus
        self.lhs = IdentifierExpression.incomplete
        self.rhs = IdentifierExpression.incomplete
        self.isIncomplete = true
    }
    
    init(op: Operator, lhs: ExpressionNode, rhs: ExpressionNode) {
        self.op = op
        self.lhs = lhs
        self.rhs = rhs
        self.isIncomplete = false
    }
    
    consuming func accept(_ visitor: any ASTVisitor) {
        visitor.visitBinaryOperation(consume self)
    }
}

struct LetDefinition: DefinitionNode  {
    let name: String
    let expression: any ExpressionNode
    
    let isIncomplete: Bool
    
    static var incomplete: LetDefinition {
        return LetDefinition()
    }
    
    private init() {
        self.name = ""
        self.expression = IdentifierExpression.incomplete
        self.isIncomplete = true
    }
    
    init(name: String, expression: any ExpressionNode) {
        self.name = name
        self.expression = expression
        self.isIncomplete = false
    }
    
    func accept(_ visitor: any ASTVisitor) {
        visitor.visitLetDefinition(self)
    }
}

struct VarDefinition: DefinitionNode {
    let name: String
    let expression: any ExpressionNode
    
    let isIncomplete: Bool
    
    static var incomplete: VarDefinition {
        return VarDefinition()
    }
    
    private init() {
        self.name = ""
        self.expression = IdentifierExpression.incomplete
        self.isIncomplete = true
    }
    
    init(name: String, expression: any ExpressionNode) {
        self.name = name
        self.expression = expression
        self.isIncomplete = false
    }
    
    func accept(_ visitor: any ASTVisitor) {
        visitor.visitVarDefinition(self)
    }
}

enum TypeName {
    case Bool
    case Int
    case String
}

struct FuncDefinition: TopLevelNode {
    
    struct Parameter {
        let name: String
        let type: TypeName
        let isIncomplete: Bool
        static var incomplete: Parameter {
            return Parameter()
        }
        
        private init() {
            self.name = ""
            self.type = .Int
            self.isIncomplete = true
        }
        
        init(name: String, type: TypeName) {
            self.name = name
            self.type = .Int 
            self.isIncomplete = false
        }
    }
    
    let name: String
    let type: TypeName
    let parameters: [Parameter]
    let body: [any BlockLevelNode]
    
    let isIncomplete: Bool
    
    static var incomplete: FuncDefinition {
        return FuncDefinition()
    }
    
    private init() {
        self.name = ""
        self.type = .Int
        self.parameters = []
        self.body = []
        self.isIncomplete = true
    }
    
    init(name: String, type: TypeName, parameters: [Parameter], body: [any BlockLevelNode]) {
        self.name = name
        self.type = type
        self.parameters = parameters
        self.body = body
        self.isIncomplete = false
    }
    
    func accept(_ visitor: any ASTVisitor) {
        visitor.visitFuncDefinition(self)
    }
}

struct FuncApplication: ExpressionNode, TopLevelNode {
    let name: String
    let arguments: [any ExpressionNode]
    
    let isIncomplete: Bool
    
    static var incomplete: FuncApplication {
        return FuncApplication()
    }
    
    private init() {
        self.name = ""
        self.arguments = []
        self.isIncomplete = true
    }
    
    init(name: String, arguments: [any ExpressionNode]) {
        self.name = name
        self.arguments = arguments
        self.isIncomplete = false
    }
    
    func accept(_ visitor: any ASTVisitor) {
        visitor.visitFuncApplication(self)
    }
}

struct IfStatement: StatementNode, BlockLevelNode {
    let condition: any ExpressionNode
    let thenBranch: [any BlockLevelNode]
    let elseBranch: [any BlockLevelNode]?
    
    let isIncomplete: Bool
    
    static var incomplete: IfStatement {
        return IfStatement()
    }
    
    private init() {
        self.condition = IdentifierExpression.incomplete
        self.thenBranch = []
        self.elseBranch = nil
        self.isIncomplete = true
    }
    
    init(condition: any ExpressionNode, thenBranch: [any BlockLevelNode], elseBranch: [any BlockLevelNode]?) {
        self.condition = condition
        self.thenBranch = thenBranch
        self.elseBranch = elseBranch
        self.isIncomplete = false
    }
    
    func accept(_ visitor: any ASTVisitor) {
        visitor.visitIfStatement(self)
    }
}

struct ReturnStatement: StatementNode, BlockLevelNode {
    let expression: any ExpressionNode
    
    let isIncomplete: Bool
    static var incomplete: ReturnStatement {
        return ReturnStatement()
    }
    
    private init() {
        self.expression = IdentifierExpression.incomplete
        self.isIncomplete = true
    }
    
    init(expression: any ExpressionNode) {
        self.expression = expression
        self.isIncomplete = false
    }
    
    func accept(_ visitor: any ASTVisitor) {
        visitor.visitReturnStatement(self)
    }
}

