//
//  Compiler.swift
//  swift-student-challenge-2025
//
//  Created by Rob Patterson on 2/4/25.
//

/// A single, composable phase in the compiler pipeline.
///
/// Conforming types represent discrete stages such as lexing, parsing, or semantic analysis.
/// Each phase:
/// - Declares the type of its input and successful result via the associated types
///   ``InputType`` and ``SuccessfulResult``.
/// - Is constructed with a shared ``CompilerErrorManager`` to report diagnostics.
/// - Implements ``begin(_:)`` to run to completion and return a ``PhaseResult``.
///
/// Example:
/// ```swift
/// struct MyPhase: CompilerPhase {
///     typealias InputType = String
///     typealias SuccessfulResult = Int
///
///     private let errorManager: CompilerErrorManager
///
///     init(errorManager: CompilerErrorManager) {
///         self.errorManager = errorManager
///     }
///
///     func begin(_ input: String) -> PhaseResult<MyPhase> {
///         // Do work, emit diagnostics via errorManager as needed...
///         return .success(result: 42)
///     }
/// }
/// ```
///
/// - SeeAlso: ``PhaseResult``, ``Compiler``, ``CompilerErrorManager``
protocol CompilerPhase {
    /// The input payload required to start this phase.
    associatedtype InputType
    /// The successful result value produced by this phase.
    associatedtype SuccessfulResult
    
    /// Creates a new phase instance.
    ///
    /// Phases receive the shared ``CompilerErrorManager`` so they can emit diagnostics
    /// that the driver can later surface to the user interface.
    ///
    /// - Parameter errorManager: The shared error manager used for diagnostics.
    init(errorManager: CompilerErrorManager)
    
    /// Starts the phase and returns a result indicating success or failure.
    ///
    /// Implementations should perform the phase’s work synchronously and report any
    /// diagnostics to the shared ``CompilerErrorManager``. On success, the phase returns
    /// the computed result; otherwise, it returns `.failure`.
    ///
    /// - Parameter input: The input payload for this phase.
    /// - Returns: A ``PhaseResult`` for this phase type.
    func begin(_ input: InputType) -> PhaseResult<Self>
}

/// The outcome of running a compiler phase.
///
/// A phase either completes successfully and returns its ``SuccessfulResult``,
/// or it fails (after emitting diagnostics).
///
/// - Note: Failure does not necessarily imply an unrecoverable error for the entire
///   pipeline; the driver may choose to continue or stop based on the phase contract.
enum PhaseResult<Phase: CompilerPhase> {
    /// The phase completed successfully with the given result.
    case success(result: Phase.SuccessfulResult)
    /// The phase failed (diagnostics should already be recorded).
    case failure
}

/// Bridges the compiler and a UI host.
///
/// ``CompilerToUIBridge`` provides a minimal interface for sending source to the
/// compiler and for forwarding diagnostics back to the UI layer. It holds a weak
/// reference to the ``Compiler`` driver to avoid retain cycles.
///
/// Responsibilities:
/// - Forward source code to the driver
/// - Relay diagnostics collected by ``CompilerErrorManager``
///
/// - Important: This bridge is intentionally thin; expand it with richer messaging
///   and progress reporting as the UI requirements grow.
class CompilerToUIBridge {
    private weak var driver: Compiler?
    weak var viewModel: ProgramEditorViewModel?
    
    /// Creates a new bridge.
    ///
    /// - Parameter driver: The compiler driver to forward requests to. Defaults to `nil`.
    init(driver: Compiler? = nil) {
        self.driver = driver
    }
    
    func addDriver(_ driver: Compiler) {
        if self.driver == nil {
            self.driver = driver
        }
    }
    
    /// Sends source code to the compiler driver to begin compilation.
    ///
    /// - Parameter source: The full source input to compile.
    func sendSourceCode(_ source: String) {
        driver?.startDriver(source)
    }
    
    /// Reports errors collected by the compiler to the UI.
    ///
    /// - Parameter errorManager: The shared error manager containing diagnostics.
    func reportErrors(from errorManager: CompilerErrorManager) {
        let messages = errorManager.dumpErrors(using: DefaultErrorFormatter())
        viewModel?.receiveErrorMessages(messages)
    }
    
    func sendDisplayNodes(from tree: ASTContext) {
        let display = ConvertToDisplayableNode.shared.begin(tree.tree)
        viewModel?.receiveDisplayTree(display)
    }
    
    func clearErrors() {
        viewModel?.errors = []
    }
}

