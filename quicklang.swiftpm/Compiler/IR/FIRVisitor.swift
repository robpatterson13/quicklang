//
//  FIRVisitor.swift
//  quicklang
//
//  Created by Rob Patterson on 12/15/25.
//

protocol FIRVisitor {
    associatedtype VisitorResult
    associatedtype VisitorInfo
    
    func visitFIRIdentifier(
        _ expression: FIRIdentifier,
        _ info: VisitorInfo
    ) -> VisitorResult
    
    func visitFIRBoolean(
        _ expression: FIRBoolean,
        _ info: VisitorInfo
    ) -> VisitorResult
    
    func visitFIRInteger(
        _ expression: FIRInteger,
        _ info: VisitorInfo
    ) -> VisitorResult
    
    func visitFIRUnaryExpression(
        _ operation: FIRUnaryExpression,
        _ info: VisitorInfo
    ) -> VisitorResult
    
    func visitFIRBinaryExpression(
        _ operation: FIRBinaryExpression,
        _ info: VisitorInfo
    ) -> VisitorResult
    
    func visitFIRAssignment(
        _ definition: FIRAssignment,
        _ info: VisitorInfo
    ) -> VisitorResult
    
    func visitFIRConditionalBranch(
        _ definition: FIRConditionalBranch,
        _ info: VisitorInfo
    ) -> VisitorResult
    
    func visitFIRBranch(
        _ expression: FIRBranch,
        _ info: VisitorInfo
    ) -> VisitorResult
    
    func visitFIRJump(
        _ statement: FIRJump,
        _ info: VisitorInfo
    ) -> VisitorResult
    
    func visitFIRLabel(
        _ statement: FIRLabel,
        _ info: VisitorInfo
    ) -> VisitorResult
    
    func visitFIRReturn(
        _ statement: FIRReturn,
        _ info: VisitorInfo
    ) -> VisitorResult
    
    func visitFIRFunctionCall(
        _ statement: FIRFunctionCall,
        _ info: VisitorInfo
    ) -> VisitorResult
    
    func visitFIREmptyTuple(
        _ empty: FIREmptyTuple,
        _ info: VisitorInfo
    ) -> VisitorResult
}
