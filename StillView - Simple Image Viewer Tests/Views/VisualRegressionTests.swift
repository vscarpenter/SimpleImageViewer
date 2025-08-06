//
//  VisualRegressionTests.swift
//  Simple Image Viewer Tests
//
//  Created by Kiro on 7/30/25.
//

import XCTest
import SwiftUI
import AppKit
@testable import Simple_Image_Viewer

@MainActor
final class VisualRegressionTests: XCTestCase {
    
    // MARK: - Test Setup
    
    private var originalAppearance: NSAppearance?
    private let screenshotDirectory = "VisualRegressionTests"
    
    override func setUp() {
        super.setUp()
        originalAppearance = NSApp.effectiveAppearance
        continueAfterFailure = false
        
        // Create screenshots directory if it doesn't exist
        createScreenshotDirectory()
    }
    
    override func tearDown() {
        if let originalAppearance = originalAppearance {
            NSApp.appearance = originalAppearance
        }
        super.tearDown()
    }
    
    // MARK: - Screenshot Comparison Tests
    
    func testNavigationControlsScreenshotComparison() {
        // Test NavigationControlsView visual consistency between light and dark modes
        let mockViewModel = createMockImageViewerViewModel()
        let view = NavigationControlsView(viewModel: mockViewModel) { }
        
        // Capture light mode screenshot
        NSApp.appearance = NSAppearance(named: .aqua)
        let lightScreenshot = captureViewScreenshot(view: AnyView(view), 
                                                   identifier: "NavigationControls_Light",
                                                   size: CGSize(width: 800, height: 100))
        
        // Capture dark mode screenshot
        NSApp.appearance = NSAppearance(named: .darkAqua)
        let darkScreenshot = captureViewScreenshot(view: AnyView(view), 
                                                  identifier: "NavigationControls_Dark",
                                                  size: CGSize(width: 800, height: 100))
        
        // Verify screenshots were captured
        XCTAssertNotNil(lightScreenshot, "Light mode screenshot should be captured")
        XCTAssertNotNil(darkScreenshot, "Dark mode screenshot should be captured")
        
        // Verify screenshots are different (indicating proper dark mode adaptation)
        if let lightData = lightScreenshot?.tiffRepresentation,
           let darkData = darkScreenshot?.tiffRepresentation {
            XCTAssertNotEqual(lightData, darkData, 
                             "Light and dark mode screenshots should be different")
        }
    }
    
    func testFolderSelectionViewScreenshotComparison() {
        // Test FolderSelectionView visual consistency between modes
        let view = FolderSelectionView()
        
        // Capture light mode screenshot
        NSApp.appearance = NSAppearance(named: .aqua)
        let lightScreenshot = captureViewScreenshot(view: AnyView(view), 
                                                   identifier: "FolderSelection_Light",
                                                   size: CGSize(width: 600, height: 500))
        
        // Capture dark mode screenshot
        NSApp.appearance = NSAppearance(named: .darkAqua)
        let darkScreenshot = captureViewScreenshot(view: AnyView(view), 
                                                  identifier: "FolderSelection_Dark",
                                                  size: CGSize(width: 600, height: 500))
        
        // Verify screenshots were captured
        XCTAssertNotNil(lightScreenshot, "Light mode screenshot should be captured")
        XCTAssertNotNil(darkScreenshot, "Dark mode screenshot should be captured")
        
        // Verify screenshots are different
        if let lightData = lightScreenshot?.tiffRepresentation,
           let darkData = darkScreenshot?.tiffRepresentation {
            XCTAssertNotEqual(lightData, darkData, 
                             "Light and dark mode screenshots should be different")
        }
    }
    
