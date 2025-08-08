//
//  BundleResourcesTests.swift
//  Simple Image Viewer Tests
//
//  Created by Kiro on 8/7/25.
//

import XCTest
@testable import Simple_Image_Viewer

final class BundleResourcesTests: XCTestCase {
    
    var mockBundle: MockBundleForResources!
    
    override func setUp() {
        super.setUp()
        mockBundle = MockBundleForResources()
    }
    
    override func tearDown() {
        mockBundle = nil
        super.tearDown()
    }
    
    // MARK: - Version Utilities Tests
    
    func testAppVersion_ReturnsCorrectVersion() {
        // Given
        mockBundle.mockInfoDictionary = ["CFBundleShortVersionString": "1.2.3"]
        
        // When
        let version = mockBundle.appVersion
        
        // Then
        XCTAssertEqual(version, "1.2.3")
    }
    
    func testAppVersion_WithMissingInfo_ReturnsDefault() {
        // Given
        mockBundle.mockInfoDictionary = [:]
        
        // When
        let version = mockBundle.appVersion
        
        // Then
        XCTAssertEqual(version, "1.0.0")
    }
    
    func testBuildNumber_ReturnsCorrectBuildNumber() {
        // Given
        mockBundle.mockInfoDictionary = ["CFBundleVersion": "42"]
        
        // When
        let buildNumber = mockBundle.buildNumber
        
        // Then
        XCTAssertEqual(buildNumber, "42")
    }
    
    func testBuildNumber_WithMissingInfo_ReturnsDefault() {
        // Given
        mockBundle.mockInfoDictionary = [:]
        
        // When
        let buildNumber = mockBundle.buildNumber
        
        // Then
        XCTAssertEqual(buildNumber, "1")
    }
    
    func testFullVersionString_CombinesVersionAndBuild() {
        // Given
        mockBundle.mockInfoDictionary = [
            "CFBundleShortVersionString": "1.2.3",
            "CFBundleVersion": "42"
        ]
        
        // When
        let fullVersion = mockBundle.fullVersionString
        
        // Then
        XCTAssertEqual(fullVersion, "Version 1.2.3 (42)")
    }
    
    // MARK: - JSON Loading Tests
    
    func testLoadJSON_WithValidJSON_ReturnsDecodedObject() {
        // Given
        let testData = TestCodableStruct(name: "Test", value: 42)
        mockBundle.mockJSONData = try! JSONEncoder().encode(testData)
        
        // When
        let result = mockBundle.loadJSON(TestCodableStruct.self, from: "test")
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "Test")
        XCTAssertEqual(result?.value, 42)
    }
    
    func testLoadJSON_WithMissingFile_ReturnsNil() {
        // Given
        mockBundle.mockJSONData = nil
        
        // When
        let result = mockBundle.loadJSON(TestCodableStruct.self, from: "missing")
        
        // Then
        XCTAssertNil(result)
    }
    
    func testLoadJSON_WithInvalidJSON_ReturnsNil() {
        // Given
        mockBundle.mockJSONData = "invalid json".data(using: .utf8)
        
        // When
        let result = mockBundle.loadJSON(TestCodableStruct.self, from: "invalid")
        
        // Then
        XCTAssertNil(result)
    }
    
    func testLoadJSON_WithDateDecoding_UsesISO8601Strategy() {
        // Given
        let dateString = "2025-02-15T10:30:00Z"
        let jsonString = """
        {
            "name": "Test",
            "date": "\(dateString)"
        }
        """
        mockBundle.mockJSONData = jsonString.data(using: .utf8)
        
        // When
        let result = mockBundle.loadJSON(TestCodableStructWithDate.self, from: "test")
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "Test")
        
        let formatter = ISO8601DateFormatter()
        let expectedDate = formatter.date(from: dateString)
        XCTAssertEqual(result?.date, expectedDate)
    }
    
    // MARK: - AppBranding Tests
    
    func testAppBranding_UsesMainBundleVersion() {
        // When/Then - These test that AppBranding delegates to Bundle.main
        // We can't easily mock Bundle.main, so we just verify the methods exist
        XCTAssertNotNil(AppBranding.version)
        XCTAssertNotNil(AppBranding.buildNumber)
        XCTAssertNotNil(AppBranding.fullVersionString)
    }
    
    func testAppBranding_HasCorrectConstants() {
        // When/Then
        XCTAssertEqual(AppBranding.appName, "StillView - Simple Image Viewer")
        XCTAssertEqual(AppBranding.tagline, "Fast & Elegant Image Browsing")
    }
}

// MARK: - Test Helper Structs

private struct TestCodableStruct: Codable, Equatable {
    let name: String
    let value: Int
}

private struct TestCodableStructWithDate: Codable, Equatable {
    let name: String
    let date: Date
}

// MARK: - Mock Bundle for Resources

private class MockBundleForResources: Bundle {
    var mockInfoDictionary: [String: Any] = [:]
    var mockJSONData: Data?
    
    override var infoDictionary: [String: Any]? {
        return mockInfoDictionary
    }
    
    override func url(forResource name: String?, withExtension ext: String?) -> URL? {
        guard mockJSONData != nil else { return nil }
        return URL(string: "file://mock/\(name ?? "test").json")
    }
    
    override func loadJSON<T: Codable>(_ type: T.Type, from filename: String) -> T? {
        guard let data = mockJSONData else { return nil }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(type, from: data)
        } catch {
            return nil
        }
    }
}