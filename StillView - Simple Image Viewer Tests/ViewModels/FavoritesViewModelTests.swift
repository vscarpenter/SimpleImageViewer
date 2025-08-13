import XCTest
import Combine
@testable import Simple_Image_Viewer

/// Unit tests for FavoritesViewModel
@MainActor
final class FavoritesViewModelTests: XCTestCase {
    
    // MARK: - Properties
    
    private var viewModel: FavoritesViewModel!
    private var mockFavoritesService: MockFavoritesService!
    private var mockErrorHandlingService: MockErrorHandlingService!
    private var cancellables: Set<AnyCancellable>!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        mockFavoritesService = MockFavoritesService()
        mockErrorHandlingService = MockErrorHandlingService()
        cancellables = Set<AnyCancellable>()
        
        viewModel = FavoritesViewModel(
            favoritesService: mockFavoritesService,
            errorHandlingService: mockErrorHandlingService
        )
    }
    
    override func tearDown() {
        cancellables = nil
        viewModel = nil
        mockFavoritesService = nil
        mockErrorHandlingService = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertTrue(viewModel.favoriteImageFiles.isEmpty)
        XCTAssertNil(viewModel.selectedFavoriteImage)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.currentError)
        XCTAssertFalse(viewModel.hasFavorites)
    }
    
    // MARK: - Load Favorites Tests
    
    func testLoadFavoritesSuccess() async {
        // Given
        let mockImageFiles = createMockImageFiles(count: 3)
        mockFavoritesService.mockValidFavorites = mockImageFiles
        
        // When
        viewModel.loadFavorites()
        
        // Wait for async operation to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertEqual(viewModel.favoriteImageFiles.count, 3)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.currentError)
        XCTAssertTrue(viewModel.hasFavorites)
        XCTAssertTrue(mockFavoritesService.validateFavoritesCalled)
        XCTAssertTrue(mockFavoritesService.getValidFavoritesCalled)
    }
    
    func testLoadFavoritesEmpty() async {
        // Given
        mockFavoritesService.mockValidFavorites = []
        
        // When
        viewModel.loadFavorites()
        
        // Wait for async operation to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertTrue(viewModel.favoriteImageFiles.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.currentError)
        XCTAssertFalse(viewModel.hasFavorites)
    }
    
    func testLoadFavoritesError() async {
        // Given
        mockFavoritesService.shouldThrowError = true
        
        // When
        viewModel.loadFavorites()
        
        // Wait for async operation to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertTrue(viewModel.favoriteImageFiles.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.currentError)
        XCTAssertFalse(viewModel.hasFavorites)
        XCTAssertTrue(mockErrorHandlingService.handleImageViewerErrorCalled)
    }
    
    // MARK: - Selection Tests
    
    func testSelectFavorite() {
        // Given
        let mockImageFiles = createMockImageFiles(count: 2)
        let imageToSelect = mockImageFiles[1]
        
        // When
        viewModel.selectFavorite(imageToSelect)
        
        // Then
        XCTAssertEqual(viewModel.selectedFavoriteImage?.url, imageToSelect.url)
    }
    
    // MARK: - Remove from Favorites Tests
    
    func testRemoveFromFavoritesSuccess() {
        // Given
        let mockImageFiles = createMockImageFiles(count: 3)
        viewModel.favoriteImageFiles = mockImageFiles
        let imageToRemove = mockImageFiles[1]
        mockFavoritesService.mockRemoveSuccess = true
        
        // When
        viewModel.removeFromFavorites(imageToRemove)
        
        // Then
        XCTAssertEqual(viewModel.favoriteImageFiles.count, 2)
        XCTAssertFalse(viewModel.favoriteImageFiles.contains { $0.url == imageToRemove.url })
        XCTAssertTrue(mockFavoritesService.removeFromFavoritesCalled)
        XCTAssertTrue(mockErrorHandlingService.showNotificationCalled)
        XCTAssertEqual(mockErrorHandlingService.lastNotificationType, .success)
    }
    
    func testRemoveFromFavoritesFailure() {
        // Given
        let mockImageFiles = createMockImageFiles(count: 3)
        viewModel.favoriteImageFiles = mockImageFiles
        let imageToRemove = mockImageFiles[1]
        mockFavoritesService.mockRemoveSuccess = false
        
        // When
        viewModel.removeFromFavorites(imageToRemove)
        
        // Then
        XCTAssertEqual(viewModel.favoriteImageFiles.count, 3) // No change
        XCTAssertTrue(mockFavoritesService.removeFromFavoritesCalled)
        XCTAssertTrue(mockErrorHandlingService.showNotificationCalled)
        XCTAssertEqual(mockErrorHandlingService.lastNotificationType, .error)
    }
    
    func testRemoveSelectedFavorite() {
        // Given
        let mockImageFiles = createMockImageFiles(count: 2)
        viewModel.favoriteImageFiles = mockImageFiles
        let imageToRemove = mockImageFiles[0]
        viewModel.selectedFavoriteImage = imageToRemove
        mockFavoritesService.mockRemoveSuccess = true
        
        // When
        viewModel.removeFromFavorites(imageToRemove)
        
        // Then
        XCTAssertNil(viewModel.selectedFavoriteImage)
        XCTAssertEqual(viewModel.favoriteImageFiles.count, 1)
    }
    
    // MARK: - Refresh Tests
    
    func testRefreshFavorites() async {
        // Given
        let mockImageFiles = createMockImageFiles(count: 2)
        mockFavoritesService.mockValidFavorites = mockImageFiles
        
        // When
        viewModel.refreshFavorites()
        
        // Wait for async operation to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertEqual(viewModel.favoriteImageFiles.count, 2)
        XCTAssertTrue(mockFavoritesService.validateFavoritesCalled)
        XCTAssertTrue(mockFavoritesService.getValidFavoritesCalled)
    }
    
    // MARK: - Create Favorites Content Tests
    
    func testCreateFavoritesContentWithFavorites() {
        // Given
        let mockImageFiles = createMockImageFiles(count: 2)
        viewModel.favoriteImageFiles = mockImageFiles
        
        // When
        let favoritesContent = viewModel.createFavoritesContent()
        
        // Then
        XCTAssertNotNil(favoritesContent)
        XCTAssertEqual(favoritesContent?.imageFiles.count, 2)
        XCTAssertEqual(favoritesContent?.folderURL.absoluteString, "favorites://")
    }
    
    func testCreateFavoritesContentEmpty() {
        // Given
        viewModel.favoriteImageFiles = []
        
        // When
        let favoritesContent = viewModel.createFavoritesContent()
        
        // Then
        XCTAssertNil(favoritesContent)
    }
    
    // MARK: - Error Handling Tests
    
    func testClearError() {
        // Given
        viewModel.currentError = .noImagesFound
        
        // When
        viewModel.clearError()
        
        // Then
        XCTAssertNil(viewModel.currentError)
    }
    
    // MARK: - Batch Removal Tests
    
    func testBatchRemoveFromFavoritesSuccess() {
        // Given
        let mockImageFiles = createMockImageFiles(count: 5)
        viewModel.favoriteImageFiles = mockImageFiles
        let imagesToRemove = Array(mockImageFiles[1...3]) // Remove 3 images
        mockFavoritesService.mockBatchRemoveCount = 3
        
        // When
        let removedCount = viewModel.batchRemoveFromFavorites(imagesToRemove)
        
        // Then
        XCTAssertEqual(removedCount, 3)
        XCTAssertEqual(viewModel.favoriteImageFiles.count, 2)
        XCTAssertTrue(mockFavoritesService.batchRemoveFromFavoritesCalled)
        XCTAssertTrue(mockErrorHandlingService.showNotificationCalled)
        XCTAssertEqual(mockErrorHandlingService.lastNotificationType, .success)
    }
    
    func testBatchRemoveFromFavoritesPartialSuccess() {
        // Given
        let mockImageFiles = createMockImageFiles(count: 4)
        viewModel.favoriteImageFiles = mockImageFiles
        let imagesToRemove = Array(mockImageFiles[1...2]) // Try to remove 2 images
        mockFavoritesService.mockBatchRemoveCount = 1 // Only 1 succeeds
        
        // When
        let removedCount = viewModel.batchRemoveFromFavorites(imagesToRemove)
        
        // Then
        XCTAssertEqual(removedCount, 1)
        XCTAssertTrue(mockFavoritesService.batchRemoveFromFavoritesCalled)
        XCTAssertTrue(mockErrorHandlingService.showNotificationCalled)
        XCTAssertEqual(mockErrorHandlingService.lastNotificationType, .warning)
    }
    
    func testBatchRemoveFromFavoritesAllFailed() {
        // Given
        let mockImageFiles = createMockImageFiles(count: 3)
        viewModel.favoriteImageFiles = mockImageFiles
        let imagesToRemove = Array(mockImageFiles[0...1]) // Try to remove 2 images
        mockFavoritesService.mockBatchRemoveCount = 0 // All fail
        
        // When
        let removedCount = viewModel.batchRemoveFromFavorites(imagesToRemove)
        
        // Then
        XCTAssertEqual(removedCount, 0)
        XCTAssertEqual(viewModel.favoriteImageFiles.count, 3) // No change
        XCTAssertTrue(mockFavoritesService.batchRemoveFromFavoritesCalled)
        XCTAssertTrue(mockErrorHandlingService.showNotificationCalled)
        XCTAssertEqual(mockErrorHandlingService.lastNotificationType, .error)
    }
    
    func testBatchRemoveEmptyArray() {
        // Given
        let mockImageFiles = createMockImageFiles(count: 2)
        viewModel.favoriteImageFiles = mockImageFiles
        let imagesToRemove: [ImageFile] = []
        
        // When
        let removedCount = viewModel.batchRemoveFromFavorites(imagesToRemove)
        
        // Then
        XCTAssertEqual(removedCount, 0)
        XCTAssertEqual(viewModel.favoriteImageFiles.count, 2) // No change
        XCTAssertTrue(mockErrorHandlingService.showNotificationCalled)
        XCTAssertEqual(mockErrorHandlingService.lastNotificationType, .success)
    }
    
    // MARK: - Last Favorite Removal Tests
    
    func testRemoveLastFavorite() {
        // Given
        let mockImageFiles = createMockImageFiles(count: 1)
        viewModel.favoriteImageFiles = mockImageFiles
        let lastImage = mockImageFiles[0]
        viewModel.selectedFavoriteImage = lastImage
        mockFavoritesService.mockRemoveSuccess = true
        
        // When
        viewModel.removeFromFavorites(lastImage)
        
        // Then
        XCTAssertTrue(viewModel.favoriteImageFiles.isEmpty)
        XCTAssertNil(viewModel.selectedFavoriteImage)
        XCTAssertFalse(viewModel.hasFavorites)
        XCTAssertTrue(mockFavoritesService.removeFromFavoritesCalled)
        XCTAssertTrue(mockErrorHandlingService.showNotificationCalled)
        XCTAssertEqual(mockErrorHandlingService.lastNotificationType, .success)
    }
    
    func testBatchRemoveAllFavorites() {
        // Given
        let mockImageFiles = createMockImageFiles(count: 3)
        viewModel.favoriteImageFiles = mockImageFiles
        viewModel.selectedFavoriteImage = mockImageFiles[1]
        mockFavoritesService.mockBatchRemoveCount = 3
        
        // When
        let removedCount = viewModel.batchRemoveFromFavorites(mockImageFiles)
        
        // Then
        XCTAssertEqual(removedCount, 3)
        XCTAssertTrue(viewModel.favoriteImageFiles.isEmpty)
        XCTAssertNil(viewModel.selectedFavoriteImage)
        XCTAssertFalse(viewModel.hasFavorites)
        XCTAssertTrue(mockFavoritesService.batchRemoveFromFavoritesCalled)
    }
    
    // MARK: - UI State Management Tests
    
    func testSelectionClearedAfterRemoval() {
        // Given
        let mockImageFiles = createMockImageFiles(count: 3)
        viewModel.favoriteImageFiles = mockImageFiles
        let selectedImage = mockImageFiles[1]
        viewModel.selectedFavoriteImage = selectedImage
        mockFavoritesService.mockRemoveSuccess = true
        
        // When
        viewModel.removeFromFavorites(selectedImage)
        
        // Then
        XCTAssertNil(viewModel.selectedFavoriteImage)
        XCTAssertEqual(viewModel.favoriteImageFiles.count, 2)
        XCTAssertFalse(viewModel.favoriteImageFiles.contains { $0.url == selectedImage.url })
    }
    
    func testSelectionPreservedAfterRemovalOfDifferentImage() {
        // Given
        let mockImageFiles = createMockImageFiles(count: 3)
        viewModel.favoriteImageFiles = mockImageFiles
        let selectedImage = mockImageFiles[0]
        let imageToRemove = mockImageFiles[2]
        viewModel.selectedFavoriteImage = selectedImage
        mockFavoritesService.mockRemoveSuccess = true
        
        // When
        viewModel.removeFromFavorites(imageToRemove)
        
        // Then
        XCTAssertEqual(viewModel.selectedFavoriteImage?.url, selectedImage.url)
        XCTAssertEqual(viewModel.favoriteImageFiles.count, 2)
        XCTAssertFalse(viewModel.favoriteImageFiles.contains { $0.url == imageToRemove.url })
    }
    
    // MARK: - Remove All Favorites Tests
    
    func testRemoveAllFavoritesSuccess() {
        // Given
        let mockImageFiles = createMockImageFiles(count: 3)
        viewModel.favoriteImageFiles = mockImageFiles
        viewModel.selectedFavoriteImage = mockImageFiles[1]
        mockFavoritesService.mockBatchRemoveCount = 3
        
        // When
        let removedCount = viewModel.removeAllFavorites()
        
        // Then
        XCTAssertEqual(removedCount, 3)
        XCTAssertTrue(viewModel.favoriteImageFiles.isEmpty)
        XCTAssertNil(viewModel.selectedFavoriteImage)
        XCTAssertFalse(viewModel.hasFavorites)
        XCTAssertTrue(mockFavoritesService.batchRemoveFromFavoritesCalled)
        XCTAssertTrue(mockErrorHandlingService.showNotificationCalled)
        XCTAssertEqual(mockErrorHandlingService.lastNotificationType, .success)
    }
    
    func testRemoveAllFavoritesEmpty() {
        // Given
        viewModel.favoriteImageFiles = []
        
        // When
        let removedCount = viewModel.removeAllFavorites()
        
        // Then
        XCTAssertEqual(removedCount, 0)
        XCTAssertTrue(viewModel.favoriteImageFiles.isEmpty)
        XCTAssertFalse(mockFavoritesService.batchRemoveFromFavoritesCalled)
        XCTAssertTrue(mockErrorHandlingService.showNotificationCalled)
        XCTAssertEqual(mockErrorHandlingService.lastNotificationType, .info)
    }
    
    // MARK: - Enhanced Batch Removal Tests
    
    func testBatchRemoveFromFavoritesEmptyInput() {
        // Given
        let mockImageFiles = createMockImageFiles(count: 2)
        viewModel.favoriteImageFiles = mockImageFiles
        let imagesToRemove: [ImageFile] = []
        
        // When
        let removedCount = viewModel.batchRemoveFromFavorites(imagesToRemove)
        
        // Then
        XCTAssertEqual(removedCount, 0)
        XCTAssertEqual(viewModel.favoriteImageFiles.count, 2) // No change
        XCTAssertFalse(mockFavoritesService.batchRemoveFromFavoritesCalled)
        XCTAssertTrue(mockErrorHandlingService.showNotificationCalled)
        XCTAssertEqual(mockErrorHandlingService.lastNotificationType, .info)
    }
    
    func testBatchRemoveFromFavoritesWithDetailedFailureMessage() {
        // Given
        let mockImageFiles = createMockImageFiles(count: 5)
        viewModel.favoriteImageFiles = mockImageFiles
        let imagesToRemove = Array(mockImageFiles[1...3]) // Try to remove 3 images
        mockFavoritesService.mockBatchRemoveCount = 2 // Only 2 succeed
        
        // When
        let removedCount = viewModel.batchRemoveFromFavorites(imagesToRemove)
        
        // Then
        XCTAssertEqual(removedCount, 2)
        XCTAssertTrue(mockFavoritesService.batchRemoveFromFavoritesCalled)
        XCTAssertTrue(mockErrorHandlingService.showNotificationCalled)
        XCTAssertEqual(mockErrorHandlingService.lastNotificationType, .warning)
        
        // Check that the notification message includes failure count
        let lastNotification = mockErrorHandlingService.lastNotificationMessage
        XCTAssertTrue(lastNotification?.contains("2 of 3") == true)
        XCTAssertTrue(lastNotification?.contains("1 failed") == true)
    }
    
    // MARK: - UI State Management Edge Cases
    
    func testBatchRemovalClearsSelectionWhenSelectedImageRemoved() {
        // Given
        let mockImageFiles = createMockImageFiles(count: 4)
        viewModel.favoriteImageFiles = mockImageFiles
        let selectedImage = mockImageFiles[2]
        viewModel.selectedFavoriteImage = selectedImage
        
        let imagesToRemove = [mockImageFiles[1], selectedImage, mockImageFiles[3]]
        mockFavoritesService.mockBatchRemoveCount = 3
        
        // When
        let removedCount = viewModel.batchRemoveFromFavorites(imagesToRemove)
        
        // Then
        XCTAssertEqual(removedCount, 3)
        XCTAssertNil(viewModel.selectedFavoriteImage) // Should be cleared
        XCTAssertEqual(viewModel.favoriteImageFiles.count, 1)
    }
    
    func testBatchRemovalPreservesSelectionWhenSelectedImageNotRemoved() {
        // Given
        let mockImageFiles = createMockImageFiles(count: 4)
        viewModel.favoriteImageFiles = mockImageFiles
        let selectedImage = mockImageFiles[0] // This won't be removed
        viewModel.selectedFavoriteImage = selectedImage
        
        let imagesToRemove = [mockImageFiles[1], mockImageFiles[2]]
        mockFavoritesService.mockBatchRemoveCount = 2
        
        // When
        let removedCount = viewModel.batchRemoveFromFavorites(imagesToRemove)
        
        // Then
        XCTAssertEqual(removedCount, 2)
        XCTAssertEqual(viewModel.selectedFavoriteImage?.url, selectedImage.url) // Should be preserved
        XCTAssertEqual(viewModel.favoriteImageFiles.count, 2)
    }
    
    // MARK: - Reactive Updates Tests
    
    func testFavoritesServiceUpdatesViewModel() async {
        // Given
        let expectation = XCTestExpectation(description: "ViewModel should reload when favorites service changes")
        
        viewModel.$favoriteImageFiles
            .dropFirst() // Skip initial empty value
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        mockFavoritesService.triggerFavoritesChange()
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Helper Methods
    
    private func createMockImageFiles(count: Int) -> [ImageFile] {
        var imageFiles: [ImageFile] = []
        
        for index in 0..<count {
            // Create temporary file for testing
            let tempDirectory = FileManager.default.temporaryDirectory
            let testImageURL = tempDirectory.appendingPathComponent("test\(index).jpg")
            
            // Create minimal JPEG data
            let testData = Data([0xFF, 0xD8, 0xFF, 0xE0]) // JPEG header
            try? testData.write(to: testImageURL)
            
            if let imageFile = try? ImageFile(url: testImageURL) {
                imageFiles.append(imageFile)
            }
        }
        
        return imageFiles
    }
}

