//
//  WhatsNewContentProviderTests.swift
//  Simple Image Viewer Tests
//
//  Created by Kiro on 8/7/25.
//

import XCTest
@testable import Simple_Image_Viewer

final class WhatsNewContentProviderTests: XCTestCase {
    
    var provider: WhatsNewContentProvider!
    var mockBundle: MockBundle!
    
    override func setUp() {
        super.setUp()
        mockBundle = MockBundle()
        provider = WhatsNewContentProvider(bundle: mockBundle)
    }
    
    override func tearDown() {
        provider = nil
        mockBundle = nil
        super.tearDown()
    }
    
    // MARK: - Content Loading Tests
    
    func testLoadContent_WithValidJSON_ReturnsContent() {
        // Given
        let expectedContent = createSampleContent()
        mockBundle.jsonContent = expectedContent
        mockBundle.mockVersion = "1.2.0"
        
        // When
        let result = try? provider.loadContent()
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.version, "1.2.0")
        XCTAssertEqual(result?.sections.count, 2)
        XCTAssertEqual(result?.sections.first?.title, "New Features")
    }
    
    func testLoadContent_WithSpecificVersion_ReturnsVersionSpecificContent() {
        // Given
        let expectedContent = createSampleContent(version: "1.1.0")
        mockBundle.versionSpecificContent["1-1-0"] = expectedContent
        
        // When
        let result = try? provider.loadContent(for: "1.1.0")
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.version, "1.1.0")
    }
    
    func testLoadContent_WithMissingJSON_ReturnsFallbackContent() {
        // Given
        mockBundle.jsonContent = nil
        mockBundle.mockVersion = "1.0.0"
        
        // When
        let result = try? provider.loadContent()
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.version, "1.0.0")
        XCTAssertEqual(result?.sections.count, 1)
        XCTAssertEqual(result?.sections.first?.title, "Updates")
        XCTAssertEqual(result?.sections.first?.items.first?.title, "App Updated")
    }
    
    func testLoadContent_WithInvalidJSON_ReturnsFallbackContent() {
        // Given
        mockBundle.shouldFailJSONDecoding = true
        mockBundle.mockVersion = "1.0.0"
        
        // When
        let result = try? provider.loadContent()
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.version, "1.0.0")
        XCTAssertEqual(result?.sections.first?.type, .improvements)
    }
    
    // MARK: - Caching Tests
    
    func testLoadContent_CachesResult() {
        // Given
        let expectedContent = createSampleContent()
        mockBundle.jsonContent = expectedContent
        mockBundle.mockVersion = "1.2.0"
        
        // When
        let result1 = try? provider.loadContent()
        mockBundle.jsonContent = nil // Remove content to test caching
        let result2 = try? provider.loadContent()
        
        // Then
        XCTAssertNotNil(result1)
        XCTAssertNotNil(result2)
        XCTAssertEqual(result1?.version, result2?.version)
        XCTAssertEqual(result1?.sections.count, result2?.sections.count)
    }
    
    func testLoadContent_InvalidatesCacheForDifferentVersion() {
        // Given
        let content1 = createSampleContent(version: "1.0.0")
        let content2 = createSampleContent(version: "1.1.0")
        mockBundle.jsonContent = content1
        
        // When
        let result1 = try? provider.loadContent(for: "1.0.0")
        mockBundle.jsonContent = content2
        let result2 = try? provider.loadContent(for: "1.1.0")
        
        // Then
        XCTAssertEqual(result1?.version, "1.0.0")
        XCTAssertEqual(result2?.version, "1.1.0")
    }
    
    // MARK: - Version Handling Tests
    
    func testLoadContent_UpdatesVersionInDefaultContent() {
        // Given
        let contentWithOldVersion = createSampleContent(version: "1.0.0")
        mockBundle.jsonContent = contentWithOldVersion
        mockBundle.mockVersion = "1.2.0"
        
        // When
        let result = try? provider.loadContent()
        
        // Then
        XCTAssertEqual(result?.version, "1.2.0") // Should use current version
        XCTAssertEqual(result?.sections.count, contentWithOldVersion.sections.count)
    }
    
    // MARK: - Fallback Content Tests
    
    func testCreateFallbackContent_HasCorrectStructure() {
        // Given
        mockBundle.jsonContent = nil
        mockBundle.mockVersion = "1.0.0"
        
        // When
        let result = try? provider.loadContent()
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.version, "1.0.0")
        XCTAssertEqual(result?.sections.count, 1)
        
        let section = result?.sections.first
        XCTAssertEqual(section?.title, "Updates")
        XCTAssertEqual(section?.type, .improvements)
        XCTAssertEqual(section?.items.count, 1)
        
        let item = section?.items.first
        XCTAssertEqual(item?.title, "App Updated")
        XCTAssertNotNil(item?.description)
        XCTAssertFalse(item?.isHighlighted ?? true)
    }
    
    // MARK: - Error Handling Tests
    
    func testLoadContent_WithEmptyVersion_ThrowsError() {
        // When & Then
        XCTAssertThrowsError(try provider.loadContent(for: "")) { error in
            XCTAssertTrue(error is WhatsNewContentProvider.ContentError)
            if case WhatsNewContentProvider.ContentError.invalidVersion(let message) = error {
                XCTAssertTrue(message.contains("cannot be empty"))
            } else {
                XCTFail("Expected ContentError.invalidVersion")
            }
        }
    }
    
    func testLoadContent_WithMaxAttemptsReached_ThrowsError() {
        // Given
        mockBundle.shouldFailJSONDecoding = true
        mockBundle.mockVersion = "1.0.0"
        
        // When - Exhaust all attempts
        for _ in 0..<3 {
            _ = try? provider.loadContent(for: "1.0.0")
        }
        
        // Then - Next attempt should throw max attempts error
        XCTAssertThrowsError(try provider.loadContent(for: "1.0.0")) { error in
            XCTAssertTrue(error is WhatsNewContentProvider.ContentError)
            if case WhatsNewContentProvider.ContentError.maxAttemptsReached = error {
                // Expected error type
            } else {
                XCTFail("Expected ContentError.maxAttemptsReached")
            }
        }
    }
    
    func testLoadContent_WithCorruptedJSON_ThrowsError() {
        // Given
        mockBundle.shouldReturnCorruptedData = true
        mockBundle.mockVersion = "1.0.0"
        
        // When & Then
        XCTAssertThrowsError(try provider.loadContent()) { error in
            XCTAssertTrue(error is WhatsNewContentProvider.ContentError)
            if case WhatsNewContentProvider.ContentError.corruptedData = error {
                // Expected error type
            } else {
                XCTFail("Expected ContentError.corruptedData")
            }
        }
    }
    
    func testLoadContent_WithInvalidJSONFormat_ThrowsError() {
        // Given
        mockBundle.shouldReturnInvalidJSON = true
        mockBundle.mockVersion = "1.0.0"
        
        // When & Then
        XCTAssertThrowsError(try provider.loadContent()) { error in
            XCTAssertTrue(error is WhatsNewContentProvider.ContentError)
            if case WhatsNewContentProvider.ContentError.invalidFormat = error {
                // Expected error type
            } else {
                XCTFail("Expected ContentError.invalidFormat")
            }
        }
    }
    
    func testLoadContent_WithEmptyJSONFile_ThrowsError() {
        // Given
        mockBundle.shouldReturnEmptyData = true
        mockBundle.mockVersion = "1.0.0"
        
        // When & Then
        XCTAssertThrowsError(try provider.loadContent()) { error in
            XCTAssertTrue(error is WhatsNewContentProvider.ContentError)
            if case WhatsNewContentProvider.ContentError.corruptedData(let message) = error {
                XCTAssertTrue(message.contains("empty"))
            } else {
                XCTFail("Expected ContentError.corruptedData for empty file")
            }
        }
    }
    
    func testLoadContent_WithInvalidContentStructure_ThrowsError() {
        // Given
        let invalidContent = WhatsNewContent(
            version: "", // Empty version should fail validation
            releaseDate: nil,
            sections: []
        )
        mockBundle.jsonContent = invalidContent
        mockBundle.mockVersion = "1.0.0"
        
        // When & Then
        XCTAssertThrowsError(try provider.loadContent()) { error in
            XCTAssertTrue(error is WhatsNewContentProvider.ContentError)
            if case WhatsNewContentProvider.ContentError.invalidFormat = error {
                // Expected error type
            } else {
                XCTFail("Expected ContentError.invalidFormat")
            }
        }
    }
    
    func testLoadContent_WithEmptySections_ThrowsError() {
        // Given
        let invalidContent = WhatsNewContent(
            version: "1.0.0",
            releaseDate: nil,
            sections: [] // Empty sections should fail validation
        )
        mockBundle.jsonContent = invalidContent
        mockBundle.mockVersion = "1.0.0"
        
        // When & Then
        XCTAssertThrowsError(try provider.loadContent()) { error in
            XCTAssertTrue(error is WhatsNewContentProvider.ContentError)
            if case WhatsNewContentProvider.ContentError.invalidFormat(let message) = error {
                XCTAssertTrue(message.contains("no sections"))
            } else {
                XCTFail("Expected ContentError.invalidFormat for empty sections")
            }
        }
    }
    
    func testLoadContent_WithSectionEmptyTitle_ThrowsError() {
        // Given
        let invalidSection = WhatsNewSection(
            title: "", // Empty title should fail validation
            items: [WhatsNewItem(title: "Test", description: "Test")],
            type: .newFeatures
        )
        let invalidContent = WhatsNewContent(
            version: "1.0.0",
            releaseDate: nil,
            sections: [invalidSection]
        )
        mockBundle.jsonContent = invalidContent
        mockBundle.mockVersion = "1.0.0"
        
        // When & Then
        XCTAssertThrowsError(try provider.loadContent()) { error in
            XCTAssertTrue(error is WhatsNewContentProvider.ContentError)
            if case WhatsNewContentProvider.ContentError.invalidFormat(let message) = error {
                XCTAssertTrue(message.contains("empty title"))
            } else {
                XCTFail("Expected ContentError.invalidFormat for empty section title")
            }
        }
    }
    
    func testLoadContent_WithSectionEmptyItems_ThrowsError() {
        // Given
        let invalidSection = WhatsNewSection(
            title: "Test Section",
            items: [], // Empty items should fail validation
            type: .newFeatures
        )
        let invalidContent = WhatsNewContent(
            version: "1.0.0",
            releaseDate: nil,
            sections: [invalidSection]
        )
        mockBundle.jsonContent = invalidContent
        mockBundle.mockVersion = "1.0.0"
        
        // When & Then
        XCTAssertThrowsError(try provider.loadContent()) { error in
            XCTAssertTrue(error is WhatsNewContentProvider.ContentError)
            if case WhatsNewContentProvider.ContentError.invalidFormat(let message) = error {
                XCTAssertTrue(message.contains("no items"))
            } else {
                XCTFail("Expected ContentError.invalidFormat for empty items")
            }
        }
    }
    
    func testLoadContent_WithItemEmptyTitle_ThrowsError() {
        // Given
        let invalidItem = WhatsNewItem(
            title: "", // Empty title should fail validation
            description: "Test description"
        )
        let invalidSection = WhatsNewSection(
            title: "Test Section",
            items: [invalidItem],
            type: .newFeatures
        )
        let invalidContent = WhatsNewContent(
            version: "1.0.0",
            releaseDate: nil,
            sections: [invalidSection]
        )
        mockBundle.jsonContent = invalidContent
        mockBundle.mockVersion = "1.0.0"
        
        // When & Then
        XCTAssertThrowsError(try provider.loadContent()) { error in
            XCTAssertTrue(error is WhatsNewContentProvider.ContentError)
            if case WhatsNewContentProvider.ContentError.invalidFormat(let message) = error {
                XCTAssertTrue(message.contains("empty title"))
            } else {
                XCTFail("Expected ContentError.invalidFormat for empty item title")
            }
        }
    }
    
    func testLoadContent_FallbackAfterMaxAttempts() {
        // Given
        mockBundle.shouldFailJSONDecoding = true
        mockBundle.mockVersion = "1.0.0"
        
        // When - Exhaust all attempts
        var result: WhatsNewContent?
        for _ in 0..<4 { // One more than max attempts
            result = try? provider.loadContent(for: "1.0.0")
        }
        
        // Then - Should eventually return fallback content
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.version, "1.0.0")
        XCTAssertEqual(result?.sections.first?.title, "Updates")
    }
    
    // MARK: - Helper Methods
    
    private func createSampleContent(version: String = "1.2.0") -> WhatsNewContent {
        let newFeaturesSection = WhatsNewSection(
            title: "New Features",
            items: [
                WhatsNewItem(
                    title: "Feature 1",
                    description: "Description 1",
                    isHighlighted: true
                )
            ],
            type: .newFeatures
        )
        
        let improvementsSection = WhatsNewSection(
            title: "Improvements",
            items: [
                WhatsNewItem(
                    title: "Improvement 1",
                    description: "Description 1",
                    isHighlighted: false
                )
            ],
            type: .improvements
        )
        
        return WhatsNewContent(
            version: version,
            releaseDate: Date(),
            sections: [newFeaturesSection, improvementsSection]
        )
    }
}

