//
//  IR.swift
//  quicklang
//
//  Created by Rob Patterson on 11/13/25.
//

protocol IRNode {}

protocol IRStatement: IRNode {}

protocol IRExpression: IRNode {}

protocol IRBlockLevel: IRNode {}

protocol IRTopLevel: IRBlockLevel {}

struct IRValDefinition: IRStatement, IRTopLevel {
    let name: String
    let binding: IRExpression
}

struct IRIdentifier: IRExpression {
    let name: String
}

struct IRNumber: IRExpression {
    let val: Int
}

struct IRBoolean: IRExpression {
    let val: Bool
}

struct IRUnaryOperation: IRExpression {
    let op: Operator
    enum Operator {
        case not
        case neg
    }
    let argument: IRExpression
}

struct IRBinaryOperation: IRExpression {
    let op: Operator
    enum Operator {
        case plus
        case minus
        case times
        
        case and
        case or
    }
    let lhs, rhs: IRExpression
}

struct IRReturnStatement: IRStatement, IRBlockLevel {
    let val: IRExpression
}

struct IRFuncDefinition: IRNode, IRTopLevel {
    let parameters: [String]
    let body: [IRBlockLevel]
}

struct IRFuncApplication: IRExpression, IRTopLevel {
    let name: String
    let arguments: [IRExpression]
}

struct IRIfStatement: IRStatement, IRBlockLevel {
    let cond: IRExpression
    let thenBranch: [any IRBlockLevel]
    let elseBranch: [any IRBlockLevel]?
}

