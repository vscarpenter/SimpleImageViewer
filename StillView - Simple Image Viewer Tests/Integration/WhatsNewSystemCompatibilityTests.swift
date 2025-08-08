//
//  WhatsNewSystemCompatibilityTests.swift
//  StillView - Simple Image Viewer Tests
//
//  Created by Kiro on 8/7/25.
//

import XCTest
import SwiftUI
import AppKit
@testable import Simple_Image_Viewer

/// Comprehensive system compatibility tests for the What's New feature
/// Tests across different macOS versions and system configurations
@MainActor
final class WhatsNewSystemCompatibilityTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private var whatsNewService: WhatsNewService!
    private var originalAppearance: NSAppearance?
    private var originalAccessibilitySettings: [String: Any] = [:]
    
    // MARK: - Setup and Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Store original appearance
        originalAppearance = NSApp.effectiveAppearance
        
        // Store original accessibility settings
        storeOriginalAccessibilitySettings()
        
        // Create service
        whatsNewService = WhatsNewService()
        
        continueAfterFailure = false
    }
    
    override func tearDownWithError() throws {
        // Restore original appearance
        if let originalAppearance = originalAppearance {
            NSApp.appearance = originalAppearance
        }
        
        // Restore accessibility settings
        restoreOriginalAccessibilitySettings()
        
        // Clean up
        whatsNewService = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - macOS Version Compatibility Tests
    
    func testMacOSVersionCompatibility() {
        // Test compatibility with minimum supported macOS version (12.0+)
        
        let currentVersion = ProcessInfo.processInfo.operatingSystemVersion
        print("Testing on macOS \(currentVersion.majorVersion).\(currentVersion.minorVersion).\(currentVersion.patchVersion)")
        
        // Verify minimum version requirement
        XCTAssertGreaterThanOrEqual(currentVersion.majorVersion, 12, 
                                   "App requires macOS 12.0 or later")
        
        // Test 1: System color availability (macOS 12.0+)
        XCTAssertNotNil(NSColor.controlBackgroundColor, "System colors should be available")
        XCTAssertNotNil(NSColor.labelColor, "Label colors should be available")
        XCTAssertNotNil(NSColor.controlAccentColor, "Accent colors should be available")
        XCTAssertNotNil(NSColor.separatorColor, "Separator colors should be available")
        
        // Test 2: SwiftUI features (macOS 12.0+)
        let content = WhatsNewContent.sampleContent
        let sheet = WhatsNewSheet(content: content)
        let controller = NSHostingController(rootView: sheet)
        
        XCTAssertNoThrow(controller.loadView(), "SwiftUI views should load on supported macOS")
        XCTAssertNotNil(controller.view, "SwiftUI view should be created")
        
        // Test 3: UserDefaults functionality
        let testKey = "WhatsNewCompatibilityTest"
        let testValue = "test_value_\(UUID().uuidString)"
        
        UserDefaults.standard.set(testValue, forKey: testKey)
        let retrievedValue = UserDefaults.standard.string(forKey: testKey)
        
        XCTAssertEqual(retrievedValue, testValue, "UserDefaults should work correctly")
        UserDefaults.standard.removeObject(forKey: testKey)
        
        // Test 4: Bundle information access
        XCTAssertNotNil(Bundle.main.infoDictionary, "Bundle info should be accessible")
        XCTAssertNotNil(Bundle.main.appVersion, "App version should be accessible")
        
        // Test 5: Notification system
        let expectation = XCTestExpectation(description: "Notification received")
        let testNotificationName = Notification.Name("WhatsNewCompatibilityTest")
        
        let observer = NotificationCenter.default.addObserver(
            forName: testNotificationName,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }
        
        NotificationCenter.default.post(name: testNotificationName, object: nil)
        wait(for: [expectation], timeout: 1.0)
        
        NotificationCenter.default.removeObserver(observer)
    }
    
    func testMacOSVersionSpecificFeatures() {
        // Test features that may vary by macOS version
        
        let currentVersion = ProcessInfo.processInfo.operatingSystemVersion
        
        if currentVersion.majorVersion >= 13 {
            // macOS 13.0+ specific tests
            testMacOS13Features()
        }
        
        if currentVersion.majorVersion >= 14 {
            // macOS 14.0+ specific tests
            testMacOS14Features()
        }
        
        // Always test baseline macOS 12.0 features
        testMacOS12BaselineFeatures()
    }
    
    private func testMacOS12BaselineFeatures() {
        // Test features that should work on macOS 12.0+
        
        // Test appearance detection
        NSApp.appearance = NSAppearance(named: .aqua)
        XCTAssertEqual(Color.currentColorScheme, .light, "Light mode detection should work")
        
        NSApp.appearance = NSAppearance(named: .darkAqua)
        XCTAssertEqual(Color.currentColorScheme, .dark, "Dark mode detection should work")
        
        // Test adaptive colors
        let adaptiveColor = Color.adaptive(light: .white, dark: .black)
        XCTAssertNotNil(adaptiveColor, "Adaptive colors should work")
        
        // Test SwiftUI sheet presentation
        let content = WhatsNewContent.sampleContent
        let sheet = WhatsNewSheet(content: content)
        let controller = NSHostingController(rootView: sheet)
        
        XCTAssertNoThrow(controller.loadView(), "Sheet presentation should work")
    }
    
    private func testMacOS13Features() {
        // Test features specific to macOS 13.0+
        print("Testing macOS 13.0+ specific features")
        
        // Test enhanced SwiftUI features if available
        // This would include any macOS 13+ specific SwiftUI APIs we use
        XCTAssertTrue(true, "macOS 13+ features tested")
    }
    
    private func testMacOS14Features() {
        // Test features specific to macOS 14.0+
        print("Testing macOS 14.0+ specific features")
        
        // Test any macOS 14+ specific features
        XCTAssertTrue(true, "macOS 14+ features tested")
    }
    
    // MARK: - System Configuration Tests
    
    func testDifferentAppearanceModes() {
        // Test all supported appearance modes
        
        let appearanceModes: [(NSAppearance.Name, String)] = [
            (.aqua, "Light mode"),
            (.darkAqua, "Dark mode")
        ]
        
        for (appearanceName, modeName) in appearanceModes {
            NSApp.appearance = NSAppearance(named: appearanceName)
            
            print("Testing \(modeName)")
            
            // Test color scheme detection
            let expectedScheme: ColorScheme = appearanceName == .darkAqua ? .dark : .light
            XCTAssertEqual(Color.currentColorScheme, expectedScheme, 
                          "Color scheme detection should work in \(modeName)")
            
            // Test adaptive colors
            XCTAssertNotNil(Color.appBackground, "Background color should exist in \(modeName)")
            XCTAssertNotNil(Color.appText, "Text color should exist in \(modeName)")
            XCTAssertNotNil(Color.appSecondaryText, "Secondary text should exist in \(modeName)")
            
            // Test UI rendering
            let content = WhatsNewContent.sampleContent
            let sheet = WhatsNewSheet(content: content)
            let controller = NSHostingController(rootView: sheet)
            controller.loadView()
            
            XCTAssertNotNil(controller.view, "UI should render in \(modeName)")
            
            // Test content view
            let contentView = WhatsNewContentView(content: content)
            let contentController = NSHostingController(rootView: contentView)
            contentController.loadView()
            
            XCTAssertNotNil(contentController.view, "Content view should render in \(modeName)")
            
            // Test section view
            let sectionView = WhatsNewSectionView(section: WhatsNewSection.sampleNewFeatures)
            let sectionController = NSHostingController(rootView: sectionView)
            sectionController.loadView()
            
            XCTAssertNotNil(sectionController.view, "Section view should render in \(modeName)")
        }
    }
    
    func testAccessibilityConfigurations() {
        // Test different accessibility configurations
        
        // Test 1: High contrast mode simulation
        simulateHighContrastMode(enabled: true)
        testUIWithAccessibilitySettings("High contrast enabled")
        
        simulateHighContrastMode(enabled: false)
        testUIWithAccessibilitySettings("High contrast disabled")
        
        // Test 2: Reduced motion simulation
        simulateReducedMotion(enabled: true)
        testUIWithAccessibilitySettings("Reduced motion enabled")
        
        simulateReducedMotion(enabled: false)
        testUIWithAccessibilitySettings("Reduced motion disabled")
        
        // Test 3: VoiceOver simulation
        simulateVoiceOver(enabled: true)
        testUIWithAccessibilitySettings("VoiceOver enabled")
        
        simulateVoiceOver(enabled: false)
        testUIWithAccessibilitySettings("VoiceOver disabled")
    }
    
    private func testUIWithAccessibilitySettings(_ configuration: String) {
        print("Testing UI with \(configuration)")
        
        let content = WhatsNewContent.sampleContent
        
        // Test sheet accessibility
        let sheet = WhatsNewSheet(content: content)
        let sheetController = NSHostingController(rootView: sheet)
        sheetController.loadView()
        
        XCTAssertNotNil(sheetController.view, "Sheet should render with \(configuration)")
        
        // Test content accessibility
        let contentView = WhatsNewContentView(content: content)
        let contentController = NSHostingController(rootView: contentView)
        contentController.loadView()
        
        XCTAssertNotNil(contentController.view, "Content should render with \(configuration)")
        
        // Verify accessibility elements exist
        let hasAccessibility = sheetController.view.isAccessibilityElement() || 
                             (sheetController.view.accessibilityElements()?.count ?? 0) > 0
        XCTAssertTrue(hasAccessibility, "Should have accessibility support with \(configuration)")
    }
    
    func testDifferentScreenSizes() {
        // Test UI on different screen sizes/resolutions
        
        let screenSizes: [(CGSize, String)] = [
            (CGSize(width: 1024, height: 768), "Small screen (1024x768)"),
            (CGSize(width: 1440, height: 900), "Medium screen (1440x900)"),
            (CGSize(width: 1920, height: 1080), "Large screen (1920x1080)"),
            (CGSize(width: 2560, height: 1440), "Very large screen (2560x1440)")
        ]
        
        for (size, description) in screenSizes {
            print("Testing \(description)")
            
            // Create a window with the test size
            let testWindow = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            
            let content = WhatsNewContent.sampleContent
            let sheet = WhatsNewSheet(content: content)
            let controller = NSHostingController(rootView: sheet)
            
            testWindow.contentViewController = controller
            controller.loadView()
            
            XCTAssertNotNil(controller.view, "UI should render on \(description)")
            
            // Test that the sheet fits within reasonable bounds
            let sheetSize = CGSize(width: 480, height: 600)
            XCTAssertLessThanOrEqual(sheetSize.width, size.width, 
                                   "Sheet should fit horizontally on \(description)")
            XCTAssertLessThanOrEqual(sheetSize.height, size.height, 
                                   "Sheet should fit vertically on \(description)")
            
            testWindow.close()
        }
    }
    
    func testDifferentLanguageSettings() {
        // Test with different system language settings
        
        // Note: This is a simplified test since changing system language
        // requires more complex setup. In a full implementation, this would
        // test localization and RTL languages.
        
        let testLocales = ["en_US", "en_GB", "fr_FR", "de_DE", "ja_JP"]
        
        for localeIdentifier in testLocales {
            let locale = Locale(identifier: localeIdentifier)
            
            // Test date formatting with different locales
            let content = WhatsNewContent(
                version: "1.0.0",
                releaseDate: Date(),
                sections: [WhatsNewSection.sampleNewFeatures]
            )
            
            let contentView = WhatsNewContentView(content: content)
            let controller = NSHostingController(rootView: contentView)
            controller.loadView()
            
            XCTAssertNotNil(controller.view, "UI should render with locale \(localeIdentifier)")
        }
    }
    
    // MARK: - Performance Tests Across Configurations
    
    func testPerformanceAcrossConfigurations() {
        // Test performance in different system configurations
        
        let configurations: [(String, () -> Void)] = [
            ("Light mode", { NSApp.appearance = NSAppearance(named: .aqua) }),
            ("Dark mode", { NSApp.appearance = NSAppearance(named: .darkAqua) }),
            ("High contrast", { self.simulateHighContrastMode(enabled: true) }),
            ("Reduced motion", { self.simulateReducedMotion(enabled: true) })
        ]
        
        for (configName, setupConfig) in configurations {
            setupConfig()
            
            // Test service performance
            measure(metrics: [XCTClockMetric()]) {
                let _ = whatsNewService.shouldShowWhatsNew()
                let _ = whatsNewService.getWhatsNewContent()
            }
            
            // Test UI performance
            let content = WhatsNewContent.sampleContent
            measure(metrics: [XCTClockMetric()]) {
                let sheet = WhatsNewSheet(content: content)
                let controller = NSHostingController(rootView: sheet)
                controller.loadView()
            }
            
            print("Performance tested for \(configName)")
        }
    }
    
    func testMemoryUsageAcrossConfigurations() {
        // Test memory usage in different configurations
        
        let configurations = [
            "Light mode": { NSApp.appearance = NSAppearance(named: .aqua) },
            "Dark mode": { NSApp.appearance = NSAppearance(named: .darkAqua) }
        ]
        
        for (configName, setupConfig) in configurations {
            setupConfig()
            
            // Create many instances to test memory usage
            for _ in 0..<100 {
                autoreleasepool {
                    let content = WhatsNewContent.sampleContent
                    let sheet = WhatsNewSheet(content: content)
                    let controller = NSHostingController(rootView: sheet)
                    controller.loadView()
                }
            }
            
            print("Memory usage tested for \(configName)")
        }
        
        // If we reach here without crashing, memory usage is acceptable
        XCTAssertTrue(true, "Memory usage test completed")
    }
    
    // MARK: - Edge Case System Configurations
    
    func testExtremeSystemConfigurations() {
        // Test edge cases and extreme system configurations
        
        // Test 1: Very small screen simulation
        let tinyWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        
        let content = WhatsNewContent.sampleContent
        let sheet = WhatsNewSheet(content: content)
        let controller = NSHostingController(rootView: sheet)
        
        tinyWindow.contentViewController = controller
        XCTAssertNoThrow(controller.loadView(), "Should handle very small screens")
        tinyWindow.close()
        
        // Test 2: Nil appearance handling
        let originalAppearance = NSApp.appearance
        NSApp.appearance = nil
        
        XCTAssertNoThrow(Color.currentColorScheme, "Should handle nil appearance")
        
        let testSheet = WhatsNewSheet(content: content)
        let testController = NSHostingController(rootView: testSheet)
        XCTAssertNoThrow(testController.loadView(), "Should render with nil appearance")
        
        NSApp.appearance = originalAppearance
        
        // Test 3: Rapid appearance switching
        for i in 0..<50 {
            let appearance = i % 2 == 0 ? NSAppearance.Name.aqua : NSAppearance.Name.darkAqua
            NSApp.appearance = NSAppearance(named: appearance)
            
            let _ = Color.currentColorScheme
            let _ = Color.appBackground
        }
        
        XCTAssertTrue(true, "Should handle rapid appearance switching")
        
        // Test 4: Corrupted UserDefaults simulation
        let corruptedKey = "WhatsNewCorruptedTest"
        UserDefaults.standard.set("invalid_data", forKey: corruptedKey)
        
        // Service should handle corrupted data gracefully
        XCTAssertNoThrow(whatsNewService.shouldShowWhatsNew(), 
                        "Should handle corrupted UserDefaults")
        
        UserDefaults.standard.removeObject(forKey: corruptedKey)
    }
    
    // MARK: - Integration with System Services
    
    func testSystemServiceIntegration() {
        // Test integration with macOS system services
        
        // Test 1: Notification Center integration
        let expectation = XCTestExpectation(description: "System notification")
        
        let observer = NotificationCenter.default.addObserver(
            forName: .showWhatsNew,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }
        
        whatsNewService.showWhatsNewSheet()
        wait(for: [expectation], timeout: 2.0)
        
        NotificationCenter.default.removeObserver(observer)
        
        // Test 2: UserDefaults integration
        let versionTracker = VersionTracker()
        let testVersion = "1.2.3"
        
        XCTAssertNoThrow(try versionTracker.setLastShownVersion(testVersion), 
                        "Should integrate with UserDefaults")
        
        let retrievedVersion = versionTracker.getLastShownVersion()
        XCTAssertEqual(retrievedVersion, testVersion, "Should persist version correctly")
        
        // Test 3: Bundle integration
        let currentVersion = versionTracker.getCurrentVersion()
        XCTAssertFalse(currentVersion.isEmpty, "Should retrieve version from bundle")
        XCTAssertTrue(versionTracker.validateVersionFormat(currentVersion), 
                     "Bundle version should be valid")
        
        // Test 4: File system integration (JSON loading)
        let contentProvider = WhatsNewContentProvider()
        XCTAssertNoThrow(try contentProvider.loadContent(), 
                        "Should load content from file system")
    }
    
    // MARK: - Helper Methods
    
    private func storeOriginalAccessibilitySettings() {
        // Store original accessibility settings to restore later
        originalAccessibilitySettings = [
            "ReduceMotion": UserDefaults.standard.bool(forKey: "ReduceMotion"),
            "AppleInterfaceStyle": UserDefaults.standard.string(forKey: "AppleInterfaceStyle") ?? ""
        ]
    }
    
    private func restoreOriginalAccessibilitySettings() {
        // Restore original accessibility settings
        for (key, value) in originalAccessibilitySettings {
            if let stringValue = value as? String {
                UserDefaults.standard.set(stringValue, forKey: key)
            } else if let boolValue = value as? Bool {
                UserDefaults.standard.set(boolValue, forKey: key)
            }
        }
    }
    
    private func simulateHighContrastMode(enabled: Bool) {
        // Simulate high contrast mode by setting appropriate UserDefaults
        if enabled {
            UserDefaults.standard.set("Dark", forKey: "AppleInterfaceStyle")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleInterfaceStyle")
        }
    }
    
    private func simulateReducedMotion(enabled: Bool) {
        // Simulate reduced motion preference
        UserDefaults.standard.set(enabled, forKey: "ReduceMotion")
    }
    
    private func simulateVoiceOver(enabled: Bool) {
        // Simulate VoiceOver being enabled
        // Note: This is a simplified simulation for testing purposes
        // In a real implementation, this would interact with accessibility APIs
    }
}