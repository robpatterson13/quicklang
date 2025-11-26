import SwiftUI

@main
struct MyApp: App {
    let bridge = MainBridge()
    
    var body: some Scene {
        WindowGroup {
            ProgramEditor(viewModel: bridge.viewModel)
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        #endif
    }
}