// MARK: - Mock Services

private class MockFavoritesService: FavoritesService {
    @Published private(set) var favoriteImages: [FavoriteImageFile] = []
    
    var favoriteImagesPublisher: Published<[FavoriteImageFile]>.Publisher {
        $favoriteImages
    }
    
    var mockValidFavorites: [ImageFile] = []
    var shouldThrowError = false
    var mockRemoveSuccess = true
    var mockBatchRemoveCount = 0
    
    var validateFavoritesCalled = false
    var getValidFavoritesCalled = false
    var removeFromFavoritesCalled = false
    var batchRemoveFromFavoritesCalled = false
    
    func addToFavorites(_ imageFile: ImageFile) -> Bool {
        return true
    }
    
    func removeFromFavorites(_ imageFile: ImageFile) -> Bool {
        removeFromFavoritesCalled = true
        return mockRemoveSuccess
    }
    
    func isFavorite(_ imageFile: ImageFile) -> Bool {
        return false
    }
    
    func validateFavorites(showNotification: Bool = false) async -> Int {
        validateFavoritesCalled = true
        if shouldThrowError {
            throw NSError(domain: "TestError", code: 1, userInfo: nil)
        }
        return 0
    }
    
    func validateFavoritesOnAppLaunch() async {
        // Mock implementation
    }
    
    func refreshFavoritesValidation() async {
        // Mock implementation
    }
    
    func getValidFavorites() async -> [ImageFile] {
        getValidFavoritesCalled = true
        if shouldThrowError {
            throw NSError(domain: "TestError", code: 1, userInfo: nil)
        }
        return mockValidFavorites
    }
    
    func batchRemoveFromFavorites(_ imageFiles: [ImageFile]) -> Int {
        batchRemoveFromFavoritesCalled = true
        return mockBatchRemoveCount
    }
    
    func clearAllFavorites() {
        favoriteImages.removeAll()
    }
    
    func triggerFavoritesChange() {
        favoriteImages = []
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
}