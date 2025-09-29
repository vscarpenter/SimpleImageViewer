//
//  AIInsightsStateTests.swift
//  StillView - Simple Image Viewer Tests
//
//  Created by Vinny Carpenter
//  Copyright © 2025 Vinny Carpenter. All rights reserved.
//  
//  Author: Vinny Carpenter (https://vinny.dev)
//  Source: https://github.com/vscarpenter/SimpleImageViewer
//

import XCTest
@testable import StillView___Simple_Image_Viewer

/// Tests for AI Insights state initialization and persistence
@MainActor
class AIInsightsStateTests: XCTestCase {
    
    var viewModel: ImageViewerViewModel!
    var mockPreferencesService: MockPreferencesService!
    var mockImageLoaderService: MockImageLoaderService!
    var mockErrorHandlingService: MockErrorHandlingService!
    
    override func setUp() {
        super.setUp()
        
        // Create mock services
        mockPreferencesService = MockPreferencesService()
        mockImageLoaderService = MockImageLoaderService()
        mockErrorHandlingService = MockErrorHandlingService()
        
        // Create view model with mock services
        viewModel = ImageViewerViewModel(
            imageLoaderService: mockImageLoaderService,
            preferencesService: mockPreferencesService,
            errorHandlingService: mockErrorHandlingService
        )
    }
    
    override func tearDown() {
        viewModel = nil
        mockPreferencesService = nil
        mockImageLoaderService = nil
        mockErrorHandlingService = nil
        super.tearDown()
    }
    
    // MARK: - State Initialization Tests
    
    func testAIInsightsStateInitializationWithEnabledPreferences() {
        // Given: AI analysis is enabled in preferences
        mockPreferencesService.enableAIAnalysis = true
        
        // When: View model is initialized
        let newViewModel = ImageViewerViewModel(
            imageLoaderService: mockImageLoaderService,
            preferencesService: mockPreferencesService,
            errorHandlingService: mockErrorHandlingService
        )
        
        // Then: AI analysis should be enabled and insights should be available on supported systems
        XCTAssertTrue(newViewModel.isAIAnalysisEnabled, "AI analysis should be enabled when preference is true")
        
        // AI Insights availability depends on system compatibility
        if #available(macOS 26.0, *) {
            // On supported systems, AI Insights should be available when analysis is enabled
            XCTAssertTrue(newViewModel.isAIInsightsAvailable, "AI Insights should be available on macOS 26+ when analysis is enabled")
        } else {
            // On unsupported systems, AI Insights should not be available
            XCTAssertFalse(newViewModel.isAIInsightsAvailable, "AI Insights should not be available on macOS < 26")
        }
        
