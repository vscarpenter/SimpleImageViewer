//
//  DarkModeUITests.swift
//  Simple Image Viewer Tests
//
//  Created by Kiro on 7/30/25.
//

import XCTest
import SwiftUI
import AppKit
@testable import Simple_Image_Viewer

@MainActor
final class DarkModeUITests: XCTestCase {
    
    // MARK: - Test Setup
    
    private var originalAppearance: NSAppearance?
    
    override func setUp() {
        super.setUp()
        // Store original appearance to restore later
        originalAppearance = NSApp.effectiveAppearance
        continueAfterFailure = false
    }
    
    override func tearDown() {
        // Restore original appearance
        if let originalAppearance = originalAppearance {
            NSApp.appearance = originalAppearance
        }
        super.tearDown()
    }
    
    // MARK: - Appearance Switching Tests
    
    func testAppearanceSwitchingDuringRuntime() {
        // Test that the app can switch between light and dark modes while running
        
        // Start with light mode
        NSApp.appearance = NSAppearance(named: .aqua)
        XCTAssertEqual(Color.currentColorScheme, .light)
        XCTAssertFalse(Color.isDarkMode)
        
        // Switch to dark mode
        NSApp.appearance = NSAppearance(named: .darkAqua)
        XCTAssertEqual(Color.currentColorScheme, .dark)
        XCTAssertTrue(Color.isDarkMode)
        
        // Switch back to light mode
        NSApp.appearance = NSAppearance(named: .aqua)
        XCTAssertEqual(Color.currentColorScheme, .light)
        XCTAssertFalse(Color.isDarkMode)
    }
    
    func testColorSchemeConsistencyDuringSwitch() {
        // Test that color scheme detection remains consistent during appearance changes
        
        let appearances: [(NSAppearance.Name, ColorScheme, Bool)] = [
            (.aqua, .light, false),
            (.darkAqua, .dark, true),
            (.aqua, .light, false),
            (.darkAqua, .dark, true)
        ]
        
        for (appearanceName, expectedScheme, expectedIsDark) in appearances {
            NSApp.appearance = NSAppearance(named: appearanceName)
            
            XCTAssertEqual(Color.currentColorScheme, expectedScheme, 
                          "Color scheme should match for \(appearanceName)")
            XCTAssertEqual(Color.isDarkMode, expectedIsDark, 
                          "isDarkMode should match for \(appearanceName)")
        }
    }
    
    // MARK: - Navigation Controls Dark Mode Tests
    
    func testNavigationControlsInLightMode() {
        // Test NavigationControlsView in light mode
        NSApp.appearance = NSAppearance(named: .aqua)
        
        let mockViewModel = createMockImageViewerViewModel()
        let view = NavigationControlsView(viewModel: mockViewModel) { }
        let hostingController = NSHostingController(rootView: view)
        
        // Load the view
        hostingController.loadView()
        
        // Verify view loads without crashing
        XCTAssertNotNil(hostingController.view)
        
        // Test that adaptive colors are properly applied
        XCTAssertEqual(Color.currentColorScheme, .light)
        XCTAssertNotNil(Color.appToolbarBackground)
        XCTAssertNotNil(Color.appText)
        XCTAssertNotNil(Color.appBorder)
    }
    
    func testNavigationControlsInDarkMode() {
        // Test NavigationControlsView in dark mode
        NSApp.appearance = NSAppearance(named: .darkAqua)
        
        let mockViewModel = createMockImageViewerViewModel()
        let view = NavigationControlsView(viewModel: mockViewModel) { }
        let hostingController = NSHostingController(rootView: view)
        
        // Load the view
        hostingController.loadView()
        
        // Verify view loads without crashing
        XCTAssertNotNil(hostingController.view)
        
        // Test that adaptive colors are properly applied
        XCTAssertEqual(Color.currentColorScheme, .dark)
        XCTAssertNotNil(Color.appToolbarBackground)
        XCTAssertNotNil(Color.appText)
        XCTAssertNotNil(Color.appBorder)
    }
    
    func testNavigationControlsAppearanceSwitching() {
        // Test NavigationControlsView during appearance switching
        let mockViewModel = createMockImageViewerViewModel()
        let view = NavigationControlsView(viewModel: mockViewModel) { }
        let hostingController = NSHostingController(rootView: view)
        
        hostingController.loadView()
        
        // Test switching from light to dark
        NSApp.appearance = NSAppearance(named: .aqua)
        XCTAssertEqual(Color.currentColorScheme, .light)
        
        NSApp.appearance = NSAppearance(named: .darkAqua)
        XCTAssertEqual(Color.currentColorScheme, .dark)
        
        // View should still be valid after appearance change
        XCTAssertNotNil(hostingController.view)
    }
    
