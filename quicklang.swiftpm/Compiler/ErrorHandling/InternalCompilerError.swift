//
//  InternalCompilerError.swift
//  quicklang
//
//  Created by Rob Patterson on 12/20/25.
//

enum InternalCompilerError {
    
    static func unreachable(_ message: String? = nil) -> Never {
        if let message {
            terminate(message)
        } else {
            terminate("This should never be reached")
        }
    }
    
    private static func terminate(_ message: String) -> Never {
        fatalError(message)
    }
}
