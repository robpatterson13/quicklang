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

class ConvertToDisplayableNode: ASTUpwardTransformer {
    typealias TransformerInfo = DisplayableNode
    
    static var shared: ConvertToDisplayableNode {
        ConvertToDisplayableNode()
    }
    
    func begin(_ tree: TopLevel) -> [DisplayableNode] {
        var display: [DisplayableNode] = []
        
        tree.sections.forEach { node in
            node.acceptUpwardTransformer(self) { _, displays in
                display.append(displays)
            }
        }
        
        return display
    }
    
    func visitIdentifierExpression(
        _ expression: IdentifierExpression,
        _ finished: @escaping OnTransformEnd<IdentifierExpression>
    ) {
        let display = DisplayableNode(id: expression.id, name: "Identifier", description: expression.name)
        finished(expression, display)
    }
    
    func visitBooleanExpression(
        _ expression: BooleanExpression,
        _ finished: @escaping OnTransformEnd<BooleanExpression>
    ) {
        let display = DisplayableNode(id: expression.id, name: "Boolean", description: String(expression.value))
        finished(expression, display)
    }
    
    func visitNumberExpression(
        _ expression: NumberExpression,
        _ finished: @escaping OnTransformEnd<NumberExpression>
    ) {
        let display = DisplayableNode(id: expression.id, name: "Number", description: String(expression.value))
        finished(expression, display)
    }
    
    func visitUnaryOperation(
        _ operation: UnaryOperation,
        _ finished: @escaping OnTransformEnd<UnaryOperation>
    ) {
        var displayExpr: DisplayableNode? = nil
        operation.expression.acceptUpwardTransformer(self) { _, display in
            displayExpr = display
        }
        
        let display = DisplayableNode(id: operation.id, name: "Unary Operation", description: "op here", children: [displayExpr!])
        finished(operation, display)
    }
    
    func visitBinaryOperation(
        _ operation: BinaryOperation,
        _ finished: @escaping OnTransformEnd<BinaryOperation>
    ) {
        var displayLhs: DisplayableNode? = nil
        operation.lhs.acceptUpwardTransformer(self) { _, lhs in
            displayLhs = lhs
        }
        var displayRhs: DisplayableNode? = nil
        operation.rhs.acceptUpwardTransformer(self) { _, rhs in
            displayRhs = rhs
        }
        
        let display = DisplayableNode(id: operation.id, name: "Binary Operation", description: "op here", children: [displayLhs!, displayRhs!])
        finished(operation, display)
    }
    
    func visitLetDefinition(
        _ definition: LetDefinition,
        _ finished: @escaping OnTransformEnd<LetDefinition>
    ) {
        var displayExpr: DisplayableNode? = nil
        definition.expression.acceptUpwardTransformer(self) { _, expr in
            displayExpr = expr
        }
        
        let display = DisplayableNode(id: definition.id, name: "Let Definition", description: definition.name, children: [displayExpr!])
        finished(definition, display)
    }
    
    func visitVarDefinition(
        _ definition: VarDefinition,
        _ finished: @escaping OnTransformEnd<VarDefinition>
    ) {
        var displayExpr: DisplayableNode? = nil
        definition.expression.acceptUpwardTransformer(self) { _, expr in
            displayExpr = expr
        }
        
        let display = DisplayableNode(id: definition.id, name: "Var Definition", description: definition.name, children: [displayExpr!])
        finished(definition, display)
    }
    
    func visitFuncDefinition(
        _ definition: FuncDefinition,
        _ finished: @escaping OnTransformEnd<FuncDefinition>
    ) {
        var displayExpr: [DisplayableNode] = []
        definition.body.forEach { node in
            node.acceptUpwardTransformer(self) { _, part in
                displayExpr.append(part)
            }
        }
        
        let display = DisplayableNode(id: definition.id, name: "Func Definition", description: definition.name, children: displayExpr)
        finished(definition, display)
    }
    
    func visitFuncApplication(
        _ expression: FuncApplication,
        _ finished: @escaping OnTransformEnd<FuncApplication>
    ) {
        var displayExpr: [DisplayableNode] = []
        expression.arguments.forEach { node in
            node.acceptUpwardTransformer(self) { _, part in
                displayExpr.append(part)
            }
        }
        
        let display = DisplayableNode(id: expression.id, name: "Func Application", description: expression.name, children: displayExpr)
        finished(expression, display)
    }
    
    func visitIfStatement(
        _ statement: IfStatement,
        _ finished: @escaping OnTransformEnd<IfStatement>
    ) {
        var displayExpr: [DisplayableNode] = []
        statement.thenBranch.forEach { node in
            node.acceptUpwardTransformer(self) { _, part in
                displayExpr.append(part)
            }
        }
        statement.elseBranch?.forEach { node in
            node.acceptUpwardTransformer(self) { _, part in
                displayExpr.append(part)
            }
        }
        
        let display = DisplayableNode(id: statement.id, name: "If Statement", description: "do condition!", children: displayExpr)
        finished(statement, display)
    }
    
    func visitReturnStatement(
        _ statement: ReturnStatement,
        _ finished: @escaping OnTransformEnd<ReturnStatement>
    ) {
        var displayExpr: DisplayableNode?
        statement.expression.acceptUpwardTransformer(self) { _, part in
            displayExpr = part
        }
        
        let display = DisplayableNode(id: statement.id, name: "Return Statement", description: "", children: [displayExpr!])
        finished(statement, display)
    }
    
    func visitAssignmentStatement(
        _ statement: AssignmentStatement,
        _ finished: @escaping OnTransformEnd<AssignmentStatement>)
    {
        var displayExpr: DisplayableNode?
        statement.expression.acceptUpwardTransformer(self) { _, part in
            displayExpr = part
        }
        
        let display = DisplayableNode(id: statement.id, name: "Assignment Statement", description: "", children: [displayExpr!])
        finished(statement, display)
    }
    
}
