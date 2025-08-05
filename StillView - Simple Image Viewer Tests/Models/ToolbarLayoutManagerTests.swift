import XCTest
@testable import StillView___Simple_Image_Viewer

class ToolbarLayoutManagerTests: XCTestCase {
    
    var layoutManager: ToolbarLayoutManager!
    
    override func setUp() {
        super.setUp()
        layoutManager = ToolbarLayoutManager()
    }
    
    override func tearDown() {
        layoutManager = nil
        super.tearDown()
    }
    
    // MARK: - Layout Calculation Tests
    
    func testLayoutCalculationForDifferentWidths() {
        // Test full layout
        layoutManager.updateLayout(for: 900)
        XCTAssertEqual(layoutManager.currentLayout, .full)
        
        // Test compact layout
        layoutManager.updateLayout(for: 700)
        XCTAssertEqual(layoutManager.currentLayout, .compact)
        
        // Test minimal layout
        layoutManager.updateLayout(for: 500)
        XCTAssertEqual(layoutManager.currentLayout, .minimal)
        
        // Test ultra compact layout
        layoutManager.updateLayout(for: 250)
        XCTAssertEqual(layoutManager.currentLayout, .ultraCompact)
    }
    
    func testResponsiveBreakpoints() {
        let breakpoints = ResponsiveBreakpoints()
        
        XCTAssertEqual(breakpoints.layoutMode(for: 850), .full)
        XCTAssertEqual(breakpoints.layoutMode(for: 750), .compact)
        XCTAssertEqual(breakpoints.layoutMode(for: 450), .minimal)
        XCTAssertEqual(breakpoints.layoutMode(for: 250), .ultraCompact)
        
        // Test edge cases
        XCTAssertEqual(breakpoints.layoutMode(for: 800), .full)
        XCTAssertEqual(breakpoints.layoutMode(for: 600), .compact)
        XCTAssertEqual(breakpoints.layoutMode(for: 400), .minimal)
        XCTAssertEqual(breakpoints.layoutMode(for: 300), .ultraCompact)
    }
    
    // MARK: - Item Visibility Tests
    
    func testOverflowItemPrioritization() {
        // Set to compact layout to trigger overflow
        layoutManager.updateLayout(for: 700)
        
        // Verify that lower priority items are moved to overflow
        let overflowItemIds = layoutManager.overflowItems.map { $0.id }
        
        // Share and delete buttons should be in overflow (priority 3)
        XCTAssertTrue(overflowItemIds.contains("share"))
        XCTAssertTrue(overflowItemIds.contains("delete"))
        
        // Essential items should remain visible
        XCTAssertTrue(layoutManager.isItemVisible("back"))
        XCTAssertTrue(layoutManager.isItemVisible("counter"))
        XCTAssertTrue(layoutManager.isItemVisible("zoom"))
    }
    
    func testEssentialItemsAlwaysVisible() {
        // Test ultra compact layout
        layoutManager.updateLayout(for: 250)
        
        // Essential items with high priority should still be visible
        XCTAssertTrue(layoutManager.isItemVisible("back"))
        XCTAssertTrue(layoutManager.isItemVisible("counter"))
        
        // Even essential items with lower priority might be hidden in ultra compact
        // Only items with priority >= 9 should be visible in ultra compact
    }
    
    func testItemVisibilityInDifferentLayouts() {
        // Full layout - all items visible
        layoutManager.updateLayout(for: 900)
        XCTAssertTrue(layoutManager.isItemVisible("info"))
        XCTAssertTrue(layoutManager.isItemVisible("slideshow"))
        XCTAssertTrue(layoutManager.isItemVisible("share"))
        XCTAssertTrue(layoutManager.isItemVisible("delete"))
        
        // Compact layout - some items in overflow
        layoutManager.updateLayout(for: 700)
        XCTAssertFalse(layoutManager.isItemVisible("share"))
        XCTAssertFalse(layoutManager.isItemVisible("delete"))
        XCTAssertTrue(layoutManager.isItemVisible("thumbnails"))
        XCTAssertTrue(layoutManager.isItemVisible("grid"))
        
        // Minimal layout - only high priority items
        layoutManager.updateLayout(for: 500)
        XCTAssertFalse(layoutManager.isItemVisible("info"))
        XCTAssertFalse(layoutManager.isItemVisible("slideshow"))
        XCTAssertTrue(layoutManager.isItemVisible("zoom"))
    }
    
