import XCTest
import Combine
@testable import StillView___Simple_Image_Viewer

class ShortcutsViewModelTests: XCTestCase {
    
    var viewModel: ShortcutsViewModel!
    var mockShortcutManager: MockShortcutManager!
    var mockValidator: MockShortcutValidator!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockShortcutManager = MockShortcutManager()
        mockValidator = MockShortcutValidator()
        viewModel = ShortcutsViewModel(
            shortcutManager: mockShortcutManager,
            validator: mockValidator
        )
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        viewModel = nil
        mockValidator = nil
        mockShortcutManager = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertFalse(viewModel.filteredShortcuts.isEmpty)
        XCTAssertTrue(viewModel.searchText.isEmpty)
        XCTAssertFalse(viewModel.hasCustomShortcuts)
        XCTAssertTrue(viewModel.validationResults.isEmpty)
    }
    
    func testShortcutCategoriesLoaded() {
        let categories = viewModel.filteredShortcuts
        
        // Verify we have the expected categories
        let categoryNames = categories.map { $0.name }
        XCTAssertTrue(categoryNames.contains("Navigation"))
        XCTAssertTrue(categoryNames.contains("View"))
        XCTAssertTrue(categoryNames.contains("File"))
        
        // Verify each category has shortcuts
        for category in categories {
            XCTAssertFalse(category.shortcuts.isEmpty)
        }
    }
    
    // MARK: - Search and Filtering Tests
    
    func testSearchFiltering() {
        let expectation = XCTestExpectation(description: "Search filtering applied")
        
        viewModel.$filteredShortcuts
            .dropFirst()
            .sink { filteredCategories in
                let allShortcuts = filteredCategories.flatMap { $0.shortcuts }
                let matchingShortcuts = allShortcuts.filter { 
                    $0.name.localizedCaseInsensitiveContains("next") ||
                    $0.description.localizedCaseInsensitiveContains("next")
                }
                XCTAssertFalse(matchingShortcuts.isEmpty)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.searchText = "next"
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testEmptySearchShowsAllShortcuts() {
        viewModel.searchText = "nonexistent"
        XCTAssertTrue(viewModel.filteredShortcuts.allSatisfy { $0.shortcuts.isEmpty })
        
        viewModel.searchText = ""
        XCTAssertFalse(viewModel.filteredShortcuts.isEmpty)
    }
    
    // MARK: - Shortcut Management Tests
    
    func testUpdateShortcut() {
        let shortcutId = "next_image"
        let newShortcut = KeyboardShortcut(key: "j", modifiers: [])
        
        let expectation = XCTestExpectation(description: "Shortcut updated")
        
        viewModel.$hasCustomShortcuts
            .dropFirst()
            .sink { hasCustom in
                XCTAssertTrue(hasCustom)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.updateShortcut(shortcutId, to: newShortcut)
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(mockShortcutManager.updatedShortcuts.contains(shortcutId))
    }
    
    func testResetShortcut() {
        let shortcutId = "next_image"
        
        // First modify a shortcut
        viewModel.updateShortcut(shortcutId, to: KeyboardShortcut(key: "j", modifiers: []))
        XCTAssertTrue(viewModel.hasCustomShortcuts)
        
        let expectation = XCTestExpectation(description: "Shortcut reset")
        
        viewModel.$hasCustomShortcuts
            .dropFirst()
            .sink { hasCustom in
                XCTAssertFalse(hasCustom)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.resetShortcut(shortcutId)
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(mockShortcutManager.resetShortcuts.contains(shortcutId))
    }
    
    func testResetAllShortcuts() {
        // First modify some shortcuts
        viewModel.updateShortcut("next_image", to: KeyboardShortcut(key: "j", modifiers: []))
        viewModel.updateShortcut("previous_image", to: KeyboardShortcut(key: "k", modifiers: []))
        XCTAssertTrue(viewModel.hasCustomShortcuts)
        
        let expectation = XCTestExpectation(description: "All shortcuts reset")
        
        viewModel.$hasCustomShortcuts
            .dropFirst()
            .sink { hasCustom in
                XCTAssertFalse(hasCustom)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.resetAllShortcuts()
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(mockShortcutManager.allShortcutsReset)
    }
    
    // MARK: - Conflict Detection Tests
    
    func testConflictDetection() {
        let shortcutId = "next_image"
        mockValidator.conflictingShortcuts[shortcutId] = "previous_image"
        
        let hasConflicts = viewModel.hasConflicts(shortcutId)
        XCTAssertTrue(hasConflicts)
        
        let validationResult = viewModel.getValidationResult(for: shortcutId)
        XCTAssertNotNil(validationResult)
        XCTAssertEqual(validationResult?.severity, .error)
    }
    
    func testSystemShortcutConflict() {
        let shortcutId = "save_image"
        mockValidator.systemConflicts[shortcutId] = true
        
        let validationResult = viewModel.getValidationResult(for: shortcutId)
        XCTAssertNotNil(validationResult)
        XCTAssertEqual(validationResult?.severity, .error)
        XCTAssertTrue(validationResult?.message?.contains("system shortcut") ?? false)
    }
    
    // MARK: - Import/Export Tests
    
    func testExportShortcuts() {
        // Modify some shortcuts first
        viewModel.updateShortcut("next_image", to: KeyboardShortcut(key: "j", modifiers: []))
        viewModel.updateShortcut("previous_image", to: KeyboardShortcut(key: "k", modifiers: []))
        
        let exportedData = viewModel.exportShortcuts()
        
        XCTAssertFalse(exportedData.isEmpty)
        XCTAssertNotNil(exportedData["shortcuts"])
        XCTAssertNotNil(exportedData["version"])
    }
    
    func testImportShortcuts() {
        let importData: [String: Any] = [
            "shortcuts": [
                "next_image": ["key": "j", "modifiers": []],
                "previous_image": ["key": "k", "modifiers": []]
            ],
            "version": "1.0"
        ]
        
        let expectation = XCTestExpectation(description: "Shortcuts imported")
        
        viewModel.$hasCustomShortcuts
            .dropFirst()
            .sink { hasCustom in
                XCTAssertTrue(hasCustom)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.importShortcuts(from: importData)
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(mockShortcutManager.shortcutsImported)
    }
    
    func testImportInvalidData() {
        let invalidData: [String: Any] = [
            "invalid": "data"
        ]
        
        viewModel.importShortcuts(from: invalidData)
        
        // Should not crash and should not import anything
        XCTAssertFalse(mockShortcutManager.shortcutsImported)
    }
    
    // MARK: - Validation Tests
    
    func testValidationResultsUpdate() {
        let shortcutId = "next_image"
        let validationResult = ValidationResult.warning("Test warning")
        mockValidator.validationResults[shortcutId] = validationResult
        
        let expectation = XCTestExpectation(description: "Validation results updated")
        
        viewModel.$validationResults
            .dropFirst()
            .sink { results in
                XCTAssertEqual(results.count, 1)
                XCTAssertEqual(results[shortcutId]?.message, "Test warning")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.updateShortcut(shortcutId, to: KeyboardShortcut(key: "j", modifiers: []))
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Performance Tests
    
    func testLargeShortcutListPerformance() {
        measure {
            // Simulate searching through a large list
            for i in 0..<100 {
                viewModel.searchText = "shortcut\(i)"
            }
            viewModel.searchText = ""
        }
    }
    
    func testRapidShortcutUpdates() {
        measure {
            // Rapidly update shortcuts
            for i in 0..<50 {
                viewModel.updateShortcut("test_shortcut_\(i)", to: KeyboardShortcut(key: "a", modifiers: []))
            }
        }
    }
}

// MARK: - Mock Classes

class MockShortcutManager: ShortcutManagerProtocol {
    var shortcuts: [String: ShortcutDefinition] = [:]
    var updatedShortcuts: Set<String> = []
    var resetShortcuts: Set<String> = []
    var allShortcutsReset = false
    var shortcutsImported = false
    
    init() {
        // Initialize with some default shortcuts
        shortcuts = [
            "next_image": ShortcutDefinition(
                id: "next_image",
                name: "Next Image",
                description: "Navigate to the next image",
                category: .navigation,
                defaultShortcut: KeyboardShortcut(key: "ArrowRight", modifiers: []),
                currentShortcut: KeyboardShortcut(key: "ArrowRight", modifiers: []),
                isCustomizable: true
            ),
            "previous_image": ShortcutDefinition(
                id: "previous_image",
                name: "Previous Image",
                description: "Navigate to the previous image",
                category: .navigation,
                defaultShortcut: KeyboardShortcut(key: "ArrowLeft", modifiers: []),
                currentShortcut: KeyboardShortcut(key: "ArrowLeft", modifiers: []),
                isCustomizable: true
            ),
            "zoom_in": ShortcutDefinition(
                id: "zoom_in",
                name: "Zoom In",
                description: "Zoom into the image",
                category: .view,
                defaultShortcut: KeyboardShortcut(key: "=", modifiers: [.command]),
                currentShortcut: KeyboardShortcut(key: "=", modifiers: [.command]),
                isCustomizable: true
            )
        ]
    }
    
    func getAllShortcuts() -> [ShortcutDefinition] {
        return Array(shortcuts.values)
    }
    
    func getShortcut(for id: String) -> ShortcutDefinition? {
        return shortcuts[id]
    }
    
    func updateShortcut(_ id: String, to newShortcut: KeyboardShortcut) {
        if var shortcut = shortcuts[id] {
            shortcut.currentShortcut = newShortcut
            shortcuts[id] = shortcut
            updatedShortcuts.insert(id)
        }
    }
    
    func resetShortcut(_ id: String) {
        if var shortcut = shortcuts[id] {
            shortcut.currentShortcut = shortcut.defaultShortcut
            shortcuts[id] = shortcut
            resetShortcuts.insert(id)
        }
    }
    
    func resetAllShortcuts() {
        for (id, var shortcut) in shortcuts {
            shortcut.currentShortcut = shortcut.defaultShortcut
            shortcuts[id] = shortcut
        }
        allShortcutsReset = true
    }
    
    func exportShortcuts() -> [String: Any] {
        let customShortcuts = shortcuts.compactMapValues { shortcut in
            shortcut.isModified ? [
                "key": shortcut.currentShortcut.key,
                "modifiers": shortcut.currentShortcut.modifiers.rawValue
            ] : nil
        }
        
        return [
            "shortcuts": customShortcuts,
            "version": "1.0"
        ]
    }
    
    func importShortcuts(from data: [String: Any]) -> Bool {
        guard let shortcutsData = data["shortcuts"] as? [String: [String: Any]] else {
            return false
        }
        
        for (id, shortcutData) in shortcutsData {
            guard let key = shortcutData["key"] as? String,
                  let modifiersRaw = shortcutData["modifiers"] as? UInt else {
                continue
            }
            
            let modifiers = NSEvent.ModifierFlags(rawValue: modifiersRaw)
            let newShortcut = KeyboardShortcut(key: key, modifiers: modifiers)
            updateShortcut(id, to: newShortcut)
        }
        
        shortcutsImported = true
        return true
    }
    
    func hasCustomShortcuts() -> Bool {
        return shortcuts.values.contains { $0.isModified }
    }
}

class MockShortcutValidator: ShortcutValidatorProtocol {
    var validationResults: [String: ValidationResult] = [:]
    var conflictingShortcuts: [String: String] = [:]
    var systemConflicts: [String: Bool] = [:]
    
    func validateShortcut(_ shortcut: KeyboardShortcut, for definition: ShortcutDefinition) -> ValidationResult {
        if let result = validationResults[definition.id] {
            return result
        }
        
        if systemConflicts[definition.id] == true {
            return .error("This shortcut conflicts with a system shortcut")
        }
        
        if let conflictingId = conflictingShortcuts[definition.id] {
            return .error("This shortcut conflicts with '\(conflictingId)'")
        }
        
        return .success()
    }
    
    func findConflictingShortcut(_ shortcut: KeyboardShortcut, excluding excludeId: String) -> ShortcutDefinition? {
        // Simplified implementation for testing
        return nil
    }
    
    func isSystemShortcut(_ shortcut: KeyboardShortcut) -> Bool {
        return systemConflicts.values.contains(true)
    }
}

// MARK: - Protocol Definitions

protocol ShortcutManagerProtocol {
    func getAllShortcuts() -> [ShortcutDefinition]
    func getShortcut(for id: String) -> ShortcutDefinition?
    func updateShortcut(_ id: String, to newShortcut: KeyboardShortcut)
    func resetShortcut(_ id: String)
    func resetAllShortcuts()
    func exportShortcuts() -> [String: Any]
    func importShortcuts(from data: [String: Any]) -> Bool
    func hasCustomShortcuts() -> Bool
}

protocol ShortcutValidatorProtocol {
    func validateShortcut(_ shortcut: KeyboardShortcut, for definition: ShortcutDefinition) -> ValidationResult
    func findConflictingShortcut(_ shortcut: KeyboardShortcut, excluding excludeId: String) -> ShortcutDefinition?
    func isSystemShortcut(_ shortcut: KeyboardShortcut) -> Bool
}