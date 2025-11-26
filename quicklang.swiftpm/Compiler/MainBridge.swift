//
//  MainBridge.swift
//  quicklang
//
//  Created by Rob Patterson on 11/26/25.
//

class MainBridge {
    var driver: Compiler
    var viewModel: ProgramEditorViewModel
    
    init() {
        self.driver = Compiler()
        self.viewModel = ProgramEditorViewModel()
        driver.bridge = self
        viewModel.bridge = self
    }
    
    func sendSourceCode(_ source: String) {
        driver.startDriver(source)
    }
    
    func reportErrors(from errorManager: CompilerErrorManager) {
        let messages = errorManager.dumpErrors(using: DefaultErrorFormatter())
        viewModel.receiveErrorMessages(messages)
    }
    
    func requestSyntaxHighlighting(of source: String) {
        let settings = DriverSettings(onlyLexer: true)
        driver.startDriver(source, settings: settings)
    }
    
    func sendDisplayNodes(from tree: ASTContext) {
        let display = ConvertToDisplayableNode.shared.begin(tree.tree)
        viewModel.receiveDisplayTree(display)
    }
    
    func sendSyntaxMapping(_ mapping: LexerSyntaxInfoManager.SyntaxMapping) {
        viewModel.receiveSyntaxMapping(mapping)
    }
    
    func clearErrors() {
        viewModel.errors = []
    }
}