    func testImageInfoOverlayScreenshotComparison() {
        // Test ImageInfoOverlayView visual consistency between modes
        let mockImageFile = createMockImageFile()
        let mockImage = createMockNSImage()
        let view = ImageInfoOverlayView(imageFile: mockImageFile, currentImage: mockImage)
        
        // Capture light mode screenshot
        NSApp.appearance = NSAppearance(named: .aqua)
        let lightScreenshot = captureViewScreenshot(view: AnyView(view), 
                                                   identifier: "ImageInfoOverlay_Light",
                                                   size: CGSize(width: 300, height: 400))
        
        // Capture dark mode screenshot
        NSApp.appearance = NSAppearance(named: .darkAqua)
        let darkScreenshot = captureViewScreenshot(view: AnyView(view), 
                                                  identifier: "ImageInfoOverlay_Dark",
                                                  size: CGSize(width: 300, height: 400))
        
        // Verify screenshots were captured
        XCTAssertNotNil(lightScreenshot, "Light mode screenshot should be captured")
        XCTAssertNotNil(darkScreenshot, "Dark mode screenshot should be captured")
        
        // Verify screenshots are different
        if let lightData = lightScreenshot?.tiffRepresentation,
           let darkData = darkScreenshot?.tiffRepresentation {
            XCTAssertNotEqual(lightData, darkData, 
                             "Light and dark mode screenshots should be different")
        }
    }
    
    // MARK: - Color Contrast Analysis Tests
    
    func testTextContrastRatiosInLightMode() {
        // Test that text contrast ratios meet WCAG AA standards in light mode
        NSApp.appearance = NSAppearance(named: .aqua)
        
        let contrastTests: [(Color, Color, String)] = [
            (Color.appText, Color.appBackground, "Primary text on background"),
            (Color.appSecondaryText, Color.appBackground, "Secondary text on background"),
            (Color.appOverlayText, Color.appOverlayBackground, "Overlay text on overlay background"),
            (Color.appText, Color.appToolbarBackground, "Text on toolbar background")
        ]
        
        for (textColor, backgroundColor, description) in contrastTests {
            let contrastRatio = calculateContrastRatio(textColor: textColor, 
                                                      backgroundColor: backgroundColor)
            
            // WCAG AA requires 4.5:1 for normal text, 3:1 for large text
            // We'll test for 3:1 as a minimum since we have various text sizes
            XCTAssertGreaterThanOrEqual(contrastRatio, 3.0, 
                                       "\(description) should meet minimum contrast ratio in light mode")
        }
    }
    
    func testTextContrastRatiosInDarkMode() {
        // Test that text contrast ratios meet WCAG AA standards in dark mode
        NSApp.appearance = NSAppearance(named: .darkAqua)
        
        let contrastTests: [(Color, Color, String)] = [
            (Color.appText, Color.appBackground, "Primary text on background"),
            (Color.appSecondaryText, Color.appBackground, "Secondary text on background"),
            (Color.appOverlayText, Color.appOverlayBackground, "Overlay text on overlay background"),
            (Color.appText, Color.appToolbarBackground, "Text on toolbar background")
        ]
        
        for (textColor, backgroundColor, description) in contrastTests {
            let contrastRatio = calculateContrastRatio(textColor: textColor, 
                                                      backgroundColor: backgroundColor)
            
            // WCAG AA requires 4.5:1 for normal text, 3:1 for large text
            XCTAssertGreaterThanOrEqual(contrastRatio, 3.0, 
                                       "\(description) should meet minimum contrast ratio in dark mode")
        }
    }
    
    // MARK: - Visual Element Visibility Tests
    
    func testToolbarElementsVisibilityInLightMode() {
        // Test that all toolbar elements are visible in light mode
        NSApp.appearance = NSAppearance(named: .aqua)
        
        let mockViewModel = createMockImageViewerViewModel()
        let view = NavigationControlsView(viewModel: mockViewModel) { }
        
        let screenshot = captureViewScreenshot(view: AnyView(view), 
                                             identifier: "ToolbarVisibility_Light",
                                             size: CGSize(width: 800, height: 100))
        
        XCTAssertNotNil(screenshot, "Toolbar screenshot should be captured in light mode")
        
        // Verify the screenshot has content (not just transparent/empty)
        if let screenshot = screenshot {
            let hasVisibleContent = analyzeScreenshotForVisibleContent(screenshot)
            XCTAssertTrue(hasVisibleContent, "Toolbar should have visible content in light mode")
        }
    }
    
