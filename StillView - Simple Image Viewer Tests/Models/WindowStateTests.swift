//
//  WindowStateTests.swift
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
@testable import Simple_Image_Viewer

final class WindowStateTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var windowState: WindowState!
    var testFolderURL: URL!
    var mockImageViewerViewModel: MockImageViewerViewModel!
    
    // MARK: - Setup and Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        windowState = WindowState()
        testFolderURL = URL(fileURLWithPath: "/tmp/test-folder")
        mockImageViewerViewModel = MockImageViewerViewModel()
    }
    
    override func tearDownWithError() throws {
        windowState = nil
        testFolderURL = nil
        mockImageViewerViewModel = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Initialization Tests
    
    func testDefaultInitialization() {
        let state = WindowState()
        
        XCTAssertEqual(state.windowFrame, CGRect(x: 100, y: 100, width: 800, height: 600))
        XCTAssertTrue(state.isVisible)
        XCTAssertFalse(state.isFullscreen)
        XCTAssertEqual(state.zoomLevel, 1.0)
        XCTAssertNil(state.lastFolderBookmark)
        XCTAssertNil(state.lastFolderPath)
        XCTAssertEqual(state.lastImageIndex, 0)
        XCTAssertFalse(state.showFileName)
        XCTAssertFalse(state.showImageInfo)
        XCTAssertEqual(state.viewMode, "normal")
        XCTAssertFalse(state.wasInSlideshow)
        XCTAssertEqual(state.slideshowInterval, 3.0)
        XCTAssertNotNil(state.lastSaved)
        XCTAssertNotNil(state.appVersion)
    }
    
    func testInitializationWithParameters() {
        // Create a mock window
        let window = NSWindow(
            contentRect: NSRect(x: 200, y: 300, width: 1000, height: 800),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        // Configure mock view model
        mockImageViewerViewModel.zoomLevel = 2.0
        mockImageViewerViewModel.showFileName = true
        mockImageViewerViewModel.showImageInfo = true
        mockImageViewerViewModel.viewMode = .grid
        mockImageViewerViewModel.isSlideshow = true
        mockImageViewerViewModel.slideshowInterval = 5.0
        
        let state = WindowState(
            window: window,
            folderURL: testFolderURL,
            imageIndex: 5,
            viewModel: mockImageViewerViewModel
        )
        
        XCTAssertEqual(state.windowFrame, window.frame)
        XCTAssertEqual(state.lastFolderPath, testFolderURL.path)
        XCTAssertEqual(state.lastImageIndex, 5)
        XCTAssertEqual(state.zoomLevel, 2.0)
        XCTAssertTrue(state.showFileName)
        XCTAssertTrue(state.showImageInfo)
        XCTAssertEqual(state.viewMode, "grid")
        XCTAssertTrue(state.wasInSlideshow)
        XCTAssertEqual(state.slideshowInterval, 5.0)
    }
    
    // MARK: - State Update Tests
    
    func testUpdateWindowFrame() {
        let newFrame = CGRect(x: 300, y: 400, width: 1200, height: 900)
        let originalDate = windowState.lastSaved
        
        // Wait a moment to ensure timestamp changes
        Thread.sleep(forTimeInterval: 0.01)
        
        windowState.updateWindowFrame(newFrame)
        
        XCTAssertEqual(windowState.windowFrame, newFrame)
        XCTAssertGreaterThan(windowState.lastSaved, originalDate)
    }
    
    func testUpdateVisibility() {
        let originalDate = windowState.lastSaved
        
        Thread.sleep(forTimeInterval: 0.01)
        
        windowState.updateVisibility(false)
        
        XCTAssertFalse(windowState.isVisible)
        XCTAssertGreaterThan(windowState.lastSaved, originalDate)
    }
    
    func testUpdateFullscreen() {
        let originalDate = windowState.lastSaved
        
        Thread.sleep(forTimeInterval: 0.01)
        
        windowState.updateFullscreen(true)
        
        XCTAssertTrue(windowState.isFullscreen)
        XCTAssertGreaterThan(windowState.lastSaved, originalDate)
    }
    
    func testUpdateFolderState() {
        let originalDate = windowState.lastSaved
        
        Thread.sleep(forTimeInterval: 0.01)
        
        windowState.updateFolderState(folderURL: testFolderURL, imageIndex: 10)
        
        XCTAssertEqual(windowState.lastFolderPath, testFolderURL.path)
        XCTAssertEqual(windowState.lastImageIndex, 10)
        XCTAssertGreaterThan(windowState.lastSaved, originalDate)
    }
    
    func testUpdateImageIndex() {
        let originalDate = windowState.lastSaved
        
        Thread.sleep(forTimeInterval: 0.01)
        
        windowState.updateImageIndex(15)
        
        XCTAssertEqual(windowState.lastImageIndex, 15)
        XCTAssertGreaterThan(windowState.lastSaved, originalDate)
    }
    
    func testUpdateUIStateFromViewModel() {
        mockImageViewerViewModel.zoomLevel = 1.5
        mockImageViewerViewModel.showFileName = true
        mockImageViewerViewModel.showImageInfo = false
        mockImageViewerViewModel.viewMode = .thumbnailStrip
        mockImageViewerViewModel.isSlideshow = false
        mockImageViewerViewModel.slideshowInterval = 4.0
        
        let originalDate = windowState.lastSaved
        
        Thread.sleep(forTimeInterval: 0.01)
        
        windowState.updateUIState(from: mockImageViewerViewModel)
        
        XCTAssertEqual(windowState.zoomLevel, 1.5)
        XCTAssertTrue(windowState.showFileName)
        XCTAssertFalse(windowState.showImageInfo)
        XCTAssertEqual(windowState.viewMode, "thumbnailStrip")
        XCTAssertFalse(windowState.wasInSlideshow)
        XCTAssertEqual(windowState.slideshowInterval, 4.0)
        XCTAssertGreaterThan(windowState.lastSaved, originalDate)
    }
    
    // MARK: - Restoration Tests
    
    func testRestoreWindowState() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        // Set up window state with valid frame
        windowState.windowFrame = CGRect(x: 200, y: 300, width: 1000, height: 800)
        
        windowState.restoreWindowState(to: window)
        
        XCTAssertEqual(window.frame, windowState.windowFrame)
    }
    
    func testRestoreWindowStateWithInvalidFrame() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        let originalFrame = window.frame
        
        // Set up window state with invalid frame (too small)
        windowState.windowFrame = CGRect(x: 200, y: 300, width: 50, height: 50)
        
        windowState.restoreWindowState(to: window)
        
        // Window frame should not change for invalid dimensions
        XCTAssertEqual(window.frame, originalFrame)
    }
    
    func testApplyUIStateToViewModel() {
        windowState.zoomLevel = 2.5
        windowState.showFileName = true
        windowState.showImageInfo = true
        windowState.viewMode = "grid"
        windowState.slideshowInterval = 6.0
        
        windowState.applyUIState(to: mockImageViewerViewModel)
        
        XCTAssertEqual(mockImageViewerViewModel.zoomLevel, 2.5)
        XCTAssertTrue(mockImageViewerViewModel.showFileName)
        XCTAssertTrue(mockImageViewerViewModel.showImageInfo)
        XCTAssertEqual(mockImageViewerViewModel.viewMode, .grid)
        XCTAssertEqual(mockImageViewerViewModel.slideshowInterval, 6.0)
    }
    
    // MARK: - Validation Tests
    
    func testIsRecentEnough() {
        // Test with recent timestamp
        XCTAssertTrue(windowState.isRecentEnough())
        
        // Test with old timestamp
        windowState.lastSaved = Date().addingTimeInterval(-8 * 24 * 60 * 60) // 8 days ago
        XCTAssertFalse(windowState.isRecentEnough())
        
        // Test with custom max age
        windowState.lastSaved = Date().addingTimeInterval(-2 * 24 * 60 * 60) // 2 days ago
        XCTAssertTrue(windowState.isRecentEnough(maxAge: 3 * 24 * 60 * 60)) // 3 days max
        XCTAssertFalse(windowState.isRecentEnough(maxAge: 1 * 24 * 60 * 60)) // 1 day max
    }
    
    func testHasValidWindowFrame() {
        // Test valid frame
        windowState.windowFrame = CGRect(x: 100, y: 100, width: 800, height: 600)
        XCTAssertTrue(windowState.hasValidWindowFrame)
        
        // Test invalid frame (too small)
        windowState.windowFrame = CGRect(x: 100, y: 100, width: 200, height: 100)
        XCTAssertFalse(windowState.hasValidWindowFrame)
        
        // Test invalid frame (too large)
        windowState.windowFrame = CGRect(x: 100, y: 100, width: 10000, height: 8000)
        XCTAssertFalse(windowState.hasValidWindowFrame)
    }
    
    func testHasValidFolderState() {
        // Test without folder state
        XCTAssertFalse(windowState.hasValidFolderState)
        
        // Test with folder state
        windowState.lastFolderPath = "/tmp/test"
        windowState.lastFolderBookmark = Data([1, 2, 3, 4])
        XCTAssertTrue(windowState.hasValidFolderState)
        
        // Test with partial folder state
        windowState.lastFolderBookmark = nil
        XCTAssertFalse(windowState.hasValidFolderState)
    }
    
    // MARK: - Codable Tests
    
    func testCodableEncoding() throws {
        windowState.windowFrame = CGRect(x: 200, y: 300, width: 1000, height: 800)
        windowState.isVisible = false
        windowState.lastFolderPath = "/tmp/test"
        windowState.lastImageIndex = 5
        windowState.showFileName = true
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(windowState)
        
        XCTAssertFalse(data.isEmpty)
    }
    
    func testCodableDecoding() throws {
        windowState.windowFrame = CGRect(x: 200, y: 300, width: 1000, height: 800)
        windowState.isVisible = false
        windowState.lastFolderPath = "/tmp/test"
        windowState.lastImageIndex = 5
        windowState.showFileName = true
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(windowState)
        
        let decoder = JSONDecoder()
        let decodedState = try decoder.decode(WindowState.self, from: data)
        
        XCTAssertEqual(decodedState.windowFrame, windowState.windowFrame)
        XCTAssertEqual(decodedState.isVisible, windowState.isVisible)
        XCTAssertEqual(decodedState.lastFolderPath, windowState.lastFolderPath)
        XCTAssertEqual(decodedState.lastImageIndex, windowState.lastImageIndex)
        XCTAssertEqual(decodedState.showFileName, windowState.showFileName)
    }
}

// MARK: - Mock Classes

class MockImageViewerViewModel: ImageViewerViewModel {
    override init() {
        super.init()
    }
}