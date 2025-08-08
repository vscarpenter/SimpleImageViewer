//
//  WhatsNewServiceTests.swift
//  Simple Image Viewer Tests
//
//  Created by Kiro on 8/7/25.
//

import XCTest
@testable import Simple_Image_Viewer

final class WhatsNewServiceTests: XCTestCase {
    
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
    
    // MARK: - shouldShowWhatsNew Tests
    
    func testShouldShowWhatsNew_WhenNewVersionAndContentAvailable_ReturnsTrue() {
        // Given
        mockVersionTracker.isNewVersionResult = true
        mockContentProvider.shouldSucceed = true
        
        // When
        let result = service.shouldShowWhatsNew()
        
        // Then
        XCTAssertTrue(result)
    }
    
    func testShouldShowWhatsNew_WhenNotNewVersion_ReturnsFalse() {
        // Given
        mockVersionTracker.isNewVersionResult = false
        mockContentProvider.shouldSucceed = true
        
        // When
        let result = service.shouldShowWhatsNew()
        
        // Then
        XCTAssertFalse(result)
    }
    
    func testShouldShowWhatsNew_WhenNewVersionButNoContent_ReturnsFalse() {
        // Given
        mockVersionTracker.isNewVersionResult = true
        mockContentProvider.shouldSucceed = false
        
        // When
        let result = service.shouldShowWhatsNew()
        
        // Then
        XCTAssertFalse(result)
    }
    
    func testShouldShowWhatsNew_WhenContentLoadingFails_ReturnsFalse() {
        // Given
        mockVersionTracker.isNewVersionResult = true
        mockContentProvider.shouldThrowError = true
        mockContentProvider.errorToThrow = WhatsNewContentProvider.ContentError.contentNotFound("Test error")
        
        // When
        let result = service.shouldShowWhatsNew()
        
        // Then
        XCTAssertFalse(result)
    }
    
    // MARK: - markWhatsNewAsShown Tests
    
    func testMarkWhatsNewAsShown_CallsVersionTrackerWithCurrentVersion() {
        // Given
        let expectedVersion = "1.2.3"
        mockVersionTracker.currentVersion = expectedVersion
        
        // When
        service.markWhatsNewAsShown()
        
        // Then
        XCTAssertEqual(mockVersionTracker.lastSetVersion, expectedVersion)
        XCTAssertTrue(mockVersionTracker.setLastShownVersionCalled)
    }
    
    func testMarkWhatsNewAsShown_HandlesVersionTrackerError() {
        // Given
        mockVersionTracker.currentVersion = "1.0.0"
        mockVersionTracker.shouldThrowOnSet = true
        mockVersionTracker.setError = VersionTrackerError.persistenceFailed("Test error")
        
        // When & Then (should not crash)
        service.markWhatsNewAsShown()
        
        // Verify the call was attempted
        XCTAssertTrue(mockVersionTracker.setLastShownVersionCalled)
    }
    
    // MARK: - getWhatsNewContent Tests
    
