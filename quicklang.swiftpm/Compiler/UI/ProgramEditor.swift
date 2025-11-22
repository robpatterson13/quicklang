//
//  ProgramEditor.swift
//  quicklang
//
//  Created by Rob Patterson on 11/20/25.
//

import SwiftUI
import UIKit
import Observation

class ProgramEditorCoordinator: NSObject, UITextViewDelegate {
    var parent: ProgramEditorView
    private var inactivityTimer: Timer?
    private var cachedText: NSMutableAttributedString?
    
    init(parent: ProgramEditorView) {
        self.parent = parent
    }
    
    func textViewDidChange(_ textView: UITextView) {
        let text = NSMutableAttributedString(attributedString: textView.attributedText)
        parent.viewModel.text = text
        
        inactivityTimer?.invalidate()
        
        inactivityTimer = Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(onTimerEnd), userInfo: nil, repeats: false)
    }
    
    @objc private func onTimerEnd() {
        if cachedText == nil {
            autoRerunFrontend()
        } else if let cachedText, parent.viewModel.text != cachedText {
            autoRerunFrontend()
        }
    }
    
    private func autoRerunFrontend() {
        parent.viewModel.requestFrontendRerun()
        self.cachedText = parent.viewModel.text
    }
        
}

struct ProgramEditorView: UIViewRepresentable {
    
    @Binding var viewModel: ProgramEditorViewModel

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.spellCheckingType = .no
        textView.font = UIFont(name: "Menlo", size: 18)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.attributedText = viewModel.text
    }
    
    func makeCoordinator() -> ProgramEditorCoordinator {
        ProgramEditorCoordinator(parent: self)
    }
}

@Observable
class ProgramEditorViewModel {
    private let bridge: CompilerToUIBridge
    var text = NSMutableAttributedString(string: "")
    var display: [DisplayableNode]? = nil
    var errors: [String] = []
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
    
    func receiveDisplayTree(_ tree: [DisplayableNode]) {
        display = tree
    }
    
    func receiveErrorMessages(_ errors: [String]) {
        self.errors.append(contentsOf: errors)
    }
    
    func requestFrontendRerun() {
        sendToDriver()
    }
}

struct DisplayableNode: Identifiable {
    var id: UUID
    var name: String
    var description: String
    var children: [DisplayableNode]? = nil
}

class ConvertToDisplayableNode: ASTUpwardTransformer {
    typealias TransformerInfo = DisplayableNode
    
    static var shared: ConvertToDisplayableNode {
        ConvertToDisplayableNode()
    }
    
    func begin(_ tree: TopLevel) -> [DisplayableNode] {
        var display: [DisplayableNode] = []
        
        tree.sections.forEach { node in
            node.acceptUpwardTransformer(self) { _, displays in
                display.append(displays)
            }
        }
        
        return display
    }
    
    func visitIdentifierExpression(
        _ expression: IdentifierExpression,
        _ finished: @escaping OnTransformEnd<IdentifierExpression>
    ) {
        let display = DisplayableNode(id: expression.id, name: "Identifier", description: expression.name)
        finished(expression, display)
    }
    
    func visitBooleanExpression(
        _ expression: BooleanExpression,
        _ finished: @escaping OnTransformEnd<BooleanExpression>
    ) {
        let display = DisplayableNode(id: expression.id, name: "Boolean", description: String(expression.value))
        finished(expression, display)
    }
    
    func visitNumberExpression(
        _ expression: NumberExpression,
        _ finished: @escaping OnTransformEnd<NumberExpression>
    ) {
        let display = DisplayableNode(id: expression.id, name: "Number", description: String(expression.value))
        finished(expression, display)
    }
    
    func visitUnaryOperation(
        _ operation: UnaryOperation,
        _ finished: @escaping OnTransformEnd<UnaryOperation>
    ) {
        var displayExpr: DisplayableNode? = nil
        operation.expression.acceptUpwardTransformer(self) { _, display in
            displayExpr = display
        }
        
        let display = DisplayableNode(id: operation.id, name: "Unary Operation", description: "op here", children: [displayExpr!])
        finished(operation, display)
    }
    
