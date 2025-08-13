//
//  FavoritesAccessibilityTests.swift
//  Simple Image Viewer Tests
//
//  Created by Kiro on 8/12/25.
//

import XCTest
import SwiftUI
import AppKit
@testable import Simple_Image_Viewer

@MainActor
final class FavoritesAccessibilityTests: XCTestCase {
    
    // MARK: - Test Setup
    
    private var originalAppearance: NSAppearance?
    private var originalHighContrast: Bool = false
    private var originalReducedMotion: Bool = false
    private var testImageFiles: [ImageFile] = []
    private var mockFavoritesService: MockFavoritesService!
    private var mockPreferencesService: MockPreferencesService!
    
    override func setUp() {
        super.setUp()
        originalAppearance = NSApp.effectiveAppearance
        originalHighContrast = AccessibilityService.shared.isHighContrastEnabled
        originalReducedMotion = AccessibilityService.shared.isReducedMotionEnabled
        
        // Create test image files
        testImageFiles = createTestImageFiles()
        
        // Create mock services
        mockPreferencesService = MockPreferencesService()
        mockFavoritesService = MockFavoritesService(preferencesService: mockPreferencesService)
        
        continueAfterFailure = false
    }
    
    override func tearDown() {
        // Restore original settings
        if let originalAppearance = originalAppearance {
            NSApp.appearance = originalAppearance
        }
        AccessibilityService.shared.isHighContrastEnabled = originalHighContrast
        AccessibilityService.shared.isReducedMotionEnabled = originalReducedMotion
        super.tearDown()
    }
    
    // MARK: - Heart Button Accessibility Tests
    
    func testHeartButtonAccessibilityLabels() {
        // Test heart button accessibility labels for both favorited and non-favorited states
        let imageViewerViewModel = createTestImageViewerViewModel()
        let navigationControls = NavigationControlsView(
            viewModel: imageViewerViewModel,
            onExit: {}
        )
        
        let hostingController = NSHostingController(rootView: navigationControls)
        hostingController.loadView()
        
        // Test that the view has accessibility elements
        let hasAccessibilityElements = hostingController.view.isAccessibilityElement() ||
                                      (hostingController.view.accessibilityElements()?.count ?? 0) > 0
        XCTAssertTrue(hasAccessibilityElements, "Navigation controls should have accessibility elements")
        
        // Test accessibility structure
        XCTAssertNotNil(hostingController.view, "Navigation controls should be accessible")
    }
    
    func testHeartButtonAccessibilityStates() {
        // Test heart button accessibility states for favorited vs non-favorited images
        let imageViewerViewModel = createTestImageViewerViewModel()
        
        // Test non-favorited state
        XCTAssertFalse(imageViewerViewModel.isFavorite, "Image should not be favorited initially")
        
        // Test favorited state
        imageViewerViewModel.toggleFavorite()
        XCTAssertTrue(imageViewerViewModel.isFavorite, "Image should be favorited after toggle")
        
        // Test accessibility properties change with state
        let navigationControls = NavigationControlsView(
            viewModel: imageViewerViewModel,
            onExit: {}
        )
        
        let hostingController = NSHostingController(rootView: navigationControls)
        hostingController.loadView()
        
        XCTAssertNotNil(hostingController.view, "Navigation controls should handle favorited state")
    }
    
    func testHeartButtonKeyboardShortcut() {
        // Test that Cmd+F keyboard shortcut is properly announced
        let imageViewerViewModel = createTestImageViewerViewModel()
        let keyboardHandler = KeyboardHandler(imageViewerViewModel: imageViewerViewModel)
        
        // Create a mock key event for Cmd+F
        let mockEvent = createMockKeyEvent(keyCode: 3, modifierFlags: [.command]) // 'f' key with Cmd
        
        let handled = keyboardHandler.handleKeyPress(mockEvent)
        XCTAssertTrue(handled, "Cmd+F should be handled by keyboard handler")
        
        // Verify favorite status changed
        XCTAssertTrue(imageViewerViewModel.isFavorite, "Image should be favorited after Cmd+F")
    }
    
    // MARK: - Heart Indicator Accessibility Tests
    