    func testGetWhatsNewContent_WhenContentAvailable_ReturnsContent() {
        // Given
        mockVersionTracker.currentVersion = "1.0.0"
        mockContentProvider.shouldSucceed = true
        
        // When
        let result = service.getWhatsNewContent()
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.version, "1.0.0")
        XCTAssertFalse(result?.sections.isEmpty ?? true)
    }
    
    func testGetWhatsNewContent_WhenContentLoadingFails_ReturnsFallbackContent() {
        // Given
        mockVersionTracker.currentVersion = "1.0.0"
        mockContentProvider.shouldThrowError = true
        mockContentProvider.errorToThrow = WhatsNewContentProvider.ContentError.contentNotFound
        
        // When
        let result = service.getWhatsNewContent()
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.version, "1.0.0")
        XCTAssertEqual(result?.sections.count, 1)
        XCTAssertEqual(result?.sections.first?.title, "App Updated")
    }
    
    func testGetWhatsNewContent_WhenEmptyVersion_ReturnsNil() {
        // Given
        mockVersionTracker.currentVersion = ""
        mockContentProvider.shouldThrowError = true
        
        // When
        let result = service.getWhatsNewContent()
        
        // Then
        XCTAssertNil(result)
    }
    
    func testGetWhatsNewContent_CachesSuccessfulResult() {
        // Given
        mockVersionTracker.currentVersion = "1.0.0"
        mockContentProvider.shouldSucceed = true
        
        // When
        let result1 = service.getWhatsNewContent()
        let result2 = service.getWhatsNewContent()
        
        // Then
        XCTAssertNotNil(result1)
        XCTAssertNotNil(result2)
        XCTAssertEqual(mockContentProvider.loadContentCallCount, 1) // Should only be called once due to caching
    }
    
    func testGetWhatsNewContent_DoesNotRetryAfterError() {
        // Given
        mockVersionTracker.currentVersion = "1.0.0"
        mockContentProvider.shouldThrowError = true
        mockContentProvider.errorToThrow = WhatsNewContentProvider.ContentError.corruptedData
        
        // When
        let result1 = service.getWhatsNewContent()
        let result2 = service.getWhatsNewContent()
        
        // Then
        XCTAssertNotNil(result1) // Should get fallback content
        XCTAssertNotNil(result2) // Should get fallback content again
        XCTAssertEqual(mockContentProvider.loadContentCallCount, 1) // Should only try once
    }
    
    // MARK: - showWhatsNewSheet Tests
    
    func testShowWhatsNewSheet_WhenContentAvailable_DoesNotCrash() {
        // Given
        mockVersionTracker.currentVersion = "1.0.0"
        mockContentProvider.shouldSucceed = true
        
        // When & Then (should not crash)
        service.showWhatsNewSheet()
    }
    
    func testShowWhatsNewSheet_WhenNoContent_DoesNotCrash() {
        // Given
        mockVersionTracker.currentVersion = ""
        mockContentProvider.shouldThrowError = true
        
        // When & Then (should not crash)
        service.showWhatsNewSheet()
    }
    
    // MARK: - Cache Management Tests
    
    func testClearCache_ResetsContentAndErrorState() {
        // Given
        mockVersionTracker.currentVersion = "1.0.0"
        mockContentProvider.shouldThrowError = true
        mockContentProvider.errorToThrow = WhatsNewContentProvider.ContentError.contentNotFound("Test error")
        
        // Load content to populate cache and error state
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
    
    // MARK: - Error Handling Tests
    
    func testGetWhatsNewContent_WithRetryLogic() {
        // Given
        mockVersionTracker.currentVersion = "1.0.0"
        mockContentProvider.shouldThrowError = true
        mockContentProvider.errorToThrow = WhatsNewContentProvider.ContentError.corruptedData("Test corruption")
        
        // When - First attempt should fail and return fallback
        let result1 = service.getWhatsNewContent()
        
        // Then - Should get fallback content
        XCTAssertNotNil(result1)
        XCTAssertEqual(result1?.sections.first?.title, "App Updated")
        
        // When - Second attempt should not retry immediately
        let result2 = service.getWhatsNewContent()
        
        // Then - Should get same fallback content without additional call
        XCTAssertNotNil(result2)
        XCTAssertEqual(mockContentProvider.loadContentCallCount, 1) // Should not retry immediately
    }
    
    func testGetWhatsNewContent_WithContentValidationFailure() {
        // Given
        mockVersionTracker.currentVersion = "1.0.0"
        mockContentProvider.shouldReturnInvalidContent = true
        
        // When
        let result = service.getWhatsNewContent()
        
        // Then - Should get fallback content due to validation failure
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.sections.first?.title, "App Updated")
    }
    
    func testGetWhatsNewContent_WithEmptyVersion() {
        // Given
        mockVersionTracker.currentVersion = ""
        
        // When
        let result = service.getWhatsNewContent()
        
        // Then
        XCTAssertNil(result) // Should return nil for empty version
    }
    
    func testGetDiagnosticInfo_ReturnsCompleteInformation() {
        // Given
        mockVersionTracker.currentVersion = "1.2.0"
        mockVersionTracker.lastShownVersion = "1.1.0"
        mockVersionTracker.isNewVersionResult = true
        mockContentProvider.shouldSucceed = true
        
        // Load content to populate state
        _ = service.getWhatsNewContent()
        
        // When
        let diagnosticInfo = service.getDiagnosticInfo()
        
        // Then
        XCTAssertEqual(diagnosticInfo.currentVersion, "1.2.0")
        XCTAssertEqual(diagnosticInfo.lastShownVersion, "1.1.0")
        XCTAssertTrue(diagnosticInfo.isNewVersion)
        XCTAssertTrue(diagnosticInfo.hasContent)
        XCTAssertEqual(diagnosticInfo.cacheStatus, .cached)
    }
    
    func testGetDiagnosticInfo_WithErrorState() {
        // Given
        mockVersionTracker.currentVersion = "1.0.0"
        mockContentProvider.shouldThrowError = true
        mockContentProvider.errorToThrow = WhatsNewContentProvider.ContentError.contentNotFound("Test error")
        
        // Load content to populate error state
        _ = service.getWhatsNewContent()
        
        // When
        let diagnosticInfo = service.getDiagnosticInfo()
        
        // Then
        XCTAssertNotNil(diagnosticInfo.contentLoadingError)
        XCTAssertTrue(diagnosticInfo.contentLoadAttempts > 0)
        XCTAssertNotNil(diagnosticInfo.lastContentLoadAttempt)
    }
}

// MARK: - Mock Classes

final class MockVersionTracker: VersionTrackerProtocol {
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

final class MockContentProvider: WhatsNewContentProviderProtocol {
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