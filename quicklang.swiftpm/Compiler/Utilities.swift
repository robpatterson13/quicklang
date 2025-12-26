//
//  Utilities.swift
//  swift-student-challenge-2025
//
//  Created by Rob Patterson on 2/6/25.
//

import Foundation
import UIKit

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
    
    public mutating func moveToEnd() {
        index = elements.count
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

extension Array where Element == any RawBlockLevelNode {
    
    var anyIncomplete: Bool {
        for node in self {
            if node.isIncomplete {
                return true
            }
        }
        
        return false
    }
}

extension Array where Element == RawFuncDefinition.Parameter {
    
    var anyIncomplete: Bool {
        for parameter in self {
            if parameter.isIncomplete {
                return true
            }
        }
        
        return false
    }
}

extension NSAttributedString {
    var wholeStringRange: NSRange {
        NSRange(location: 0, length: self.length)
    }
}

extension UITextView {
    var cursorPosition: Int? {
        if let selectedRange = self.selectedTextRange {
            return offset(from: self.beginningOfDocument, to: selectedRange.start)
        }
        
        return nil
    }
    
    func characterBeforeCursor(count num: Int) -> String? {
        if let cursorRange = self.selectedTextRange,
           let newPosition = self.position(from: cursorRange.start, offset: -num) {
            
            let range = self.textRange(from: newPosition, to: cursorRange.start)
            let new = self.text(in: range!)
            
            if let new,
               new.count > 1,
                let first = new.first {
                return String(first)
            }
        }
        
        return nil
    }

}

final class GenSymInfo: @unchecked Sendable {
    static let singleton = GenSymInfo()
    
    private let lock = NSLock()
    
    private var _tag = 0
    private var tag: Int {
        get {
            lock.lock()
            defer { lock.unlock() }
            _tag += 1
            return _tag
        }
    }
    
    func genSym(root: String, id: UUID?) -> String {
        return root + "_$\(tag)$"
    }
    
    private init() {}
}
