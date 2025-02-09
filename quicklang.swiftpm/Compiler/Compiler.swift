//
//  Compiler.swift
//  swift-student-challenge-2025
//
//  Created by Rob Patterson on 2/4/25.
//

struct Compiler {
    var lexer: Lexer
    
    init() {
        self.lexer = Lexer(for: "if true { return 2 } else { x return 30; \n}")
        print(try! lexer.tokenize())
    }
}
