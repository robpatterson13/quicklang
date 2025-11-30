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

class ConvertToDisplayableNode: ASTVisitor {
    typealias TransformerInfo = DisplayableNode
    
    static var shared: ConvertToDisplayableNode {
        ConvertToDisplayableNode()
    }
    
    func begin(_ tree: TopLevel) -> [DisplayableNode] {
        var display: [DisplayableNode] = []
        
        tree.sections.forEach { node in
            display.append(node.acceptVisitor(self))
        }
        
        return display
    }
    
    func visitIdentifierExpression(
        _ expression: IdentifierExpression,
        _ info: Void
    ) -> DisplayableNode {
        return DisplayableNode(id: expression.id, name: "Identifier", description: expression.name)
    }
    
    func visitBooleanExpression(
        _ expression: BooleanExpression,
        _ info: Void
    ) -> DisplayableNode {
        return DisplayableNode(id: expression.id, name: "Boolean", description: String(expression.value))
    }
    
    func visitNumberExpression(
        _ expression: NumberExpression,
        _ info: Void
    ) -> DisplayableNode {
        return DisplayableNode(id: expression.id, name: "Number", description: String(expression.value))
    }
    
    func visitUnaryOperation(
        _ operation: UnaryOperation,
        _ info: Void
    ) -> DisplayableNode {
        
        let displayExpr = operation.expression.acceptVisitor(self)
        return DisplayableNode(id: operation.id, name: "Unary Operation", description: "op here", children: [displayExpr])
    }
    
    func visitBinaryOperation(
        _ operation: BinaryOperation,
        _ info: Void
    ) -> DisplayableNode {
        let displayLhs = operation.lhs.acceptVisitor(self)
        let displayRhs = operation.rhs.acceptVisitor(self)
        
        return DisplayableNode(id: operation.id, name: "Binary Operation", description: "op here", children: [displayLhs, displayRhs])
    }
    
    func visitLetDefinition(
        _ definition: LetDefinition,
        _ info: Void
    ) -> DisplayableNode {
        let displayExpr = definition.expression.acceptVisitor(self)
        
        return DisplayableNode(id: definition.id, name: "Let Definition", description: definition.name, children: [displayExpr])
    }
    
    func visitVarDefinition(
        _ definition: VarDefinition,
        _ info: Void
    ) -> DisplayableNode {
        let displayExpr = definition.expression.acceptVisitor(self)
        
        return DisplayableNode(id: definition.id, name: "Var Definition", description: definition.name, children: [displayExpr])
    }
    
    func visitFuncDefinition(
        _ definition: FuncDefinition,
        _ info: Void
    ) -> DisplayableNode {
        var displayExpr: [DisplayableNode] = []
        definition.body.forEach { node in
            displayExpr.append(node.acceptVisitor(self))
        }
        
        return DisplayableNode(id: definition.id, name: "Func Definition", description: definition.name, children: displayExpr)
    }
    
    func visitFuncApplication(
        _ expression: FuncApplication,
        _ info: Void
    ) -> DisplayableNode {
        var displayExpr: [DisplayableNode] = []
        expression.arguments.forEach { node in
            displayExpr.append(node.acceptVisitor(self))
        }
        
        return DisplayableNode(id: expression.id, name: "Func Application", description: expression.name, children: displayExpr)
    }
    
    func visitIfStatement(
        _ statement: IfStatement,
        _ info: Void
    ) -> DisplayableNode {
        var displayExpr: [DisplayableNode] = []
        statement.thenBranch.forEach { node in
            displayExpr.append(node.acceptVisitor(self))
        }
        statement.elseBranch?.forEach { node in
            displayExpr.append(node.acceptVisitor(self))
        }
        
        return DisplayableNode(id: statement.id, name: "If Statement", description: "do condition!", children: displayExpr)
    }
    
    func visitReturnStatement(
        _ statement: ReturnStatement,
        _ info: Void
    ) -> DisplayableNode {
        let displayExpr = statement.expression.acceptVisitor(self)
        
        return DisplayableNode(id: statement.id, name: "Return Statement", description: "", children: [displayExpr])
    }
    
    func visitAssignmentStatement(
        _ statement: AssignmentStatement,
        _ info: Void
    ) -> DisplayableNode {
        let displayExpr = statement.expression.acceptVisitor(self)
        
        return DisplayableNode(id: statement.id, name: "Assignment Statement", description: "", children: [displayExpr])
    }
    
}
