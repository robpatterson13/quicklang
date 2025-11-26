//
//  ProgramEditor.swift
//  quicklang
//
//  Created by Rob Patterson on 11/20/25.
//

import SwiftUI
import UIKit
import Observation

@Observable
class ProgramEditorViewModel {
    var bridge: MainBridge?
    var text = NSMutableAttributedString(string: "")
    var display: [DisplayableNode]? = nil
    var errors: [String] = []
    var mapping: LexerSyntaxInfoManager.SyntaxMapping?
    var theme: Theme = .default
    
    func sendToDriver() {
        if !text.string.isEmpty {
            bridge?.sendSourceCode(text.string)
        }
    }
    
    func receiveDisplayTree(_ tree: [DisplayableNode]) {
        display = tree
    }
    
    func receiveErrorMessages(_ errors: [String]) {
        self.errors.append(contentsOf: errors)
    }
    
    func requestFrontendRerun() {
        sendToDriver()
    }
    
    func requestSyntaxHighlighting() {
        bridge?.requestSyntaxHighlighting(of: text.string)
    }
    
    func receiveSyntaxMapping(_ mapping: LexerSyntaxInfoManager.SyntaxMapping) {
        self.mapping = mapping
    }
    
    func resetMapping() {
        mapping = nil
    }
}

struct ProgramEditor: View {
    @State private var viewModel: ProgramEditorViewModel
    
    init(viewModel: ProgramEditorViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        GeometryReader { reader in
            HStack {
                VStack {
                    toolbar
                    
                    ProgramEditorView(viewModel: $viewModel)
                    
                    console
                        .frame(height: reader.size.height / 5)
                    
                }
                tree
                    .frame(maxWidth: reader.size.width / 3, maxHeight: .infinity)
            }
            .padding(12)
        }
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
    
    @ViewBuilder
    var tree: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                
                if let display = viewModel.display {
                    List(display, id: \.id, children: \.children) { line in
                        HStack {
                            Text(line.name)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Text(line.description)
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                } else {
                    Text("No AST to display")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .padding()
                }
                
                Spacer(minLength: 0)
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 2)
    }
    
    @ViewBuilder
    var console: some View {
        VStack {
            if viewModel.errors.isEmpty {
                Text("No errors")
                    .multilineTextAlignment(.leading)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.errors, id: \.self) { message in
                        Text(message)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            
            Spacer()
        }
        .font(.custom("Menlo", size: 18))
        .foregroundStyle(viewModel.errors.isEmpty ? .white : .red)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(12)
        .background(.ultraThickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.trailing, 12)
        .shadow(radius: 2)
    }
}
