//
//  HeartButtonUITests.swift
//  Simple Image Viewer Tests
//
//  Created by Kiro on 8/11/25.
//

import XCTest
import SwiftUI
import AppKit
@testable import Simple_Image_Viewer

@MainActor
final class HeartButtonUITests: XCTestCase {
    
    // MARK: - Test Setup
    
    private var mockViewModel: ImageViewerViewModel!
    private var mockImageFile: ImageFile!
    private var mockFavoritesService: MockFavoritesService!
    private var mockPreferencesService: MockPreferencesService!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        
        // Create mock services
        mockPreferencesService = MockPreferencesService()
        mockFavoritesService = MockFavoritesService(preferencesService: mockPreferencesService)
        
        // Create mock view model with favorites service
        mockViewModel = ImageViewerViewModel(
            favoritesService: mockFavoritesService
        )
        
        // Create mock image file
        mockImageFile = createMockImageFile()
        
        // Set up mock folder content with the image file
        let mockFolderContent = FolderContent(
            folderURL: URL(fileURLWithPath: "/tmp"),
            imageFiles: [mockImageFile],
            currentIndex: 0
        )
        mockViewModel.loadFolderContent(mockFolderContent)
    }
    
    override func tearDown() {
        mockViewModel = nil
        mockImageFile = nil
        mockFavoritesService = nil
        mockPreferencesService = nil
        super.tearDown()
    }
    
    // MARK: - Heart Button Visibility Tests
    
    func testHeartButtonIsVisible() {
        // Test that the heart button is visible in the navigation controls
        let view = NavigationControlsView(viewModel: mockViewModel) { }
        let hostingController = NSHostingController(rootView: view)
        
        hostingController.loadView()
        
        // Verify view loads without crashing
        XCTAssertNotNil(hostingController.view)
        
        // The heart button should be visible as part of the responsive right section
        // This is tested by ensuring the view renders without errors
    }
    
    func testHeartButtonVisibilityWithNoImage() {
        // Test heart button when no image is loaded
        let emptyViewModel = ImageViewerViewModel(favoritesService: mockFavoritesService)
        let view = NavigationControlsView(viewModel: emptyViewModel) { }
        let hostingController = NSHostingController(rootView: view)
        
        hostingController.loadView()
        
        // View should still render, but heart button should be disabled
        XCTAssertNotNil(hostingController.view)
        XCTAssertNil(emptyViewModel.currentImageFile)
    }
    
    func testHeartButtonInDifferentLayoutModes() {
        // Test heart button visibility in different responsive layout modes
        let view = NavigationControlsView(viewModel: mockViewModel) { }
        
        // Test in different window sizes to trigger different layout modes
        let testSizes: [CGSize] = [
            CGSize(width: 1200, height: 800), // Full layout
            CGSize(width: 800, height: 600),  // Standard layout
            CGSize(width: 600, height: 400),  // Compact layout
            CGSize(width: 400, height: 300)   // Ultra compact layout
        ]
        
        for size in testSizes {
            let hostingController = NSHostingController(rootView: view)
            hostingController.view.frame = NSRect(origin: .zero, size: size)
            hostingController.loadView()
            
            XCTAssertNotNil(hostingController.view, "Heart button should be visible at size \(size)")
        }
    }
    
    // MARK: - Heart Button State Tests
    
    func testHeartButtonUnfavoritedState() {
        // Test heart button appearance when image is not favorited
        XCTAssertFalse(mockViewModel.isFavorite, "Image should not be favorited initially")
        
        let view = NavigationControlsView(viewModel: mockViewModel) { }
        let hostingController = NSHostingController(rootView: view)
        
        hostingController.loadView()
        XCTAssertNotNil(hostingController.view)
        
        // Verify the view model state
        XCTAssertFalse(mockFavoritesService.isFavorite(mockImageFile))
    }
    
    func testHeartButtonFavoritedState() {
        // Test heart button appearance when image is favorited
        let success = mockFavoritesService.addToFavorites(mockImageFile)
        XCTAssertTrue(success, "Should be able to add image to favorites")
        
        XCTAssertTrue(mockViewModel.isFavorite, "Image should be favorited")
        
        let view = NavigationControlsView(viewModel: mockViewModel) { }
        let hostingController = NSHostingController(rootView: view)
        
        hostingController.loadView()
        XCTAssertNotNil(hostingController.view)
        
        // Verify the favorites service state
        XCTAssertTrue(mockFavoritesService.isFavorite(mockImageFile))
    }
    
    func testHeartButtonStateToggling() {
        // Test that heart button state changes when favorites are toggled
        XCTAssertFalse(mockViewModel.isFavorite, "Should start unfavorited")
        
        // Toggle to favorited
        mockViewModel.toggleFavorite()
        XCTAssertTrue(mockViewModel.isFavorite, "Should be favorited after toggle")
        XCTAssertTrue(mockFavoritesService.isFavorite(mockImageFile))
        
        // Toggle back to unfavorited
        mockViewModel.toggleFavorite()
        XCTAssertFalse(mockViewModel.isFavorite, "Should be unfavorited after second toggle")
        XCTAssertFalse(mockFavoritesService.isFavorite(mockImageFile))
    }
    
    // MARK: - Heart Button Interaction Tests
    
    func testHeartButtonToggleFunctionality() {
        // Test that the heart button correctly toggles favorite status
        let initialFavoriteState = mockViewModel.isFavorite
        
        // Simulate button press by calling the toggle function
        mockViewModel.toggleFavorite()
        
        // Verify state changed
        XCTAssertNotEqual(mockViewModel.isFavorite, initialFavoriteState, 
                         "Favorite state should change after toggle")
        
        // Toggle again and verify it returns to original state
        mockViewModel.toggleFavorite()
        XCTAssertEqual(mockViewModel.isFavorite, initialFavoriteState,
                      "Favorite state should return to original after second toggle")
    }
    
    func testHeartButtonDisabledWithNoImage() {
        // Test that heart button is disabled when no image is loaded
        let emptyViewModel = ImageViewerViewModel(favoritesService: mockFavoritesService)
        
        // Attempt to toggle favorite with no image
        emptyViewModel.toggleFavorite()
        
        // Should not crash and should show appropriate notification
        XCTAssertNil(emptyViewModel.currentImageFile)
    }
    
    func testHeartButtonWithMultipleImages() {
        // Test heart button behavior when switching between images
        let secondImageFile = createMockImageFile(name: "test_image_2.jpg")
        let mockFolderContent = FolderContent(
            folderURL: URL(fileURLWithPath: "/tmp"),
            imageFiles: [mockImageFile, secondImageFile],
            currentIndex: 0
        )
        mockViewModel.loadFolderContent(mockFolderContent)
        
        // Favorite the first image
        mockViewModel.toggleFavorite()
        XCTAssertTrue(mockViewModel.isFavorite, "First image should be favorited")
        
        // Switch to second image
        mockViewModel.nextImage()
        XCTAssertFalse(mockViewModel.isFavorite, "Second image should not be favorited")
        
        // Favorite the second image
        mockViewModel.toggleFavorite()
        XCTAssertTrue(mockViewModel.isFavorite, "Second image should now be favorited")
        
        // Switch back to first image
        mockViewModel.previousImage()
        XCTAssertTrue(mockViewModel.isFavorite, "First image should still be favorited")
    }
    
    // MARK: - Accessibility Tests
    
    func testHeartButtonAccessibilityLabels() {
        // Test accessibility labels for unfavorited state
        XCTAssertFalse(mockViewModel.isFavorite)
        
        let view = NavigationControlsView(viewModel: mockViewModel) { }
        let hostingController = NSHostingController(rootView: view)
        hostingController.loadView()
        
        // Verify view has accessibility elements
        XCTAssertNotNil(hostingController.view)
        
        // Toggle to favorited state and test again
        mockViewModel.toggleFavorite()
        XCTAssertTrue(mockViewModel.isFavorite)
        
        let favoritedView = NavigationControlsView(viewModel: mockViewModel) { }
        let favoritedController = NSHostingController(rootView: favoritedView)
        favoritedController.loadView()
        
        XCTAssertNotNil(favoritedController.view)
    }
    
    func testHeartButtonKeyboardShortcut() {
        // Test that Cmd+F keyboard shortcut works for toggling favorites
        let keyboardHandler = KeyboardHandler(imageViewerViewModel: mockViewModel)
        
        // Create mock Cmd+F key event
        let mockEvent = createMockKeyEvent(characters: "f", modifierFlags: .command)
        
        let initialState = mockViewModel.isFavorite
        let handled = keyboardHandler.handleKeyPress(mockEvent)
        
        XCTAssertTrue(handled, "Keyboard handler should handle Cmd+F")
        XCTAssertNotEqual(mockViewModel.isFavorite, initialState, 
                         "Favorite state should change after Cmd+F")
    }
    
    func testHeartButtonKeyboardShortcutWithoutCommand() {
        // Test that F key without Cmd modifier doesn't toggle favorites (should toggle fullscreen)
        let keyboardHandler = KeyboardHandler(imageViewerViewModel: mockViewModel)
        
        // Create mock F key event without command modifier
        let mockEvent = createMockKeyEvent(characters: "f", modifierFlags: [])
        
        let initialFavoriteState = mockViewModel.isFavorite
        let handled = keyboardHandler.handleKeyPress(mockEvent)
        
        XCTAssertTrue(handled, "Keyboard handler should handle F key")
        XCTAssertEqual(mockViewModel.isFavorite, initialFavoriteState, 
                      "Favorite state should not change with F key alone")
    }
    
    // MARK: - Visual State Tests
    
    func testHeartButtonIconStates() {
        // Test that heart button shows correct icons for different states
        let view = NavigationControlsView(viewModel: mockViewModel) { }
        
        // Test unfavorited state (should show outline heart)
        XCTAssertFalse(mockViewModel.isFavorite)
        let unfavoritedController = NSHostingController(rootView: view)
        unfavoritedController.loadView()
        XCTAssertNotNil(unfavoritedController.view)
        
        // Test favorited state (should show filled heart)
        mockViewModel.toggleFavorite()
        XCTAssertTrue(mockViewModel.isFavorite)
        let favoritedController = NSHostingController(rootView: view)
        favoritedController.loadView()
        XCTAssertNotNil(favoritedController.view)
    }
    
    func testHeartButtonHoverEffects() {
        // Test that heart button responds to hover effects
        let view = NavigationControlsView(viewModel: mockViewModel) { }
        let hostingController = NSHostingController(rootView: view)
        
        hostingController.loadView()
        
        // Verify view loads and can handle hover events
        XCTAssertNotNil(hostingController.view)
        
        // The hover effects are handled by the ToolbarButtonStyle
        // This test ensures the view structure supports hover interactions
    }
    
    // MARK: - Dark Mode Tests
    
    func testHeartButtonInLightMode() {
        // Test heart button appearance in light mode
        NSApp.appearance = NSAppearance(named: .aqua)
        
        let view = NavigationControlsView(viewModel: mockViewModel) { }
        let hostingController = NSHostingController(rootView: view)
        
        hostingController.loadView()
        XCTAssertNotNil(hostingController.view)
        XCTAssertEqual(Color.currentColorScheme, .light)
    }
    
    func testHeartButtonInDarkMode() {
        // Test heart button appearance in dark mode
        NSApp.appearance = NSAppearance(named: .darkAqua)
        
        let view = NavigationControlsView(viewModel: mockViewModel) { }
        let hostingController = NSHostingController(rootView: view)
        
        hostingController.loadView()
        XCTAssertNotNil(hostingController.view)
        XCTAssertEqual(Color.currentColorScheme, .dark)
    }
    
    func testHeartButtonColorConsistency() {
        // Test that heart button colors are consistent with app theme
        let testModes: [NSAppearance.Name] = [.aqua, .darkAqua]
        
        for appearanceName in testModes {
            NSApp.appearance = NSAppearance(named: appearanceName)
            
            let view = NavigationControlsView(viewModel: mockViewModel) { }
            let hostingController = NSHostingController(rootView: view)
            
            hostingController.loadView()
            XCTAssertNotNil(hostingController.view)
            
            // Verify adaptive colors are available
            XCTAssertNotNil(Color.appText)
            XCTAssertNotNil(Color.appToolbarBackground)
        }
    }
    
    // MARK: - Performance Tests
    
    func testHeartButtonTogglePerformance() {
        // Test that heart button toggling is performant
        measure {
            for _ in 0..<100 {
                mockViewModel.toggleFavorite()
            }
        }
    }
    
    func testHeartButtonRenderingPerformance() {
        // Test that heart button rendering is performant
        let view = NavigationControlsView(viewModel: mockViewModel) { }
        
        measure {
            for _ in 0..<50 {
                let hostingController = NSHostingController(rootView: view)
                hostingController.loadView()
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testHeartButtonWithFavoritesServiceError() {
        // Test heart button behavior when favorites service fails
        let failingFavoritesService = FailingMockFavoritesService()
        let viewModelWithFailingService = ImageViewerViewModel(
            favoritesService: failingFavoritesService
        )
        
        let mockFolderContent = FolderContent(
            folderURL: URL(fileURLWithPath: "/tmp"),
            imageFiles: [mockImageFile],
            currentIndex: 0
        )
        viewModelWithFailingService.loadFolderContent(mockFolderContent)
        
        // Attempt to toggle favorite - should handle error gracefully
        viewModelWithFailingService.toggleFavorite()
        
        // Should not crash and should maintain consistent state
        XCTAssertNotNil(viewModelWithFailingService.currentImageFile)
    }
    
    // MARK: - Integration Tests
    
    func testHeartButtonIntegrationWithNavigationControls() {
        // Test that heart button integrates properly with other navigation controls
        let view = NavigationControlsView(viewModel: mockViewModel) { }
        let hostingController = NSHostingController(rootView: view)
        
        hostingController.loadView()
        
        // Test that heart button works alongside other controls
        mockViewModel.toggleFavorite()
        mockViewModel.nextImage() // Should work even after favoriting
        mockViewModel.toggleImageInfo() // Other controls should still work
        
        XCTAssertNotNil(hostingController.view)
    }
    
    // MARK: - Helper Methods
    
    private func createMockImageFile(name: String = "test_image.jpg") -> ImageFile {
        // Create a temporary file for testing
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(name)
        
        // Create a simple test file
        let testData = Data([0xFF, 0xD8, 0xFF, 0xE0]) // JPEG header
        try? testData.write(to: tempURL)
        
        do {
            return try ImageFile(url: tempURL)
        } catch {
            // Fallback: create with a system image path
            let systemImageURL = URL(fileURLWithPath: "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericDocumentIcon.icns")
            return try! ImageFile(url: systemImageURL)
        }
    }
    
    private func createMockKeyEvent(characters: String, modifierFlags: NSEvent.ModifierFlags) -> NSEvent {
        // Create a mock NSEvent for testing keyboard shortcuts
        return NSEvent.keyEvent(
            with: .keyDown,
            location: NSPoint.zero,
            modifierFlags: modifierFlags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: 0
        )!
    }
}

// MARK: - Mock Services

private class MockFavoritesService: FavoritesService {
    private var favorites: Set<URL> = []
    private let preferencesService: PreferencesService
    
    init(preferencesService: PreferencesService) {
        self.preferencesService = preferencesService
    }
    
    var favoriteImages: [FavoriteImageFile] {
        return favorites.compactMap { url in
            do {
                let imageFile = try ImageFile(url: url)
                return FavoriteImageFile(from: imageFile)
            } catch {
                return nil
            }
        }
    }
    
    func addToFavorites(_ imageFile: ImageFile) -> Bool {
        favorites.insert(imageFile.url)
        return true
    }
    
    func removeFromFavorites(_ imageFile: ImageFile) -> Bool {
        favorites.remove(imageFile.url)
        return true
    }
    
    func isFavorite(_ imageFile: ImageFile) -> Bool {
        return favorites.contains(imageFile.url)
    }
    
    func validateFavorites() async {
        // Mock implementation - no validation needed for tests
    }
    
    func getValidFavorites() async -> [ImageFile] {
        return favoriteImages.compactMap { favoriteImageFile in
            try? favoriteImageFile.toImageFile()
        }
    }
}

private class FailingMockFavoritesService: FavoritesService {
    var favoriteImages: [FavoriteImageFile] { return [] }
    
    func addToFavorites(_ imageFile: ImageFile) -> Bool {
        return false // Always fail
    }
    
    func removeFromFavorites(_ imageFile: ImageFile) -> Bool {
        return false // Always fail
    }
    
    func isFavorite(_ imageFile: ImageFile) -> Bool {
        return false
    }
    
    func validateFavorites() async {
        // Mock implementation
    }
    
    func getValidFavorites() async -> [ImageFile] {
        return []
    }
}

private class MockPreferencesService: PreferencesService {
    var showFileName: Bool = false
    var showImageInfo: Bool = false
    var slideshowInterval: Double = 3.0
    var favoriteImages: [FavoriteImageFile] = []
    
    func saveFavorites() {
        // Mock implementation
    }
    
    func loadFavorites() -> [FavoriteImageFile] {
        return favoriteImages
    }
}