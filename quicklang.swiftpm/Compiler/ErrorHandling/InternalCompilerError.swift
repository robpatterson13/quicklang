//
//  InternalCompilerError.swift
//  quicklang
//
//  Created by Rob Patterson on 12/20/25.
//

enum InternalCompilerError {
    
    static func unreachable(_ message: String) -> Never {
        terminate(message)
    }
    
    private static func terminate(_ message: String) -> Never {
        fatalError(message)
    }
}
