//
//  VersionTrackerTests.swift
//  Simple Image Viewer Tests
//
//  Created by Kiro on 8/6/25.
//

import XCTest
@testable import Simple_Image_Viewer

final class VersionTrackerTests: XCTestCase {
    
    // MARK: - Properties
    
    private var mockUserDefaults: UserDefaults!
    private var mockBundle: Bundle!
    private var versionTracker: VersionTracker!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // Create a test UserDefaults suite to avoid affecting real user defaults
        mockUserDefaults = UserDefaults(suiteName: "test.suite.whats.new")!
        
        // Clear any existing test data
        mockUserDefaults.removePersistentDomain(forName: "test.suite.whats.new")
        
        // Create mock bundle with test info dictionary
        mockBundle = MockBundle()
        
        versionTracker = VersionTracker(userDefaults: mockUserDefaults, bundle: mockBundle)
    }
    
    override func tearDown() {
        mockUserDefaults.removePersistentDomain(forName: "test.suite.whats.new")
        mockUserDefaults = nil
        mockBundle = nil
        versionTracker = nil
        super.tearDown()
    }
    
    // MARK: - getCurrentVersion Tests
    
    func testGetCurrentVersionFromBundle() {
        // Given
        let expectedVersion = "1.2.3"
        (mockBundle as! MockBundle).mockVersion = expectedVersion
        
        // When
        let currentVersion = versionTracker.getCurrentVersion()
        
        // Then
        XCTAssertEqual(currentVersion, expectedVersion)
    }
    
    func testGetCurrentVersionWithMissingBundleInfo() {
        // Given
        (mockBundle as! MockBundle).mockVersion = nil
        
        // When
        let currentVersion = versionTracker.getCurrentVersion()
        
        // Then
        XCTAssertEqual(currentVersion, "1.0.0") // Default fallback
    }
    
    // MARK: - UserDefaults Integration Tests
    
    func testGetLastShownVersionWhenNoneStored() {
        // When
        let lastShownVersion = versionTracker.getLastShownVersion()
        
        // Then
        XCTAssertNil(lastShownVersion)
    }
    
    func testSetAndGetLastShownVersion() {
        // Given
        let version = "1.2.3"
        
        // When
        versionTracker.setLastShownVersion(version)
        let retrievedVersion = versionTracker.getLastShownVersion()
        
        // Then
        XCTAssertEqual(retrievedVersion, version)
    }
    
    func testGetLastShownVersionWithEmptyString() {
        // Given
        mockUserDefaults.set("", forKey: "LastShownWhatsNewVersion")
        
        // When
        let lastShownVersion = versionTracker.getLastShownVersion()
        
        // Then
        XCTAssertNil(lastShownVersion) // Empty string should be treated as nil
    }
    
    func testSetLastShownVersionPersistence() {
        // Given
        let version = "2.0.0"
        versionTracker.setLastShownVersion(version)
        
        // When - Create new tracker instance with same UserDefaults
        let newTracker = VersionTracker(userDefaults: mockUserDefaults, bundle: mockBundle)
        let retrievedVersion = newTracker.getLastShownVersion()
        
        // Then
        XCTAssertEqual(retrievedVersion, version)
    }
    
    // MARK: - isNewVersion Tests
    
    func testIsNewVersionWhenNoVersionStored() {
        // Given
        (mockBundle as! MockBundle).mockVersion = "1.0.0"
        
        // When
        let isNew = versionTracker.isNewVersion()
        
        // Then
        XCTAssertTrue(isNew) // Should be true when no previous version is stored
    }
    
    func testIsNewVersionWhenCurrentIsNewer() {
        // Given
        (mockBundle as! MockBundle).mockVersion = "1.2.0"
        versionTracker.setLastShownVersion("1.1.0")
        
        // When
        let isNew = versionTracker.isNewVersion()
        
        // Then
        XCTAssertTrue(isNew)
    }
    
    func testIsNewVersionWhenCurrentIsSame() {
        // Given
        (mockBundle as! MockBundle).mockVersion = "1.1.0"
        versionTracker.setLastShownVersion("1.1.0")
        
        // When
        let isNew = versionTracker.isNewVersion()
        
        // Then
        XCTAssertFalse(isNew)
    }
    
    func testIsNewVersionWhenCurrentIsOlder() {
        // Given
        (mockBundle as! MockBundle).mockVersion = "1.0.0"
        versionTracker.setLastShownVersion("1.1.0")
        
        // When
        let isNew = versionTracker.isNewVersion()
        
        // Then
        XCTAssertFalse(isNew)
    }
    
    // MARK: - Version Comparison Edge Cases
    
    func testVersionComparisonWithDifferentComponentCounts() {
        // Given
        (mockBundle as! MockBundle).mockVersion = "1.2"
        versionTracker.setLastShownVersion("1.1.9")
        
        // When
        let isNew = versionTracker.isNewVersion()
        
        // Then
        XCTAssertTrue(isNew) // 1.2 should be greater than 1.1.9
    }
    
    func testVersionComparisonWithMissingComponents() {
        // Given
        (mockBundle as! MockBundle).mockVersion = "2"
        versionTracker.setLastShownVersion("1.9.9")
        
        // When
        let isNew = versionTracker.isNewVersion()
        
        // Then
        XCTAssertTrue(isNew) // 2 should be greater than 1.9.9
    }
    
    func testVersionComparisonWithZeroComponents() {
        // Given
        (mockBundle as! MockBundle).mockVersion = "1.0.1"
        versionTracker.setLastShownVersion("1.0.0")
        
        // When
        let isNew = versionTracker.isNewVersion()
        
        // Then
        XCTAssertTrue(isNew)
    }
    
    func testVersionComparisonWithLargeNumbers() {
        // Given
        (mockBundle as! MockBundle).mockVersion = "10.0.0"
        versionTracker.setLastShownVersion("9.99.99")
        
        // When
        let isNew = versionTracker.isNewVersion()
        
        // Then
        XCTAssertTrue(isNew)
    }
    
    func testVersionComparisonWithIdenticalVersions() {
        // Given
        (mockBundle as! MockBundle).mockVersion = "1.2.3"
        versionTracker.setLastShownVersion("1.2.3")
        
        // When
        let isNew = versionTracker.isNewVersion()
        
        // Then
        XCTAssertFalse(isNew)
    }
    
    func testVersionComparisonWithPatchVersionIncrease() {
        // Given
        (mockBundle as! MockBundle).mockVersion = "1.0.1"
        versionTracker.setLastShownVersion("1.0.0")
        
        // When
        let isNew = versionTracker.isNewVersion()
        
        // Then
        XCTAssertTrue(isNew)
    }
    
    func testVersionComparisonWithMinorVersionIncrease() {
        // Given
        (mockBundle as! MockBundle).mockVersion = "1.1.0"
        versionTracker.setLastShownVersion("1.0.9")
        
        // When
        let isNew = versionTracker.isNewVersion()
        
        // Then
        XCTAssertTrue(isNew)
    }
    
    func testVersionComparisonWithMajorVersionIncrease() {
        // Given
        (mockBundle as! MockBundle).mockVersion = "2.0.0"
        versionTracker.setLastShownVersion("1.9.9")
        
        // When
        let isNew = versionTracker.isNewVersion()
        
        // Then
        XCTAssertTrue(isNew)
    }
    
    // MARK: - Edge Cases and Error Handling
    
    func testVersionComparisonWithNonNumericComponents() {
        // Given - This tests the robustness of version parsing
        (mockBundle as! MockBundle).mockVersion = "1.2.3"
        try! versionTracker.setLastShownVersion("1.2.beta")
        
        // When
        let isNew = versionTracker.isNewVersion()
        
        // Then
        // Should handle gracefully - invalid version format should be cleared
        XCTAssertTrue(isNew) // Invalid stored version should be treated as no version
    }
    
    func testVersionComparisonWithEmptyVersionString() {
        // Given
        (mockBundle as! MockBundle).mockVersion = "1.0.0"
        try! versionTracker.setLastShownVersion("")
        
        // When
        let isNew = versionTracker.isNewVersion()
        
        // Then
        XCTAssertTrue(isNew) // Empty string should be treated as no version stored
    }
    
    func testSetLastShownVersionWithInvalidFormat() {
        // Given
        let invalidVersion = "invalid.version.format"
        
        // When & Then
        XCTAssertThrowsError(try versionTracker.setLastShownVersion(invalidVersion)) { error in
            XCTAssertTrue(error is VersionTrackerError)
            if case VersionTrackerError.invalidVersion(let message) = error {
                XCTAssertTrue(message.contains("invalid format"))
            } else {
                XCTFail("Expected VersionTrackerError.invalidVersion")
            }
        }
    }
    
    func testSetLastShownVersionWithEmptyString() {
        // When & Then
        XCTAssertThrowsError(try versionTracker.setLastShownVersion("")) { error in
            XCTAssertTrue(error is VersionTrackerError)
            if case VersionTrackerError.invalidVersion(let message) = error {
                XCTAssertTrue(message.contains("cannot be empty"))
            } else {
                XCTFail("Expected VersionTrackerError.invalidVersion")
            }
        }
    }
    
    func testValidateVersionFormat() {
        // Valid versions
        XCTAssertTrue(versionTracker.validateVersionFormat("1.0.0"))
        XCTAssertTrue(versionTracker.validateVersionFormat("1.2"))
        XCTAssertTrue(versionTracker.validateVersionFormat("10.5.3"))
        XCTAssertTrue(versionTracker.validateVersionFormat("2"))
        
        // Invalid versions
        XCTAssertFalse(versionTracker.validateVersionFormat(""))
        XCTAssertFalse(versionTracker.validateVersionFormat("   "))
        XCTAssertFalse(versionTracker.validateVersionFormat("1.2.beta"))
        XCTAssertFalse(versionTracker.validateVersionFormat("v1.2.3"))
        XCTAssertFalse(versionTracker.validateVersionFormat("1.2.3-alpha"))
        XCTAssertFalse(versionTracker.validateVersionFormat("1..2"))
        XCTAssertFalse(versionTracker.validateVersionFormat(".1.2"))
        XCTAssertFalse(versionTracker.validateVersionFormat("1.2."))
    }
    
    func testGetLastShownVersionWithCorruptedData() {
        // Given - Manually set corrupted data
        mockUserDefaults.set("corrupted.version.data", forKey: "LastShownWhatsNewVersion")
        
        // When
        let result = versionTracker.getLastShownVersion()
        
        // Then
        XCTAssertNil(result) // Should return nil and clear corrupted data
        
        // Verify data was cleared
        let clearedValue = mockUserDefaults.string(forKey: "LastShownWhatsNewVersion")
        XCTAssertNil(clearedValue)
    }
    
    func testUserDefaultsPersistenceFailure() {
        // Given - Create a mock that simulates UserDefaults failure
        let failingDefaults = FailingUserDefaults()
        let failingTracker = VersionTracker(userDefaults: failingDefaults, bundle: mockBundle)
        
        // When & Then
        XCTAssertThrowsError(try failingTracker.setLastShownVersion("1.0.0")) { error in
            XCTAssertTrue(error is VersionTrackerError)
            if case VersionTrackerError.persistenceFailed = error {
                // Expected error type
            } else {
                XCTFail("Expected VersionTrackerError.persistenceFailed")
            }
        }
    }
    
    func testVersionComparisonWithMalformedStoredVersion() {
        // Given
        (mockBundle as! MockBundle).mockVersion = "1.2.0"
        
        // Manually set malformed version that passes initial validation but fails parsing
        mockUserDefaults.set("1.2.0", forKey: "LastShownWhatsNewVersion")
        
        // Simulate corruption by changing the stored value after validation
        mockUserDefaults.set("1.2.0.corrupted", forKey: "LastShownWhatsNewVersion")
        
        // When
        let isNew = versionTracker.isNewVersion()
        
        // Then - Should handle gracefully and treat as new version
        XCTAssertTrue(isNew)
    }
}

// MARK: - Mock Bundle

private class MockBundle: Bundle {
    var mockVersion: String?
    
    override var infoDictionary: [String : Any]? {
        guard let version = mockVersion else { return [:] }
        return ["CFBundleShortVersionString": version]
    }
}

private class FailingUserDefaults: UserDefaults {
    override func set(_ value: Any?, forKey defaultName: String) {
        // Simulate a UserDefaults failure
        // In real scenarios, this could happen due to disk space, permissions, etc.
    }
    
    override func string(forKey defaultName: String) -> String? {
        return nil
    }
}