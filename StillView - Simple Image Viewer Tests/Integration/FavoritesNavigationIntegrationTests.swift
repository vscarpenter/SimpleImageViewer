import XCTest
import SwiftUI
import AppKit
@testable import StillView___Simple_Image_Viewer

/// Integration tests for favorites navigation and full-screen support
@MainActor
final class FavoritesNavigationIntegrationTests: XCTestCase {
    
    // MARK: - Properties
    
    private var favoritesService: MockFavoritesService!
    private var preferencesService: MockPreferencesService!
    private var errorHandlingService: MockErrorHandlingService!
    private var favoritesViewModel: FavoritesViewModel!
    private var imageViewerViewModel: ImageViewerViewModel!
    private var testImageFiles: [ImageFile]!
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create test image files
        testImageFiles = try createTestImageFiles()
        
        // Create mock services
        preferencesService = MockPreferencesService()
        favoritesService = MockFavoritesService(preferencesService: preferencesService)
        errorHandlingService = MockErrorHandlingService()
        
        // Add test images to favorites
        for imageFile in testImageFiles {
            _ = favoritesService.addToFavorites(imageFile)
        }
        
        // Create view models
        favoritesViewModel = FavoritesViewModel(
            favoritesService: favoritesService,
            errorHandlingService: errorHandlingService
        )
        
