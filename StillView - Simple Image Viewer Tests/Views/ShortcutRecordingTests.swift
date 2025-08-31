import XCTest
import SwiftUI
@testable import StillView___Simple_Image_Viewer

class ShortcutRecordingTests: XCTestCase {
    
    var viewModel: ShortcutsViewModel!
    var mockShortcutManager: MockShortcutManager!
    var mockValidator: MockShortcutValidator!
    
    override func setUp() {
        super.setUp()
        mockShortcutManager = MockShortcutManager()
        mockValidator = MockShortcutValidator()
        viewModel = ShortcutsViewModel(
            shortcutManager: mockShortcutManager,
            validator: mockValidator
        )
    }
    
    override func tearDown() {
        viewModel = nil
        mockValidator = nil
        mockShortcutManager = nil
        super.tearDown()
    }
    
    // MARK: - Shortcut Recording Tests
    
    func testShortcutRecordingInterface() {
        let shortcutId = "next_image"
        let originalShortcut = mockShortcutManager.getShortcut(for: shortcutId)?.currentShortcut
        
        XCTAssertNotNil(originalShortcut)
        
        // Simulate starting recording
        let newShortcut = KeyboardShortcut(key: "j", modifiers: [])
        viewModel.updateShortcut(shortcutId, to: newShortcut)
        
        // Verify the shortcut was updated
        let updatedShortcut = mockShortcutManager.getShortcut(for: shortcutId)?.currentShortcut
        XCTAssertEqual(updatedShortcut?.key, "j")
        XCTAssertTrue(updatedShortcut?.modifiers.isEmpty ?? false)
    }
    
    func testShortcutRecordingWithModifiers() {
        let shortcutId = "zoom_in"
        let newShortcut = KeyboardShortcut(key: "=", modifiers: [.command, .shift])
        
        viewModel.updateShortcut(shortcutId, to: newShortcut)
        
        let updatedShortcut = mockShortcutManager.getShortcut(for: shortcutId)?.currentShortcut
        XCTAssertEqual(updatedShortcut?.key, "=")
        XCTAssertTrue(updatedShortcut?.modifiers.contains(.command) ?? false)
        XCTAssertTrue(updatedShortcut?.modifiers.contains(.shift) ?? false)
    }
    
    func testInvalidShortcutRecording() {
        let shortcutId = "next_image"
        
        // Set up validator to return error for this shortcut
        mockValidator.validationResults[shortcutId] = .error("Invalid shortcut")
        
        let newShortcut = KeyboardShortcut(key: "invalid", modifiers: [])
        viewModel.updateShortcut(shortcutId, to: newShortcut)
        
        // Verify validation error is present
        let validationResult = viewModel.getValidationResult(for: shortcutId)
        XCTAssertNotNil(validationResult)
        XCTAssertFalse(validationResult?.isValid ?? true)
        XCTAssertEqual(validationResult?.severity, .error)
    }
    
    // MARK: - Conflict Detection Tests
    
    func testShortcutConflictDetection() {
        let shortcutId1 = "next_image"
        let shortcutId2 = "previous_image"
        
        // Set up a conflict
        mockValidator.conflictingShortcuts[shortcutId1] = shortcutId2
        
        let hasConflicts = viewModel.hasConflicts(shortcutId1)
        XCTAssertTrue(hasConflicts)
        
        let validationResult = viewModel.getValidationResult(for: shortcutId1)
        XCTAssertNotNil(validationResult)
        XCTAssertEqual(validationResult?.severity, .error)
        XCTAssertTrue(validationResult?.message?.contains("conflicts") ?? false)
    }
    
    func testSystemShortcutConflict() {
        let shortcutId = "save_image"
        
        // Set up system conflict
        mockValidator.systemConflicts[shortcutId] = true
        
        let validationResult = viewModel.getValidationResult(for: shortcutId)
        XCTAssertNotNil(validationResult)
        XCTAssertEqual(validationResult?.severity, .error)
        XCTAssertTrue(validationResult?.message?.contains("system shortcut") ?? false)
    }
    
