////
////  Desugar.swift
////  quicklang
////
////  Created by Rob Patterson on 12/13/25.
////
//
//final class Desugar: RawASTVisitor {
//    
//    enum DesugaringBridgeToAST {
//        case generic(any ASTNode)
//        case expression(any ExpressionNode)
//        case blockLevel(any BlockLevelNode)
//        case topLevel(any TopLevelNode)
//    }
//    
//    func visitRawIdentifierExpression(
//        _ expression: RawIdentifierExpression,
//        _ info: Void
//    ) -> DesugaringBridgeToAST {
//        let identifier = IdentifierExpression(name: expression.name)
//        return .expression(identifier)
//    }
//    
//    func visitRawBooleanExpression(
//        _ expression: RawBooleanExpression,
//        _ info: Void
//    ) -> DesugaringBridgeToAST {
//        let boolean = BooleanExpression(value: expression.value)
//        return .expression(boolean)
//    }
//    
//    func visitRawNumberExpression(
//        _ expression: RawNumberExpression,
//        _ info: Void
//    ) -> DesugaringBridgeToAST {
//        let number = NumberExpression(value: expression.value)
//        return .expression(number)
//    }
//    
//    func visitRawUnaryOperation(
//        _ operation: RawUnaryOperation,
//        _ info: Void
//    ) -> DesugaringBridgeToAST {
//        <#code#>
//    }
//    
//    func visitRawBinaryOperation(_ operation: RawBinaryOperation, _ info: Void) -> DesugaringBridgeToAST {
//        <#code#>
//    }
//    
//    func visitRawLetDefinition(
//        _ definition: RawLetDefinition,
//        _ info: Void
//    ) -> DesugaringBridgeToAST {
//        <#code#>
//    }
//    
//    func visitRawVarDefinition(_ definition: RawVarDefinition, _ info: Void) -> DesugaringBridgeToAST {
//        <#code#>
//    }
//    
//    func visitRawFuncDefinition(_ definition: RawFuncDefinition, _ info: Void) -> DesugaringBridgeToAST {
//        <#code#>
//    }
//    
//    func visitRawFuncApplication(_ expression: RawFuncApplication, _ info: Void) -> DesugaringBridgeToAST {
//        <#code#>
//    }
//    
//    func visitRawIfStatement(_ statement: RawIfStatement, _ info: Void) -> DesugaringBridgeToAST {
//        <#code#>
//    }
//    
//    func visitRawReturnStatement(_ statement: RawReturnStatement, _ info: Void) -> DesugaringBridgeToAST {
//        <#code#>
//    }
//    
//    func visitRawAssignmentStatement(_ statement: RawAssignmentStatement, _ info: Void) -> DesugaringBridgeToAST {
//        <#code#>
//    }
//    
//    func visitRawAttributedNode(_ attributedNode: RawAttributedNode, _ info: Void) -> DesugaringBridgeToAST {
//        <#code#>
//    }
//    
//}