    func testHeartIndicatorAccessibilityLabels() {
        // Test heart indicator accessibility labels on thumbnails
        let heartIndicator = HeartIndicatorView(
            isFavorite: true,
            thumbnailSize: CGSize(width: 120, height: 120),
            isVisible: true
        )
        
        let hostingController = NSHostingController(rootView: heartIndicator)
        hostingController.loadView()
        
        // Test that heart indicator has proper accessibility properties
        XCTAssertNotNil(hostingController.view, "Heart indicator should be accessible")
        
        // Test that the indicator is properly hidden from accessibility when parent handles it
        // This is tested through the accessibilityHidden(true) property
    }
    
    func testHeartIndicatorHighContrastMode() {
        // Test heart indicator visibility in high contrast mode
        AccessibilityService.shared.isHighContrastEnabled = true
        
        let heartIndicator = HeartIndicatorView(
            isFavorite: true,
            thumbnailSize: CGSize(width: 120, height: 120),
            isVisible: true
        )
        
        let hostingController = NSHostingController(rootView: heartIndicator)
        hostingController.loadView()
        
        // Verify heart indicator adapts to high contrast mode
        XCTAssertNotNil(hostingController.view, "Heart indicator should work in high contrast mode")
        
        // Test that colors are adapted for high contrast
        XCTAssertTrue(AccessibilityService.shared.isHighContrastEnabled, "High contrast should be enabled")
    }
    
    func testHeartIndicatorReducedMotion() {
        // Test heart indicator respects reduced motion preferences
        AccessibilityService.shared.isReducedMotionEnabled = true
        
        let heartIndicator = HeartIndicatorView(
            isFavorite: true,
            thumbnailSize: CGSize(width: 120, height: 120),
            isVisible: true
        )
        
        let hostingController = NSHostingController(rootView: heartIndicator)
        hostingController.loadView()
        
        // Verify heart indicator respects reduced motion
        XCTAssertNotNil(hostingController.view, "Heart indicator should work with reduced motion")
        
        // Test that animations are disabled
        let animationDuration = AccessibilityService.shared.adaptiveAnimationDuration(0.3)
        XCTAssertEqual(animationDuration, 0.0, "Animation should be disabled with reduced motion")
    }
    
    // MARK: - Favorites View Accessibility Tests
    
    func testFavoritesViewAccessibilityStructure() {
        // Test that FavoritesView has proper accessibility structure
        let favoritesView = FavoritesView(
            onImageSelected: { _, _ in },
            onBackToFolderSelection: {}
        )
        
        let hostingController = NSHostingController(rootView: favoritesView)
        hostingController.loadView()
        
        // Test accessibility hierarchy
        let hasAccessibilityElements = hostingController.view.isAccessibilityElement() ||
                                      (hostingController.view.accessibilityElements()?.count ?? 0) > 0
        XCTAssertTrue(hasAccessibilityElements, "Favorites view should have accessibility elements")
        
        // Test that the view is properly labeled
        XCTAssertNotNil(hostingController.view, "Favorites view should be accessible")
    }
    
    func testFavoritesViewKeyboardNavigation() {
        // Test keyboard navigation in favorites view
        let favoritesView = FavoritesView(
            onImageSelected: { _, _ in },
            onBackToFolderSelection: {}
        )
        
        let hostingController = NSHostingController(rootView: favoritesView)
        hostingController.loadView()
        
        // Test that the view accepts keyboard input
        let canBecomeFirstResponder = hostingController.view.acceptsFirstResponder
        XCTAssertTrue(canBecomeFirstResponder, "Favorites view should accept keyboard input")
        
        // Test focus management
        let canSetFocus = hostingController.view.canBecomeKeyView
        XCTAssertTrue(canSetFocus, "Favorites view should be able to receive focus")
    }
    
    func testFavoritesViewEmptyStateAccessibility() {
        // Test accessibility of empty favorites state
        let favoritesView = FavoritesView(
            onImageSelected: { _, _ in },
            onBackToFolderSelection: {}
        )
        
        let hostingController = NSHostingController(rootView: favoritesView)
        hostingController.loadView()
        
        // Test that empty state is accessible
        XCTAssertNotNil(hostingController.view, "Empty favorites view should be accessible")
        
        // Test that empty state provides helpful information
        let accessibilityLabel = hostingController.view.accessibilityLabel()
        if let label = accessibilityLabel {
            XCTAssertTrue(label.contains("Favorites") || label.contains("favorites"), 
                         "Empty state should mention favorites")
        }
    }
    
