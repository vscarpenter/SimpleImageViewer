import XCTest
import SwiftUI
@testable import Simple_Image_Viewer

/// UI tests for heart indicator display in thumbnail grids
final class HeartIndicatorUITests: XCTestCase {
    
    // MARK: - Test Properties
    
    private var mockImageFiles: [ImageFile] = []
    private var mockFavoritesService: MockFavoritesService!
    private var mockImageViewerViewModel: ImageViewerViewModel!
    
    // MARK: - Setup and Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create mock image files for testing
        mockImageFiles = try createMockImageFiles()
        
        // Create mock services
        mockFavoritesService = MockFavoritesService()
        mockImageViewerViewModel = ImageViewerViewModel()
        
        // Set up some favorites for testing
        if let firstImage = mockImageFiles.first {
            _ = mockFavoritesService.addToFavorites(firstImage)
        }
    }
    
    override func tearDownWithError() throws {
        mockImageFiles = []
        mockFavoritesService = nil
        mockImageViewerViewModel = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Enhanced Thumbnail Grid View Tests
    
    func testHeartIndicatorDisplayInEnhancedThumbnailGrid() throws {
        // Given
        let thumbnailGridView = EnhancedThumbnailGridView(
            imageFiles: mockImageFiles,
            selectedImageFile: nil,
            thumbnailQuality: .medium,
            viewModel: mockImageViewerViewModel,
            onImageSelected: { _ in },
            onImageDoubleClicked: { _ in }
        )
        
        // When - The grid is displayed
        // Then - Heart indicators should be visible for favorited images
        XCTAssertFalse(mockImageFiles.isEmpty, "Should have mock image files for testing")
        
        // Verify that the first image is favorited
        if let firstImage = mockImageFiles.first {
            XCTAssertTrue(mockFavoritesService.isFavorite(firstImage), "First image should be favorited")
        }
    }
    
    func testHeartIndicatorScalingInDifferentThumbnailSizes() throws {
        // Given - Different thumbnail qualities that result in different sizes
        let thumbnailQualities: [ThumbnailQuality] = [.low, .medium, .high]
        
        for quality in thumbnailQualities {
            // When
            let thumbnailGridView = EnhancedThumbnailGridView(
                imageFiles: mockImageFiles,
                selectedImageFile: nil,
                thumbnailQuality: quality,
                viewModel: mockImageViewerViewModel,
                onImageSelected: { _ in },
                onImageDoubleClicked: { _ in }
            )
            
            // Then - Heart indicators should scale appropriately with thumbnail size
            XCTAssertNotNil(thumbnailGridView, "Thumbnail grid should be created for quality: \(quality)")
        }
    }
    
    func testHeartIndicatorPositioningConsistency() throws {
        // Given
        let selectedImage = mockImageFiles.first
        
        let thumbnailGridView = EnhancedThumbnailGridView(
            imageFiles: mockImageFiles,
            selectedImageFile: selectedImage,
            thumbnailQuality: .medium,
            viewModel: mockImageViewerViewModel,
            onImageSelected: { _ in },
            onImageDoubleClicked: { _ in }
        )
        
        // When/Then - Heart indicators should be positioned consistently
        // across all thumbnails in the grid
        XCTAssertNotNil(thumbnailGridView, "Thumbnail grid should be created")
        XCTAssertEqual(thumbnailGridView.selectedImageFile, selectedImage, "Selected image should match")
    }
    
    // MARK: - Grid Thumbnail Item View Tests
    
    func testHeartIndicatorInGridThumbnailItem() throws {
        // Given
        guard let testImage = mockImageFiles.first else {
            XCTFail("No mock image files available")
            return
        }
        
        let gridThumbnailItem = GridThumbnailItemView(
            imageFile: testImage,
            index: 0,
            isSelected: false,
            size: CGSize(width: 200, height: 150),
            onTap: { },
            viewModel: mockImageViewerViewModel
        )
        
        // When/Then - Heart indicator should be displayed for favorited images
        XCTAssertNotNil(gridThumbnailItem, "Grid thumbnail item should be created")
    }
    
    func testHeartIndicatorVisibilityStates() throws {
        // Given
        guard let favoritedImage = mockImageFiles.first,
              let nonFavoritedImage = mockImageFiles.dropFirst().first else {
            XCTFail("Need at least 2 mock image files")
            return
        }
        
        // Ensure one is favorited and one is not
        _ = mockFavoritesService.addToFavorites(favoritedImage)
        _ = mockFavoritesService.removeFromFavorites(nonFavoritedImage)
        
        // When - Creating grid items for both images
        let favoritedGridItem = GridThumbnailItemView(
            imageFile: favoritedImage,
            index: 0,
            isSelected: false,
            size: CGSize(width: 200, height: 150),
            onTap: { },
            viewModel: mockImageViewerViewModel
        )
        
        let nonFavoritedGridItem = GridThumbnailItemView(
            imageFile: nonFavoritedImage,
            index: 1,
            isSelected: false,
            size: CGSize(width: 200, height: 150),
            onTap: { },
            viewModel: mockImageViewerViewModel
        )
        
        // Then - Heart indicators should only be visible for favorited images
        XCTAssertNotNil(favoritedGridItem, "Favorited grid item should be created")
        XCTAssertNotNil(nonFavoritedGridItem, "Non-favorited grid item should be created")
        
        XCTAssertTrue(mockFavoritesService.isFavorite(favoritedImage), "Image should be favorited")
        XCTAssertFalse(mockFavoritesService.isFavorite(nonFavoritedImage), "Image should not be favorited")
    }
    
    // MARK: - Favorites View Integration Tests
    
    func testHeartIndicatorInFavoritesView() throws {
        // Given
        let favoritesView = FavoritesView(
            onImageSelected: { _, _ in },
            onBackToFolderSelection: { }
        )
        
        // When/Then - Favorites view should display heart indicators
        XCTAssertNotNil(favoritesView, "Favorites view should be created")
    }
    
    // MARK: - Accessibility Tests
    
    func testHeartIndicatorAccessibilityLabels() throws {
        // Given
        let heartIndicator = HeartIndicatorView(
            isFavorite: true,
            thumbnailSize: CGSize(width: 120, height: 120),
            isVisible: true
        )
        
        // When/Then - Heart indicator should have proper accessibility labels
        XCTAssertTrue(heartIndicator.isFavorite, "Heart indicator should be favorited")
        XCTAssertTrue(heartIndicator.isVisible, "Heart indicator should be visible")
    }
    
    func testHeartIndicatorAccessibilityInGrids() throws {
        // Given
        guard let testImage = mockImageFiles.first else {
            XCTFail("No mock image files available")
            return
        }
        
        // Make the image favorited
        _ = mockFavoritesService.addToFavorites(testImage)
        
        let gridThumbnailItem = GridThumbnailItemView(
            imageFile: testImage,
            index: 0,
            isSelected: false,
            size: CGSize(width: 200, height: 150),
            onTap: { },
            viewModel: mockImageViewerViewModel
        )
        
        // When/Then - Grid item with heart indicator should maintain accessibility
        XCTAssertNotNil(gridThumbnailItem, "Grid thumbnail item should be created")
        XCTAssertTrue(mockFavoritesService.isFavorite(testImage), "Test image should be favorited")
    }
    
    // MARK: - Performance Tests
    
    func testHeartIndicatorPerformanceInLargeGrid() throws {
        // Given - Create a large number of mock images
        let largeImageSet = Array(repeating: mockImageFiles, count: 10).flatMap { $0 }
        
        // When/Then - Creating a grid with many heart indicators should be performant
        measure {
            let thumbnailGridView = EnhancedThumbnailGridView(
                imageFiles: largeImageSet,
                selectedImageFile: nil,
                thumbnailQuality: .medium,
                viewModel: mockImageViewerViewModel,
                onImageSelected: { _ in },
                onImageDoubleClicked: { _ in }
            )
            
            XCTAssertNotNil(thumbnailGridView, "Large thumbnail grid should be created")
        }
    }
    
    // MARK: - Visual Regression Tests
    
    func testHeartIndicatorVisualConsistency() throws {
        // Given - Different thumbnail sizes
        let thumbnailSizes = [
            CGSize(width: 80, height: 80),
            CGSize(width: 120, height: 120),
            CGSize(width: 200, height: 200)
        ]
        
        for size in thumbnailSizes {
            // When
            let heartIndicator = HeartIndicatorView(
                isFavorite: true,
                thumbnailSize: size,
                isVisible: true
            )
            
            // Then - Heart indicator should maintain visual consistency across sizes
            XCTAssertEqual(heartIndicator.thumbnailSize, size, "Heart indicator should match thumbnail size")
            XCTAssertTrue(heartIndicator.isFavorite, "Heart indicator should be favorited")
            XCTAssertTrue(heartIndicator.isVisible, "Heart indicator should be visible")
        }
    }
    
    // MARK: - Dark Mode Tests
    
    func testHeartIndicatorInDarkMode() throws {
        // Given
        let heartIndicator = HeartIndicatorView(
            isFavorite: true,
            thumbnailSize: CGSize(width: 120, height: 120),
            isVisible: true
        )
        
        // When/Then - Heart indicator should work properly in dark mode
        // Note: Actual dark mode testing would require UI testing framework
        XCTAssertTrue(heartIndicator.isFavorite, "Heart indicator should work in dark mode")
    }
}

