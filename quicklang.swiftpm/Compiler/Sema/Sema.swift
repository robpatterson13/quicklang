//
//  Sema.swift
//  quicklang
//
//  Created by Rob Patterson on 11/18/25.
//

protocol SemaPass {
    associatedtype Result
    var context: ASTContext { get }
    
    func begin(reportingTo: CompilerErrorManager) -> Result
}

final class Sema: CompilerPhase {
    typealias InputType = (context: ASTContext, passes: [PassType])
    
    typealias SuccessfulResult = ASTContext?
    
    enum PassType: Int, CaseIterable {
        case symbolResolve = 0
        case typecheck = 1
        case linearize = 2
        
        fileprivate func makePassManager(using context: ASTContext) -> any SemaPass {
            switch self {
            case .linearize:
                return ASTLinearize(context: context)
            case .symbolResolve:
                return SymbolResolve(context: context)
            case .typecheck:
                return Typechecker(context: context)
            }
        }
    }
    
    private var passes: [PassType] = []
    
    static let defaultPasses = PassType.allCases
    
    private let errorManager: CompilerErrorManager
    
    init(
        errorManager: CompilerErrorManager
    ) {
        self.errorManager = errorManager
    }
    
    private func sortPasses() {
        passes.sort { a, b in
            a.rawValue < b.rawValue
        }
    }
    
    private func addPasses(_ passes: [PassType]) {
        self.passes.append(contentsOf: passes)
        sortPasses()
    }
    
    func begin(_ input: InputType) -> PhaseResult<Sema> {
        self.passes = input.passes
        let context = input.context
        
        var passResult: Any? = nil
        passes.forEach { passType in
            let pass: any SemaPass
            if let newContext = passResult as? ASTContext {
                pass = passType.makePassManager(using: newContext)
                passResult = nil
            } else {
                pass = passType.makePassManager(using: context)
            }
            
            let result = pass.begin(reportingTo: errorManager)
            if let result = result as? ASTContext {
                passResult = result
            }
            
            if errorManager.hasErrors {
                return
            }
        }
        
        if errorManager.hasErrors {
            return .failure
        }
        
        let finalResult = passResult as? ASTContext
        return .success(result: context)
    }
}

struct SemaError: CompilerPhaseError {
    var location: SourceCodeLocation
    var message: String
    
}