        // Panel should start hidden by default
        XCTAssertFalse(newViewModel.showAIInsights, "AI Insights panel should start hidden by default")
    }
    
    func testAIInsightsStateInitializationWithDisabledPreferences() {
        // Given: AI analysis is disabled in preferences
        mockPreferencesService.enableAIAnalysis = false
        
        // When: View model is initialized
        let newViewModel = ImageViewerViewModel(
            imageLoaderService: mockImageLoaderService,
            preferencesService: mockPreferencesService,
            errorHandlingService: mockErrorHandlingService
        )
        
        // Then: AI analysis should be disabled and insights should not be available
        XCTAssertFalse(newViewModel.isAIAnalysisEnabled, "AI analysis should be disabled when preference is false")
        XCTAssertFalse(newViewModel.isAIInsightsAvailable, "AI Insights should not be available when analysis is disabled")
        XCTAssertFalse(newViewModel.showAIInsights, "AI Insights panel should be hidden when analysis is disabled")
    }
    
    // MARK: - Panel Visibility Tests
    
    func testToggleAIInsightsWhenAvailable() {
        // Given: AI Insights is available
        mockPreferencesService.enableAIAnalysis = true
        viewModel.updateAIInsightsAvailability()
        
        // Skip test if not on supported system
        guard viewModel.isAIInsightsAvailable else {
            throw XCTSkip("AI Insights not available on this system")
        }
        
        // When: Toggling AI Insights
        let initialState = viewModel.showAIInsights
        viewModel.toggleAIInsights()
        
        // Then: State should change
        XCTAssertNotEqual(viewModel.showAIInsights, initialState, "AI Insights panel visibility should toggle")
        
        // When: Toggling again
        let secondState = viewModel.showAIInsights
        viewModel.toggleAIInsights()
        
        // Then: State should return to original
        XCTAssertEqual(viewModel.showAIInsights, initialState, "AI Insights panel should return to original state")
    }
    
    func testToggleAIInsightsWhenNotAvailable() {
        // Given: AI Insights is not available
        mockPreferencesService.enableAIAnalysis = false
        viewModel.updateAIInsightsAvailability()
        
        // When: Attempting to toggle AI Insights
        let initialState = viewModel.showAIInsights
        viewModel.toggleAIInsights()
        
        // Then: State should not change
        XCTAssertEqual(viewModel.showAIInsights, initialState, "AI Insights panel should not toggle when not available")
        XCTAssertFalse(viewModel.showAIInsights, "AI Insights panel should remain hidden when not available")
    }
    
    // MARK: - State Restoration Tests
    
    func testRestoreAIInsightsStateWhenAvailable() {
        // Given: AI Insights is available
        mockPreferencesService.enableAIAnalysis = true
        viewModel.updateAIInsightsAvailability()
        
        // Skip test if not on supported system
        guard viewModel.isAIInsightsAvailable else {
            throw XCTSkip("AI Insights not available on this system")
        }
        
        // When: Restoring state to show panel
        viewModel.restoreAIInsightsState(true)
        
        // Then: Panel should be visible
        XCTAssertTrue(viewModel.showAIInsights, "AI Insights panel should be visible after restoring to true")
        
        // When: Restoring state to hide panel
        viewModel.restoreAIInsightsState(false)
        
        // Then: Panel should be hidden
        XCTAssertFalse(viewModel.showAIInsights, "AI Insights panel should be hidden after restoring to false")
    }
    
    func testRestoreAIInsightsStateWhenNotAvailable() {
        // Given: AI Insights is not available
        mockPreferencesService.enableAIAnalysis = false
        viewModel.updateAIInsightsAvailability()
        
        // When: Attempting to restore state to show panel
        viewModel.restoreAIInsightsState(true)
        
        // Then: Panel should remain hidden
        XCTAssertFalse(viewModel.showAIInsights, "AI Insights panel should remain hidden when not available, even when restoring to true")
    }
    
    // MARK: - Preference Change Tests
    
    func testPreferenceChangeFromEnabledToDisabled() {
        // Given: AI analysis is initially enabled
        mockPreferencesService.enableAIAnalysis = true
        viewModel.updateAIInsightsAvailability()
        
        // Skip test if not on supported system
        guard viewModel.isAIInsightsAvailable else {
            throw XCTSkip("AI Insights not available on this system")
        }
        
        // And: Panel is visible
        viewModel.toggleAIInsights()
        XCTAssertTrue(viewModel.showAIInsights, "Panel should be visible initially")
        
        // When: AI analysis is disabled
        mockPreferencesService.enableAIAnalysis = false
        NotificationCenter.default.post(name: .aiAnalysisPreferenceDidChange, object: false)
        
        // Give notification time to process
        let expectation = XCTestExpectation(description: "Preference change processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then: AI Insights should be disabled and panel hidden
        XCTAssertFalse(viewModel.isAIAnalysisEnabled, "AI analysis should be disabled")
        XCTAssertFalse(viewModel.isAIInsightsAvailable, "AI Insights should not be available")
        XCTAssertFalse(viewModel.showAIInsights, "AI Insights panel should be hidden")
    }
    
    func testPreferenceChangeFromDisabledToEnabled() {
        // Given: AI analysis is initially disabled
        mockPreferencesService.enableAIAnalysis = false
        viewModel.updateAIInsightsAvailability()
        XCTAssertFalse(viewModel.isAIInsightsAvailable, "AI Insights should not be available initially")
        
        // When: AI analysis is enabled
        mockPreferencesService.enableAIAnalysis = true
        NotificationCenter.default.post(name: .aiAnalysisPreferenceDidChange, object: true)
        
        // Give notification time to process
        let expectation = XCTestExpectation(description: "Preference change processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then: AI analysis should be enabled
        XCTAssertTrue(viewModel.isAIAnalysisEnabled, "AI analysis should be enabled")
        
        // AI Insights availability depends on system compatibility
        if #available(macOS 26.0, *) {
            XCTAssertTrue(viewModel.isAIInsightsAvailable, "AI Insights should be available on supported systems")
        } else {
            XCTAssertFalse(viewModel.isAIInsightsAvailable, "AI Insights should not be available on unsupported systems")
        }
    }
    
    // MARK: - Session Management Tests
    
    func testNewSessionInitialization() {
        // Given: AI Insights is available and panel persistence is disabled
        mockPreferencesService.enableAIAnalysis = true
        mockPreferencesService.rememberAIInsightsPanelState = false
        viewModel.updateAIInsightsAvailability()
        
        // Skip test if not on supported system
        guard viewModel.isAIInsightsAvailable else {
            throw XCTSkip("AI Insights not available on this system")
        }
        
        // And: Panel is currently visible
        viewModel.restoreAIInsightsState(true)
        XCTAssertTrue(viewModel.showAIInsights, "Panel should be visible initially")
        
        // When: Loading new folder content (simulating new session)
        let mockFolderContent = FolderContent(
            folderURL: URL(fileURLWithPath: "/tmp/test"),
            imageFiles: [],
            currentIndex: 0
        )
        viewModel.loadFolderContent(mockFolderContent)
        
        // Then: Panel should be reset to hidden (since persistence is disabled)
        XCTAssertFalse(viewModel.showAIInsights, "Panel should be hidden for new session when persistence is disabled")
    }
    
    func testSessionEndCleanup() {
        // Given: AI Insights is available and panel is visible
        mockPreferencesService.enableAIAnalysis = true
        viewModel.updateAIInsightsAvailability()
        
        // Skip test if not on supported system
        guard viewModel.isAIInsightsAvailable else {
            throw XCTSkip("AI Insights not available on this system")
        }
        
        viewModel.restoreAIInsightsState(true)
        XCTAssertTrue(viewModel.showAIInsights, "Panel should be visible initially")
        
        // When: Clearing content (simulating session end)
        viewModel.clearContent()
        
        // Then: Panel should be hidden
        XCTAssertFalse(viewModel.showAIInsights, "Panel should be hidden after clearing content")
    }
}

