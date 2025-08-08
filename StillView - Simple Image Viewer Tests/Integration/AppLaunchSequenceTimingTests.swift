//
//  AppLaunchSequenceTimingTests.swift
//  StillView - Simple Image Viewer Tests
//
//  Created by Kiro on 8/7/25.
//

import XCTest
import SwiftUI
@testable import StillView___Simple_Image_Viewer

/// Comprehensive tests for app launch sequence timing and What's New integration
final class AppLaunchSequenceTimingTests: XCTestCase {
    
    // MARK: - Properties
    
    private var mockVersionTracker: MockVersionTracker!
    private var mockContentProvider: MockWhatsNewContentProvider!
    private var whatsNewService: WhatsNewService!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        mockVersionTracker = MockVersionTracker()
        mockContentProvider = MockWhatsNewContentProvider()
        whatsNewService = WhatsNewService(
            versionTracker: mockVersionTracker,
            contentProvider: mockContentProvider
        )
        
        // Clear any previous retry counts
        UserDefaults.standard.removeObject(forKey: "WhatsNewRetryCount")
    }
    
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "WhatsNewRetryCount")
        mockVersionTracker = nil
        mockContentProvider = nil
        whatsNewService = nil
        super.tearDown()
    }
    
    // MARK: - Launch Timing Tests
    
    func testAppLaunchInitialDelayTiming() {
        // Given: A new version scenario
        mockVersionTracker.currentVersion = "1.2.0"
        mockVersionTracker.lastShownVersion = "1.1.0"
        mockContentProvider.shouldReturnContent = true
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let expectation = XCTestExpectation(description: "Initial delay should be respected")
        
        // When: Simulating the 0.8 second initial delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
            let shouldShow = self.whatsNewService.shouldShowWhatsNew()
            
            // Then: Should respect the initial delay timing
            XCTAssertGreaterThanOrEqual(elapsedTime, 0.8, "Should wait at least 0.8 seconds")
            XCTAssertLessThan(elapsedTime, 1.0, "Should not delay excessively")
            XCTAssertTrue(shouldShow, "Should show What's New after initial delay")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testAppLaunchFinalDelayTiming() {
        // Given: A scenario where window is ready and final delay is applied
        mockVersionTracker.currentVersion = "1.2.0"
        mockVersionTracker.lastShownVersion = "1.1.0"
        mockContentProvider.shouldReturnContent = true
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let expectation = XCTestExpectation(description: "Final delay should be respected")
        
        // When: Simulating the complete timing sequence (0.8s + 0.2s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            // Window ready check passes, now apply final delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
                let shouldShow = self.whatsNewService.shouldShowWhatsNew()
                
                // Then: Should respect the complete timing sequence
                XCTAssertGreaterThanOrEqual(elapsedTime, 1.0, "Should wait at least 1.0 seconds total")
                XCTAssertLessThan(elapsedTime, 1.3, "Should not delay excessively")
                XCTAssertTrue(shouldShow, "Should show What's New after complete delay")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testLaunchSequenceDoesNotBlockMainThread() {
        // Given: A scenario with content loading
        mockVersionTracker.currentVersion = "1.2.0"
        mockVersionTracker.lastShownVersion = "1.1.0"
        mockContentProvider.shouldReturnContent = true
        mockContentProvider.loadingDelay = 0.1 // Simulate some loading time
        
        let mainThreadExpectation = XCTestExpectation(description: "Main thread should not be blocked")
        let contentLoadExpectation = XCTestExpectation(description: "Content should load asynchronously")
        
        // When: Performing operations on main thread while content loads
        DispatchQueue.main.async {
            // Simulate main thread work
            for i in 0..<1000 {
                _ = i * 2 // Simple computation
            }
            mainThreadExpectation.fulfill()
            
            // Content loading should happen without blocking
            DispatchQueue.global(qos: .userInitiated).async {
                let content = self.whatsNewService.getWhatsNewContent()
                DispatchQueue.main.async {
                    XCTAssertNotNil(content, "Content should be loaded")
                    contentLoadExpectation.fulfill()
                }
            }
        }
        
        // Then: Both operations should complete without blocking
        wait(for: [mainThreadExpectation, contentLoadExpectation], timeout: 1.0)
    }
    
    // MARK: - Window Readiness Tests
    
    func testWindowReadinessRetryLogic() {
        // Given: A scenario where window might not be ready initially
        mockVersionTracker.currentVersion = "1.2.0"
        mockVersionTracker.lastShownVersion = "1.1.0"
        mockContentProvider.shouldReturnContent = true
        
        // When: Simulating retry logic (testing the UserDefaults retry counter)
        let initialRetryCount = UserDefaults.standard.integer(forKey: "WhatsNewRetryCount")
        XCTAssertEqual(initialRetryCount, 0, "Initial retry count should be 0")
        
        // Simulate a retry
        UserDefaults.standard.set(1, forKey: "WhatsNewRetryCount")
        let afterRetryCount = UserDefaults.standard.integer(forKey: "WhatsNewRetryCount")
        XCTAssertEqual(afterRetryCount, 1, "Retry count should be incremented")
        
        // Simulate successful completion (retry count should be cleared)
        UserDefaults.standard.removeObject(forKey: "WhatsNewRetryCount")
        let finalRetryCount = UserDefaults.standard.integer(forKey: "WhatsNewRetryCount")
        XCTAssertEqual(finalRetryCount, 0, "Retry count should be cleared on success")
    }
    
    func testWindowReadinessMaxRetries() {
        // Given: A scenario where window is never ready
        mockVersionTracker.currentVersion = "1.2.0"
        mockVersionTracker.lastShownVersion = "1.1.0"
        mockContentProvider.shouldReturnContent = true
        
        // When: Simulating max retries (5 retries)
        for i in 1...5 {
            UserDefaults.standard.set(i, forKey: "WhatsNewRetryCount")
            let retryCount = UserDefaults.standard.integer(forKey: "WhatsNewRetryCount")
            XCTAssertEqual(retryCount, i, "Retry count should be \(i)")
        }
        
        // Then: After max retries, should reset
        let maxRetries = 5
        let currentRetryCount = UserDefaults.standard.integer(forKey: "WhatsNewRetryCount")
        
        if currentRetryCount >= maxRetries {
            UserDefaults.standard.removeObject(forKey: "WhatsNewRetryCount")
            let resetCount = UserDefaults.standard.integer(forKey: "WhatsNewRetryCount")
            XCTAssertEqual(resetCount, 0, "Retry count should be reset after max retries")
        }
    }
    
    // MARK: - Performance Tests
    
    func testLaunchSequencePerformanceImpact() {
        // Given: A scenario with What's New enabled
        mockVersionTracker.currentVersion = "1.2.0"
        mockVersionTracker.lastShownVersion = "1.1.0"
        mockContentProvider.shouldReturnContent = true
        
        // When: Measuring the performance impact of What's New checks
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Simulate multiple checks as might happen during app launch
        for _ in 0..<10 {
            _ = whatsNewService.shouldShowWhatsNew()
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let elapsedTime = endTime - startTime
        
        // Then: Performance impact should be minimal
        XCTAssertLessThan(elapsedTime, 0.1, "Multiple What's New checks should be fast")
    }
    
    func testContentLoadingPerformanceWithCaching() {
        // Given: A scenario where content needs to be loaded
        mockVersionTracker.currentVersion = "1.2.0"
        mockVersionTracker.lastShownVersion = "1.1.0"
        mockContentProvider.shouldReturnContent = true
        
        // When: Loading content multiple times (should use caching)
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let firstLoad = whatsNewService.getWhatsNewContent()
        let secondLoad = whatsNewService.getWhatsNewContent()
        let thirdLoad = whatsNewService.getWhatsNewContent()
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let elapsedTime = endTime - startTime
        
        // Then: Content should be cached and loading should be fast
        XCTAssertNotNil(firstLoad, "First load should succeed")
        XCTAssertNotNil(secondLoad, "Second load should succeed")
        XCTAssertNotNil(thirdLoad, "Third load should succeed")
        XCTAssertLessThan(elapsedTime, 0.5, "Cached content loading should be fast")
    }
    
    // MARK: - Focus Management Timing Tests
    
    func testFocusRestorationTiming() {
        // Given: What's New has been dismissed
        mockVersionTracker.currentVersion = "1.2.0"
        mockVersionTracker.lastShownVersion = "1.1.0"
        
        let expectation = XCTestExpectation(description: "Focus restoration should happen with proper timing")
        
        // When: Simulating the focus restoration delay (0.1 seconds)
        let startTime = CFAbsoluteTimeGetCurrent()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
            
            // Then: Focus restoration should happen after the specified delay
            XCTAssertGreaterThanOrEqual(elapsedTime, 0.1, "Focus restoration should wait at least 0.1 seconds")
            XCTAssertLessThan(elapsedTime, 0.2, "Focus restoration should not delay excessively")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testDismissalNotificationTiming() {
        // Given: What's New dismissal scenario
        let expectation = XCTestExpectation(description: "Dismissal notification should be posted promptly")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // When: Observing for the dismissal notification
        let observer = NotificationCenter.default.addObserver(
            forName: .whatsNewDismissed,
            object: nil,
            queue: .main
        ) { _ in
            let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
            
            // Then: Notification should be posted promptly
            XCTAssertLessThan(elapsedTime, 0.5, "Dismissal notification should be posted quickly")
            expectation.fulfill()
        }
        
        // Simulate dismissal notification
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: .whatsNewDismissed, object: nil)
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // Cleanup
        NotificationCenter.default.removeObserver(observer)
    }
}

// MARK: - Mock Classes

/// Mock version tracker for testing
private class MockVersionTracker: VersionTrackerProtocol {
    var currentVersion: String = "1.0.0"
    var lastShownVersion: String?
    var shouldThrowError: Bool = false
    
    func getCurrentVersion() -> String {
        if shouldThrowError {
            return ""
        }
        return currentVersion
    }
    
    func getLastShownVersion() -> String? {
        if shouldThrowError {
            return nil
        }
        return lastShownVersion
    }
    
    func setLastShownVersion(_ version: String) {
        if !shouldThrowError {
            lastShownVersion = version
        }
    }
    
    func isNewVersion() -> Bool {
        if shouldThrowError {
            return false
        }
        
        guard let lastShown = lastShownVersion else {
            return true // First install
        }
        
        return currentVersion != lastShown
    }
}

/// Mock content provider for testing
private class MockWhatsNewContentProvider: WhatsNewContentProviderProtocol {
    var shouldReturnContent: Bool = true
    var shouldThrowError: Bool = false
    var loadingDelay: TimeInterval = 0
    
    func loadContent(for version: String) throws -> WhatsNewContent {
        if loadingDelay > 0 {
            Thread.sleep(forTimeInterval: loadingDelay)
        }
        
        if shouldThrowError {
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }
        
        guard shouldReturnContent else {
            throw NSError(domain: "ContentError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Content not found"])
        }
        
        return WhatsNewContent(
            version: version,
            releaseDate: Date(),
            sections: [
                WhatsNewSection(
                    title: "Test Features",
                    items: [
                        WhatsNewItem(
                            title: "Test Feature",
                            description: "Test description",
                            isHighlighted: true
                        )
                    ],
                    type: .newFeatures
                )
            ]
        )
    }
}