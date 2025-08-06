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
        let imageActions: [ContextMenuAction] = [.copyImage, .copyPath, .share, .revealInFinder, .moveToTrash]
        
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
    }
}

// MARK: - Mock Classes for Testing

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