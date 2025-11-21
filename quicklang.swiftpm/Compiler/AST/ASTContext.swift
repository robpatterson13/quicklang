//
//  ASTContext.swift
//  quicklang
//
//  Created by Rob Patterson on 11/15/25.
//

import Foundation

class ASTContext {
    
    struct ScopeInfo {
        let inScope: [String]
    }
    
    struct SymbolInfo {
        let id: UUID?
        let type: TypeName?
        let scopeInfo: ScopeInfo?
        
        typealias Parameters = [FuncDefinition.Parameter]
        let params: Parameters?
        
        init(
            id: UUID? = nil,
            type: TypeName? = nil,
            scopeInfo: ScopeInfo? = nil,
            params: Parameters? = nil
        ) {
            self.id = id
            self.type = type
            self.scopeInfo = scopeInfo
            self.params = params
        }
        
        func makeNew(
            id: UUID? = nil,
            type: TypeName? = nil,
            scopeInfo: ScopeInfo? = nil,
            params: Parameters? = nil
        ) -> SymbolInfo {
            let newId = id == nil ? self.id : id!
            let newType = type == nil ? self.type : type!
            let newScopeInfo = scopeInfo == nil ? self.scopeInfo : scopeInfo!
            let params = params == nil ? self.params : params!
            
            return SymbolInfo(id: newId, type: newType, scopeInfo: newScopeInfo, params: params)
        }
    }
    
    private var types = [UUID: TypeName]()
    private var symbols = [String: SymbolInfo]()
    
    var tree: TopLevel
    
    init(tree: TopLevel = TopLevel(sections: [])) {
        self.tree = tree
    }
    
    func getType(of expr: any ExpressionNode) -> TypeName {
        if let type = types[expr.id] {
            return type
        }
        
        return askForType(of: expr)
    }
    
    func getFuncParams(of id: String) -> [FuncDefinition.Parameter] {
        guard let params = symbols[id]?.params else {
            fatalError("No func params available for \(id)")
        }
        
        return params
    }
    
    func getScopeInfo(of id: String) -> ScopeInfo {
        guard let info = symbols[id]?.scopeInfo else {
            fatalError("No func params available for \(id)")
        }
        
        return info
    }
    
    func assignTypeOf(_ type: TypeName, to symbol: String) {
        let symbolInfo = symbols[symbol]
        if let symbolInfo {
            symbols[symbol] = symbolInfo.makeNew(type: type)
        } else {
            symbols[symbol] = SymbolInfo(type: type)
        }
    }
    
    func addParamsTo(func symbol: String, _ params: [FuncDefinition.Parameter]) {
        let symbolInfo = symbols[symbol]
        if let symbolInfo {
            symbols[symbol] = symbolInfo.makeNew(params: params)
        } else {
            symbols[symbol] = SymbolInfo(params: params)
        }
    }
    
    func queryTypeOfIdentifierExpression(_ expr: IdentifierExpression) {
        guard let varDefInfo = symbols[expr.name] else {
            fatalError("Symbol table does not contain identifier")
        }
    }
    
    func queryTypeOfBooleanExpression(_ expr: BooleanExpression) {
        types[expr.id] = .Bool
    }
    
    func queryTypeOfNumberExpression(_ expr: NumberExpression) {
        types[expr.id] = .Int
    }
    
    func queryTypeOfFuncApplication(_ expr: FuncApplication) {
        guard let funcDefInfo = symbols[expr.name] else {
            fatalError("Symbol table does not contain func")
        }
        
        guard let type = funcDefInfo.type else {
            fatalError("Symbol table must have type for function declaration")
        }
        
        switch type {
        case .Arrow(_, to: let to):
            types[expr.id] = to
        default:
            fatalError("Functions must have arrow types")
        }
    }
    
    func queryTypeOfUnaryOperation(_ expr: UnaryOperation) {
        switch expr.op {
        case .not, .neg:
            types[expr.id] = .Bool
        }
    }
    
    func queryTypeOfBinaryOperation(_ expr: BinaryOperation) {
        switch expr.op {
        case .plus, .minus, .times:
            types[expr.id] = .Int
        case .and, .or:
            types[expr.id] = .Bool
        }
    }
    
    func addSymbolInfo(_ info: SymbolInfo, for id: String) {
        symbols[id] = info
    }
    
    func getGlobalSymbols(excluding: String? = nil) -> [String] {
        var globals: [String] = []
        tree.sections.forEach { node in
            node.acceptUpwardTransformer(SymbolGrabber.shared) { _, bindings in
                if let excluding, bindings.contains(excluding) {
                    globals.append(contentsOf: bindings.filter({ $0 != excluding }))
                    return
                }
                
                globals.append(contentsOf: bindings)
            }
        }
        
        return globals
    }
    
    private func askForType(of expr: any ExpressionNode) -> TypeName {
        expr.acceptTypeQuery(self)
        return types[expr.id]!
    }
}

