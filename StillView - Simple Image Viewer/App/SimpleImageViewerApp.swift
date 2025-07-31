//
//  SimpleImageViewerApp.swift
//  StillView - Simple Image Viewer
//
//  Created by Vinny Carpenter
//  Copyright © 2025 Vinny Carpenter. All rights reserved.
//  
//  Author: Vinny Carpenter (https://vinny.dev)
//  Source: https://github.com/vscarpenter/SimpleImageViewer
//

import SwiftUI
import AppKit

@main
struct SimpleImageViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var window: NSWindow?
    @State private var showingAbout = false
    @State private var showingHelp = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    setupWindow()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    handleAppWillTerminate()
                }
                .sheet(isPresented: $showingAbout) {
                    AboutView()
                }
                .sheet(isPresented: $showingHelp) {
                    HelpView()
                }
        }
        .applyWindowResizability()
        .commands {
            // Add About menu command
            CommandGroup(replacing: .appInfo) {
                Button("About StillView") {
                    showingAbout = true
                }
            }
            
            // Add File menu commands
            CommandGroup(replacing: .newItem) {
                Button("Open Folder...") {
                    // Bring window to foreground and handle folder selection
                    Task { @MainActor in
                        appDelegate.showMainWindow()
                        NotificationCenter.default.post(name: .requestFolderSelection, object: nil)
                    }
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Divider()
                
                Button("Back to Folder Selection") {
                    // Bring window to foreground and go back to folder selection
                    Task { @MainActor in
                        appDelegate.showMainWindow()
                        NotificationCenter.default.post(name: .requestFolderSelection, object: nil)
                    }
                }
                .keyboardShortcut("b", modifiers: .command)
            }
            
            // Add Help menu commands
            CommandGroup(replacing: .help) {
                Button("StillView Help") {
                    showingHelp = true
                }
                .keyboardShortcut("/", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Keyboard Shortcuts") {
                    showingHelp = true
                }
                .keyboardShortcut("?", modifiers: .command)
                
                Button("Visit GitHub Repository") {
                    if let url = URL(string: "https://github.com/vscarpenter/SimpleImageViewer") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupWindow() {
        // Find the main window and set it in the app delegate
        DispatchQueue.main.async {
            if let window = NSApp.windows.first {
                self.window = window
                Task { @MainActor in
                    self.appDelegate.setMainWindow(window)
                }
            }
        }
    }
    
    private func handleAppWillTerminate() {
        // Handle app termination - save preferences and window state
        let preferencesService = DefaultPreferencesService()
        preferencesService.savePreferences()
        
        // Save window state through app delegate
        Task { @MainActor in
            appDelegate.windowStateManager.saveWindowState()
        }
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

