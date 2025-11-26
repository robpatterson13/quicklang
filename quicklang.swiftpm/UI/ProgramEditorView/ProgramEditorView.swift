//
//  ProgramEditorView.swift
//  quicklang
//
//  Created by Rob Patterson on 11/26/25.
//

import Foundation
import UIKit
import SwiftUI

struct ProgramEditorView: UIViewRepresentable {
    
    @Binding var viewModel: ProgramEditorViewModel

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.spellCheckingType = .no
        textView.font = viewModel.theme.font
        textView.tintColor = .white
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // keep selection accurate after taking text from viewModel
        let selection = uiView.selectedRange
        defer {
            uiView.selectedRange = selection
        }
        
        uiView.attributedText = viewModel.text
    }
    
    func makeCoordinator() -> ProgramEditorCoordinator {
        ProgramEditorCoordinator(parent: self)
    }
}
