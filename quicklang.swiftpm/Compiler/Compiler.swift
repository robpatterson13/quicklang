//
//  Compiler.swift
//  swift-student-challenge-2025
//
//  Created by Rob Patterson on 2/4/25.
//

protocol CompilerPhase {
    associatedtype InputType
    associatedtype SuccessfulResult
    
    init(errorManager: CompilerErrorManager, settings: DriverSettings)
    
    func begin(_ input: InputType) -> PhaseResult<Self>
}

enum PhaseResult<Phase: CompilerPhase> {
    case success(result: Phase.SuccessfulResult)
    case failure
}

struct DriverSettings {
    var parserRecoveryStrategy: RecoveryEngine = DefaultRecovery.shared
    var onlyLexer: Bool = false
}

class Compiler {
    weak var bridge: MainBridge?
    
    private var lexer: Lexer?
    private var parser: Parser?
    private var sema: Sema?
    private var lowerToFIR: ConvertToRawFIR?
    
    private let errorManager: CompilerErrorManager
    
    init() {
        errorManager = CompilerErrorManager()
    }

    func startDriver(_ source: Lexer.SourceCode, settings: DriverSettings = .init()) {
        if !settings.onlyLexer {
            errorManager.clearErrors()
            bridge?.clearErrors()
        }
        resetPhases()
        
        let lexResult: Lexer.SuccessfulResult
        switch startLexing(source, settings: settings) {
        case .success(result: let result):
            lexResult = result
        case .failure:
            onFailure()
            return
        }
        
        guard !settings.onlyLexer else {
            return
        }
        
        let parseResult: Parser.SuccessfulResult
        switch startParsing(lexResult, settings: settings) {
        case .success(result: let result):
            parseResult = result
        case .failure:
            onFailure()
            return
        }
        
        bridge?.sendDisplayNodes(from: parseResult)
        
        switch startSema(passes: Sema.defaultPasses, parseResult, settings: settings) {
        case .success(result: let result):
            if let result {
                print(result.tree)
            }
        case .failure:
            onFailure()
            return
        }
        
        let loweringResult: ConvertToRawFIR.SuccessfulResult
        switch startLowering(parseResult, settings: settings) {
        case .success(result: let result):
            print(result.nodes)
        case .failure:
            onFailure()
            return
        }
    }
    
    private func startLexing(_ source: Lexer.SourceCode, settings: DriverSettings) -> PhaseResult<Lexer> {
        if lexer == nil {
            lexer = Lexer(errorManager: errorManager, settings: settings)
        }
        
        let result = lexer!.begin(source)
        let syntaxMapping = lexer!.getSyntaxMapping()
        bridge?.sendSyntaxMapping(syntaxMapping)
        return result
    }
    
    private func startParsing(_ tokens: Lexer.SuccessfulResult, settings: DriverSettings) -> PhaseResult<Parser> {
        if parser == nil {
            parser = Parser(errorManager: errorManager, settings: settings)
        }
        
        return parser!.begin(tokens)
    }
    
    private func startSema(passes: [Sema.PassType], _ tree: Parser.SuccessfulResult, settings: DriverSettings) -> PhaseResult<Sema> {
        if sema == nil {
            sema = Sema(errorManager: errorManager, settings: settings)
        }
        
        let input: Sema.InputType = (context: tree, passes: passes)
        return sema!.begin(input)
    }
    
    private func startLowering(_ context: ASTContext, settings: DriverSettings) -> PhaseResult<ConvertToRawFIR> {
        if lowerToFIR == nil {
            lowerToFIR = ConvertToRawFIR(errorManager: errorManager, settings: settings)
        }
        
        let result = lowerToFIR!.begin(context)
        return result
    }
    
    private func resetPhases() {
        lexer = nil
        parser = nil
        sema = nil
    }
    
    private func onFailure() {
        resetPhases()
        bridge?.reportErrors(from: errorManager)
    }
}