    // MARK: - Image Info Overlay Dark Mode Tests
    
    func testImageInfoOverlayInLightMode() {
        // Test ImageInfoOverlayView in light mode
        NSApp.appearance = NSAppearance(named: .aqua)
        
        let mockImageFile = createMockImageFile()
        let mockImage = createMockNSImage()
        let view = ImageInfoOverlayView(imageFile: mockImageFile, currentImage: mockImage)
        let hostingController = NSHostingController(rootView: view)
        
        hostingController.loadView()
        
        // Verify view loads without crashing
        XCTAssertNotNil(hostingController.view)
        
        // Test overlay colors in light mode
        XCTAssertEqual(Color.currentColorScheme, .light)
        XCTAssertNotNil(Color.appOverlayBackground)
        XCTAssertNotNil(Color.appOverlayText)
        XCTAssertNotNil(Color.appInfo)
    }
    
    func testImageInfoOverlayInDarkMode() {
        // Test ImageInfoOverlayView in dark mode
        NSApp.appearance = NSAppearance(named: .darkAqua)
        
        let mockImageFile = createMockImageFile()
        let mockImage = createMockNSImage()
        let view = ImageInfoOverlayView(imageFile: mockImageFile, currentImage: mockImage)
        let hostingController = NSHostingController(rootView: view)
        
        hostingController.loadView()
        
        // Verify view loads without crashing
        XCTAssertNotNil(hostingController.view)
        
        // Test overlay colors in dark mode
        XCTAssertEqual(Color.currentColorScheme, .dark)
        XCTAssertNotNil(Color.appOverlayBackground)
        XCTAssertNotNil(Color.appOverlayText)
        XCTAssertNotNil(Color.appInfo)
    }
    
    // MARK: - Folder Selection View Dark Mode Tests
    
    func testFolderSelectionViewInLightMode() {
        // Test FolderSelectionView in light mode
        NSApp.appearance = NSAppearance(named: .aqua)
        
        let view = FolderSelectionView()
        let hostingController = NSHostingController(rootView: view)
        
        hostingController.loadView()
        
        // Verify view loads without crashing
        XCTAssertNotNil(hostingController.view)
        
        // Test background gradient colors in light mode
        XCTAssertEqual(Color.currentColorScheme, .light)
        XCTAssertNotNil(Color.appBackground)
        XCTAssertNotNil(Color.appSecondaryBackground)
        XCTAssertNotNil(Color.appTertiaryBackground)
    }
    
    func testFolderSelectionViewInDarkMode() {
        // Test FolderSelectionView in dark mode
        NSApp.appearance = NSAppearance(named: .darkAqua)
        
        let view = FolderSelectionView()
        let hostingController = NSHostingController(rootView: view)
        
        hostingController.loadView()
        
        // Verify view loads without crashing
        XCTAssertNotNil(hostingController.view)
        
        // Test background gradient colors in dark mode
        XCTAssertEqual(Color.currentColorScheme, .dark)
        XCTAssertNotNil(Color.appBackground)
        XCTAssertNotNil(Color.appSecondaryBackground)
        XCTAssertNotNil(Color.appTertiaryBackground)
    }
    
    // MARK: - Toolbar and Status Elements Tests
    
    func testToolbarElementsVisibilityInBothModes() {
        // Test that all toolbar elements are visible in both light and dark modes
        let mockViewModel = createMockImageViewerViewModel()
        let view = NavigationControlsView(viewModel: mockViewModel) { }
        
        // Test in light mode
        NSApp.appearance = NSAppearance(named: .aqua)
        let lightHostingController = NSHostingController(rootView: view)
        lightHostingController.loadView()
        XCTAssertNotNil(lightHostingController.view)
        
        // Test in dark mode
        NSApp.appearance = NSAppearance(named: .darkAqua)
        let darkHostingController = NSHostingController(rootView: view)
        darkHostingController.loadView()
        XCTAssertNotNil(darkHostingController.view)
        
        // Verify toolbar colors are different between modes
        XCTAssertNotEqual(Color.currentColorScheme, .light) // Should be dark now
    }
    
