//
//  ProgramEditorCoordinator.swift
//  quicklang
//
//  Created by Rob Patterson on 11/26/25.
//

import Foundation
import UIKit

class ProgramEditorCoordinator: NSObject, UITextViewDelegate {
    var parent: ProgramEditorView
    private let renderer: ProgramEditorRenderer
    private var inactivityTimer: Timer?
    private var renderingTimer: Timer?
    private var cachedText: NSMutableAttributedString?
    
    private var viewAfterLastChange: UITextView?
    
    init(parent: ProgramEditorView) {
        self.parent = parent
        self.renderer = ProgramEditorRenderer(theme: parent.viewModel.theme)
    }
    
    func textViewDidChange(_ textView: UITextView) {
        let text = NSMutableAttributedString(attributedString: textView.attributedText)
        parent.viewModel.text = text
        viewAfterLastChange = textView
        
        inactivityTimer?.invalidate()
        
        inactivityTimer = Timer.scheduledTimer(
            timeInterval: 2.0,
            target: self,
            selector: #selector(onInactivityTimerEnd),
            userInfo: nil,
            repeats: false
        )
        
        if renderingTimer == nil {
            renderingTimer = Timer.scheduledTimer(
                timeInterval: 0.02,
                target: self,
                selector: #selector(onRenderingTimerEnd),
                userInfo: nil,
                repeats: true
            )
        }
    }
    
    @objc private func onInactivityTimerEnd() {
        if cachedText == nil {
            autoRerunFrontend()
        } else if let cachedText, parent.viewModel.text != cachedText {
            autoRerunFrontend()
        }
    }
    
    @objc private func onRenderingTimerEnd() {
        parent.viewModel.requestSyntaxHighlighting()
        
        if let mapping = parent.viewModel.mapping {
            renderer.render(text: &parent.viewModel.text, with: mapping)
            parent.viewModel.resetMapping()
        }
    }
    
    private func autoRerunFrontend() {
        parent.viewModel.requestFrontendRerun()
        self.cachedText = parent.viewModel.text
    }
        
}