    func visitBinaryOperation(
        _ operation: BinaryOperation,
        _ finished: @escaping OnTransformEnd<BinaryOperation>
    ) {
        var displayLhs: DisplayableNode? = nil
        operation.lhs.acceptUpwardTransformer(self) { _, lhs in
            displayLhs = lhs
        }
        var displayRhs: DisplayableNode? = nil
        operation.rhs.acceptUpwardTransformer(self) { _, rhs in
            displayRhs = rhs
        }
        
        let display = DisplayableNode(id: operation.id, name: "Binary Operation", description: "op here", children: [displayLhs!, displayRhs!])
        finished(operation, display)
    }
    
    func visitLetDefinition(
        _ definition: LetDefinition,
        _ finished: @escaping OnTransformEnd<LetDefinition>
    ) {
        var displayExpr: DisplayableNode? = nil
        definition.expression.acceptUpwardTransformer(self) { _, expr in
            displayExpr = expr
        }
        
        let display = DisplayableNode(id: definition.id, name: "Let Definition", description: definition.name, children: [displayExpr!])
        finished(definition, display)
    }
    
    func visitVarDefinition(
        _ definition: VarDefinition,
        _ finished: @escaping OnTransformEnd<VarDefinition>
    ) {
        var displayExpr: DisplayableNode? = nil
        definition.expression.acceptUpwardTransformer(self) { _, expr in
            displayExpr = expr
        }
        
        let display = DisplayableNode(id: definition.id, name: "Var Definition", description: definition.name, children: [displayExpr!])
        finished(definition, display)
    }
    
    func visitFuncDefinition(
        _ definition: FuncDefinition,
        _ finished: @escaping OnTransformEnd<FuncDefinition>
    ) {
        var displayExpr: [DisplayableNode] = []
        definition.body.forEach { node in
            node.acceptUpwardTransformer(self) { _, part in
                displayExpr.append(part)
            }
        }
        
        let display = DisplayableNode(id: definition.id, name: "Func Definition", description: definition.name, children: displayExpr)
        finished(definition, display)
    }
    
    func visitFuncApplication(
        _ expression: FuncApplication,
        _ finished: @escaping OnTransformEnd<FuncApplication>
    ) {
        var displayExpr: [DisplayableNode] = []
        expression.arguments.forEach { node in
            node.acceptUpwardTransformer(self) { _, part in
                displayExpr.append(part)
            }
        }
        
        let display = DisplayableNode(id: expression.id, name: "Func Application", description: expression.name, children: displayExpr)
        finished(expression, display)
    }
    
    func visitIfStatement(
        _ statement: IfStatement,
        _ finished: @escaping OnTransformEnd<IfStatement>
    ) {
        var displayExpr: [DisplayableNode] = []
        statement.thenBranch.forEach { node in
            node.acceptUpwardTransformer(self) { _, part in
                displayExpr.append(part)
            }
        }
        statement.elseBranch?.forEach { node in
            node.acceptUpwardTransformer(self) { _, part in
                displayExpr.append(part)
            }
        }
        
        let display = DisplayableNode(id: statement.id, name: "If Statement", description: "do condition!", children: displayExpr)
        finished(statement, display)
    }
    
    func visitReturnStatement(
        _ statement: ReturnStatement,
        _ finished: @escaping OnTransformEnd<ReturnStatement>
    ) {
        var displayExpr: DisplayableNode?
        statement.expression.acceptUpwardTransformer(self) { _, part in
            displayExpr = part
        }
        
        let display = DisplayableNode(id: statement.id, name: "Return Statement", description: "", children: [displayExpr!])
        finished(statement, display)
    }
    
    
}

struct ProgramEditor: View {
    @State private var viewModel = ProgramEditorViewModel()
    
    var body: some View {
        GeometryReader { reader in
            HStack {
                VStack {
                    toolbar
                    
                    ProgramEditorView(viewModel: $viewModel)
                        .onAppear {
                            viewModel.onLoad()
                        }
                    
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
