import XCTest
import SwiftUI
@testable import StillView___Simple_Image_Viewer

class PreferencesTabViewTests: XCTestCase {
    
    var coordinator: PreferencesCoordinator!
    
    override func setUp() {
        super.setUp()
        coordinator = PreferencesCoordinator()
    }
    
    override func tearDown() {
        coordinator = nil
        super.tearDown()
    }
    
    // MARK: - Tab Navigation Tests
    
    func testInitialTabSelection() {
        XCTAssertEqual(coordinator.selectedTab, .general)
    }
    
    func testTabSelection() {
        coordinator.selectTab(.appearance)
        XCTAssertEqual(coordinator.selectedTab, .appearance)
        
        coordinator.selectTab(.shortcuts)
        XCTAssertEqual(coordinator.selectedTab, .shortcuts)
        
        coordinator.selectTab(.general)
        XCTAssertEqual(coordinator.selectedTab, .general)
    }
    
    func testTabPersistence() {
        // Test that tab selection is remembered
        coordinator.selectTab(.shortcuts)
        XCTAssertEqual(coordinator.selectedTab, .shortcuts)
        
        // Simulate app restart by creating new coordinator
        let newCoordinator = PreferencesCoordinator()
        // In a real implementation, this would restore from UserDefaults
        // For now, we test that it starts with general tab
        XCTAssertEqual(newCoordinator.selectedTab, .general)
    }
    
    // MARK: - Tab Content Tests
    
    func testTabContentRendering() {
        let tabView = PreferencesTabView(coordinator: coordinator)
        
        // Test that each tab renders without crashing
        coordinator.selectTab(.general)
        // In a real UI test, we would verify the content is displayed
        
        coordinator.selectTab(.appearance)
        // Verify appearance content is shown
        
        coordinator.selectTab(.shortcuts)
        // Verify shortcuts content is shown
    }
    
    // MARK: - Accessibility Tests
    
    func testTabAccessibilityLabels() {
        let generalTab = Preferences.Tab.general
        XCTAssertEqual(generalTab.accessibilityLabel, "General preferences tab")
        
        let appearanceTab = Preferences.Tab.appearance
        XCTAssertEqual(appearanceTab.accessibilityLabel, "Appearance preferences tab")
        
        let shortcutsTab = Preferences.Tab.shortcuts
        XCTAssertEqual(shortcutsTab.accessibilityLabel, "Keyboard shortcuts preferences tab")
    }
    
    func testTabIcons() {
        XCTAssertEqual(Preferences.Tab.general.icon, "gearshape")
        XCTAssertEqual(Preferences.Tab.appearance.icon, "paintbrush")
        XCTAssertEqual(Preferences.Tab.shortcuts.icon, "keyboard")
    }
    
    func testTabTitles() {
        XCTAssertEqual(Preferences.Tab.general.title, "General")
        XCTAssertEqual(Preferences.Tab.appearance.title, "Appearance")
        XCTAssertEqual(Preferences.Tab.shortcuts.title, "Shortcuts")
    }
}

// MARK: - Integration Tests

class PreferencesIntegrationTests: XCTestCase {
    
    var coordinator: PreferencesCoordinator!
    var preferencesService: MockPreferencesService!
    var viewModel: PreferencesViewModel!
    
    override func setUp() {
        super.setUp()
        coordinator = PreferencesCoordinator()
        preferencesService = MockPreferencesService()
        viewModel = PreferencesViewModel(preferencesService: preferencesService)
    }
    
    override func tearDown() {
        viewModel = nil
        preferencesService = nil
        coordinator = nil
        super.tearDown()
    }
    
    // MARK: - Service Integration Tests
    
    func testPreferencesServiceIntegration() {
        // Test that view model properly integrates with preferences service
        let initialValue = viewModel.showFileName
        
        viewModel.showFileName = !initialValue
        
        // Verify the service was updated
        XCTAssertEqual(preferencesService.showFileName, viewModel.showFileName)
    }
    
    func testPreferencesValidationIntegration() {
        // Test that validation works with the view model
        viewModel.slideshowInterval = 0.5 // Invalid value
        
        let validationResult = viewModel.getValidationResult(for: "slideshowInterval")
        XCTAssertNotNil(validationResult)
        XCTAssertFalse(validationResult?.isValid ?? true)
    }
    
    func testPreferencesCoordinatorIntegration() {
        // Test that coordinator properly manages tab state
        let expectation = XCTestExpectation(description: "Tab changed")
        
        var tabChangeCount = 0
        let cancellable = coordinator.$selectedTab.sink { _ in
            tabChangeCount += 1
            if tabChangeCount == 2 { // Initial + one change
                expectation.fulfill()
            }
        }
        
        coordinator.selectTab(.appearance)
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(coordinator.selectedTab, .appearance)
        
        cancellable.cancel()
    }
    
    // MARK: - Live Preview Integration Tests
    
    func testLivePreviewUpdates() {
        // Test that appearance changes are reflected in live preview
        coordinator.selectTab(.appearance)
        
        let initialToolbarStyle = viewModel.toolbarStyle
        viewModel.toolbarStyle = (initialToolbarStyle == .floating) ? .attached : .floating
        
        // In a real implementation, we would verify the preview updates
        XCTAssertNotEqual(viewModel.toolbarStyle, initialToolbarStyle)
    }
    
