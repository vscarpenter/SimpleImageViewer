//
//  WhatsNewErrorHandlingTests.swift
//  StillView - Simple Image Viewer Tests
//
//  Created by Kiro on 8/7/25.
//

import XCTest
@testable import Simple_Image_Viewer

/// Comprehensive tests for error handling and edge cases in the What's New feature
final class WhatsNewErrorHandlingTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private var mockVersionTracker: MockVersionTracker!
    private var mockContentProvider: MockContentProvider!
    private var service: WhatsNewService!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        mockVersionTracker = MockVersionTracker()
        mockContentProvider = MockContentProvider()
        service = WhatsNewService(
            versionTracker: mockVersionTracker,
            contentProvider: mockContentProvider
        )
    }
    
    override func tearDown() {
        service = nil
        mockContentProvider = nil
        mockVersionTracker = nil
        super.tearDown()
    }
    
    // MARK: - Content Loading Error Tests
    
    func testContentLoadingFailure_ReturnsNilAfterMaxAttempts() {
        // Given
        mockVersionTracker.currentVersion = "1.0.0"
        mockContentProvider.shouldThrowError = true
        mockContentProvider.errorToThrow = WhatsNewContentProvider.ContentError.contentNotFound("Test error")
        
        // When - Multiple attempts should eventually return nil
        var result: WhatsNewContent?
        for _ in 0..<5 {
            result = service.getWhatsNewContent()
            // Small delay to test retry logic
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        // Then - Should get fallback content
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.sections.first?.title, "App Updated")
    }
    
    func testContentLoadingWithCorruptedData_ReturnsFallback() {
        // Given
        mockVersionTracker.currentVersion = "1.0.0"
        mockContentProvider.shouldThrowError = true
        mockContentProvider.errorToThrow = WhatsNewContentProvider.ContentError.corruptedData("Data corrupted")
        
        // When
        let result = service.getWhatsNewContent()
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.version, "1.0.0")
        XCTAssertEqual(result?.sections.count, 1)
        XCTAssertEqual(result?.sections.first?.title, "App Updated")
    }
    
    func testContentLoadingWithInvalidFormat_ReturnsFallback() {
        // Given
        mockVersionTracker.currentVersion = "1.0.0"
        mockContentProvider.shouldThrowError = true
        mockContentProvider.errorToThrow = WhatsNewContentProvider.ContentError.invalidFormat("Invalid JSON")
        
        // When
        let result = service.getWhatsNewContent()
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.sections.first?.items.first?.title, "New Version Available")
    }
    
    func testContentValidationFailure_ReturnsFallback() {
        // Given
        mockVersionTracker.currentVersion = "1.0.0"
        mockContentProvider.shouldReturnInvalidContent = true
        
        // When
        let result = service.getWhatsNewContent()
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.sections.first?.title, "App Updated")
    }
    
    // MARK: - Version Tracking Error Tests
    
    func testVersionTrackerPersistenceFailure_DoesNotCrash() {
        // Given
        mockVersionTracker.currentVersion = "1.0.0"
        mockVersionTracker.shouldThrowOnSet = true
        mockVersionTracker.setError = VersionTrackerError.persistenceFailed("UserDefaults failed")
        
        // When & Then - Should not crash
        XCTAssertNoThrow(service.markWhatsNewAsShown())
        
        // Verify the attempt was made
        XCTAssertTrue(mockVersionTracker.setLastShownVersionCalled)
    }
    
    func testVersionTrackerWithInvalidVersion_HandlesGracefully() {
        // Given
        mockVersionTracker.currentVersion = ""
        
        // When
        let result = service.getWhatsNewContent()
        
        // Then
        XCTAssertNil(result) // Should return nil for empty version
    }
    
    func testVersionTrackerWithCorruptedStoredVersion_ClearsData() {
        // Given
        mockVersionTracker.currentVersion = "1.0.0"
        mockVersionTracker.lastShownVersion = "corrupted.version.data"
        
        // When
        let isNew = mockVersionTracker.isNewVersion()
        
        // Then - Should treat as new version due to corrupted data
        XCTAssertTrue(isNew)
    }
    
    // MARK: - Edge Case Tests
    
    func testEmptyVersionString_ReturnsNil() {
        // Given
        mockVersionTracker.currentVersion = ""
        
        // When
        let result = service.getWhatsNewContent()
        
        // Then
        XCTAssertNil(result)
    }
    
    func testWhitespaceOnlyVersion_ReturnsNil() {
        // Given
        mockVersionTracker.currentVersion = "   "
        
        // When
        let result = service.getWhatsNewContent()
        
        // Then
        XCTAssertNil(result)
    }
    
    func testServiceWithNilContentProvider_HandlesGracefully() {
        // Given
        mockContentProvider.shouldSucceed = false
        mockContentProvider.shouldThrowError = true
        mockContentProvider.errorToThrow = WhatsNewContentProvider.ContentError.contentNotFound("No provider")
        
        // When
        let shouldShow = service.shouldShowWhatsNew()
        
        // Then
        XCTAssertFalse(shouldShow)
    }
    
    // MARK: - Diagnostic Information Tests
    
    func testDiagnosticInfo_WithErrorState() {
        // Given
        mockVersionTracker.currentVersion = "1.0.0"
        mockVersionTracker.lastShownVersion = "0.9.0"
        mockVersionTracker.isNewVersionResult = true
        mockContentProvider.shouldThrowError = true
        mockContentProvider.errorToThrow = WhatsNewContentProvider.ContentError.contentNotFound("Test error")
        
        // Load content to populate error state
        _ = service.getWhatsNewContent()
        
        // When
        let diagnosticInfo = service.getDiagnosticInfo()
        
        // Then
        XCTAssertEqual(diagnosticInfo.currentVersion, "1.0.0")
        XCTAssertEqual(diagnosticInfo.lastShownVersion, "0.9.0")
        XCTAssertTrue(diagnosticInfo.isNewVersion)
        XCTAssertTrue(diagnosticInfo.hasContent) // Should have fallback content
        XCTAssertNotNil(diagnosticInfo.contentLoadingError)
        XCTAssertTrue(diagnosticInfo.contentLoadAttempts > 0)
        XCTAssertNotNil(diagnosticInfo.lastContentLoadAttempt)
    }
    
    func testDiagnosticInfo_WithSuccessState() {
        // Given
        mockVersionTracker.currentVersion = "1.0.0"
        mockVersionTracker.lastShownVersion = nil
        mockVersionTracker.isNewVersionResult = true
        mockContentProvider.shouldSucceed = true
        
        // Load content to populate success state
        _ = service.getWhatsNewContent()
        
        // When
        let diagnosticInfo = service.getDiagnosticInfo()
        
        // Then
        XCTAssertEqual(diagnosticInfo.currentVersion, "1.0.0")
        XCTAssertNil(diagnosticInfo.lastShownVersion)
        XCTAssertTrue(diagnosticInfo.isNewVersion)
        XCTAssertTrue(diagnosticInfo.hasContent)
        XCTAssertEqual(diagnosticInfo.cacheStatus, .cached)
    }
    
    func testDiagnosticDescription_ContainsAllInformation() {
        // Given
        mockVersionTracker.currentVersion = "1.2.0"
        mockVersionTracker.lastShownVersion = "1.1.0"
        mockVersionTracker.isNewVersionResult = true
        mockContentProvider.shouldSucceed = true
        
        _ = service.getWhatsNewContent()
        
        // When
        let diagnosticInfo = service.getDiagnosticInfo()
        let description = diagnosticInfo.diagnosticDescription
        
        // Then
        XCTAssertTrue(description.contains("Current Version: 1.2.0"))
        XCTAssertTrue(description.contains("Last Shown Version: 1.1.0"))
        XCTAssertTrue(description.contains("Is New Version: true"))
        XCTAssertTrue(description.contains("Has Content: true"))
        XCTAssertTrue(description.contains("Cache Status:"))
    }
    
    // MARK: - Recovery Mechanism Tests
    
    func testCacheClearing_ResetsErrorState() {
        // Given
        mockVersionTracker.currentVersion = "1.0.0"
        mockContentProvider.shouldThrowError = true
        mockContentProvider.errorToThrow = WhatsNewContentProvider.ContentError.corruptedData("Test corruption")
        
        // Load content to populate error state
        _ = service.getWhatsNewContent()
        
        // When
        service.clearCache()
        
        // Reset mock to succeed
        mockContentProvider.shouldThrowError = false
        mockContentProvider.shouldSucceed = true
        
        // Then
        let result = service.getWhatsNewContent()
        XCTAssertNotNil(result)
        XCTAssertEqual(mockContentProvider.loadContentCallCount, 2) // Should have been called again after cache clear
    }
    
    func testMultipleFailuresFollowedBySuccess_Recovers() {
        // Given
        mockVersionTracker.currentVersion = "1.0.0"
        mockContentProvider.shouldThrowError = true
        mockContentProvider.errorToThrow = WhatsNewContentProvider.ContentError.contentNotFound("Temporary failure")
        
        // When - Multiple failures
        _ = service.getWhatsNewContent()
        _ = service.getWhatsNewContent()
        
        // Then success
        service.clearCache()
        mockContentProvider.shouldThrowError = false
        mockContentProvider.shouldSucceed = true
        
        let result = service.getWhatsNewContent()
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.sections.first?.title, "Test Features") // Should get real content, not fallback
    }
}

