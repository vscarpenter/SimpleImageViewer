import XCTest
import Combine
import AppKit
@testable import Simple_Image_Viewer

class ImageViewerViewModelTests: XCTestCase {
    var viewModel: ImageViewerViewModel!
    var mockImageLoaderService: MockImageLoaderService!
    var mockPreferencesService: MockPreferencesService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockImageLoaderService = MockImageLoaderService()
        mockPreferencesService = MockPreferencesService()
        viewModel = ImageViewerViewModel(
            imageLoaderService: mockImageLoaderService,
            preferencesService: mockPreferencesService
        )
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        // Clean up temporary files
        cleanupTemporaryFiles()
        
        cancellables = nil
        viewModel = nil
        mockImageLoaderService = nil
        mockPreferencesService = nil
        super.tearDown()
    }
    
    private func cleanupTemporaryFiles() {
        let tempDir = FileManager.default.temporaryDirectory
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            for url in contents {
                if url.lastPathComponent.hasPrefix("test_image_") {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        } catch {
            // Ignore cleanup errors
        }
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNil(viewModel.currentImage)
        XCTAssertEqual(viewModel.currentIndex, 0)
        XCTAssertEqual(viewModel.totalImages, 0)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.zoomLevel, 1.0)
        XCTAssertFalse(viewModel.isFullscreen)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.showFileName, mockPreferencesService.showFileName)
    }
    
    // MARK: - Folder Content Loading Tests
    
    func testLoadFolderContentWithImages() throws {
        // Given
        let imageFiles = try createMockImageFiles(count: 3)
        let folderContent = FolderContent(
            folderURL: URL(fileURLWithPath: "/test/folder"),
            imageFiles: imageFiles,
            currentIndex: 1
        )
        
        // When
        viewModel.loadFolderContent(folderContent)
        
        // Then
        XCTAssertEqual(viewModel.totalImages, 3)
        XCTAssertEqual(viewModel.currentIndex, 1)
        XCTAssertTrue(viewModel.isLoading)
        XCTAssertEqual(mockImageLoaderService.loadImageCallCount, 1)
    }
    
    func testLoadFolderContentWithNoImages() {
        // Given
        let folderContent = FolderContent(
            folderURL: URL(fileURLWithPath: "/test/folder"),
            imageFiles: [],
            currentIndex: 0
        )
        
        // When
        viewModel.loadFolderContent(folderContent)
        
        // Then
        XCTAssertEqual(viewModel.totalImages, 0)
        XCTAssertEqual(viewModel.currentIndex, 0)
        XCTAssertNil(viewModel.currentImage)
        XCTAssertEqual(viewModel.errorMessage, "No images found in the selected folder")
    }
    
    // MARK: - Navigation Tests
    
    func testNextImage() throws {
        // Given
        let imageFiles = try createMockImageFiles(count: 3)
        let folderContent = FolderContent(
            folderURL: URL(fileURLWithPath: "/test/folder"),
            imageFiles: imageFiles,
            currentIndex: 0
        )
        viewModel.loadFolderContent(folderContent)
        
        // When
        viewModel.nextImage()
        
        // Then
        XCTAssertEqual(viewModel.currentIndex, 1)
        XCTAssertEqual(mockImageLoaderService.loadImageCallCount, 2) // Initial + next
    }
    
    func testNextImageAtEnd() throws {
        // Given
        let imageFiles = try createMockImageFiles(count: 3)
        let folderContent = FolderContent(
            folderURL: URL(fileURLWithPath: "/test/folder"),
            imageFiles: imageFiles,
            currentIndex: 2
        )
        viewModel.loadFolderContent(folderContent)
        
        // When
        viewModel.nextImage()
        
        // Then
        XCTAssertEqual(viewModel.currentIndex, 2) // Should not change
    }
    
    func testPreviousImage() throws {
        // Given
        let imageFiles = try createMockImageFiles(count: 3)
        let folderContent = FolderContent(
            folderURL: URL(fileURLWithPath: "/test/folder"),
            imageFiles: imageFiles,
            currentIndex: 1
        )
        viewModel.loadFolderContent(folderContent)
        
        // When
        viewModel.previousImage()
        
        // Then
        XCTAssertEqual(viewModel.currentIndex, 0)
        XCTAssertEqual(mockImageLoaderService.loadImageCallCount, 2) // Initial + previous
    }
    
    func testPreviousImageAtBeginning() throws {
        // Given
        let imageFiles = try createMockImageFiles(count: 3)
        let folderContent = FolderContent(
            folderURL: URL(fileURLWithPath: "/test/folder"),
            imageFiles: imageFiles,
            currentIndex: 0
        )
        viewModel.loadFolderContent(folderContent)
        
        // When
        viewModel.previousImage()
        
        // Then
        XCTAssertEqual(viewModel.currentIndex, 0) // Should not change
    }
    
    func testGoToFirst() throws {
        // Given
        let imageFiles = try createMockImageFiles(count: 3)
        let folderContent = FolderContent(
            folderURL: URL(fileURLWithPath: "/test/folder"),
            imageFiles: imageFiles,
            currentIndex: 2
        )
        viewModel.loadFolderContent(folderContent)
        
        // When
        viewModel.goToFirst()
        
        // Then
        XCTAssertEqual(viewModel.currentIndex, 0)
    }
    
    func testGoToLast() throws {
        // Given
        let imageFiles = try createMockImageFiles(count: 3)
        let folderContent = FolderContent(
            folderURL: URL(fileURLWithPath: "/test/folder"),
            imageFiles: imageFiles,
            currentIndex: 0
        )
        viewModel.loadFolderContent(folderContent)
        
        // When
        viewModel.goToLast()
        
        // Then
        XCTAssertEqual(viewModel.currentIndex, 2)
    }
    
    func testNavigateToIndex() throws {
        // Given
        let imageFiles = try createMockImageFiles(count: 5)
        let folderContent = FolderContent(
            folderURL: URL(fileURLWithPath: "/test/folder"),
            imageFiles: imageFiles,
            currentIndex: 0
        )
        viewModel.loadFolderContent(folderContent)
        
        // When
        viewModel.navigateToIndex(3)
        
        // Then
        XCTAssertEqual(viewModel.currentIndex, 3)
        XCTAssertEqual(mockImageLoaderService.preloadImagesCallCount, 2) // Initial + navigate
    }
    
    func testNavigateToInvalidIndex() throws {
        // Given
        let imageFiles = try createMockImageFiles(count: 3)
        let folderContent = FolderContent(
            folderURL: URL(fileURLWithPath: "/test/folder"),
            imageFiles: imageFiles,
            currentIndex: 1
        )
        viewModel.loadFolderContent(folderContent)
        let originalIndex = viewModel.currentIndex
        
        // When
        viewModel.navigateToIndex(-1)
        
        // Then
        XCTAssertEqual(viewModel.currentIndex, originalIndex) // Should not change
        
        // When
        viewModel.navigateToIndex(10)
        
        // Then
        XCTAssertEqual(viewModel.currentIndex, originalIndex) // Should not change
    }
    
    // MARK: - Zoom Tests
    
    func testSetZoom() {
        // When
        viewModel.setZoom(2.0)
        
        // Then
        XCTAssertEqual(viewModel.zoomLevel, 2.0)
    }
    
    func testZoomIn() {
        // Given
        viewModel.setZoom(1.0)
        
        // When
        viewModel.zoomIn()
        
        // Then
        XCTAssertEqual(viewModel.zoomLevel, 1.25)
    }
    
    func testZoomInFromFitToWindow() {
        // Given
        viewModel.zoomToFit()
        
        // When
        viewModel.zoomIn()
        
        // Then
        XCTAssertEqual(viewModel.zoomLevel, 1.0)
    }
    
    func testZoomOut() {
        // Given
        viewModel.setZoom(1.0)
        
        // When
        viewModel.zoomOut()
        
        // Then
        XCTAssertEqual(viewModel.zoomLevel, 0.75)
    }
    
    func testZoomOutToFitToWindow() {
        // Given
        viewModel.setZoom(0.1)
        
        // When
        viewModel.zoomOut()
        
        // Then
        XCTAssertEqual(viewModel.zoomLevel, -1.0) // Fit to window
    }
    
    func testZoomToFit() {
        // Given
        viewModel.setZoom(2.0)
        
        // When
        viewModel.zoomToFit()
        
        // Then
        XCTAssertEqual(viewModel.zoomLevel, -1.0)
        XCTAssertTrue(viewModel.isZoomFitToWindow)
    }
    
    func testZoomToActualSize() {
        // Given
        viewModel.setZoom(2.0)
        
        // When
        viewModel.zoomToActualSize()
        
        // Then
        XCTAssertEqual(viewModel.zoomLevel, 1.0)
        XCTAssertFalse(viewModel.isZoomFitToWindow)
    }
    
    func testZoomPercentageText() {
        // Test normal zoom
        viewModel.setZoom(1.5)
        XCTAssertEqual(viewModel.zoomPercentageText, "150%")
        
        // Test fit to window
        viewModel.zoomToFit()
        XCTAssertEqual(viewModel.zoomPercentageText, "Fit")
    }
    
    // MARK: - Fullscreen Tests
    
    func testToggleFullscreen() {
        // Given
        XCTAssertFalse(viewModel.isFullscreen)
        
        // When
        viewModel.toggleFullscreen()
        
        // Then
        XCTAssertTrue(viewModel.isFullscreen)
        
        // When
        viewModel.toggleFullscreen()
        
        // Then
        XCTAssertFalse(viewModel.isFullscreen)
    }
    
    func testEnterFullscreen() {
        // When
        viewModel.enterFullscreen()
        
        // Then
        XCTAssertTrue(viewModel.isFullscreen)
    }
    
    func testExitFullscreen() {
        // Given
        viewModel.enterFullscreen()
        
        // When
        viewModel.exitFullscreen()
        
        // Then
        XCTAssertFalse(viewModel.isFullscreen)
    }
    
    // MARK: - File Name Display Tests
    
    func testToggleFileNameDisplay() {
        // Given
        let initialValue = viewModel.showFileName
        
        // When
        viewModel.toggleFileNameDisplay()
        
        // Then
        XCTAssertEqual(viewModel.showFileName, !initialValue)
        XCTAssertEqual(mockPreferencesService.showFileName, !initialValue)
        XCTAssertTrue(mockPreferencesService.savePreferencesCalled)
    }
    
    // MARK: - Error Handling Tests
    
    func testClearError() {
        // Given
        viewModel.errorMessage = "Test error"
        
        // When
        viewModel.clearError()
        
        // Then
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testImageLoadingError() throws {
        // Given
        let imageFiles = try createMockImageFiles(count: 1)
        let folderContent = FolderContent(
            folderURL: URL(fileURLWithPath: "/test/folder"),
            imageFiles: imageFiles,
            currentIndex: 0
        )
        mockImageLoaderService.shouldFailLoading = true
        mockImageLoaderService.errorToReturn = ImageLoaderError.corruptedImage
        
        // When
        viewModel.loadFolderContent(folderContent)
        
        // Wait for async completion
        let expectation = XCTestExpectation(description: "Image loading error")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage?.contains("Corrupted image file") == true)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    // MARK: - Loading State Tests
    
    func testCancelLoading() throws {
        // Given
        let imageFiles = try createMockImageFiles(count: 1)
        let folderContent = FolderContent(
            folderURL: URL(fileURLWithPath: "/test/folder"),
            imageFiles: imageFiles,
            currentIndex: 0
        )
        viewModel.loadFolderContent(folderContent)
        
        // When
        viewModel.cancelLoading()
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.loadingProgress, 0.0)
        XCTAssertEqual(mockImageLoaderService.cancelLoadingCallCount, 1)
    }
    
    // MARK: - Computed Properties Tests
    
    func testHasNext() throws {
        // Given
        let imageFiles = try createMockImageFiles(count: 3)
        let folderContent = FolderContent(
            folderURL: URL(fileURLWithPath: "/test/folder"),
            imageFiles: imageFiles,
            currentIndex: 1
        )
        viewModel.loadFolderContent(folderContent)
        
        // Then
        XCTAssertTrue(viewModel.hasNext)
        
        // When at last image
        viewModel.navigateToIndex(2)
        
        // Then
        XCTAssertFalse(viewModel.hasNext)
    }
    
    func testHasPrevious() throws {
        // Given
        let imageFiles = try createMockImageFiles(count: 3)
        let folderContent = FolderContent(
            folderURL: URL(fileURLWithPath: "/test/folder"),
            imageFiles: imageFiles,
            currentIndex: 1
        )
        viewModel.loadFolderContent(folderContent)
        
        // Then
        XCTAssertTrue(viewModel.hasPrevious)
        
        // When at first image
        viewModel.navigateToIndex(0)
        
        // Then
        XCTAssertFalse(viewModel.hasPrevious)
    }
    
    func testImageCounterText() throws {
        // Given no images
        XCTAssertEqual(viewModel.imageCounterText, "No images")
        
        // Given with images
        let imageFiles = try createMockImageFiles(count: 5)
        let folderContent = FolderContent(
            folderURL: URL(fileURLWithPath: "/test/folder"),
            imageFiles: imageFiles,
            currentIndex: 2
        )
        viewModel.loadFolderContent(folderContent)
        
        // Then
        XCTAssertEqual(viewModel.imageCounterText, "3 of 5")
    }
    
    func testCurrentFileName() throws {
        // Given
        let imageFiles = try createMockImageFiles(count: 1)
        let folderContent = FolderContent(
            folderURL: URL(fileURLWithPath: "/test/folder"),
            imageFiles: imageFiles,
            currentIndex: 0
        )
        viewModel.loadFolderContent(folderContent)
        
        // Then
        XCTAssertEqual(viewModel.currentFileName, "test_image_0")
    }
    
    func testAIAnalysisPreferenceUpdatesViaNotification() {
        mockPreferencesService.enableAIAnalysis = false
        let viewModel = ImageViewerViewModel(
            imageLoaderService: mockImageLoaderService,
            preferencesService: mockPreferencesService,
            errorHandlingService: mockErrorHandlingService
        )
        XCTAssertFalse(viewModel.isAIAnalysisEnabled)
        
        mockPreferencesService.enableAIAnalysis = true
        NotificationCenter.default.post(name: .aiAnalysisPreferenceDidChange, object: true)
        
        XCTAssertTrue(viewModel.isAIAnalysisEnabled)
    }
    
    // Removed feature tests
    
    // MARK: - Helper Methods
    
    private func createMockImageFiles(count: Int) throws -> [ImageFile] {
        var imageFiles: [ImageFile] = []
        
        for i in 0..<count {
            // Create a temporary file for testing
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "test_image_\(i).jpg"
            let fileURL = tempDir.appendingPathComponent(fileName)
            
            // Create a minimal JPEG file for testing
            let jpegData = Data([0xFF, 0xD8, 0xFF, 0xE0]) // Minimal JPEG header
            try jpegData.write(to: fileURL)
            
            // Set the content type manually
            try fileURL.setResourceValue(UTType.jpeg, forKey: .contentTypeKey)
            
            let imageFile = try ImageFile(url: fileURL)
            imageFiles.append(imageFile)
        }
        
        return imageFiles
    }
}

