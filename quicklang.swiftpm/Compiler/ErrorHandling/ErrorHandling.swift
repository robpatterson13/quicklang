//
//  ErrorHandling.swift
//  quicklang
//
//  Created by Rob Patterson on 11/19/25.
//

class CompilerErrorManager {
    
    private var errors: [any CompilerPhaseError] = []
    
    var hasErrors: Bool {
        !errors.isEmpty
    }
    
    func addError(_ error: any CompilerPhaseError) {
        errors.append(error)
    }
    
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

protocol CompilerErrorFormatter {
    associatedtype CompilerErrorFormatterOutput
    
    func format(_ error: any CompilerPhaseError) -> CompilerErrorFormatterOutput
}

class DefaultErrorFormatter: CompilerErrorFormatter {
    
    func format(_ error: any CompilerPhaseError) -> String {
        return error.message
    }
}

protocol CompilerPhaseError {
    var location: SourceCodeLocation { get }
    var message: String { get }
    
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
