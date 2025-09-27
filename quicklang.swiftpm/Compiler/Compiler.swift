//
//  Compiler.swift
//  swift-student-challenge-2025
//
//  Created by Rob Patterson on 2/4/25.
//

protocol DiagnosticEngineDelegate: AnyObject {
    func onError()
}

protocol DiagnosticEngine {
    associatedtype PhaseErrorInfo
    
    var delegate: (any DiagnosticEngineDelegate)? { get set }
    var errors: [PhaseErrorInfo] { get set }
    
    typealias ErrorReport = String
    func dump() -> ErrorReport
}

class Compiler {
    var lexer: Lexer
    
    let diagnostics: [any DiagnosticEngine] = []
    
    let program = """
let value = 10 + true * 8 + i(16 * blue + another) - hello;
"""
//func abc(param1: Int) -> Bool {
//    if (true) { 
//        return true;
//    } else { 
//        return true;
//    }
//}
//func i(abcdce: Bool, hello: Int) -> Int {
//    if (true) {
//        return true;
//    } else {
//        return false + i();
//    }
//}
//let value = true;
//var value2 = true;
//abc(value);

    init() {
        self.lexer = Lexer(for: program)
        let lexed = try! lexer.tokenize()
        print(lexed)
        print("\n\n")
        let parser = Parser(for: lexed, manager: ParserErrorManager.default, recoverer: DefaultRecovery())
        
        let result = parser.begin()
        print(result)
        print(result.sections.andmap { node in
            node.anyIncomplete
        })
    }
}
