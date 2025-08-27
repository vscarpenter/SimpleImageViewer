//
//  AppDelegate.swift
//  StillView - Simple Image Viewer
//
//  Created by Vinny Carpenter
//  Copyright © 2025 Vinny Carpenter. All rights reserved.
//  
//  Author: Vinny Carpenter (https://vinny.dev)
//  Source: https://github.com/vscarpenter/SimpleImageViewer
//

import AppKit
import SwiftUI

/// AppDelegate handles application-level window management and lifecycle events
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Properties
    
    /// Reference to the main application window
    var mainWindow: NSWindow?
    
    /// Tracks whether the main window is currently visible
    internal var isMainWindowVisible: Bool = true
    
    /// Window state manager for persistence and restoration
    @MainActor internal lazy var windowStateManager = WindowStateManager()
    
    /// Window state for restoration
    internal var lastWindowFrame: NSRect = .zero
    private var hasSetupMenus: Bool = false
    
    // MARK: - NSApplicationDelegate Methods
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupApplication()
        // Delay menu setup to ensure main window is available
        DispatchQueue.main.async {
            self.setupMenus()
        }
        
        // Favorites removed
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // When user clicks dock icon and no windows are visible, show main window
        if !flag {
            Task { @MainActor in
                showMainWindow()
            }
        }
        return true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't terminate when last window is closed - keep app running
        return false
    }
    
    // MARK: - Window Management
    
    /// Shows the main window, creating it if necessary
    @MainActor func showMainWindow() {
        guard let window = mainWindow else {
            // If no window reference, try to find the main window
            Task { @MainActor in
                findMainWindow()
            }
            return
        }
        
        // Restore previous window frame if available
        if lastWindowFrame != .zero {
            window.setFrame(lastWindowFrame, display: true)
        }
        
        // Make window visible and bring to front
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isMainWindowVisible = true
        
        // Update window state manager
        windowStateManager.updateWindowVisibility(true)
    }
    
    /// Hides the main window without closing the application
    @MainActor func hideMainWindow() {
        // Save current window frame before hiding
        if let window = mainWindow {
            lastWindowFrame = window.frame
            window.orderOut(nil)
        }
        isMainWindowVisible = false
        
        // Update window state manager
        windowStateManager.updateWindowVisibility(false)
    }
    
    /// Sets the main window reference
    @MainActor func setMainWindow(_ window: NSWindow) {
        mainWindow = window
        setupWindowDelegate(for: window)
        
        // Set up window state manager
        windowStateManager.setMainWindow(window)
        
        // Store initial window frame
        lastWindowFrame = window.frame
        
        // Try to restore previous session if available
        tryRestorePreviousSession()
    }
    
    /// Returns whether the main window is currently visible
    var isWindowVisible: Bool {
        return isMainWindowVisible && (mainWindow?.isVisible ?? false)
    }
    
    // MARK: - Private Methods
    
    private func setupApplication() {
        // Configure application behavior
        NSApp.setActivationPolicy(.regular)
    }
    
    private func setupMenus() {
        // Prevent duplicate menu setup
        guard !hasSetupMenus else { return }
        hasSetupMenus = true
        
        // Get the current main menu
        guard let mainMenu = NSApp.mainMenu else { return }
        
        // Find or create Window menu
        var windowMenu: NSMenu
        var windowMenuItem: NSMenuItem
        
        if let existingWindowMenuItem = mainMenu.items.first(where: { $0.title == "Window" }) {
            windowMenuItem = existingWindowMenuItem
            windowMenu = existingWindowMenuItem.submenu ?? NSMenu(title: "Window")
        } else {
            windowMenu = NSMenu(title: "Window")
            windowMenuItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
            windowMenuItem.submenu = windowMenu
            
            // Insert Window menu before Help menu
            let helpMenuIndex = mainMenu.items.firstIndex { $0.title == "Help" } ?? mainMenu.items.count
            mainMenu.insertItem(windowMenuItem, at: helpMenuIndex)
        }
        
        // Add "Show Main Window" menu item if it doesn't exist
        if !windowMenu.items.contains(where: { $0.title == "Show Main Window" }) {
            let showMainWindowItem = NSMenuItem(
                title: "Show Main Window",
                action: #selector(showMainWindowAction),
                keyEquivalent: "n"
            )
            showMainWindowItem.keyEquivalentModifierMask = [.command]
            showMainWindowItem.target = self
            
            windowMenu.addItem(showMainWindowItem)
        }
        
        // Add standard window management items
        if !windowMenu.items.contains(where: { $0.title == "Minimize" }) {
            windowMenu.addItem(NSMenuItem.separator())
            
            let minimizeItem = NSMenuItem(
                title: "Minimize",
                action: #selector(NSWindow.miniaturize(_:)),
                keyEquivalent: "m"
            )
            minimizeItem.keyEquivalentModifierMask = [.command]
            windowMenu.addItem(minimizeItem)
            
            let zoomItem = NSMenuItem(
                title: "Zoom",
                action: #selector(NSWindow.zoom(_:)),
                keyEquivalent: ""
            )
            windowMenu.addItem(zoomItem)
        }
    }
    
    @MainActor private func findMainWindow() {
        // Try to find the main window among existing windows
        if let window = NSApp.windows.first(where: { $0.isMainWindow || $0.isKeyWindow }) {
            setMainWindow(window)
            showMainWindow()
        }
    }
    
    private func setupWindowDelegate(for window: NSWindow) {
        // Set up window delegate to handle close behavior
        let windowDelegate = WindowDelegate(appDelegate: self)
        window.delegate = windowDelegate
    }
    
    // MARK: - Menu Actions
    
    @objc private func showMainWindowAction() {
        Task { @MainActor in
            showMainWindow()
        }
    }
    
    /// Try to restore the previous session state
    @MainActor private func tryRestorePreviousSession() {
        guard windowStateManager.hasValidPreviousSession(),
              let sessionData = windowStateManager.restorePreviousSession() else {
            return
        }
        
        // Post notification to restore the folder and image state
        let userInfo: [String: Any] = [
            "folderURL": sessionData.folderURL,
            "imageIndex": sessionData.imageIndex
        ]
        
        NotificationCenter.default.post(
            name: .restoreWindowState,
            object: nil,
            userInfo: userInfo
        )
    }
    
    // Favorites removed
}

// MARK: - Window Delegate

/// WindowDelegate handles window-specific events and prevents app termination on window close
private class WindowDelegate: NSObject, NSWindowDelegate {
    weak var appDelegate: AppDelegate?
    
    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        super.init()
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Save window state before hiding
        Task { @MainActor in
            appDelegate?.windowStateManager.saveWindowState()
            appDelegate?.hideMainWindow()
        }
        return false
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        appDelegate?.isMainWindowVisible = true
    }
    
    func windowDidResignKey(_ notification: Notification) {
        // Window is no longer key, but might still be visible
    }
    
    func windowDidMove(_ notification: Notification) {
        // Save window frame when moved
        if let window = notification.object as? NSWindow {
            appDelegate?.lastWindowFrame = window.frame
        }
        // Window state manager will handle this through its own observers
    }
    
    func windowDidResize(_ notification: Notification) {
        // Save window frame when resized
        if let window = notification.object as? NSWindow {
            appDelegate?.lastWindowFrame = window.frame
        }
        // Window state manager will handle this through its own observers
    }
    
    func windowWillClose(_ notification: Notification) {
        // This should not be called since windowShouldClose returns false
        // But included for completeness
        appDelegate?.isMainWindowVisible = false
    }
}
