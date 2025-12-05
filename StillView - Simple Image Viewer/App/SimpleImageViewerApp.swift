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
    @State private var showingWhatsNew = false
    @State private var hasCompletedInitialLaunch = false

    // WhatsNewService for managing version updates and content
    private let whatsNewService: WhatsNewServiceProtocol = WhatsNewService()

    // Performance and memory management services
    private let performanceService = PerformanceOptimizationService.shared
    private let memoryService = MemoryManagementService.shared
    private let unifiedErrorService = UnifiedErrorHandlingService.shared

    // Preferences coordinator for managing preferences window
    @StateObject private var preferencesCoordinator = PreferencesCoordinator()

    // Accessibility service for system-wide accessibility support
    private let accessibilityService = AccessibilityService.shared

    // Feedback service for user feedback submission
    private let feedbackService: FeedbackServiceProtocol = FeedbackService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    setupWindow()
                    handleAppLaunchSequence()
                    startPerformanceMonitoring()
                    // Initialize accessibility service
                    _ = AccessibilityService.shared
                    // Initialize AI Insights state after app setup
                    initializeAIInsightsState()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    handleAppWillTerminate()
                }
                .onReceive(NotificationCenter.default.publisher(for: .showWhatsNew)) { _ in
                    showingWhatsNew = true
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    handleAppDidBecomeActive()
                }
                .sheet(isPresented: $showingAbout) {
                    AboutView()
                }
                .sheet(isPresented: $showingHelp) {
                    HelpView()
                }
                .sheet(isPresented: $showingWhatsNew, onDismiss: handleWhatsNewDismissal) {
                    // Use WhatsNewService to get content
                    if let content = whatsNewService.getWhatsNewContent() {
                        WhatsNewSheet(content: content)
                    }
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
            
            // Add Preferences menu command
            CommandGroup(after: .appInfo) {
                Button("Preferences...") {
                    Task { @MainActor in
                        preferencesCoordinator.showPreferences()
                    }
                }
                .keyboardShortcut(",", modifiers: .command)
                .help("Open application preferences")
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
                Button("What's New") {
                    whatsNewService.showWhatsNewSheet()
                }

                Divider()

                Button("StillView Help") {
                    showingHelp = true
                }
                .keyboardShortcut("/", modifiers: [.command, .shift])

                Button("Keyboard Shortcuts") {
                    showingHelp = true
                }
                .keyboardShortcut("?", modifiers: .command)

                Divider()

                Button("Send Feedback via GitHub...") {
                    feedbackService.openGitHubFeedbackForm()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])

                Button("Send Feedback via Email...") {
                    feedbackService.openEmailFeedbackForm()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Divider()

                Button("Visit GitHub Repository") {
                    if let url = URL(string: "https://github.com/vscarpenter/SimpleImageViewer") {
                        NSWorkspace.shared.open(url)
                    }
                }

                Divider()

                Button("Reset AI Consent (Debug)") {
                    resetAIConsentForTesting()
                }
                .keyboardShortcut("r", modifiers: [.command, .option, .shift])
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
        
        // Delay security-scoped bookmark restoration to prevent startup crashes
        // This allows the app to fully initialize before accessing system resources
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            Task { @MainActor in
                do {
                    Logger.start("Starting bookmark restoration...")
                    SecurityScopedBookmarkManager.shared.restoreBookmarksOnLaunch()
                    Logger.complete("Bookmark restoration completed")
                } catch {
                    Logger.fail("Bookmark restoration failed", error: error)
                }
            }
        }
    }
    
    /// Handles the app launch sequence including automatic "What's New" popup
    private func handleAppLaunchSequence() {
        // Mark that we've started the launch sequence
        hasCompletedInitialLaunch = false
        
        // Delay the "What's New" check to ensure main app initialization is complete
        // This prevents interference with the main app startup and ensures the window is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.checkAndShowWhatsNewIfNeeded()
        }
    }
    
    /// Checks if "What's New" should be shown and presents it automatically
    private func checkAndShowWhatsNewIfNeeded() {
        // Only show automatic popup if we haven't completed initial launch
        // and the service determines it should be shown
        guard !hasCompletedInitialLaunch && whatsNewService.shouldShowWhatsNew() else {
            hasCompletedInitialLaunch = true
            return
        }
        
        // Ensure the main window is ready and visible before showing the popup
        guard let window = window, window.isVisible, window.isMainWindow else {
            // Retry after a short delay if window isn't ready, but limit retries
            let maxRetries = 5
            let currentRetry = UserDefaults.standard.integer(forKey: "WhatsNewRetryCount")
            
            if currentRetry < maxRetries {
                UserDefaults.standard.set(currentRetry + 1, forKey: "WhatsNewRetryCount")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.checkAndShowWhatsNewIfNeeded()
                }
            } else {
                // Reset retry count and mark as completed to avoid infinite retries
                UserDefaults.standard.removeObject(forKey: "WhatsNewRetryCount")
                hasCompletedInitialLaunch = true
            }
            return
        }
        
        // Reset retry count on successful window check
        UserDefaults.standard.removeObject(forKey: "WhatsNewRetryCount")
        
        // Ensure the main app interface is fully loaded before showing popup
        // This prevents interference with the main app initialization
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Final check that we should still show the popup
            guard self.whatsNewService.shouldShowWhatsNew() else {
                self.hasCompletedInitialLaunch = true
                return
            }
            
            // Show the "What's New" sheet
            self.showingWhatsNew = true
            self.hasCompletedInitialLaunch = true
        }
    }
    
    /// Handles app becoming active (for focus management)
    private func handleAppDidBecomeActive() {
        // If we're showing the What's New sheet, ensure proper focus
        if showingWhatsNew {
            // Ensure the main window remains key after the sheet is presented
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let window = self.window {
                    window.makeKey()
                }
            }
        }
    }
    
    /// Handles "What's New" sheet dismissal with proper focus management
    private func handleWhatsNewDismissal() {
        // Mark the current version as shown when the sheet is dismissed
        whatsNewService.markWhatsNewAsShown()
        
        // Restore focus to the main window with improved focus management
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = self.window {
                // Ensure the window is visible and properly focused
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                
                // Activate the application to ensure proper focus
                NSApp.activate(ignoringOtherApps: true)
                
                // Post notification that focus has been restored
                NotificationCenter.default.post(name: .whatsNewDismissed, object: nil)
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
        
        // Stop performance monitoring
        performanceService.stopMonitoring()
    }
    
    /// Start performance monitoring and optimization
    private func startPerformanceMonitoring() {
        // Start performance monitoring
        performanceService.startMonitoring()
        
        // Start memory monitoring
        // Memory service starts automatically
        
        Logger.info("Performance and memory monitoring started")
    }
    
    /// Initialize AI Insights state during app launch
    private func initializeAIInsightsState() {
        // Delay AI Insights initialization to ensure all services are ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            Logger.info("AI Insights state initialization completed during app launch")
            
            // Post notification that AI Insights initialization is complete
            NotificationCenter.default.post(name: .aiInsightsInitializationComplete, object: nil)
        }
    }

    // MARK: - Debug Methods

    /// Reset AI consent for testing the first-run experience
    private func resetAIConsentForTesting() {
        AIConsentManager.shared.resetConsentState()

        // Show alert to confirm reset
        let alert = NSAlert()
        alert.messageText = "AI Consent Reset"
        alert.informativeText = "AI consent has been reset. Restart the app to see the first-run dialog."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    /// Posted when AI Insights initialization is complete
    static let aiInsightsInitializationComplete = Notification.Name("aiInsightsInitializationComplete")
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