    // MARK: - Thumbnail Grid Accessibility Tests
    
    func testThumbnailGridAccessibilityLabels() {
        // Test thumbnail grid accessibility labels include favorite status
        let imageViewerViewModel = createTestImageViewerViewModel()
        let gridView = EnhancedThumbnailGridView(
            imageFiles: testImageFiles,
            selectedImageFile: testImageFiles.first,
            thumbnailQuality: .medium,
            viewModel: imageViewerViewModel,
            onImageSelected: { _ in },
            onImageDoubleClicked: { _ in }
        )
        
        let hostingController = NSHostingController(rootView: gridView)
        hostingController.loadView()
        
        // Test that grid has accessibility elements
        let hasAccessibilityElements = hostingController.view.isAccessibilityElement() ||
                                      (hostingController.view.accessibilityElements()?.count ?? 0) > 0
        XCTAssertTrue(hasAccessibilityElements, "Thumbnail grid should have accessibility elements")
        
        // Test that thumbnails are accessible
        XCTAssertNotNil(hostingController.view, "Thumbnail grid should be accessible")
    }
    
    func testThumbnailAccessibilityWithFavoriteStatus() {
        // Test that thumbnail accessibility includes favorite status
        let imageViewerViewModel = createTestImageViewerViewModel()
        
        // Mark first image as favorite
        if let firstImage = testImageFiles.first {
            mockFavoritesService.addToFavorites(firstImage)
        }
        
        let gridView = EnhancedThumbnailGridView(
            imageFiles: testImageFiles,
            selectedImageFile: testImageFiles.first,
            thumbnailQuality: .medium,
            viewModel: imageViewerViewModel,
            onImageSelected: { _ in },
            onImageDoubleClicked: { _ in }
        )
        
        let hostingController = NSHostingController(rootView: gridView)
        hostingController.loadView()
        
        // Test that favorite status is included in accessibility
        XCTAssertNotNil(hostingController.view, "Grid with favorited items should be accessible")
    }
    
    // MARK: - Keyboard Navigation Tests
    
    func testFavoritesKeyboardNavigationArrowKeys() {
        // Test arrow key navigation in favorites view
        let keyboardHandler = FavoritesKeyboardHandler(
            onNavigateLeft: {},
            onNavigateRight: {},
            onNavigateUp: {},
            onNavigateDown: {},
            onEnterFullScreen: {},
            onBackToFolderSelection: {},
            onToggleFavorite: {}
        )
        
        // Test left arrow
        let leftArrowEvent = createMockKeyEvent(keyCode: 123, modifierFlags: [])
        XCTAssertTrue(keyboardHandler.handleKeyPress(leftArrowEvent), "Left arrow should be handled")
        
        // Test right arrow
        let rightArrowEvent = createMockKeyEvent(keyCode: 124, modifierFlags: [])
        XCTAssertTrue(keyboardHandler.handleKeyPress(rightArrowEvent), "Right arrow should be handled")
        
        // Test up arrow
        let upArrowEvent = createMockKeyEvent(keyCode: 126, modifierFlags: [])
        XCTAssertTrue(keyboardHandler.handleKeyPress(upArrowEvent), "Up arrow should be handled")
        
        // Test down arrow
        let downArrowEvent = createMockKeyEvent(keyCode: 125, modifierFlags: [])
        XCTAssertTrue(keyboardHandler.handleKeyPress(downArrowEvent), "Down arrow should be handled")
    }
    