/// The top-level compiler driver that coordinates the pipeline.
///
/// ``Compiler`` wires together the major phases: lexing, parsing, and semantics (Sema).
/// It owns a single shared ``CompilerErrorManager`` and forwards it to all phases.
/// The driver:
/// - Accepts source code from the UI bridge
/// - Runs phases in order (lex → parse → sema)
/// - Forwards diagnostics back to the UI via ``CompilerToUIBridge``
///
/// Workflow:
/// 1. Source arrives via ``CompilerToUIBridge/sendSourceCode(_:)``
/// 2. ``startDriver(_:)`` invokes lexing, parsing, and semantic analysis
/// 3. On any failure, diagnostics are reported and the pipeline stops
///
/// - Note: The example currently bootstraps with a hardcoded program in `init()`.
///   Replace with UI-provided source for interactive usage.
class Compiler {
    
    /// Bridge for communicating with the UI layer.
    let bridge: CompilerToUIBridge
    
    /// Lazily constructed pipeline phases.
    private var lexer: Lexer?
    private var parser: Parser?
    private var sema: Sema?
    
    /// Shared diagnostic manager for all phases.
    private let errorManager: CompilerErrorManager
    
    /// Creates a new compiler driver and kicks off a demo compilation.
    ///
    /// - Important: This initializer seeds the driver with a sample program and
    ///   immediately starts compilation. For production use, construct the driver
    ///   and call ``CompilerToUIBridge/sendSourceCode(_:)`` instead.
    init(bridge: CompilerToUIBridge) {
        errorManager = CompilerErrorManager()
        self.bridge = bridge
    }

    /// Starts the end-to-end compilation pipeline for the given source.
    ///
    /// This method orchestrates lexing, parsing, and semantic analysis in order.
    /// On failure of any phase, diagnostics are reported to the UI and the pipeline stops.
    ///
    /// - Parameter source: The source code to compile.
    fileprivate func startDriver(_ source: Lexer.SourceCode) {
        errorManager.clearErrors()
        bridge.clearErrors()
        resetPhases()
        
        let lexResult: Lexer.SuccessfulResult
        switch startLexing(source) {
        case .success(result: let result):
            lexResult = result
        case .failure:
            onFailure()
            return
        }
        
        let parseResult: Parser.SuccessfulResult
        switch startParsing(lexResult) {
        case .success(result: let result):
            print(result.tree)
            parseResult = result
        case .failure:
            onFailure()
            return
        }
        
        bridge.sendDisplayNodes(from: parseResult)
        
//        switch startSema(passes: Sema.defaultPasses, parseResult) {
//        case .success:
//            break
//        case .failure:
//            onFailure()
//            return
//        }
    }
    
    /// Runs the lexing phase, constructing it on first use.
    ///
    /// - Parameter source: The raw source code.
    /// - Returns: The ``PhaseResult`` for ``Lexer``.
    private func startLexing(_ source: Lexer.SourceCode) -> PhaseResult<Lexer> {
        if lexer == nil {
            lexer = Lexer(errorManager: errorManager)
        }
        
        return lexer!.begin(source)
    }
    
    /// Runs the parsing phase, constructing it on first use.
    ///
    /// - Parameter tokens: The token stream produced by the lexer.
    /// - Returns: The ``PhaseResult`` for ``Parser``.
    private func startParsing(_ tokens: Lexer.SuccessfulResult) -> PhaseResult<Parser> {
        if parser == nil {
            parser = Parser(errorManager: errorManager)
        }
        
        return parser!.begin(tokens)
    }
    
    /// Runs the semantic analysis pipeline, constructing it on first use.
    ///
    /// - Parameter tree: The parsed AST produced by the parser.
    /// - Returns: The ``PhaseResult`` for ``Sema``.
    ///
    /// - Note: This placeholder currently returns `.failure`. Integrate with
    ///   ``Sema`` by constructing a pass list and invoking its ``Sema.begin(_:)``.
    private func startSema(passes: [Sema.PassType], _ tree: Parser.SuccessfulResult) -> PhaseResult<Sema> {
        if sema == nil {
            sema = Sema(errorManager: errorManager)
        }
        
        let input: Sema.InputType = (context: tree, passes: passes)
        return sema!.begin(input)
    }
    
    private func resetPhases() {
        lexer = nil
        parser = nil
        sema = nil
    }
    
    private func onFailure() {
        resetPhases()
        bridge.reportErrors(from: errorManager)
    }
}
//    let value = 10 + true * 8 + i(16 * blue + another) - hello;

//
//        let program =
//        """
//        func abc(param1: Int) -> Bool {
//        if (true) {
//            return true;
//        } else {
//            return true;
//        }
//        }
//        func i(abcdce: Bool, hello: Int) -> Int {
//        if (true) {
//            return true;
//        } else {
//            return false + i();
//        }
//        }
//        let value = true;
//        var value2 = true;
//        abc(value);
//        """
//
//        startDriver(program)
