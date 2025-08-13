import XCTest
import Combine
import SwiftUI
@testable import StillView___Simple_Image_Viewer

/// Integration tests for favorites removal and management functionality
@MainActor
final class FavoritesRemovalIntegrationTests: XCTestCase {
    
    // MARK: - Properties
    
    private var favoritesService: DefaultFavoritesService!
    private var favoritesViewModel: FavoritesViewModel!
    private var mockPreferencesService: MockPreferencesService!
    private var mockErrorHandlingService: MockErrorHandlingService!
    private var tempDirectory: URL!
    private var testImageFiles: [ImageFile] = []
    private var cancellables: Set<AnyCancellable>!
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        cancellables = Set<AnyCancellable>()
        
        // Create temporary directory for test files
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FavoritesRemovalIntegrationTests")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Create test image files
        testImageFiles = try createTestImageFiles(count: 5)
        
        // Create mock services
        mockPreferencesService = MockPreferencesService()
        mockErrorHandlingService = MockErrorHandlingService()
        
        // Create favorites service and view model
        favoritesService = DefaultFavoritesService(
            preferencesService: mockPreferencesService,
            errorHandlingService: mockErrorHandlingService
        )
        
        favoritesViewModel = FavoritesViewModel(
            favoritesService: favoritesService,
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
    
    // MARK: - End-to-End Removal Tests
    
    func testCompleteRemovalWorkflow() async {
        // Given - Add favorites through the service
        for imageFile in testImageFiles {
            XCTAssertTrue(favoritesService.addToFavorites(imageFile))
        }
        
        // Load favorites in view model
        favoritesViewModel.loadFavorites()
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Verify initial state
        XCTAssertEqual(favoritesViewModel.favoriteImageFiles.count, 5)
        XCTAssertTrue(favoritesViewModel.hasFavorites)
        
        // When - Remove single favorite
        let imageToRemove = testImageFiles[2]
        favoritesViewModel.removeFromFavorites(imageToRemove)
        
        // Then - Verify single removal
        XCTAssertEqual(favoritesViewModel.favoriteImageFiles.count, 4)
        XCTAssertFalse(favoritesViewModel.favoriteImageFiles.contains { $0.url == imageToRemove.url })
        XCTAssertTrue(mockErrorHandlingService.showNotificationCalled)
        XCTAssertEqual(mockErrorHandlingService.lastNotificationType, .success)
        
        // When - Batch remove multiple favorites
        let imagesToBatchRemove = Array(testImageFiles[0...1])
        let removedCount = favoritesViewModel.batchRemoveFromFavorites(imagesToBatchRemove)
        
        // Then - Verify batch removal
        XCTAssertEqual(removedCount, 2)
        XCTAssertEqual(favoritesViewModel.favoriteImageFiles.count, 2)
        for imageFile in imagesToBatchRemove {
            XCTAssertFalse(favoritesViewModel.favoriteImageFiles.contains { $0.url == imageFile.url })
        }
        
        // When - Remove all remaining favorites
        let allRemovedCount = favoritesViewModel.removeAllFavorites()
        
        // Then - Verify complete removal
        XCTAssertEqual(allRemovedCount, 2)
        XCTAssertTrue(favoritesViewModel.favoriteImageFiles.isEmpty)
        XCTAssertFalse(favoritesViewModel.hasFavorites)
        XCTAssertNil(favoritesViewModel.selectedFavoriteImage)
    }
    
    func testRemovalWithFileSystemChanges() async {
        // Given - Add favorites
        for imageFile in testImageFiles {
            XCTAssertTrue(favoritesService.addToFavorites(imageFile))
        }
        
        favoritesViewModel.loadFavorites()
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        XCTAssertEqual(favoritesViewModel.favoriteImageFiles.count, 5)
        
        // When - Delete a file from the file system
        let fileToDelete = testImageFiles[1]
        try FileManager.default.removeItem(at: fileToDelete.url)
        
        // Refresh favorites to trigger validation
        favoritesViewModel.refreshFavorites()
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Then - Verify automatic cleanup
        XCTAssertEqual(favoritesViewModel.favoriteImageFiles.count, 4)
        XCTAssertFalse(favoritesViewModel.favoriteImageFiles.contains { $0.url == fileToDelete.url })
        
        // When - Try to remove the already-deleted file
        favoritesViewModel.removeFromFavorites(fileToDelete)
        
        // Then - Should handle gracefully
        XCTAssertEqual(favoritesViewModel.favoriteImageFiles.count, 4) // No change
    }
    
    func testSelectionStateManagementDuringRemoval() async {
        // Given - Add favorites and load them
        for imageFile in testImageFiles {
            XCTAssertTrue(favoritesService.addToFavorites(imageFile))
        }
        
        favoritesViewModel.loadFavorites()
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Select a favorite
        let selectedImage = testImageFiles[2]
        favoritesViewModel.selectFavorite(selectedImage)
        XCTAssertEqual(favoritesViewModel.selectedFavoriteImage?.url, selectedImage.url)
        
        // When - Remove the selected favorite
        favoritesViewModel.removeFromFavorites(selectedImage)
        
        // Then - Selection should be cleared
        XCTAssertNil(favoritesViewModel.selectedFavoriteImage)
        XCTAssertEqual(favoritesViewModel.favoriteImageFiles.count, 4)
        
        // When - Select another favorite and remove a different one
        let newSelectedImage = testImageFiles[0]
        let imageToRemove = testImageFiles[1]
        favoritesViewModel.selectFavorite(newSelectedImage)
        favoritesViewModel.removeFromFavorites(imageToRemove)
        
        // Then - Selection should be preserved
        XCTAssertEqual(favoritesViewModel.selectedFavoriteImage?.url, newSelectedImage.url)
        XCTAssertEqual(favoritesViewModel.favoriteImageFiles.count, 3)
    }
    
    func testBatchRemovalPerformance() async {
        // Given - Create many test files
        let manyTestFiles = try createTestImageFiles(count: 50)
        
        // Add all to favorites
        for imageFile in manyTestFiles {
            XCTAssertTrue(favoritesService.addToFavorites(imageFile))
        }
        
        favoritesViewModel.loadFavorites()
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        XCTAssertEqual(favoritesViewModel.favoriteImageFiles.count, 50)
        
        // When - Measure batch removal performance
        let startTime = CFAbsoluteTimeGetCurrent()
        let removedCount = favoritesViewModel.batchRemoveFromFavorites(manyTestFiles)
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then - Should complete quickly and successfully
        XCTAssertEqual(removedCount, 50)
        XCTAssertTrue(favoritesViewModel.favoriteImageFiles.isEmpty)
        XCTAssertLessThan(timeElapsed, 2.0, "Batch removal should complete within 2 seconds for 50 files")
        XCTAssertTrue(mockErrorHandlingService.showNotificationCalled)
        XCTAssertEqual(mockErrorHandlingService.lastNotificationType, .success)
    }
    
    func testRemovalErrorHandling() async {
        // Given - Add favorites
        for imageFile in testImageFiles {
            XCTAssertTrue(favoritesService.addToFavorites(imageFile))
        }
        
        favoritesViewModel.loadFavorites()
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // When - Try to remove empty array
        let removedCount = favoritesViewModel.batchRemoveFromFavorites([])
        
        // Then - Should handle gracefully
        XCTAssertEqual(removedCount, 0)
        XCTAssertEqual(favoritesViewModel.favoriteImageFiles.count, 5) // No change
        XCTAssertTrue(mockErrorHandlingService.showNotificationCalled)
        XCTAssertEqual(mockErrorHandlingService.lastNotificationType, .info)
        
        // When - Try to remove all from empty favorites
        favoritesViewModel.removeAllFavorites() // Remove all first
        mockErrorHandlingService.reset() // Reset notification tracking
        
        let emptyRemovalCount = favoritesViewModel.removeAllFavorites()
        
        // Then - Should handle gracefully
        XCTAssertEqual(emptyRemovalCount, 0)
        XCTAssertTrue(mockErrorHandlingService.showNotificationCalled)
        XCTAssertEqual(mockErrorHandlingService.lastNotificationType, .info)
    }
    
    func testPersistenceAfterRemoval() async {
        // Given - Add favorites
        for imageFile in testImageFiles {
            XCTAssertTrue(favoritesService.addToFavorites(imageFile))
        }
        
        favoritesViewModel.loadFavorites()
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        XCTAssertEqual(favoritesViewModel.favoriteImageFiles.count, 5)
        
        // When - Remove some favorites
        let imagesToRemove = Array(testImageFiles[1...3])
        let removedCount = favoritesViewModel.batchRemoveFromFavorites(imagesToRemove)
        
        // Then - Verify persistence was updated
        XCTAssertEqual(removedCount, 3)
        XCTAssertTrue(mockPreferencesService.saveFavoritesCalled)
        XCTAssertEqual(mockPreferencesService.favoriteImages.count, 2)
        
        // When - Create new view model (simulating app restart)
        let newViewModel = FavoritesViewModel(
            favoritesService: favoritesService,
            errorHandlingService: mockErrorHandlingService
        )
        
        newViewModel.loadFavorites()
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then - Should load the correct remaining favorites
        XCTAssertEqual(newViewModel.favoriteImageFiles.count, 2)
        XCTAssertTrue(newViewModel.hasFavorites)
        
        // Verify the correct ones remain
        let remainingUrls = Set(newViewModel.favoriteImageFiles.map { $0.url })
        XCTAssertTrue(remainingUrls.contains(testImageFiles[0].url))
        XCTAssertTrue(remainingUrls.contains(testImageFiles[4].url))
        
        // Verify the removed ones are gone
        for removedImage in imagesToRemove {
            XCTAssertFalse(remainingUrls.contains(removedImage.url))
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestImageFiles(count: Int) throws -> [ImageFile] {
        var imageFiles: [ImageFile] = []
        
        for index in 0..<count {
            let testImageURL = tempDirectory.appendingPathComponent("test\(index).jpg")
            let imageData = createTestJPEGData()
            try imageData.write(to: testImageURL)
            let imageFile = try ImageFile(url: testImageURL)
            imageFiles.append(imageFile)
        }
        
        return imageFiles
    }
    
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

// MARK: - Mock Services

private class MockPreferencesService: PreferencesService {
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

private class MockErrorHandlingService: ErrorHandlingService {
    var handleImageViewerErrorCalled = false
    var showNotificationCalled = false
    var lastNotificationType: NotificationView.NotificationType?
    var lastNotificationMessage: String?
    
    override func handleImageViewerError(_ error: ImageViewerError) {
        handleImageViewerErrorCalled = true
    }
    
    override func showNotification(_ message: String, type: NotificationView.NotificationType) {
        showNotificationCalled = true
        lastNotificationType = type
        lastNotificationMessage = message
    }
    
    func reset() {
        handleImageViewerErrorCalled = false
        showNotificationCalled = false
        lastNotificationType = nil
        lastNotificationMessage = nil
    }
}