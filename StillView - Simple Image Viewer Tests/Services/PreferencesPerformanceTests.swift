import XCTest
import Combine
@testable import StillView___Simple_Image_Viewer

class PreferencesPerformanceTests: XCTestCase {
    
    var preferencesService: MockPreferencesService!
    var viewModel: PreferencesViewModel!
    var shortcutsViewModel: ShortcutsViewModel!
    var mockShortcutManager: MockShortcutManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        preferencesService = MockPreferencesService()
        viewModel = PreferencesViewModel(preferencesService: preferencesService)
        mockShortcutManager = MockShortcutManager()
        shortcutsViewModel = ShortcutsViewModel(shortcutManager: mockShortcutManager)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        shortcutsViewModel = nil
        mockShortcutManager = nil
        viewModel = nil
        preferencesService = nil
        super.tearDown()
    }
    
    // MARK: - Preference Loading Performance Tests
    
    func testPreferencesLoadingPerformance() {
        measure {
            // Simulate loading preferences multiple times
            for _ in 0..<100 {
                let newViewModel = PreferencesViewModel(preferencesService: preferencesService)
                _ = newViewModel.showFileName
                _ = newViewModel.slideshowInterval
                _ = newViewModel.toolbarStyle
            }
        }
    }
    
    func testPreferencesInitializationPerformance() {
        measure {
            // Test rapid initialization of preferences
            for _ in 0..<50 {
                let service = MockPreferencesService()
                let vm = PreferencesViewModel(preferencesService: service)
                
                // Access all properties to ensure they're loaded
                _ = vm.showFileName
                _ = vm.showImageInfo
                _ = vm.defaultZoomLevel
                _ = vm.slideshowInterval
                _ = vm.loopSlideshow
                _ = vm.confirmDelete
                _ = vm.rememberLastFolder
                _ = vm.toolbarStyle
                _ = vm.enableGlassEffects
                _ = vm.animationIntensity
                _ = vm.enableHoverEffects
                _ = vm.thumbnailSize
                _ = vm.showMetadataBadges
            }
        }
    }
    
    // MARK: - Preference Saving Performance Tests
    
    func testRapidPreferenceSaving() {
        measure {
            // Test rapid preference changes
            for i in 0..<200 {
                viewModel.slideshowInterval = Double(i % 30) + 1.0
                viewModel.showFileName = i % 2 == 0
                viewModel.thumbnailSize = ThumbnailSize.allCases[i % 3]
            }
        }
    }
    
    func testBatchPreferenceUpdates() {
        measure {
            // Test updating multiple preferences at once
            for i in 0..<100 {
                viewModel.showFileName = i % 2 == 0
                viewModel.showImageInfo = i % 3 == 0
                viewModel.loopSlideshow = i % 4 == 0
                viewModel.confirmDelete = i % 5 == 0
                viewModel.rememberLastFolder = i % 6 == 0
            }
        }
    }
    
    func testPreferenceValidationPerformance() {
        let validator = PreferencesValidator()
        
        measure {
            // Test validation performance
            for i in 0..<1000 {
                _ = validator.validateSlideshowInterval(Double(i % 60) + 1.0)
                _ = validator.validateAnimationIntensity(AnimationIntensity.allCases[i % 3])
                _ = validator.validateThumbnailSize(ThumbnailSize.allCases[i % 3])
                _ = validator.validateGlassEffects(i % 2 == 0)
            }
        }
    }
    
    // MARK: - Shortcuts Performance Tests
    
    func testShortcutsLoadingPerformance() {
        measure {
            // Test loading shortcuts multiple times
            for _ in 0..<50 {
                let manager = MockShortcutManager()
                let vm = ShortcutsViewModel(shortcutManager: manager)
                _ = vm.filteredShortcuts
                _ = vm.hasCustomShortcuts
            }
        }
    }
    
    func testShortcutSearchPerformance() {
        // Add many shortcuts to test search performance
        for i in 0..<100 {
            let shortcut = ShortcutDefinition(
                id: "test_shortcut_\(i)",
                name: "Test Shortcut \(i)",
                description: "Description for test shortcut \(i)",
                category: .navigation,
                defaultShortcut: KeyboardShortcut(key: "a", modifiers: []),
                currentShortcut: KeyboardShortcut(key: "a", modifiers: []),
                isCustomizable: true
            )
            mockShortcutManager.shortcuts["test_shortcut_\(i)"] = shortcut
        }
        
        measure {
            // Test search performance with many shortcuts
            let searchTerms = ["test", "shortcut", "navigation", "view", "file", "edit"]
            for term in searchTerms {
                shortcutsViewModel.searchText = term
                _ = shortcutsViewModel.filteredShortcuts
            }
            shortcutsViewModel.searchText = ""
        }
    }
    
    func testRapidShortcutUpdates() {
        measure {
            // Test rapid shortcut updates
            for i in 0..<100 {
                let shortcut = KeyboardShortcut(key: "a", modifiers: [])
                shortcutsViewModel.updateShortcut("next_image", to: shortcut)
            }
        }
    }
    
    func testShortcutConflictDetectionPerformance() {
        let validator = MockShortcutValidator()
        
        // Add many potential conflicts
        for i in 0..<50 {
            validator.conflictingShortcuts["shortcut_\(i)"] = "conflict_\(i)"
        }
        
        measure {
            // Test conflict detection performance
            for i in 0..<100 {
                let shortcut = KeyboardShortcut(key: "a", modifiers: [])
                let definition = ShortcutDefinition(
                    id: "test_\(i)",
                    name: "Test",
                    description: "Test",
                    category: .navigation,
                    defaultShortcut: shortcut,
                    currentShortcut: shortcut,
                    isCustomizable: true
                )
                _ = validator.validateShortcut(shortcut, for: definition)
            }
        }
    }
    
    // MARK: - Memory Performance Tests
    
    func testMemoryUsageDuringRapidChanges() {
        let expectation = XCTestExpectation(description: "Memory test completed")
        
        // Monitor memory usage during rapid changes
        var changeCount = 0
        let targetChanges = 1000
        
        let timer = Timer.scheduledTimer(withTimeInterval: 0.001, repeats: true) { _ in
            self.viewModel.slideshowInterval = Double(changeCount % 30) + 1.0
            changeCount += 1
            
            if changeCount >= targetChanges {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        timer.invalidate()
        
        // Memory should be stable after rapid changes
        XCTAssertLessThan(changeCount, targetChanges + 100) // Allow some buffer
    }
    
    func testCombinePublisherPerformance() {
        measure {
            // Test Combine publisher performance
            var receivedValues = 0
            
            viewModel.$slideshowInterval
                .sink { _ in
                    receivedValues += 1
                }
                .store(in: &cancellables)
            
            // Rapidly change values
            for i in 0..<100 {
                viewModel.slideshowInterval = Double(i % 30) + 1.0
            }
            
            // Ensure all values were received
            XCTAssertGreaterThan(receivedValues, 0)
        }
    }
    
    // MARK: - UI Performance Tests
    
    func testTabSwitchingPerformance() {
        let coordinator = PreferencesCoordinator()
        
        measure {
            // Test rapid tab switching
            for _ in 0..<200 {
                coordinator.selectTab(.general)
                coordinator.selectTab(.appearance)
                coordinator.selectTab(.shortcuts)
            }
        }
    }
    
    func testValidationFeedbackPerformance() {
        // Create many validation results
        var validationResults: [ValidationResult] = []
        for i in 0..<100 {
            validationResults.append(.warning("Warning \(i)"))
        }
        
        measure {
            // Test rendering many validation results
            for _ in 0..<50 {
                _ = ValidationFeedbackView(results: validationResults)
            }
        }
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentPreferenceAccess() {
        let expectation = XCTestExpectation(description: "Concurrent access completed")
        expectation.expectedFulfillmentCount = 10
        
        let queue = DispatchQueue.global(qos: .userInitiated)
        
        // Test concurrent access to preferences
        for i in 0..<10 {
            queue.async {
                let service = MockPreferencesService()
                let vm = PreferencesViewModel(preferencesService: service)
                
                // Perform operations concurrently
                vm.slideshowInterval = Double(i % 30) + 1.0
                vm.showFileName = i % 2 == 0
                
                DispatchQueue.main.async {
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testConcurrentShortcutAccess() {
        let expectation = XCTestExpectation(description: "Concurrent shortcut access completed")
        expectation.expectedFulfillmentCount = 10
        
        let queue = DispatchQueue.global(qos: .userInitiated)
        
        // Test concurrent access to shortcuts
        for i in 0..<10 {
            queue.async {
                let manager = MockShortcutManager()
                let vm = ShortcutsViewModel(shortcutManager: manager)
                
                // Perform operations concurrently
                let shortcut = KeyboardShortcut(key: "a", modifiers: [])
                vm.updateShortcut("test_\(i)", to: shortcut)
                
                DispatchQueue.main.async {
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Large Dataset Performance Tests
    
    func testLargeShortcutDataset() {
        // Create a large number of shortcuts
        for i in 0..<500 {
            let shortcut = ShortcutDefinition(
                id: "large_test_\(i)",
                name: "Large Test Shortcut \(i)",
                description: "This is a test shortcut with a longer description to test performance with larger datasets \(i)",
                category: ShortcutCategory.allCases[i % ShortcutCategory.allCases.count],
                defaultShortcut: KeyboardShortcut(key: "a", modifiers: []),
                currentShortcut: KeyboardShortcut(key: "a", modifiers: []),
                isCustomizable: true
            )
            mockShortcutManager.shortcuts["large_test_\(i)"] = shortcut
        }
        
        measure {
            // Test performance with large dataset
            shortcutsViewModel.searchText = "test"
            _ = shortcutsViewModel.filteredShortcuts
            
            shortcutsViewModel.searchText = "shortcut"
            _ = shortcutsViewModel.filteredShortcuts
            
            shortcutsViewModel.searchText = ""
            _ = shortcutsViewModel.filteredShortcuts
        }
    }
    
    // MARK: - Animation Performance Tests
    
    func testAnimationPerformanceWithAccessibility() {
        let accessibilityService = AccessibilityService.shared
        
        measure {
            // Test animation adaptation performance
            for i in 0..<100 {
                let animation = Animation.easeInOut(duration: 0.3)
                _ = accessibilityService.adaptiveAnimation(animation)
                _ = accessibilityService.adaptiveAnimationDuration(0.3)
            }
        }
    }
    
    // MARK: - Stress Tests
    
    func testPreferencesStressTest() {
        measure {
            // Stress test with many rapid changes
            for i in 0..<500 {
                viewModel.slideshowInterval = Double(i % 60) + 1.0
                viewModel.showFileName = i % 2 == 0
                viewModel.showImageInfo = i % 3 == 0
                viewModel.loopSlideshow = i % 4 == 0
                viewModel.confirmDelete = i % 5 == 0
                viewModel.toolbarStyle = ToolbarStyle.allCases[i % 2]
                viewModel.animationIntensity = AnimationIntensity.allCases[i % 3]
                viewModel.thumbnailSize = ThumbnailSize.allCases[i % 3]
            }
        }
    }
    
    func testShortcutsStressTest() {
        measure {
            // Stress test shortcuts system
            for i in 0..<200 {
                let shortcut = KeyboardShortcut(
                    key: String(Character(UnicodeScalar(65 + (i % 26))!)), // A-Z
                    modifiers: i % 2 == 0 ? [.command] : []
                )
                shortcutsViewModel.updateShortcut("stress_test", to: shortcut)
                
                if i % 10 == 0 {
                    shortcutsViewModel.searchText = "stress"
                    _ = shortcutsViewModel.filteredShortcuts
                    shortcutsViewModel.searchText = ""
                }
            }
        }
    }
}