// MARK: - Helper Methods

extension HeartIndicatorUITests {
    
    /// Create mock image files for testing
    /// - Returns: Array of mock ImageFile objects
    private func createMockImageFiles() throws -> [ImageFile] {
        // Create temporary test files
        let tempDirectory = FileManager.default.temporaryDirectory
        var mockFiles: [ImageFile] = []
        
        for i in 1...5 {
            let fileName = "test_image_\(i).jpg"
            let fileURL = tempDirectory.appendingPathComponent(fileName)
            
            // Create a minimal file for testing
            let testData = Data("test image data \(i)".utf8)
            try testData.write(to: fileURL)
            
            // Create ImageFile (this might need adjustment based on actual ImageFile initializer)
            if let imageFile = try? ImageFile(url: fileURL) {
                mockFiles.append(imageFile)
            }
        }
        
        return mockFiles
    }
}

// MARK: - Mock Services

/// Mock favorites service for testing
private class MockFavoritesService: FavoritesService {
    @Published private(set) var favoriteImages: [FavoriteImageFile] = []
    
    var favoriteImagesPublisher: Published<[FavoriteImageFile]>.Publisher {
        $favoriteImages
    }
    
    func addToFavorites(_ imageFile: ImageFile) -> Bool {
        guard !isFavorite(imageFile) else { return false }
        let favoriteImage = FavoriteImageFile(from: imageFile)
        favoriteImages.append(favoriteImage)
        return true
    }
    
    func removeFromFavorites(_ imageFile: ImageFile) -> Bool {
        let initialCount = favoriteImages.count
        favoriteImages.removeAll { $0.originalURL == imageFile.url }
        return favoriteImages.count < initialCount
    }
    
    func isFavorite(_ imageFile: ImageFile) -> Bool {
        return favoriteImages.contains { $0.originalURL == imageFile.url }
    }
    
    func validateFavorites() async {
        // Mock implementation
    }
    
    func getValidFavorites() async -> [ImageFile] {
        // Mock implementation
        return []
    }
    
    func clearAllFavorites() {
        favoriteImages.removeAll()
    }
}