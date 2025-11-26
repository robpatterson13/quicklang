//
//  Compiler.swift
//  swift-student-challenge-2025
//
//  Created by Rob Patterson on 2/4/25.
//

protocol CompilerPhase {
    associatedtype InputType
    associatedtype SuccessfulResult
    
    init(errorManager: CompilerErrorManager)
    
    func begin(_ input: InputType) -> PhaseResult<Self>
}

enum PhaseResult<Phase: CompilerPhase> {
    case success(result: Phase.SuccessfulResult)
    case failure
}

class Compiler {
    
    weak var bridge: MainBridge?
    
    private var lexer: Lexer?
    private var parser: Parser?
    private var sema: Sema?
    
    private let errorManager: CompilerErrorManager
    
    init() {
        errorManager = CompilerErrorManager()
    }

    func startDriver(_ source: Lexer.SourceCode, onlyLexer: Bool = false) {
        if !onlyLexer {  // change to have some reasoning about settings that shouldn't clear errors
            // ex. lexing for highlighting or parsing for connecting braces of functions for highlighting
            errorManager.clearErrors()
            bridge?.clearErrors()
        }
        resetPhases()
        
        let lexResult: Lexer.SuccessfulResult
        switch startLexing(source) {
        case .success(result: let result):
            lexResult = result
        case .failure:
            onFailure()
            return
        }
        
        guard !onlyLexer else {
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
        
        bridge?.sendDisplayNodes(from: parseResult)
        
//        switch startSema(passes: Sema.defaultPasses, parseResult) {
//        case .success:
//            break
//        case .failure:
//            onFailure()
//            return
//        }
    }
    
    private func startLexing(_ source: Lexer.SourceCode) -> PhaseResult<Lexer> {
        if lexer == nil {
            lexer = Lexer(errorManager: errorManager)
        }
        
        let result = lexer!.begin(source)
        let syntaxMapping = lexer!.getSyntaxMapping()
        bridge?.sendSyntaxMapping(syntaxMapping)
        return result
    }
    
    private func startParsing(_ tokens: Lexer.SuccessfulResult) -> PhaseResult<Parser> {
        if parser == nil {
            parser = Parser(errorManager: errorManager)
        }
        
        return parser!.begin(tokens)
    }
    
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
        bridge?.reportErrors(from: errorManager)
    }
}
