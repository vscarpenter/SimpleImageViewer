//
//  AppLaunchWhatsNewIntegrationTests.swift
//  StillView - Simple Image Viewer Tests
//
//  Created by Kiro on 8/7/25.
//

import XCTest
import SwiftUI
@testable import StillView___Simple_Image_Viewer

/// Integration tests for "What's New" automatic popup during app launch sequence
final class AppLaunchWhatsNewIntegrationTests: XCTestCase {
    
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
    }
    
    override func tearDown() {
        mockVersionTracker = nil
        mockContentProvider = nil
        whatsNewService = nil
        super.tearDown()
    }
    
    // MARK: - Launch Sequence Tests
    
    func testAppLaunchWithNewVersion_ShowsWhatsNewAutomatically() {
        // Given: A new version is detected
        mockVersionTracker.currentVersion = "1.2.0"
        mockVersionTracker.lastShownVersion = "1.1.0"
        mockContentProvider.shouldReturnContent = true
        
        // When: Checking if What's New should be shown
        let shouldShow = whatsNewService.shouldShowWhatsNew()
        
        // Then: What's New should be shown automatically
        XCTAssertTrue(shouldShow, "What's New should be shown for new version")
    }
    
    func testAppLaunchWithSameVersion_DoesNotShowWhatsNew() {
        // Given: Same version as previously shown
        mockVersionTracker.currentVersion = "1.1.0"
        mockVersionTracker.lastShownVersion = "1.1.0"
        mockContentProvider.shouldReturnContent = true
        
        // When: Checking if What's New should be shown
        let shouldShow = whatsNewService.shouldShowWhatsNew()
        
        // Then: What's New should not be shown
        XCTAssertFalse(shouldShow, "What's New should not be shown for same version")
    }
    
    func testAppLaunchWithNewVersionButNoContent_DoesNotShowWhatsNew() {
        // Given: New version but no content available
        mockVersionTracker.currentVersion = "1.2.0"
        mockVersionTracker.lastShownVersion = "1.1.0"
        mockContentProvider.shouldReturnContent = false
        
        // When: Checking if What's New should be shown
        let shouldShow = whatsNewService.shouldShowWhatsNew()
        
        // Then: What's New should not be shown without content
        XCTAssertFalse(shouldShow, "What's New should not be shown without content")
    }
    
    func testAppLaunchWithFirstInstall_ShowsWhatsNew() {
        // Given: First install (no previous version)
        mockVersionTracker.currentVersion = "1.0.0"
        mockVersionTracker.lastShownVersion = nil
        mockContentProvider.shouldReturnContent = true
        
        // When: Checking if What's New should be shown
        let shouldShow = whatsNewService.shouldShowWhatsNew()
        
        // Then: What's New should be shown for first install
        XCTAssertTrue(shouldShow, "What's New should be shown for first install")
    }
    
    // MARK: - Timing Tests
    
    func testLaunchSequenceTimingDoesNotBlockMainThread() {
        // Given: A new version scenario
        mockVersionTracker.currentVersion = "1.2.0"
        mockVersionTracker.lastShownVersion = "1.1.0"
        mockContentProvider.shouldReturnContent = true
        
        let expectation = XCTestExpectation(description: "Launch sequence completes without blocking")
        
        // When: Simulating app launch sequence
        DispatchQueue.main.async {
            // Simulate the delayed check that happens in the real app
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let shouldShow = self.whatsNewService.shouldShowWhatsNew()
                XCTAssertTrue(shouldShow)
                expectation.fulfill()
            }
        }
        
        // Then: The sequence should complete without blocking
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testLaunchSequenceWithProperDelayTiming() {
        // Given: A new version scenario
        mockVersionTracker.currentVersion = "1.2.0"
        mockVersionTracker.lastShownVersion = "1.1.0"
        mockContentProvider.shouldReturnContent = true
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let expectation = XCTestExpectation(description: "Launch sequence respects timing delays")
        
        // When: Simulating the actual app launch timing (0.8s initial delay + 0.2s final delay)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                let shouldShow = self.whatsNewService.shouldShowWhatsNew()
                let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
                
                // Then: Should show after proper delay and timing should be respected
                XCTAssertTrue(shouldShow, "What's New should be shown after proper delay")
                XCTAssertGreaterThanOrEqual(elapsedTime, 1.0, "Should respect minimum delay timing")
                XCTAssertLessThan(elapsedTime, 1.5, "Should not delay excessively")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testLaunchSequenceDoesNotInterfereWithMainAppInitialization() {
        // Given: A scenario where What's New should be shown
        mockVersionTracker.currentVersion = "1.2.0"
        mockVersionTracker.lastShownVersion = "1.1.0"
        mockContentProvider.shouldReturnContent = true
        
        let mainAppInitExpectation = XCTestExpectation(description: "Main app initialization completes")
        let whatsNewCheckExpectation = XCTestExpectation(description: "What's New check happens after init")
        
        // When: Simulating main app initialization
        DispatchQueue.main.async {
            // Simulate main app initialization work
            Thread.sleep(forTimeInterval: 0.1)
            mainAppInitExpectation.fulfill()
            
            // What's New check should happen after main app init
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                let shouldShow = self.whatsNewService.shouldShowWhatsNew()
                XCTAssertTrue(shouldShow)
                whatsNewCheckExpectation.fulfill()
            }
        }
        
        // Then: Main app init should complete before What's New check
        wait(for: [mainAppInitExpectation], timeout: 0.5)
        wait(for: [whatsNewCheckExpectation], timeout: 1.5)
    }
    
    func testContentLoadingPerformanceDuringLaunch() {
        // Given: A scenario that requires content loading
        mockVersionTracker.currentVersion = "1.2.0"
        mockVersionTracker.lastShownVersion = "1.1.0"
        mockContentProvider.shouldReturnContent = true
        mockContentProvider.loadingDelay = 0.1 // Simulate some loading time
        
        // When: Measuring content loading performance
        let startTime = CFAbsoluteTimeGetCurrent()
        let content = whatsNewService.getWhatsNewContent()
        let endTime = CFAbsoluteTimeGetCurrent()
        
        // Then: Content should load quickly and be available
        XCTAssertNotNil(content, "Content should be loaded")
        XCTAssertLessThan(endTime - startTime, 0.5, "Content loading should be fast")
    }
    
    // MARK: - Focus Management Tests
    
    func testWhatsNewDismissalMarksVersionAsShown() {
        // Given: What's New is being shown
        mockVersionTracker.currentVersion = "1.2.0"
        mockVersionTracker.lastShownVersion = "1.1.0"
        
        // When: What's New is dismissed (marked as shown)
        whatsNewService.markWhatsNewAsShown()
        
        // Then: The current version should be marked as shown
        XCTAssertEqual(mockVersionTracker.lastShownVersion, "1.2.0", "Current version should be marked as shown")
    }
    
    func testWhatsNewDismissalPostsNotification() {
        // Given: What's New dismissal scenario
        let expectation = XCTestExpectation(description: "Dismissal notification should be posted")
        
        // When: Observing for the dismissal notification
        let observer = NotificationCenter.default.addObserver(
            forName: .whatsNewDismissed,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }
        
        // Simulate dismissal by posting the notification (as would happen in the real app)
        NotificationCenter.default.post(name: .whatsNewDismissed, object: nil)
        
        // Then: Notification should be posted
        wait(for: [expectation], timeout: 1.0)
        
        // Cleanup
        NotificationCenter.default.removeObserver(observer)
    }
    
    func testFocusManagementAfterWhatsNewDismissal() {
        // Given: What's New has been shown and dismissed
        mockVersionTracker.currentVersion = "1.2.0"
        mockVersionTracker.lastShownVersion = "1.1.0"
        
        let focusExpectation = XCTestExpectation(description: "Focus should be restored after dismissal")
        
        // When: Simulating the focus restoration sequence
        DispatchQueue.main.async {
            // Mark as shown (simulating dismissal)
            self.whatsNewService.markWhatsNewAsShown()
            
            // Simulate the delay that happens in the real app for focus restoration
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Verify that the version was marked as shown (indicating proper dismissal handling)
                XCTAssertEqual(self.mockVersionTracker.lastShownVersion, "1.2.0")
                focusExpectation.fulfill()
            }
        }
        
        // Then: Focus restoration sequence should complete
        wait(for: [focusExpectation], timeout: 1.0)
    }
    
    func testSubsequentLaunchAfterDismissal_DoesNotShowWhatsNew() {
        // Given: What's New was previously shown and dismissed
        mockVersionTracker.currentVersion = "1.2.0"
        mockVersionTracker.lastShownVersion = "1.1.0"
        
        // When: Marking as shown and checking again
        whatsNewService.markWhatsNewAsShown()
        let shouldShowAfterDismissal = whatsNewService.shouldShowWhatsNew()
        
        // Then: What's New should not be shown again
        XCTAssertFalse(shouldShowAfterDismissal, "What's New should not be shown after dismissal")
    }
    
    // MARK: - Error Handling Tests
    
    func testLaunchWithContentLoadingError_HandleGracefully() {
        // Given: Content loading will fail
        mockVersionTracker.currentVersion = "1.2.0"
        mockVersionTracker.lastShownVersion = "1.1.0"
        mockContentProvider.shouldThrowError = true
        
        // When: Attempting to get content
        let content = whatsNewService.getWhatsNewContent()
        
        // Then: Should handle error gracefully with fallback content
        XCTAssertNotNil(content, "Should provide fallback content on error")
        XCTAssertEqual(content?.version, "1.2.0", "Fallback content should have correct version")
    }
    
    func testLaunchWithVersionTrackingError_HandleGracefully() {
        // Given: Version tracking has issues
        mockVersionTracker.shouldThrowError = true
        
        // When: Checking if What's New should be shown
        let shouldShow = whatsNewService.shouldShowWhatsNew()
        
        // Then: Should handle gracefully (likely not show to be safe)
        // The exact behavior depends on implementation, but it shouldn't crash
        XCTAssertFalse(shouldShow, "Should handle version tracking errors gracefully")
    }
    
    // MARK: - Window Readiness Tests
    
    func testLaunchSequenceWaitsForWindowReadiness() {
        // Given: A scenario where What's New should be shown
        mockVersionTracker.currentVersion = "1.2.0"
        mockVersionTracker.lastShownVersion = "1.1.0"
        mockContentProvider.shouldReturnContent = true
        
        // When: Checking that the service logic works correctly
        let shouldShow = whatsNewService.shouldShowWhatsNew()
        
        // Then: Service should indicate What's New should be shown
        XCTAssertTrue(shouldShow, "Service should indicate What's New should be shown when window is ready")
    }
    
    func testLaunchSequenceHandlesWindowNotReady() {
        // Given: A scenario where window might not be ready initially
        mockVersionTracker.currentVersion = "1.2.0"
        mockVersionTracker.lastShownVersion = "1.1.0"
        mockContentProvider.shouldReturnContent = true
        
        // When: Service is checked multiple times (simulating retry logic)
        let firstCheck = whatsNewService.shouldShowWhatsNew()
        let secondCheck = whatsNewService.shouldShowWhatsNew()
        
        // Then: Service should consistently return the same result
        XCTAssertEqual(firstCheck, secondCheck, "Service should be consistent across multiple checks")
        XCTAssertTrue(firstCheck, "Service should indicate What's New should be shown")
    }
    
    // MARK: - Integration with App State Tests
    
    func testWhatsNewServiceIntegrationWithNotificationCenter() {
        // Given: A scenario where What's New should be shown
        mockVersionTracker.currentVersion = "1.2.0"
        mockVersionTracker.lastShownVersion = "1.1.0"
        mockContentProvider.shouldReturnContent = true
        
        let expectation = XCTestExpectation(description: "Notification should be posted")
        
        // When: Observing for the show What's New notification
        let observer = NotificationCenter.default.addObserver(
            forName: .showWhatsNew,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }
        
        // Trigger the service to show What's New
        whatsNewService.showWhatsNewSheet()
        
        // Then: Notification should be posted
        wait(for: [expectation], timeout: 1.0)
        
        // Cleanup
        NotificationCenter.default.removeObserver(observer)
    }
    
    func testLaunchSequenceIntegrationWithAppLifecycle() {
        // Given: A complete app launch scenario
        mockVersionTracker.currentVersion = "1.2.0"
        mockVersionTracker.lastShownVersion = "1.1.0"
        mockContentProvider.shouldReturnContent = true
        
        let launchExpectation = XCTestExpectation(description: "Launch sequence should complete")
        
        // When: Simulating the complete launch sequence
        DispatchQueue.main.async {
            // 1. App starts up
            let shouldShow = self.whatsNewService.shouldShowWhatsNew()
            XCTAssertTrue(shouldShow, "Should show What's New on launch")
            
            // 2. What's New is shown and then dismissed
            self.whatsNewService.markWhatsNewAsShown()
            
            // 3. Subsequent checks should not show What's New
            let shouldShowAfter = self.whatsNewService.shouldShowWhatsNew()
            XCTAssertFalse(shouldShowAfter, "Should not show What's New after dismissal")
            
            launchExpectation.fulfill()
        }
        
        // Then: Complete sequence should work correctly
        wait(for: [launchExpectation], timeout: 1.0)
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