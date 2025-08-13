import XCTest
import Combine
import UniformTypeIdentifiers
@testable import StillView___Simple_Image_Viewer

/// Integration tests for the favorites file validation and cleanup system
final class FavoritesFileValidationIntegrationTests: XCTestCase {
    
    var favoritesService: DefaultFavoritesService!
    var mockPreferencesService: MockPreferencesService!
    var mockNotificationManager: MockNotificationManager!
    var tempDirectory: URL!
    var testImageFiles: [ImageFile] = []
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        cancellables = Set<AnyCancellable>()
        
        // Create temporary directory for test files
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FavoritesValidationTests")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Create multiple test image files
        try createTestImageFiles()
        
        // Create mock services
        mockPreferencesService = MockPreferencesService()
        mockNotificationManager = MockNotificationManager()
        
        // Create favorites service with mocks
        favoritesService = DefaultFavoritesService(
            preferencesService: mockPreferencesService,
            notificationManager: mockNotificationManager
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
    
    // MARK: - App Launch Validation Tests
    
    func testValidateFavoritesOnAppLaunch_WithValidFiles() async {
        // Given
        for imageFile in testImageFiles {
            _ = favoritesService.addToFavorites(imageFile)
        }
        XCTAssertEqual(favoritesService.favoriteImages.count, testImageFiles.count)
        
        // When
        await favoritesService.validateFavoritesOnAppLaunch()
        
        // Then
        XCTAssertEqual(favoritesService.favoriteImages.count, testImageFiles.count)
        XCTAssertEqual(mockNotificationManager.infoNotifications.count, 0) // No cleanup needed
    }
    
    func testValidateFavoritesOnAppLaunch_WithInvalidFiles() async {
        // Given
        for imageFile in testImageFiles {
            _ = favoritesService.addToFavorites(imageFile)
        }
        
        // Delete some files to make them invalid
        let filesToDelete = Array(testImageFiles.prefix(2))
        for imageFile in filesToDelete {
            try! FileManager.default.removeItem(at: imageFile.url)
        }
        
        // When
        await favoritesService.validateFavoritesOnAppLaunch()
        
        // Then
        XCTAssertEqual(favoritesService.favoriteImages.count, testImageFiles.count - 2)
        XCTAssertEqual(mockNotificationManager.infoNotifications.count, 1)
        XCTAssertTrue(mockNotificationManager.infoNotifications.first?.contains("Cleaned up 2 unavailable") == true)
    }
    
    func testValidateFavoritesOnAppLaunch_WithEmptyFavorites() async {
        // Given - no favorites
        XCTAssertEqual(favoritesService.favoriteImages.count, 0)
        
        // When
        await favoritesService.validateFavoritesOnAppLaunch()
        
        // Then
        XCTAssertEqual(favoritesService.favoriteImages.count, 0)
        XCTAssertEqual(mockNotificationManager.infoNotifications.count, 0)
    }
    
    // MARK: - Manual Refresh Validation Tests
    
    func testRefreshFavoritesValidation_WithValidFiles() async {
        // Given
        for imageFile in testImageFiles {
            _ = favoritesService.addToFavorites(imageFile)
        }
        
        // When
        await favoritesService.refreshFavoritesValidation()
        
        // Then
        XCTAssertEqual(favoritesService.favoriteImages.count, testImageFiles.count)
        XCTAssertEqual(mockNotificationManager.infoNotifications.count, 1) // "Validating favorites..."
        XCTAssertEqual(mockNotificationManager.successNotifications.count, 1) // "All favorites are valid"
    }
    
    func testRefreshFavoritesValidation_WithInvalidFiles() async {
        // Given
        for imageFile in testImageFiles {
            _ = favoritesService.addToFavorites(imageFile)
        }
        
        // Delete one file
        try! FileManager.default.removeItem(at: testImageFiles[0].url)
        
        // When
        await favoritesService.refreshFavoritesValidation()
        
        // Then
        XCTAssertEqual(favoritesService.favoriteImages.count, testImageFiles.count - 1)
        XCTAssertEqual(mockNotificationManager.infoNotifications.count, 1) // "Validating favorites..."
        XCTAssertEqual(mockNotificationManager.warningNotifications.count, 1) // Cleanup notification
        XCTAssertTrue(mockNotificationManager.warningNotifications.first?.contains("Removed 1 unavailable") == true)
    }
    
    func testRefreshFavoritesValidation_WithEmptyFavorites() async {
        // Given - no favorites
        XCTAssertEqual(favoritesService.favoriteImages.count, 0)
        
        // When
        await favoritesService.refreshFavoritesValidation()
        
        // Then
        XCTAssertEqual(mockNotificationManager.infoNotifications.count, 1)
        XCTAssertTrue(mockNotificationManager.infoNotifications.first?.contains("No favorites to validate") == true)
    }
    
    // MARK: - Batch Processing Tests
    
    func testValidateFavorites_BatchProcessing() async {
        // Given - Create many favorites to test batch processing
        var manyImageFiles: [ImageFile] = []
        for i in 0..<25 { // More than the batch size of 10
            let imageURL = tempDirectory.appendingPathComponent("batch_test_\(i).jpg")
            let imageData = createTestJPEGData()
            try! imageData.write(to: imageURL)
            let imageFile = try! ImageFile(url: imageURL)
            manyImageFiles.append(imageFile)
            _ = favoritesService.addToFavorites(imageFile)
        }
        
        // Delete some files to test cleanup
        let filesToDelete = Array(manyImageFiles.prefix(5))
        for imageFile in filesToDelete {
            try! FileManager.default.removeItem(at: imageFile.url)
        }
        
        // When
        let removedCount = await favoritesService.validateFavorites(showNotification: true)
        
        // Then
        XCTAssertEqual(removedCount, 5)
        XCTAssertEqual(favoritesService.favoriteImages.count, 20)
        XCTAssertEqual(mockNotificationManager.warningNotifications.count, 1)
        XCTAssertTrue(mockNotificationManager.warningNotifications.first?.contains("Removed 5 unavailable") == true)
    }
    
    // MARK: - Edge Case Tests
    
    func testValidateFavorites_PermissionDenied() async {
        // Given
        let imageFile = testImageFiles[0]
        _ = favoritesService.addToFavorites(imageFile)
        
        // Simulate permission denied by making file unreadable
        try! FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: imageFile.url.path)
        
        // When
        let removedCount = await favoritesService.validateFavorites(showNotification: true)
        
        // Then
        XCTAssertEqual(removedCount, 1)
        XCTAssertEqual(favoritesService.favoriteImages.count, 0)
        
        // Restore permissions for cleanup
        try! FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: imageFile.url.path)
    }
    
    func testValidateFavorites_CorruptedImageFile() async {
        // Given
        let imageFile = testImageFiles[0]
        _ = favoritesService.addToFavorites(imageFile)
        
        // Corrupt the image file by writing invalid data
        try! Data("invalid image data".utf8).write(to: imageFile.url)
        
        // When
        let removedCount = await favoritesService.validateFavorites(showNotification: true)
        
        // Then
        XCTAssertEqual(removedCount, 1)
        XCTAssertEqual(favoritesService.favoriteImages.count, 0)
    }
    
    func testValidateFavorites_NetworkDriveSimulation() async {
        // Given - This test simulates network drive behavior
        // We can't easily create actual network drives in unit tests,
        // so we test the logic with local files that we make temporarily unavailable
        
        let imageFile = testImageFiles[0]
        _ = favoritesService.addToFavorites(imageFile)
        
        // Move file to simulate network unavailability
        let hiddenURL = tempDirectory.appendingPathComponent(".hidden_\(imageFile.url.lastPathComponent)")
        try! FileManager.default.moveItem(at: imageFile.url, to: hiddenURL)
        
        // When
        let removedCount = await favoritesService.validateFavorites(showNotification: true)
        
        // Then
        XCTAssertEqual(removedCount, 1)
        XCTAssertEqual(favoritesService.favoriteImages.count, 0)
        
        // Restore file for cleanup
        try! FileManager.default.moveItem(at: hiddenURL, to: imageFile.url)
    }
    
    // MARK: - Notification Tests
    
    func testValidateFavorites_NotificationContent() async {
        // Given
        let imageFiles = Array(testImageFiles.prefix(3))
        for imageFile in imageFiles {
            _ = favoritesService.addToFavorites(imageFile)
        }
        
        // Delete files with specific names
        for imageFile in imageFiles {
            try! FileManager.default.removeItem(at: imageFile.url)
        }
        
        // When
        await favoritesService.validateFavorites(showNotification: true)
        
        // Then
        XCTAssertEqual(mockNotificationManager.warningNotifications.count, 1)
        let notification = mockNotificationManager.warningNotifications.first!
        XCTAssertTrue(notification.contains("Removed 3 unavailable"))
        
        // Check that file names are included for small counts
        for imageFile in imageFiles {
            XCTAssertTrue(notification.contains(imageFile.name))
        }
    }
    
    func testValidateFavorites_LargeCleanupNotification() async {
        // Given - Create many favorites
        var manyImageFiles: [ImageFile] = []
        for i in 0..<10 {
            let imageURL = tempDirectory.appendingPathComponent("large_cleanup_\(i).jpg")
            let imageData = createTestJPEGData()
            try! imageData.write(to: imageURL)
            let imageFile = try! ImageFile(url: imageURL)
            manyImageFiles.append(imageFile)
            _ = favoritesService.addToFavorites(imageFile)
        }
        
        // Delete all files
        for imageFile in manyImageFiles {
            try! FileManager.default.removeItem(at: imageFile.url)
        }
        
        // When
        await favoritesService.validateFavorites(showNotification: true)
        
        // Then
        XCTAssertEqual(mockNotificationManager.warningNotifications.count, 1)
        let notification = mockNotificationManager.warningNotifications.first!
        XCTAssertTrue(notification.contains("Removed 10 unavailable"))
        // For large counts, individual file names should not be included
        XCTAssertFalse(notification.contains("large_cleanup_0.jpg"))
    }
    
    // MARK: - Performance Tests
    
    func testValidateFavorites_Performance() async {
        // Given - Create many favorites
        var manyImageFiles: [ImageFile] = []
        for i in 0..<50 {
            let imageURL = tempDirectory.appendingPathComponent("perf_test_\(i).jpg")
            let imageData = createTestJPEGData()
            try! imageData.write(to: imageURL)
            let imageFile = try! ImageFile(url: imageURL)
            manyImageFiles.append(imageFile)
            _ = favoritesService.addToFavorites(imageFile)
        }
        
        // When - Measure validation performance
        let startTime = CFAbsoluteTimeGetCurrent()
        await favoritesService.validateFavorites(showNotification: false)
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then - Should complete within reasonable time (2 seconds for 50 files)
        XCTAssertLessThan(timeElapsed, 2.0, "Validation should complete within 2 seconds for 50 files")
        XCTAssertEqual(favoritesService.favoriteImages.count, 50) // All should be valid
    }
    
    // MARK: - Integration with FavoritesViewModel Tests
    
    func testFavoritesViewModel_IntegrationWithValidation() async {
        // Given
        let viewModel = FavoritesViewModel(
            favoritesService: favoritesService,
            errorHandlingService: ErrorHandlingService.shared
        )
        
        // Add some favorites
        for imageFile in testImageFiles {
            _ = favoritesService.addToFavorites(imageFile)
        }
        
        // Delete one file
        try! FileManager.default.removeItem(at: testImageFiles[0].url)
        
        // When
        viewModel.refreshFavorites()
        
        // Wait for async operations to complete
        try! await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertEqual(viewModel.favoriteImageFiles.count, testImageFiles.count - 1)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    // MARK: - Helper Methods
    
    private func createTestImageFiles() throws {
        let imageData = createTestJPEGData()
        
        for i in 0..<5 {
            let imageURL = tempDirectory.appendingPathComponent("test_image_\(i).jpg")
            try imageData.write(to: imageURL)
            let imageFile = try ImageFile(url: imageURL)
            testImageFiles.append(imageFile)
        }
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

// MARK: - Mock NotificationManager

class MockNotificationManager: NotificationManager {
    var infoNotifications: [String] = []
    var warningNotifications: [String] = []
    var errorNotifications: [String] = []
    var successNotifications: [String] = []
    
    override func showInfo(_ message: String) {
        infoNotifications.append(message)
    }
    
    override func showWarning(_ message: String) {
        warningNotifications.append(message)
    }
    
    override func showError(_ message: String) {
        errorNotifications.append(message)
    }
    
    override func showSuccess(_ message: String) {
        successNotifications.append(message)
    }
}