//
//  ASTScope.swift
//  quicklang
//
//  Created by Rob Patterson on 11/30/25.
//

import Foundation

typealias IdentifiableName = (String, UUID)

final class ASTScope {
    let isGlobal: Bool
    weak var parent: ASTScope?
    var child: ASTScope?
    var decls: [IntroducedBinding]
    
    enum IntroducedBinding {
        case funcParameter(FuncDefinition.Parameter)
        case function(FuncDefinition)
        case definition(any DefinitionNode)
        
        var identifiableName: IdentifiableName {
            switch self {
            case .funcParameter(let parameter):
                return (parameter.name, parameter.id)
            case .function(let funcDefinition):
                return (funcDefinition.name, funcDefinition.id)
            case .definition(let definitionNode):
                return (definitionNode.name, definitionNode.id)
            }
        }
        
        var scope: ASTScope? {
            switch self {
            case .funcParameter(let parameter):
                return parameter.scope
            case .function(let funcDefinition):
                return funcDefinition.scope
            case .definition(let definitionNode):
                return definitionNode.scope
            }
        }
    }
    
    init(
        isGlobal: Bool,
        parent: ASTScope? = nil,
        child: ASTScope? = nil,
        decls: [IntroducedBinding] = []
    ) {
        self.isGlobal = isGlobal
        self.parent = parent
        self.child = child
        self.decls = decls
    }
    
    func newChild(with decl: IntroducedBinding) -> ASTScope {
        let child = ASTScope(isGlobal: false, parent: self, decls: [decl])
        self.child = child
        return child
    }
    
    func addDecls(_ newDecls: [IntroducedBinding]) {
        self.decls.append(contentsOf: newDecls)
    }
    
    func inScope(_ name: String) -> Bool {
        let names = decls.map { binding in
            switch binding {
            case .funcParameter(let parameter):
                return parameter.name
            case .function(let funcDefinition):
                return funcDefinition.name
            case .definition(let definitionNode):
                return definitionNode.name
            }
        }
        
        if names.contains(name) {
            return true
        }
        
        if let parent = parent {
            return parent.inScope(name)
        }
        
        return false
    }
    
    func alreadyDeclared(_ binding: IntroducedBinding) -> Bool {
        let (name, id) = binding.identifiableName
        let namesAndIds = decls.map { $0.identifiableName }
        
        for (exisitingName, exisitingId) in namesAndIds {
            if name == exisitingName && id != exisitingId {
                return true
            }
        }
        
        return false
    }
}