// MARK: - Mock Bundle

private class MockBundle: Bundle {
    var jsonContent: WhatsNewContent?
    var versionSpecificContent: [String: WhatsNewContent] = [:]
    var shouldFailJSONDecoding = false
    var shouldReturnCorruptedData = false
    var shouldReturnInvalidJSON = false
    var shouldReturnEmptyData = false
    var mockVersion = "1.0.0"
    
    override var appVersion: String {
        return mockVersion
    }
    
    override func url(forResource name: String?, withExtension ext: String?) -> URL? {
        guard let name = name, ext == "json" else {
            return nil
        }
        
        // Handle version-specific content
        if name.hasPrefix("whats-new-") {
            let versionKey = String(name.dropFirst("whats-new-".count))
            if versionSpecificContent[versionKey] != nil {
                return URL(string: "file://mock/\(name).json")
            }
            return nil
        }
        
        // Handle default content
        if name == "whats-new" && (jsonContent != nil || shouldFailJSONDecoding || shouldReturnCorruptedData || shouldReturnInvalidJSON || shouldReturnEmptyData) {
            return URL(string: "file://mock/whats-new.json")
        }
        
        return nil
    }
    
    override func loadJSON<T: Codable>(_ type: T.Type, from filename: String) -> T? {
        if shouldFailJSONDecoding {
            return nil
        }
        
        if shouldReturnCorruptedData {
            // Simulate corrupted data by returning nil
            return nil
        }
        
        if shouldReturnInvalidJSON {
            // Simulate invalid JSON structure
            return nil
        }
        
        if shouldReturnEmptyData {
            // Simulate empty data
            return nil
        }
        
        // Handle version-specific content
        if filename.hasPrefix("whats-new-") {
            let versionKey = String(filename.dropFirst("whats-new-".count))
            if let content = versionSpecificContent[versionKey] as? T {
                return content
            }
            return nil
        }
        
        // Handle default content
        if filename == "whats-new" {
            return jsonContent as? T
        }
        
        return nil
    }
}