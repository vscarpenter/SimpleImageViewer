import XCTest
import AppKit
@testable import Simple_Image_Viewer

/// Unit tests for KeyboardHandler
final class KeyboardHandlerTests: XCTestCase {
    
    var keyboardHandler: KeyboardHandler!
    var mockImageViewerViewModel: MockImageViewerViewModel!
    
    override func setUp() {
        super.setUp()
        mockImageViewerViewModel = MockImageViewerViewModel()
        keyboardHandler = KeyboardHandler(imageViewerViewModel: mockImageViewerViewModel)
    }
    
    override func tearDown() {
        keyboardHandler = nil
        mockImageViewerViewModel = nil
        super.tearDown()
    }
    
    // MARK: - Navigation Tests
    
    func testLeftArrowNavigatesToPreviousImage() {
        // Given
        let event = createKeyEvent(keyCode: 123) // Left arrow
        
        // When
        let handled = keyboardHandler.handleKeyPress(event)
        
        // Then
        XCTAssertTrue(handled)
        XCTAssertTrue(mockImageViewerViewModel.previousImageCalled)
    }
    
    func testRightArrowNavigatesToNextImage() {
        // Given
        let event = createKeyEvent(keyCode: 124) // Right arrow
        
        // When
        let handled = keyboardHandler.handleKeyPress(event)
        
        // Then
        XCTAssertTrue(handled)
        XCTAssertTrue(mockImageViewerViewModel.nextImageCalled)
    }
    
    func testSpacebarNavigatesToNextImage() {
        // Given
        let event = createKeyEvent(keyCode: 49) // Spacebar
        
        // When
        let handled = keyboardHandler.handleKeyPress(event)
        
        // Then
        XCTAssertTrue(handled)
        XCTAssertTrue(mockImageViewerViewModel.nextImageCalled)
    }
    
    func testHomeNavigatesToFirstImage() {
        // Given
        let event = createKeyEvent(keyCode: 115) // Home
        
        // When
        let handled = keyboardHandler.handleKeyPress(event)
        
        // Then
        XCTAssertTrue(handled)
        XCTAssertTrue(mockImageViewerViewModel.goToFirstCalled)
    }
    
    func testEndNavigatesToLastImage() {
        // Given
        let event = createKeyEvent(keyCode: 119) // End
        
        // When
        let handled = keyboardHandler.handleKeyPress(event)
        
        // Then
        XCTAssertTrue(handled)
        XCTAssertTrue(mockImageViewerViewModel.goToLastCalled)
    }
    
    func testPageUpNavigatesToPreviousImage() {
        // Given
        let event = createKeyEvent(keyCode: 116) // Page Up
        
        // When
        let handled = keyboardHandler.handleKeyPress(event)
        
        // Then
        XCTAssertTrue(handled)
        XCTAssertTrue(mockImageViewerViewModel.previousImageCalled)
    }
    
    func testPageDownNavigatesToNextImage() {
        // Given
        let event = createKeyEvent(keyCode: 121) // Page Down
        
        // When
        let handled = keyboardHandler.handleKeyPress(event)
        
        // Then
        XCTAssertTrue(handled)
        XCTAssertTrue(mockImageViewerViewModel.nextImageCalled)
    }
    
    // MARK: - Fullscreen Tests
    
    func testFKeyTogglesFullscreen() {
        // Given
        let event = createKeyEvent(characters: "f")
        
        // When
        let handled = keyboardHandler.handleKeyPress(event)
        
        // Then
        XCTAssertTrue(handled)
        XCTAssertTrue(mockImageViewerViewModel.toggleFullscreenCalled)
    }
    
    func testEnterKeyTogglesFullscreen() {
        // Given
        let event = createKeyEvent(keyCode: 36) // Enter/Return
        
        // When
        let handled = keyboardHandler.handleKeyPress(event)
        
        // Then
        XCTAssertTrue(handled)
        XCTAssertTrue(mockImageViewerViewModel.toggleFullscreenCalled)
    }
    
