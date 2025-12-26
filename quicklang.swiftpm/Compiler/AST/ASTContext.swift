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
    
    func visitDefinition(
        _ definition: DefinitionNode,
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
    
    func visitControlFlowJumpStatement(_ statement: ControlFlowJumpStatement, _ info: Void) -> ASTScope.IntroducedBinding? {
        InternalCompilerError.unreachable()
    }
    
    func visitLabelControlFlowStatement(_ statement: LabelControlFlowStatement, _ info: Void) -> ASTScope.IntroducedBinding? {
        InternalCompilerError.unreachable()
    }
}

class ASTContext {
    
    var rawTree: RawTopLevel
    
    private var _tree: TopLevel?
    var tree: TopLevel {
        if let _tree { return _tree }
        
        fatalError("The AST cannot be accessed before desugaring")
    }
    
    var symbols: [String: TypeName] = [:]
    var cfgMapping: [String: FIRBasicBlock] = [:]
    
    init(rawTree: RawTopLevel = RawTopLevel(sections: [])) {
        self.rawTree = rawTree
        self._tree = nil
    }
    
    func finishDesugaredAST(tree: TopLevel) {
        guard _tree == nil else {
            fatalError("Can only finish desugaring once; use the changing version")
        }
        
        _tree = tree
    }
    
    func changeAST(_ tree: TopLevel) {
        guard _tree != nil else {
            fatalError("Can only change AST once desugaring is done")
        }
        
        _tree = tree
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
    
    func addCFGMapping(_ name: String, _ block: FIRBasicBlock) {
        cfgMapping[name] = block
    }
    
    func blockWithName(_ name: String) -> FIRBasicBlock? {
        cfgMapping[name]
    }
    
    func getTypeOf(symbol: String) -> TypeName? {
        symbols[symbol]
    }
    
    func assignTypeOf(_ type: TypeName, to symbol: String) {
        symbols[symbol] = type
    }
}

