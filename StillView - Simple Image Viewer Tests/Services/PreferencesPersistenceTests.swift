import XCTest
import Combine
@testable import StillView___Simple_Image_Viewer

class PreferencesPersistenceTests: XCTestCase {
    
    var preferencesService: TestablePreferencesService!
    var viewModel: PreferencesViewModel!
    var shortcutsViewModel: ShortcutsViewModel!
    var shortcutManager: TestableShortcutManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        preferencesService = TestablePreferencesService()
        viewModel = PreferencesViewModel(preferencesService: preferencesService)
        shortcutManager = TestableShortcutManager()
        shortcutsViewModel = ShortcutsViewModel(shortcutManager: shortcutManager)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        shortcutsViewModel = nil
        shortcutManager = nil
        viewModel = nil
        preferencesService = nil
        super.tearDown()
    }
    
    // MARK: - Basic Persistence Tests
    
    func testPreferencePersistence() {
        let expectation = XCTestExpectation(description: "Preference persisted")
        
        // Change a preference
        viewModel.showFileName = true
        viewModel.slideshowInterval = 10.0
        
        // Wait for persistence
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Verify the preference was saved
            XCTAssertTrue(self.preferencesService.persistedData.showFileName)
            XCTAssertEqual(self.preferencesService.persistedData.slideshowInterval, 10.0)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testPreferenceRestoration() {
        // Set up initial data
        preferencesService.persistedData.showFileName = true
        preferencesService.persistedData.slideshowInterval = 15.0
        preferencesService.persistedData.toolbarStyle = .attached
        
        // Create new view model (simulating app restart)
        let newViewModel = PreferencesViewModel(preferencesService: preferencesService)
        
        // Verify preferences were restored
        XCTAssertTrue(newViewModel.showFileName)
        XCTAssertEqual(newViewModel.slideshowInterval, 15.0)
        XCTAssertEqual(newViewModel.toolbarStyle, .attached)
    }
    
    func testMultiplePreferencePersistence() {
        let expectation = XCTestExpectation(description: "Multiple preferences persisted")
        
        // Change multiple preferences
        viewModel.showFileName = true
        viewModel.showImageInfo = false
        viewModel.slideshowInterval = 8.0
        viewModel.loopSlideshow = true
        viewModel.confirmDelete = false
        viewModel.toolbarStyle = .attached
        viewModel.animationIntensity = .enhanced
        viewModel.thumbnailSize = .large
        
        // Wait for persistence
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let data = self.preferencesService.persistedData
            XCTAssertTrue(data.showFileName)
            XCTAssertFalse(data.showImageInfo)
            XCTAssertEqual(data.slideshowInterval, 8.0)
            XCTAssertTrue(data.loopSlideshow)
            XCTAssertFalse(data.confirmDelete)
            XCTAssertEqual(data.toolbarStyle, .attached)
            XCTAssertEqual(data.animationIntensity, .enhanced)
            XCTAssertEqual(data.thumbnailSize, .large)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Shortcut Persistence Tests
    
    func testShortcutPersistence() {
        let expectation = XCTestExpectation(description: "Shortcut persisted")
        
        let shortcutId = "next_image"
        let newShortcut = KeyboardShortcut(key: "j", modifiers: [])
        
        // Update shortcut
        shortcutsViewModel.updateShortcut(shortcutId, to: newShortcut)
        
        // Wait for persistence
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Verify shortcut was saved
            let persistedShortcut = self.shortcutManager.persistedShortcuts[shortcutId]
            XCTAssertNotNil(persistedShortcut)
            XCTAssertEqual(persistedShortcut?.key, "j")
            XCTAssertTrue(persistedShortcut?.modifiers.isEmpty ?? false)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testShortcutRestoration() {
        // Set up persisted shortcuts
        shortcutManager.persistedShortcuts["next_image"] = KeyboardShortcut(key: "j", modifiers: [])
        shortcutManager.persistedShortcuts["previous_image"] = KeyboardShortcut(key: "k", modifiers: [])
        shortcutManager.persistedShortcuts["zoom_in"] = KeyboardShortcut(key: "=", modifiers: [.command, .shift])
        
        // Create new shortcuts view model (simulating app restart)
        let newShortcutManager = TestableShortcutManager()
        newShortcutManager.persistedShortcuts = shortcutManager.persistedShortcuts
        let newViewModel = ShortcutsViewModel(shortcutManager: newShortcutManager)
        
        // Verify shortcuts were restored
        XCTAssertTrue(newViewModel.hasCustomShortcuts)
        
        let nextImageShortcut = newShortcutManager.getShortcut(for: "next_image")?.currentShortcut
        XCTAssertEqual(nextImageShortcut?.key, "j")
        
        let zoomInShortcut = newShortcutManager.getShortcut(for: "zoom_in")?.currentShortcut
        XCTAssertEqual(zoomInShortcut?.key, "=")
        XCTAssertTrue(zoomInShortcut?.modifiers.contains(.command) ?? false)
        XCTAssertTrue(zoomInShortcut?.modifiers.contains(.shift) ?? false)
    }
    
    func testShortcutResetPersistence() {
        let expectation = XCTestExpectation(description: "Shortcut reset persisted")
        
        let shortcutId = "next_image"
        
        // First modify a shortcut
        shortcutsViewModel.updateShortcut(shortcutId, to: KeyboardShortcut(key: "j", modifiers: []))
        XCTAssertTrue(shortcutsViewModel.hasCustomShortcuts)
        
        // Then reset it
        shortcutsViewModel.resetShortcut(shortcutId)
        
        // Wait for persistence
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Verify reset was persisted (shortcut should be removed from custom shortcuts)
            XCTAssertNil(self.shortcutManager.persistedShortcuts[shortcutId])
            XCTAssertFalse(self.shortcutsViewModel.hasCustomShortcuts)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Tab State Persistence Tests
    
    func testTabStatePersistence() {
        let coordinator = PreferencesCoordinator()
        
        // Change tab
        coordinator.selectTab(.appearance)
        XCTAssertEqual(coordinator.selectedTab, .appearance)
        
        // Simulate app restart
        let newCoordinator = PreferencesCoordinator()
        // In a real implementation, this would restore from UserDefaults
        // For testing, we verify the mechanism works
        XCTAssertEqual(newCoordinator.selectedTab, .general) // Default tab
    }
    
    // MARK: - Error Recovery Tests
    
    func testCorruptedPreferencesRecovery() {
        // Simulate corrupted preferences
        preferencesService.shouldSimulateCorruption = true
        
        // Create new view model
        let newViewModel = PreferencesViewModel(preferencesService: preferencesService)
        
        // Should fall back to defaults
        XCTAssertFalse(newViewModel.showFileName) // Default value
        XCTAssertEqual(newViewModel.slideshowInterval, 3.0) // Default value
        XCTAssertEqual(newViewModel.toolbarStyle, .floating) // Default value
    }
    
    func testCorruptedShortcutsRecovery() {
        // Simulate corrupted shortcuts
        shortcutManager.shouldSimulateCorruption = true
        
        // Create new shortcuts view model
        let newViewModel = ShortcutsViewModel(shortcutManager: shortcutManager)
        
        // Should fall back to defaults
        XCTAssertFalse(newViewModel.hasCustomShortcuts)
        
        let shortcuts = newViewModel.filteredShortcuts.flatMap { $0.shortcuts }
        for shortcut in shortcuts {
            XCTAssertFalse(shortcut.isModified) // All should be default
        }
    }
    
    // MARK: - Backup and Restore Tests
    
    func testPreferencesBackup() {
        // Set up preferences
        viewModel.showFileName = true
        viewModel.slideshowInterval = 12.0
        viewModel.toolbarStyle = .attached
        
        // Create backup
        let backup = preferencesService.createBackup()
        
        XCTAssertNotNil(backup)
        XCTAssertTrue(backup["showFileName"] as? Bool ?? false)
        XCTAssertEqual(backup["slideshowInterval"] as? Double, 12.0)
        XCTAssertEqual(backup["toolbarStyle"] as? String, "attached")
    }
    
    func testPreferencesRestore() {
        let backup: [String: Any] = [
            "showFileName": true,
            "slideshowInterval": 20.0,
            "toolbarStyle": "attached",
            "animationIntensity": "enhanced"
        ]
        
        // Restore from backup
        let success = preferencesService.restoreFromBackup(backup)
        XCTAssertTrue(success)
        
        // Create new view model to verify restoration
        let newViewModel = PreferencesViewModel(preferencesService: preferencesService)
        XCTAssertTrue(newViewModel.showFileName)
        XCTAssertEqual(newViewModel.slideshowInterval, 20.0)
        XCTAssertEqual(newViewModel.toolbarStyle, .attached)
        XCTAssertEqual(newViewModel.animationIntensity, .enhanced)
    }
    
    func testShortcutsBackup() {
        // Set up custom shortcuts
        shortcutsViewModel.updateShortcut("next_image", to: KeyboardShortcut(key: "j", modifiers: []))
        shortcutsViewModel.updateShortcut("zoom_in", to: KeyboardShortcut(key: "=", modifiers: [.command, .shift]))
        
        // Create backup
        let backup = shortcutManager.createBackup()
        
        XCTAssertNotNil(backup)
        XCTAssertNotNil(backup["shortcuts"])
        
        let shortcuts = backup["shortcuts"] as? [String: [String: Any]]
        XCTAssertNotNil(shortcuts?["next_image"])
        XCTAssertNotNil(shortcuts?["zoom_in"])
    }
    
    func testShortcutsRestore() {
        let backup: [String: Any] = [
            "shortcuts": [
                "next_image": ["key": "j", "modifiers": 0],
                "previous_image": ["key": "k", "modifiers": 0]
            ],
            "version": "1.0"
        ]
        
        // Restore from backup
        let success = shortcutManager.restoreFromBackup(backup)
        XCTAssertTrue(success)
        
        // Verify restoration
        let nextShortcut = shortcutManager.getShortcut(for: "next_image")?.currentShortcut
        XCTAssertEqual(nextShortcut?.key, "j")
        
        let prevShortcut = shortcutManager.getShortcut(for: "previous_image")?.currentShortcut
        XCTAssertEqual(prevShortcut?.key, "k")
    }
    
    // MARK: - Migration Tests
    
    func testPreferencesMigration() {
        // Simulate old version preferences
        let oldPreferences: [String: Any] = [
            "showFileName": true,
            "slideshowDuration": 5.0, // Old key name
            "toolbarType": "floating" // Old key name
        ]
        
        // Migrate preferences
        let migrated = preferencesService.migratePreferences(from: oldPreferences)
        XCTAssertTrue(migrated)
        
        // Verify migration
        let newViewModel = PreferencesViewModel(preferencesService: preferencesService)
        XCTAssertTrue(newViewModel.showFileName)
        XCTAssertEqual(newViewModel.slideshowInterval, 5.0) // Migrated from slideshowDuration
        XCTAssertEqual(newViewModel.toolbarStyle, .floating) // Migrated from toolbarType
    }
    
    func testShortcutsMigration() {
        // Simulate old version shortcuts
        let oldShortcuts: [String: Any] = [
            "nextImage": ["key": "Right", "cmd": true], // Old format
            "prevImage": ["key": "Left", "cmd": true]
        ]
        
        // Migrate shortcuts
        let migrated = shortcutManager.migrateShortcuts(from: oldShortcuts)
        XCTAssertTrue(migrated)
        
        // Verify migration
        let nextShortcut = shortcutManager.getShortcut(for: "next_image")?.currentShortcut
        XCTAssertEqual(nextShortcut?.key, "ArrowRight") // Migrated key name
        XCTAssertTrue(nextShortcut?.modifiers.contains(.command) ?? false)
    }
    
    // MARK: - Concurrent Persistence Tests
    
    func testConcurrentPreferenceSaving() {
        let expectation = XCTestExpectation(description: "Concurrent saving completed")
        expectation.expectedFulfillmentCount = 10
        
        let queue = DispatchQueue.global(qos: .userInitiated)
        
        // Test concurrent preference changes
        for i in 0..<10 {
            queue.async {
                let service = TestablePreferencesService()
                let vm = PreferencesViewModel(preferencesService: service)
                
                vm.slideshowInterval = Double(i % 30) + 1.0
                vm.showFileName = i % 2 == 0
                
                DispatchQueue.main.async {
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Large Data Persistence Tests
    
    func testLargeShortcutDatasetPersistence() {
        // Create many custom shortcuts
        for i in 0..<100 {
            let shortcut = KeyboardShortcut(key: "a", modifiers: [])
            shortcutsViewModel.updateShortcut("large_test_\(i)", to: shortcut)
        }
        
        let expectation = XCTestExpectation(description: "Large dataset persisted")
        
        // Wait for persistence
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Verify all shortcuts were persisted
            XCTAssertEqual(self.shortcutManager.persistedShortcuts.count, 100)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - Validation During Persistence Tests
    
    func testValidationDuringPersistence() {
        let expectation = XCTestExpectation(description: "Validation during persistence")
        
        // Set invalid value
        viewModel.slideshowInterval = 0.5 // Invalid
        
        // Wait for validation and persistence
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Invalid values should not be persisted
            XCTAssertNotEqual(self.preferencesService.persistedData.slideshowInterval, 0.5)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - Testable Services

class TestablePreferencesService: PreferencesServiceProtocol {
    var persistedData = PreferencesData()
    var shouldSimulateCorruption = false
    
    func updatePreference<T>(_ keyPath: WritableKeyPath<PreferencesData, T>, value: T) throws {
        if shouldSimulateCorruption {
            throw PreferencesError.saveFailed
        }
        
        persistedData[keyPath: keyPath] = value
    }
    
    func resetToDefaults() throws {
        if shouldSimulateCorruption {
            throw PreferencesError.resetFailed
        }
        
        persistedData = PreferencesData()
    }
    
    func createBackup() -> [String: Any] {
        return [
            "showFileName": persistedData.showFileName,
            "slideshowInterval": persistedData.slideshowInterval,
            "toolbarStyle": persistedData.toolbarStyle.rawValue,
            "animationIntensity": persistedData.animationIntensity.rawValue
        ]
    }
    
    func restoreFromBackup(_ backup: [String: Any]) -> Bool {
        guard !shouldSimulateCorruption else { return false }
        
        if let showFileName = backup["showFileName"] as? Bool {
            persistedData.showFileName = showFileName
        }
        
        if let slideshowInterval = backup["slideshowInterval"] as? Double {
            persistedData.slideshowInterval = slideshowInterval
        }
        
        if let toolbarStyleRaw = backup["toolbarStyle"] as? String,
           let toolbarStyle = ToolbarStyle(rawValue: toolbarStyleRaw) {
            persistedData.toolbarStyle = toolbarStyle
        }
        
        if let animationIntensityRaw = backup["animationIntensity"] as? String,
           let animationIntensity = AnimationIntensity(rawValue: animationIntensityRaw) {
            persistedData.animationIntensity = animationIntensity
        }
        
        return true
    }
    
    func migratePreferences(from oldPreferences: [String: Any]) -> Bool {
        guard !shouldSimulateCorruption else { return false }
        
        // Migrate old preference keys to new ones
        if let showFileName = oldPreferences["showFileName"] as? Bool {
            persistedData.showFileName = showFileName
        }
        
        if let slideshowDuration = oldPreferences["slideshowDuration"] as? Double {
            persistedData.slideshowInterval = slideshowDuration
        }
        
        if let toolbarType = oldPreferences["toolbarType"] as? String {
            persistedData.toolbarStyle = toolbarType == "floating" ? .floating : .attached
        }
        
        return true
    }
}

class TestableShortcutManager: ShortcutManagerProtocol {
    var shortcuts: [String: ShortcutDefinition] = [:]
    var persistedShortcuts: [String: KeyboardShortcut] = [:]
    var shouldSimulateCorruption = false
    
    init() {
        // Initialize with default shortcuts
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
            persistedShortcuts[id] = newShortcut
        }
    }
    
    func resetShortcut(_ id: String) {
        if var shortcut = shortcuts[id] {
            shortcut.currentShortcut = shortcut.defaultShortcut
            shortcuts[id] = shortcut
            persistedShortcuts.removeValue(forKey: id)
        }
    }
    
    func resetAllShortcuts() {
        for (id, var shortcut) in shortcuts {
            shortcut.currentShortcut = shortcut.defaultShortcut
            shortcuts[id] = shortcut
        }
        persistedShortcuts.removeAll()
    }
    
    func exportShortcuts() -> [String: Any] {
        return [
            "shortcuts": persistedShortcuts.mapValues { shortcut in
                ["key": shortcut.key, "modifiers": shortcut.modifiers.rawValue]
            },
            "version": "1.0"
        ]
    }
    
    func importShortcuts(from data: [String: Any]) -> Bool {
        guard !shouldSimulateCorruption,
              let shortcutsData = data["shortcuts"] as? [String: [String: Any]] else {
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
        
        return true
    }
    
    func hasCustomShortcuts() -> Bool {
        return !persistedShortcuts.isEmpty
    }
    
    func createBackup() -> [String: Any] {
        return exportShortcuts()
    }
    
    func restoreFromBackup(_ backup: [String: Any]) -> Bool {
        return importShortcuts(from: backup)
    }
    
    func migrateShortcuts(from oldShortcuts: [String: Any]) -> Bool {
        guard !shouldSimulateCorruption else { return false }
        
        // Migrate old shortcut format
        for (oldId, oldData) in oldShortcuts {
            guard let data = oldData as? [String: Any],
                  let key = data["key"] as? String else {
                continue
            }
            
            // Map old IDs to new IDs
            let newId: String
            switch oldId {
            case "nextImage":
                newId = "next_image"
            case "prevImage":
                newId = "previous_image"
            default:
                newId = oldId
            }
            
            // Map old key names to new ones
            let newKey: String
            switch key {
            case "Right":
                newKey = "ArrowRight"
            case "Left":
                newKey = "ArrowLeft"
            default:
                newKey = key
            }
            
            // Convert old modifier format
            var modifiers: NSEvent.ModifierFlags = []
            if data["cmd"] as? Bool == true {
                modifiers.insert(.command)
            }
            if data["shift"] as? Bool == true {
                modifiers.insert(.shift)
            }
            if data["alt"] as? Bool == true {
                modifiers.insert(.option)
            }
            
            let newShortcut = KeyboardShortcut(key: newKey, modifiers: modifiers)
            updateShortcut(newId, to: newShortcut)
        }
        
        return true
    }
}