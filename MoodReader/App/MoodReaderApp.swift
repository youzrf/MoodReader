import SwiftUI

@main
struct MoodReaderApp: App {
    @StateObject private var store = LibraryStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(store)
                .preferredColorScheme(.light)
                .tint(Palette.accent)
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active {
                        store.saveNow()
                    }
                }
        }
    }
}
