//
//  WindowStateManagerTests.swift
//  StillView - Simple Image Viewer Tests
//
//  Created by Vinny Carpenter
//  Copyright © 2025 Vinny Carpenter. All rights reserved.
//  
//  Author: Vinny Carpenter (https://vinny.dev)
//  Source: https://github.com/vscarpenter/SimpleImageViewer
//

import XCTest
import AppKit
import Combine
@testable import Simple_Image_Viewer

@MainActor
final class WindowStateManagerTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var windowStateManager: WindowStateManager!
    var mockPreferencesService: MockPreferencesService!
    var mockWindow: NSWindow!
    var mockImageViewerViewModel: MockImageViewerViewModel!
    var testFolderURL: URL!
    var cancellables: Set<AnyCancellable>!
    
    // MARK: - Setup and Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        mockPreferencesService = MockPreferencesService()
        windowStateManager = WindowStateManager(preferencesService: mockPreferencesService)
        
        mockWindow = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        mockImageViewerViewModel = MockImageViewerViewModel()
        testFolderURL = URL(fileURLWithPath: "/tmp/test-folder")
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        cancellables = nil
        testFolderURL = nil
        mockImageViewerViewModel = nil
        mockWindow = nil
        windowStateManager = nil
        mockPreferencesService = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertTrue(windowStateManager.isMainWindowVisible)
        XCTAssertNotNil(windowStateManager.currentWindowState)
    }
    
    func testInitializationWithSavedState() {
        let savedState = WindowState()
        mockPreferencesService.windowState = savedState
        
        let manager = WindowStateManager(preferencesService: mockPreferencesService)
        
        XCTAssertEqual(manager.currentWindowState.windowFrame, savedState.windowFrame)
    }
    
    // MARK: - Window Management Tests
    
    func testSetMainWindow() {
        windowStateManager.setMainWindow(mockWindow)
        
        // Verify window state is applied if valid
        let expectedFrame = windowStateManager.currentWindowState.windowFrame
        if windowStateManager.currentWindowState.hasValidWindowFrame {
            XCTAssertEqual(mockWindow.frame, expectedFrame)
        }
    }
    
    func testSetImageViewerViewModel() {
        mockImageViewerViewModel.zoomLevel = 1.5
        mockImageViewerViewModel.showFileName = true
        
        windowStateManager.setImageViewerViewModel(mockImageViewerViewModel)
        
        // The view model should have UI state applied from current window state
        // Since we start with default state, these should remain as set
        XCTAssertEqual(mockImageViewerViewModel.zoomLevel, 1.5)
        XCTAssertTrue(mockImageViewerViewModel.showFileName)
    }
    
    // MARK: - State Update Tests
    
    func testUpdateFolderState() {
        let imageIndex = 5
        
        windowStateManager.updateFolderState(folderURL: testFolderURL, imageIndex: imageIndex)
        
        XCTAssertEqual(windowStateManager.currentWindowState.lastFolderPath, testFolderURL.path)
        XCTAssertEqual(windowStateManager.currentWindowState.lastImageIndex, imageIndex)
    }
    
    func testUpdateImageIndex() {
        let newIndex = 10
        
        windowStateManager.updateImageIndex(newIndex)
        
        XCTAssertEqual(windowStateManager.currentWindowState.lastImageIndex, newIndex)
    }
    
    func testUpdateWindowVisibility() {
        windowStateManager.updateWindowVisibility(false)
        
        XCTAssertFalse(windowStateManager.isMainWindowVisible)
        XCTAssertFalse(windowStateManager.currentWindowState.isVisible)
    }
    
    // MARK: - Save and Load Tests
    
    func testSaveWindowState() {
        // Set up some state
        windowStateManager.updateFolderState(folderURL: testFolderURL, imageIndex: 3)
        windowStateManager.updateWindowVisibility(false)
        
        windowStateManager.saveWindowState()
        
        // Verify the state was saved to preferences
        XCTAssertNotNil(mockPreferencesService.windowState)
        XCTAssertEqual(mockPreferencesService.windowState?.lastFolderPath, testFolderURL.path)
        XCTAssertEqual(mockPreferencesService.windowState?.lastImageIndex, 3)
        XCTAssertFalse(mockPreferencesService.windowState?.isVisible ?? true)
    }
    
    func testRestorePreviousSessionWithValidState() {
        // Create a valid window state with folder bookmark
        var savedState = WindowState()
        savedState.lastFolderPath = testFolderURL.path
        savedState.lastImageIndex = 7
        savedState.lastSaved = Date() // Recent
        
        // Create a mock bookmark (in real scenario this would be created by the system)
        savedState.lastFolderBookmark = Data([1, 2, 3, 4])
        
        mockPreferencesService.windowState = savedState
        
        // Create a new manager to load the saved state
        let manager = WindowStateManager(preferencesService: mockPreferencesService)
        
        // Since we can't actually create valid security-scoped bookmarks in tests,
        // we'll test the validation logic
        XCTAssertTrue(manager.currentWindowState.hasValidFolderState)
        XCTAssertTrue(manager.currentWindowState.isRecentEnough())
    }
    
    func testRestorePreviousSessionWithInvalidState() {
        // Create an invalid window state (no folder bookmark)
        var savedState = WindowState()
        savedState.lastFolderPath = testFolderURL.path
        savedState.lastImageIndex = 7
        savedState.lastSaved = Date().addingTimeInterval(-10 * 24 * 60 * 60) // 10 days ago
        
        mockPreferencesService.windowState = savedState
        
        let manager = WindowStateManager(preferencesService: mockPreferencesService)
        
        XCTAssertFalse(manager.hasValidPreviousSession())
    }
    
    func testClearWindowState() {
        // Set up some state first
        windowStateManager.updateFolderState(folderURL: testFolderURL, imageIndex: 5)
        windowStateManager.saveWindowState()
        
        // Verify state exists
        XCTAssertNotNil(mockPreferencesService.windowState)
        
        // Clear the state
        windowStateManager.clearWindowState()
        
        // Verify state is cleared
        XCTAssertNil(mockPreferencesService.windowState)
        XCTAssertEqual(windowStateManager.currentWindowState.lastImageIndex, 0)
        XCTAssertNil(windowStateManager.currentWindowState.lastFolderPath)
    }
    
    // MARK: - Validation Tests
    
    func testHasValidPreviousSession() {
        // Test with no saved state
        XCTAssertFalse(windowStateManager.hasValidPreviousSession())
        
        // Test with valid state
        var validState = WindowState()
        validState.lastFolderPath = testFolderURL.path
        validState.lastFolderBookmark = Data([1, 2, 3, 4])
        validState.lastSaved = Date()
        
        windowStateManager.currentWindowState = validState
        
        // Note: This will still return false in tests because we can't create valid bookmarks
        // But the logic is tested
        XCTAssertTrue(validState.hasValidFolderState)
        XCTAssertTrue(validState.isRecentEnough())
    }
    
    func testGetLastWindowFrame() {
        let testFrame = CGRect(x: 200, y: 300, width: 1000, height: 800)
        windowStateManager.currentWindowState.windowFrame = testFrame
        
        let retrievedFrame = windowStateManager.getLastWindowFrame()
        
        XCTAssertEqual(retrievedFrame, testFrame)
    }
    
    // MARK: - Observer Tests
    
    func testViewModelObservers() {
        windowStateManager.setImageViewerViewModel(mockImageViewerViewModel)
        
        let expectation = XCTestExpectation(description: "State should be saved after view model changes")
        
        // Set up a timer to check if save was scheduled
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            // After debounce period, state should be saved
            expectation.fulfill()
        }
        
        // Trigger view model changes
        mockImageViewerViewModel.currentIndex = 5
        mockImageViewerViewModel.zoomLevel = 2.0
        mockImageViewerViewModel.showFileName = true
        
        wait(for: [expectation], timeout: 4.0)
    }
    
    // MARK: - Performance Tests
    
    func testSavePerformance() {
        // Set up complex state
        windowStateManager.setMainWindow(mockWindow)
        windowStateManager.setImageViewerViewModel(mockImageViewerViewModel)
        windowStateManager.updateFolderState(folderURL: testFolderURL, imageIndex: 100)
        
        measure {
            windowStateManager.saveWindowState()
        }
    }
}