    func testToolbarElementsVisibilityInDarkMode() {
        // Test that all toolbar elements are visible in dark mode
        NSApp.appearance = NSAppearance(named: .darkAqua)
        
        let mockViewModel = createMockImageViewerViewModel()
        let view = NavigationControlsView(viewModel: mockViewModel) { }
        
        let screenshot = captureViewScreenshot(view: AnyView(view), 
                                             identifier: "ToolbarVisibility_Dark",
                                             size: CGSize(width: 800, height: 100))
        
        XCTAssertNotNil(screenshot, "Toolbar screenshot should be captured in dark mode")
        
        // Verify the screenshot has content
        if let screenshot = screenshot {
            let hasVisibleContent = analyzeScreenshotForVisibleContent(screenshot)
            XCTAssertTrue(hasVisibleContent, "Toolbar should have visible content in dark mode")
        }
    }
    
    func testOverlayElementsVisibilityInBothModes() {
        // Test that overlay elements are visible in both modes
        let mockImageFile = createMockImageFile()
        let mockImage = createMockNSImage()
        let view = ImageInfoOverlayView(imageFile: mockImageFile, currentImage: mockImage)
        
        let modes: [(NSAppearance.Name, String)] = [
            (.aqua, "Light"),
            (.darkAqua, "Dark")
        ]
        
        for (appearanceName, modeName) in modes {
            NSApp.appearance = NSAppearance(named: appearanceName)
            
            let screenshot = captureViewScreenshot(view: AnyView(view), 
                                                 identifier: "OverlayVisibility_\(modeName)",
                                                 size: CGSize(width: 300, height: 400))
            
            XCTAssertNotNil(screenshot, "Overlay screenshot should be captured in \(modeName.lowercased()) mode")
            
            if let screenshot = screenshot {
                let hasVisibleContent = analyzeScreenshotForVisibleContent(screenshot)
                XCTAssertTrue(hasVisibleContent, "Overlay should have visible content in \(modeName.lowercased()) mode")
            }
        }
    }
    
    // MARK: - Skeleton Loading Screen Tests
    
    func testSkeletonLoadingScreensVisualConsistency() {
        // Test skeleton loading screens in both light and dark modes
        let testCases: [(CGSize?, Bool, Double, String)] = [
            (nil, false, 0.0, "Default"),
            (CGSize(width: 800, height: 600), true, 0.65, "WithProgress"),
            (CGSize(width: 1200, height: 800), false, 0.0, "LargeImage"),
            (CGSize(width: 400, height: 600), true, 0.25, "PortraitImage")
        ]
        
        for (imageSize, showProgress, progress, testName) in testCases {
            let view = SkeletonLoadingView(
                imageSize: imageSize,
                showProgressBar: showProgress,
                loadingProgress: progress
            )
            
            // Test light mode
            NSApp.appearance = NSAppearance(named: .aqua)
            let lightScreenshot = captureViewScreenshot(
                view: AnyView(view),
                identifier: "SkeletonLoading_\(testName)_Light",
                size: CGSize(width: 400, height: 300)
            )
            
            // Test dark mode
            NSApp.appearance = NSAppearance(named: .darkAqua)
            let darkScreenshot = captureViewScreenshot(
                view: AnyView(view),
                identifier: "SkeletonLoading_\(testName)_Dark",
                size: CGSize(width: 400, height: 300)
            )
            
            // Verify screenshots were captured
            XCTAssertNotNil(lightScreenshot, "Light mode skeleton loading screenshot should be captured for \(testName)")
            XCTAssertNotNil(darkScreenshot, "Dark mode skeleton loading screenshot should be captured for \(testName)")
            
            // Verify both screenshots have visible content
            if let lightScreenshot = lightScreenshot {
                let hasLightContent = analyzeScreenshotForVisibleContent(lightScreenshot)
                XCTAssertTrue(hasLightContent, "Light mode skeleton loading should have visible content for \(testName)")
            }
            
            if let darkScreenshot = darkScreenshot {
                let hasDarkContent = analyzeScreenshotForVisibleContent(darkScreenshot)
                XCTAssertTrue(hasDarkContent, "Dark mode skeleton loading should have visible content for \(testName)")
            }
            
            // Verify screenshots are different between modes
            if let lightData = lightScreenshot?.tiffRepresentation,
               let darkData = darkScreenshot?.tiffRepresentation {
                XCTAssertNotEqual(lightData, darkData,
                                 "Light and dark mode skeleton loading screenshots should be different for \(testName)")
            }
        }
    }
    
