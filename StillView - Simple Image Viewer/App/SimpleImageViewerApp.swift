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
    @FocusedValue(\.openFolderAction) private var openFolderAction
    @FocusedValue(\.backToFoldersAction) private var backToFoldersAction

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
            ContentView(windowStateManager: appDelegate.windowStateManager)
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    setupWindow()
                    handleAppLaunchSequence()
                    startPerformanceMonitoring()
                    // Initialize accessibility service
                    _ = AccessibilityService.shared
                }
                .onReceive(NotificationCenter.default.publisher(for: .showWhatsNew)) { _ in
                    showingWhatsNew = true
                }
                .onReceive(NotificationCenter.default.publisher(for: .openPreferences)) { _ in
                    preferencesCoordinator.showPreferences()
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
        // Studio redesign: the unified toolbar owns the title-bar region;
        // traffic lights render inline over it. Default frame matches the
        // design reference window.
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 740)
        .windowResizability(.contentSize)
        .commands {
            #if DEBUG
            CommandMenu("Debug") {
                Button("Run AI Insights Eval…") {
                    InsightEvalHarness.presentAndRun()
                }
            }
            #endif

            // Add About menu command
            CommandGroup(replacing: .appInfo) {
                Button("About StillView") {
                    showingAbout = true
                }
            }
            
            // Add Preferences menu command
            CommandGroup(after: .appInfo) {
                Button("Settings…") {
                    Task { @MainActor in
                        preferencesCoordinator.showPreferences()
                    }
                }
                .keyboardShortcut(",", modifiers: .command)
                .help("Open StillView settings")
            }
            
            // Add File menu commands
            CommandGroup(replacing: .newItem) {
                Button("Open Folder…") {
                    openFolderAction?()
                }
                .keyboardShortcut("o", modifiers: .command)
                .disabled(openFolderAction == nil)
                
                Divider()
                
                Button("Back to Folder Selection") {
                    backToFoldersAction?()
                }
                .keyboardShortcut("b", modifiers: .command)
                .disabled(backToFoldersAction == nil)
            }

            ViewerCommands()
            
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
                    preferencesCoordinator.selectTab(.shortcuts)
                    preferencesCoordinator.showPreferences()
                }

                Divider()

                Button("Send Feedback via GitHub…") {
                    feedbackService.openGitHubFeedbackForm()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])

                Button("Send Feedback via Email…") {
                    feedbackService.openEmailFeedbackForm()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Divider()

                if let privacyURL = URL(string: "https://stillviewapp.com/privacy.html") {
                    Link("Privacy Policy", destination: privacyURL)
                }

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
        // Security-scoped bookmark restoration now happens in
        // AppDelegate.applicationDidFinishLaunching — no arbitrary delay needed.
    }

    /// Handles the app launch sequence including automatic "What's New" popup.
    /// Triggered from the WindowGroup `.onAppear` and re-tried on the first
    /// `didBecomeActive` so we don't depend on a timing-based delay.
    private func handleAppLaunchSequence() {
        checkAndShowWhatsNewIfNeeded()
    }

    /// Checks if "What's New" should be shown and presents it automatically.
    /// Returns silently if the window isn't ready yet; the `didBecomeActive`
    /// publisher will re-invoke this on the next activation, which is the
    /// proper signal for "the app is fully on screen."
    private func checkAndShowWhatsNewIfNeeded() {
        guard !hasCompletedInitialLaunch else { return }
        guard whatsNewService.shouldShowWhatsNew() else {
            hasCompletedInitialLaunch = true
            return
        }
        guard let window = window, window.isVisible else {
            // Window not attached yet; bail out and wait for didBecomeActive to re-call us.
            return
        }

        showingWhatsNew = true
        hasCompletedInitialLaunch = true
    }
    
    /// Handles app becoming active (for focus management and What's New retry).
    private func handleAppDidBecomeActive() {
        // Second-chance trigger for What's New: when the app first becomes active the
        // window has been attached, so a check that bailed out from `.onAppear` can succeed.
        checkAndShowWhatsNewIfNeeded()

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
    
    /// Start performance monitoring and optimization
    private func startPerformanceMonitoring() {
        // Start performance monitoring
        performanceService.startMonitoring()
        
        // Start memory monitoring
        // Memory service starts automatically
        
        Logger.info("Performance and memory monitoring started")
    }
    
}

