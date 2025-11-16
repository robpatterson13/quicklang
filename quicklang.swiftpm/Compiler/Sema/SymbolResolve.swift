////
////  SymbolResolve.swift
////  quicklang
////
////  Created by Rob Patterson on 11/15/25.
////
//
//class SymbolResolve: ASTTransformer {
//    
//    typealias TransformerInfo = ()
//    
//    let context: ASTContext
//    
//    func visitIdentifierExpression(
//        _ expression: IdentifierExpression,
//        _ finished: @escaping OnTransformEnd<IdentifierExpression>
//    ) {
//        finished(expression, ())
//    }
//    
//    func visitBooleanExpression(_ expression: BooleanExpression, _ finished: @escaping OnTransformEnd<BooleanExpression>) {
//        finished(expression, ())
//    }
//    
//    func visitNumberExpression(_ expression: NumberExpression, _ finished: @escaping OnTransformEnd<NumberExpression>) {
//        finished(expression, ())
//    }
//    
//    func visitUnaryOperation(_ operation: UnaryOperation, _ finished: @escaping OnTransformEnd<UnaryOperation>) {
//        finished(operation, ())
//    }
//    
//    func visitBinaryOperation(_ operation: BinaryOperation, _ finished: @escaping OnTransformEnd<BinaryOperation>) {
//        <#code#>
//    }
//    
//    func visitLetDefinition(_ definition: LetDefinition, _ finished: @escaping OnTransformEnd<LetDefinition>) {
//        <#code#>
//    }
//    
//    func visitVarDefinition(_ definition: VarDefinition, _ finished: @escaping OnTransformEnd<VarDefinition>) {
//        <#code#>
//    }
//    
//    func visitFuncDefinition(_ definition: FuncDefinition, _ finished: @escaping OnTransformEnd<FuncDefinition>) {
//        <#code#>
//    }
//    
//    func visitFuncApplication(_ expression: FuncApplication, _ finished: @escaping OnTransformEnd<FuncApplication>) {
//        <#code#>
//    }
//    
//    func visitIfStatement(_ statement: IfStatement, _ finished: @escaping OnTransformEnd<IfStatement>) {
//        <#code#>
//    }
//    
//    func visitReturnStatement(_ statement: ReturnStatement, _ finished: @escaping OnTransformEnd<ReturnStatement>) {
//        <#code#>
//    }
//    
//}
