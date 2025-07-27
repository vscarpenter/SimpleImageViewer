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
    @State private var window: NSWindow?
    @State private var showingAbout = false
    @State private var showingHelp = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
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
                    // This will be handled by the ContentView
                }
                .keyboardShortcut("o", modifiers: .command)
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

