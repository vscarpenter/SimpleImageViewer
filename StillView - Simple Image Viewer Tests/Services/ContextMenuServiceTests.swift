import XCTest
import AppKit
@testable import StillView___Simple_Image_Viewer

class ContextMenuServiceTests: XCTestCase {
    
    var contextMenuService: ContextMenuService!
    var mockImageFile: ImageFile!
    var mockViewModel: ImageViewerViewModel!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        contextMenuService = ContextMenuService.shared
        
        // Create a mock image file for testing
        let testBundle = Bundle(for: type(of: self))
        guard let testImageURL = testBundle.url(forResource: "test-image", withExtension: "jpg") else {
            // Create a temporary test image if none exists
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-image.jpg")
            let testImage = NSImage(size: CGSize(width: 100, height: 100))
            testImage.lockFocus()
            NSColor.blue.setFill()
            NSRect(x: 0, y: 0, width: 100, height: 100).fill()
            testImage.unlockFocus()
            
            guard let tiffData = testImage.tiffRepresentation,
                  let bitmapRep = NSBitmapImageRep(data: tiffData),
                  let jpegData = bitmapRep.representation(using: .jpeg, properties: [:]) else {
                throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create test image"])
            }
            
            try jpegData.write(to: tempURL)
            mockImageFile = try ImageFile(url: tempURL)
            return
        }
        