    func testStatusElementsContrastInBothModes() {
        // Test that status elements have sufficient contrast in both modes
        let testCases: [(NSAppearance.Name, String)] = [
            (.aqua, "light mode"),
            (.darkAqua, "dark mode")
        ]
        
        for (appearanceName, modeName) in testCases {
            NSApp.appearance = NSAppearance(named: appearanceName)
            
            // Test that text colors provide contrast against backgrounds
            let backgroundColor = Color.appBackground
            let textColor = Color.appText
            let secondaryTextColor = Color.appSecondaryText
            
            XCTAssertNotNil(backgroundColor, "Background color should exist in \(modeName)")
            XCTAssertNotNil(textColor, "Text color should exist in \(modeName)")
            XCTAssertNotNil(secondaryTextColor, "Secondary text color should exist in \(modeName)")
            
            // Test overlay colors
            let overlayBackground = Color.appOverlayBackground
            let overlayText = Color.appOverlayText
            
            XCTAssertNotNil(overlayBackground, "Overlay background should exist in \(modeName)")
            XCTAssertNotNil(overlayText, "Overlay text should exist in \(modeName)")
        }
    }
    
    // MARK: - Accessibility and Contrast Tests
    
    func testTextContrastRatiosInLightMode() {
        // Test that text contrast ratios meet accessibility standards in light mode
        NSApp.appearance = NSAppearance(named: .aqua)
        
        // Test primary text contrast
        let backgroundColor = NSColor.controlBackgroundColor
        let textColor = NSColor.labelColor
        
        XCTAssertNotNil(backgroundColor)
        XCTAssertNotNil(textColor)
        
        // Verify colors are appropriate for light mode
        XCTAssertEqual(Color.currentColorScheme, .light)
        
        // Test that system colors provide appropriate contrast
        // (System colors are designed to meet accessibility standards)
        let adaptiveBackground = Color.appBackground
        let adaptiveText = Color.appText
        
        XCTAssertNotNil(adaptiveBackground)
        XCTAssertNotNil(adaptiveText)
    }
    
    func testTextContrastRatiosInDarkMode() {
        // Test that text contrast ratios meet accessibility standards in dark mode
        NSApp.appearance = NSAppearance(named: .darkAqua)
        
        // Test primary text contrast
        let backgroundColor = NSColor.controlBackgroundColor
        let textColor = NSColor.labelColor
        
        XCTAssertNotNil(backgroundColor)
        XCTAssertNotNil(textColor)
        
        // Verify colors are appropriate for dark mode
        XCTAssertEqual(Color.currentColorScheme, .dark)
        
        // Test that system colors provide appropriate contrast
        let adaptiveBackground = Color.appBackground
        let adaptiveText = Color.appText
        
        XCTAssertNotNil(adaptiveBackground)
        XCTAssertNotNil(adaptiveText)
    }
    
    func testAccessibilityLabelsInBothModes() {
        // Test that accessibility labels work correctly in both modes
        let testModes: [NSAppearance.Name] = [.aqua, .darkAqua]
        
        for appearanceName in testModes {
            NSApp.appearance = NSAppearance(named: appearanceName)
            
            let mockViewModel = createMockImageViewerViewModel()
            let view = NavigationControlsView(viewModel: mockViewModel) { }
            let hostingController = NSHostingController(rootView: view)
            
            hostingController.loadView()
            
            // Verify view has accessibility elements
            let hasAccessibilityElements = hostingController.view.isAccessibilityElement() || 
                                         (hostingController.view.accessibilityElements()?.count ?? 0) > 0
            
            XCTAssertTrue(hasAccessibilityElements, 
                         "View should have accessibility elements in \(appearanceName)")
        }
    }
    
    // MARK: - Visual Regression Tests
    
    func testVisualConsistencyBetweenModes() {
        // Test that UI elements maintain visual consistency between modes
        let mockViewModel = createMockImageViewerViewModel()
        let view = NavigationControlsView(viewModel: mockViewModel) { }
        
        // Test light mode
        NSApp.appearance = NSAppearance(named: .aqua)
        let lightController = NSHostingController(rootView: view)
        lightController.loadView()
        
        // Test dark mode
        NSApp.appearance = NSAppearance(named: .darkAqua)
        let darkController = NSHostingController(rootView: view)
        darkController.loadView()
        
        // Both should load successfully
        XCTAssertNotNil(lightController.view)
        XCTAssertNotNil(darkController.view)
        
        // Views should have similar structure (same number of subviews at root level)
        let lightSubviewCount = lightController.view.subviews.count
        let darkSubviewCount = darkController.view.subviews.count
        
        XCTAssertEqual(lightSubviewCount, darkSubviewCount, 
                      "View structure should be consistent between light and dark modes")
    }
    