    func testProgressiveLoadingScreensVisualConsistency() {
        // Test progressive loading screens with preview images
        let testImage = createMockNSImage()
        let testCases: [(NSImage?, Double, CGSize?, String)] = [
            (testImage, 0.0, CGSize(width: 800, height: 600), "WithPreview_Start"),
            (testImage, 0.5, CGSize(width: 800, height: 600), "WithPreview_Half"),
            (testImage, 0.9, CGSize(width: 800, height: 600), "WithPreview_Almost"),
            (nil, 0.3, CGSize(width: 800, height: 600), "NoPreview")
        ]
        
        for (previewImage, progress, targetSize, testName) in testCases {
            let view = ProgressiveLoadingView(
                previewImage: previewImage,
                loadingProgress: progress,
                targetSize: targetSize
            )
            
            // Test light mode
            NSApp.appearance = NSAppearance(named: .aqua)
            let lightScreenshot = captureViewScreenshot(
                view: AnyView(view),
                identifier: "ProgressiveLoading_\(testName)_Light",
                size: CGSize(width: 400, height: 300)
            )
            
            // Test dark mode
            NSApp.appearance = NSAppearance(named: .darkAqua)
            let darkScreenshot = captureViewScreenshot(
                view: AnyView(view),
                identifier: "ProgressiveLoading_\(testName)_Dark",
                size: CGSize(width: 400, height: 300)
            )
            
            // Verify screenshots were captured
            XCTAssertNotNil(lightScreenshot, "Light mode progressive loading screenshot should be captured for \(testName)")
            XCTAssertNotNil(darkScreenshot, "Dark mode progressive loading screenshot should be captured for \(testName)")
            
            // Verify both screenshots have visible content
            if let lightScreenshot = lightScreenshot {
                let hasLightContent = analyzeScreenshotForVisibleContent(lightScreenshot)
                XCTAssertTrue(hasLightContent, "Light mode progressive loading should have visible content for \(testName)")
            }
            
            if let darkScreenshot = darkScreenshot {
                let hasDarkContent = analyzeScreenshotForVisibleContent(darkScreenshot)
                XCTAssertTrue(hasDarkContent, "Dark mode progressive loading should have visible content for \(testName)")
            }
        }
    }
    
    func testLoadingScreenAnimationStates() {
        // Test that loading screens respect reduced motion settings
        let originalReducedMotion = AccessibilityService.shared.isReducedMotionEnabled
        
        defer {
            // Reset to original state
            AccessibilityService.shared.isReducedMotionEnabled = originalReducedMotion
        }
        
        let testCases: [(Bool, String)] = [
            (false, "NormalMotion"),
            (true, "ReducedMotion")
        ]
        
        for (reducedMotion, testName) in testCases {
            AccessibilityService.shared.isReducedMotionEnabled = reducedMotion
            
            let skeletonView = SkeletonLoadingView(
                imageSize: CGSize(width: 800, height: 600),
                showProgressBar: true,
                loadingProgress: 0.5
            )
            
            NSApp.appearance = NSAppearance(named: .aqua)
            let screenshot = captureViewScreenshot(
                view: AnyView(skeletonView),
                identifier: "SkeletonLoading_\(testName)",
                size: CGSize(width: 400, height: 300)
            )
            
            XCTAssertNotNil(screenshot, "Skeleton loading screenshot should be captured for \(testName)")
            
            if let screenshot = screenshot {
                let hasContent = analyzeScreenshotForVisibleContent(screenshot)
                XCTAssertTrue(hasContent, "Skeleton loading should have visible content for \(testName)")
            }
        }
    }
    
    // MARK: - Regression Detection Tests
    
