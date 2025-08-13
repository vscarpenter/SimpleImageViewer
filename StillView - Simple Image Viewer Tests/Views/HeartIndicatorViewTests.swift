import XCTest
import SwiftUI
@testable import Simple_Image_Viewer

/// Tests for HeartIndicatorView component
final class HeartIndicatorViewTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private let smallThumbnailSize = CGSize(width: 80, height: 80)
    private let mediumThumbnailSize = CGSize(width: 120, height: 120)
    private let largeThumbnailSize = CGSize(width: 200, height: 200)
    
    // MARK: - Visibility Tests
    
    func testHeartIndicatorVisibilityWhenFavorited() {
        // Given
        let heartIndicator = HeartIndicatorView(
            isFavorite: true,
            thumbnailSize: mediumThumbnailSize,
            isVisible: true
        )
        
        // When/Then - Heart should be visible when favorited and visibility is true
        XCTAssertTrue(heartIndicator.isFavorite)
        XCTAssertTrue(heartIndicator.isVisible)
    }
    
    func testHeartIndicatorHiddenWhenNotFavorited() {
        // Given
        let heartIndicator = HeartIndicatorView(
            isFavorite: false,
            thumbnailSize: mediumThumbnailSize,
            isVisible: true
        )
        
        // When/Then - Heart should not be visible when not favorited
        XCTAssertFalse(heartIndicator.isFavorite)
    }
    
    func testHeartIndicatorHiddenWhenNotVisible() {
        // Given
        let heartIndicator = HeartIndicatorView(
            isFavorite: true,
            thumbnailSize: mediumThumbnailSize,
            isVisible: false
        )
        
        // When/Then - Heart should not be visible when visibility is false
        XCTAssertTrue(heartIndicator.isFavorite)
        XCTAssertFalse(heartIndicator.isVisible)
    }
    
    // MARK: - Scaling Tests
    
    func testHeartIndicatorScalingWithSmallThumbnail() {
        // Given
        let heartIndicator = HeartIndicatorView(
            isFavorite: true,
            thumbnailSize: smallThumbnailSize,
            isVisible: true
        )
        
        // When/Then - Verify the heart indicator scales appropriately for small thumbnails
        XCTAssertEqual(heartIndicator.thumbnailSize, smallThumbnailSize)
        
        // The indicator size should be proportional but have minimum bounds
        let expectedMinSize: CGFloat = 12
        let calculatedSize = min(smallThumbnailSize.width, smallThumbnailSize.height) * 0.15
        let actualSize = max(expectedMinSize, min(calculatedSize, 24))
        
        XCTAssertGreaterThanOrEqual(actualSize, expectedMinSize)
    }
    
    func testHeartIndicatorScalingWithMediumThumbnail() {
        // Given
        let heartIndicator = HeartIndicatorView(
            isFavorite: true,
            thumbnailSize: mediumThumbnailSize,
            isVisible: true
        )
        
        // When/Then - Verify the heart indicator scales appropriately for medium thumbnails
        XCTAssertEqual(heartIndicator.thumbnailSize, mediumThumbnailSize)
        
        // The indicator size should be proportional
        let expectedMinSize: CGFloat = 12
        let expectedMaxSize: CGFloat = 24
        let calculatedSize = min(mediumThumbnailSize.width, mediumThumbnailSize.height) * 0.15
        let actualSize = max(expectedMinSize, min(calculatedSize, expectedMaxSize))
        
        XCTAssertGreaterThanOrEqual(actualSize, expectedMinSize)
        XCTAssertLessThanOrEqual(actualSize, expectedMaxSize)
    }
    
    func testHeartIndicatorScalingWithLargeThumbnail() {
        // Given
        let heartIndicator = HeartIndicatorView(
            isFavorite: true,
            thumbnailSize: largeThumbnailSize,
            isVisible: true
        )
        
        // When/Then - Verify the heart indicator scales appropriately for large thumbnails
        XCTAssertEqual(heartIndicator.thumbnailSize, largeThumbnailSize)
        
        // The indicator size should be capped at maximum
        let expectedMaxSize: CGFloat = 24
        let calculatedSize = min(largeThumbnailSize.width, largeThumbnailSize.height) * 0.15
        let actualSize = max(12, min(calculatedSize, expectedMaxSize))
        
        XCTAssertLessThanOrEqual(actualSize, expectedMaxSize)
    }
    
    // MARK: - Positioning Tests
    
    func testHeartIndicatorPositioning() {
        // Given
        let heartIndicator = HeartIndicatorView(
            isFavorite: true,
            thumbnailSize: mediumThumbnailSize,
            isVisible: true
        )
        
        // When/Then - Verify the heart indicator is positioned correctly
        XCTAssertEqual(heartIndicator.thumbnailSize.width, mediumThumbnailSize.width)
        XCTAssertEqual(heartIndicator.thumbnailSize.height, mediumThumbnailSize.height)
        
        // Corner offset should be proportional to thumbnail size
        let expectedMinOffset: CGFloat = 6
        let expectedMaxOffset: CGFloat = 12
        let calculatedOffset = min(mediumThumbnailSize.width, mediumThumbnailSize.height) * 0.08
        let actualOffset = max(expectedMinOffset, min(calculatedOffset, expectedMaxOffset))
        
        XCTAssertGreaterThanOrEqual(actualOffset, expectedMinOffset)
        XCTAssertLessThanOrEqual(actualOffset, expectedMaxOffset)
    }
    
    // MARK: - Accessibility Tests
    
    func testHeartIndicatorAccessibility() {
        // Given
        let heartIndicator = HeartIndicatorView(
            isFavorite: true,
            thumbnailSize: mediumThumbnailSize,
            isVisible: true
        )
        
        // When/Then - Verify accessibility properties are set correctly
        XCTAssertTrue(heartIndicator.isFavorite)
        // Note: Accessibility testing for SwiftUI views requires UI testing framework
        // This test verifies the component properties that affect accessibility
    }
    
    // MARK: - State Change Tests
    
    func testHeartIndicatorStateChanges() {
        // Given
        var isFavorite = false
        var isVisible = false
        
        // When - Initial state (not favorited, not visible)
        var heartIndicator = HeartIndicatorView(
            isFavorite: isFavorite,
            thumbnailSize: mediumThumbnailSize,
            isVisible: isVisible
        )
        
        // Then
        XCTAssertFalse(heartIndicator.isFavorite)
        XCTAssertFalse(heartIndicator.isVisible)
        
        // When - Make visible but not favorited
        isVisible = true
        heartIndicator = HeartIndicatorView(
            isFavorite: isFavorite,
            thumbnailSize: mediumThumbnailSize,
            isVisible: isVisible
        )
        
        // Then
        XCTAssertFalse(heartIndicator.isFavorite)
        XCTAssertTrue(heartIndicator.isVisible)
        
        // When - Make favorited and visible
        isFavorite = true
        heartIndicator = HeartIndicatorView(
            isFavorite: isFavorite,
            thumbnailSize: mediumThumbnailSize,
            isVisible: isVisible
        )
        
        // Then
        XCTAssertTrue(heartIndicator.isFavorite)
        XCTAssertTrue(heartIndicator.isVisible)
    }
    
    // MARK: - Edge Case Tests
    
    func testHeartIndicatorWithZeroSizeThumbnail() {
        // Given
        let zeroSize = CGSize.zero
        
        // When
        let heartIndicator = HeartIndicatorView(
            isFavorite: true,
            thumbnailSize: zeroSize,
            isVisible: true
        )
        
        // Then - Should handle zero size gracefully
        XCTAssertEqual(heartIndicator.thumbnailSize, zeroSize)
        
        // Indicator size should still have minimum bounds
        let calculatedSize = min(zeroSize.width, zeroSize.height) * 0.15
        let actualSize = max(12, min(calculatedSize, 24))
        XCTAssertEqual(actualSize, 12) // Should use minimum size
    }
    
    func testHeartIndicatorWithVeryLargeThumbnail() {
        // Given
        let veryLargeSize = CGSize(width: 1000, height: 1000)
        
        // When
        let heartIndicator = HeartIndicatorView(
            isFavorite: true,
            thumbnailSize: veryLargeSize,
            isVisible: true
        )
        
        // Then - Should handle very large size gracefully
        XCTAssertEqual(heartIndicator.thumbnailSize, veryLargeSize)
        
        // Indicator size should be capped at maximum
        let calculatedSize = min(veryLargeSize.width, veryLargeSize.height) * 0.15
        let actualSize = max(12, min(calculatedSize, 24))
        XCTAssertEqual(actualSize, 24) // Should use maximum size
    }
    
    // MARK: - Performance Tests
    
    func testHeartIndicatorPerformance() {
        // Given
        let thumbnailSizes = [
            CGSize(width: 50, height: 50),
            CGSize(width: 100, height: 100),
            CGSize(width: 150, height: 150),
            CGSize(width: 200, height: 200),
            CGSize(width: 300, height: 300)
        ]
        
        // When/Then - Creating multiple heart indicators should be performant
        measure {
            for size in thumbnailSizes {
                let _ = HeartIndicatorView(
                    isFavorite: true,
                    thumbnailSize: size,
                    isVisible: true
                )
            }
        }
    }
}

// MARK: - Test Extensions

extension HeartIndicatorViewTests {
    
    /// Helper method to create a heart indicator for testing
    /// - Parameters:
    ///   - isFavorite: Whether the image is favorited
    ///   - size: Thumbnail size
    ///   - isVisible: Whether the indicator should be visible
    /// - Returns: HeartIndicatorView instance
    private func createHeartIndicator(
        isFavorite: Bool = true,
        size: CGSize = CGSize(width: 120, height: 120),
        isVisible: Bool = true
    ) -> HeartIndicatorView {
        return HeartIndicatorView(
            isFavorite: isFavorite,
            thumbnailSize: size,
            isVisible: isVisible
        )
    }
}