        mockImageFile = try ImageFile(url: testImageURL)
        mockViewModel = ImageViewerViewModel()
    }
    
    override func tearDownWithError() throws {
        contextMenuService = nil
        mockImageFile = nil
        mockViewModel = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Copy Image Tests
    
    func testCopyImage() throws {
        // Given
        let expectation = XCTestExpectation(description: "Image copied to clipboard")
        
        // When
        contextMenuService.copyImage(mockImageFile)
        
        // Then
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let pasteboard = NSPasteboard.general
            let hasImage = pasteboard.canReadObject(forClasses: [NSImage.self], options: nil)
            XCTAssertTrue(hasImage, "Image should be copied to clipboard")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testCopyImagePath() throws {
        // Given
        let expectation = XCTestExpectation(description: "Image path copied to clipboard")
        
        // When
        contextMenuService.copyImagePath(mockImageFile)
        
        // Then
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let pasteboard = NSPasteboard.general
            let copiedPath = pasteboard.string(forType: .string)
            XCTAssertEqual(copiedPath, self.mockImageFile.url.path, "Image path should be copied to clipboard")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - File Operations Tests
    
    func testRevealInFinder() throws {
        // This test verifies the method doesn't crash
        // Actual Finder interaction can't be easily tested in unit tests
        XCTAssertNoThrow(contextMenuService.revealInFinder(mockImageFile))
    }
    
    // MARK: - Navigation Tests
    
    func testJumpToImage() throws {
        // Given
        let testIndex = 2
        
        // When
        contextMenuService.jumpToImage(at: testIndex, viewModel: mockViewModel)
        
        // Then
        // The actual navigation would be tested in integration tests
        // Here we just verify the method doesn't crash
        XCTAssertNoThrow(contextMenuService.jumpToImage(at: testIndex, viewModel: mockViewModel))
    }
    
    // MARK: - View Model Integration Tests
    
    func testSelectFolder() throws {
        // Given
        let initialNavigationState = mockViewModel.shouldNavigateToFolderSelection
        
        // When
        contextMenuService.selectFolder(viewModel: mockViewModel)
        
        // Then
        XCTAssertTrue(mockViewModel.shouldNavigateToFolderSelection, "Should trigger folder selection navigation")
        XCTAssertNotEqual(initialNavigationState, mockViewModel.shouldNavigateToFolderSelection, "Navigation state should change")
    }
    
    func testToggleViewMode() throws {
        // Given
        let initialViewMode = mockViewModel.viewMode
        let newViewMode: ViewMode = initialViewMode == .normal ? .grid : .normal
        
        // When
        contextMenuService.toggleViewMode(to: newViewMode, viewModel: mockViewModel)
        
        // Then
        XCTAssertEqual(mockViewModel.viewMode, newViewMode, "View mode should be updated")
        XCTAssertNotEqual(mockViewModel.viewMode, initialViewMode, "View mode should change")
    }
    
    // MARK: - Action Availability Tests
    
    func testIsActionAvailableWithImageFile() throws {
        // Test actions that require an image file
        let imageActions: [ContextMenuAction] = [.copyImage, .copyPath, .share, .revealInFinder, .moveToTrash, .toggleFavorite]
        
        for action in imageActions {
            XCTAssertTrue(contextMenuService.isActionAvailable(action, for: mockImageFile), 
                         "Action \(action) should be available with image file")
            XCTAssertFalse(contextMenuService.isActionAvailable(action, for: nil), 
                          "Action \(action) should not be available without image file")
        }
    }
    
    func testIsActionAvailableWithoutImageFile() throws {
        // Test actions that don't require an image file
        let generalActions: [ContextMenuAction] = [.selectFolder, .toggleViewMode, .openPreferences]
        
        for action in generalActions {
            XCTAssertTrue(contextMenuService.isActionAvailable(action, for: nil), 
                         "Action \(action) should be available without image file")
            XCTAssertTrue(contextMenuService.isActionAvailable(action, for: mockImageFile), 
                         "Action \(action) should be available with image file")
        }
    }
    
    // MARK: - Context Menu Action Properties Tests
    
    func testContextMenuActionProperties() throws {
        // Test that all actions have proper titles and icons
        for action in ContextMenuAction.allCases {
            XCTAssertFalse(action.title.isEmpty, "Action \(action) should have a title")
            XCTAssertFalse(action.icon.isEmpty, "Action \(action) should have an icon")
        }
        
        // Test destructive action
        XCTAssertTrue(ContextMenuAction.moveToTrash.isDestructive, "Move to trash should be destructive")
        XCTAssertFalse(ContextMenuAction.copyImage.isDestructive, "Copy image should not be destructive")
    }
    
    func testKeyboardShortcuts() throws {
        // Test that important actions have keyboard shortcuts
        XCTAssertNotNil(ContextMenuAction.copyImage.keyboardShortcut, "Copy image should have keyboard shortcut")
        XCTAssertNotNil(ContextMenuAction.revealInFinder.keyboardShortcut, "Reveal in Finder should have keyboard shortcut")
        XCTAssertNotNil(ContextMenuAction.selectFolder.keyboardShortcut, "Select folder should have keyboard shortcut")
        XCTAssertNotNil(ContextMenuAction.moveToTrash.keyboardShortcut, "Move to trash should have keyboard shortcut")
        XCTAssertNotNil(ContextMenuAction.toggleFavorite.keyboardShortcut, "Toggle favorite should have keyboard shortcut")
    }
    
    // MARK: - Favorites Tests
    
    func testToggleFavoriteAddToFavorites() throws {
        // Given
        let mockFavoritesService = MockFavoritesService()
        XCTAssertFalse(mockFavoritesService.isFavorite(mockImageFile), "Image should not be favorited initially")
        
        // When
        contextMenuService.toggleFavorite(mockImageFile, favoritesService: mockFavoritesService)
        
        // Then
        XCTAssertTrue(mockFavoritesService.addToFavoritesCalled, "addToFavorites should be called")
        XCTAssertFalse(mockFavoritesService.removeFromFavoritesCalled, "removeFromFavorites should not be called")
    }
    
    func testToggleFavoriteRemoveFromFavorites() throws {
        // Given
        let mockFavoritesService = MockFavoritesService()
        mockFavoritesService.mockIsFavorite = true
        XCTAssertTrue(mockFavoritesService.isFavorite(mockImageFile), "Image should be favorited initially")
        
        // When
        contextMenuService.toggleFavorite(mockImageFile, favoritesService: mockFavoritesService)
        
        // Then
        XCTAssertTrue(mockFavoritesService.removeFromFavoritesCalled, "removeFromFavorites should be called")
        XCTAssertFalse(mockFavoritesService.addToFavoritesCalled, "addToFavorites should not be called")
    }
    
    func testGetFavoriteActionTitleForNonFavorite() throws {
        // Given
        let mockFavoritesService = MockFavoritesService()
        mockFavoritesService.mockIsFavorite = false
        
        // When
        let title = contextMenuService.getFavoriteActionTitle(for: mockImageFile, favoritesService: mockFavoritesService)
        
        // Then
        XCTAssertEqual(title, "Add to Favorites", "Should return 'Add to Favorites' for non-favorite image")
    }
    
    func testGetFavoriteActionTitleForFavorite() throws {
        // Given
        let mockFavoritesService = MockFavoritesService()
        mockFavoritesService.mockIsFavorite = true
        
        // When
        let title = contextMenuService.getFavoriteActionTitle(for: mockImageFile, favoritesService: mockFavoritesService)
        
        // Then
        XCTAssertEqual(title, "Remove from Favorites", "Should return 'Remove from Favorites' for favorite image")
    }
    
    func testGetFavoriteActionIconForNonFavorite() throws {
        // Given
        let mockFavoritesService = MockFavoritesService()
        mockFavoritesService.mockIsFavorite = false
        
        // When
        let icon = contextMenuService.getFavoriteActionIcon(for: mockImageFile, favoritesService: mockFavoritesService)
        
        // Then
        XCTAssertEqual(icon, "heart", "Should return 'heart' icon for non-favorite image")
    }
    
    func testGetFavoriteActionIconForFavorite() throws {
        // Given
        let mockFavoritesService = MockFavoritesService()
        mockFavoritesService.mockIsFavorite = true
        
        // When
        let icon = contextMenuService.getFavoriteActionIcon(for: mockImageFile, favoritesService: mockFavoritesService)
        
        // Then
        XCTAssertEqual(icon, "heart.fill", "Should return 'heart.fill' icon for favorite image")
    }
    
    func testToggleFavoriteActionAvailability() throws {
        // Given
        let action = ContextMenuAction.toggleFavorite
        
        // When & Then
        XCTAssertTrue(contextMenuService.isActionAvailable(action, for: mockImageFile), 
                     "Toggle favorite should be available with image file")
        XCTAssertFalse(contextMenuService.isActionAvailable(action, for: nil), 
                      "Toggle favorite should not be available without image file")
    }
    
    func testToggleFavoriteActionProperties() throws {
        // Given
        let action = ContextMenuAction.toggleFavorite
        
        // When & Then
        XCTAssertEqual(action.title, "Toggle Favorite", "Toggle favorite should have correct title")
        XCTAssertEqual(action.icon, "heart", "Toggle favorite should have heart icon")
        XCTAssertEqual(action.keyboardShortcut, "f", "Toggle favorite should have 'f' keyboard shortcut")
        XCTAssertEqual(action.keyboardModifiers, .command, "Toggle favorite should use command modifier")
        XCTAssertFalse(action.isDestructive, "Toggle favorite should not be destructive")
    }
}

// MARK: - Mock Classes for Testing

class MockFavoritesService: FavoritesService {
    @Published var favoriteImages: [FavoriteImageFile] = []
    
    var favoriteImagesPublisher: Published<[FavoriteImageFile]>.Publisher {
        $favoriteImages
    }
    
    var mockIsFavorite = false
    var mockAddToFavoritesResult = true
    var mockRemoveFromFavoritesResult = true
    
    var addToFavoritesCalled = false
    var removeFromFavoritesCalled = false
    var isFavoriteCalled = false
    
    func addToFavorites(_ imageFile: ImageFile) -> Bool {
        addToFavoritesCalled = true
        if mockAddToFavoritesResult {
            let favoriteImage = FavoriteImageFile(from: imageFile)
            favoriteImages.append(favoriteImage)
        }
        return mockAddToFavoritesResult
    }
    
    func removeFromFavorites(_ imageFile: ImageFile) -> Bool {
        removeFromFavoritesCalled = true
        if mockRemoveFromFavoritesResult {
            favoriteImages.removeAll { $0.originalURL == imageFile.url }
        }
        return mockRemoveFromFavoritesResult
    }
    
    func isFavorite(_ imageFile: ImageFile) -> Bool {
        isFavoriteCalled = true
        return mockIsFavorite
    }
    
    func validateFavorites() async {
        // Mock implementation
    }
    
    func getValidFavorites() async -> [ImageFile] {
        return []
    }
    
    func clearAllFavorites() {
        favoriteImages.removeAll()
    }
}

class MockImageViewerViewModel: ImageViewerViewModel {
    var mockShouldNavigateToFolderSelection = false
    var mockViewMode: ViewMode = .normal
    var mockCanShareCurrentImage = true
    var mockCanDeleteCurrentImage = true
    
    override var shouldNavigateToFolderSelection: Bool {
        get { mockShouldNavigateToFolderSelection }
        set { mockShouldNavigateToFolderSelection = newValue }
    }
    
    override var viewMode: ViewMode {
        get { mockViewMode }
        set { mockViewMode = newValue }
    }
    
    override var canShareCurrentImage: Bool {
        return mockCanShareCurrentImage
    }
    
    override var canDeleteCurrentImage: Bool {
        return mockCanDeleteCurrentImage
    }
    
    override func navigateToFolderSelection() {
        mockShouldNavigateToFolderSelection = true
    }
    
    override func setViewMode(_ mode: ViewMode) {
        mockViewMode = mode
    }
    
    override func jumpToImage(at index: Int) {
        // Mock implementation - just verify it's called
    }
}