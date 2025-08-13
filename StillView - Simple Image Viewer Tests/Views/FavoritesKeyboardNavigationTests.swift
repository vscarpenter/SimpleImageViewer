//
//  FavoritesKeyboardNavigationTests.swift
//  Simple Image Viewer Tests
//
//  Created by Kiro on 8/12/25.
//

import XCTest
import SwiftUI
import AppKit
@testable import Simple_Image_Viewer

@MainActor
final class FavoritesKeyboardNavigationTests: XCTestCase {
    
    // MARK: - Test Setup
    
    private var testImageFiles: [ImageFile] = []
    private var mockFavoritesService: MockFavoritesService!
    private var mockPreferencesService: MockPreferencesService!
    private var keyboardHandler: FavoritesKeyboardHandler!
    
    // Navigation tracking
    private var navigationCallbacks: NavigationCallbacks!
    
    override func setUp() {
        super.setUp()
        
        // Create test image files
        testImageFiles = createTestImageFiles()
        
        // Create mock services
        mockPreferencesService = MockPreferencesService()
        mockFavoritesService = MockFavoritesService(preferencesService: mockPreferencesService)
        
        // Create navigation callbacks tracker
        navigationCallbacks = NavigationCallbacks()
        
        // Create keyboard handler with tracked callbacks
        keyboardHandler = FavoritesKeyboardHandler(
            onNavigateLeft: navigationCallbacks.navigateLeft,
            onNavigateRight: navigationCallbacks.navigateRight,
            onNavigateUp: navigationCallbacks.navigateUp,
            onNavigateDown: navigationCallbacks.navigateDown,
            onEnterFullScreen: navigationCallbacks.enterFullScreen,
            onBackToFolderSelection: navigationCallbacks.backToFolderSelection,
            onToggleFavorite: navigationCallbacks.toggleFavorite
        )
        
        continueAfterFailure = false
    }
    
    override func tearDown() {
        keyboardHandler = nil
        navigationCallbacks = nil
        mockFavoritesService = nil
        mockPreferencesService = nil
        testImageFiles = []
        super.tearDown()
    }
    
    // MARK: - Arrow Key Navigation Tests
    
    func testLeftArrowKeyNavigation() {
        // Test left arrow key navigation
        let leftArrowEvent = createMockKeyEvent(keyCode: 123, modifierFlags: [])
        
        let handled = keyboardHandler.handleKeyPress(leftArrowEvent)
        
        XCTAssertTrue(handled, "Left arrow key should be handled")
        XCTAssertTrue(navigationCallbacks.navigateLeftCalled, "Navigate left callback should be called")
        XCTAssertEqual(navigationCallbacks.navigateLeftCallCount, 1, "Navigate left should be called once")
    }
    
    func testRightArrowKeyNavigation() {
        // Test right arrow key navigation
        let rightArrowEvent = createMockKeyEvent(keyCode: 124, modifierFlags: [])
        
        let handled = keyboardHandler.handleKeyPress(rightArrowEvent)
        
        XCTAssertTrue(handled, "Right arrow key should be handled")
        XCTAssertTrue(navigationCallbacks.navigateRightCalled, "Navigate right callback should be called")
        XCTAssertEqual(navigationCallbacks.navigateRightCallCount, 1, "Navigate right should be called once")
    }
    
    func testUpArrowKeyNavigation() {
        // Test up arrow key navigation
        let upArrowEvent = createMockKeyEvent(keyCode: 126, modifierFlags: [])
        
        let handled = keyboardHandler.handleKeyPress(upArrowEvent)
        
        XCTAssertTrue(handled, "Up arrow key should be handled")
        XCTAssertTrue(navigationCallbacks.navigateUpCalled, "Navigate up callback should be called")
        XCTAssertEqual(navigationCallbacks.navigateUpCallCount, 1, "Navigate up should be called once")
    }
    
    func testDownArrowKeyNavigation() {
        // Test down arrow key navigation
        let downArrowEvent = createMockKeyEvent(keyCode: 125, modifierFlags: [])
        
        let handled = keyboardHandler.handleKeyPress(downArrowEvent)
        
        XCTAssertTrue(handled, "Down arrow key should be handled")
        XCTAssertTrue(navigationCallbacks.navigateDownCalled, "Navigate down callback should be called")
        XCTAssertEqual(navigationCallbacks.navigateDownCallCount, 1, "Navigate down should be called once")
    }
    
