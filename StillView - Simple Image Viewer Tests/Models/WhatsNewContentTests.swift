//
//  WhatsNewContentTests.swift
//  Simple Image Viewer Tests
//
//  Created by Kiro on 8/6/25.
//

import XCTest
@testable import Simple_Image_Viewer

final class WhatsNewContentTests: XCTestCase {
    
    // MARK: - WhatsNewContent Tests
    
    func testWhatsNewContentInitialization() {
        // Given
        let version = "1.2.0"
        let releaseDate = Date()
        let sections = [
            WhatsNewSection(title: "New Features", items: [], type: .newFeatures)
        ]
        
        // When
        let content = WhatsNewContent(version: version, releaseDate: releaseDate, sections: sections)
        
        // Then
        XCTAssertEqual(content.version, version)
        XCTAssertEqual(content.releaseDate, releaseDate)
        XCTAssertEqual(content.sections.count, 1)
        XCTAssertEqual(content.sections.first?.title, "New Features")
    }
    
    func testWhatsNewContentWithoutReleaseDate() {
        // Given
        let version = "1.0.0"
        let sections: [WhatsNewSection] = []
        
        // When
        let content = WhatsNewContent(version: version, sections: sections)
        
        // Then
        XCTAssertEqual(content.version, version)
        XCTAssertNil(content.releaseDate)
        XCTAssertTrue(content.sections.isEmpty)
    }
    
    // MARK: - WhatsNewSection Tests
    
    func testWhatsNewSectionInitialization() {
        // Given
        let title = "Bug Fixes"
        let items = [
            WhatsNewItem(title: "Fixed crash", description: "Fixed a crash when opening large images")
        ]
        let type = SectionType.bugFixes
        
        // When
        let section = WhatsNewSection(title: title, items: items, type: type)
        
        // Then
        XCTAssertEqual(section.title, title)
        XCTAssertEqual(section.items.count, 1)
        XCTAssertEqual(section.type, type)
        XCTAssertEqual(section.items.first?.title, "Fixed crash")
    }
    
    // MARK: - SectionType Tests
    
    func testSectionTypeDisplayTitles() {
        XCTAssertEqual(SectionType.newFeatures.displayTitle, "New Features")
        XCTAssertEqual(SectionType.improvements.displayTitle, "Improvements")
        XCTAssertEqual(SectionType.bugFixes.displayTitle, "Bug Fixes")
    }
    
    func testSectionTypeRawValues() {
        XCTAssertEqual(SectionType.newFeatures.rawValue, "newFeatures")
        XCTAssertEqual(SectionType.improvements.rawValue, "improvements")
        XCTAssertEqual(SectionType.bugFixes.rawValue, "bugFixes")
    }
    
    func testSectionTypeCaseIterable() {
        let allCases = SectionType.allCases
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.newFeatures))
        XCTAssertTrue(allCases.contains(.improvements))
        XCTAssertTrue(allCases.contains(.bugFixes))
    }
    
    // MARK: - WhatsNewItem Tests
    
    func testWhatsNewItemInitialization() {
        // Given
        let title = "New Feature"
        let description = "This is a new feature"
        let isHighlighted = true
        
        // When
        let item = WhatsNewItem(title: title, description: description, isHighlighted: isHighlighted)
        
        // Then
        XCTAssertEqual(item.title, title)
        XCTAssertEqual(item.description, description)
        XCTAssertEqual(item.isHighlighted, isHighlighted)
    }
    
    func testWhatsNewItemWithDefaults() {
        // Given
        let title = "Simple Feature"
        
        // When
        let item = WhatsNewItem(title: title)
        
        // Then
        XCTAssertEqual(item.title, title)
        XCTAssertNil(item.description)
        XCTAssertFalse(item.isHighlighted)
    }
    
    // MARK: - Codable Tests
    
    func testWhatsNewContentCodable() throws {
        // Given
        let originalContent = WhatsNewContent(
            version: "1.2.0",
            releaseDate: Date(timeIntervalSince1970: 1640995200), // 2022-01-01
            sections: [
                WhatsNewSection(
                    title: "New Features",
                    items: [
                        WhatsNewItem(title: "Feature 1", description: "Description 1", isHighlighted: true)
                    ],
                    type: .newFeatures
                )
            ]
        )
        
        // When
        let encodedData = try JSONEncoder().encode(originalContent)
        let decodedContent = try JSONDecoder().decode(WhatsNewContent.self, from: encodedData)
        
        // Then
        XCTAssertEqual(decodedContent, originalContent)
    }
    
    func testSectionTypeCodable() throws {
        // Given
        let originalType = SectionType.improvements
        
        // When
        let encodedData = try JSONEncoder().encode(originalType)
        let decodedType = try JSONDecoder().decode(SectionType.self, from: encodedData)
        
        // Then
        XCTAssertEqual(decodedType, originalType)
    }
    
    // MARK: - Equatable Tests
    
    func testWhatsNewContentEquality() {
        // Given
        let content1 = WhatsNewContent(version: "1.0.0", sections: [])
        let content2 = WhatsNewContent(version: "1.0.0", sections: [])
        let content3 = WhatsNewContent(version: "1.0.1", sections: [])
        
        // Then
        XCTAssertEqual(content1, content2)
        XCTAssertNotEqual(content1, content3)
    }
    
    func testWhatsNewSectionEquality() {
        // Given
        let section1 = WhatsNewSection(title: "Features", items: [], type: .newFeatures)
        let section2 = WhatsNewSection(title: "Features", items: [], type: .newFeatures)
        let section3 = WhatsNewSection(title: "Fixes", items: [], type: .bugFixes)
        
        // Then
        XCTAssertEqual(section1, section2)
        XCTAssertNotEqual(section1, section3)
    }
    
    func testWhatsNewItemEquality() {
        // Given
        let item1 = WhatsNewItem(title: "Feature", description: "Desc", isHighlighted: true)
        let item2 = WhatsNewItem(title: "Feature", description: "Desc", isHighlighted: true)
        let item3 = WhatsNewItem(title: "Feature", description: "Different", isHighlighted: true)
        
        // Then
        XCTAssertEqual(item1, item2)
        XCTAssertNotEqual(item1, item3)
    }
}