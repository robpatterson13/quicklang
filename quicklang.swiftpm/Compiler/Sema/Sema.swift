//
//  Sema.swift
//  quicklang
//
//  Created by Rob Patterson on 11/18/25.
//

/// A single semantic analysis pass in the compiler pipeline.
///
/// Conforming types implement one phase of semantic processing (for example,
/// symbol resolution, type checking, or linearization) and operate over the AST
/// using the shared ``ASTContext``. Passes receive a ``CompilerErrorManager`` to
/// record diagnostics consistently with the rest of the toolchain.
///
/// Typical conformers:
/// - ``SymbolResolve``: validates names and scopes
/// - ``Typechecker``: assigns and validates static types
/// - ``ASTLinearize``: rewrites expressions into a linear evaluation form
///
/// Conformance Requirements:
/// - Provide a readable ``context`` for querying and recording shared semantic state.
/// - Implement ``begin(reportingTo:)`` to run the pass and emit diagnostics.
///
/// - SeeAlso: ``Sema``, ``ASTContext``, ``CompilerErrorManager``
protocol SemaPass {
    associatedtype Result
    /// The shared semantic/type context available to all passes.
    ///
    /// Passes may use the context to query types, look up symbol metadata,
    /// or share information with other passes in the pipeline.
    var context: ASTContext { get }
    
    /// Entry point for the pass.
    ///
    /// Implementations should traverse the relevant portion of the AST and
    /// report diagnostics via the provided ``CompilerErrorManager``. The pass
    /// may mutate the shared ``ASTContext`` as needed to record results that
    /// subsequent passes depend on.
    ///
    /// - Parameter reportingTo: The compiler’s error manager used to record diagnostics.
    func begin(reportingTo: CompilerErrorManager) -> Result
}

/// Orchestrates the sequence of semantic analysis passes over the AST.
///
/// ``Sema`` owns the pass ordering and constructs each pass with the shared
/// ``ASTContext``. It invokes each pass in order, forwarding the compiler’s
/// error manager so passes can emit diagnostics consistently.
///
/// Usage:
/// 1. Configure the pipeline by supplying a list of ``PassType`` values.
/// 2. Call ``begin(_:)`` with the shared context and pass list.
/// 3. Each pass is constructed and executed in its canonical order.
///
/// - Note: The pipeline ordering is determined by ``PassType`` raw values
///   (lower runs earlier). See ``PassType`` for details.
///
/// - SeeAlso: ``SemaPass``, ``ASTContext``, ``CompilerErrorManager``
final class Sema: CompilerPhase {
    /// The input to the semantic pipeline.
    ///
    /// - Parameters:
    ///   - context: The shared ``ASTContext`` used by all passes.
    ///   - passes: The list of ``PassType`` values that defines which passes to run.
    typealias InputType = (context: ASTContext, passes: [PassType])
    
    /// The successful result of running the semantic pipeline.
    ///
    /// - Note: This pipeline currently does not return a transformed AST from
    ///   ``begin(_:)``; instead, passes communicate via the shared ``ASTContext``.
    typealias SuccessfulResult = ASTContext?
    
    /// Supported semantic passes in their canonical execution order.
    ///
    /// The `rawValue` establishes scheduling priority; lower values run earlier.
    /// Use ``makePassManager(using:)`` to instantiate the concrete pass for a case.
    enum PassType: Int, CaseIterable {
        /// Name resolution and scope validation.
        case symbolResolve = 0
        /// Type inference and checking.
        case typecheck = 1
        /// Expression linearization for statement-like evaluation order.
        case linearize = 2
        
        /// Creates the concrete pass for this type using the provided context.
        ///
        /// - Parameter context: The shared ``ASTContext`` passed to the pass initializer.
        /// - Returns: A concrete instance conforming to ``SemaPass``.
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
    
    /// The configured pass pipeline.
    ///
    /// - Important: The pipeline is sorted by ``PassType`` raw values before execution.
    private var passes: [PassType] = []
    
    static let defaultPasses = PassType.allCases
    
    /// Compiler driver that supplies diagnostic sinks.
    ///
    /// The error manager is forwarded to each pass so diagnostics are emitted
    /// consistently and can be collected centrally by the driver.
    private let errorManager: CompilerErrorManager
    
    /// Creates a semantic analyzer with the given driver.
    ///
    /// - Parameter errorManager: The compiler’s error manager used for diagnostics.
    init(
        errorManager: CompilerErrorManager
    ) {
        self.errorManager = errorManager
    }
    
    /// Sorts the pass pipeline by their declared execution order.
    ///
    /// - Note: Lower ``PassType`` raw values are scheduled earlier.
    private func sortPasses() {
        passes.sort { a, b in
            a.rawValue < b.rawValue
        }
    }
    
    /// Adds passes to the pipeline and re-sorts by execution order.
    ///
    /// - Parameter passes: The additional ``PassType`` values to append.
    private func addPasses(_ passes: [PassType]) {
        self.passes.append(contentsOf: passes)
        sortPasses()
    }
    
    /// Runs all configured semantic passes in order.
    ///
    /// Each pass is constructed with the shared ``ASTContext`` and reports diagnostics
    /// to the driver’s ``CompilerErrorManager``.
    ///
    /// - Parameter input: The tuple containing the shared context and pass list.
    /// - Returns: The pipeline result. Currently returns `.failure` as a placeholder.
    ///
    /// - Important: This implementation forwards the error manager to each pass and
    ///   executes them in canonical order. Adjust return behavior when integrating
    ///   with the rest of the driver pipeline.
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
