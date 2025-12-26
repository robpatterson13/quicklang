//
//  ASTVisitor.swift
//  quicklang
//
//  Created by Rob Patterson on 11/15/25.
//

protocol ASTVisitor {
    associatedtype VisitorResult
    associatedtype VisitorInfo
    
    func visitIdentifierExpression(
        _ expression: IdentifierExpression,
        _ info: VisitorInfo
    ) -> VisitorResult 
    
    func visitBooleanExpression(
        _ expression: BooleanExpression,
        _ info: VisitorInfo
    ) -> VisitorResult 
    
    func visitNumberExpression(
        _ expression: NumberExpression,
        _ info: VisitorInfo
    ) -> VisitorResult 
    
    func visitUnaryOperation(
        _ operation: UnaryOperation,
        _ info: VisitorInfo
    ) -> VisitorResult 
    
    func visitBinaryOperation(
        _ operation: BinaryOperation,
        _ info: VisitorInfo
    ) -> VisitorResult
    
    func visitDefinition(
        _ definition: DefinitionNode,
        _ info: VisitorInfo
    ) -> VisitorResult 
    
    func visitFuncDefinition(
        _ definition: FuncDefinition,
        _ info: VisitorInfo
    ) -> VisitorResult 
    
    func visitFuncApplication(
        _ expression: FuncApplication,
        _ info: VisitorInfo
    ) -> VisitorResult 
    
    func visitIfStatement(
        _ statement: IfStatement,
        _ info: VisitorInfo
    ) -> VisitorResult 
    
    func visitReturnStatement(
        _ statement: ReturnStatement,
        _ info: VisitorInfo
    ) -> VisitorResult 
    
    func visitAssignmentStatement(
        _ statement: AssignmentStatement,
        _ info: VisitorInfo
    ) -> VisitorResult
    
    func visitControlFlowJumpStatement(
        _ statement: ControlFlowJumpStatement,
        _ info: VisitorInfo
    ) -> VisitorResult
    
    func visitLabelControlFlowStatement(
        _ statement: LabelControlFlowStatement,
        _ info: VisitorInfo
    ) -> VisitorResult
}
