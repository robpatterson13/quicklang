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
        guard index != 0 else { return nil }
        defer { self.index -= 1}
        return elements[index]
    }
    
    public func isEmpty() -> Bool {
        return index == elements.count
    }
}