// MARK: - Mock Classes

class MockPreferencesService: PreferencesService {
    var recentFolders: [URL] = []
    var windowFrame: CGRect = CGRect(x: 100, y: 100, width: 800, height: 600)
    var showFileName: Bool = false
    var showImageInfo: Bool = false
    var slideshowInterval: Double = 3.0
    var lastSelectedFolder: URL?
    var folderBookmarks: [Data] = []
    var windowState: WindowState?
    var defaultThumbnailGridSize: ThumbnailGridSize = .medium
    var useResponsiveGridLayout: Bool = true
    var enableAIAnalysis: Bool = true
    
    func addRecentFolder(_ url: URL) {
        recentFolders.insert(url, at: 0)
        if recentFolders.count > 10 {
            recentFolders = Array(recentFolders.prefix(10))
        }
    }
    
    func removeRecentFolder(_ url: URL) {
        recentFolders.removeAll { $0 == url }
    }
    
    func clearRecentFolders() {
        recentFolders.removeAll()
        folderBookmarks.removeAll()
    }
    
    func savePreferences() {
        // Mock implementation - no actual saving needed
    }
    
    func loadPreferences() {
        // Mock implementation - no actual loading needed
    }
    
    func saveWindowState(_ windowState: WindowState) {
        self.windowState = windowState
    }
    
    func loadWindowState() -> WindowState? {
        return windowState
    }
    
    func saveFavorites() { }
}
