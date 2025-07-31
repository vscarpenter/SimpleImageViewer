//
//  WindowManagementIntegrationTests.swift
//  StillView - Simple Image Viewer Tests
//
//  Created by Vinny Carpenter
//  Copyright © 2025 Vinny Carpenter. All rights reserved.
//  
//  Author: Vinny Carpenter (https://vinny.dev)
//  Source: https://github.com/vscarpenter/SimpleImageViewer
//

import XCTest
import AppKit
import Combine
@testable import Simple_Image_Viewer

/// Integration tests for complete window management functionality
@MainActor
final class WindowManagementIntegrationTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var appDelegate: AppDelegate!
    var windowStateManager: WindowStateManager!
    var mockWindow: NSWindow!
    var mockPreferencesService: MockPreferencesService!
    var cancellables: Set<AnyCancellable>!
    
    // MARK: - Setup and Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Set up mock preferences service
        mockPreferencesService = MockPreferencesService()
        
        // Create app delegate
        appDelegate = AppDelegate()
        
        // Create window state manager with mock service
        windowStateManager = WindowStateManager(preferencesService: mockPreferencesService)
        appDelegate.windowStateManager = windowStateManager
        
        // Create mock window
        mockWindow = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        cancellables = Set<AnyCancellable>()
        
        // Clear any existing menus
        NSApp.mainMenu = NSMenu()
    }
    
    override func tearDownWithError() throws {
        cancellables = nil
        mockWindow?.close()
        mockWindow = nil
        windowStateManager = nil
        appDelegate = nil
        mockPreferencesService = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Complete Workflow Tests
    
    func testCompleteWindowManagementWorkflow() {
        // Given - Set up complete system
        appDelegate.setMainWindow(mockWindow)
        windowStateManager.setMainWindow(mockWindow)
        
        // Set up menus
        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        
        // Wait for menu setup
        let menuSetupExpectation = XCTestExpectation(description: "Menu setup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            menuSetupExpectation.fulfill()
        }
        wait(for: [menuSetupExpectation], timeout: 1.0)
        
        // Step 1: Window is initially visible
        XCTAssertTrue(mockWindow.isVisible)
        XCTAssertTrue(appDelegate.isWindowVisible)
        XCTAssertTrue(windowStateManager.isMainWindowVisible)
        
        // Step 2: User closes window via close button
        let shouldClose = mockWindow.delegate?.windowShouldClose?(mockWindow) ?? true
        XCTAssertFalse(shouldClose, "Window should not actually close")
        XCTAssertFalse(mockWindow.isVisible, "Window should be hidden")
        XCTAssertFalse(appDelegate.isWindowVisible)
        XCTAssertFalse(windowStateManager.isMainWindowVisible)
        
        // Step 3: App should still be running (not terminated)
        let shouldTerminate = appDelegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared)
        XCTAssertFalse(shouldTerminate, "App should continue running")
        
        // Step 4: User clicks dock icon to restore window
        let handleReopen = appDelegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false)
        XCTAssertTrue(handleReopen)
        XCTAssertTrue(mockWindow.isVisible, "Window should be restored via dock icon")
        XCTAssertTrue(appDelegate.isWindowVisible)
        XCTAssertTrue(windowStateManager.isMainWindowVisible)
        
        // Step 5: Hide window again
        appDelegate.hideMainWindow()
        XCTAssertFalse(mockWindow.isVisible)
        
        // Step 6: Restore via Window menu
        let windowMenu = NSApp.mainMenu?.items.first { $0.title == "Window" }?.submenu
        let showMainWindowItem = windowMenu?.items.first { $0.title == "Show Main Window" }
        
        XCTAssertNotNil(showMainWindowItem)
        
        if let target = showMainWindowItem?.target as? AppDelegate,
           let action = showMainWindowItem?.action {
            target.perform(action)
        }
        
        XCTAssertTrue(mockWindow.isVisible, "Window should be restored via menu")
        XCTAssertTrue(appDelegate.isWindowVisible)
        XCTAssertTrue(windowStateManager.isMainWindowVisible)
        
        // Step 7: Hide window and restore via Cmd+N shortcut
        appDelegate.hideMainWindow()
        XCTAssertFalse(mockWindow.isVisible)
        
        // Verify shortcut exists
        XCTAssertEqual(showMainWindowItem?.keyEquivalent, "n")
        XCTAssertTrue(showMainWindowItem?.keyEquivalentModifierMask.contains(.command) ?? false)
        
        // Simulate shortcut activation
        if let target = showMainWindowItem?.target as? AppDelegate,
           let action = showMainWindowItem?.action {
            target.perform(action)
        }
        
        XCTAssertTrue(mockWindow.isVisible, "Window should be restored via Cmd+N")
        XCTAssertTrue(appDelegate.isWindowVisible)
        XCTAssertTrue(windowStateManager.isMainWindowVisible)
    }
    
    func testWindowStateRestorationWorkflow() {
        // Given - Set up window with specific state
        appDelegate.setMainWindow(mockWindow)
        windowStateManager.setMainWindow(mockWindow)
        
        let originalFrame = NSRect(x: 200, y: 300, width: 1000, height: 800)
        mockWindow.setFrame(originalFrame, display: false)
        
        // Set up folder state
        let testFolderURL = URL(fileURLWithPath: "/tmp/test-folder")
        windowStateManager.updateFolderState(folderURL: testFolderURL, imageIndex: 5)
        
        // Step 1: Hide window (should save state)
        appDelegate.hideMainWindow()
        XCTAssertEqual(appDelegate.lastWindowFrame, originalFrame, "Frame should be saved")
        
        // Step 2: Modify window frame externally
        let differentFrame = NSRect(x: 400, y: 500, width: 600, height: 400)
        mockWindow.setFrame(differentFrame, display: false)
        
        // Step 3: Restore window (should restore original frame)
        appDelegate.showMainWindow()
        XCTAssertEqual(mockWindow.frame, originalFrame, "Original frame should be restored")
        XCTAssertTrue(mockWindow.isVisible)
        
        // Step 4: Verify state persistence
        windowStateManager.saveWindowState()
        XCTAssertNotNil(mockPreferencesService.windowState)
        XCTAssertEqual(mockPreferencesService.windowState?.lastFolderPath, testFolderURL.path)
        XCTAssertEqual(mockPreferencesService.windowState?.lastImageIndex, 5)
    }
    
    func testSessionRestorationOnAppLaunch() {
        // Given - Set up saved session state
        let testFolderURL = URL(fileURLWithPath: "/tmp/test-folder")
        var savedState = WindowState()
        savedState.lastFolderPath = testFolderURL.path
        savedState.lastImageIndex = 10
        savedState.windowFrame = NSRect(x: 150, y: 250, width: 900, height: 700)
        savedState.lastSaved = Date()
        
        // Create mock bookmark data
        savedState.lastFolderBookmark = Data([1, 2, 3, 4, 5])
        
        mockPreferencesService.windowState = savedState
        
        // Create new app delegate and window state manager (simulating app launch)
        let newAppDelegate = AppDelegate()
        let newWindowStateManager = WindowStateManager(preferencesService: mockPreferencesService)
        newAppDelegate.windowStateManager = newWindowStateManager
        
        // Set up window
        newAppDelegate.setMainWindow(mockWindow)
        newWindowStateManager.setMainWindow(mockWindow)
        
        // Verify state was loaded
        XCTAssertEqual(newWindowStateManager.currentWindowState.lastFolderPath, testFolderURL.path)
        XCTAssertEqual(newWindowStateManager.currentWindowState.lastImageIndex, 10)
        XCTAssertEqual(newWindowStateManager.currentWindowState.windowFrame, savedState.windowFrame)
        
        // Verify window frame was restored (if valid)
        if savedState.hasValidWindowFrame {
            XCTAssertEqual(mockWindow.frame, savedState.windowFrame)
        }
    }
    
    // MARK: - Error Recovery Tests
    
    func testRecoveryFromCorruptedWindowState() {
        // Given - Set up corrupted state
        var corruptedState = WindowState()
        corruptedState.windowFrame = CGRect(x: -10000, y: -10000, width: -100, height: -100) // Invalid frame
        corruptedState.lastImageIndex = -5 // Invalid index
        
        mockPreferencesService.windowState = corruptedState
        
        // When - Create new window state manager
        let newWindowStateManager = WindowStateManager(preferencesService: mockPreferencesService)
        appDelegate.windowStateManager = newWindowStateManager
        
        appDelegate.setMainWindow(mockWindow)
        newWindowStateManager.setMainWindow(mockWindow)
        
        // Then - Should handle gracefully without crashing
        XCTAssertNoThrow(appDelegate.showMainWindow())
        XCTAssertTrue(mockWindow.isVisible)
        
        // Window frame should not be corrupted
        let currentFrame = mockWindow.frame
        XCTAssertGreaterThan(currentFrame.width, 0)
        XCTAssertGreaterThan(currentFrame.height, 0)
    }
    
    func testRecoveryFromMissingWindow() {
        // Given - App delegate without window reference
        appDelegate.mainWindow = nil
        
        // When - Try various operations
        XCTAssertNoThrow(appDelegate.showMainWindow())
        XCTAssertNoThrow(appDelegate.hideMainWindow())
        
        // Should handle dock icon clicks gracefully
        let result = appDelegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false)
        XCTAssertTrue(result)
        
        // Should not crash when setting up menus
        XCTAssertNoThrow(appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        ))
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentWindowOperations() {
        // Given
        appDelegate.setMainWindow(mockWindow)
        windowStateManager.setMainWindow(mockWindow)
        
        let expectation = XCTestExpectation(description: "Concurrent operations complete")
        expectation.expectedFulfillmentCount = 10
        
        // When - Perform concurrent operations
        for i in 0..<10 {
            DispatchQueue.global(qos: .userInitiated).async {
                DispatchQueue.main.async {
                    if i % 2 == 0 {
                        self.appDelegate.showMainWindow()
                    } else {
                        self.appDelegate.hideMainWindow()
                    }
                    expectation.fulfill()
                }
            }
        }
        
        // Then - Should complete without crashing
        wait(for: [expectation], timeout: 5.0)
        
        // Final state should be consistent
        XCTAssertNotNil(appDelegate.mainWindow)
        XCTAssertEqual(appDelegate.mainWindow, mockWindow)
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryManagementDuringWindowOperations() {
        // Given
        appDelegate.setMainWindow(mockWindow)
        windowStateManager.setMainWindow(mockWindow)
        
        // When - Perform many operations to test for memory leaks
        for _ in 0..<1000 {
            appDelegate.hideMainWindow()
            appDelegate.showMainWindow()
            
            // Simulate window delegate callbacks
            let moveNotification = Notification(name: NSWindow.didMoveNotification, object: mockWindow)
            mockWindow.delegate?.windowDidMove?(moveNotification)
            
            let resizeNotification = Notification(name: NSWindow.didResizeNotification, object: mockWindow)
            mockWindow.delegate?.windowDidResize?(resizeNotification)
        }
        
        // Then - Should complete without excessive memory usage
        // Note: In a real test environment, you might use memory profiling tools
        XCTAssertNotNil(appDelegate.mainWindow)
        XCTAssertTrue(mockWindow.isVisible)
    }
    
    // MARK: - Edge Case Tests
    
    func testWindowOperationsWithNilDelegate() {
        // Given - Window without delegate
        let windowWithoutDelegate = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        windowWithoutDelegate.delegate = nil
        
        // When - Set as main window
        appDelegate.setMainWindow(windowWithoutDelegate)
        
        // Then - Should handle gracefully
        XCTAssertNoThrow(appDelegate.showMainWindow())
        XCTAssertNoThrow(appDelegate.hideMainWindow())
        
        windowWithoutDelegate.close()
    }
    
    func testMultipleWindowReferences() {
        // Given - Multiple windows
        let secondWindow = NSWindow(
            contentRect: NSRect(x: 200, y: 200, width: 600, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        // When - Switch between windows
        appDelegate.setMainWindow(mockWindow)
        XCTAssertEqual(appDelegate.mainWindow, mockWindow)
        
        appDelegate.setMainWindow(secondWindow)
        XCTAssertEqual(appDelegate.mainWindow, secondWindow)
        
        // Then - Operations should work with current window
        XCTAssertNoThrow(appDelegate.showMainWindow())
        XCTAssertTrue(secondWindow.isVisible)
        
        secondWindow.close()
    }
}

// MARK: - Mock Classes for Integration Tests

class MockPreferencesService: PreferencesService {
    var recentFolders: [URL] = []
    var windowFrame: CGRect = CGRect(x: 100, y: 100, width: 800, height: 600)
    var showFileName: Bool = false
    var showImageInfo: Bool = false
    var slideshowInterval: Double = 3.0
    var lastSelectedFolder: URL?
    var folderBookmarks: [Data] = []
    var windowState: WindowState?
    
    func addRecentFolder(_ url: URL) {
        recentFolders.insert(url, at: 0)
        if recentFolders.count > 10 {
            recentFolders = Array(recentFolders.prefix(10))
        }
    }
    
    func removeRecentFolder(_ url: URL) {
        recentFolders.removeAll { $0 == url }
    }
    
    func clearRecentFolders() {
        recentFolders.removeAll()
        folderBookmarks.removeAll()
    }
    
    func savePreferences() {
        // Mock implementation
    }
    
    func loadPreferences() {
        // Mock implementation
    }
    
    func saveWindowState(_ windowState: WindowState) {
        self.windowState = windowState
    }
    
    func loadWindowState() -> WindowState? {
        return windowState
    }
}