    func testConflictResolution() {
        let shortcutId1 = "next_image"
        let shortcutId2 = "previous_image"
        
        // Create initial conflict
        mockValidator.conflictingShortcuts[shortcutId1] = shortcutId2
        XCTAssertTrue(viewModel.hasConflicts(shortcutId1))
        
        // Resolve conflict by changing shortcut
        mockValidator.conflictingShortcuts.removeValue(forKey: shortcutId1)
        let newShortcut = KeyboardShortcut(key: "n", modifiers: [])
        viewModel.updateShortcut(shortcutId1, to: newShortcut)
        
        // Verify conflict is resolved
        XCTAssertFalse(viewModel.hasConflicts(shortcutId1))
    }
    
    // MARK: - Shortcut Display Tests
    
    func testShortcutDisplayString() {
        let shortcut1 = KeyboardShortcut(key: "n", modifiers: [])
        XCTAssertEqual(shortcut1.displayString, "N")
        
        let shortcut2 = KeyboardShortcut(key: "s", modifiers: [.command])
        XCTAssertEqual(shortcut2.displayString, "⌘S")
        
        let shortcut3 = KeyboardShortcut(key: "z", modifiers: [.command, .shift])
        XCTAssertEqual(shortcut3.displayString, "⇧⌘Z")
        
        let shortcut4 = KeyboardShortcut(key: "ArrowRight", modifiers: [])
        XCTAssertEqual(shortcut4.displayString, "→")
    }
    
    func testShortcutModification() {
        let shortcutId = "next_image"
        let originalShortcut = mockShortcutManager.getShortcut(for: shortcutId)
        
        XCTAssertNotNil(originalShortcut)
        XCTAssertFalse(originalShortcut?.isModified ?? true)
        
        // Modify the shortcut
        let newShortcut = KeyboardShortcut(key: "j", modifiers: [])
        viewModel.updateShortcut(shortcutId, to: newShortcut)
        
        let modifiedShortcut = mockShortcutManager.getShortcut(for: shortcutId)
        XCTAssertTrue(modifiedShortcut?.isModified ?? false)
    }
    
    // MARK: - Shortcut Reset Tests
    
    func testIndividualShortcutReset() {
        let shortcutId = "next_image"
        
        // First modify the shortcut
        let newShortcut = KeyboardShortcut(key: "j", modifiers: [])
        viewModel.updateShortcut(shortcutId, to: newShortcut)
        XCTAssertTrue(viewModel.hasCustomShortcuts)
        
        // Then reset it
        viewModel.resetShortcut(shortcutId)
        
        let resetShortcut = mockShortcutManager.getShortcut(for: shortcutId)
        XCTAssertFalse(resetShortcut?.isModified ?? true)
        XCTAssertTrue(mockShortcutManager.resetShortcuts.contains(shortcutId))
    }
    
    func testResetAllShortcuts() {
        // Modify multiple shortcuts
        viewModel.updateShortcut("next_image", to: KeyboardShortcut(key: "j", modifiers: []))
        viewModel.updateShortcut("previous_image", to: KeyboardShortcut(key: "k", modifiers: []))
        XCTAssertTrue(viewModel.hasCustomShortcuts)
        
        // Reset all
        viewModel.resetAllShortcuts()
        
        XCTAssertFalse(viewModel.hasCustomShortcuts)
        XCTAssertTrue(mockShortcutManager.allShortcutsReset)
    }
    
    // MARK: - Search and Filter Tests
    
    func testShortcutSearch() {
        // Test searching for shortcuts
        viewModel.searchText = "next"
        
        let filteredCategories = viewModel.filteredShortcuts
        let allShortcuts = filteredCategories.flatMap { $0.shortcuts }
        
        // Should only contain shortcuts matching "next"
        for shortcut in allShortcuts {
            let matchesSearch = shortcut.name.localizedCaseInsensitiveContains("next") ||
                               shortcut.description.localizedCaseInsensitiveContains("next")
            XCTAssertTrue(matchesSearch)
        }
    }
    
