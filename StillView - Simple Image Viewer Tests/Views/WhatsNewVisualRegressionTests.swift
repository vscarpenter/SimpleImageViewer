//
//  WhatsNewVisualRegressionTests.swift
//  Simple Image Viewer Tests
//
//  Created by Kiro on 8/7/25.
//

import XCTest
import SwiftUI
import AppKit
@testable import Simple_Image_Viewer

@MainActor
final class WhatsNewVisualRegressionTests: XCTestCase {
    
    // MARK: - Test Setup
    
    private var originalAppearance: NSAppearance?
    private let screenshotDirectory = "WhatsNewVisualRegressionTests"
    
    override func setUp() {
        super.setUp()
        originalAppearance = NSApp.effectiveAppearance
        continueAfterFailure = false
        createScreenshotDirectory()
    }
    
    override func tearDown() {
        if let originalAppearance = originalAppearance {
            NSApp.appearance = originalAppearance
        }
        super.tearDown()
    }
    
    // MARK: - What's New Sheet Visual Tests
    
    func testWhatsNewSheetVisualConsistency() {
        // Test WhatsNewSheet visual consistency between light and dark modes
        let content = WhatsNewContent.sampleContent
        let view = WhatsNewSheet(content: content)
        
        // Test light mode
        NSApp.appearance = NSAppearance(named: .aqua)
        let lightScreenshot = captureViewScreenshot(
            view: AnyView(view),
            identifier: "WhatsNewSheet_Light",
            size: CGSize(width: 480, height: 600)
        )
        
        // Test dark mode
        NSApp.appearance = NSAppearance(named: .darkAqua)
        let darkScreenshot = captureViewScreenshot(
            view: AnyView(view),
            identifier: "WhatsNewSheet_Dark",
            size: CGSize(width: 480, height: 600)
        )
        
        // Verify screenshots were captured
        XCTAssertNotNil(lightScreenshot, "Light mode What's New sheet screenshot should be captured")
        XCTAssertNotNil(darkScreenshot, "Dark mode What's New sheet screenshot should be captured")
        
        // Verify screenshots are different (indicating proper dark mode adaptation)
        if let lightData = lightScreenshot?.tiffRepresentation,
           let darkData = darkScreenshot?.tiffRepresentation {
            XCTAssertNotEqual(lightData, darkData,
                             "Light and dark mode What's New sheet screenshots should be different")
        }
        
        // Verify both screenshots have visible content
        if let lightScreenshot = lightScreenshot {
            let hasLightContent = analyzeScreenshotForVisibleContent(lightScreenshot)
            XCTAssertTrue(hasLightContent, "Light mode What's New sheet should have visible content")
        }
        
        if let darkScreenshot = darkScreenshot {
            let hasDarkContent = analyzeScreenshotForVisibleContent(darkScreenshot)
            XCTAssertTrue(hasDarkContent, "Dark mode What's New sheet should have visible content")
        }
    }
    
    func testWhatsNewContentViewWithDifferentContentLengths() {
        // Test WhatsNewContentView with various content lengths
        let testCases: [(WhatsNewContent, String)] = [
            (createShortContent(), "Short"),
            (createMediumContent(), "Medium"),
            (createLongContent(), "Long"),
            (createVeryLongContent(), "VeryLong")
        ]
        
        for (content, lengthType) in testCases {
            let view = WhatsNewContentView(content: content)
            
            // Test light mode
            NSApp.appearance = NSAppearance(named: .aqua)
            let lightScreenshot = captureViewScreenshot(
                view: AnyView(view),
                identifier: "WhatsNewContent_\(lengthType)_Light",
                size: CGSize(width: 480, height: 600)
            )
            
            // Test dark mode
            NSApp.appearance = NSAppearance(named: .darkAqua)
            let darkScreenshot = captureViewScreenshot(
                view: AnyView(view),
                identifier: "WhatsNewContent_\(lengthType)_Dark",
                size: CGSize(width: 480, height: 600)
            )
            
            // Verify screenshots were captured
            XCTAssertNotNil(lightScreenshot, "Light mode \(lengthType) content screenshot should be captured")
            XCTAssertNotNil(darkScreenshot, "Dark mode \(lengthType) content screenshot should be captured")
            
            // Verify both screenshots have visible content
            if let lightScreenshot = lightScreenshot {
                let hasContent = analyzeScreenshotForVisibleContent(lightScreenshot)
                XCTAssertTrue(hasContent, "Light mode \(lengthType) content should have visible content")
            }
            
            if let darkScreenshot = darkScreenshot {
                let hasContent = analyzeScreenshotForVisibleContent(darkScreenshot)
                XCTAssertTrue(hasContent, "Dark mode \(lengthType) content should have visible content")
            }
        }
    }
    