    func testArrowKeySequence() {
        // Test sequence of arrow key presses
        let keys = [
            (123, "left"),   // Left
            (124, "right"),  // Right  
            (126, "up"),     // Up
            (125, "down")    // Down
        ]
        
        for (keyCode, direction) in keys {
            let event = createMockKeyEvent(keyCode: UInt16(keyCode), modifierFlags: [])
            let handled = keyboardHandler.handleKeyPress(event)
            XCTAssertTrue(handled, "\(direction.capitalized) arrow key should be handled")
        }
        
        // Verify all navigation methods were called
        XCTAssertEqual(navigationCallbacks.navigateLeftCallCount, 1, "Left navigation should be called once")
        XCTAssertEqual(navigationCallbacks.navigateRightCallCount, 1, "Right navigation should be called once")
        XCTAssertEqual(navigationCallbacks.navigateUpCallCount, 1, "Up navigation should be called once")
        XCTAssertEqual(navigationCallbacks.navigateDownCallCount, 1, "Down navigation should be called once")
    }
    
    // MARK: - Action Key Tests
    
    func testEnterKeyFullScreen() {
        // Test Enter key for full screen
        let enterEvent = createMockKeyEvent(keyCode: 36, modifierFlags: [])
        
        let handled = keyboardHandler.handleKeyPress(enterEvent)
        
        XCTAssertTrue(handled, "Enter key should be handled")
        XCTAssertTrue(navigationCallbacks.enterFullScreenCalled, "Enter full screen callback should be called")
        XCTAssertEqual(navigationCallbacks.enterFullScreenCallCount, 1, "Enter full screen should be called once")
    }
    
    func testSpacebarFullScreen() {
        // Test Spacebar for full screen
        let spaceEvent = createMockKeyEvent(keyCode: 49, modifierFlags: [])
        
        let handled = keyboardHandler.handleKeyPress(spaceEvent)
        
        XCTAssertTrue(handled, "Spacebar should be handled")
        XCTAssertTrue(navigationCallbacks.enterFullScreenCalled, "Enter full screen callback should be called")
        XCTAssertEqual(navigationCallbacks.enterFullScreenCallCount, 1, "Enter full screen should be called once")
    }
    
    func testEscapeKeyBackToFolderSelection() {
        // Test Escape key for back to folder selection
        let escapeEvent = createMockKeyEvent(keyCode: 53, modifierFlags: [])
        
        let handled = keyboardHandler.handleKeyPress(escapeEvent)
        
        XCTAssertTrue(handled, "Escape key should be handled")
        XCTAssertTrue(navigationCallbacks.backToFolderSelectionCalled, "Back to folder selection callback should be called")
        XCTAssertEqual(navigationCallbacks.backToFolderSelectionCallCount, 1, "Back to folder selection should be called once")
    }
    
    func testDeleteKeyRemoveFavorite() {
        // Test Delete key for removing favorite
        let deleteEvent = createMockKeyEvent(keyCode: 117, modifierFlags: [])
        
        let handled = keyboardHandler.handleKeyPress(deleteEvent)
        
        XCTAssertTrue(handled, "Delete key should be handled")
        XCTAssertTrue(navigationCallbacks.toggleFavoriteCalled, "Toggle favorite callback should be called")
        XCTAssertEqual(navigationCallbacks.toggleFavoriteCallCount, 1, "Toggle favorite should be called once")
    }
    
    // MARK: - Character Key Tests
    
    func testFKeyFullScreen() {
        // Test 'f' key for full screen
        let fKeyEvent = createMockKeyEventWithCharacter("f", keyCode: 3, modifierFlags: [])
        
        let handled = keyboardHandler.handleKeyPress(fKeyEvent)
        
        XCTAssertTrue(handled, "F key should be handled")
        XCTAssertTrue(navigationCallbacks.enterFullScreenCalled, "Enter full screen callback should be called")
        XCTAssertEqual(navigationCallbacks.enterFullScreenCallCount, 1, "Enter full screen should be called once")
    }
    
    func testCommandFToggleFavorite() {
        // Test Cmd+F for toggle favorite
        let cmdFEvent = createMockKeyEventWithCharacter("f", keyCode: 3, modifierFlags: [.command])
        
        let handled = keyboardHandler.handleKeyPress(cmdFEvent)
        
        XCTAssertTrue(handled, "Cmd+F should be handled")
        XCTAssertTrue(navigationCallbacks.toggleFavoriteCalled, "Toggle favorite callback should be called")
        XCTAssertEqual(navigationCallbacks.toggleFavoriteCallCount, 1, "Toggle favorite should be called once")
    }
    
