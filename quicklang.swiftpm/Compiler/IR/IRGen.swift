//
//  IRGen.swift
//  quicklang
//
//  Created by Rob Patterson on 11/14/25.
//

class IRGen {
    
    private func lowerExpression(_ expr: any ExpressionNode) -> IRExpression {
        switch expr {
        case let e as IdentifierExpression:
            return visitIdentifierExpression(e)
        case let e as BooleanExpression:
            return visitBooleanExpression(e)
        case let e as NumberExpression:
            return visitNumberExpression(e)
        case let e as UnaryOperation:
            return visitUnaryOperation(e)
        case let e as BinaryOperation:
            return visitBinaryOperation(e)
        case let e as FuncApplication:
            return visitFuncApplication(e)
        default:
            fatalError("Unhandled ExpressionNode type: \(type(of: expr))")
        }
    }
    
    private func lowerBlockLevel(_ node: any BlockLevelNode) -> IRBlockLevel {
        switch node {
        case let d as LetDefinition:
            return visitLetDefinition(d)
        case let d as VarDefinition:
            return visitVarDefinition(d)
        case let r as ReturnStatement:
            return visitReturnStatement(r)
        case let i as IfStatement:
            return visitIfStatement(i)
        case let fa as FuncApplication:
            return visitFuncApplication(fa)
        case is BlockLevelNodeIncomplete:
            fatalError("Internal Compiler Error: Attempted to lower incomplete block-level node")
        default:
            fatalError("Unhandled BlockLevelNode type: \(type(of: node))")
        }
    }
    
    func visitIdentifierExpression(_ expression: IdentifierExpression) -> IRIdentifier {
        return IRIdentifier(name: expression.name)
    }
    
    func visitBooleanExpression(_ expression: BooleanExpression) -> IRBoolean {
        return IRBoolean(val: expression.value)
    }
    
    func visitNumberExpression(_ expression: NumberExpression) -> IRNumber {
        return IRNumber(val: expression.value)
    }
    
    func visitUnaryOperation(_ operation: UnaryOperation) -> IRUnaryOperation {
        func mapOperator(_ op: UnaryOperation.Operator) -> IRUnaryOperation.Operator {
            switch op {
            case .not:
                return .not
            case .neg:
                return .neg
            }
        }
        
        let expression: IRExpression = lowerExpression(operation.expression)
        let op = mapOperator(operation.op)
        return IRUnaryOperation(op: op, argument: expression)
    }
    
    func visitBinaryOperation(_ operation: BinaryOperation) -> IRBinaryOperation {
        func mapOperator(_ op: BinaryOperation.Operator) -> IRBinaryOperation.Operator {
            switch op {
            case .plus:
                return .plus
            case .minus:
                return .minus
            case .times:
                return .times
            case .and:
                return .and
            case .or:
                return .or
            }
        }
        
        let lhs = lowerExpression(operation.lhs)
        let rhs = lowerExpression(operation.rhs)
        let op = mapOperator(operation.op)
        return IRBinaryOperation(op: op, lhs: lhs, rhs: rhs)
    }
    
    func visitLetDefinition(_ definition: LetDefinition) -> IRValDefinition {
        let binding = lowerExpression(definition.expression)
        return IRValDefinition(name: definition.name, binding: binding)
    }
    
    func visitVarDefinition(_ definition: VarDefinition) -> IRValDefinition {
        let binding = lowerExpression(definition.expression)
        return IRValDefinition(name: definition.name, binding: binding)
    }
    
    func visitFuncDefinition(_ definition: FuncDefinition) -> IRFuncDefinition {
        let params = definition.parameters.map { $0.name }
        let body: [IRBlockLevel] = definition.body.map { lowerBlockLevel($0) }
        return IRFuncDefinition(parameters: params, body: body)
    }
    
    func visitFuncApplication(_ expression: FuncApplication) -> IRFuncApplication {
        let args = expression.arguments.map { lowerExpression($0) }
        return IRFuncApplication(name: expression.name, arguments: args)
    }
    
    func visitIfStatement(_ statement: IfStatement) -> IRIfStatement {
        let cond = lowerExpression(statement.condition)
        let thn = statement.thenBranch.map { lowerBlockLevel($0) }
        let els = statement.elseBranch?.map { lowerBlockLevel($0) }
        return IRIfStatement(cond: cond, thenBranch: thn, elseBranch: els)
    }
    
    func visitReturnStatement(_ statement: ReturnStatement) -> IRReturnStatement {
        let value = lowerExpression(statement.expression)
        return IRReturnStatement(val: value)
    }
    
    typealias ASTVisitResult = any IRNode
}
