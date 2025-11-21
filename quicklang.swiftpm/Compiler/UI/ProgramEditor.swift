//
//  ProgramEditor.swift
//  quicklang
//
//  Created by Rob Patterson on 11/20/25.
//

import SwiftUI
import UIKit
import Observation

struct ProgramEditorView: UIViewRepresentable {
    
    @Binding var viewModel: ProgramEditorViewModel

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.spellCheckingType = .no
        textView.font = UIFont(name: "Menlo", size: 14)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.attributedText = viewModel.text
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: ProgramEditorView
        
        init(parent: ProgramEditorView) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            let text = NSMutableAttributedString(attributedString: textView.attributedText)
            parent.viewModel.text = text
            if let last = textView.text.last, last == " " {
                text.addAttribute(.font, value: UIFont(name: "Menlo-Bold", size: 14), range: text.mutableString.range(of: "func"))
                textView.attributedText = text
            }
        }
    }
}

@Observable
class ProgramEditorViewModel {
    private let bridge: CompilerToUIBridge
    var text = NSMutableAttributedString(string: "")
    private let driver: Compiler
    
    init() {
        self.bridge = CompilerToUIBridge()
        driver = Compiler(bridge: bridge)
        bridge.viewModel = self
    }
    
    func onLoad() {
        bridge.addDriver(driver)
    }
    
    func sendToDriver() {
        if !text.string.isEmpty {
            bridge.sendSourceCode(text.string)
        }
    }
}

struct ProgramEditor: View {
    @State private var viewModel = ProgramEditorViewModel()
    
    var body: some View {
        VStack {
            toolbar
            
            ProgramEditorView(viewModel: $viewModel)
                .onAppear {
                    viewModel.onLoad()
                }
        }
        .padding(10)
    }
    
    @ViewBuilder
    var toolbar: some View {
        HStack {
            Button {
                viewModel.sendToDriver()
            } label: {
                Image(systemName: "play.fill")
                    .resizable()
                    .frame(width: 20, height: 20)
            }
            .foregroundStyle(Color(.white))
            
            Spacer()
        }
    }
}
