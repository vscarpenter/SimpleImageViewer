//
//  WhatsNewVersionUpgradeIntegrationTests.swift
//  StillView - Simple Image Viewer Tests
//
//  Created by Kiro on 8/7/25.
//

import XCTest
import SwiftUI
@testable import Simple_Image_Viewer

/// Integration tests specifically focused on version upgrade scenarios
/// and complex version comparison edge cases.
/// Requirements: 6.1, 6.2
final class WhatsNewVersionUpgradeIntegrationTests: XCTestCase {
    
    // MARK: - Properties
    
    private var testUserDefaults: UserDefaults!
    private var versionTracker: VersionTracker!
    private var contentProvider: WhatsNewContentProvider!
    private var whatsNewService: WhatsNewService!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        testUserDefaults = UserDefaults(suiteName: "VersionUpgradeTests")!
        testUserDefaults.removePersistentDomain(forName: "VersionUpgradeTests")
        
        versionTracker = VersionTracker(userDefaults: testUserDefaults)
        contentProvider = WhatsNewContentProvider()
        whatsNewService = WhatsNewService(
            versionTracker: versionTracker,
            contentProvider: contentProvider
        )
    }
    
    override func tearDown() {
        testUserDefaults.removePersistentDomain(forName: "VersionUpgradeTests")
        testUserDefaults = nil
        versionTracker = nil
        contentProvider = nil
        whatsNewService = nil
        super.tearDown()
    }
    
    // MARK: - Real-World Version Upgrade Scenarios
    
    func testAppStoreVersionUpgradeScenarios() {
        let realWorldScenarios: [(oldVersion: String, newVersion: String, shouldShow: Bool, scenario: String)] = [
            // Typical App Store progression
            ("1.0", "1.0.1", true, "Initial release to first patch"),
            ("1.0.1", "1.0.2", true, "Patch to patch"),
            ("1.0.2", "1.1.0", true, "Patch to minor"),
            ("1.1.0", "1.1.1", true, "Minor to patch"),
            ("1.1.1", "2.0.0", true, "Minor patch to major"),
            
            // Beta/TestFlight scenarios
            ("1.0.0", "1.1.0-beta", true, "Release to beta"),
            ("1.1.0-beta", "1.1.0-beta.2", true, "Beta to beta"),
            ("1.1.0-beta.2", "1.1.0", true, "Beta to release"),
            ("1.1.0-rc.1", "1.1.0", true, "Release candidate to release"),
            
            // Xcode version format scenarios
            ("1.0 (1)", "1.0 (2)", true, "Build number change"),
            ("1.0 (Build 1)", "1.0 (Build 2)", true, "Build with text"),
            ("1.0.0 (1A1)", "1.0.0 (1A2)", true, "Xcode-style build"),
            
            // Marketing version scenarios
            ("Version 1.0", "Version 1.1", true, "Marketing version format"),
            ("v1.0.0", "v1.0.1", true, "Git tag style"),
            ("1.0.0-release", "1.0.1-release", true, "Release suffix"),
            
            // Edge cases that should not trigger
            ("1.0.0", "1.0.0", false, "Identical versions"),
            ("1.1.0", "1.0.0", false, "Downgrade scenario"),
            
            // Complex real-world formats
            ("1.0.0 (2024.01.15)", "1.0.1 (2024.01.20)", true, "Date-based builds"),
            ("1.0.0+20240115", "1.0.1+20240120", true, "Semantic versioning with metadata"),
            ("1.0.0-alpha.1+build.1", "1.0.0-alpha.2+build.2", true, "Full semantic versioning")
        ]
        
        for scenario in realWorldScenarios {
            // Given: Clean test environment with old version
            testUserDefaults.removePersistentDomain(forName: "VersionUpgradeTests")
            testUserDefaults.set(scenario.oldVersion, forKey: "LastShownWhatsNewVersion")
            
            // Create mock version tracker with new version
            let mockTracker = MockVersionTracker()
            mockTracker.currentVersion = scenario.newVersion
            mockTracker.lastShownVersion = scenario.oldVersion
            
            let testService = WhatsNewService(
                versionTracker: mockTracker,
                contentProvider: contentProvider
            )
            
            // When: Checking if What's New should be shown
            let shouldShow = testService.shouldShowWhatsNew()
            
            // Then: Result should match expectation
            XCTAssertEqual(shouldShow, scenario.shouldShow, 
                          "Failed scenario: \(scenario.scenario) (\(scenario.oldVersion) -> \(scenario.newVersion))")
            
            // If should show, verify dismissal works
            if scenario.shouldShow {
                testService.markWhatsNewAsShown()
                let shouldShowAfterDismissal = testService.shouldShowWhatsNew()
                XCTAssertFalse(shouldShowAfterDismissal, 
                              "Should not show after dismissal for scenario: \(scenario.scenario)")
            }
        }
    }
    
    func testMultipleVersionUpgradeSequence() {
        // Given: A sequence of version upgrades over time
        let versionSequence = [
            "1.0.0",    // Initial release
            "1.0.1",    // First patch
            "1.0.2",    // Second patch
            "1.1.0",    // Minor update
            "1.1.1",    // Patch on minor
            "1.2.0",    // Another minor
            "2.0.0",    // Major update
            "2.0.1",    // Patch on major
            "2.1.0"     // Final version
        ]
        
        var previousVersion: String?
        
        for (index, currentVersion) in versionSequence.enumerated() {
            // Given: Previous version is stored (if exists)
            if let prev = previousVersion {
                testUserDefaults.set(prev, forKey: "LastShownWhatsNewVersion")
            }
            
            // Create service with current version
            let mockTracker = MockVersionTracker()
            mockTracker.currentVersion = currentVersion
            mockTracker.lastShownVersion = previousVersion
            
            let testService = WhatsNewService(
                versionTracker: mockTracker,
                contentProvider: contentProvider
            )
            
            // When: Checking if What's New should be shown
            let shouldShow = testService.shouldShowWhatsNew()
            
            // Then: Should show for all versions (each is newer than previous)
            let expectedShow = previousVersion == nil || previousVersion != currentVersion
            XCTAssertEqual(shouldShow, expectedShow, 
                          "Version \(currentVersion) (step \(index + 1)) should show: \(expectedShow)")
            
            // When: User dismisses What's New
            testService.markWhatsNewAsShown()
            
            // Then: Should not show again for same version
            let shouldShowAfterDismissal = testService.shouldShowWhatsNew()
            XCTAssertFalse(shouldShowAfterDismissal, 
                          "Version \(currentVersion) should not show after dismissal")
            
            // Update for next iteration
            previousVersion = currentVersion
        }
    }
    
    func testVersionUpgradeWithAppReinstallation() {
        // Given: User had version 1.5.0 installed
        testUserDefaults.set("1.5.0", forKey: "LastShownWhatsNewVersion")
        
        // When: App is uninstalled and reinstalled with newer version 2.0.0
        // (simulated by clearing UserDefaults and setting new version)
        testUserDefaults.removePersistentDomain(forName: "VersionUpgradeTests")
        
        let mockTracker = MockVersionTracker()
        mockTracker.currentVersion = "2.0.0"
        mockTracker.lastShownVersion = nil // No stored version after reinstall
        
        let testService = WhatsNewService(
            versionTracker: mockTracker,
            contentProvider: contentProvider
        )
        
        // Then: What's New should be shown (treated as first install)
        let shouldShow = testService.shouldShowWhatsNew()
        XCTAssertTrue(shouldShow, "Should show What's New after reinstallation")
        
        // When: User dismisses What's New
        testService.markWhatsNewAsShown()
        
        // Then: Version should be stored and not shown again
        let shouldShowAfterDismissal = testService.shouldShowWhatsNew()
        XCTAssertFalse(shouldShowAfterDismissal, "Should not show after dismissal post-reinstall")
        
        // Verify correct version is stored
        XCTAssertEqual(mockTracker.lastShownVersion, "2.0.0", "Should store current version")
    }
    
    func testVersionUpgradeWithDataMigration() {
        // Given: Old version with different UserDefaults key (simulating data migration)
        testUserDefaults.set("1.0.0", forKey: "OldWhatsNewVersionKey")
        
        // When: New version uses different key but migrates data
        let oldVersion = testUserDefaults.string(forKey: "OldWhatsNewVersionKey")
        if let oldVersion = oldVersion {
            testUserDefaults.set(oldVersion, forKey: "LastShownWhatsNewVersion")
            testUserDefaults.removeObject(forKey: "OldWhatsNewVersionKey")
        }
        
        let mockTracker = MockVersionTracker()
        mockTracker.currentVersion = "1.1.0"
        mockTracker.lastShownVersion = oldVersion
        
        let testService = WhatsNewService(
            versionTracker: mockTracker,
            contentProvider: contentProvider
        )
        
        // Then: Should show What's New for new version
        let shouldShow = testService.shouldShowWhatsNew()
        XCTAssertTrue(shouldShow, "Should show What's New after data migration")
        
        // Verify migration worked
        let migratedVersion = testUserDefaults.string(forKey: "LastShownWhatsNewVersion")
        XCTAssertEqual(migratedVersion, "1.0.0", "Should have migrated old version")
        
        let oldKeyExists = testUserDefaults.object(forKey: "OldWhatsNewVersionKey") != nil
        XCTAssertFalse(oldKeyExists, "Old key should be removed after migration")
    }
    
    // MARK: - Version Comparison Edge Cases
    
    func testSemanticVersioningCompliance() {
        let semanticVersionTests: [(v1: String, v2: String, expected: ComparisonResult, description: String)] = [
            // Basic semantic versioning
            ("1.0.0", "1.0.1", .orderedAscending, "patch increment"),
            ("1.0.0", "1.1.0", .orderedAscending, "minor increment"),
            ("1.0.0", "2.0.0", .orderedAscending, "major increment"),
            
            // Pre-release versions
            ("1.0.0-alpha", "1.0.0-alpha.1", .orderedAscending, "alpha to alpha.1"),
            ("1.0.0-alpha.1", "1.0.0-alpha.beta", .orderedAscending, "alpha.1 to alpha.beta"),
            ("1.0.0-alpha.beta", "1.0.0-beta", .orderedAscending, "alpha.beta to beta"),
            ("1.0.0-beta", "1.0.0-beta.2", .orderedAscending, "beta to beta.2"),
            ("1.0.0-beta.2", "1.0.0-beta.11", .orderedAscending, "beta.2 to beta.11"),
            ("1.0.0-beta.11", "1.0.0-rc.1", .orderedAscending, "beta.11 to rc.1"),
            ("1.0.0-rc.1", "1.0.0", .orderedAscending, "rc.1 to release"),
            
            // Build metadata (should be ignored in comparison)
            ("1.0.0+20130313144700", "1.0.0+20130313144701", .orderedSame, "build metadata ignored"),
            ("1.0.0-beta+exp.sha.5114f85", "1.0.0-beta+exp.sha.999999", .orderedSame, "pre-release with build metadata"),
            
            // Complex pre-release identifiers
            ("1.0.0-1", "1.0.0-2", .orderedAscending, "numeric pre-release"),
            ("1.0.0-1.2", "1.0.0-1.2.3", .orderedAscending, "multi-part numeric pre-release"),
            ("1.0.0-1.2.3", "1.0.0-1.2.3.4", .orderedAscending, "extended numeric pre-release")
        ]
        
        for test in semanticVersionTests {
            // When: Comparing versions using the version tracker
            let result = versionTracker.compareVersions(test.v1, test.v2)
            
            // Then: Result should match semantic versioning specification
            XCTAssertEqual(result, test.expected, 
                          "Semantic versioning failed for \(test.description): \(test.v1) vs \(test.v2)")
        }
    }
    
    func testVersionComparisonPerformance() {
        // Given: Large number of version comparisons
        let versions = [
            "1.0.0", "1.0.1", "1.0.2", "1.1.0", "1.1.1", "1.2.0",
            "2.0.0", "2.0.1", "2.1.0", "2.1.1", "2.2.0", "3.0.0",
            "1.0.0-alpha", "1.0.0-beta", "1.0.0-rc.1", "1.0.0-rc.2",
            "1.0.0+build.1", "1.0.0+build.2", "1.1.0-alpha+build.1"
        ]
        
        let iterations = 1000
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // When: Performing many version comparisons
        for _ in 0..<iterations {
            for i in 0..<versions.count {
                for j in 0..<versions.count {
                    _ = versionTracker.compareVersions(versions[i], versions[j])
                }
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime
        let averageTime = totalTime / Double(iterations * versions.count * versions.count)
        
        // Then: Performance should be acceptable
        XCTAssertLessThan(totalTime, 1.0, "Total comparison time should be under 1 second")
        XCTAssertLessThan(averageTime, 0.000001, "Average comparison should be under 1 microsecond")
        
        print("Version comparison performance: \(totalTime)s total, \(averageTime * 1000000)μs average")
    }
    
    // MARK: - Cross-Platform Version Handling
    
    func testCrossPlatformVersionFormats() {
        let crossPlatformTests: [(version: String, shouldParse: Bool, description: String)] = [
            // macOS formats
            ("1.0.0", true, "Standard macOS version"),
            ("1.0 (Build 1A1)", true, "Xcode build format"),
            ("Version 1.0.0 (1)", true, "Marketing version"),
            
            // iOS formats
            ("14.5.1", true, "iOS version format"),
            ("14.5.1 (18E212)", true, "iOS with build number"),
            
            // Windows formats
            ("1.0.0.0", true, "Windows four-part version"),
            ("1.0.0.1234", true, "Windows with build number"),
            
            // Linux/Unix formats
            ("1.0.0-1", true, "Debian package version"),
            ("1.0.0-1ubuntu1", true, "Ubuntu package version"),
            ("1.0.0.el7", true, "RHEL package version"),
            
            // Web/Node.js formats
            ("1.0.0-next.1", true, "NPM pre-release"),
            ("1.0.0-canary.1", true, "Canary release"),
            
            // Invalid formats
            ("", false, "Empty version"),
            ("invalid", false, "Non-numeric version"),
            ("1.0.0.0.0", true, "Five-part version (should handle gracefully)"),
            ("v", false, "Just prefix"),
            ("1.0.0-", true, "Trailing dash (should handle)")
        ]
        
        for test in crossPlatformTests {
            // When: Processing cross-platform version format
            let mockTracker = MockVersionTracker()
            mockTracker.currentVersion = test.version
            mockTracker.lastShownVersion = "0.9.0" // Always older
            
            let testService = WhatsNewService(
                versionTracker: mockTracker,
                contentProvider: contentProvider
            )
            
            // Then: Should handle format appropriately
            if test.shouldParse {
                let shouldShow = testService.shouldShowWhatsNew()
                // For valid versions that are newer, should show
                let expectedShow = !test.version.isEmpty && test.version != "0.9.0"
                XCTAssertEqual(shouldShow, expectedShow, 
                              "Should handle \(test.description): \(test.version)")
            } else {
                // Invalid versions should be handled gracefully (likely not show)
                let shouldShow = testService.shouldShowWhatsNew()
                XCTAssertFalse(shouldShow, 
                              "Should handle invalid version gracefully: \(test.description)")
            }
        }
    }
    
    // MARK: - Version Rollback Scenarios
    
    func testVersionRollbackHandling() {
        // Given: User had newer version installed
        testUserDefaults.set("2.0.0", forKey: "LastShownWhatsNewVersion")
        
        // When: App is rolled back to older version (rare but possible)
        let mockTracker = MockVersionTracker()
        mockTracker.currentVersion = "1.9.0"
        mockTracker.lastShownVersion = "2.0.0"
        
        let testService = WhatsNewService(
            versionTracker: mockTracker,
            contentProvider: contentProvider
        )
        
        // Then: Should not show What's New for rollback
        let shouldShow = testService.shouldShowWhatsNew()
        XCTAssertFalse(shouldShow, "Should not show What's New for version rollback")
        
        // When: User manually accesses via Help menu
        let content = testService.getWhatsNewContent()
        
        // Then: Content should still be available
        XCTAssertNotNil(content, "Content should be available even for rollback")
        XCTAssertEqual(content?.version, "1.9.0", "Content should reflect current version")
    }
    
    func testVersionRollbackWithSubsequentUpgrade() {
        // Given: Version rollback scenario
        testUserDefaults.set("2.0.0", forKey: "LastShownWhatsNewVersion")
        
        let mockTracker = MockVersionTracker()
        mockTracker.currentVersion = "1.9.0"
        mockTracker.lastShownVersion = "2.0.0"
        
        let testService = WhatsNewService(
            versionTracker: mockTracker,
            contentProvider: contentProvider
        )
        
        // Verify rollback doesn't show What's New
        XCTAssertFalse(testService.shouldShowWhatsNew(), "Should not show for rollback")
        
        // When: App is upgraded to new version higher than original
        mockTracker.currentVersion = "2.1.0"
        
        // Then: Should show What's New for new upgrade
        let shouldShowAfterUpgrade = testService.shouldShowWhatsNew()
        XCTAssertTrue(shouldShowAfterUpgrade, "Should show What's New for upgrade after rollback")
        
        // When: User dismisses What's New
        testService.markWhatsNewAsShown()
        
        // Then: New version should be stored
        XCTAssertEqual(mockTracker.lastShownVersion, "2.1.0", "Should store new version")
    }
}

// MARK: - Mock Version Tracker for Testing

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
    
    func validateVersionFormat(_ version: String) -> Bool {
        return !version.isEmpty
    }
    
    func isNewVersion() -> Bool {
        if shouldThrowError {
            return false
        }
        
        guard let lastShown = lastShownVersion else {
            return true // First install
        }
        
        return compareVersions(currentVersion, lastShown) == .orderedDescending
    }
    
    func compareVersions(_ version1: String, _ version2: String) -> ComparisonResult {
        // Enhanced version comparison that handles more formats
        if version1.isEmpty && version2.isEmpty {
            return .orderedSame
        }
        if version1.isEmpty {
            return .orderedAscending
        }
        if version2.isEmpty {
            return .orderedDescending
        }
        
        // Clean versions by removing common prefixes and suffixes
        let cleanVersion1 = cleanVersionString(version1)
        let cleanVersion2 = cleanVersionString(version2)
        
        // Split into components
        let components1 = parseVersionComponents(cleanVersion1)
        let components2 = parseVersionComponents(cleanVersion2)
        
        // Compare numeric components first
        let numericResult = compareNumericComponents(components1.numeric, components2.numeric)
        if numericResult != .orderedSame {
            return numericResult
        }
        
        // If numeric components are equal, compare pre-release identifiers
        return comparePreReleaseComponents(components1.preRelease, components2.preRelease)
    }
    
    private func cleanVersionString(_ version: String) -> String {
        var cleaned = version
        
        // Remove common prefixes
        if cleaned.hasPrefix("Version ") {
            cleaned = String(cleaned.dropFirst(8))
        }
        if cleaned.hasPrefix("v") {
            cleaned = String(cleaned.dropFirst(1))
        }
        
        // Remove build metadata (everything after +)
        if let plusIndex = cleaned.firstIndex(of: "+") {
            cleaned = String(cleaned[..<plusIndex])
        }
        
        // Remove build info in parentheses
        if let parenIndex = cleaned.firstIndex(of: "(") {
            cleaned = String(cleaned[..<parenIndex]).trimmingCharacters(in: .whitespaces)
        }
        
        return cleaned
    }
    
    private func parseVersionComponents(_ version: String) -> (numeric: [Int], preRelease: String?) {
        let parts = version.components(separatedBy: "-")
        let numericPart = parts[0]
        let preReleasePart = parts.count > 1 ? parts[1...].joined(separator: "-") : nil
        
        let numericComponents = numericPart.components(separatedBy: ".").compactMap { Int($0) }
        
        return (numericComponents, preReleasePart)
    }
    
    private func compareNumericComponents(_ components1: [Int], _ components2: [Int]) -> ComparisonResult {
        let maxCount = max(components1.count, components2.count)
        
        for i in 0..<maxCount {
            let comp1 = i < components1.count ? components1[i] : 0
            let comp2 = i < components2.count ? components2[i] : 0
            
            if comp1 < comp2 {
                return .orderedAscending
            } else if comp1 > comp2 {
                return .orderedDescending
            }
        }
        
        return .orderedSame
    }
    
    private func comparePreReleaseComponents(_ preRelease1: String?, _ preRelease2: String?) -> ComparisonResult {
        switch (preRelease1, preRelease2) {
        case (nil, nil):
            return .orderedSame
        case (nil, _):
            return .orderedDescending // Release version is greater than pre-release
        case (_, nil):
            return .orderedAscending // Pre-release is less than release
        case let (pre1?, pre2?):
            return pre1.compare(pre2, options: .numeric)
        }
    }
}