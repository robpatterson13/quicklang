//
//  ErrorHandling.swift
//  quicklang
//
//  Created by Rob Patterson on 11/19/25.
//

/// Central aggregator for compiler-phase errors.
///
/// Stores errors emitted by any phase (lexer, parser, sema, etc.) as values
/// conforming to `CompilerPhaseError`. Consumers can later render them using
/// a pluggable `CompilerErrorFormatter`.
class CompilerErrorManager {
    
    /// Collected diagnostics in emission order.
    private var errors: [any CompilerPhaseError] = []
    
    var hasErrors: Bool {
        !errors.isEmpty
    }
    
    /// Records a new compiler-phase error.
    /// - Parameter error: Any value conforming to `CompilerPhaseError`.
    func addError(_ error: any CompilerPhaseError) {
        errors.append(error)
    }
    
    /// Produces formatted representations for all collected errors.
    ///
    /// - Parameter formatter: A formatter that knows how to turn a `CompilerPhaseError`
    ///   into the desired output type (e.g., `String`, rich text, JSON).
    /// - Returns: An array of formatter-specific outputs, preserving error order.
    func dumpErrors<F: CompilerErrorFormatter>(
        using formatter: F
    ) -> [F.CompilerErrorFormatterOutput] {
        let dumped = errors.map { $0.getDescription(from: formatter) }
        clearErrors()
        return dumped
    }
    
    func clearErrors() {
        errors = []
    }
}

/// Strategy object that renders a `CompilerPhaseError` to a specific output.
///
/// Implementations can produce plain strings, attributed strings, structured JSON,
/// or any other output needed by the host application.
protocol CompilerErrorFormatter {
    associatedtype CompilerErrorFormatterOutput
    
    /// Formats a single compiler-phase error.
    func format(_ error: any CompilerPhaseError) -> CompilerErrorFormatterOutput
}

class DefaultErrorFormatter: CompilerErrorFormatter {
    
    func format(_ error: any CompilerPhaseError) -> String {
        return error.message
    }
}

/// Common interface for all compiler-phase diagnostics.
///
/// Phases should define concrete error types conforming to this protocol
/// (e.g., `ParserError`, `TypeError`) and provide a source location and message.
protocol CompilerPhaseError {
    /// Source span for the diagnostic (file/line/column range).
    var location: SourceCodeLocation { get }
    /// Human-readable message describing the issue.
    var message: String { get }
    
    /// Returns a formatted description using the given formatter.
    func getDescription<F: CompilerErrorFormatter>(from formatter: F) -> F.CompilerErrorFormatterOutput
}

extension CompilerPhaseError {
    func getDescription<F: CompilerErrorFormatter>(from formatter: F) -> F.CompilerErrorFormatterOutput {
        return formatter.format(self)
    }
}

protocol CompilerPhaseErrorType {
    associatedtype PhaseErrorInfo
    func buildInfo(at location: SourceCodeLocation) -> PhaseErrorInfo
}
    
protocol CompilerPhaseErrorInfo {
    associatedtype PhaseErrorCreator
    associatedtype PhaseError
    func getError(from manager: PhaseErrorCreator) -> PhaseError
}
