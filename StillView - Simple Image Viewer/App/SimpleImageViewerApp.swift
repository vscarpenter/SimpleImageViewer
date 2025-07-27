import SwiftUI
import AppKit

@main
struct SimpleImageViewerApp: App {
    @State private var window: NSWindow?
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    handleAppWillTerminate()
                }
        }
        .applyWindowResizability()
        .commands {
            // Add File menu commands
            CommandGroup(replacing: .newItem) {
                Button("Open Folder...") {
                    // This will be handled by the ContentView
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func handleAppWillTerminate() {
        // Handle app termination - save preferences
        let preferencesService = DefaultPreferencesService()
        preferencesService.savePreferences()
    }
}

// MARK: - Compatibility Extensions

extension Scene {
    func applyWindowResizability() -> some Scene {
        if #available(macOS 13.0, *) {
            return self.windowResizability(.contentSize)
        } else {
            return self
        }
    }
}