    func testBKeyBackToFolderSelection() {
        // Test 'b' key for back to folder selection
        let bKeyEvent = createMockKeyEventWithCharacter("b", keyCode: 11, modifierFlags: [])
        
        let handled = keyboardHandler.handleKeyPress(bKeyEvent)
        
        XCTAssertTrue(handled, "B key should be handled")
        XCTAssertTrue(navigationCallbacks.backToFolderSelectionCalled, "Back to folder selection callback should be called")
        XCTAssertEqual(navigationCallbacks.backToFolderSelectionCallCount, 1, "Back to folder selection should be called once")
    }
    
    // MARK: - Modifier Key Combination Tests
    
    func testModifierKeyHandling() {
        // Test that modifier keys are properly handled
        let testCases: [(String, UInt16, NSEvent.ModifierFlags, Bool)] = [
            ("f", 3, [], true),           // F key alone
            ("f", 3, [.command], true),   // Cmd+F
            ("f", 3, [.shift], true),     // Shift+F (should still work as F)
            ("f", 3, [.option], true),    // Option+F (should still work as F)
            ("b", 11, [], true),          // B key alone
            ("b", 11, [.command], false), // Cmd+B (should not be handled)
        ]
        
        for (character, keyCode, modifiers, shouldHandle) in testCases {
            navigationCallbacks.reset()
            
            let event = createMockKeyEventWithCharacter(character, keyCode: keyCode, modifierFlags: modifiers)
            let handled = keyboardHandler.handleKeyPress(event)
            
            XCTAssertEqual(handled, shouldHandle, 
                          "\(character) with modifiers \(modifiers) should \(shouldHandle ? "be" : "not be") handled")
        }
    }
    
    // MARK: - Unhandled Key Tests
    
    func testUnhandledKeys() {
        // Test that unhandled keys return false
        let unhandledKeys: [(String, UInt16)] = [
            ("x", 7),   // X key
            ("z", 6),   // Z key
            ("1", 18),  // 1 key
            ("2", 19),  // 2 key
        ]
        
        for (character, keyCode) in unhandledKeys {
            let event = createMockKeyEventWithCharacter(character, keyCode: keyCode, modifierFlags: [])
            let handled = keyboardHandler.handleKeyPress(event)
            
            XCTAssertFalse(handled, "\(character) key should not be handled")
        }
        
        // Verify no callbacks were triggered
        XCTAssertFalse(navigationCallbacks.anyCallbackCalled, "No callbacks should be called for unhandled keys")
    }
    
    // MARK: - Accessibility Announcement Tests
    
    func testNavigationAnnouncements() {
        // Test that navigation changes trigger accessibility announcements
        // Note: In a real implementation, this would test actual accessibility notifications
        
        let arrowKeys = [
            (123, "left"),
            (124, "right"),
            (126, "up"),
            (125, "down")
        ]
        
        for (keyCode, direction) in arrowKeys {
            let event = createMockKeyEvent(keyCode: UInt16(keyCode), modifierFlags: [])
            let handled = keyboardHandler.handleKeyPress(event)
            
            XCTAssertTrue(handled, "\(direction.capitalized) arrow should be handled")
            // In a real implementation, we would verify that NSAccessibility.post was called
        }
    }
    
    func testActionAnnouncements() {
        // Test that actions trigger accessibility announcements
        let actionKeys = [
            (36, "enter"),    // Enter
            (49, "space"),    // Space
            (53, "escape"),   // Escape
            (117, "delete")   // Delete
        ]
        
        for (keyCode, action) in actionKeys {
            navigationCallbacks.reset()
            
            let event = createMockKeyEvent(keyCode: UInt16(keyCode), modifierFlags: [])
            let handled = keyboardHandler.handleKeyPress(event)
            
            XCTAssertTrue(handled, "\(action.capitalized) key should be handled")
            // In a real implementation, we would verify that accessibility announcements were made
        }
    }
    
    // MARK: - Rapid Key Press Tests
    
