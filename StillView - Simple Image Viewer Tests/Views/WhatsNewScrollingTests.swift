//
//  WhatsNewScrollingTests.swift
//  Simple Image Viewer Tests
//
//  Created by Kiro on 8/7/25.
//

import XCTest
import SwiftUI
import AppKit
@testable import Simple_Image_Viewer

@MainActor
final class WhatsNewScrollingTests: XCTestCase {
    
    // MARK: - Test Setup
    
    private var originalAppearance: NSAppearance?
    
    override func setUp() {
        super.setUp()
        originalAppearance = NSApp.effectiveAppearance
        continueAfterFailure = false
    }
    
    override func tearDown() {
        if let originalAppearance = originalAppearance {
            NSApp.appearance = originalAppearance
        }
        super.tearDown()
    }
    
    // MARK: - Scrolling Behavior Tests
    
    func testScrollViewWithShortContent() {
        // Test that short content doesn't require scrolling
        let shortContent = createShortContent()
        let view = WhatsNewContentView(content: shortContent)
        let hostingController = NSHostingController(rootView: view)
        
        // Set a reasonable view size
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 480, height: 600)
        hostingController.loadView()
        
        // Verify view loads successfully
        XCTAssertNotNil(hostingController.view, "Short content view should load successfully")
        
        // Test that content fits within the view bounds
        let viewHeight = hostingController.view.frame.height
        XCTAssertGreaterThan(viewHeight, 0, "View should have a valid height")
        
        // Short content should not require scrolling
        // This is verified by ensuring the view renders without issues
        hostingController.view.needsLayout = true
        hostingController.view.layoutSubtreeIfNeeded()
        
