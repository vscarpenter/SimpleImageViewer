import XCTest
import Combine
import UniformTypeIdentifiers
@testable import StillView___Simple_Image_Viewer

final class FavoritesServiceTests: XCTestCase {
    
    var favoritesService: DefaultFavoritesService!
    var mockPreferencesService: MockPreferencesService!
    var tempDirectory: URL!
    var testImageFile1: ImageFile!
    var testImageFile2: ImageFile!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        cancellables = Set<AnyCancellable>()
        
        // Create temporary directory for test files
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FavoritesServiceTests")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Create test image files
        let testImageURL1 = tempDirectory.appendingPathComponent("test1.jpg")
        let testImageURL2 = tempDirectory.appendingPathComponent("test2.png")
        
        let imageData = createTestJPEGData()
        try imageData.write(to: testImageURL1)
        try imageData.write(to: testImageURL2)
        
        testImageFile1 = try ImageFile(url: testImageURL1)
        testImageFile2 = try ImageFile(url: testImageURL2)
        
        // Create mock preferences service
        mockPreferencesService = MockPreferencesService()
        
        // Create favorites service with mock error handling service
        let mockErrorHandlingService = MockErrorHandlingService()
        favoritesService = DefaultFavoritesService(
            preferencesService: mockPreferencesService,
            errorHandlingService: mockErrorHandlingService
        )
    }
    
    override func tearDownWithError() throws {
        cancellables = nil
        
        // Clean up temporary directory
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
        
        try super.tearDownWithError()
    }
    
    // MARK: - Add to Favorites Tests
    
    func testAddToFavorites_Success() {
        // Given
        XCTAssertFalse(favoritesService.isFavorite(testImageFile1))
        
        // When
        let result = favoritesService.addToFavorites(testImageFile1)
        
        // Then
        XCTAssertTrue(result)
        XCTAssertTrue(favoritesService.isFavorite(testImageFile1))
        XCTAssertEqual(favoritesService.favoriteImages.count, 1)
        XCTAssertEqual(favoritesService.favoriteImages.first?.originalURL, testImageFile1.url)
    }
    
    func testAddToFavorites_AlreadyFavorited() {
        // Given
        _ = favoritesService.addToFavorites(testImageFile1)
        XCTAssertTrue(favoritesService.isFavorite(testImageFile1))
        
        // When
        let result = favoritesService.addToFavorites(testImageFile1)
        
        // Then
        XCTAssertFalse(result) // Should return false for duplicate
        XCTAssertEqual(favoritesService.favoriteImages.count, 1) // Count should remain 1
    }
    
    func testAddToFavorites_MultipleDifferentImages() {
        // When
        let result1 = favoritesService.addToFavorites(testImageFile1)
        let result2 = favoritesService.addToFavorites(testImageFile2)
        
        // Then
        XCTAssertTrue(result1)
        XCTAssertTrue(result2)
        XCTAssertEqual(favoritesService.favoriteImages.count, 2)
        XCTAssertTrue(favoritesService.isFavorite(testImageFile1))
        XCTAssertTrue(favoritesService.isFavorite(testImageFile2))
    }
    
    // MARK: - Remove from Favorites Tests
    
    func testRemoveFromFavorites_Success() {
        // Given
        _ = favoritesService.addToFavorites(testImageFile1)
        XCTAssertTrue(favoritesService.isFavorite(testImageFile1))
        
        // When
        let result = favoritesService.removeFromFavorites(testImageFile1)
        
        // Then
        XCTAssertTrue(result)
        XCTAssertFalse(favoritesService.isFavorite(testImageFile1))
        XCTAssertEqual(favoritesService.favoriteImages.count, 0)
    }
    
    func testRemoveFromFavorites_NotFavorited() {
        // Given
        XCTAssertFalse(favoritesService.isFavorite(testImageFile1))
        
        // When
        let result = favoritesService.removeFromFavorites(testImageFile1)
        
        // Then
        XCTAssertFalse(result) // Should return false if not favorited
        XCTAssertEqual(favoritesService.favoriteImages.count, 0)
    }
    
    func testRemoveFromFavorites_OneOfMultiple() {
        // Given
        _ = favoritesService.addToFavorites(testImageFile1)
        _ = favoritesService.addToFavorites(testImageFile2)
        XCTAssertEqual(favoritesService.favoriteImages.count, 2)
        
        // When
        let result = favoritesService.removeFromFavorites(testImageFile1)
        
        // Then
        XCTAssertTrue(result)
        XCTAssertFalse(favoritesService.isFavorite(testImageFile1))
        XCTAssertTrue(favoritesService.isFavorite(testImageFile2))
        XCTAssertEqual(favoritesService.favoriteImages.count, 1)
    }
    
    // MARK: - Is Favorite Tests
    
    func testIsFavorite_True() {
        // Given
        _ = favoritesService.addToFavorites(testImageFile1)
        
        // When & Then
        XCTAssertTrue(favoritesService.isFavorite(testImageFile1))
    }
    
    func testIsFavorite_False() {
        // When & Then
        XCTAssertFalse(favoritesService.isFavorite(testImageFile1))
    }
    
    // MARK: - Validate Favorites Tests
    
    func testValidateFavorites_RemovesInvalidFiles() async {
        // Given
        _ = favoritesService.addToFavorites(testImageFile1)
        _ = favoritesService.addToFavorites(testImageFile2)
        XCTAssertEqual(favoritesService.favoriteImages.count, 2)
        
        // Delete one of the files
        try! FileManager.default.removeItem(at: testImageFile1.url)
        
        // When
        let removedCount = await favoritesService.validateFavorites(showNotification: false)
        
        // Then
        XCTAssertEqual(removedCount, 1)
        XCTAssertEqual(favoritesService.favoriteImages.count, 1)
        XCTAssertFalse(favoritesService.isFavorite(testImageFile1))
        XCTAssertTrue(favoritesService.isFavorite(testImageFile2))
    }
    
    func testValidateFavorites_UpdatesValidationTimestamp() async {
        // Given
        _ = favoritesService.addToFavorites(testImageFile1)
        let originalValidationDate = favoritesService.favoriteImages.first!.lastValidated
        
        // Wait a small amount to ensure timestamp difference
        try! await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        
        // When
        let removedCount = await favoritesService.validateFavorites(showNotification: false)
        
        // Then
        XCTAssertEqual(removedCount, 0) // No files removed
        let updatedValidationDate = favoritesService.favoriteImages.first!.lastValidated
        XCTAssertGreaterThan(updatedValidationDate, originalValidationDate)
    }
    
    func testValidateFavorites_NoChangesWhenAllValid() async {
        // Given
        _ = favoritesService.addToFavorites(testImageFile1)
        _ = favoritesService.addToFavorites(testImageFile2)
        let originalCount = favoritesService.favoriteImages.count
        
        // When
        let removedCount = await favoritesService.validateFavorites(showNotification: false)
        
        // Then
        XCTAssertEqual(removedCount, 0) // No files removed
        XCTAssertEqual(favoritesService.favoriteImages.count, originalCount)
        XCTAssertTrue(favoritesService.isFavorite(testImageFile1))
        XCTAssertTrue(favoritesService.isFavorite(testImageFile2))
    }
    
    func testValidateFavoritesOnAppLaunch_WithValidFiles() async {
        // Given
        _ = favoritesService.addToFavorites(testImageFile1)
        _ = favoritesService.addToFavorites(testImageFile2)
        
        // When
        await favoritesService.validateFavoritesOnAppLaunch()
        
        // Then
        XCTAssertEqual(favoritesService.favoriteImages.count, 2)
        XCTAssertTrue(favoritesService.isFavorite(testImageFile1))
        XCTAssertTrue(favoritesService.isFavorite(testImageFile2))
    }
    
    func testRefreshFavoritesValidation_WithValidFiles() async {
        // Given
        _ = favoritesService.addToFavorites(testImageFile1)
        _ = favoritesService.addToFavorites(testImageFile2)
        
        // When
        await favoritesService.refreshFavoritesValidation()
        
        // Then
        XCTAssertEqual(favoritesService.favoriteImages.count, 2)
        XCTAssertTrue(favoritesService.isFavorite(testImageFile1))
        XCTAssertTrue(favoritesService.isFavorite(testImageFile2))
    }
    
    // MARK: - Get Valid Favorites Tests
    
    func testGetValidFavorites_ReturnsValidImageFiles() async {
        // Given
        _ = favoritesService.addToFavorites(testImageFile1)
        _ = favoritesService.addToFavorites(testImageFile2)
        
        // When
        let validFavorites = await favoritesService.getValidFavorites()
        
        // Then
        XCTAssertEqual(validFavorites.count, 2)
        XCTAssertTrue(validFavorites.contains { $0.url == testImageFile1.url })
        XCTAssertTrue(validFavorites.contains { $0.url == testImageFile2.url })
    }
    
    func testGetValidFavorites_SkipsInvalidFiles() async {
        // Given
        _ = favoritesService.addToFavorites(testImageFile1)
        _ = favoritesService.addToFavorites(testImageFile2)
        
        // Delete one file
        try! FileManager.default.removeItem(at: testImageFile1.url)
        
        // When
        let validFavorites = await favoritesService.getValidFavorites()
        
        // Then
        XCTAssertEqual(validFavorites.count, 1)
        XCTAssertEqual(validFavorites.first?.url, testImageFile2.url)
    }
    
    func testGetValidFavorites_EmptyWhenNoFavorites() async {
        // When
        let validFavorites = await favoritesService.getValidFavorites()
        
        // Then
        XCTAssertEqual(validFavorites.count, 0)
    }
    
    // MARK: - Batch Remove from Favorites Tests
    
    func testBatchRemoveFromFavorites_Success() {
        // Given
        _ = favoritesService.addToFavorites(testImageFile1)
        _ = favoritesService.addToFavorites(testImageFile2)
        XCTAssertEqual(favoritesService.favoriteImages.count, 2)
        
        let imagesToRemove = [testImageFile1, testImageFile2]
        
        // When
        let removedCount = favoritesService.batchRemoveFromFavorites(imagesToRemove)
        
        // Then
        XCTAssertEqual(removedCount, 2)
        XCTAssertEqual(favoritesService.favoriteImages.count, 0)
        XCTAssertFalse(favoritesService.isFavorite(testImageFile1))
        XCTAssertFalse(favoritesService.isFavorite(testImageFile2))
    }
    
    func testBatchRemoveFromFavorites_PartialRemoval() {
        // Given
        _ = favoritesService.addToFavorites(testImageFile1)
        XCTAssertEqual(favoritesService.favoriteImages.count, 1)
        
        // Try to remove both images, but only one is favorited
        let imagesToRemove = [testImageFile1, testImageFile2]
        
        // When
        let removedCount = favoritesService.batchRemoveFromFavorites(imagesToRemove)
        
        // Then
        XCTAssertEqual(removedCount, 1) // Only one was actually removed
        XCTAssertEqual(favoritesService.favoriteImages.count, 0)
        XCTAssertFalse(favoritesService.isFavorite(testImageFile1))
        XCTAssertFalse(favoritesService.isFavorite(testImageFile2))
    }
    
    func testBatchRemoveFromFavorites_EmptyArray() {
        // Given
        _ = favoritesService.addToFavorites(testImageFile1)
        _ = favoritesService.addToFavorites(testImageFile2)
        XCTAssertEqual(favoritesService.favoriteImages.count, 2)
        
        let imagesToRemove: [ImageFile] = []
        
        // When
        let removedCount = favoritesService.batchRemoveFromFavorites(imagesToRemove)
        
        // Then
        XCTAssertEqual(removedCount, 0)
        XCTAssertEqual(favoritesService.favoriteImages.count, 2) // No change
        XCTAssertTrue(favoritesService.isFavorite(testImageFile1))
        XCTAssertTrue(favoritesService.isFavorite(testImageFile2))
    }
    
    func testBatchRemoveFromFavorites_NonFavoritedImages() {
        // Given
        XCTAssertEqual(favoritesService.favoriteImages.count, 0)
        
        let imagesToRemove = [testImageFile1, testImageFile2]
        
        // When
        let removedCount = favoritesService.batchRemoveFromFavorites(imagesToRemove)
        
        // Then
        XCTAssertEqual(removedCount, 0) // Nothing to remove
        XCTAssertEqual(favoritesService.favoriteImages.count, 0)
        XCTAssertFalse(favoritesService.isFavorite(testImageFile1))
        XCTAssertFalse(favoritesService.isFavorite(testImageFile2))
    }
    
    func testBatchRemoveFromFavorites_MixedFavoritedAndNonFavorited() {
        // Given
        _ = favoritesService.addToFavorites(testImageFile1)
        // testImageFile2 is not favorited
        XCTAssertEqual(favoritesService.favoriteImages.count, 1)
        
        let imagesToRemove = [testImageFile1, testImageFile2]
        
        // When
        let removedCount = favoritesService.batchRemoveFromFavorites(imagesToRemove)
        
        // Then
        XCTAssertEqual(removedCount, 1) // Only the favorited one was removed
        XCTAssertEqual(favoritesService.favoriteImages.count, 0)
        XCTAssertFalse(favoritesService.isFavorite(testImageFile1))
        XCTAssertFalse(favoritesService.isFavorite(testImageFile2))
    }
    
    func testBatchRemoveFromFavorites_CallsSavePreferences() {
        // Given
        _ = favoritesService.addToFavorites(testImageFile1)
        _ = favoritesService.addToFavorites(testImageFile2)
        mockPreferencesService.saveFavoritesCalled = false // Reset flag
        
        let imagesToRemove = [testImageFile1]
        
        // When
        let removedCount = favoritesService.batchRemoveFromFavorites(imagesToRemove)
        
        // Then
        XCTAssertEqual(removedCount, 1)
        XCTAssertTrue(mockPreferencesService.saveFavoritesCalled)
    }
    
    func testBatchRemoveFromFavorites_DoesNotSaveWhenNothingRemoved() {
        // Given
        XCTAssertEqual(favoritesService.favoriteImages.count, 0)
        mockPreferencesService.saveFavoritesCalled = false // Reset flag
        
        let imagesToRemove = [testImageFile1, testImageFile2]
        
        // When
        let removedCount = favoritesService.batchRemoveFromFavorites(imagesToRemove)
        
        // Then
        XCTAssertEqual(removedCount, 0)
        XCTAssertFalse(mockPreferencesService.saveFavoritesCalled)
    }
    
    // MARK: - Edge Case Tests for Batch Removal
    
    func testBatchRemoveFromFavorites_LargeNumberOfFiles() {
        // Given - Add many favorites
        var manyImageFiles: [ImageFile] = []
        for i in 0..<50 {
            let testImageURL = tempDirectory.appendingPathComponent("test\(i).jpg")
            let imageData = createTestJPEGData()
            try! imageData.write(to: testImageURL)
            let imageFile = try! ImageFile(url: testImageURL)
            manyImageFiles.append(imageFile)
            _ = favoritesService.addToFavorites(imageFile)
        }
        
        XCTAssertEqual(favoritesService.favoriteImages.count, 50)
        
        // When - Remove half of them
        let imagesToRemove = Array(manyImageFiles[0..<25])
        let removedCount = favoritesService.batchRemoveFromFavorites(imagesToRemove)
        
        // Then
        XCTAssertEqual(removedCount, 25)
        XCTAssertEqual(favoritesService.favoriteImages.count, 25)
        
        // Verify the correct ones were removed
        for imageFile in imagesToRemove {
            XCTAssertFalse(favoritesService.isFavorite(imageFile))
        }
        
        // Verify the remaining ones are still there
        for imageFile in manyImageFiles[25..<50] {
            XCTAssertTrue(favoritesService.isFavorite(imageFile))
        }
    }
    
    func testBatchRemoveFromFavorites_DuplicateFilesInArray() {
        // Given
        _ = favoritesService.addToFavorites(testImageFile1)
        _ = favoritesService.addToFavorites(testImageFile2)
        XCTAssertEqual(favoritesService.favoriteImages.count, 2)
        
        // When - Try to remove with duplicates in the array
        let imagesToRemove = [testImageFile1, testImageFile2, testImageFile1, testImageFile2]
        let removedCount = favoritesService.batchRemoveFromFavorites(imagesToRemove)
        
        // Then - Should still only remove each file once
        XCTAssertEqual(removedCount, 2)
        XCTAssertEqual(favoritesService.favoriteImages.count, 0)
        XCTAssertFalse(favoritesService.isFavorite(testImageFile1))
        XCTAssertFalse(favoritesService.isFavorite(testImageFile2))
    }
    
    func testBatchRemoveFromFavorites_PerformanceWithManyFiles() {
        // Given - Add many favorites
        var manyImageFiles: [ImageFile] = []
        for i in 0..<100 {
            let testImageURL = tempDirectory.appendingPathComponent("perf_test\(i).jpg")
            let imageData = createTestJPEGData()
            try! imageData.write(to: testImageURL)
            let imageFile = try! ImageFile(url: testImageURL)
            manyImageFiles.append(imageFile)
            _ = favoritesService.addToFavorites(imageFile)
        }
        
        // When - Measure batch removal performance
        let startTime = CFAbsoluteTimeGetCurrent()
        let removedCount = favoritesService.batchRemoveFromFavorites(manyImageFiles)
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then
        XCTAssertEqual(removedCount, 100)
        XCTAssertEqual(favoritesService.favoriteImages.count, 0)
        XCTAssertLessThan(timeElapsed, 1.0, "Batch removal should complete within 1 second for 100 files")
    }
    
    // MARK: - Clear All Favorites Tests
    
    func testClearAllFavorites() {
        // Given
        _ = favoritesService.addToFavorites(testImageFile1)
        _ = favoritesService.addToFavorites(testImageFile2)
        XCTAssertEqual(favoritesService.favoriteImages.count, 2)
        
        // When
        favoritesService.clearAllFavorites()
        
        // Then
        XCTAssertEqual(favoritesService.favoriteImages.count, 0)
        XCTAssertFalse(favoritesService.isFavorite(testImageFile1))
        XCTAssertFalse(favoritesService.isFavorite(testImageFile2))
    }
    
    // MARK: - Publisher Tests
    
    func testFavoriteImagesPublisher_EmitsChanges() {
        // Given
        let expectation = XCTestExpectation(description: "Publisher emits changes")
        var receivedValues: [[FavoriteImageFile]] = []
        
        favoritesService.favoriteImagesPublisher
            .sink { favorites in
                receivedValues.append(favorites)
                if receivedValues.count >= 3 { // Initial empty, after add, after remove
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        _ = favoritesService.addToFavorites(testImageFile1)
        _ = favoritesService.removeFromFavorites(testImageFile1)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedValues.count, 3)
        XCTAssertEqual(receivedValues[0].count, 0) // Initial empty
        XCTAssertEqual(receivedValues[1].count, 1) // After add
        XCTAssertEqual(receivedValues[2].count, 0) // After remove
    }
    
    // MARK: - Persistence Tests
    
    func testPersistence_SavesAndLoadsCorrectly() {
        // Given
        _ = favoritesService.addToFavorites(testImageFile1)
        
        // Verify save was called
        XCTAssertTrue(mockPreferencesService.saveFavoritesCalled)
        XCTAssertEqual(mockPreferencesService.favoriteImages.count, 1)
        
        // When - Create new service instance (simulating app restart)
        let newFavoritesService = DefaultFavoritesService(preferencesService: mockPreferencesService)
        
        // Then
        XCTAssertEqual(newFavoritesService.favoriteImages.count, 1)
        XCTAssertTrue(newFavoritesService.isFavorite(testImageFile1))
    }
    
    // MARK: - Helper Methods
    
    private func createTestJPEGData() -> Data {
        // Create minimal valid JPEG data for testing
        let jpegBytes: [UInt8] = [
            0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
            0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
            0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
            0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
            0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
            0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
            0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
            0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x11, 0x08, 0x00, 0x01,
            0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01,
            0xFF, 0xC4, 0x00, 0x14, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0xFF, 0xC4,
            0x00, 0x14, 0x10, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xDA, 0x00, 0x0C,
            0x03, 0x01, 0x00, 0x02, 0x11, 0x03, 0x11, 0x00, 0x3F, 0x00, 0x8A, 0x00,
            0xFF, 0xD9
        ]
        return Data(jpegBytes)
    }
}