    func testWhatsNewSectionViewVisualConsistency() {
        // Test individual section views in both modes
        let testSections: [(WhatsNewSection, String)] = [
            (WhatsNewSection.sampleNewFeatures, "NewFeatures"),
            (WhatsNewSection.sampleImprovements, "Improvements"),
            (WhatsNewSection.sampleBugFixes, "BugFixes"),
            (createLongSection(), "LongSection")
        ]
        
        for (section, sectionType) in testSections {
            let view = WhatsNewSectionView(section: section)
            
            // Test light mode
            NSApp.appearance = NSAppearance(named: .aqua)
            let lightScreenshot = captureViewScreenshot(
                view: AnyView(view),
                identifier: "WhatsNewSection_\(sectionType)_Light",
                size: CGSize(width: 440, height: 300)
            )
            
            // Test dark mode
            NSApp.appearance = NSAppearance(named: .darkAqua)
            let darkScreenshot = captureViewScreenshot(
                view: AnyView(view),
                identifier: "WhatsNewSection_\(sectionType)_Dark",
                size: CGSize(width: 440, height: 300)
            )
            
            // Verify screenshots were captured
            XCTAssertNotNil(lightScreenshot, "Light mode \(sectionType) section screenshot should be captured")
            XCTAssertNotNil(darkScreenshot, "Dark mode \(sectionType) section screenshot should be captured")
            
            // Verify screenshots are different between modes
            if let lightData = lightScreenshot?.tiffRepresentation,
               let darkData = darkScreenshot?.tiffRepresentation {
                XCTAssertNotEqual(lightData, darkData,
                                 "Light and dark mode \(sectionType) section screenshots should be different")
            }
        }
    }
    
    // MARK: - Accessibility Visual Tests
    
    func testHighContrastModeVisualConsistency() {
        // Test What's New views in high contrast mode
        let originalHighContrast = AccessibilityService.shared.isHighContrastEnabled
        defer { AccessibilityService.shared.isHighContrastEnabled = originalHighContrast }
        
        let content = WhatsNewContent.sampleContent
        let view = WhatsNewContentView(content: content)
        
        // Test normal contrast
        AccessibilityService.shared.isHighContrastEnabled = false
        NSApp.appearance = NSAppearance(named: .aqua)
        let normalContrastScreenshot = captureViewScreenshot(
            view: AnyView(view),
            identifier: "WhatsNewContent_NormalContrast",
            size: CGSize(width: 480, height: 600)
        )
        
        // Test high contrast
        AccessibilityService.shared.isHighContrastEnabled = true
        let highContrastScreenshot = captureViewScreenshot(
            view: AnyView(view),
            identifier: "WhatsNewContent_HighContrast",
            size: CGSize(width: 480, height: 600)
        )
        
        // Verify screenshots were captured
        XCTAssertNotNil(normalContrastScreenshot, "Normal contrast screenshot should be captured")
        XCTAssertNotNil(highContrastScreenshot, "High contrast screenshot should be captured")
        
        // Verify screenshots are different (indicating high contrast adaptation)
        if let normalData = normalContrastScreenshot?.tiffRepresentation,
           let highContrastData = highContrastScreenshot?.tiffRepresentation {
            XCTAssertNotEqual(normalData, highContrastData,
                             "Normal and high contrast screenshots should be different")
        }
    }
    