// MARK: - Mock Services

class MockPreferencesService: PreferencesService {
    var recentFolders: [URL] = []
    var windowFrame: CGRect = CGRect(x: 0, y: 0, width: 800, height: 600)
    var showFileName: Bool = false
    var showImageInfo: Bool = false
    var slideshowInterval: Double = 3.0
    var lastSelectedFolder: URL?
    var folderBookmarks: [Data] = []
    var windowState: WindowState?
    var defaultThumbnailGridSize: ThumbnailGridSize = .medium
    var useResponsiveGridLayout: Bool = true
    var enableAIAnalysis: Bool = true
    var rememberAIInsightsPanelState: Bool = true
    
    func addRecentFolder(_ url: URL) {}
    func removeRecentFolder(_ url: URL) {}
    func clearRecentFolders() {}
    func savePreferences() {}
    func loadPreferences() {}
    func saveWindowState(_ windowState: WindowState) {}
    func loadWindowState() -> WindowState? { return windowState }
    func saveFavorites() {}
}

class MockImageLoaderService: ImageLoaderService {
    func loadImage(from url: URL) -> AnyPublisher<NSImage, ImageLoaderError> {
        return Just(NSImage())
            .setFailureType(to: ImageLoaderError.self)
            .eraseToAnyPublisher()
    }
    
    func cancelLoading(for url: URL) {}
    func preloadImages(_ urls: [URL], maxCount: Int) {}
    func clearCache() {}
}

class MockErrorHandlingService: ErrorHandlingService {
    override init() {
        super.init()
    }
}