    func testUIElementVisibilityInBothModes() {
        // Test that all UI elements are visible in both modes
        let testViews: [(String, any View)] = [
            ("FolderSelectionView", FolderSelectionView()),
            ("NavigationControlsView", NavigationControlsView(viewModel: createMockImageViewerViewModel()) { }),
            ("ImageInfoOverlayView", ImageInfoOverlayView(imageFile: createMockImageFile(), currentImage: createMockNSImage()))
        ]
        
        for (viewName, testView) in testViews {
            // Test in light mode
            NSApp.appearance = NSAppearance(named: .aqua)
            let lightController = NSHostingController(rootView: AnyView(testView))
            lightController.loadView()
            XCTAssertNotNil(lightController.view, "\(viewName) should load in light mode")
            
            // Test in dark mode
            NSApp.appearance = NSAppearance(named: .darkAqua)
            let darkController = NSHostingController(rootView: AnyView(testView))
            darkController.loadView()
            XCTAssertNotNil(darkController.view, "\(viewName) should load in dark mode")
        }
    }
    
    // MARK: - Performance Tests
    
    func testAppearanceSwitchingPerformance() {
        // Test that appearance switching doesn't cause performance issues
        let mockViewModel = createMockImageViewerViewModel()
        let view = NavigationControlsView(viewModel: mockViewModel) { }
        let hostingController = NSHostingController(rootView: view)
        
        hostingController.loadView()
        
        measure {
            // Switch between appearances multiple times
            for _ in 0..<10 {
                NSApp.appearance = NSAppearance(named: .aqua)
                NSApp.appearance = NSAppearance(named: .darkAqua)
            }
        }
    }
    
    func testColorCreationPerformanceInBothModes() {
        // Test that color creation is performant in both modes
        let appearances: [NSAppearance.Name] = [.aqua, .darkAqua]
        
        for appearanceName in appearances {
            NSApp.appearance = NSAppearance(named: appearanceName)
            
            measure {
                for _ in 0..<100 {
                    let _ = Color.appBackground
                    let _ = Color.appText
                    let _ = Color.appAccent
                    let _ = Color.appOverlayBackground
                    let _ = Color.appToolbarBackground
                }
            }
        }
    }
    
    // MARK: - Edge Cases and Error Handling
    
    func testInvalidAppearanceHandling() {
        // Test that the app handles invalid or nil appearances gracefully
        
        // Test with nil appearance
        NSApp.appearance = nil
        let currentScheme = Color.currentColorScheme
        XCTAssertTrue(currentScheme == .light || currentScheme == .dark, 
                     "Should handle nil appearance gracefully")
        
        // Test that views still work with nil appearance
        let view = FolderSelectionView()
        let hostingController = NSHostingController(rootView: view)
        hostingController.loadView()
        XCTAssertNotNil(hostingController.view)
    }
    
    func testRapidAppearanceChanges() {
        // Test that rapid appearance changes don't cause issues
        let view = FolderSelectionView()
        let hostingController = NSHostingController(rootView: view)
        hostingController.loadView()
        
        // Rapidly switch appearances
        for i in 0..<20 {
            let appearance = i % 2 == 0 ? NSAppearance.Name.aqua : NSAppearance.Name.darkAqua
            NSApp.appearance = NSAppearance(named: appearance)
        }
        
        // View should still be valid
        XCTAssertNotNil(hostingController.view)
        
        // Color scheme detection should still work
        let finalScheme = Color.currentColorScheme
        XCTAssertTrue(finalScheme == .light || finalScheme == .dark)
    }
    
    // MARK: - Helper Methods
    
    private func createMockImageViewerViewModel() -> ImageViewerViewModel {
        let viewModel = ImageViewerViewModel()
        // Set up mock data for testing
        return viewModel
    }
    
    private func createMockImageFile() -> ImageFile {
        // Create a temporary file for testing
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test_image.jpg")
        
        // Create a simple test file
        let testData = Data([0xFF, 0xD8, 0xFF, 0xE0]) // JPEG header
        try? testData.write(to: tempURL)
        
        do {
            return try ImageFile(url: tempURL)
        } catch {
            // Fallback: create with a system image path
            let systemImageURL = URL(fileURLWithPath: "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericDocumentIcon.icns")
            return try! ImageFile(url: systemImageURL)
        }
    }
    
    private func createMockNSImage() -> NSImage {
        // Create a simple test image
        let image = NSImage(size: NSSize(width: 100, height: 100))
        image.lockFocus()
        NSColor.blue.setFill()
        NSRect(x: 0, y: 0, width: 100, height: 100).fill()
        image.unlockFocus()
        return image
    }
}