    func testReducedMotionVisualConsistency() {
        // Test What's New views with reduced motion enabled
        let originalReducedMotion = AccessibilityService.shared.isReducedMotionEnabled
        defer { AccessibilityService.shared.isReducedMotionEnabled = originalReducedMotion }
        
        let content = WhatsNewContent.sampleContent
        let view = WhatsNewSheet(content: content)
        
        let testCases: [(Bool, String)] = [
            (false, "NormalMotion"),
            (true, "ReducedMotion")
        ]
        
        for (reducedMotion, testName) in testCases {
            AccessibilityService.shared.isReducedMotionEnabled = reducedMotion
            
            NSApp.appearance = NSAppearance(named: .aqua)
            let screenshot = captureViewScreenshot(
                view: AnyView(view),
                identifier: "WhatsNewSheet_\(testName)",
                size: CGSize(width: 480, height: 600)
            )
            
            XCTAssertNotNil(screenshot, "What's New sheet screenshot should be captured for \(testName)")
            
            if let screenshot = screenshot {
                let hasContent = analyzeScreenshotForVisibleContent(screenshot)
                XCTAssertTrue(hasContent, "What's New sheet should have visible content for \(testName)")
            }
        }
    }
    
    // MARK: - Scrolling Behavior Visual Tests
    
    func testScrollingBehaviorWithLongContent() {
        // Test scrolling behavior with content that exceeds view height
        let longContent = createVeryLongContent()
        let view = WhatsNewContentView(content: longContent)
        
        // Test with different view heights to simulate scrolling scenarios
        let testSizes: [(CGSize, String)] = [
            (CGSize(width: 480, height: 300), "Short"),
            (CGSize(width: 480, height: 600), "Medium"),
            (CGSize(width: 480, height: 900), "Tall")
        ]
        
        for (size, heightType) in testSizes {
            // Test light mode
            NSApp.appearance = NSAppearance(named: .aqua)
            let lightScreenshot = captureViewScreenshot(
                view: AnyView(view),
                identifier: "WhatsNewScrolling_\(heightType)_Light",
                size: size
            )
            
            // Test dark mode
            NSApp.appearance = NSAppearance(named: .darkAqua)
            let darkScreenshot = captureViewScreenshot(
                view: AnyView(view),
                identifier: "WhatsNewScrolling_\(heightType)_Dark",
                size: size
            )
            
            // Verify screenshots were captured
            XCTAssertNotNil(lightScreenshot, "Light mode scrolling \(heightType) screenshot should be captured")
            XCTAssertNotNil(darkScreenshot, "Dark mode scrolling \(heightType) screenshot should be captured")
            
            // Verify content is visible
            if let lightScreenshot = lightScreenshot {
                let hasContent = analyzeScreenshotForVisibleContent(lightScreenshot)
                XCTAssertTrue(hasContent, "Light mode scrolling \(heightType) should have visible content")
            }
            
            if let darkScreenshot = darkScreenshot {
                let hasContent = analyzeScreenshotForVisibleContent(darkScreenshot)
                XCTAssertTrue(hasContent, "Dark mode scrolling \(heightType) should have visible content")
            }
        }
    }
    
    // MARK: - Theme Consistency Tests
    
    func testThemeConsistencyAcrossComponents() {
        // Test that all What's New components use consistent theming
        let content = WhatsNewContent.sampleContent
        let components: [(String, AnyView)] = [
            ("Sheet", AnyView(WhatsNewSheet(content: content))),
            ("Content", AnyView(WhatsNewContentView(content: content))),
            ("Section", AnyView(WhatsNewSectionView(section: content.sections.first!)))
        ]
        
        let appearances: [(NSAppearance.Name, String)] = [
            (.aqua, "Light"),
            (.darkAqua, "Dark")
        ]
        
        for (appearanceName, modeName) in appearances {
            NSApp.appearance = NSAppearance(named: appearanceName)
            
            for (componentName, component) in components {
                let screenshot = captureViewScreenshot(
                    view: component,
                    identifier: "WhatsNewTheme_\(componentName)_\(modeName)",
                    size: CGSize(width: 480, height: 400)
                )
                
                XCTAssertNotNil(screenshot, "\(componentName) theme screenshot should be captured in \(modeName) mode")
                
                if let screenshot = screenshot {
                    let hasContent = analyzeScreenshotForVisibleContent(screenshot)
                    XCTAssertTrue(hasContent, "\(componentName) should have visible content in \(modeName) mode")
                }
            }
        }
    }
    