    // MARK: - Overflow Menu Tests
    
    func testOverflowMenuVisibility() {
        // Full layout should not show overflow button
        layoutManager.updateLayout(for: 900)
        XCTAssertFalse(layoutManager.showOverflowButton)
        
        // Compact layout should show overflow button
        layoutManager.updateLayout(for: 700)
        XCTAssertTrue(layoutManager.showOverflowButton)
        XCTAssertFalse(layoutManager.overflowItems.isEmpty)
    }
    
    func testOverflowMenuToggle() {
        layoutManager.updateLayout(for: 700) // Ensure we have overflow items
        
        XCTAssertFalse(layoutManager.isOverflowMenuPresented)
        
        layoutManager.toggleOverflowMenu()
        XCTAssertTrue(layoutManager.isOverflowMenuPresented)
        
        layoutManager.toggleOverflowMenu()
        XCTAssertFalse(layoutManager.isOverflowMenuPresented)
        
        layoutManager.hideOverflowMenu()
        XCTAssertFalse(layoutManager.isOverflowMenuPresented)
    }
    
    // MARK: - Width Calculation Tests
    
    func testEssentialControlsWidthCalculation() {
        let essentialWidth = layoutManager.calculateEssentialControlsWidth()
        XCTAssertGreaterThan(essentialWidth, 0)
        XCTAssertLessThan(essentialWidth, 300) // Should be reasonable
    }
    
    func testFullToolbarWidthCalculation() {
        let fullWidth = layoutManager.calculateFullToolbarWidth()
        let essentialWidth = layoutManager.calculateEssentialControlsWidth()
        
        XCTAssertGreaterThan(fullWidth, essentialWidth)
        XCTAssertLessThan(fullWidth, 1200) // Should be reasonable
    }
    
    // MARK: - Animation State Tests
    
    func testAnimationStateTransitions() {
        let initialLayout = layoutManager.currentLayout
        
        // Simulate width change
        layoutManager.updateLayout(for: 500)
        
        // Layout should have changed
        XCTAssertNotEqual(layoutManager.currentLayout, initialLayout)
        
        // Overflow items should be updated
        XCTAssertFalse(layoutManager.overflowItems.isEmpty)
    }
    
    // MARK: - Configuration Tests
    
    func testToolbarConfiguration() {
        let config = ToolbarConfiguration.default
        
        XCTAssertEqual(config.sections.count, 3)
        XCTAssertNotNil(config.sections.first { $0.id == "left" })
        XCTAssertNotNil(config.sections.first { $0.id == "center" })
        XCTAssertNotNil(config.sections.first { $0.id == "right" })
        
        // Test breakpoints
        XCTAssertEqual(config.responsiveBreakpoints.fullWidth, 800)
        XCTAssertEqual(config.responsiveBreakpoints.compactWidth, 600)
        XCTAssertEqual(config.responsiveBreakpoints.minimalWidth, 400)
    }
    
    func testToolbarSectionConfiguration() {
        let leftSection = ToolbarSection.leftSection
        
        XCTAssertEqual(leftSection.id, "left")
        XCTAssertEqual(leftSection.position, .left)
        XCTAssertFalse(leftSection.items.isEmpty)
        
        // Test that essential items are marked correctly
        let backButton = leftSection.items.first { $0.id == "back" }
        XCTAssertNotNil(backButton)
        XCTAssertTrue(backButton?.isEssential == true)
        XCTAssertEqual(backButton?.priority, 10)
    }
    
    // MARK: - Performance Tests
    
    func testLayoutCalculationPerformance() {
        measure {
            for width in stride(from: 200, through: 1000, by: 10) {
                layoutManager.updateLayout(for: CGFloat(width))
            }
        }
    }
    
    func testOverflowItemCalculationPerformance() {
        measure {
            for _ in 0..<100 {
                layoutManager.updateLayout(for: 700) // Trigger overflow calculation
            }
        }
    }
}