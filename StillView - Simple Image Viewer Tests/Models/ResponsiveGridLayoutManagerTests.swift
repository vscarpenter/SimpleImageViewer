import XCTest
import SwiftUI
@testable import Simple_Image_Viewer

final class ResponsiveGridLayoutManagerTests: XCTestCase {
    var layoutManager: ResponsiveGridLayoutManager!
    var mockPreferencesService: MockPreferencesService!
    
    override func setUp() {
        super.setUp()
        mockPreferencesService = MockPreferencesService()
        layoutManager = ResponsiveGridLayoutManager(preferencesService: mockPreferencesService)
    }
    
    override func tearDown() {
        layoutManager = nil
        mockPreferencesService = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(layoutManager)
        XCTAssertEqual(layoutManager.effectiveGridSize, .medium) // Default
        XCTAssertTrue(layoutManager.isResponsiveLayoutEnabled) // Default
        XCTAssertEqual(layoutManager.windowSize, .zero) // Initial
    }
    
    func testInitializationWithCustomPreferences() {
        mockPreferencesService.defaultThumbnailGridSize = .large
        mockPreferencesService.useResponsiveGridLayout = false
        
        let customLayoutManager = ResponsiveGridLayoutManager(preferencesService: mockPreferencesService)
        
        XCTAssertEqual(customLayoutManager.effectiveGridSize, .large)
        XCTAssertFalse(customLayoutManager.isResponsiveLayoutEnabled)
    }
    
    // MARK: - Window Size Update Tests
    
    func testUpdateWindowSizeSmall() {
        let smallSize = CGSize(width: 400, height: 300)
        layoutManager.updateWindowSize(smallSize)
        
        XCTAssertEqual(layoutManager.windowSize, smallSize)
        XCTAssertEqual(layoutManager.effectiveGridSize, .small)
    }
    
    func testUpdateWindowSizeMedium() {
        let mediumSize = CGSize(width: 800, height: 600)
        layoutManager.updateWindowSize(mediumSize)
        
        XCTAssertEqual(layoutManager.windowSize, mediumSize)
        XCTAssertEqual(layoutManager.effectiveGridSize, .medium)
    }
    
    func testUpdateWindowSizeLarge() {
        let largeSize = CGSize(width: 1200, height: 800)
        layoutManager.updateWindowSize(largeSize)
        
        XCTAssertEqual(layoutManager.windowSize, largeSize)
        XCTAssertEqual(layoutManager.effectiveGridSize, .large)
    }
    
    // MARK: - User Preference Tests
    
    func testSetUserPreferredGridSize() {
        layoutManager.setUserPreferredGridSize(.large)
        
        XCTAssertEqual(mockPreferencesService.defaultThumbnailGridSize, .large)
        XCTAssertTrue(mockPreferencesService.savePreferencesCalled)
    }
    
    func testSetResponsiveLayoutEnabled() {
        layoutManager.setResponsiveLayoutEnabled(false)
        
        XCTAssertFalse(layoutManager.isResponsiveLayoutEnabled)
        XCTAssertFalse(mockPreferencesService.useResponsiveGridLayout)
        XCTAssertTrue(mockPreferencesService.savePreferencesCalled)
    }
    
    // MARK: - Responsive Layout Tests
    
    func testResponsiveLayoutDisabled() {
        layoutManager.setResponsiveLayoutEnabled(false)
        layoutManager.setUserPreferredGridSize(.small)
        
        // Even with large window, should use user preference when responsive is disabled
        let largeSize = CGSize(width: 1200, height: 800)
        layoutManager.updateWindowSize(largeSize)
        
        XCTAssertEqual(layoutManager.effectiveGridSize, .small)
    }
    
    func testResponsiveLayoutEnabled() {
        layoutManager.setResponsiveLayoutEnabled(true)
        layoutManager.setUserPreferredGridSize(.small)
        
        // With responsive enabled, should adapt to window size
        let largeSize = CGSize(width: 1200, height: 800)
        layoutManager.updateWindowSize(largeSize)
        
        // Should not be small for large window
        XCTAssertNotEqual(layoutManager.effectiveGridSize, .small)
    }
    
    // MARK: - Column Count Tests
    