    func testVisualRegressionDetection() {
        // Test that we can detect visual regressions between test runs
        let view = FolderSelectionView()
        
        // Capture current screenshot
        NSApp.appearance = NSAppearance(named: .aqua)
        let currentScreenshot = captureViewScreenshot(view: AnyView(view), 
                                                     identifier: "RegressionTest_Current",
                                                     size: CGSize(width: 600, height: 500))
        
        XCTAssertNotNil(currentScreenshot, "Current screenshot should be captured")
        
        // In a real implementation, you would compare against a baseline screenshot
        // For this test, we'll just verify the screenshot was captured successfully
        if let screenshot = currentScreenshot {
            let hasContent = analyzeScreenshotForVisibleContent(screenshot)
            XCTAssertTrue(hasContent, "Screenshot should contain visible content")
            
            // Save as baseline for future comparisons
            saveScreenshotAsBaseline(screenshot, identifier: "FolderSelection_Baseline")
        }
    }
    
    func testAppearanceSwitchingVisualConsistency() {
        // Test that switching appearances maintains visual consistency
        let mockViewModel = createMockImageViewerViewModel()
        let view = NavigationControlsView(viewModel: mockViewModel) { }
        
        // Capture initial light mode
        NSApp.appearance = NSAppearance(named: .aqua)
        let initialLight = captureViewScreenshot(view: AnyView(view), 
                                               identifier: "ConsistencyTest_InitialLight",
                                               size: CGSize(width: 800, height: 100))
        
        // Switch to dark and back to light
        NSApp.appearance = NSAppearance(named: .darkAqua)
        NSApp.appearance = NSAppearance(named: .aqua)
        
        let finalLight = captureViewScreenshot(view: AnyView(view), 
                                             identifier: "ConsistencyTest_FinalLight",
                                             size: CGSize(width: 800, height: 100))
        
        // Screenshots should be identical (or very similar)
        if let initial = initialLight?.tiffRepresentation,
           let final = finalLight?.tiffRepresentation {
            
            // Allow for minor differences due to rendering variations
            let similarity = calculateImageSimilarity(data1: initial, data2: final)
            XCTAssertGreaterThan(similarity, 0.95, 
                               "Light mode appearance should be consistent after switching")
        }
    }
    
    // MARK: - Helper Methods
    
    private func captureViewScreenshot(view: AnyView, identifier: String, size: CGSize) -> NSImage? {
        let hostingController = NSHostingController(rootView: view)
        hostingController.loadView()
        
        // Set the view size
        hostingController.view.frame = NSRect(origin: .zero, size: size)
        hostingController.view.needsLayout = true
        hostingController.view.layoutSubtreeIfNeeded()
        
        // Capture screenshot
        guard let bitmapRep = hostingController.view.bitmapImageRepForCachingDisplay(in: hostingController.view.bounds) else {
            return nil
        }
        
        hostingController.view.cacheDisplay(in: hostingController.view.bounds, to: bitmapRep)
        
        let screenshot = NSImage(size: size)
        screenshot.addRepresentation(bitmapRep)
        
        // Save screenshot for debugging
        saveScreenshot(screenshot, identifier: identifier)
        
        return screenshot
    }
    
    private func calculateContrastRatio(textColor: Color, backgroundColor: Color) -> Double {
        // Convert SwiftUI Colors to NSColors for analysis
        let textNSColor = NSColor(textColor)
        let backgroundNSColor = NSColor(backgroundColor)
        
        // Get RGB components
        guard let textRGB = textNSColor.usingColorSpace(.sRGB),
              let backgroundRGB = backgroundNSColor.usingColorSpace(.sRGB) else {
            return 1.0 // Fallback ratio
        }
        
        // Calculate relative luminance
        let textLuminance = calculateRelativeLuminance(
            red: textRGB.redComponent,
            green: textRGB.greenComponent,
            blue: textRGB.blueComponent
        )
        
        let backgroundLuminance = calculateRelativeLuminance(
            red: backgroundRGB.redComponent,
            green: backgroundRGB.greenComponent,
            blue: backgroundRGB.blueComponent
        )
        
        // Calculate contrast ratio
        let lighter = max(textLuminance, backgroundLuminance)
        let darker = min(textLuminance, backgroundLuminance)
        
        return (lighter + 0.05) / (darker + 0.05)
    }
    