        imageViewerViewModel = ImageViewerViewModel(
            preferencesService: preferencesService,
            errorHandlingService: errorHandlingService,
            favoritesService: favoritesService
        )
    }
    
    override func tearDown() async throws {
        favoritesService = nil
        preferencesService = nil
        errorHandlingService = nil
        favoritesViewModel = nil
        imageViewerViewModel = nil
        testImageFiles = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Arrow Key Navigation Tests
    
    func testArrowKeyNavigationInFavoritesView() async throws {
        // Given: Favorites view with multiple images
        await favoritesViewModel.loadFavorites()
        
        // Verify we have test images loaded
        XCTAssertEqual(favoritesViewModel.favoriteImageFiles.count, testImageFiles.count)
        
        // Create a mock favorites view for testing navigation
        let mockFavoritesView = MockFavoritesView(favoritesViewModel: favoritesViewModel)
        
        // When: Navigate right (next image)
        mockFavoritesView.navigateRight()
        
        // Then: Selection should move to next image
        XCTAssertEqual(mockFavoritesView.selectedImageIndex, 1)
        XCTAssertEqual(favoritesViewModel.selectedFavoriteImage?.url, testImageFiles[1].url)
        
        // When: Navigate left (previous image)
        mockFavoritesView.navigateLeft()
        
        // Then: Selection should move back to first image
        XCTAssertEqual(mockFavoritesView.selectedImageIndex, 0)
        XCTAssertEqual(favoritesViewModel.selectedFavoriteImage?.url, testImageFiles[0].url)
        
        // When: Navigate left from first image (should wrap to last)
        mockFavoritesView.navigateLeft()
        
        // Then: Selection should wrap to last image
        XCTAssertEqual(mockFavoritesView.selectedImageIndex, testImageFiles.count - 1)
        XCTAssertEqual(favoritesViewModel.selectedFavoriteImage?.url, testImageFiles.last?.url)
    }
    
    func testGridNavigationUpDown() async throws {
        // Given: Favorites view with enough images for grid navigation
        await favoritesViewModel.loadFavorites()
        
        let mockFavoritesView = MockFavoritesView(favoritesViewModel: favoritesViewModel)
        
        // When: Navigate down in grid
        mockFavoritesView.navigateDown()
        
        // Then: Selection should move down by estimated grid columns
        let estimatedColumns = max(1, Int(sqrt(Double(testImageFiles.count))))
        let expectedIndex = min(estimatedColumns, testImageFiles.count - 1)
        XCTAssertEqual(mockFavoritesView.selectedImageIndex, expectedIndex)
        
        // When: Navigate up in grid
        mockFavoritesView.navigateUp()
        
        // Then: Selection should move back up
        XCTAssertEqual(mockFavoritesView.selectedImageIndex, 0)
    }
    
    // MARK: - Full-Screen Mode Tests
    
    func testDoubleClickEntersFullScreenMode() async throws {
        // Given: Favorites view with loaded images
        await favoritesViewModel.loadFavorites()
        
        var fullScreenImageFile: ImageFile?
        var fullScreenFolderContent: FolderContent?
        
        let mockFavoritesView = MockFavoritesView(
            favoritesViewModel: favoritesViewModel,
            onImageSelected: { folderContent, imageFile in
                fullScreenFolderContent = folderContent
                fullScreenImageFile = imageFile
            }
        )
        
        // When: Double-click on an image
        let targetImage = testImageFiles[1]
        mockFavoritesView.enterFullScreenMode(with: targetImage)
        
        // Then: Full-screen mode should be triggered with correct image and folder content
        XCTAssertNotNil(fullScreenImageFile)
        XCTAssertNotNil(fullScreenFolderContent)
        XCTAssertEqual(fullScreenImageFile?.url, targetImage.url)
        XCTAssertEqual(fullScreenFolderContent?.currentIndex, 1)
        XCTAssertEqual(fullScreenFolderContent?.imageFiles.count, testImageFiles.count)
    }
    
    func testEnterKeyEntersFullScreenMode() async throws {
        // Given: Favorites view with selected image
        await favoritesViewModel.loadFavorites()
        
        var fullScreenTriggered = false
        let mockFavoritesView = MockFavoritesView(
            favoritesViewModel: favoritesViewModel,
            onImageSelected: { _, _ in
                fullScreenTriggered = true
            }
        )
        
        // Set initial selection
        mockFavoritesView.selectedImageIndex = 1
        
        // When: Press Enter key
        mockFavoritesView.enterFullScreenWithCurrentSelection()
        
        // Then: Full-screen mode should be triggered
        XCTAssertTrue(fullScreenTriggered)
    }
    
    // MARK: - Favorite Toggle in Full-Screen Tests
    
    func testFavoriteToggleInFullScreenMode() async throws {
        // Given: Image viewer in full-screen mode with favorites content
        let favoritesContent = FolderContent(
            folderURL: URL(string: "favorites://")!,
            imageFiles: testImageFiles,
            currentIndex: 1
        )
        
        imageViewerViewModel.loadFolderContent(favoritesContent)
        
        // Verify initial favorite status
        XCTAssertTrue(imageViewerViewModel.isFavorite)
        
        // When: Toggle favorite status
        imageViewerViewModel.toggleFavorite()
        
        // Then: Image should be removed from favorites
        XCTAssertFalse(imageViewerViewModel.isFavorite)
        XCTAssertFalse(favoritesService.isFavorite(testImageFiles[1]))
        
        // When: Toggle favorite status again
        imageViewerViewModel.toggleFavorite()
        
        // Then: Image should be added back to favorites
        XCTAssertTrue(imageViewerViewModel.isFavorite)
        XCTAssertTrue(favoritesService.isFavorite(testImageFiles[1]))
    }
    
    // MARK: - Zoom and Pan Controls Tests
    
    func testZoomControlsInFavoritesFullScreen() async throws {
        // Given: Image viewer in full-screen mode with favorites content
        let favoritesContent = FolderContent(
            folderURL: URL(string: "favorites://")!,
            imageFiles: testImageFiles,
            currentIndex: 0
        )
        
        imageViewerViewModel.loadFolderContent(favoritesContent)
        
        // Wait for image to load
        try await waitForImageLoad()
        
        // When: Zoom in
        imageViewerViewModel.zoomIn()
        
        // Then: Zoom level should increase
        XCTAssertGreaterThan(imageViewerViewModel.zoomLevel, 1.0)
        
        // When: Zoom out
        imageViewerViewModel.zoomOut()
        
        // Then: Zoom level should decrease
        XCTAssertLessThanOrEqual(imageViewerViewModel.zoomLevel, 1.0)
        
        // When: Zoom to fit
        imageViewerViewModel.zoomToFit()
        
        // Then: Should be in fit-to-window mode
        XCTAssertTrue(imageViewerViewModel.isZoomFitToWindow)
        
        // When: Zoom to actual size
        imageViewerViewModel.zoomToActualSize()
        
        // Then: Zoom level should be 100%
        XCTAssertEqual(imageViewerViewModel.zoomLevel, 1.0)
        XCTAssertFalse(imageViewerViewModel.isZoomFitToWindow)
    }
    
    // MARK: - Navigation Between Favorites in Full-Screen Tests
    
    func testNavigationBetweenFavoritesInFullScreen() async throws {
        // Given: Image viewer in full-screen mode with favorites content
        let favoritesContent = FolderContent(
            folderURL: URL(string: "favorites://")!,
            imageFiles: testImageFiles,
            currentIndex: 1
        )
        
        imageViewerViewModel.loadFolderContent(favoritesContent)
        
        // Wait for image to load
        try await waitForImageLoad()
        
        // Verify initial state
        XCTAssertEqual(imageViewerViewModel.currentIndex, 1)
        XCTAssertEqual(imageViewerViewModel.currentImageFile?.url, testImageFiles[1].url)
        
        // When: Navigate to next image
        imageViewerViewModel.nextImage()
        
        // Then: Should move to next favorite
        XCTAssertEqual(imageViewerViewModel.currentIndex, 2)
        XCTAssertEqual(imageViewerViewModel.currentImageFile?.url, testImageFiles[2].url)
        
        // When: Navigate to previous image
        imageViewerViewModel.previousImage()
        
        // Then: Should move back to previous favorite
        XCTAssertEqual(imageViewerViewModel.currentIndex, 1)
        XCTAssertEqual(imageViewerViewModel.currentImageFile?.url, testImageFiles[1].url)
    }
    
    // MARK: - Keyboard Shortcuts Tests
    
    func testKeyboardShortcutsInFavoritesView() async throws {
        // Given: Favorites view with keyboard handler
        await favoritesViewModel.loadFavorites()
        
        let mockFavoritesView = MockFavoritesView(favoritesViewModel: favoritesViewModel)
        let keyboardHandler = FavoritesKeyboardHandler(
            favoritesView: mockFavoritesView,
            onNavigateLeft: mockFavoritesView.navigateLeft,
            onNavigateRight: mockFavoritesView.navigateRight,
            onNavigateUp: mockFavoritesView.navigateUp,
            onNavigateDown: mockFavoritesView.navigateDown,
            onEnterFullScreen: mockFavoritesView.enterFullScreenWithCurrentSelection,
            onBackToFolderSelection: { },
            onToggleFavorite: mockFavoritesView.toggleCurrentFavorite
        )
        
        // Test left arrow key
        let leftArrowEvent = createKeyEvent(keyCode: 123) // Left arrow
        XCTAssertTrue(keyboardHandler.handleKeyPress(leftArrowEvent))
        
        // Test right arrow key
        let rightArrowEvent = createKeyEvent(keyCode: 124) // Right arrow
        XCTAssertTrue(keyboardHandler.handleKeyPress(rightArrowEvent))
        
        // Test Enter key
        let enterEvent = createKeyEvent(keyCode: 36) // Enter
        XCTAssertTrue(keyboardHandler.handleKeyPress(enterEvent))
        
        // Test Cmd+F for favorite toggle
        let cmdFEvent = createKeyEvent(keyCode: 3, modifiers: .command, characters: "f") // Cmd+F
        XCTAssertTrue(keyboardHandler.handleKeyPress(cmdFEvent))
    }
    
    // MARK: - Error Handling Tests
    
    func testNavigationWithEmptyFavorites() async throws {
        // Given: Empty favorites list
        favoritesService.clearAllFavorites()
        await favoritesViewModel.loadFavorites()
        
        let mockFavoritesView = MockFavoritesView(favoritesViewModel: favoritesViewModel)
        
        // When: Try to navigate
        mockFavoritesView.navigateRight()
        mockFavoritesView.navigateLeft()
        mockFavoritesView.navigateUp()
        mockFavoritesView.navigateDown()
        
        // Then: Should handle gracefully without crashes
        XCTAssertEqual(mockFavoritesView.selectedImageIndex, 0)
        XCTAssertNil(favoritesViewModel.selectedFavoriteImage)
    }
    
    // MARK: - Helper Methods
    
    private func createTestImageFiles() throws -> [ImageFile] {
        var imageFiles: [ImageFile] = []
        
        // Create temporary test image files
        let tempDir = FileManager.default.temporaryDirectory
        
        for i in 1...5 {
            let fileName = "test_image_\(i).jpg"
            let fileURL = tempDir.appendingPathComponent(fileName)
            
            // Create a minimal JPEG file (1x1 pixel)
            let imageData = createMinimalJPEGData()
            try imageData.write(to: fileURL)
            
            // Create ImageFile from the temporary file
            let imageFile = try ImageFile(url: fileURL)
            imageFiles.append(imageFile)
        }
        
        return imageFiles
    }
    
    private func createMinimalJPEGData() -> Data {
        // Minimal JPEG file data (1x1 pixel black image)
        let jpegData: [UInt8] = [
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
            0x03, 0x01, 0x00, 0x02, 0x11, 0x03, 0x11, 0x00, 0x3F, 0x00, 0x80, 0xFF, 0xD9
        ]
        return Data(jpegData)
    }
    
    private func waitForImageLoad() async throws {
        // Wait for image to load with timeout
        let timeout: TimeInterval = 5.0
        let startTime = Date()
        
        while imageViewerViewModel.isLoading && Date().timeIntervalSince(startTime) < timeout {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        if imageViewerViewModel.isLoading {
            throw XCTestError(.timeoutWhileWaiting)
        }
    }
    
    private func createKeyEvent(keyCode: UInt16, modifiers: NSEvent.ModifierFlags = [], characters: String = "") -> NSEvent {
        return NSEvent.keyEvent(
            with: .keyDown,
            location: NSPoint.zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: keyCode
        )!
    }
}

// MARK: - Mock Classes

/// Mock favorites view for testing navigation
private class MockFavoritesView {
    let favoritesViewModel: FavoritesViewModel
    var selectedImageIndex: Int = 0
    let onImageSelected: ((FolderContent, ImageFile) -> Void)?
    
    init(favoritesViewModel: FavoritesViewModel, onImageSelected: ((FolderContent, ImageFile) -> Void)? = nil) {
        self.favoritesViewModel = favoritesViewModel
        self.onImageSelected = onImageSelected
    }
    
    func navigateLeft() {
        guard !favoritesViewModel.favoriteImageFiles.isEmpty else { return }
        
        let newIndex = selectedImageIndex > 0 ? selectedImageIndex - 1 : favoritesViewModel.favoriteImageFiles.count - 1
        selectedImageIndex = newIndex
        
        if let selectedImage = getSelectedImageFile() {
            favoritesViewModel.selectFavorite(selectedImage)
        }
    }
    
    func navigateRight() {
        guard !favoritesViewModel.favoriteImageFiles.isEmpty else { return }
        
        let newIndex = selectedImageIndex < favoritesViewModel.favoriteImageFiles.count - 1 ? selectedImageIndex + 1 : 0
        selectedImageIndex = newIndex
        
        if let selectedImage = getSelectedImageFile() {
            favoritesViewModel.selectFavorite(selectedImage)
        }
    }
    
    func navigateUp() {
        guard !favoritesViewModel.favoriteImageFiles.isEmpty else { return }
        
        let estimatedColumns = max(1, Int(sqrt(Double(favoritesViewModel.favoriteImageFiles.count))))
        let newIndex = selectedImageIndex - estimatedColumns
        
        if newIndex >= 0 {
            selectedImageIndex = newIndex
        } else {
            let remainder = selectedImageIndex % estimatedColumns
            let lastRowStart = ((favoritesViewModel.favoriteImageFiles.count - 1) / estimatedColumns) * estimatedColumns
            selectedImageIndex = min(lastRowStart + remainder, favoritesViewModel.favoriteImageFiles.count - 1)
        }
        
        if let selectedImage = getSelectedImageFile() {
            favoritesViewModel.selectFavorite(selectedImage)
        }
    }
    
    func navigateDown() {
        guard !favoritesViewModel.favoriteImageFiles.isEmpty else { return }
        
        let estimatedColumns = max(1, Int(sqrt(Double(favoritesViewModel.favoriteImageFiles.count))))
        let newIndex = selectedImageIndex + estimatedColumns
        
        if newIndex < favoritesViewModel.favoriteImageFiles.count {
            selectedImageIndex = newIndex
        } else {
            let remainder = selectedImageIndex % estimatedColumns
            selectedImageIndex = remainder
        }
        
        if let selectedImage = getSelectedImageFile() {
            favoritesViewModel.selectFavorite(selectedImage)
        }
    }
    
    func enterFullScreenMode(with imageFile: ImageFile) {
        if let index = favoritesViewModel.favoriteImageFiles.firstIndex(where: { $0.url == imageFile.url }) {
            selectedImageIndex = index
            favoritesViewModel.selectFavorite(imageFile)
        }
        
        if let favoritesContent = favoritesViewModel.createFavoritesContent() {
            let updatedContent = FolderContent(
                folderURL: favoritesContent.folderURL,
                imageFiles: favoritesContent.imageFiles,
                currentIndex: selectedImageIndex
            )
            onImageSelected?(updatedContent, imageFile)
        }
    }
    
    func enterFullScreenWithCurrentSelection() {
        guard let selectedImage = getSelectedImageFile() else { return }
        enterFullScreenMode(with: selectedImage)
    }
    
    func toggleCurrentFavorite() {
        guard let selectedImage = getSelectedImageFile() else { return }
        favoritesViewModel.removeFromFavorites(selectedImage)
        
        if favoritesViewModel.favoriteImageFiles.isEmpty {
            selectedImageIndex = 0
        } else if selectedImageIndex >= favoritesViewModel.favoriteImageFiles.count {
            selectedImageIndex = favoritesViewModel.favoriteImageFiles.count - 1
        }
    }
    
    private func getSelectedImageFile() -> ImageFile? {
        guard !favoritesViewModel.favoriteImageFiles.isEmpty,
              selectedImageIndex >= 0,
              selectedImageIndex < favoritesViewModel.favoriteImageFiles.count else {
            return nil
        }
        return favoritesViewModel.favoriteImageFiles[selectedImageIndex]
    }
}

/// Mock favorites service for testing
private class MockFavoritesService: FavoritesService, ObservableObject {
    @Published private(set) var favoriteImages: [FavoriteImageFile] = []
    private let preferencesService: PreferencesService
    
    init(preferencesService: PreferencesService) {
        self.preferencesService = preferencesService
    }
    
    var favoriteImagesPublisher: Published<[FavoriteImageFile]>.Publisher {
        return $favoriteImages
    }
    
    func addToFavorites(_ imageFile: ImageFile) -> Bool {
        let favoriteImageFile = FavoriteImageFile(from: imageFile)
        favoriteImages.append(favoriteImageFile)
        return true
    }
    
    func removeFromFavorites(_ imageFile: ImageFile) -> Bool {
        favoriteImages.removeAll { $0.originalURL == imageFile.url }
        return true
    }
    
    func isFavorite(_ imageFile: ImageFile) -> Bool {
        return favoriteImages.contains { $0.originalURL == imageFile.url }
    }
    
    func validateFavorites() async {
        // Mock implementation - no validation needed for tests
    }
    
    func getValidFavorites() async -> [ImageFile] {
        return favoriteImages.compactMap { try? $0.toImageFile() }.compactMap { $0 }
    }
    
    func clearAllFavorites() {
        favoriteImages.removeAll()
    }
}

/// Mock preferences service for testing
private class MockPreferencesService: PreferencesService {
    var showFileName: Bool = true
    var showImageInfo: Bool = false
    var slideshowInterval: Double = 3.0
    var favoriteImages: [FavoriteImageFile] = []
    
    func savePreferences() {
        // Mock implementation
    }
    
    func loadFavorites() -> [FavoriteImageFile] {
        return favoriteImages
    }
    
    func saveFavorites() {
        // Mock implementation
    }
}

/// Mock error handling service for testing
private class MockErrorHandlingService: ErrorHandlingService {
    var lastNotification: (String, NotificationType)?
    var lastError: Error?
    
    override func showNotification(_ message: String, type: NotificationType) {
        lastNotification = (message, type)
    }
    
    override func handleImageViewerError(_ error: ImageViewerError) {
        lastError = error
    }
    
    override func handleImageLoaderError(_ error: ImageLoaderError, imageURL: URL) {
        lastError = error
    }
}