    func testGetOptimalColumnCountSmallWindow() {
        layoutManager.updateWindowSize(CGSize(width: 400, height: 300))
        let columnCount = layoutManager.getOptimalColumnCount()
        
        XCTAssertGreaterThan(columnCount, 0)
        XCTAssertLessThanOrEqual(columnCount, ThumbnailGridSize.small.columnCount * 2)
    }
    
    func testGetOptimalColumnCountLargeWindow() {
        layoutManager.updateWindowSize(CGSize(width: 1600, height: 1000))
        let columnCount = layoutManager.getOptimalColumnCount()
        
        XCTAssertGreaterThan(columnCount, 0)
        // Should allow more columns for larger windows
        XCTAssertGreaterThanOrEqual(columnCount, ThumbnailGridSize.medium.columnCount)
    }
    
    func testGetOptimalColumnCountWithResponsiveDisabled() {
        layoutManager.setResponsiveLayoutEnabled(false)
        layoutManager.setUserPreferredGridSize(.medium)
        
        let columnCount = layoutManager.getOptimalColumnCount()
        XCTAssertEqual(columnCount, ThumbnailGridSize.medium.columnCount)
    }
    
    // MARK: - Thumbnail Size Tests
    
    func testGetOptimalThumbnailSize() {
        layoutManager.updateWindowSize(CGSize(width: 800, height: 600))
        let thumbnailSize = layoutManager.getOptimalThumbnailSize()
        
        XCTAssertGreaterThan(thumbnailSize.width, 0)
        XCTAssertGreaterThan(thumbnailSize.height, 0)
        
        // Should maintain reasonable aspect ratio
        let aspectRatio = thumbnailSize.width / thumbnailSize.height
        XCTAssertGreaterThan(aspectRatio, 1.0) // Width should be greater than height
        XCTAssertLessThan(aspectRatio, 2.0) // But not too wide
    }
    
    func testGetOptimalThumbnailSizeConstraints() {
        // Test with very small window
        layoutManager.updateWindowSize(CGSize(width: 200, height: 150))
        let smallThumbnailSize = layoutManager.getOptimalThumbnailSize()
        
        // Should not be smaller than minimum
        XCTAssertGreaterThanOrEqual(smallThumbnailSize.width, 80)
        XCTAssertGreaterThanOrEqual(smallThumbnailSize.height, 60)
        
        // Test with very large window
        layoutManager.updateWindowSize(CGSize(width: 2000, height: 1500))
        let largeThumbnailSize = layoutManager.getOptimalThumbnailSize()
        
        // Should not exceed maximum
        XCTAssertLessThanOrEqual(largeThumbnailSize.width, 300)
        XCTAssertLessThanOrEqual(largeThumbnailSize.height, 225)
    }
    
    // MARK: - Grid Columns Tests
    
    func testGetGridColumns() {
        layoutManager.updateWindowSize(CGSize(width: 800, height: 600))
        let gridColumns = layoutManager.getGridColumns()
        
        XCTAssertFalse(gridColumns.isEmpty)
        XCTAssertEqual(gridColumns.count, layoutManager.getOptimalColumnCount())
        
        // All columns should be flexible
        for column in gridColumns {
            XCTAssertEqual(column.size, .flexible())
        }
    }
    
    // MARK: - Layout Metrics Tests
    
    func testGetCurrentLayoutMetrics() {
        layoutManager.updateWindowSize(CGSize(width: 800, height: 600))
        let metrics = layoutManager.getCurrentLayoutMetrics()
        
        XCTAssertNotNil(metrics.gridSize)
        XCTAssertGreaterThan(metrics.columnCount, 0)
        XCTAssertGreaterThan(metrics.thumbnailSize.width, 0)
        XCTAssertGreaterThan(metrics.thumbnailSize.height, 0)
        XCTAssertGreaterThan(metrics.spacing, 0)
        XCTAssertGreaterThan(metrics.padding, 0)
        XCTAssertEqual(metrics.isResponsive, layoutManager.isResponsiveLayoutEnabled)
    }
    
    // MARK: - Layout Update Tests
    
    func testShouldUpdateLayoutSignificantChange() {
        layoutManager.updateWindowSize(CGSize(width: 800, height: 600))
        
        let newSize = CGSize(width: 1000, height: 700)
        let shouldUpdate = layoutManager.shouldUpdateLayout(for: newSize)
        
        XCTAssertTrue(shouldUpdate)
    }
    