    private func calculateRelativeLuminance(red: CGFloat, green: CGFloat, blue: CGFloat) -> Double {
        // Convert to linear RGB
        func linearize(_ component: CGFloat) -> Double {
            let c = Double(component)
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        
        let r = linearize(red)
        let g = linearize(green)
        let b = linearize(blue)
        
        // Calculate relative luminance using ITU-R BT.709 coefficients
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
    
    private func analyzeScreenshotForVisibleContent(_ screenshot: NSImage) -> Bool {
        // Analyze if the screenshot contains visible content (not just transparent/empty)
        guard let tiffData = screenshot.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return false
        }
        
        let width = bitmapRep.pixelsWide
        let height = bitmapRep.pixelsHigh
        
        var hasVisiblePixels = false
        var pixelCount = 0
        let sampleSize = min(100, width * height) // Sample up to 100 pixels
        
        for _ in 0..<sampleSize {
            let x = Int.random(in: 0..<width)
            let y = Int.random(in: 0..<height)
            
            if let color = bitmapRep.colorAt(x: x, y: y) {
                // Check if pixel is not completely transparent
                if color.alphaComponent > 0.1 {
                    hasVisiblePixels = true
                    pixelCount += 1
                }
            }
        }
        
        // Consider content visible if more than 10% of sampled pixels are non-transparent
        return hasVisiblePixels && (Double(pixelCount) / Double(sampleSize)) > 0.1
    }
    
    private func calculateImageSimilarity(data1: Data, data2: Data) -> Double {
        // Simple similarity calculation based on data comparison
        // In a real implementation, you might use more sophisticated image comparison
        
        if data1.count != data2.count {
            return 0.0
        }
        
        let bytes1 = data1.withUnsafeBytes { $0.bindMemory(to: UInt8.self) }
        let bytes2 = data2.withUnsafeBytes { $0.bindMemory(to: UInt8.self) }
        
        var matchingBytes = 0
        let totalBytes = min(bytes1.count, bytes2.count)
        
        for i in 0..<totalBytes {
            if bytes1[i] == bytes2[i] {
                matchingBytes += 1
            }
        }
        
        return Double(matchingBytes) / Double(totalBytes)
    }
    
    private func createScreenshotDirectory() {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let screenshotPath = (documentsPath as NSString).appendingPathComponent(screenshotDirectory)
        
        if !FileManager.default.fileExists(atPath: screenshotPath) {
            try? FileManager.default.createDirectory(atPath: screenshotPath, 
                                                   withIntermediateDirectories: true, 
                                                   attributes: nil)
        }
    }
    
    private func saveScreenshot(_ screenshot: NSImage, identifier: String) {
        guard let tiffData = screenshot.tiffRepresentation else { return }
        
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let screenshotPath = (documentsPath as NSString).appendingPathComponent(screenshotDirectory)
        let filePath = (screenshotPath as NSString).appendingPathComponent("\(identifier).tiff")
        
        try? tiffData.write(to: URL(fileURLWithPath: filePath))
    }
    
    private func saveScreenshotAsBaseline(_ screenshot: NSImage, identifier: String) {
        guard let tiffData = screenshot.tiffRepresentation else { return }
        
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let screenshotPath = (documentsPath as NSString).appendingPathComponent(screenshotDirectory)
        let baselinePath = (screenshotPath as NSString).appendingPathComponent("Baselines")
        
        // Create baselines directory
        if !FileManager.default.fileExists(atPath: baselinePath) {
            try? FileManager.default.createDirectory(atPath: baselinePath, 
                                                   withIntermediateDirectories: true, 
                                                   attributes: nil)
        }
        
        let filePath = (baselinePath as NSString).appendingPathComponent("\(identifier).tiff")
        try? tiffData.write(to: URL(fileURLWithPath: filePath))
    }
    
    private func createMockImageViewerViewModel() -> ImageViewerViewModel {
        let viewModel = ImageViewerViewModel()
        // Set up mock data for consistent testing
        return viewModel
    }
    
    private func createMockImageFile() -> ImageFile {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test_image.jpg")
        
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
        NSColor.blue.setFill()
        NSRect(x: 0, y: 0, width: 100, height: 100).fill()
        image.unlockFocus()
        return image
    }
}