    func testCaseInsensitiveSearch() {
        viewModel.searchText = "ZOOM"
        
        let filteredCategories = viewModel.filteredShortcuts
        let allShortcuts = filteredCategories.flatMap { $0.shortcuts }
        
        // Should find shortcuts regardless of case
        let hasZoomShortcuts = allShortcuts.contains { shortcut in
            shortcut.name.localizedCaseInsensitiveContains("zoom") ||
            shortcut.description.localizedCaseInsensitiveContains("zoom")
        }
        
        XCTAssertTrue(hasZoomShortcuts)
    }
    
    func testEmptySearchResults() {
        viewModel.searchText = "nonexistentshortcut"
        
        let filteredCategories = viewModel.filteredShortcuts
        let allShortcuts = filteredCategories.flatMap { $0.shortcuts }
        
        XCTAssertTrue(allShortcuts.isEmpty)
    }
    
    // MARK: - Category Organization Tests
    
    func testShortcutCategories() {
        let categories = viewModel.filteredShortcuts
        
        // Verify we have expected categories
        let categoryNames = Set(categories.map { $0.name })
        XCTAssertTrue(categoryNames.contains("Navigation"))
        XCTAssertTrue(categoryNames.contains("View"))
        
        // Verify shortcuts are properly categorized
        for category in categories {
            for shortcut in category.shortcuts {
                // Each shortcut should belong to its category
                XCTAssertEqual(shortcut.category.displayName, category.name)
            }
        }
    }
    
    func testCategoryIcons() {
        let categories = viewModel.filteredShortcuts
        
        for category in categories {
            // Each category should have an icon
            XCTAssertFalse(category.icon.isEmpty)
        }
    }
    
    // MARK: - Performance Tests
    
    func testShortcutSearchPerformance() {
        measure {
            for i in 0..<100 {
                viewModel.searchText = "search\(i)"
            }
            viewModel.searchText = ""
        }
    }
    
    func testRapidShortcutModification() {
        measure {
            for i in 0..<50 {
                let shortcut = KeyboardShortcut(key: "a", modifiers: [])
                viewModel.updateShortcut("test_shortcut", to: shortcut)
            }
        }
    }
    
    // MARK: - Edge Cases Tests
    
    func testEmptyShortcutKey() {
        let shortcutId = "next_image"
        let emptyShortcut = KeyboardShortcut(key: "", modifiers: [])
        
        viewModel.updateShortcut(shortcutId, to: emptyShortcut)
        
        // Should handle empty key gracefully
        let validationResult = viewModel.getValidationResult(for: shortcutId)
        // Depending on implementation, this might be an error or handled differently
    }
    
    func testSpecialKeys() {
        let shortcutId = "next_image"
        
        // Test various special keys
        let specialKeys = ["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown", "Space", "Tab", "Escape"]
        
        for key in specialKeys {
            let shortcut = KeyboardShortcut(key: key, modifiers: [])
            viewModel.updateShortcut(shortcutId, to: shortcut)
            
            let updatedShortcut = mockShortcutManager.getShortcut(for: shortcutId)?.currentShortcut
            XCTAssertEqual(updatedShortcut?.key, key)
        }
    }
    
    func testFunctionKeys() {
        let shortcutId = "next_image"
        
        // Test function keys
        for i in 1...12 {
            let key = "F\(i)"
            let shortcut = KeyboardShortcut(key: key, modifiers: [])
            viewModel.updateShortcut(shortcutId, to: shortcut)
            
            let updatedShortcut = mockShortcutManager.getShortcut(for: shortcutId)?.currentShortcut
            XCTAssertEqual(updatedShortcut?.key, key)
        }
    }
}