    func testShouldUpdateLayoutMinorChange() {
        layoutManager.updateWindowSize(CGSize(width: 800, height: 600))
        
        let newSize = CGSize(width: 810, height: 605)
        let shouldUpdate = layoutManager.shouldUpdateLayout(for: newSize)
        
        XCTAssertFalse(shouldUpdate)
    }
    
    // MARK: - Edge Cases Tests
    
    func testVerySmallWindow() {
        let tinySize = CGSize(width: 100, height: 100)
        layoutManager.updateWindowSize(tinySize)
        
        // Should still provide valid layout
        XCTAssertGreaterThan(layoutManager.getOptimalColumnCount(), 0)
        XCTAssertGreaterThan(layoutManager.getOptimalThumbnailSize().width, 0)
    }
    
    func testVeryLargeWindow() {
        let hugeSize = CGSize(width: 3000, height: 2000)
        layoutManager.updateWindowSize(hugeSize)
        
        // Should still provide reasonable layout
        let columnCount = layoutManager.getOptimalColumnCount()
        XCTAssertLessThanOrEqual(columnCount, 20) // Reasonable upper bound
        
        let thumbnailSize = layoutManager.getOptimalThumbnailSize()
        XCTAssertLessThanOrEqual(thumbnailSize.width, 300) // Should respect maximum
    }
    
    func testZeroSizeWindow() {
        let zeroSize = CGSize.zero
        layoutManager.updateWindowSize(zeroSize)
        
        // Should handle gracefully
        XCTAssertGreaterThan(layoutManager.getOptimalColumnCount(), 0)
        XCTAssertGreaterThan(layoutManager.getOptimalThumbnailSize().width, 0)
    }
    
    // MARK: - Performance Tests
    
    func testLayoutCalculationPerformance() {
        measure {
            for _ in 0..<100 {
                layoutManager.updateWindowSize(CGSize(width: 800, height: 600))
                _ = layoutManager.getOptimalColumnCount()
                _ = layoutManager.getOptimalThumbnailSize()
                _ = layoutManager.getGridColumns()
            }
        }
    }
    
    func testResponsiveCalculationPerformance() {
        let windowSizes = [
            CGSize(width: 400, height: 300),
            CGSize(width: 800, height: 600),
            CGSize(width: 1200, height: 800),
            CGSize(width: 1600, height: 1000)
        ]
        
        measure {
            for size in windowSizes {
                for _ in 0..<25 {
                    layoutManager.updateWindowSize(size)
                    _ = layoutManager.getCurrentLayoutMetrics()
                }
            }
        }
    }
}

// MARK: - Mock Preferences Service

private class MockPreferencesService: PreferencesService {
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
    
    var savePreferencesCalled = false
    
    func addRecentFolder(_ url: URL) {
        recentFolders.insert(url, at: 0)
    }
    
    func removeRecentFolder(_ url: URL) {
        recentFolders.removeAll { $0 == url }
    }
    
    func clearRecentFolders() {
        recentFolders.removeAll()
    }
    
    func savePreferences() {
        savePreferencesCalled = true
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

// MARK: - ThumbnailGridSize Extension Tests

extension ResponsiveGridLayoutManagerTests {
    
    func testThumbnailGridSizeResponsiveVariant() {
        // Test small window
        let smallVariant = ThumbnailGridSize.large.responsiveVariant(for: CGSize(width: 400, height: 300))
        XCTAssertEqual(smallVariant, .small)
        
        // Test large window
        let largeVariant = ThumbnailGridSize.medium.responsiveVariant(for: CGSize(width: 1500, height: 1000))
        XCTAssertEqual(largeVariant, .large)
        
        // Test medium window
        let mediumVariant = ThumbnailGridSize.medium.responsiveVariant(for: CGSize(width: 800, height: 600))
        XCTAssertEqual(mediumVariant, .medium)
    }
    
    func testThumbnailGridSizeOptimalColumnCount() {
        let gridSize = ThumbnailGridSize.medium
        
        // Test with different window widths
        let smallWidth: CGFloat = 400
        let smallColumns = gridSize.optimalColumnCount(for: smallWidth)
        XCTAssertGreaterThan(smallColumns, 0)
        XCTAssertLessThanOrEqual(smallColumns, gridSize.columnCount * 2)
        
        let largeWidth: CGFloat = 1200
        let largeColumns = gridSize.optimalColumnCount(for: largeWidth)
        XCTAssertGreaterThanOrEqual(largeColumns, smallColumns)
    }
}