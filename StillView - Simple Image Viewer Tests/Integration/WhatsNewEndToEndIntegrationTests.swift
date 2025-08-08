//
//  WhatsNewEndToEndIntegrationTests.swift
//  StillView - Simple Image Viewer Tests
//
//  Created by Kiro on 8/7/25.
//

import XCTest
import SwiftUI
@testable import Simple_Image_Viewer

/// Comprehensive end-to-end integration tests for the What's New feature
/// covering complete user workflows, version upgrade scenarios, UserDefaults persistence,
/// and performance impact on app launch time.
/// Requirements: 1.1, 1.4, 1.5, 2.1, 2.2, 6.1, 6.2
final class WhatsNewEndToEndIntegrationTests: XCTestCase {
    
    // MARK: - Properties
    
    private var whatsNewService: WhatsNewService!
    private var versionTracker: VersionTracker!
    private var contentProvider: WhatsNewContentProvider!
    private var testUserDefaults: UserDefaults!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // Create isolated UserDefaults for testing
        testUserDefaults = UserDefaults(suiteName: "WhatsNewEndToEndTests")!
        testUserDefaults.removePersistentDomain(forName: "WhatsNewEndToEndTests")
        
        // Initialize components with test dependencies
        versionTracker = VersionTracker(userDefaults: testUserDefaults)
        contentProvider = WhatsNewContentProvider()
        whatsNewService = WhatsNewService(
            versionTracker: versionTracker,
            contentProvider: contentProvider
        )
    }
    
    override func tearDown() {
        // Clean up test data
        testUserDefaults.removePersistentDomain(forName: "WhatsNewEndToEndTests")
        
        whatsNewService = nil
        versionTracker = nil
        contentProvider = nil
        testUserDefaults = nil
        
        super.tearDown()
    }
    
    // MARK: - Complete User Workflow Tests (Requirements: 1.1, 1.4, 1.5)
    
    func testCompleteAutomaticPopupWorkflow() {
        // Given: Fresh install scenario (no previous version stored)
        XCTAssertNil(testUserDefaults.string(forKey: "LastShownWhatsNewVersion"), 
                    "Should start with no stored version")
        
        // When: App launches for the first time
        let shouldShowOnFirstLaunch = whatsNewService.shouldShowWhatsNew()
        
        // Then: What's New should be shown automatically
        XCTAssertTrue(shouldShowOnFirstLaunch, "Should show What's New on first launch")
        
        // When: User views and dismisses What's New
        whatsNewService.markWhatsNewAsShown()
        
        // Then: Version should be persisted
        let storedVersion = testUserDefaults.string(forKey: "LastShownWhatsNewVersion")
        XCTAssertNotNil(storedVersion, "Version should be stored after dismissal")
        XCTAssertEqual(storedVersion, Bundle.main.appVersion, "Should store current app version")
        
        // When: App launches again with same version
        let shouldShowOnSecondLaunch = whatsNewService.shouldShowWhatsNew()
        
        // Then: What's New should not be shown again
        XCTAssertFalse(shouldShowOnSecondLaunch, "Should not show What's New again for same version")
    }
    
    func testCompleteHelpMenuWorkflow() {
        // Given: App is running (any version state)
        let initialShouldShow = whatsNewService.shouldShowWhatsNew()
        
        // When: User accesses What's New via Help menu
        let content = whatsNewService.getWhatsNewContent()
        
        // Then: Content should be available regardless of automatic popup state
        XCTAssertNotNil(content, "Content should be available via Help menu")
        XCTAssertFalse(content!.version.isEmpty, "Content should have valid version")
        XCTAssertFalse(content!.sections.isEmpty, "Content should have sections")
        
        // When: User shows What's New sheet via Help menu
        var notificationReceived = false
        let expectation = XCTestExpectation(description: "Show What's New notification")
        
        let observer = NotificationCenter.default.addObserver(
            forName: .showWhatsNew,
            object: nil,
            queue: .main
        ) { _ in
            notificationReceived = true
            expectation.fulfill()
        }
        
        whatsNewService.showWhatsNewSheet()
        
        // Then: Sheet should be presented
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(notificationReceived, "Show What's New notification should be posted")
        
        // When: User dismisses sheet from Help menu
        whatsNewService.markWhatsNewAsShown()
        
        // Then: Automatic popup state should be updated
        let shouldShowAfterHelpMenuDismissal = whatsNewService.shouldShowWhatsNew()
        XCTAssertFalse(shouldShowAfterHelpMenuDismissal, 
                      "Automatic popup should be disabled after Help menu dismissal")
        
        // Cleanup
        NotificationCenter.default.removeObserver(observer)
    }
    
    func testCompleteVersionUpgradeWorkflow() {
        // Given: User has used app before (simulate old version)
        testUserDefaults.set("1.0.0", forKey: "LastShownWhatsNewVersion")
        
        // When: App is updated to new version (current version is newer)
        let shouldShowAfterUpgrade = whatsNewService.shouldShowWhatsNew()
        
        // Then: What's New should be shown for the upgrade
        XCTAssertTrue(shouldShowAfterUpgrade, "Should show What's New after version upgrade")
        
        // When: User views and dismisses What's New
        whatsNewService.markWhatsNewAsShown()
        
        // Then: New version should be stored
        let storedVersion = testUserDefaults.string(forKey: "LastShownWhatsNewVersion")
        XCTAssertEqual(storedVersion, Bundle.main.appVersion, "Should store new version")
        
        // When: App launches again with same new version
        let shouldShowAfterUpgradeAndDismissal = whatsNewService.shouldShowWhatsNew()
        
        // Then: What's New should not be shown again
        XCTAssertFalse(shouldShowAfterUpgradeAndDismissal, 
                      "Should not show What's New again after upgrade dismissal")
    }
    
    // MARK: - UserDefaults Persistence Tests (Requirements: 6.1, 6.2)
    
    func testUserDefaultsPersistenceAcrossAppLaunches() {
        // Given: Fresh UserDefaults
        XCTAssertNil(testUserDefaults.string(forKey: "LastShownWhatsNewVersion"))
        
        // When: What's New is shown and dismissed
        whatsNewService.markWhatsNewAsShown()
        
        // Then: Version should be persisted immediately
        let storedVersion = testUserDefaults.string(forKey: "LastShownWhatsNewVersion")
        XCTAssertNotNil(storedVersion, "Version should be stored immediately")
        XCTAssertEqual(storedVersion, Bundle.main.appVersion, "Should store current version")
        
        // When: Creating new service instance (simulating app restart)
        let newVersionTracker = VersionTracker(userDefaults: testUserDefaults)
        let newService = WhatsNewService(
            versionTracker: newVersionTracker,
            contentProvider: contentProvider
        )
        
        // Then: Previous version should be remembered
        let shouldShowAfterRestart = newService.shouldShowWhatsNew()
        XCTAssertFalse(shouldShowAfterRestart, "Should remember dismissal after restart")
        
        // And: Stored version should still be accessible
        let retrievedVersion = newVersionTracker.getLastShownVersion()
        XCTAssertEqual(retrievedVersion, Bundle.main.appVersion, "Should retrieve stored version")
    }
    
    func testUserDefaultsCorruptionHandling() {
        // Given: Corrupted data in UserDefaults
        testUserDefaults.set(NSData(), forKey: "LastShownWhatsNewVersion") // Invalid data type
        
        // When: Service attempts to read version
        let retrievedVersion = versionTracker.getLastShownVersion()
        
        // Then: Should handle corruption gracefully
        XCTAssertNil(retrievedVersion, "Should return nil for corrupted data")
        
        // When: Service checks if What's New should be shown
        let shouldShow = whatsNewService.shouldShowWhatsNew()
        
        // Then: Should default to showing (fail-safe behavior)
        XCTAssertTrue(shouldShow, "Should show What's New when data is corrupted (fail-safe)")
        
        // When: Version is marked as shown
        whatsNewService.markWhatsNewAsShown()
        
        // Then: Should recover and store valid data
        let newRetrievedVersion = versionTracker.getLastShownVersion()
        XCTAssertNotNil(newRetrievedVersion, "Should recover and store valid version")
        XCTAssertEqual(newRetrievedVersion, Bundle.main.appVersion, "Should store current version")
    }
    
    // MARK: - Performance Impact Tests (Requirements: 1.1, 1.4, 1.5)
    
    func testAppLaunchTimeImpact() {
        // Given: Performance measurement setup
        let iterations = 10
        var launchTimes: [TimeInterval] = []
        
        for _ in 0..<iterations {
            // When: Measuring launch sequence performance
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Simulate app launch sequence
            let shouldShow = whatsNewService.shouldShowWhatsNew()
            let content = whatsNewService.getWhatsNewContent()
            
            let endTime = CFAbsoluteTimeGetCurrent()
            let launchTime = endTime - startTime
            launchTimes.append(launchTime)
            
            // Verify functionality works
            XCTAssertNotNil(content, "Content should be available during performance test")
        }
        
        // Then: Performance should meet requirements
        let averageLaunchTime = launchTimes.reduce(0, +) / Double(launchTimes.count)
        let maxLaunchTime = launchTimes.max() ?? 0
        
        XCTAssertLessThan(averageLaunchTime, 0.1, 
                         "Average What's New check should take less than 100ms")
        XCTAssertLessThan(maxLaunchTime, 0.2, 
                         "Maximum What's New check should take less than 200ms")
        
        print("What's New performance - Average: \(averageLaunchTime * 1000)ms, Max: \(maxLaunchTime * 1000)ms")
    }
    
    func testVersionUpgradeScenarios_DifferentFormats() {
        let versionTestCases: [(old: String, new: String, shouldShow: Bool, description: String)] = [
            // Major version upgrades
            ("1.0.0", "2.0.0", true, "major version upgrade"),
            ("1.5.3", "2.0.0", true, "major version upgrade with patch"),
            
            // Minor version upgrades
            ("1.0.0", "1.1.0", true, "minor version upgrade"),
            ("1.2.0", "1.3.0", true, "minor version upgrade"),
            
            // Patch version upgrades
            ("1.0.0", "1.0.1", true, "patch version upgrade"),
            ("1.2.3", "1.2.4", true, "patch version upgrade"),
            
            // Same version (no upgrade)
            ("1.0.0", "1.0.0", false, "same version"),
            ("1.2.3", "1.2.3", false, "same version with patch"),
            
            // Edge cases
            ("", "1.0.0", true, "empty old version (first install)"),
            ("1.0.0", "", false, "empty new version (should not show)")
        ]
        
        for testCase in versionTestCases {
            // Given: Clean test environment
            testUserDefaults.removePersistentDomain(forName: "WhatsNewEndToEndTests")
            
            // Set old version if not empty
            if !testCase.old.isEmpty {
                testUserDefaults.set(testCase.old, forKey: "LastShownWhatsNewVersion")
            }
            
            // Create version tracker with mock current version
            let mockVersionTracker = MockVersionTracker()
            mockVersionTracker.currentVersion = testCase.new
            mockVersionTracker.lastShownVersion = testCase.old.isEmpty ? nil : testCase.old
            
            let testService = WhatsNewService(
                versionTracker: mockVersionTracker,
                contentProvider: contentProvider
            )
            
            // When: Checking if What's New should be shown
            let shouldShow = testService.shouldShowWhatsNew()
            
            // Then: Result should match expectation
            XCTAssertEqual(shouldShow, testCase.shouldShow, 
                          "Failed for \(testCase.description): \(testCase.old) -> \(testCase.new)")
        }
    }
    
    // MARK: - Integration with App Lifecycle Tests
    
    func testCompleteAppLifecycleIntegration() {
        // Given: Complete app lifecycle simulation
        let lifecycleExpectation = XCTestExpectation(description: "Complete lifecycle")
        
        DispatchQueue.main.async {
            // 1. App Launch
            let shouldShowOnLaunch = self.whatsNewService.shouldShowWhatsNew()
            XCTAssertTrue(shouldShowOnLaunch, "Should show on first launch")
            
            // 2. User sees What's New and dismisses
            self.whatsNewService.markWhatsNewAsShown()
            
            // 3. App continues running
            let shouldShowAfterDismissal = self.whatsNewService.shouldShowWhatsNew()
            XCTAssertFalse(shouldShowAfterDismissal, "Should not show after dismissal")
            
            // 4. User accesses via Help menu
            let content = self.whatsNewService.getWhatsNewContent()
            XCTAssertNotNil(content, "Content should be available via Help menu")
            
            // 5. App is terminated and relaunched (same version)
            let newService = WhatsNewService(
                versionTracker: VersionTracker(userDefaults: self.testUserDefaults),
                contentProvider: WhatsNewContentProvider()
            )
            
            let shouldShowAfterRelaunch = newService.shouldShowWhatsNew()
            XCTAssertFalse(shouldShowAfterRelaunch, "Should not show after relaunch with same version")
            
            lifecycleExpectation.fulfill()
        }
        
        wait(for: [lifecycleExpectation], timeout: 2.0)
    }
    
    // MARK: - Helper Methods
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        } else {
            return 0
        }
    }
}

// MARK: - Mock Classes for Testing

private class MockVersionTracker: VersionTrackerProtocol {
    var currentVersion: String = Bundle.main.appVersion
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
    
    func setLastShownVersion(_ version: String) throws {
        if shouldThrowError {
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }
        lastShownVersion = version
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
    
    func validateVersionFormat(_ version: String) -> Bool {
        return !version.isEmpty
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let showWhatsNew = Notification.Name("ShowWhatsNew")
    static let whatsNewDismissed = Notification.Name("WhatsNewDismissed")
}