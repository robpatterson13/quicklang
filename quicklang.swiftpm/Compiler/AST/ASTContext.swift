//
//  ASTContext.swift
//  quicklang
//
//  Created by Rob Patterson on 11/15/25.
//

import Foundation

/// Holds contextual information for semantic analysis and type queries.
class ASTContext {
    
    struct ScopeInfo {
        let inScope: [String]
    }
    
    /// Metadata for a declared symbol.
    struct SymbolInfo {
        /// The AST node identifier that introduced this symbol.
        let id: UUID
        /// Function parameters when this symbol represents a function.
        let params: [FuncDefinition.Parameter]?
        
        let scopeInfo: ScopeInfo
    }
    
    /// Cache of expression types keyed by expression UUID.
    private var types = [UUID: TypeName]()
    
    /// Global symbol table keyed by symbol name.
    private var symbols = [String: SymbolInfo]()
    
    /// Returns the static type of an expression.
    ///
    /// - Parameter expr: The expression to query.
    func getType(of expr: any ExpressionNode) -> TypeName {
        if let type = types[expr.id] {
            return type
        }
        
        return askForType(of: expr)
    }
    
    /// Returns the formal parameter list for a function symbol.
    ///
    /// - Parameter id: The function name to look up.
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
    
    /// Resolves the type of an identifier expression.
    ///
    /// - Parameter expr: The identifier expression to resolve.
    func queryTypeOfIdentifierExpression(_ expr: IdentifierExpression) {
        guard let varDefInfo = symbols[expr.name] else {
            fatalError("Symbol table does not contain identifier")
        }
        
        types[expr.id] = types[varDefInfo.id]
    }
    
    /// Resolves the type of a boolean literal expression.
    ///
    /// - Parameter expr: The boolean expression to resolve.
    func queryTypeOfBooleanExpression(_ expr: BooleanExpression) {
        types[expr.id] = .Bool
    }
    
    /// Resolves the type of a numeric literal expression.
    ///
    /// - Parameter expr: The number expression to resolve.
    func queryTypeOfNumberExpression(_ expr: NumberExpression) {
        types[expr.id] = .Int
    }
    
    /// Resolves the result type of a function application.
    ///
    /// - Parameter expr: The function application expression.
    func queryTypeOfFuncApplication(_ expr: FuncApplication) {
        guard let funcDefInfo = symbols[expr.name] else {
            fatalError("Symbol table does not contain func")
        }
        
        types[expr.id] = types[funcDefInfo.id]
    }
    
    /// Resolves the type of a unary operation.
    ///
    /// - Parameter expr: The unary operation to resolve.
    func queryTypeOfUnaryOperation(_ expr: UnaryOperation) {
        switch expr.op {
        case .not, .neg:
            types[expr.id] = .Bool
        }
    }
    
    /// Resolves the type of a binary operation.
    ///
    /// - Parameter expr: The binary operation to resolve.
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
    
    /// Requests an expression to compute and cache its type.
    ///
    /// - Parameter expr: The expression to query.
    /// - Returns: The resolved type.
    private func askForType(of expr: any ExpressionNode) -> TypeName {
        expr.acceptTypeQuery(self)
        return types[expr.id]! // safe to force, added to table in line above
    }
}
