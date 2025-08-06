import XCTest
import SwiftUI
@testable import StillView___Simple_Image_Viewer

class ContextMenuProviderTests: XCTestCase {
    
    var mockImageFile: ImageFile!
    var mockViewModel: ImageViewerViewModel!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create a mock image file for testing
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-context-menu.jpg")
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
        mockViewModel = ImageViewerViewModel()
    }
    
    override func tearDownWithError() throws {
        mockImageFile = nil
        mockViewModel = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Context Menu Type Tests
    
    func testContextMenuTypes() throws {
        // Test that all context menu types are properly defined
        let imageType = ContextMenuType.image
        let thumbnailType = ContextMenuType.thumbnail
        let emptyAreaType = ContextMenuType.emptyArea
        
        XCTAssertNotNil(imageType)
        XCTAssertNotNil(thumbnailType)
        XCTAssertNotNil(emptyAreaType)
    }
    
    // MARK: - Context Menu Action Tests
    
    func testContextMenuActionProperties() throws {
        // Test that all context menu actions have proper properties
        for action in ContextMenuAction.allCases {
            XCTAssertFalse(action.title.isEmpty, "Action \(action) should have a non-empty title")
            XCTAssertFalse(action.icon.isEmpty, "Action \(action) should have a non-empty icon")
            
            // Test that the icon is a valid SF Symbol name (basic check)
            XCTAssertTrue(action.icon.contains(".") || action.icon.isValidSFSymbol, 
                         "Action \(action) should have a valid SF Symbol icon")
        }
    }
    
    func testDestructiveActions() throws {
        // Test that only appropriate actions are marked as destructive
        let destructiveActions = ContextMenuAction.allCases.filter { $0.isDestructive }
        
        XCTAssertEqual(destructiveActions.count, 1, "Only one action should be destructive")
        XCTAssertTrue(destructiveActions.contains(.moveToTrash), "Move to trash should be destructive")
    }
    
    func testKeyboardShortcuts() throws {
        // Test that important actions have keyboard shortcuts
        let actionsWithShortcuts = ContextMenuAction.allCases.filter { $0.keyboardShortcut != nil }
        
        XCTAssertTrue(actionsWithShortcuts.contains(.copyImage), "Copy image should have keyboard shortcut")
        XCTAssertTrue(actionsWithShortcuts.contains(.revealInFinder), "Reveal in Finder should have keyboard shortcut")
        XCTAssertTrue(actionsWithShortcuts.contains(.selectFolder), "Select folder should have keyboard shortcut")
        XCTAssertTrue(actionsWithShortcuts.contains(.moveToTrash), "Move to trash should have keyboard shortcut")
        
        // Test specific shortcuts
        XCTAssertEqual(ContextMenuAction.copyImage.keyboardShortcut, "c")
        XCTAssertEqual(ContextMenuAction.revealInFinder.keyboardShortcut, "r")
        XCTAssertEqual(ContextMenuAction.selectFolder.keyboardShortcut, "o")
        XCTAssertEqual(ContextMenuAction.moveToTrash.keyboardShortcut, KeyEquivalent(.delete))
    }
    
    func testKeyboardModifiers() throws {
        // Test keyboard modifiers for actions
        XCTAssertEqual(ContextMenuAction.copyImage.keyboardModifiers, .command)
        XCTAssertEqual(ContextMenuAction.revealInFinder.keyboardModifiers, [.command, .shift])
        XCTAssertEqual(ContextMenuAction.selectFolder.keyboardModifiers, .command)
        XCTAssertEqual(ContextMenuAction.moveToTrash.keyboardModifiers, [])
    }
    
    // MARK: - View Extension Tests
    
    func testViewExtensions() throws {
        // Test that view extensions compile and can be used
        let testView = Rectangle()
            .imageContextMenu(for: mockImageFile, viewModel: mockViewModel)
        
        XCTAssertNotNil(testView)
        
        let thumbnailView = Rectangle()
            .thumbnailContextMenu(for: mockImageFile, at: 0, viewModel: mockViewModel)
        
        XCTAssertNotNil(thumbnailView)
        
        let emptyAreaView = Rectangle()
            .emptyAreaContextMenu(viewModel: mockViewModel)
        
        XCTAssertNotNil(emptyAreaView)
    }
    
    // MARK: - Context Menu Provider Tests
    
    func testImageContextMenuProvider() throws {
        // Test that image context menu can be created
        let contextMenu = ContextMenuProvider.imageContextMenu(
            for: mockImageFile,
            viewModel: mockViewModel,
            sourceView: nil
        )
        
        XCTAssertNotNil(contextMenu)
    }
    
    func testThumbnailContextMenuProvider() throws {
        // Test that thumbnail context menu can be created
        let contextMenu = ContextMenuProvider.thumbnailContextMenu(
            for: mockImageFile,
            at: 0,
            viewModel: mockViewModel
        )
        
        XCTAssertNotNil(contextMenu)
    }
    
    func testEmptyAreaContextMenuProvider() throws {
        // Test that empty area context menu can be created
        let contextMenu = ContextMenuProvider.emptyAreaContextMenu(viewModel: mockViewModel)
        
        XCTAssertNotNil(contextMenu)
    }
    
    // MARK: - Integration Tests
    
    func testContextMenuModifier() throws {
        // Test that context menu modifier can be applied
        let modifier = ContextMenuModifier(
            menuType: .image,
            imageFile: mockImageFile,
            index: nil,
            viewModel: mockViewModel,
            sourceView: nil
        )
        
        XCTAssertNotNil(modifier)
        XCTAssertEqual(modifier.menuType, .image)
        XCTAssertEqual(modifier.imageFile?.url, mockImageFile.url)
        XCTAssertNil(modifier.index)
    }
    
    func testThumbnailContextMenuModifier() throws {
        // Test thumbnail-specific modifier
        let modifier = ContextMenuModifier(
            menuType: .thumbnail,
            imageFile: mockImageFile,
            index: 5,
            viewModel: mockViewModel,
            sourceView: nil
        )
        
        XCTAssertEqual(modifier.menuType, .thumbnail)
        XCTAssertEqual(modifier.index, 5)
    }
    
    func testEmptyAreaContextMenuModifier() throws {
        // Test empty area-specific modifier
        let modifier = ContextMenuModifier(
            menuType: .emptyArea,
            imageFile: nil,
            index: nil,
            viewModel: mockViewModel,
            sourceView: nil
        )
        
        XCTAssertEqual(modifier.menuType, .emptyArea)
        XCTAssertNil(modifier.imageFile)
        XCTAssertNil(modifier.index)
    }
    
    // MARK: - Accessibility Tests
    
    func testContextMenuAccessibility() throws {
        // Test that context menu actions have proper accessibility labels
        for action in ContextMenuAction.allCases {
            let title = action.title
            XCTAssertFalse(title.isEmpty, "Action \(action) should have accessibility-friendly title")
            
            // Test that titles don't contain technical jargon that would confuse screen readers
            XCTAssertFalse(title.contains("...") && title.hasSuffix("..."), 
                          "Action \(action) title should not end with ellipsis for accessibility")
        }
    }
}

// MARK: - Helper Extensions

extension String {
    /// Basic check if string could be a valid SF Symbol name
    var isValidSFSymbol: Bool {
        // Basic validation - SF Symbols typically contain letters, numbers, dots, and underscores
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._"))
        return !isEmpty && rangeOfCharacter(from: allowedCharacters.inverted) == nil
    }
}

// MARK: - Mock Classes

class MockNSView: NSView {
    override var bounds: NSRect {
        return NSRect(x: 0, y: 0, width: 100, height: 100)
    }
}