        XCTAssertNotNil(hostingController.view, "View should remain valid after layout")
    }
    
    func testScrollViewWithLongContent() {
        // Test that long content enables proper scrolling
        let longContent = createLongContent()
        let view = WhatsNewContentView(content: longContent)
        let hostingController = NSHostingController(rootView: view)
        
        // Set a constrained view size to force scrolling
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 480, height: 400)
        hostingController.loadView()
        
        // Verify view loads successfully
        XCTAssertNotNil(hostingController.view, "Long content view should load successfully")
        
        // Test that the view handles scrolling content properly
        hostingController.view.needsLayout = true
        hostingController.view.layoutSubtreeIfNeeded()
        
        // Verify that the scroll view is properly configured
        let hasScrollableContent = findScrollView(in: hostingController.view) != nil
        XCTAssertTrue(hasScrollableContent, "Long content should have a scroll view")
    }
    
    func testScrollViewWithVeryLongContent() {
        // Test scrolling with extremely long content
        let veryLongContent = createVeryLongContent()
        let view = WhatsNewContentView(content: veryLongContent)
        let hostingController = NSHostingController(rootView: view)
        
        // Set a small view size to ensure scrolling is required
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 480, height: 300)
        hostingController.loadView()
        
        // Verify view loads successfully even with very long content
        XCTAssertNotNil(hostingController.view, "Very long content view should load successfully")
        
        // Test that layout completes without issues
        hostingController.view.needsLayout = true
        hostingController.view.layoutSubtreeIfNeeded()
        
        // Verify scroll view exists and is configured properly
        let scrollView = findScrollView(in: hostingController.view)
        XCTAssertNotNil(scrollView, "Very long content should have a scroll view")
        
        if let scrollView = scrollView {
            // Test that scroll indicators are enabled
            XCTAssertTrue(scrollView.hasVerticalScroller, "Scroll view should have vertical scroller for long content")
            
            // Test that the document view is larger than the clip view
            if let documentView = scrollView.documentView,
               let clipView = scrollView.contentView {
                let documentHeight = documentView.frame.height
                let clipHeight = clipView.frame.height
                XCTAssertGreaterThan(documentHeight, clipHeight, 
                                   "Document view should be taller than clip view for scrollable content")
            }
        }
    }
    
    func testScrollViewIndicators() {
        // Test that scroll indicators are properly configured
        let longContent = createLongContent()
        let view = WhatsNewContentView(content: longContent)
        let hostingController = NSHostingController(rootView: view)
        
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 480, height: 400)
        hostingController.loadView()
        hostingController.view.layoutSubtreeIfNeeded()
        
        // Find the scroll view
        let scrollView = findScrollView(in: hostingController.view)
        XCTAssertNotNil(scrollView, "Should have a scroll view for long content")
        
        if let scrollView = scrollView {
            // Test that scroll indicators are shown
            XCTAssertTrue(scrollView.hasVerticalScroller, "Should show vertical scroll indicators")
            
            // Test that horizontal scrolling is disabled (content should wrap)
            XCTAssertFalse(scrollView.hasHorizontalScroller, "Should not show horizontal scroll indicators")
            
            // Test scroll view configuration
            XCTAssertTrue(scrollView.autohidesScrollers, "Should auto-hide scrollers when not needed")
        }
    }
    
    func testScrollViewPerformanceWithLongContent() {
        // Test that scrolling performance is acceptable with long content
        let veryLongContent = createVeryLongContent()
        let view = WhatsNewContentView(content: veryLongContent)
        
        measure {
            let hostingController = NSHostingController(rootView: view)
            hostingController.view.frame = NSRect(x: 0, y: 0, width: 480, height: 400)
            hostingController.loadView()
            hostingController.view.layoutSubtreeIfNeeded()
        }
    }
    
    func testScrollViewInDifferentSizes() {
        // Test scroll view behavior in different window sizes
        let longContent = createLongContent()
        let view = WhatsNewContentView(content: longContent)
        
        let testSizes: [(CGSize, String)] = [
            (CGSize(width: 480, height: 300), "Small"),
            (CGSize(width: 480, height: 600), "Medium"),
            (CGSize(width: 480, height: 900), "Large"),
            (CGSize(width: 600, height: 400), "Wide")
        ]
        
        for (size, sizeName) in testSizes {
            let hostingController = NSHostingController(rootView: view)
            hostingController.view.frame = NSRect(origin: .zero, size: size)
            hostingController.loadView()
            hostingController.view.layoutSubtreeIfNeeded()
            
            // Verify view loads successfully at different sizes
            XCTAssertNotNil(hostingController.view, "View should load successfully at \(sizeName) size")
            
            // Test that scroll view adapts to different sizes
            let scrollView = findScrollView(in: hostingController.view)
            if let scrollView = scrollView {
                let scrollViewFrame = scrollView.frame
                XCTAssertGreaterThan(scrollViewFrame.width, 0, "Scroll view should have valid width at \(sizeName) size")
                XCTAssertGreaterThan(scrollViewFrame.height, 0, "Scroll view should have valid height at \(sizeName) size")
            }
        }
    }
    
    func testScrollViewContentInsets() {
        // Test that scroll view content has proper padding/insets
        let longContent = createLongContent()
        let view = WhatsNewContentView(content: longContent)
        let hostingController = NSHostingController(rootView: view)
        
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 480, height: 400)
        hostingController.loadView()
        hostingController.view.layoutSubtreeIfNeeded()
        
        // Find the scroll view
        let scrollView = findScrollView(in: hostingController.view)
        XCTAssertNotNil(scrollView, "Should have a scroll view")
        
        if let scrollView = scrollView {
            // Test that content insets are reasonable
            let contentInsets = scrollView.contentInsets
            
            // Content should have some padding but not excessive
            XCTAssertGreaterThanOrEqual(contentInsets.top, 0, "Top content inset should be non-negative")
            XCTAssertGreaterThanOrEqual(contentInsets.bottom, 0, "Bottom content inset should be non-negative")
            XCTAssertGreaterThanOrEqual(contentInsets.left, 0, "Left content inset should be non-negative")
            XCTAssertGreaterThanOrEqual(contentInsets.right, 0, "Right content inset should be non-negative")
            
            // Insets shouldn't be excessively large
            XCTAssertLessThan(contentInsets.top, 100, "Top content inset should be reasonable")
            XCTAssertLessThan(contentInsets.bottom, 100, "Bottom content inset should be reasonable")
        }
    }
    
    func testScrollViewInBothAppearanceModes() {
        // Test scroll view behavior in both light and dark modes
        let longContent = createLongContent()
        let view = WhatsNewContentView(content: longContent)
        
        let appearances: [(NSAppearance.Name, String)] = [
            (.aqua, "Light"),
            (.darkAqua, "Dark")
        ]
        
        for (appearanceName, modeName) in appearances {
            NSApp.appearance = NSAppearance(named: appearanceName)
            
            let hostingController = NSHostingController(rootView: view)
            hostingController.view.frame = NSRect(x: 0, y: 0, width: 480, height: 400)
            hostingController.loadView()
            hostingController.view.layoutSubtreeIfNeeded()
            
            // Verify view loads successfully in both modes
            XCTAssertNotNil(hostingController.view, "View should load successfully in \(modeName) mode")
            
            // Test that scroll view works in both appearance modes
            let scrollView = findScrollView(in: hostingController.view)
            XCTAssertNotNil(scrollView, "Should have scroll view in \(modeName) mode")
            
            if let scrollView = scrollView {
                // Test that scroll view is properly configured
                XCTAssertTrue(scrollView.hasVerticalScroller, "Should have vertical scroller in \(modeName) mode")
                
                // Test that the scroll view background adapts to appearance
                XCTAssertNotNil(scrollView.backgroundColor, "Scroll view should have background color in \(modeName) mode")
            }
        }
    }
    
    func testScrollViewAccessibility() {
        // Test that scroll view maintains accessibility with scrollable content
        let longContent = createLongContent()
        let view = WhatsNewContentView(content: longContent)
        let hostingController = NSHostingController(rootView: view)
        
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 480, height: 400)
        hostingController.loadView()
        hostingController.view.layoutSubtreeIfNeeded()
        
        // Test that the view maintains accessibility properties
        let hasAccessibilityElements = hostingController.view.isAccessibilityElement() ||
                                      (hostingController.view.accessibilityElements()?.count ?? 0) > 0
        XCTAssertTrue(hasAccessibilityElements, "Scrollable content should maintain accessibility")
        
        // Test that accessibility label is preserved
        let accessibilityLabel = hostingController.view.accessibilityLabel()
        XCTAssertNotNil(accessibilityLabel, "Scrollable content should have accessibility label")
        
        if let label = accessibilityLabel {
            XCTAssertTrue(label.contains("What's New"), "Accessibility label should mention What's New")
        }
    }
    
    // MARK: - Edge Cases
    
    func testScrollViewWithEmptyContent() {
        // Test scroll view behavior with empty content
        let emptyContent = WhatsNewContent(version: "1.0.0", releaseDate: nil, sections: [])
        let view = WhatsNewContentView(content: emptyContent)
        let hostingController = NSHostingController(rootView: view)
        
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 480, height: 600)
        hostingController.loadView()
        hostingController.view.layoutSubtreeIfNeeded()
        
        // Verify view loads successfully even with empty content
        XCTAssertNotNil(hostingController.view, "View should load successfully with empty content")
        
        // Empty content should still have a scroll view (even if not needed)
        let scrollView = findScrollView(in: hostingController.view)
        if let scrollView = scrollView {
            // With empty content, scrolling shouldn't be necessary
            XCTAssertFalse(scrollView.hasVerticalScroller || scrollView.verticalScroller?.isHidden == false,
                          "Empty content should not require vertical scrolling")
        }
    }
    
    func testScrollViewWithSingleItem() {
        // Test scroll view with minimal content
        let minimalContent = WhatsNewContent(
            version: "1.0.0",
            releaseDate: Date(),
            sections: [
                WhatsNewSection(
                    title: "Updates",
                    items: [
                        WhatsNewItem(title: "Single update", description: "Brief description", isHighlighted: false)
                    ],
                    type: .improvements
                )
            ]
        )
        
        let view = WhatsNewContentView(content: minimalContent)
        let hostingController = NSHostingController(rootView: view)
        
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 480, height: 600)
        hostingController.loadView()
        hostingController.view.layoutSubtreeIfNeeded()
        
        // Verify view loads successfully
        XCTAssertNotNil(hostingController.view, "View should load successfully with minimal content")
        
        // Test that scroll view is present but may not need scrolling
        let scrollView = findScrollView(in: hostingController.view)
        if let scrollView = scrollView {
            // Minimal content should fit without scrolling in a 600pt tall view
            let documentHeight = scrollView.documentView?.frame.height ?? 0
            let clipHeight = scrollView.contentView.frame.height
            
            // Document might be slightly taller due to padding, but shouldn't require scrolling
            XCTAssertLessThanOrEqual(documentHeight, clipHeight + 50, 
                                   "Minimal content should not require significant scrolling")
        }
    }
    
    // MARK: - Helper Methods
    
    private func findScrollView(in view: NSView) -> NSScrollView? {
        // Recursively search for NSScrollView in the view hierarchy
        if let scrollView = view as? NSScrollView {
            return scrollView
        }
        
        for subview in view.subviews {
            if let scrollView = findScrollView(in: subview) {
                return scrollView
            }
        }
        
        return nil
    }
    
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
    
    private func createLongContent() -> WhatsNewContent {
        return WhatsNewContent(
            version: "1.2.0",
            releaseDate: Date(),
            sections: [
                WhatsNewSection(
                    title: "New Features",
                    items: Array(1...5).map { index in
                        WhatsNewItem(
                            title: "Feature \(index)",
                            description: "This is a detailed description for feature \(index) that provides comprehensive information about what this feature does and how it benefits users.",
                            isHighlighted: index <= 2
                        )
                    },
                    type: .newFeatures
                ),
                WhatsNewSection(
                    title: "Improvements",
                    items: Array(1...4).map { index in
                        WhatsNewItem(
                            title: "Improvement \(index)",
                            description: "Description for improvement \(index) with additional details",
                            isHighlighted: false
                        )
                    },
                    type: .improvements
                ),
                WhatsNewSection(
                    title: "Bug Fixes",
                    items: Array(1...3).map { index in
                        WhatsNewItem(
                            title: "Bug Fix \(index)",
                            description: "Fixed issue \(index) that was affecting user experience",
                            isHighlighted: false
                        )
                    },
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
                    items: Array(1...8).map { index in
                        WhatsNewItem(
                            title: "Major Feature \(index)",
                            description: "This is a very detailed description for major feature \(index) that explains in depth what this feature does, how it works, why it's beneficial for users, and how to use it effectively. This description is intentionally long to test scrolling behavior with extensive content.",
                            isHighlighted: index <= 3
                        )
                    },
                    type: .newFeatures
                ),
                WhatsNewSection(
                    title: "Performance Improvements",
                    items: Array(1...6).map { index in
                        WhatsNewItem(
                            title: "Performance Enhancement \(index)",
                            description: "Detailed explanation of performance improvement \(index) including technical details and user benefits",
                            isHighlighted: false
                        )
                    },
                    type: .improvements
                ),
                WhatsNewSection(
                    title: "Bug Fixes and Stability",
                    items: Array(1...10).map { index in
                        WhatsNewItem(
                            title: "Bug Fix \(index)",
                            description: "Comprehensive description of bug fix \(index) including the issue that was resolved and the impact on user experience",
                            isHighlighted: false
                        )
                    },
                    type: .bugFixes
                )
            ]
        )
    }
}