// MARK: - Mock Classes

class MockImageLoaderService: ImageLoaderService {
    var loadImageCallCount = 0
    var preloadImageCallCount = 0
    var preloadImagesCallCount = 0
    var cancelLoadingCallCount = 0
    var clearCacheCallCount = 0
    
    var shouldFailLoading = false
    var errorToReturn: Error = ImageLoaderError.corruptedImage
    
    func loadImage(from url: URL) -> AnyPublisher<NSImage, Error> {
        loadImageCallCount += 1
        
        if shouldFailLoading {
            return Fail(error: errorToReturn)
                .eraseToAnyPublisher()
        } else {
            let image = NSImage(size: NSSize(width: 100, height: 100))
            return Just(image)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
    }
    
    func preloadImage(from url: URL) {
        preloadImageCallCount += 1
    }
    
    func cancelLoading(for url: URL) {
        cancelLoadingCallCount += 1
    }
    
    func clearCache() {
        clearCacheCallCount += 1
    }
    
    func preloadImages(_ urls: [URL], maxCount: Int) {
        preloadImagesCallCount += 1
    }
}

class MockPreferencesService: PreferencesService {
    var recentFolders: [URL] = []
    var windowFrame: CGRect = CGRect(x: 0, y: 0, width: 800, height: 600)
    var showFileName: Bool = false
    var showImageInfo: Bool = false
    var slideshowInterval: Double = 3.0
    var lastSelectedFolder: URL?
    var folderBookmarks: [Data] = []
    var windowState: WindowState?
    var defaultThumbnailGridSize: ThumbnailGridSize = .medium
    var useResponsiveGridLayout: Bool = true
    var enableAIAnalysis: Bool = true
    // Favorites removed
    
    var savePreferencesCalled = false
    var loadPreferencesCalled = false
    
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
        loadPreferencesCalled = true
    }
    
    func saveWindowState(_ windowState: WindowState) {
        self.windowState = windowState
    }
    
    func loadWindowState() -> WindowState? {
        return windowState
    }
    
    // Favorites removed
}


class MockErrorHandlingService: ErrorHandlingService {
    var showNotificationCalled = false
    var showModalErrorCalled = false
    var showPermissionRequestCalled = false
    
    var lastNotificationMessage: String?
    var lastNotificationType: NotificationView.NotificationType?
    var lastModalError: Error?
    var lastPermissionRequest: PermissionRequestInfo?
    
    override func showNotification(_ message: String, type: NotificationView.NotificationType) {
        showNotificationCalled = true
        lastNotificationMessage = message
        lastNotificationType = type
    }
    
    override func showModalError(_ error: Error, title: String? = nil, actions: [ModalErrorAction] = []) {
        showModalErrorCalled = true
        lastModalError = error
    }
    
    override func showPermissionRequest(_ request: PermissionRequestInfo) {
        showPermissionRequestCalled = true
        lastPermissionRequest = request
    }
}