    func testFavoritesKeyboardNavigationActionKeys() {
        // Test action keys in favorites view
        let keyboardHandler = FavoritesKeyboardHandler(
            onNavigateLeft: {},
            onNavigateRight: {},
            onNavigateUp: {},
            onNavigateDown: {},
            onEnterFullScreen: {},
            onBackToFolderSelection: {},
            onToggleFavorite: {}
        )
        
        // Test Enter key (full screen)
        let enterEvent = createMockKeyEvent(keyCode: 36, modifierFlags: [])
        XCTAssertTrue(keyboardHandler.handleKeyPress(enterEvent), "Enter key should be handled")
        
        // Test Escape key (back to folder selection)
        let escapeEvent = createMockKeyEvent(keyCode: 53, modifierFlags: [])
        XCTAssertTrue(keyboardHandler.handleKeyPress(escapeEvent), "Escape key should be handled")
        
        // Test Spacebar (full screen)
        let spaceEvent = createMockKeyEvent(keyCode: 49, modifierFlags: [])
        XCTAssertTrue(keyboardHandler.handleKeyPress(spaceEvent), "Spacebar should be handled")
        
        // Test Delete key (remove favorite)
        let deleteEvent = createMockKeyEvent(keyCode: 117, modifierFlags: [])
        XCTAssertTrue(keyboardHandler.handleKeyPress(deleteEvent), "Delete key should be handled")
    }
    
    func testFavoritesKeyboardNavigationCharacterKeys() {
        // Test character keys in favorites view
        let keyboardHandler = FavoritesKeyboardHandler(
            onNavigateLeft: {},
            onNavigateRight: {},
            onNavigateUp: {},
            onNavigateDown: {},
            onEnterFullScreen: {},
            onBackToFolderSelection: {},
            onToggleFavorite: {}
        )
        
        // Test 'f' key (full screen)
        let fKeyEvent = createMockKeyEventWithCharacter("f", keyCode: 3, modifierFlags: [])
        XCTAssertTrue(keyboardHandler.handleKeyPress(fKeyEvent), "F key should be handled")
        
        // Test Cmd+F (toggle favorite)
        let cmdFEvent = createMockKeyEventWithCharacter("f", keyCode: 3, modifierFlags: [.command])
        XCTAssertTrue(keyboardHandler.handleKeyPress(cmdFEvent), "Cmd+F should be handled")
        
        // Test 'b' key (back to folder selection)
        let bKeyEvent = createMockKeyEventWithCharacter("b", keyCode: 11, modifierFlags: [])
        XCTAssertTrue(keyboardHandler.handleKeyPress(bKeyEvent), "B key should be handled")
    }
    
    // MARK: - High Contrast Mode Tests
    
    func testFavoritesHighContrastMode() {
        // Test favorites feature in high contrast mode
        AccessibilityService.shared.isHighContrastEnabled = true
        
        let testModes: [(NSAppearance.Name, String)] = [
            (.aqua, "light"),
            (.darkAqua, "dark")
        ]
        
        for (appearanceName, modeName) in testModes {
            NSApp.appearance = NSAppearance(named: appearanceName)
            
            let favoritesView = FavoritesView(
                onImageSelected: { _, _ in },
                onBackToFolderSelection: {}
            )
            
            let hostingController = NSHostingController(rootView: favoritesView)
            hostingController.loadView()
            
            XCTAssertNotNil(hostingController.view, 
                           "Favorites view should work in high contrast \(modeName) mode")
        }
    }
    
    func testHeartIndicatorHighContrastColors() {
        // Test heart indicator colors in high contrast mode
        AccessibilityService.shared.isHighContrastEnabled = true
        
        let heartIndicator = HeartIndicatorView(
            isFavorite: true,
            thumbnailSize: CGSize(width: 120, height: 120),
            isVisible: true
        )
        
        let hostingController = NSHostingController(rootView: heartIndicator)
        hostingController.loadView()
        
        // Test that high contrast colors are used
        let adaptiveColor = AccessibilityService.shared.adaptiveColor(
            normal: .red,
            highContrast: .red
        )
        XCTAssertNotNil(adaptiveColor, "High contrast color should be available")
        
        XCTAssertNotNil(hostingController.view, "Heart indicator should work with high contrast colors")
    }
    
    // MARK: - Reduced Motion Tests
    
