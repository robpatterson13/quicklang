//
//  DisplayableNode.swift
//  quicklang
//
//  Created by Rob Patterson on 11/26/25.
//

import SwiftUI

struct DisplayableNode: Identifiable {
    var id: UUID
    var name: String
    var description: String
    var children: [DisplayableNode]? = nil
}

class ConvertToDisplayableNode: RawASTVisitor {
    
    typealias VisitorResult = DisplayableNode
    typealias VisitorInfo = Void
    
    static var shared: ConvertToDisplayableNode {
        ConvertToDisplayableNode()
    }
    
    func begin(_ tree: RawTopLevel) -> [DisplayableNode] {
        var display: [DisplayableNode] = []
        
        tree.sections.forEach { node in
            display.append(node.acceptVisitor(self))
        }
        
        return display
    }
    
    func visitRawIdentifierExpression(
        _ expression: RawIdentifierExpression,
        _ info: Void
    ) -> DisplayableNode {
        return DisplayableNode(id: expression.id, name: "Identifier", description: expression.name)
    }
    
    func visitRawBooleanExpression(
        _ expression: RawBooleanExpression,
        _ info: Void
    ) -> DisplayableNode {
        return DisplayableNode(id: expression.id, name: "Boolean", description: String(expression.value))
    }
    
    func visitRawNumberExpression(
        _ expression: RawNumberExpression,
        _ info: Void
    ) -> DisplayableNode {
        return DisplayableNode(id: expression.id, name: "Number", description: String(expression.value))
    }
    
    func visitRawUnaryOperation(
        _ operation: RawUnaryOperation,
        _ info: Void
    ) -> DisplayableNode {
        let displayExpr = operation.expression.acceptVisitor(self)
        let opDescription: String = {
            switch operation.op {
            case .not: return "not"
            case .neg: return "neg"
            }
        }()
        return DisplayableNode(id: operation.id, name: "Unary Operation", description: opDescription, children: [displayExpr])
    }
    
    func visitRawBinaryOperation(
        _ operation: RawBinaryOperation,
        _ info: Void
    ) -> DisplayableNode {
        let displayLhs = operation.lhs.acceptVisitor(self)
        let displayRhs = operation.rhs.acceptVisitor(self)
        let opDescription: String = {
            switch operation.op {
            case .plus: return "+"
            case .minus: return "-"
            case .times: return "*"
            case .and: return "and"
            case .or: return "or"
            case .gt:
                return ">"
            case .gte:
                return ">="
            case .lt:
                return "<"
            case .lte:
                return "<="
            }
        }()
        return DisplayableNode(id: operation.id, name: "Binary Operation", description: opDescription, children: [displayLhs, displayRhs])
    }
    
    func visitRawLetDefinition(
        _ definition: RawLetDefinition,
        _ info: Void
    ) -> DisplayableNode {
        let displayExpr = definition.expression.acceptVisitor(self)
        return DisplayableNode(id: definition.id, name: "Let Definition", description: definition.name, children: [displayExpr])
    }
    
    func visitRawVarDefinition(
        _ definition: RawVarDefinition,
        _ info: Void
    ) -> DisplayableNode {
        let displayExpr = definition.expression.acceptVisitor(self)
        return DisplayableNode(id: definition.id, name: "Var Definition", description: definition.name, children: [displayExpr])
    }
    
    func visitRawConditionalBlock(
        _ block: RawConditionalBlock,
        _ info: Void
    ) -> DisplayableNode {
        let condition = block.condition.acceptVisitor(self)
        let conditionView = DisplayableNode(id: block.id, name: "Condition", description: "", children: [condition])
        
        let body = block.body.acceptVisitor(self)
        
        return DisplayableNode(id: block.id, name: "Body", description: "", children: [conditionView, body])
    }
    
    func visitRawBlockStatement(
        _ block: RawBlockStatement,
        _ info: Void
    ) -> DisplayableNode {
        let statements = block.statements.map { node in
            node.acceptVisitor(self)
        }
        
        return DisplayableNode(id: block.id, name: "Block Statement", description: "", children: statements)
    }
    
    func visitRawFuncDefinition(
        _ definition: RawFuncDefinition,
        _ info: Void
    ) -> DisplayableNode {
        let body = definition.body.acceptVisitor(self)
        
        return DisplayableNode(id: definition.id, name: "Func Definition", description: definition.name, children: [body])
    }
    
    func visitRawFuncApplication(
        _ expression: RawFuncApplication,
        _ info: Void
    ) -> DisplayableNode {
        var displayExpr: [DisplayableNode] = []
        expression.arguments.forEach { node in
            displayExpr.append(node.acceptVisitor(self))
        }
        
        return DisplayableNode(id: expression.id, name: "Func Application", description: expression.name, children: displayExpr)
    }
    
    func visitRawIfStatement(
        _ statement: RawIfStatement,
        _ info: Void
    ) -> DisplayableNode {
        var conditionalBlocks: [DisplayableNode] = statement.conditionalBlocks.map { $0.acceptVisitor(self) }
        if let elseBranch = statement.elseBranch {
            let displayElse = elseBranch.acceptVisitor(self)
            conditionalBlocks.append(displayElse)
        }
        
        return DisplayableNode(id: statement.id, name: "If Statement", description: "", children: conditionalBlocks)
    }
    
    func visitRawReturnStatement(
        _ statement: RawReturnStatement,
        _ info: Void
    ) -> DisplayableNode {
        let displayExpr = statement.expression.acceptVisitor(self)
        
        return DisplayableNode(id: statement.id, name: "Return Statement", description: "", children: [displayExpr])
    }
    
    func visitRawAssignmentStatement(
        _ statement: RawAssignmentStatement,
        _ info: Void
    ) -> DisplayableNode {
        let displayExpr = statement.expression.acceptVisitor(self)
        
        return DisplayableNode(id: statement.id, name: "Assignment Statement", description: statement.name, children: [displayExpr])
    }
    
    func visitRawAttributedNode(
        _ attributedNode: RawAttributedNode,
        _ info: Void
    ) -> DisplayableNode {
        let child = attributedNode.node.acceptVisitor(self)
        let attrDescription: String = {
            switch attributedNode.attribute {
            case .main: return "@main"
            case .never: return "@never"
            }
        }()
        return DisplayableNode(id: attributedNode.id, name: "Attribute", description: attrDescription, children: [child])
    }
}
