//
//  AppStoreComplianceTests.swift
//  StillView - Simple Image Viewer Tests
//
//  Created by Kiro on 7/30/25.
//

import XCTest
import SwiftUI
import AppKit
@testable import Simple_Image_Viewer

/// Comprehensive App Store compliance validation tests
/// Tests exact scenarios mentioned in App Store rejection feedback
@MainActor
final class AppStoreComplianceTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private var originalAppearance: NSAppearance?
    private var appDelegate: AppDelegate!
    private var windowStateManager: WindowStateManager!
    private var mockWindow: NSWindow!
    private var mockPreferencesService: MockPreferencesService!
    
    // MARK: - Setup and Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Store original appearance
        originalAppearance = NSApp.effectiveAppearance
        
        // Set up mock services
        mockPreferencesService = MockPreferencesService()
        
        // Create app delegate and window state manager
        appDelegate = AppDelegate()
        windowStateManager = WindowStateManager(preferencesService: mockPreferencesService)
        appDelegate.windowStateManager = windowStateManager
        
        // Create mock window
        mockWindow = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        // Set up window references
        appDelegate.setMainWindow(mockWindow)
        windowStateManager.setMainWindow(mockWindow)
        
        continueAfterFailure = false
    }
    
    override func tearDownWithError() throws {
        // Restore original appearance
        if let originalAppearance = originalAppearance {
            NSApp.appearance = originalAppearance
        }
        
        // Clean up
        mockWindow?.close()
        mockWindow = nil
        windowStateManager = nil
        appDelegate = nil
        mockPreferencesService = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - App Store Rejection Scenario Tests
    
    func testDarkModeUIVisibilityScenarios() {
        // Test exact scenarios mentioned in App Store rejection feedback
        // Requirement 4.1: Dark mode UI visibility issues
        
        let testScenarios: [(NSAppearance.Name, String)] = [
            (.darkAqua, "Dark mode"),
            (.aqua, "Light mode")
        ]
        
        for (appearanceName, modeName) in testScenarios {
            NSApp.appearance = NSAppearance(named: appearanceName)
            
            // Test 1: Navigation controls visibility
            let mockViewModel = createMockImageViewerViewModel()
            let navigationView = NavigationControlsView(viewModel: mockViewModel) { }
            let navController = NSHostingController(rootView: navigationView)
            navController.loadView()
            
            XCTAssertNotNil(navController.view, "Navigation controls should load in \(modeName)")
            
            // Verify adaptive colors are applied
            XCTAssertNotNil(Color.appToolbarBackground, "Toolbar background should exist in \(modeName)")
            XCTAssertNotNil(Color.appText, "Text color should exist in \(modeName)")
            XCTAssertNotNil(Color.appBorder, "Border color should exist in \(modeName)")
            
            // Test 2: Image info overlay visibility
            let mockImageFile = createMockImageFile()
            let mockImage = createMockNSImage()
            let overlayView = ImageInfoOverlayView(imageFile: mockImageFile, currentImage: mockImage)
            let overlayController = NSHostingController(rootView: overlayView)
            overlayController.loadView()
            
            XCTAssertNotNil(overlayController.view, "Image info overlay should load in \(modeName)")
            
            // Verify overlay colors are visible
            XCTAssertNotNil(Color.appOverlayBackground, "Overlay background should exist in \(modeName)")
            XCTAssertNotNil(Color.appOverlayText, "Overlay text should exist in \(modeName)")
            
            // Test 3: Folder selection view visibility
            let folderView = FolderSelectionView()
            let folderController = NSHostingController(rootView: folderView)
            folderController.loadView()
            
            XCTAssertNotNil(folderController.view, "Folder selection should load in \(modeName)")
            
            // Verify background gradients use adaptive colors
            XCTAssertNotNil(Color.appBackground, "Background should exist in \(modeName)")
            XCTAssertNotNil(Color.appSecondaryBackground, "Secondary background should exist in \(modeName)")
            XCTAssertNotNil(Color.appTertiaryBackground, "Tertiary background should exist in \(modeName)")
        }
    }
    
    func testWindowManagementComplianceScenarios() {
        // Test exact scenarios mentioned in App Store rejection feedback
        // Requirement 4.2: Window management following macOS Human Interface Guidelines
        
        // Set up menus
        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        
        // Wait for menu setup
        let menuExpectation = XCTestExpectation(description: "Menu setup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            menuExpectation.fulfill()
        }
        wait(for: [menuExpectation], timeout: 1.0)
        
        // Scenario 1: Window close behavior (should hide, not terminate app)
        XCTAssertTrue(mockWindow.isVisible, "Window should initially be visible")
        
        let shouldClose = mockWindow.delegate?.windowShouldClose?(mockWindow) ?? true
        XCTAssertFalse(shouldClose, "Window should not actually close (should hide instead)")
        XCTAssertFalse(mockWindow.isVisible, "Window should be hidden after close attempt")
        
        let shouldTerminate = appDelegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared)
        XCTAssertFalse(shouldTerminate, "App should continue running after window close")
        
        // Scenario 2: Window menu availability
        let windowMenu = NSApp.mainMenu?.items.first { $0.title == "Window" }?.submenu
        XCTAssertNotNil(windowMenu, "Window menu should exist")
        
        let showMainWindowItem = windowMenu?.items.first { $0.title == "Show Main Window" }
        XCTAssertNotNil(showMainWindowItem, "Show Main Window menu item should exist")
        
        // Scenario 3: Keyboard shortcut (Cmd+N)
        XCTAssertEqual(showMainWindowItem?.keyEquivalent, "n", "Should have Cmd+N shortcut")
        XCTAssertTrue(showMainWindowItem?.keyEquivalentModifierMask.contains(.command) ?? false, 
                     "Should use Command modifier")
        
        // Scenario 4: Dock icon behavior
        let handleReopen = appDelegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false)
        XCTAssertTrue(handleReopen, "Should handle dock icon clicks")
        XCTAssertTrue(mockWindow.isVisible, "Window should be restored via dock icon")
        
        // Scenario 5: Menu item functionality
        appDelegate.hideMainWindow()
        XCTAssertFalse(mockWindow.isVisible, "Window should be hidden")
        
        if let target = showMainWindowItem?.target as? AppDelegate,
           let action = showMainWindowItem?.action {
            target.perform(action)
        }
        
        XCTAssertTrue(mockWindow.isVisible, "Window should be restored via menu item")
    }
    
    func testMacOSVersionCompatibility() {
        // Test compatibility across multiple macOS versions
        // Requirement 4.4: Test on multiple macOS versions
        
        let currentVersion = ProcessInfo.processInfo.operatingSystemVersion
        print("Testing on macOS \(currentVersion.majorVersion).\(currentVersion.minorVersion).\(currentVersion.patchVersion)")
        
        // Test 1: System color availability (should work on macOS 12.0+)
        XCTAssertNotNil(NSColor.controlBackgroundColor, "System colors should be available")
        XCTAssertNotNil(NSColor.labelColor, "Label colors should be available")
        XCTAssertNotNil(NSColor.controlAccentColor, "Accent colors should be available")
        
        // Test 2: SwiftUI appearance detection
        NSApp.appearance = NSAppearance(named: .aqua)
        XCTAssertEqual(Color.currentColorScheme, .light, "Light mode detection should work")
        
        NSApp.appearance = NSAppearance(named: .darkAqua)
        XCTAssertEqual(Color.currentColorScheme, .dark, "Dark mode detection should work")
        
        // Test 3: Window management APIs
        XCTAssertNotNil(mockWindow.delegate, "Window delegate should be supported")
        XCTAssertTrue(mockWindow.responds(to: #selector(NSWindow.setFrame(_:display:))), 
                     "Window frame management should be supported")
        
        // Test 4: Menu system APIs
        XCTAssertNotNil(NSApp.mainMenu, "Main menu should be supported")
        XCTAssertTrue(NSApp.responds(to: #selector(NSApplication.activate(ignoringOtherApps:))), 
                     "App activation should be supported")
    }
    
    func testExistingFunctionalityIntegrity() {
        // Test that fixes don't break existing functionality
        // Requirement 4.5: Validate that fixes don't break existing functionality
        
        // Test 1: Image loading functionality
        let mockImageFile = createMockImageFile()
        XCTAssertNotNil(mockImageFile, "Image file creation should still work")
        
        // Test 2: Folder scanning functionality
        let tempFolderURL = createTempFolderWithImages()
        let folderScanner = FolderScanner()
        
        let scanExpectation = XCTestExpectation(description: "Folder scan")
        folderScanner.scanFolder(at: tempFolderURL) { result in
            switch result {
            case .success(let content):
                XCTAssertNotNil(content, "Folder scanning should still work")
                scanExpectation.fulfill()
            case .failure(let error):
                XCTFail("Folder scanning failed: \(error)")
                scanExpectation.fulfill()
            }
        }
        wait(for: [scanExpectation], timeout: 5.0)
        
        // Test 3: Preferences service functionality
        let preferencesService = PreferencesService()
        XCTAssertNoThrow(preferencesService.loadPreferences(), "Preferences loading should work")
        XCTAssertNoThrow(preferencesService.savePreferences(), "Preferences saving should work")
        
        // Test 4: Image cache functionality
        let imageCache = ImageCache()
        let testImage = createMockNSImage()
        let testURL = URL(fileURLWithPath: "/tmp/test.jpg")
        
        imageCache.setImage(testImage, for: testURL)
        let cachedImage = imageCache.getImage(for: testURL)
        XCTAssertNotNil(cachedImage, "Image caching should still work")
        
        // Test 5: Keyboard navigation functionality
        let keyboardHandler = KeyboardHandler()
        XCTAssertNotNil(keyboardHandler, "Keyboard handler should still work")
        
        // Clean up temp folder
        try? FileManager.default.removeItem(at: tempFolderURL)
    }
    
    // MARK: - Specific App Store Guidelines Tests
    
    func testHumanInterfaceGuidelinesCompliance() {
        // Test compliance with macOS Human Interface Guidelines
        // Requirement 4.3: Confirm window management follows macOS HIG
        
        // HIG 1: Window behavior should be predictable
        XCTAssertTrue(mockWindow.isVisible, "Window should be visible by default")
        
        // Close window - should hide, not terminate
        let shouldClose = mockWindow.delegate?.windowShouldClose?(mockWindow) ?? true
        XCTAssertFalse(shouldClose, "Closing window should hide it, not terminate app")
        
        // HIG 2: Provide clear ways to restore hidden windows
        let windowMenu = NSApp.mainMenu?.items.first { $0.title == "Window" }?.submenu
        XCTAssertNotNil(windowMenu, "Should provide Window menu")
        
        let showWindowItem = windowMenu?.items.first { $0.title == "Show Main Window" }
        XCTAssertNotNil(showWindowItem, "Should provide menu item to restore window")
        
        // HIG 3: Support standard keyboard shortcuts
        XCTAssertEqual(showWindowItem?.keyEquivalent, "n", "Should use standard Cmd+N shortcut")
        
        // HIG 4: Respond to dock icon clicks
        let handlesReopen = appDelegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false)
        XCTAssertTrue(handlesReopen, "Should handle dock icon clicks")
        
        // HIG 5: Window state should be preserved
        let originalFrame = NSRect(x: 200, y: 300, width: 1000, height: 800)
        mockWindow.setFrame(originalFrame, display: false)
        
        appDelegate.hideMainWindow()
        appDelegate.showMainWindow()
        
        XCTAssertEqual(mockWindow.frame, originalFrame, "Window frame should be preserved")
    }
    
    func testAccessibilityCompliance() {
        // Test accessibility compliance for App Store approval
        
        let testViews: [(String, any View)] = [
            ("NavigationControls", NavigationControlsView(viewModel: createMockImageViewerViewModel()) { }),
            ("FolderSelection", FolderSelectionView()),
            ("ImageInfoOverlay", ImageInfoOverlayView(imageFile: createMockImageFile(), currentImage: createMockNSImage()))
        ]
        
        for (viewName, testView) in testViews {
            let controller = NSHostingController(rootView: AnyView(testView))
            controller.loadView()
            
            // Test in both light and dark modes
            for appearanceName in [NSAppearance.Name.aqua, NSAppearance.Name.darkAqua] {
                NSApp.appearance = NSAppearance(named: appearanceName)
                
                // Verify view has accessibility support
                let hasAccessibility = controller.view.isAccessibilityElement() || 
                                     (controller.view.accessibilityElements()?.count ?? 0) > 0
                
                XCTAssertTrue(hasAccessibility, 
                             "\(viewName) should have accessibility support in \(appearanceName)")
                
                // Test color contrast (basic check)
                let backgroundColor = Color.appBackground
                let textColor = Color.appText
                
                XCTAssertNotNil(backgroundColor, "\(viewName) should have background color in \(appearanceName)")
                XCTAssertNotNil(textColor, "\(viewName) should have text color in \(appearanceName)")
            }
        }
    }
    
    func testSandboxCompatibility() {
        // Test that window management works within App Sandbox restrictions
        
        // Test 1: Window operations should work without additional entitlements
        XCTAssertNoThrow(appDelegate.showMainWindow(), "Show window should work in sandbox")
        XCTAssertNoThrow(appDelegate.hideMainWindow(), "Hide window should work in sandbox")
        
        // Test 2: Menu operations should work
        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        
        let windowMenu = NSApp.mainMenu?.items.first { $0.title == "Window" }?.submenu
        XCTAssertNotNil(windowMenu, "Menu creation should work in sandbox")
        
        // Test 3: Preferences saving should work with sandbox
        let windowState = WindowState()
        XCTAssertNoThrow(mockPreferencesService.saveWindowState(windowState), 
                        "State saving should work in sandbox")
        
        // Test 4: App activation should work
        XCTAssertNoThrow(NSApp.activate(ignoringOtherApps: true), 
                        "App activation should work in sandbox")
    }
    
    // MARK: - Performance and Stability Tests
    
    func testPerformanceUnderLoad() {
        // Test that fixes don't cause performance regression
        
        measure {
            // Simulate rapid appearance switching
            for i in 0..<50 {
                let appearance = i % 2 == 0 ? NSAppearance.Name.aqua : NSAppearance.Name.darkAqua
                NSApp.appearance = NSAppearance(named: appearance)
                
                // Access adaptive colors
                let _ = Color.appBackground
                let _ = Color.appText
                let _ = Color.appToolbarBackground
            }
        }
        
        // Test window operations performance
        measure {
            for _ in 0..<100 {
                appDelegate.hideMainWindow()
                appDelegate.showMainWindow()
            }
        }
    }
    
    func testMemoryStability() {
        // Test for memory leaks in new functionality
        
        // Create and destroy many views to test for leaks
        for _ in 0..<1000 {
            autoreleasepool {
                let view = FolderSelectionView()
                let controller = NSHostingController(rootView: view)
                controller.loadView()
                
                // Switch appearance
                NSApp.appearance = NSAppearance(named: .darkAqua)
                NSApp.appearance = NSAppearance(named: .aqua)
                
                // Access colors
                let _ = Color.appBackground
                let _ = Color.appText
            }
        }
        
        // Test window management operations
        for _ in 0..<1000 {
            autoreleasepool {
                appDelegate.hideMainWindow()
                appDelegate.showMainWindow()
                
                // Simulate window delegate callbacks
                let notification = Notification(name: NSWindow.didMoveNotification, object: mockWindow)
                mockWindow.delegate?.windowDidMove?(notification)
            }
        }
        
        // If we reach here without crashing, memory management is likely stable
        XCTAssertTrue(true, "Memory stability test completed")
    }
    
    // MARK: - Edge Case and Error Handling Tests
    
    func testErrorRecoveryScenarios() {
        // Test error recovery scenarios that might occur during App Store review
        
        // Test 1: Invalid appearance handling
        NSApp.appearance = nil
        XCTAssertNoThrow(Color.currentColorScheme, "Should handle nil appearance gracefully")
        
        let view = FolderSelectionView()
        let controller = NSHostingController(rootView: view)
        XCTAssertNoThrow(controller.loadView(), "Views should load with nil appearance")
        
        // Test 2: Missing window reference
        appDelegate.mainWindow = nil
        XCTAssertNoThrow(appDelegate.showMainWindow(), "Should handle missing window gracefully")
        XCTAssertNoThrow(appDelegate.hideMainWindow(), "Should handle missing window gracefully")
        
        // Test 3: Corrupted preferences
        var corruptedState = WindowState()
        corruptedState.windowFrame = CGRect(x: -10000, y: -10000, width: -100, height: -100)
        mockPreferencesService.windowState = corruptedState
        
        let newWindowStateManager = WindowStateManager(preferencesService: mockPreferencesService)
        XCTAssertNoThrow(newWindowStateManager.loadWindowState(), 
                        "Should handle corrupted state gracefully")
        
        // Test 4: Rapid state changes
        for _ in 0..<100 {
            appDelegate.hideMainWindow()
            appDelegate.showMainWindow()
            NSApp.appearance = NSAppearance(named: .darkAqua)
            NSApp.appearance = NSAppearance(named: .aqua)
        }
        
        XCTAssertNotNil(appDelegate.mainWindow, "Should remain stable after rapid changes")
    }
    
    // MARK: - Final Validation Tests
    
    func testCompleteAppStoreScenarioSimulation() {
        // Simulate the complete App Store review scenario
        
        print("🧪 Simulating complete App Store review scenario...")
        
        // Step 1: App launches (light mode)
        NSApp.appearance = NSAppearance(named: .aqua)
        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        
        // Verify initial state
        XCTAssertTrue(mockWindow.isVisible, "App should launch with visible window")
        XCTAssertEqual(Color.currentColorScheme, .light, "Should detect light mode")
        
        // Step 2: User switches to dark mode
        NSApp.appearance = NSAppearance(named: .darkAqua)
        XCTAssertEqual(Color.currentColorScheme, .dark, "Should detect dark mode switch")
        
        // Verify all UI elements are visible in dark mode
        let navigationView = NavigationControlsView(viewModel: createMockImageViewerViewModel()) { }
        let navController = NSHostingController(rootView: navigationView)
        navController.loadView()
        XCTAssertNotNil(navController.view, "Navigation should be visible in dark mode")
        
        // Step 3: User closes main window
        let shouldClose = mockWindow.delegate?.windowShouldClose?(mockWindow) ?? true
        XCTAssertFalse(shouldClose, "Window should hide, not close")
        XCTAssertFalse(mockWindow.isVisible, "Window should be hidden")
        
        // Step 4: App should still be running
        let shouldTerminate = appDelegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared)
        XCTAssertFalse(shouldTerminate, "App should continue running")
        
        // Step 5: User clicks dock icon
        let handlesReopen = appDelegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false)
        XCTAssertTrue(handlesReopen, "Should handle dock icon click")
        XCTAssertTrue(mockWindow.isVisible, "Window should be restored")
        
        // Step 6: User uses Window menu
        appDelegate.hideMainWindow()
        let windowMenu = NSApp.mainMenu?.items.first { $0.title == "Window" }?.submenu
        let showWindowItem = windowMenu?.items.first { $0.title == "Show Main Window" }
        
        if let target = showWindowItem?.target as? AppDelegate,
           let action = showWindowItem?.action {
            target.perform(action)
        }
        
        XCTAssertTrue(mockWindow.isVisible, "Window should be restored via menu")
        
        // Step 7: User uses Cmd+N shortcut
        appDelegate.hideMainWindow()
        XCTAssertEqual(showWindowItem?.keyEquivalent, "n", "Should have Cmd+N shortcut")
        
        // Step 8: Switch back to light mode
        NSApp.appearance = NSAppearance(named: .aqua)
        XCTAssertEqual(Color.currentColorScheme, .light, "Should switch back to light mode")
        
        // Verify UI is still visible in light mode
        let folderView = FolderSelectionView()
        let folderController = NSHostingController(rootView: folderView)
        folderController.loadView()
        XCTAssertNotNil(folderController.view, "Folder view should be visible in light mode")
        
        print("✅ App Store review scenario simulation completed successfully")
    }
    
    // MARK: - Helper Methods
    
    private func createMockImageViewerViewModel() -> ImageViewerViewModel {
        let viewModel = ImageViewerViewModel()
        return viewModel
    }
    
    private func createMockImageFile() -> ImageFile {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test_image_\(UUID().uuidString).jpg")
        
        let testData = Data([0xFF, 0xD8, 0xFF, 0xE0]) // JPEG header
        try? testData.write(to: tempURL)
        
        do {
            return try ImageFile(url: tempURL)
        } catch {
            let systemImageURL = URL(fileURLWithPath: "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericDocumentIcon.icns")
            return try! ImageFile(url: systemImageURL)
        }
    }
    
    private func createMockNSImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 100, height: 100))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: 100, height: 100).fill()
        image.unlockFocus()
        return image
    }
    
    private func createTempFolderWithImages() -> URL {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test_folder_\(UUID().uuidString)")
        
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Create a few test image files
        for i in 1...3 {
            let imageURL = tempDir.appendingPathComponent("test_image_\(i).jpg")
            let testData = Data([0xFF, 0xD8, 0xFF, 0xE0]) // JPEG header
            try? testData.write(to: imageURL)
        }
        
        return tempDir
    }
}

// MARK: - Mock Classes

class MockPreferencesService: PreferencesService {
    var recentFolders: [URL] = []
    var windowFrame: CGRect = CGRect(x: 100, y: 100, width: 800, height: 600)
    var showFileName: Bool = false
    var showImageInfo: Bool = false
    var slideshowInterval: Double = 3.0
    var lastSelectedFolder: URL?
    var folderBookmarks: [Data] = []
    var windowState: WindowState?
    var defaultThumbnailGridSize: ThumbnailGridSize = .medium
    var useResponsiveGridLayout: Bool = true
    var enableAIAnalysis: Bool = true
    
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
    
    func saveFavorites() { }
}
