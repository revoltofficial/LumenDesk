import SwiftUI

@main
struct LumenDeskApp: App {
    @StateObject private var store = LightingStore()
    var body: some Scene {
        WindowGroup {
            WorkspaceView().environmentObject(store)
                .preferredColorScheme(.dark)
                .frame(minWidth: 1060, minHeight: 720)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Show…") { store.loadProject() }.keyboardShortcut("o")
                Button("Save Show…") { store.saveProject() }.keyboardShortcut("s")
            }
        }
    }
}