// MARK: - Mock PreferencesService

class MockPreferencesService: PreferencesService {
    var recentFolders: [URL] = []
    var windowFrame: CGRect = .zero
    var showFileName: Bool = false
    var showImageInfo: Bool = false
    var slideshowInterval: Double = 3.0
    var lastSelectedFolder: URL?
    var folderBookmarks: [Data] = []
    var windowState: WindowState?
    var defaultThumbnailGridSize: ThumbnailGridSize = .medium
    var useResponsiveGridLayout: Bool = true
    var favoriteImages: [FavoriteImageFile] = []
    
    var saveFavoritesCalled = false
    var loadFavoritesCalled = false
    
    func addRecentFolder(_ url: URL) {}
    func removeRecentFolder(_ url: URL) {}
    func clearRecentFolders() {}
    func savePreferences() {}
    func loadPreferences() {}
    func saveWindowState(_ windowState: WindowState) {}
    func loadWindowState() -> WindowState? { return nil }
    
    func saveFavorites() {
        saveFavoritesCalled = true
    }
    
    func loadFavorites() -> [FavoriteImageFile] {
        loadFavoritesCalled = true
        return favoriteImages
    }
}

// MARK: - Mock ErrorHandlingService

class MockErrorHandlingService: ErrorHandlingService {
    var notifications: [String] = []
    
    override func showNotification(_ message: String, type: NotificationView.NotificationType) {
        notifications.append("\(type): \(message)")
    }
}