/// The menu bar remains useful in Single, Strip, and Grid without stealing typing keys.
@MainActor
private struct ViewerCommands: Commands {
    @FocusedObject private var viewModel: ImageViewerViewModel?
    @FocusedValue(\.toggleSubfoldersAction) private var toggleSubfoldersAction
    @FocusedValue(\.refreshFolderAction) private var refreshFolderAction

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Group {
                Button("Single") { viewModel?.setViewMode(.single) }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Strip") { viewModel?.setViewMode(.strip) }
                    .keyboardShortcut("2", modifiers: .command)
                Button("Grid") { viewModel?.setViewMode(.grid) }
                    .keyboardShortcut("3", modifiers: .command)

                Divider()

                Button(viewModel?.inspectorVisible == true ? "Hide Inspector" : "Show Inspector") {
                    viewModel?.toggleInspector()
                }
                .keyboardShortcut("i", modifiers: [.command, .option])
                Button("Show AI Insights") { viewModel?.showInspector(tab: .insights) }
                    .keyboardShortcut("i", modifiers: .command)
                Toggle("Show Filename", isOn: Binding(
                    get: { viewModel?.showFileName ?? false },
                    set: { newValue in
                        if viewModel?.showFileName != newValue { viewModel?.toggleFileNameDisplay() }
                    }
                ))

                Divider()

                Button("Zoom In") { viewModel?.zoomIn() }
                    .keyboardShortcut("+", modifiers: .command)
                Button("Zoom Out") { viewModel?.zoomOut() }
                    .keyboardShortcut("-", modifiers: .command)
                Button("Fit to Window") { viewModel?.zoomToFit() }
                    .keyboardShortcut("0", modifiers: .command)
                Button("Actual Size") { viewModel?.zoomToActualSize() }
                    .keyboardShortcut("0", modifiers: [.command, .option])

                Divider()

                Toggle("Include Subfolders", isOn: Binding(
                    get: { viewModel?.includeSubfolders ?? false },
                    set: { _ in toggleSubfoldersAction?() }
                ))
                .disabled(toggleSubfoldersAction == nil)
                Button("Refresh Folder") { refreshFolderAction?() }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(refreshFolderAction == nil)
            }
            .disabled(viewModel == nil)
        }

        CommandMenu("Image") {
            Group {
                Button("Previous Image") { viewModel?.previousImage() }
                    .disabled(viewModel?.hasPrevious != true)
                Button("Next Image") { viewModel?.nextImage() }
                    .disabled(viewModel?.hasNext != true)
                Button(viewModel?.isSlideshow == true ? "Stop Slideshow" : "Start Slideshow") {
                    viewModel?.toggleSlideshow()
                }
                .disabled(viewModel?.totalImages == 0)

                Divider()

                Button("Copy Image") {
                    if let imageFile = viewModel?.currentImageFile { ContextMenuService.shared.copyImage(imageFile) }
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                Button("Copy Path") {
                    if let imageFile = viewModel?.currentImageFile { ContextMenuService.shared.copyImagePath(imageFile) }
                }
                .keyboardShortcut("c", modifiers: [.command, .option])
                Button("Share…") { viewModel?.shareCurrentImage() }
                Button("Reveal in Finder") {
                    if let imageFile = viewModel?.currentImageFile { ContextMenuService.shared.revealInFinder(imageFile) }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Divider()

                Button("Move to Trash") {
                    Task { await viewModel?.moveCurrentImageToTrash() }
                }
                .disabled(viewModel?.canDeleteCurrentImage != true)
            }
            .disabled(viewModel?.currentImageFile == nil)
        }
    }
}
