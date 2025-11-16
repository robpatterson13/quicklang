//
//  ASTContext.swift
//  quicklang
//
//  Created by Rob Patterson on 11/15/25.
//

import Foundation

class ASTContext {
    
    struct SymbolInfo {
        let id: UUID
        
        let params: [FuncDefinition.Parameter]?
    }
    
    private var types = [UUID: TypeName]()
    private var symbols = [String: SymbolInfo]()
    
    func getType(of expr: any ExpressionNode) -> TypeName {
        if let type = types[expr.id] {
            return type
        }
        
        return askForType(of: expr)
    }
    
    func getFuncParams(of id: String) -> [FuncDefinition.Parameter] {
        if let type = types[expr.id] {
            return type
        }
        
        return askForType(of: expr)
    }
    
    func queryTypeOfIdentifierExpression(_ expr: IdentifierExpression) {
        guard let varDefInfo = symbols[expr.name] else {
            fatalError("Symbol table does not contain identifier")
        }
        
        types[expr.id] = types[varDefInfo.id]
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
        
        types[expr.id] = types[funcDefInfo.id]
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
    
    private func askForType(of expr: any ExpressionNode) -> TypeName {
        expr.acceptTypeQuery(self)
        return types[expr.id]! // safe to force, added to table in line above
    }
}