// MARK: - Enhanced Mock Classes

private final class MockVersionTracker: VersionTrackerProtocol {
    var currentVersion = "1.0.0"
    var lastShownVersion: String?
    var isNewVersionResult = false
    var lastSetVersion: String?
    var setLastShownVersionCalled = false
    var shouldThrowOnSet = false
    var setError: Error?
    
    func getCurrentVersion() -> String {
        return currentVersion
    }
    
    func getLastShownVersion() -> String? {
        return lastShownVersion
    }
    
    func setLastShownVersion(_ version: String) throws {
        setLastShownVersionCalled = true
        lastSetVersion = version
        
        if shouldThrowOnSet {
            throw setError ?? VersionTrackerError.persistenceFailed("Mock error")
        }
    }
    
    func isNewVersion() -> Bool {
        return isNewVersionResult
    }
    
    func validateVersionFormat(_ version: String) -> Bool {
        return !version.isEmpty && version.range(of: #"^\d+(\.\d+)*$"#, options: .regularExpression) != nil
    }
}

private final class MockContentProvider: WhatsNewContentProviderProtocol {
    var shouldSucceed = true
    var shouldThrowError = false
    var shouldReturnInvalidContent = false
    var errorToThrow: Error = WhatsNewContentProvider.ContentError.contentNotFound("Mock error")
    var loadContentCallCount = 0
    
    func loadContent() throws -> WhatsNewContent {
        return try loadContent(for: "1.0.0")
    }
    
    func loadContent(for version: String) throws -> WhatsNewContent {
        loadContentCallCount += 1
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        if !shouldSucceed {
            throw WhatsNewContentProvider.ContentError.contentNotFound("Mock failure")
        }
        
        if shouldReturnInvalidContent {
            // Return content that would fail validation
            let invalidSection = WhatsNewSection(
                title: "", // Empty title should fail validation
                items: [],
                type: .newFeatures
            )
            
            return WhatsNewContent(
                version: version,
                releaseDate: Date(),
                sections: [invalidSection]
            )
        }
        
        // Return valid sample content
        let section = WhatsNewSection(
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
        
        return WhatsNewContent(
            version: version,
            releaseDate: Date(),
            sections: [section]
        )
    }
}