    func testColorContrastInBothModes() {
        // Test that color contrast meets accessibility standards in both modes
        let content = WhatsNewContent.sampleContent
        let view = WhatsNewContentView(content: content)
        
        let testModes: [(NSAppearance.Name, String)] = [
            (.aqua, "Light"),
            (.darkAqua, "Dark")
        ]
        
        for (appearanceName, modeName) in testModes {
            NSApp.appearance = NSAppearance(named: appearanceName)
            
            let screenshot = captureViewScreenshot(
                view: AnyView(view),
                identifier: "WhatsNewContrast_\(modeName)",
                size: CGSize(width: 480, height: 600)
            )
            
            XCTAssertNotNil(screenshot, "Contrast test screenshot should be captured in \(modeName) mode")
            
            if let screenshot = screenshot {
                // Analyze screenshot for contrast issues
                let hasGoodContrast = analyzeScreenshotForContrast(screenshot)
                XCTAssertTrue(hasGoodContrast, "What's New content should have good contrast in \(modeName) mode")
            }
        }
    }
    
    // MARK: - Edge Cases Visual Tests
    
    func testEmptyContentVisualHandling() {
        // Test visual handling of empty or minimal content
        let emptyContent = WhatsNewContent(
            version: "1.0.0",
            releaseDate: Date(),
            sections: []
        )
        
        let minimalContent = WhatsNewContent(
            version: "1.0.0",
            releaseDate: nil,
            sections: [
                WhatsNewSection(
                    title: "Updates",
                    items: [
                        WhatsNewItem(title: "Minor fixes", description: nil, isHighlighted: false)
                    ],
                    type: .improvements
                )
            ]
        )
        
        let testCases: [(WhatsNewContent, String)] = [
            (emptyContent, "Empty"),
            (minimalContent, "Minimal")
        ]
        
        for (content, contentType) in testCases {
            let view = WhatsNewContentView(content: content)
            
            // Test light mode
            NSApp.appearance = NSAppearance(named: .aqua)
            let lightScreenshot = captureViewScreenshot(
                view: AnyView(view),
                identifier: "WhatsNewEdgeCase_\(contentType)_Light",
                size: CGSize(width: 480, height: 600)
            )
            
            // Test dark mode
            NSApp.appearance = NSAppearance(named: .darkAqua)
            let darkScreenshot = captureViewScreenshot(
                view: AnyView(view),
                identifier: "WhatsNewEdgeCase_\(contentType)_Dark",
                size: CGSize(width: 480, height: 600)
            )
            
            // Verify screenshots were captured
            XCTAssertNotNil(lightScreenshot, "Light mode \(contentType) content screenshot should be captured")
            XCTAssertNotNil(darkScreenshot, "Dark mode \(contentType) content screenshot should be captured")
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
        
        // Allow time for view to render
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
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
    
    private func analyzeScreenshotForVisibleContent(_ screenshot: NSImage) -> Bool {
        guard let tiffData = screenshot.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return false
        }
        
        let width = bitmapRep.pixelsWide
        let height = bitmapRep.pixelsHigh
        
        var visiblePixelCount = 0
        let sampleSize = min(200, width * height)
        
        for _ in 0..<sampleSize {
            let x = Int.random(in: 0..<width)
            let y = Int.random(in: 0..<height)
            
            if let color = bitmapRep.colorAt(x: x, y: y) {
                // Check if pixel is not completely transparent and not pure white/black background
                if color.alphaComponent > 0.1 &&
                   !(color.redComponent > 0.95 && color.greenComponent > 0.95 && color.blueComponent > 0.95) &&
                   !(color.redComponent < 0.05 && color.greenComponent < 0.05 && color.blueComponent < 0.05) {
                    visiblePixelCount += 1
                }
            }
        }
        
        // Consider content visible if more than 5% of sampled pixels are content
        return Double(visiblePixelCount) / Double(sampleSize) > 0.05
    }
    
    private func analyzeScreenshotForContrast(_ screenshot: NSImage) -> Bool {
        // Simple contrast analysis - in a real implementation, this would be more sophisticated
        guard let tiffData = screenshot.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return false
        }
        
        let width = bitmapRep.pixelsWide
        let height = bitmapRep.pixelsHigh
        
        var contrastSamples: [Double] = []
        let sampleSize = min(50, width * height / 100)
        
        for _ in 0..<sampleSize {
            let x = Int.random(in: 1..<(width-1))
            let y = Int.random(in: 1..<(height-1))
            
            if let centerColor = bitmapRep.colorAt(x: x, y: y),
               let neighborColor = bitmapRep.colorAt(x: x+1, y: y) {
                
                let centerLuminance = calculateLuminance(centerColor)
                let neighborLuminance = calculateLuminance(neighborColor)
                
                let contrast = abs(centerLuminance - neighborLuminance)
                contrastSamples.append(contrast)
            }
        }
        
        // Check if average contrast is reasonable
        let averageContrast = contrastSamples.reduce(0, +) / Double(contrastSamples.count)
        return averageContrast > 0.1 // Minimum contrast threshold
    }
    
