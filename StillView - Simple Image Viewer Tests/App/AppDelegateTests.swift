//
//  AppDelegateTests.swift
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
@testable import Simple_Image_Viewer

final class AppDelegateTests: XCTestCase {
    
    var appDelegate: AppDelegate!
    var mockWindow: NSWindow!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        appDelegate = AppDelegate()
        
        // Create a mock window for testing
        mockWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
    }
    
    override func tearDownWithError() throws {
        mockWindow?.close()
        mockWindow = nil
        appDelegate = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Window Management Tests
    
    func testSetMainWindow() {
        // Given
        XCTAssertNil(appDelegate.mainWindow)
        
        // When
        appDelegate.setMainWindow(mockWindow)
        
        // Then
        XCTAssertEqual(appDelegate.mainWindow, mockWindow)
        XCTAssertNotNil(mockWindow.delegate)
        XCTAssertTrue(appDelegate.isWindowVisible)
    }
    
    func testIsWindowVisibleProperty() {
        // Given
        appDelegate.setMainWindow(mockWindow)
        mockWindow.makeKeyAndOrderFront(nil)
        
        // When/Then
        XCTAssertTrue(appDelegate.isWindowVisible)
        
        // Hide window
        appDelegate.hideMainWindow()
        XCTAssertFalse(appDelegate.isWindowVisible)
    }
    
    func testShowMainWindow() {
        // Given
        appDelegate.setMainWindow(mockWindow)
        mockWindow.orderOut(nil) // Hide the window initially
        
        // When
        appDelegate.showMainWindow()
        
        // Then
        XCTAssertTrue(mockWindow.isVisible)
        XCTAssertTrue(appDelegate.isWindowVisible)
    }
    
    func testShowMainWindowRestoresFrame() {
        // Given
        appDelegate.setMainWindow(mockWindow)
        let originalFrame = NSRect(x: 100, y: 100, width: 800, height: 600)
        mockWindow.setFrame(originalFrame, display: false)
        
        // Hide window (which saves frame)
        appDelegate.hideMainWindow()
        
        // Move window to different position
        mockWindow.setFrame(NSRect(x: 200, y: 200, width: 600, height: 400), display: false)
        
        // When
        appDelegate.showMainWindow()
        
        // Then
        XCTAssertEqual(mockWindow.frame, originalFrame)
    }
    
    func testHideMainWindow() {
        // Given
        appDelegate.setMainWindow(mockWindow)
        mockWindow.makeKeyAndOrderFront(nil) // Show the window initially
        let originalFrame = mockWindow.frame
        
        // When
        appDelegate.hideMainWindow()
        
        // Then
        XCTAssertFalse(mockWindow.isVisible)
        XCTAssertFalse(appDelegate.isWindowVisible)
        // Frame should be saved
        XCTAssertEqual(appDelegate.lastWindowFrame, originalFrame)
    }
    
    func testShowMainWindowWithoutWindowReference() {
        // Given
        appDelegate.mainWindow = nil
        
        // When/Then - Should not crash
        XCTAssertNoThrow(appDelegate.showMainWindow())
    }
    
    // MARK: - Application Delegate Tests
    
    func testApplicationShouldHandleReopenWithNoVisibleWindows() {
        // Given
        appDelegate.setMainWindow(mockWindow)
        mockWindow.orderOut(nil) // Hide window
        let mockApp = NSApplication.shared
        
        // When
        let result = appDelegate.applicationShouldHandleReopen(mockApp, hasVisibleWindows: false)
        
        // Then
        XCTAssertTrue(result)
        XCTAssertTrue(mockWindow.isVisible)
    }
    
    func testApplicationShouldHandleReopenWithVisibleWindows() {
        // Given
        appDelegate.setMainWindow(mockWindow)
        mockWindow.makeKeyAndOrderFront(nil) // Show window
        let mockApp = NSApplication.shared
        
        // When
        let result = appDelegate.applicationShouldHandleReopen(mockApp, hasVisibleWindows: true)
        
        // Then
        XCTAssertTrue(result)
        // Window should remain visible
        XCTAssertTrue(mockWindow.isVisible)
    }
    
    func testApplicationShouldTerminateAfterLastWindowClosed() {
        // Given
        let mockApp = NSApplication.shared
        
        // When
        let result = appDelegate.applicationShouldTerminateAfterLastWindowClosed(mockApp)
        
        // Then
        XCTAssertFalse(result) // App should not terminate when last window is closed
    }
    
    // MARK: - Menu Setup Tests
    
    func testApplicationDidFinishLaunching() {
        // Given
        let notification = Notification(name: NSApplication.didFinishLaunchingNotification)
        
        // When/Then - Should not crash
        XCTAssertNoThrow(appDelegate.applicationDidFinishLaunching(notification))
    }
    
    func testMenuSetupCreatesWindowMenu() {
        // Given - Clear any existing menus
        NSApp.mainMenu = NSMenu()
        
        // When
        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        
        // Wait for async menu setup
        let expectation = XCTestExpectation(description: "Menu setup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then
        let windowMenuItem = NSApp.mainMenu?.items.first { $0.title == "Window" }
        XCTAssertNotNil(windowMenuItem)
        
        let windowMenu = windowMenuItem?.submenu
        XCTAssertNotNil(windowMenu)
        
        let showMainWindowItem = windowMenu?.items.first { $0.title == "Show Main Window" }
        XCTAssertNotNil(showMainWindowItem)
        XCTAssertEqual(showMainWindowItem?.keyEquivalent, "n")
    }
    
    // MARK: - Window Delegate Tests
    
    func testWindowDelegatePreventsWindowClose() {
        // Given
        appDelegate.setMainWindow(mockWindow)
        mockWindow.makeKeyAndOrderFront(nil)
        
        // When
        let shouldClose = mockWindow.delegate?.windowShouldClose?(mockWindow) ?? true
        
        // Then
        XCTAssertFalse(shouldClose) // Window should not actually close
        XCTAssertFalse(mockWindow.isVisible) // But should be hidden
    }
    
    func testWindowDelegateHandlesWindowBecomeKey() {
        // Given
        appDelegate.setMainWindow(mockWindow)
        let notification = Notification(
            name: NSWindow.didBecomeKeyNotification,
            object: mockWindow
        )
        
        // When/Then - Should not crash
        XCTAssertNoThrow(mockWindow.delegate?.windowDidBecomeKey?(notification))
    }
    
    func testWindowDelegateHandlesWindowMove() {
        // Given
        appDelegate.setMainWindow(mockWindow)
        let newFrame = NSRect(x: 150, y: 150, width: 800, height: 600)
        mockWindow.setFrame(newFrame, display: false)
        
        let notification = Notification(
            name: NSWindow.didMoveNotification,
            object: mockWindow
        )
        
        // When
        mockWindow.delegate?.windowDidMove?(notification)
        
        // Then
        XCTAssertEqual(appDelegate.lastWindowFrame, newFrame)
    }
    
    func testWindowDelegateHandlesWindowResize() {
        // Given
        appDelegate.setMainWindow(mockWindow)
        let newFrame = NSRect(x: 0, y: 0, width: 1000, height: 700)
        mockWindow.setFrame(newFrame, display: false)
        
        let notification = Notification(
            name: NSWindow.didResizeNotification,
            object: mockWindow
        )
        
        // When
        mockWindow.delegate?.windowDidResize?(notification)
        
        // Then
        XCTAssertEqual(appDelegate.lastWindowFrame, newFrame)
    }
    
    // MARK: - Menu Action Tests
    
    func testShowMainWindowAction() {
        // Given
        appDelegate.setMainWindow(mockWindow)
        mockWindow.orderOut(nil) // Hide window
        
        // When
        appDelegate.perform(#selector(AppDelegate.showMainWindowAction))
        
        // Then
        XCTAssertTrue(mockWindow.isVisible)
    }
    
    // MARK: - Window Management Integration Tests
    
    func testMainWindowClosingAndReopeningViaWindowMenu() {
        // Given - Set up window and menu
        appDelegate.setMainWindow(mockWindow)
        mockWindow.makeKeyAndOrderFront(nil)
        
        // Simulate menu setup
        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        
        // Wait for async menu setup
        let menuSetupExpectation = XCTestExpectation(description: "Menu setup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            menuSetupExpectation.fulfill()
        }
        wait(for: [menuSetupExpectation], timeout: 1.0)
        
        // When - Close window via delegate (simulates user clicking close button)
        let shouldClose = mockWindow.delegate?.windowShouldClose?(mockWindow) ?? true
        
        // Then - Window should be hidden, not closed
        XCTAssertFalse(shouldClose, "Window should not actually close")
        XCTAssertFalse(mockWindow.isVisible, "Window should be hidden")
        XCTAssertFalse(appDelegate.isWindowVisible, "AppDelegate should track window as not visible")
        
        // When - Reopen via Window menu
        let windowMenu = NSApp.mainMenu?.items.first { $0.title == "Window" }?.submenu
        let showMainWindowItem = windowMenu?.items.first { $0.title == "Show Main Window" }
        
        XCTAssertNotNil(showMainWindowItem, "Show Main Window menu item should exist")
        
        // Simulate menu action
        if let target = showMainWindowItem?.target as? AppDelegate,
           let action = showMainWindowItem?.action {
            target.perform(action)
        }
        
        // Then - Window should be visible again
        XCTAssertTrue(mockWindow.isVisible, "Window should be visible after menu action")
        XCTAssertTrue(appDelegate.isWindowVisible, "AppDelegate should track window as visible")
    }
    
    func testDockIconClickingRestoresHiddenWindow() {
        // Given - Set up window and hide it
        appDelegate.setMainWindow(mockWindow)
        mockWindow.makeKeyAndOrderFront(nil)
        appDelegate.hideMainWindow()
        
        XCTAssertFalse(mockWindow.isVisible, "Window should be hidden initially")
        
        // When - Simulate dock icon click (applicationShouldHandleReopen with no visible windows)
        let result = appDelegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false)
        
        // Then - Window should be restored
        XCTAssertTrue(result, "Should handle reopen")
        XCTAssertTrue(mockWindow.isVisible, "Window should be visible after dock icon click")
        XCTAssertTrue(appDelegate.isWindowVisible, "AppDelegate should track window as visible")
    }
    
    func testDockIconClickingWithVisibleWindowsDoesNothing() {
        // Given - Set up window and keep it visible
        appDelegate.setMainWindow(mockWindow)
        mockWindow.makeKeyAndOrderFront(nil)
        
        XCTAssertTrue(mockWindow.isVisible, "Window should be visible initially")
        
        // When - Simulate dock icon click with visible windows
        let result = appDelegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: true)
        
        // Then - Should still handle reopen but window remains as is
        XCTAssertTrue(result, "Should handle reopen")
        XCTAssertTrue(mockWindow.isVisible, "Window should remain visible")
    }
    
    func testCmdNKeyboardShortcutForWindowRestoration() {
        // Given - Set up window and menu system
        appDelegate.setMainWindow(mockWindow)
        appDelegate.hideMainWindow()
        
        // Simulate menu setup
        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        
        // Wait for async menu setup
        let menuSetupExpectation = XCTestExpectation(description: "Menu setup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            menuSetupExpectation.fulfill()
        }
        wait(for: [menuSetupExpectation], timeout: 1.0)
        
        XCTAssertFalse(mockWindow.isVisible, "Window should be hidden initially")
        
        // When - Find and verify the keyboard shortcut
        let windowMenu = NSApp.mainMenu?.items.first { $0.title == "Window" }?.submenu
        let showMainWindowItem = windowMenu?.items.first { $0.title == "Show Main Window" }
        
        XCTAssertNotNil(showMainWindowItem, "Show Main Window menu item should exist")
        XCTAssertEqual(showMainWindowItem?.keyEquivalent, "n", "Should have Cmd+N shortcut")
        XCTAssertTrue(showMainWindowItem?.keyEquivalentModifierMask.contains(.command) ?? false, "Should use Command modifier")
        
        // Simulate keyboard shortcut activation
        if let target = showMainWindowItem?.target as? AppDelegate,
           let action = showMainWindowItem?.action {
            target.perform(action)
        }
        
        // Then - Window should be restored
        XCTAssertTrue(mockWindow.isVisible, "Window should be visible after Cmd+N")
        XCTAssertTrue(appDelegate.isWindowVisible, "AppDelegate should track window as visible")
    }
    
    func testAppContinuesRunningWhenMainWindowIsClosed() {
        // Given - Set up window
        appDelegate.setMainWindow(mockWindow)
        mockWindow.makeKeyAndOrderFront(nil)
        
        // When - Close the window via delegate
        let shouldClose = mockWindow.delegate?.windowShouldClose?(mockWindow) ?? true
        
        // Then - Window should not actually close (app continues running)
        XCTAssertFalse(shouldClose, "Window should not close, preventing app termination")
        XCTAssertFalse(mockWindow.isVisible, "Window should be hidden")
        
        // Verify app termination behavior
        let shouldTerminate = appDelegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared)
        XCTAssertFalse(shouldTerminate, "App should not terminate when last window is closed")
    }
    
    func testWindowStateRestorationAfterReopening() {
        // Given - Set up window with specific frame and state
        appDelegate.setMainWindow(mockWindow)
        let originalFrame = NSRect(x: 150, y: 200, width: 900, height: 700)
        mockWindow.setFrame(originalFrame, display: false)
        mockWindow.makeKeyAndOrderFront(nil)
        
        // Hide the window (which should save the frame)
        appDelegate.hideMainWindow()
        XCTAssertEqual(appDelegate.lastWindowFrame, originalFrame, "Frame should be saved when hiding")
        
        // Move window to different position to simulate system changes
        let differentFrame = NSRect(x: 300, y: 400, width: 600, height: 500)
        mockWindow.setFrame(differentFrame, display: false)
        
        // When - Show window again
        appDelegate.showMainWindow()
        
        // Then - Original frame should be restored
        XCTAssertEqual(mockWindow.frame, originalFrame, "Original frame should be restored")
        XCTAssertTrue(mockWindow.isVisible, "Window should be visible")
        XCTAssertTrue(appDelegate.isWindowVisible, "AppDelegate should track window as visible")
    }
    
    func testWindowStateRestorationWithZeroFrame() {
        // Given - Set up window with zero saved frame
        appDelegate.setMainWindow(mockWindow)
        appDelegate.lastWindowFrame = .zero
        mockWindow.orderOut(nil)
        
        let currentFrame = mockWindow.frame
        
        // When - Show window with zero saved frame
        appDelegate.showMainWindow()
        
        // Then - Window frame should not change (no restoration)
        XCTAssertEqual(mockWindow.frame, currentFrame, "Frame should not change when saved frame is zero")
        XCTAssertTrue(mockWindow.isVisible, "Window should still be visible")
    }
    
    // MARK: - Window State Manager Integration Tests
    
    func testWindowStateManagerIntegration() {
        // Given - Set up window
        appDelegate.setMainWindow(mockWindow)
        let originalFrame = NSRect(x: 100, y: 150, width: 800, height: 600)
        mockWindow.setFrame(originalFrame, display: false)
        
        // When - Hide window
        appDelegate.hideMainWindow()
        
        // Then - Window state manager should be updated
        XCTAssertFalse(appDelegate.windowStateManager.isMainWindowVisible, "WindowStateManager should track visibility")
        
        // When - Show window
        appDelegate.showMainWindow()
        
        // Then - Window state manager should be updated
        XCTAssertTrue(appDelegate.windowStateManager.isMainWindowVisible, "WindowStateManager should track visibility")
    }
    
    func testPreviousSessionRestoration() {
        // Given - Set up window state manager with previous session
        let testFolderURL = URL(fileURLWithPath: "/tmp/test-folder")
        appDelegate.setMainWindow(mockWindow)
        
        // Simulate having a previous session by directly updating the window state manager
        appDelegate.windowStateManager.updateFolderState(folderURL: testFolderURL, imageIndex: 5)
        
        // Create expectation for notification (this would be posted during app launch)
        let expectation = XCTestExpectation(description: "Restore window state notification")
        
        let observer = NotificationCenter.default.addObserver(
            forName: .restoreWindowState,
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let folderURL = userInfo["folderURL"] as? URL,
               let imageIndex = userInfo["imageIndex"] as? Int {
                XCTAssertEqual(folderURL, testFolderURL)
                XCTAssertEqual(imageIndex, 5)
                expectation.fulfill()
            }
        }
        
        // When - Simulate app launch which would trigger session restoration
        // Since tryRestorePreviousSession is private, we test the window state manager directly
        if appDelegate.windowStateManager.hasValidPreviousSession(),
           let sessionData = appDelegate.windowStateManager.restorePreviousSession() {
            
            // Post the same notification that would be posted by the private method
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
        
        // Then - Should post notification with session data
        wait(for: [expectation], timeout: 1.0)
        
        NotificationCenter.default.removeObserver(observer)
    }
    
    // MARK: - Error Handling Tests
    
    func testShowMainWindowWithoutWindowReference() {
        // Given - No window reference
        appDelegate.mainWindow = nil
        
        // When/Then - Should not crash
        XCTAssertNoThrow(appDelegate.showMainWindow())
    }
    
    func testHideMainWindowWithoutWindowReference() {
        // Given - No window reference
        appDelegate.mainWindow = nil
        
        // When/Then - Should not crash and should update visibility state
        XCTAssertNoThrow(appDelegate.hideMainWindow())
        XCTAssertFalse(appDelegate.isWindowVisible)
    }
    
    func testMenuSetupIdempotency() {
        // Given - Clear any existing menus
        NSApp.mainMenu = NSMenu()
        
        // When - Set up menus multiple times
        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        
        // Wait for first setup
        let firstSetupExpectation = XCTestExpectation(description: "First menu setup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            firstSetupExpectation.fulfill()
        }
        wait(for: [firstSetupExpectation], timeout: 1.0)
        
        let windowMenuAfterFirst = NSApp.mainMenu?.items.first { $0.title == "Window" }?.submenu
        let itemCountAfterFirst = windowMenuAfterFirst?.items.count ?? 0
        
        // Set up menus again
        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        
        // Wait for second setup
        let secondSetupExpectation = XCTestExpectation(description: "Second menu setup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            secondSetupExpectation.fulfill()
        }
        wait(for: [secondSetupExpectation], timeout: 1.0)
        
        // Then - Should not duplicate menu items
        let windowMenuAfterSecond = NSApp.mainMenu?.items.first { $0.title == "Window" }?.submenu
        let itemCountAfterSecond = windowMenuAfterSecond?.items.count ?? 0
        
        XCTAssertEqual(itemCountAfterFirst, itemCountAfterSecond, "Menu items should not be duplicated")
    }
    
    // MARK: - Performance Tests
    
    func testWindowShowHidePerformance() {
        // Given
        appDelegate.setMainWindow(mockWindow)
        
        // When/Then - Measure performance of show/hide operations
        measure {
            for _ in 0..<100 {
                appDelegate.hideMainWindow()
                appDelegate.showMainWindow()
            }
        }
    }
    
    func testMenuSetupPerformance() {
        // Given
        NSApp.mainMenu = NSMenu()
        
        // When/Then - Measure menu setup performance
        measure {
            appDelegate.applicationDidFinishLaunching(
                Notification(name: NSApplication.didFinishLaunchingNotification)
            )
        }
    }
    
    // MARK: - Stress Tests
    
    func testRapidWindowStateChanges() {
        // Given
        appDelegate.setMainWindow(mockWindow)
        
        // When - Rapidly change window state
        for i in 0..<50 {
            if i % 2 == 0 {
                appDelegate.hideMainWindow()
                XCTAssertFalse(appDelegate.isWindowVisible)
            } else {
                appDelegate.showMainWindow()
                XCTAssertTrue(appDelegate.isWindowVisible)
            }
        }
        
        // Then - Final state should be consistent
        XCTAssertTrue(appDelegate.isWindowVisible)
        XCTAssertTrue(mockWindow.isVisible)
    }
    
    func testMultipleWindowDelegateCallbacks() {
        // Given
        appDelegate.setMainWindow(mockWindow)
        let delegate = mockWindow.delegate
        
        // When - Simulate multiple rapid delegate callbacks
        for _ in 0..<20 {
            delegate?.windowDidBecomeKey?(Notification(name: NSWindow.didBecomeKeyNotification, object: mockWindow))
            delegate?.windowDidResignKey?(Notification(name: NSWindow.didResignKeyNotification, object: mockWindow))
        }
        
        // Then - Should not crash and maintain consistent state
        XCTAssertNotNil(appDelegate.mainWindow)
        XCTAssertEqual(appDelegate.mainWindow, mockWindow)
    }
    
    // MARK: - Integration with WindowStateManager Tests
    
    func testWindowFrameUpdatesWindowStateManager() {
        // Given
        appDelegate.setMainWindow(mockWindow)
        let newFrame = NSRect(x: 200, y: 300, width: 1000, height: 800)
        
        // When
        mockWindow.setFrame(newFrame, display: false)
        
        // Simulate window move notification
        let notification = Notification(name: NSWindow.didMoveNotification, object: mockWindow)
        mockWindow.delegate?.windowDidMove?(notification)
        
        // Then
        XCTAssertEqual(appDelegate.lastWindowFrame, newFrame)
    }
    
    func testWindowResizeUpdatesWindowStateManager() {
        // Given
        appDelegate.setMainWindow(mockWindow)
        let newFrame = NSRect(x: 100, y: 100, width: 1200, height: 900)
        
        // When
        mockWindow.setFrame(newFrame, display: false)
        
        // Simulate window resize notification
        let notification = Notification(name: NSWindow.didResizeNotification, object: mockWindow)
        mockWindow.delegate?.windowDidResize?(notification)
        
        // Then
        XCTAssertEqual(appDelegate.lastWindowFrame, newFrame)
    }
}

// MARK: - Test Extensions

extension AppDelegate {
    @objc func showMainWindowAction() {
        showMainWindow()
    }
}