    func testEscapeExitsFullscreenWhenInFullscreen() {
        // Given
        mockImageViewerViewModel.isFullscreen = true
        let event = createKeyEvent(keyCode: 53) // Escape
        
        // When
        let handled = keyboardHandler.handleKeyPress(event)
        
        // Then
        XCTAssertTrue(handled)
        XCTAssertTrue(mockImageViewerViewModel.exitFullscreenCalled)
    }
    
    func testEscapeDoesNotHandleWhenNotInFullscreen() {
        // Given
        mockImageViewerViewModel.isFullscreen = false
        let event = createKeyEvent(keyCode: 53) // Escape
        
        // When
        let handled = keyboardHandler.handleKeyPress(event)
        
        // Then
        XCTAssertFalse(handled)
        XCTAssertFalse(mockImageViewerViewModel.exitFullscreenCalled)
    }
    
    // MARK: - Zoom Tests
    
    func testPlusKeyZoomsIn() {
        // Given
        let event = createKeyEvent(characters: "+")
        
        // When
        let handled = keyboardHandler.handleKeyPress(event)
        
        // Then
        XCTAssertTrue(handled)
        XCTAssertTrue(mockImageViewerViewModel.zoomInCalled)
    }
    
    func testEqualsKeyZoomsIn() {
        // Given
        let event = createKeyEvent(characters: "=")
        
        // When
        let handled = keyboardHandler.handleKeyPress(event)
        
        // Then
        XCTAssertTrue(handled)
        XCTAssertTrue(mockImageViewerViewModel.zoomInCalled)
    }
    
    func testMinusKeyZoomsOut() {
        // Given
        let event = createKeyEvent(characters: "-")
        
        // When
        let handled = keyboardHandler.handleKeyPress(event)
        
        // Then
        XCTAssertTrue(handled)
        XCTAssertTrue(mockImageViewerViewModel.zoomOutCalled)
    }
    
    func testZeroKeyZoomsToFit() {
        // Given
        let event = createKeyEvent(characters: "0")
        
        // When
        let handled = keyboardHandler.handleKeyPress(event)
        
        // Then
        XCTAssertTrue(handled)
        XCTAssertTrue(mockImageViewerViewModel.zoomToFitCalled)
    }
    
    func testOneKeyZoomsToActualSize() {
        // Given
        let event = createKeyEvent(characters: "1")
        
        // When
        let handled = keyboardHandler.handleKeyPress(event)
        
        // Then
        XCTAssertTrue(handled)
        XCTAssertTrue(mockImageViewerViewModel.zoomToActualSizeCalled)
    }
    
    // MARK: - Edge Cases
    
    func testHandleKeyPressWithoutViewModelReturnsFalse() {
        // Given
        let keyboardHandlerWithoutViewModel = KeyboardHandler()
        let event = createKeyEvent(keyCode: 124) // Right arrow
        
        // When
        let handled = keyboardHandlerWithoutViewModel.handleKeyPress(event)
        
        // Then
        XCTAssertFalse(handled)
    }
    
    func testUnknownKeyReturnsFalse() {
        // Given
        let event = createKeyEvent(characters: "x")
        
        // When
        let handled = keyboardHandler.handleKeyPress(event)
        
        // Then
        XCTAssertFalse(handled)
    }
    
    func testSetImageViewerViewModel() {
        // Given
        let newKeyboardHandler = KeyboardHandler()
        let newMockViewModel = MockImageViewerViewModel()
        
        // When
        newKeyboardHandler.setImageViewerViewModel(newMockViewModel)
        let event = createKeyEvent(keyCode: 124) // Right arrow
        let handled = newKeyboardHandler.handleKeyPress(event)
        
        // Then
        XCTAssertTrue(handled)
        XCTAssertTrue(newMockViewModel.nextImageCalled)
    }
    
    // MARK: - Keyboard Shortcuts Documentation
    
