//
//  Utilities.swift
//  swift-student-challenge-2025
//
//  Created by Rob Patterson on 2/6/25.
//

public struct PeekableIterator<Element>: IteratorProtocol {
    private var elements: [Element]
    private var index: Int
    
    public init(elements: [Element], index: Int = 0) {
        self.elements = elements
        self.index = index
    }
    
    public mutating func push(_ element: Element) {
        elements.insert(element, at: self.index)
    }
    
    public mutating func next() -> Element? {
        guard index < elements.count else { return nil }
        defer { self.index += 1 }
        return elements[index]
    }
    
    public mutating func prev() -> Element? {
        guard index > 0 else { return nil }
        self.index -= 1
        return elements[index]
    }
    
    public func peekPrev() -> Element? {
        guard index > 0 else { return nil }
        return elements[index - 1]
    }
    
    public func peekNext() -> Element? {
        guard index < elements.count else { return nil }
        return elements[index]
    }
    
    public func isEmpty() -> Bool {
        return index == elements.count
    }
    
    public mutating func burn() {
        if index < elements.count {
            self.index += 1
        }
    }
    
    public func peek(ahead: Int) -> Element? {
        guard index + (ahead - 1) < elements.count else { return nil }
        return elements[index + (ahead - 1)]
    }
}

extension Array {
    
    public func andmap<E>(_ transform: (Self.Element) throws(E) -> Bool) throws(E) -> Bool where E : Error {
        let results = try self.map(transform)
        
        for result in results {
            if !result {
                return false
            }
        }
        
        return true
    }
}

extension Array where Element == any BlockLevelNode {
    
    var anyIncomplete: Bool {
        for node in self {
            if node.isIncomplete {
                return true
            }
        }
        
        return false
    }
}

extension Array where Element == FuncDefinition.Parameter {
    
    var anyIncomplete: Bool {
        for parameter in self {
            if parameter.isIncomplete {
                return true
            }
        }
        
        return false
    }
}

extension Array where Element == any ExpressionNode {
    
    var anyIncomplete: Bool {
        for expression in self {
            if expression.isIncomplete {
                return true
            }
        }
        
        return false
    }
}