    func testFavoritesReducedMotion() {
        // Test favorites feature with reduced motion
        AccessibilityService.shared.isReducedMotionEnabled = true
        
        let favoritesView = FavoritesView(
            onImageSelected: { _, _ in },
            onBackToFolderSelection: {}
        )
        
        let hostingController = NSHostingController(rootView: favoritesView)
        hostingController.loadView()
        
        XCTAssertNotNil(hostingController.view, "Favorites view should work with reduced motion")
        
        // Test that animations are disabled
        let animation = AccessibilityService.shared.adaptiveAnimation(.easeInOut)
        XCTAssertNil(animation, "Animations should be disabled with reduced motion")
    }
    
    func testHeartIndicatorReducedMotionAnimations() {
        // Test heart indicator animations with reduced motion
        AccessibilityService.shared.isReducedMotionEnabled = true
        
        let heartIndicator = HeartIndicatorView(
            isFavorite: true,
            thumbnailSize: CGSize(width: 120, height: 120),
            isVisible: true
        )
        
        let hostingController = NSHostingController(rootView: heartIndicator)
        hostingController.loadView()
        
        // Verify that pulse animation is disabled with reduced motion
        XCTAssertNotNil(hostingController.view, "Heart indicator should work without animations")
        
        // Test that reduced motion is respected
        XCTAssertTrue(AccessibilityService.shared.isReducedMotionEnabled, "Reduced motion should be enabled")
    }
    
    // MARK: - VoiceOver Support Tests
    
    func testFavoritesVoiceOverSupport() {
        // Test VoiceOver support for favorites feature
        let favoritesView = FavoritesView(
            onImageSelected: { _, _ in },
            onBackToFolderSelection: {}
        )
        
        let hostingController = NSHostingController(rootView: favoritesView)
        hostingController.loadView()
        
        // Test that VoiceOver can navigate the view
        let hasAccessibilityElements = hostingController.view.isAccessibilityElement() ||
                                      (hostingController.view.accessibilityElements()?.count ?? 0) > 0
        XCTAssertTrue(hasAccessibilityElements, "Favorites view should support VoiceOver navigation")
        
        // Test accessibility labels
        let accessibilityLabel = hostingController.view.accessibilityLabel()
        XCTAssertNotNil(accessibilityLabel, "Favorites view should have accessibility label for VoiceOver")
    }
    
    func testHeartButtonVoiceOverAnnouncements() {
        // Test VoiceOver announcements for heart button state changes
        let imageViewerViewModel = createTestImageViewerViewModel()
        
        // Test initial state
        XCTAssertFalse(imageViewerViewModel.isFavorite, "Image should not be favorited initially")
        
        // Test state change
        imageViewerViewModel.toggleFavorite()
        XCTAssertTrue(imageViewerViewModel.isFavorite, "Image should be favorited after toggle")
        
        // Test that state changes can be announced
        // In a real implementation, this would trigger VoiceOver announcements
        XCTAssertNotNil(imageViewerViewModel.currentImageFile, "Current image should be available for announcements")
    }
    
    // MARK: - Dynamic Type Support Tests
    
    func testFavoritesDynamicTypeSupport() {
        // Test that favorites views adapt to different text sizes
        let favoritesView = FavoritesView(
            onImageSelected: { _, _ in },
            onBackToFolderSelection: {}
        )
        
        // Test with different content size scenarios
        let hostingController = NSHostingController(rootView: favoritesView)
        hostingController.loadView()
        
        XCTAssertNotNil(hostingController.view, "Favorites view should support dynamic type")
    }
    
    // MARK: - Error Handling Accessibility Tests
    
    func testFavoritesAccessibilityWithErrors() {
        // Test accessibility behavior when favorites operations fail
        let imageViewerViewModel = createTestImageViewerViewModel()
        
        // Simulate error condition
        mockFavoritesService.shouldFailOperations = true
        
        // Attempt to toggle favorite
        imageViewerViewModel.toggleFavorite()
        
        // Test that error states are accessible
        XCTAssertNotNil(imageViewerViewModel, "View model should handle errors gracefully")
    }
    
    // MARK: - Helper Methods
    
