//
//  Compiler.swift
//  swift-student-challenge-2025
//
//  Created by Rob Patterson on 2/4/25.
//

struct Compiler {
    var lexer: Lexer
    
    let program = "\nabc(and, adne, wid, wir)"
    
    init() {
        self.lexer = Lexer(for: program)
        let lexed = try! lexer.tokenize()
        print(lexed)
        print("\n\n")
        var parser = Parser(for: lexed)
        
        do {
            print(try parser.beginParse())
        } catch let e as Parser.ParseError {
            print("\nError while parsing: \n\(program)\n\n")
            print(e.message)
        } catch {
            print(error)
        }
    }
}