    func testGetKeyboardShortcuts() {
        // When
        let shortcuts = KeyboardHandler.getKeyboardShortcuts()
        
        // Then
        XCTAssertFalse(shortcuts.isEmpty)
        XCTAssertEqual(shortcuts["← / →"], "Navigate between images")
        XCTAssertEqual(shortcuts["Spacebar"], "Next image")
        XCTAssertEqual(shortcuts["Page Up/Down"], "Navigate between images")
        XCTAssertEqual(shortcuts["Home"], "Go to first image")
        XCTAssertEqual(shortcuts["End"], "Go to last image")
        XCTAssertEqual(shortcuts["F / Enter"], "Toggle fullscreen")
        XCTAssertEqual(shortcuts["Escape"], "Exit fullscreen")
        XCTAssertEqual(shortcuts["+ / ="], "Zoom in")
        XCTAssertEqual(shortcuts["-"], "Zoom out")
        XCTAssertEqual(shortcuts["0"], "Fit to window")
        XCTAssertEqual(shortcuts["1"], "Actual size (100%)")
    }
    
    func testGetFormattedKeyboardShortcuts() {
        // When
        let formattedShortcuts = KeyboardHandler.getFormattedKeyboardShortcuts()
        
        // Then
        XCTAssertFalse(formattedShortcuts.isEmpty)
        XCTAssertEqual(formattedShortcuts.count, 11)
        
        // Check that all shortcuts are properly formatted
        for shortcut in formattedShortcuts {
            XCTAssertTrue(shortcut.contains(":"))
        }
        
        // Check that they're sorted
        let sortedShortcuts = formattedShortcuts.sorted()
        XCTAssertEqual(formattedShortcuts, sortedShortcuts)
    }
    
    // MARK: - Helper Methods
    
    private func createKeyEvent(keyCode: UInt16 = 0, characters: String? = nil) -> NSEvent {
        return NSEvent.keyEvent(
            with: .keyDown,
            location: NSPoint.zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters ?? "",
            charactersIgnoringModifiers: characters ?? "",
            isARepeat: false,
            keyCode: keyCode
        )!
    }
}

// MARK: - Mock ImageViewerViewModel

class MockImageViewerViewModel: ImageViewerViewModel {
    var nextImageCalled = false
    var previousImageCalled = false
    var goToFirstCalled = false
    var goToLastCalled = false
    var toggleFullscreenCalled = false
    var exitFullscreenCalled = false
    var zoomInCalled = false
    var zoomOutCalled = false
    var zoomToFitCalled = false
    var zoomToActualSizeCalled = false
    
    override func nextImage() {
        nextImageCalled = true
    }
    
    override func previousImage() {
        previousImageCalled = true
    }
    
    override func goToFirst() {
        goToFirstCalled = true
    }
    
    override func goToLast() {
        goToLastCalled = true
    }
    
    override func toggleFullscreen() {
        toggleFullscreenCalled = true
    }
    
    override func exitFullscreen() {
        exitFullscreenCalled = true
    }
    
    override func zoomIn() {
        zoomInCalled = true
    }
    
    override func zoomOut() {
        zoomOutCalled = true
    }
    
    override func zoomToFit() {
        zoomToFitCalled = true
    }
    
    override func zoomToActualSize() {
        zoomToActualSizeCalled = true
    }
}    // 
MARK: - Integration Tests
    
    func testKeyboardHandlerIntegrationWithRealViewModel() {
        // Given
        let realViewModel = ImageViewerViewModel()
        let keyboardHandler = KeyboardHandler(imageViewerViewModel: realViewModel)
        
        // When - Test navigation without loaded content (should still handle the key)
        let rightArrowEvent = createKeyEvent(keyCode: 124) // Right arrow
        let handled = keyboardHandler.handleKeyPress(rightArrowEvent)
        
        // Then
        XCTAssertTrue(handled)
        // The key should be handled even if no images are loaded
    }
    
    func testKeyboardHandlerWithMultipleCharactersInEvent() {
        // Given
        let event = createKeyEvent(characters: "f1") // Multiple characters
        
        // When
        let handled = keyboardHandler.handleKeyPress(event)
        
        // Then
        XCTAssertTrue(handled) // Should handle the 'f' and toggle fullscreen
        XCTAssertTrue(mockImageViewerViewModel.toggleFullscreenCalled)
    }
    
    func testKeyboardHandlerWithEmptyCharacters() {
        // Given
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: NSPoint.zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: nil,
            isARepeat: false,
            keyCode: 999 // Unknown key code
        )!
        
        // When
        let handled = keyboardHandler.handleKeyPress(event)
        
        // Then
        XCTAssertFalse(handled)
    }