    func testRapidKeyPresses() {
        // Test handling of rapid key presses
        let rapidPresses = 10
        
        for _ in 0..<rapidPresses {
            let rightArrowEvent = createMockKeyEvent(keyCode: 124, modifierFlags: [])
            let handled = keyboardHandler.handleKeyPress(rightArrowEvent)
            XCTAssertTrue(handled, "Rapid key presses should be handled")
        }
        
        XCTAssertEqual(navigationCallbacks.navigateRightCallCount, rapidPresses, 
                      "All rapid key presses should be processed")
    }
    
    // MARK: - Key Repeat Tests
    
    func testKeyRepeatHandling() {
        // Test that key repeats are handled properly
        let repeatEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: NSPoint.zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: true,  // This is a repeat event
            keyCode: 124      // Right arrow
        )!
        
        let handled = keyboardHandler.handleKeyPress(repeatEvent)
        
        XCTAssertTrue(handled, "Key repeat should be handled")
        XCTAssertTrue(navigationCallbacks.navigateRightCalled, "Navigate right should be called for repeat")
    }
    
    // MARK: - Integration Tests
    
    func testKeyboardNavigationIntegration() {
        // Test keyboard navigation integration with FavoritesView
        let favoritesView = FavoritesView(
            onImageSelected: { _, _ in },
            onBackToFolderSelection: {}
        )
        
        let hostingController = NSHostingController(rootView: favoritesView)
        hostingController.loadView()
        
        // Test that the view can become first responder
        let canBecomeFirstResponder = hostingController.view.acceptsFirstResponder
        XCTAssertTrue(canBecomeFirstResponder, "Favorites view should accept first responder for keyboard navigation")
        
        // Test focus management
        let canReceiveFocus = hostingController.view.canBecomeKeyView
        XCTAssertTrue(canReceiveFocus, "Favorites view should be able to receive keyboard focus")
    }
    
    // MARK: - Helper Methods
    
    private func createTestImageFiles() -> [ImageFile] {
        var imageFiles: [ImageFile] = []
        
        // Create mock image files for testing
        for i in 1...5 {
            let mockURL = URL(fileURLWithPath: "/tmp/test-image-\(i).jpg")
            if let mockImageFile = try? ImageFile(url: mockURL) {
                imageFiles.append(mockImageFile)
            }
        }
        
        return imageFiles
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

// MARK: - Navigation Callbacks Tracker

private class NavigationCallbacks {
    var navigateLeftCalled = false
    var navigateRightCalled = false
    var navigateUpCalled = false
    var navigateDownCalled = false
    var enterFullScreenCalled = false
    var backToFolderSelectionCalled = false
    var toggleFavoriteCalled = false
    
    var navigateLeftCallCount = 0
    var navigateRightCallCount = 0
    var navigateUpCallCount = 0
    var navigateDownCallCount = 0
    var enterFullScreenCallCount = 0
    var backToFolderSelectionCallCount = 0
    var toggleFavoriteCallCount = 0
    
    var anyCallbackCalled: Bool {
        return navigateLeftCalled || navigateRightCalled || navigateUpCalled || 
               navigateDownCalled || enterFullScreenCalled || backToFolderSelectionCalled || 
               toggleFavoriteCalled
    }
    
    func navigateLeft() {
        navigateLeftCalled = true
        navigateLeftCallCount += 1
    }
    
    func navigateRight() {
        navigateRightCalled = true
        navigateRightCallCount += 1
    }
    
    func navigateUp() {
        navigateUpCalled = true
        navigateUpCallCount += 1
    }
    
    func navigateDown() {
        navigateDownCalled = true
        navigateDownCallCount += 1
    }
    
    func enterFullScreen() {
        enterFullScreenCalled = true
        enterFullScreenCallCount += 1
    }
    
    func backToFolderSelection() {
        backToFolderSelectionCalled = true
        backToFolderSelectionCallCount += 1
    }
    
    func toggleFavorite() {
        toggleFavoriteCalled = true
        toggleFavoriteCallCount += 1
    }
    
    func reset() {
        navigateLeftCalled = false
        navigateRightCalled = false
        navigateUpCalled = false
        navigateDownCalled = false
        enterFullScreenCalled = false
        backToFolderSelectionCalled = false
        toggleFavoriteCalled = false
        
        navigateLeftCallCount = 0
        navigateRightCallCount = 0
        navigateUpCallCount = 0
        navigateDownCallCount = 0
        enterFullScreenCallCount = 0
        backToFolderSelectionCallCount = 0
        toggleFavoriteCallCount = 0
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