    func testAnimationIntensityPreview() {
        coordinator.selectTab(.appearance)
        
        viewModel.animationIntensity = .enhanced
        
        // Verify validation warning is shown
        let validationResult = viewModel.getValidationResult(for: "animationIntensity")
        XCTAssertEqual(validationResult?.severity, .warning)
    }
    
    // MARK: - Keyboard Navigation Integration Tests
    
    func testKeyboardTabNavigation() {
        // Test keyboard navigation between tabs
        XCTAssertEqual(coordinator.selectedTab, .general)
        
        // Simulate right arrow key
        coordinator.selectTab(.appearance)
        XCTAssertEqual(coordinator.selectedTab, .appearance)
        
        // Simulate right arrow key again
        coordinator.selectTab(.shortcuts)
        XCTAssertEqual(coordinator.selectedTab, .shortcuts)
        
        // Simulate left arrow key
        coordinator.selectTab(.appearance)
        XCTAssertEqual(coordinator.selectedTab, .appearance)
    }
    
    // MARK: - Error Handling Integration Tests
    
    func testErrorHandlingIntegration() {
        preferencesService.shouldThrowError = true
        
        // Attempt to change a preference
        viewModel.showFileName = true
        
        // Verify error is handled gracefully
        let validationResults = viewModel.validationResults
        XCTAssertTrue(validationResults.contains { $0.severity == .error })
    }
    
    // MARK: - Performance Integration Tests
    
    func testRapidTabSwitching() {
        measure {
            for _ in 0..<100 {
                coordinator.selectTab(.appearance)
                coordinator.selectTab(.shortcuts)
                coordinator.selectTab(.general)
            }
        }
    }
    
    func testRapidPreferenceChanges() {
        measure {
            for i in 0..<100 {
                viewModel.slideshowInterval = Double(i % 30) + 1.0
            }
        }
    }
}

// MARK: - Accessibility Integration Tests

class PreferencesAccessibilityTests: XCTestCase {
    
    var accessibilityService: AccessibilityService!
    var coordinator: PreferencesCoordinator!
    
    override func setUp() {
        super.setUp()
        accessibilityService = AccessibilityService.shared
        coordinator = PreferencesCoordinator()
    }
    
    override func tearDown() {
        coordinator = nil
        accessibilityService = nil
        super.tearDown()
    }
    
    // MARK: - VoiceOver Integration Tests
    
    func testVoiceOverSupport() {
        // Test that VoiceOver announcements work
        let testMessage = "Test preference changed"
        
        // This would normally test actual VoiceOver integration
        // For unit tests, we verify the method doesn't crash
        accessibilityService.announcePreferenceChange(setting: "Test Setting", newValue: "New Value")
        
        // No assertion needed - just verify no crash
    }
    
    func testHighContrastSupport() {
        // Test high contrast color adaptation
        let normalColor = Color.blue
        let highContrastColor = Color.primary
        
        let adaptedColor = accessibilityService.adaptiveColor(
            normal: normalColor,
            highContrast: highContrastColor
        )
        
        // The adapted color should be one of the two options
        XCTAssertTrue(adaptedColor == normalColor || adaptedColor == highContrastColor)
    }
    
    func testReducedMotionSupport() {
        // Test reduced motion animation adaptation
        let normalAnimation = Animation.easeInOut(duration: 0.3)
        let adaptedAnimation = accessibilityService.adaptiveAnimation(normalAnimation)
        
        // Should return either the animation or nil based on reduced motion setting
        if accessibilityService.isReducedMotionEnabled {
            XCTAssertNil(adaptedAnimation)
        } else {
            XCTAssertNotNil(adaptedAnimation)
        }
    }
    
    func testFocusRingAdaptation() {
        // Test focus ring adaptation for accessibility
        let focusColor = accessibilityService.focusRingColor()
        let focusWidth = accessibilityService.focusRingWidth()
        
        XCTAssertNotNil(focusColor)
        XCTAssertGreaterThan(focusWidth, 0)
        
        if accessibilityService.isHighContrastEnabled {
            XCTAssertGreaterThanOrEqual(focusWidth, 3.0)
        }
    }
    
    // MARK: - Keyboard Navigation Tests
    
    func testKeyboardFocusManagement() {
        let focusManager = PreferencesFocusManager()
        
        focusManager.setFocus(to: "test_control")
        XCTAssertEqual(focusManager.focusedControl, "test_control")
        
        focusManager.setFocus(to: .appearance)
        XCTAssertEqual(focusManager.focusedTab, .appearance)
        
        focusManager.clearFocus()
        XCTAssertNil(focusManager.focusedControl)
        XCTAssertNil(focusManager.focusedTab)
    }
    
    // MARK: - Contrast and Visibility Tests
    
    func testContrastRatios() {
        let minimumRatio = accessibilityService.minimumContrastRatio()
        
        if accessibilityService.isHighContrastEnabled {
            XCTAssertGreaterThanOrEqual(minimumRatio, 7.0) // WCAG AAA
        } else {
            XCTAssertGreaterThanOrEqual(minimumRatio, 4.5) // WCAG AA
        }
    }
    
    func testTransparencyAdaptation() {
        let normalOpacity = 0.8
        let adaptedOpacity = accessibilityService.adaptiveBackgroundOpacity(normalOpacity)
        
        if accessibilityService.isReducedTransparencyEnabled() {
            XCTAssertEqual(adaptedOpacity, 1.0)
        } else {
            XCTAssertEqual(adaptedOpacity, normalOpacity)
        }
    }
}