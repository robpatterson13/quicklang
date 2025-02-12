//
//  Compiler.swift
//  swift-student-challenge-2025
//
//  Created by Rob Patterson on 2/4/25.
//

struct Compiler {
    var lexer: Lexer
    
    let program = """
                  func abc(param1: Int) -> Bool { 
                    if 32 { 
                        return 32 
                    } else { 
                        return 31 
                    }
                  }
                  let value = 32;
                  var value2 = true;
                  abc(value)
                  """
    
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
