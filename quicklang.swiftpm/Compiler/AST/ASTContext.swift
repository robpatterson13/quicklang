//
//  ASTContext.swift
//  quicklang
//
//  Created by Rob Patterson on 11/15/25.
//

import Foundation

class IsGlobalSymbol: ASTVisitor {
    typealias VisitorInfo = Void
    typealias VisitorResult = ASTScope.IntroducedBinding?
    
    static var shared: IsGlobalSymbol {
        .init()
    }
    
    private init() {}
    
    func visitIdentifierExpression(
        _ expression: IdentifierExpression,
        _ info: Void
    ) -> ASTScope.IntroducedBinding? {
        nil
    }
    
    func visitBooleanExpression(
        _ expression: BooleanExpression,
        _ info: Void
    ) -> ASTScope.IntroducedBinding? {
        nil
    }
    
    func visitNumberExpression(
        _ expression: NumberExpression,
        _ info: Void
    ) -> ASTScope.IntroducedBinding? {
        nil
    }
    
    func visitUnaryOperation(
        _ operation: UnaryOperation,
        _ info: Void
    ) -> ASTScope.IntroducedBinding? {
        nil
    }
    
    func visitBinaryOperation(
        _ operation: BinaryOperation,
        _ info: Void
    ) -> ASTScope.IntroducedBinding? {
        nil
    }
    
    func visitLetDefinition(
        _ definition: LetDefinition,
        _ info: Void
    ) -> ASTScope.IntroducedBinding? {
        .definition(definition)
    }
    
    func visitVarDefinition(
        _ definition: VarDefinition,
        _ info: Void
    ) -> ASTScope.IntroducedBinding? {
        .definition(definition)
    }
    
    func visitFuncDefinition(
        _ definition: FuncDefinition,
        _ info: Void
    ) -> ASTScope.IntroducedBinding? {
        .function(definition)
    }
    
    func visitFuncApplication(
        _ expression: FuncApplication,
        _ info: Void
    ) -> ASTScope.IntroducedBinding? {
        nil
    }
    
    func visitIfStatement(
        _ statement: IfStatement,
        _ info: Void
    ) -> ASTScope.IntroducedBinding? {
        nil
    }
    
    func visitReturnStatement(
        _ statement: ReturnStatement,
        _ info: Void
    ) -> ASTScope.IntroducedBinding? {
        nil
    }
    
    func visitAssignmentStatement(
        _ statement: AssignmentStatement,
        _ info: Void
    ) -> ASTScope.IntroducedBinding? {
        nil
    }
}

class ASTContext {
    
    var tree: TopLevel
    
    var symbols: [String: TypeName] = [:]
    
    init(tree: TopLevel = TopLevel(sections: [])) {
        self.tree = tree
    }
    
    func allGlobals(excluding: (any TopLevelNode)? = nil) -> [ASTScope.IntroducedBinding] {
        var topLevelNodes = [ASTScope.IntroducedBinding]()
        
        tree.sections.forEach { node in
            if let result = node.acceptVisitor(IsGlobalSymbol.shared) {
                if let excluding, excluding.id == node.id {
                    return
                }
                
                topLevelNodes.append(result)
            }
        }
        
        return topLevelNodes
    }
    
    func getTypeOf(symbol: String) -> TypeName? {
        symbols[symbol]
    }
    
    func assignTypeOf(_ type: TypeName, to symbol: String) {
        symbols[symbol] = type
    }
}

