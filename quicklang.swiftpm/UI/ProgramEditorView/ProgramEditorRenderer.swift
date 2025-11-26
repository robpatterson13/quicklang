//
//  ProgramEditorRenderer.swift
//  quicklang
//
//  Created by Rob Patterson on 11/26/25.
//

import Foundation
import UIKit

@MainActor
class ProgramEditorRenderer {
    
    var theme: Theme
    
    init(theme: Theme) {
        self.theme = theme
    }
    
    func render(
        text: inout NSMutableAttributedString,
        with mapping: LexerSyntaxInfoManager.SyntaxMapping
    ) {
        invalidateHighlighting(of: &text)
        doSyntaxHighlighting(for: &text, with: mapping)
    }
    
    private func invalidateHighlighting(of text: inout NSMutableAttributedString) {
        let plainText = text.string
        let newAttributedString = NSMutableAttributedString(string: plainText)
        newAttributedString.addAttributes(theme.plainText, range: newAttributedString.wholeStringRange)
        text = newAttributedString
    }
    
    private func doSyntaxHighlighting(
        for text: inout NSMutableAttributedString,
        with mapping: LexerSyntaxInfoManager.SyntaxMapping
    ) {
        mapping.forEach { (syntaxType, tokens) in
            switch syntaxType {
            case .keyword:
                doSyntaxHighlightingForKeywords(tokens, on: &text)
            case .booleanLiteral:
                return
            case .numLiteral:
                doSyntaxHighlightingForNumLiterals(tokens, on: &text)
            case .identifier:
                return
            case .symbol:
                return
            }
        }
    }
    
    private func doSyntaxHighlightingForKeywords(
        _ tokens: [LexerSyntaxInfoManager.SyntaxInfo],
        on text: inout NSMutableAttributedString
    ) {
        tokens.forEach { (_, range) in
            text.addAttributes(theme.keyword, range: range)
        }
    }
    
    private func doSyntaxHighlightingForNumLiterals(
        _ tokens: [LexerSyntaxInfoManager.SyntaxInfo],
        on text: inout NSMutableAttributedString
    ) {
        tokens.forEach { (_, range) in
            text.addAttributes(theme.numLiteral, range: range)
        }
    }
}