    private func calculateLuminance(_ color: NSColor) -> Double {
        guard let rgbColor = color.usingColorSpace(.sRGB) else { return 0 }
        
        // Calculate relative luminance using ITU-R BT.709 coefficients
        let r = Double(rgbColor.redComponent)
        let g = Double(rgbColor.greenComponent)
        let b = Double(rgbColor.blueComponent)
        
        return 0.299 * r + 0.587 * g + 0.114 * b
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
    
    // MARK: - Test Content Creation
    
    private func createShortContent() -> WhatsNewContent {
        return WhatsNewContent(
            version: "1.0.0",
            releaseDate: Date(),
            sections: [
                WhatsNewSection(
                    title: "New Features",
                    items: [
                        WhatsNewItem(title: "Quick feature", description: "Brief description", isHighlighted: true)
                    ],
                    type: .newFeatures
                )
            ]
        )
    }
    
    private func createMediumContent() -> WhatsNewContent {
        return WhatsNewContent(
            version: "1.1.0",
            releaseDate: Date(),
            sections: [
                WhatsNewSection(
                    title: "New Features",
                    items: [
                        WhatsNewItem(title: "Feature One", description: "Description for feature one", isHighlighted: true),
                        WhatsNewItem(title: "Feature Two", description: "Description for feature two", isHighlighted: false)
                    ],
                    type: .newFeatures
                ),
                WhatsNewSection(
                    title: "Improvements",
                    items: [
                        WhatsNewItem(title: "Performance boost", description: "Faster loading times", isHighlighted: false)
                    ],
                    type: .improvements
                )
            ]
        )
    }
    
    private func createLongContent() -> WhatsNewContent {
        return WhatsNewContent(
            version: "1.2.0",
            releaseDate: Date(),
            sections: [
                WhatsNewSection(
                    title: "New Features",
                    items: [
                        WhatsNewItem(title: "Advanced Image Processing", description: "Enhanced image processing capabilities with support for more formats and better quality", isHighlighted: true),
                        WhatsNewItem(title: "Improved Navigation", description: "Streamlined navigation controls with keyboard shortcuts and gesture support", isHighlighted: true),
                        WhatsNewItem(title: "Batch Operations", description: "Process multiple images at once with batch operations", isHighlighted: false)
                    ],
                    type: .newFeatures
                ),
                WhatsNewSection(
                    title: "Improvements",
                    items: [
                        WhatsNewItem(title: "Performance Optimizations", description: "Significant performance improvements for large image collections", isHighlighted: false),
                        WhatsNewItem(title: "Memory Management", description: "Better memory usage and reduced memory footprint", isHighlighted: false)
                    ],
                    type: .improvements
                ),
                WhatsNewSection(
                    title: "Bug Fixes",
                    items: [
                        WhatsNewItem(title: "Fixed crash on startup", description: "Resolved issue causing crashes on certain system configurations", isHighlighted: false)
                    ],
                    type: .bugFixes
                )
            ]
        )
    }
    
    private func createVeryLongContent() -> WhatsNewContent {
        return WhatsNewContent(
            version: "2.0.0",
            releaseDate: Date(),
            sections: [
                WhatsNewSection(
                    title: "Major New Features",
                    items: [
                        WhatsNewItem(title: "Complete UI Redesign", description: "A completely redesigned user interface with modern styling, improved accessibility, and better user experience across all features", isHighlighted: true),
                        WhatsNewItem(title: "Advanced Image Editing", description: "Built-in image editing capabilities including crop, rotate, adjust brightness, contrast, and saturation with real-time preview", isHighlighted: true),
                        WhatsNewItem(title: "Cloud Integration", description: "Seamless integration with popular cloud storage services including iCloud, Dropbox, Google Drive, and OneDrive for easy access to your images", isHighlighted: true),
                        WhatsNewItem(title: "AI-Powered Organization", description: "Automatic image organization using machine learning to categorize and tag your photos based on content, location, and other metadata", isHighlighted: false),
                        WhatsNewItem(title: "Advanced Search", description: "Powerful search functionality that lets you find images by content, metadata, location, date, and custom tags", isHighlighted: false)
                    ],
                    type: .newFeatures
                ),
                WhatsNewSection(
                    title: "Performance Improvements",
                    items: [
                        WhatsNewItem(title: "Lightning Fast Loading", description: "Dramatically improved loading times for large image collections with intelligent caching and preloading", isHighlighted: false),
                        WhatsNewItem(title: "Optimized Memory Usage", description: "Reduced memory footprint by up to 60% while maintaining smooth performance even with thousands of images", isHighlighted: false),
                        WhatsNewItem(title: "Background Processing", description: "Thumbnail generation and metadata extraction now happen in the background without blocking the UI", isHighlighted: false),
                        WhatsNewItem(title: "Multi-threading Support", description: "Better utilization of multi-core processors for faster image processing and smoother scrolling", isHighlighted: false)
                    ],
                    type: .improvements
                ),
                WhatsNewSection(
                    title: "Bug Fixes and Stability",
                    items: [
                        WhatsNewItem(title: "Fixed memory leaks", description: "Resolved several memory leaks that could cause performance degradation over time", isHighlighted: false),
                        WhatsNewItem(title: "Improved error handling", description: "Better error handling and recovery for corrupted or unsupported image files", isHighlighted: false),
                        WhatsNewItem(title: "Fixed display issues", description: "Resolved various display issues on high-DPI screens and external monitors", isHighlighted: false),
                        WhatsNewItem(title: "Stability improvements", description: "General stability improvements and crash fixes based on user feedback", isHighlighted: false)
                    ],
                    type: .bugFixes
                )
            ]
        )
    }
    
    private func createLongSection() -> WhatsNewSection {
        return WhatsNewSection(
            title: "Comprehensive Updates",
            items: [
                WhatsNewItem(title: "Feature Alpha", description: "This is a very long description that explains in detail what this feature does, how it works, and why it's beneficial for users. It includes multiple sentences and provides comprehensive information about the functionality.", isHighlighted: true),
                WhatsNewItem(title: "Feature Beta", description: "Another detailed description that goes into the specifics of this particular feature, including technical details and user benefits.", isHighlighted: false),
                WhatsNewItem(title: "Feature Gamma", description: "A third comprehensive description that covers all aspects of this feature.", isHighlighted: false),
                WhatsNewItem(title: "Feature Delta", description: "Yet another detailed explanation of functionality and benefits.", isHighlighted: false),
                WhatsNewItem(title: "Feature Epsilon", description: "Final comprehensive description in this long section.", isHighlighted: false)
            ],
            type: .newFeatures
        )
    }
}