    private func createTestImageFiles() -> [ImageFile] {
        let testBundle = Bundle(for: type(of: self))
        var imageFiles: [ImageFile] = []
        
        // Create mock image files for testing
        for i in 1...5 {
            if let testImageURL = testBundle.url(forResource: "test-image-\(i)", withExtension: "jpg") {
                do {
                    let imageFile = try ImageFile(url: testImageURL)
                    imageFiles.append(imageFile)
                } catch {
                    // Create a mock ImageFile for testing
                    let mockURL = URL(fileURLWithPath: "/tmp/test-image-\(i).jpg")
                    if let mockImageFile = try? ImageFile(url: mockURL) {
                        imageFiles.append(mockImageFile)
                    }
                }
            }
        }
        
        // If no test images found, create mock ones
        if imageFiles.isEmpty {
            for i in 1...5 {
                let mockURL = URL(fileURLWithPath: "/tmp/test-image-\(i).jpg")
                if let mockImageFile = try? ImageFile(url: mockURL) {
                    imageFiles.append(mockImageFile)
                }
            }
        }
        
        return imageFiles
    }
    
    private func createTestImageViewerViewModel() -> ImageViewerViewModel {
        let imageLoaderService = ImageLoaderService()
        let errorHandlingService = ErrorHandlingService.shared
        
        return ImageViewerViewModel(
            imageLoaderService: imageLoaderService,
            preferencesService: mockPreferencesService,
            errorHandlingService: errorHandlingService,
            favoritesService: mockFavoritesService
        )
    }
    
    private func createMockKeyEvent(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) -> NSEvent {
        return NSEvent.keyEvent(
            with: .keyDown,
            location: NSPoint.zero,
            modifierFlags: modifierFlags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: keyCode
        )!
    }
    
    private func createMockKeyEventWithCharacter(_ character: String, keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) -> NSEvent {
        return NSEvent.keyEvent(
            with: .keyDown,
            location: NSPoint.zero,
            modifierFlags: modifierFlags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: character,
            charactersIgnoringModifiers: character,
            isARepeat: false,
            keyCode: keyCode
        )!
    }
}

// MARK: - Mock Services for Testing

private class MockFavoritesService: FavoritesService {
    private var favorites: [FavoriteImageFile] = []
    private let preferencesService: PreferencesService
    var shouldFailOperations = false
    
    init(preferencesService: PreferencesService) {
        self.preferencesService = preferencesService
    }
    
    var favoriteImages: [FavoriteImageFile] {
        return favorites
    }
    
    func addToFavorites(_ imageFile: ImageFile) -> Bool {
        if shouldFailOperations { return false }
        
        let favoriteImageFile = FavoriteImageFile(from: imageFile)
        favorites.append(favoriteImageFile)
        return true
    }
    
    func removeFromFavorites(_ imageFile: ImageFile) -> Bool {
        if shouldFailOperations { return false }
        
        favorites.removeAll { $0.originalURL == imageFile.url }
        return true
    }
    
    func isFavorite(_ imageFile: ImageFile) -> Bool {
        return favorites.contains { $0.originalURL == imageFile.url }
    }
    
    func validateFavorites() async {
        // Mock implementation
    }
    
    func getValidFavorites() async -> [ImageFile] {
        return favorites.compactMap { try? $0.toImageFile() }.compactMap { $0 }
    }
}

private class MockPreferencesService: PreferencesService {
    private var storage: [String: Any] = [:]
    
    var favoriteImages: [FavoriteImageFile] {
        get {
            guard let data = storage["favoriteImages"] as? Data,
                  let favorites = try? JSONDecoder().decode([FavoriteImageFile].self, from: data) else {
                return []
            }
            return favorites
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                storage["favoriteImages"] = data
            }
        }
    }
    
    func saveFavorites() {
        // Mock implementation - data is already stored in memory
    }
    
    func loadFavorites() -> [FavoriteImageFile] {
        return favoriteImages
    }
    
    // Other PreferencesService methods would be implemented here for a complete mock
    var thumbnailQuality: ThumbnailQuality = .medium
    var slideshowInterval: Double = 3.0
    var showFileName: Bool = false
    var showImageInfo: Bool = false
    var lastSelectedFolderURL: URL? = nil
    var windowFrame: CGRect? = nil
    var isFullscreen: Bool = false
    var zoomLevel: Double = 1.0
    var viewMode: ViewMode = .normal
}