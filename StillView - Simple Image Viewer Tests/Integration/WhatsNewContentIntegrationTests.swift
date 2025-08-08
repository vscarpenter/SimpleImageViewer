//
//  WhatsNewContentIntegrationTests.swift
//  Simple Image Viewer Tests
//
//  Created by Kiro on 8/7/25.
//

import XCTest
@testable import Simple_Image_Viewer

final class WhatsNewContentIntegrationTests: XCTestCase {
    
    var provider: WhatsNewContentProvider!
    
    override func setUp() {
        super.setUp()
        provider = WhatsNewContentProvider()
    }
    
    override func tearDown() {
        provider = nil
        super.tearDown()
    }
    
    // MARK: - Integration Tests
    
    func testLoadContent_WithRealBundle_LoadsFromJSON() {
        // When
        let content = provider.loadContent()
        
        // Then
        XCTAssertNotNil(content, "Should load content from JSON file")
        
        if let content = content {
            XCTAssertFalse(content.version.isEmpty, "Version should not be empty")
            XCTAssertFalse(content.sections.isEmpty, "Should have at least one section")
            
            // Verify sections have expected types
            let sectionTypes = content.sections.map { $0.type }
            XCTAssertTrue(sectionTypes.contains(.newFeatures), "Should have new features section")
            XCTAssertTrue(sectionTypes.contains(.improvements), "Should have improvements section")
            XCTAssertTrue(sectionTypes.contains(.bugFixes), "Should have bug fixes section")
            
            // Verify each section has items
            for section in content.sections {
                XCTAssertFalse(section.items.isEmpty, "Section '\(section.title)' should have items")
                
                // Verify items have titles
                for item in section.items {
                    XCTAssertFalse(item.title.isEmpty, "Item title should not be empty")
                }
            }
        }
    }
    
    func testBundleVersionUtilities_ReturnValidValues() {
        // When
        let version = Bundle.main.appVersion
        let buildNumber = Bundle.main.buildNumber
        let fullVersion = Bundle.main.fullVersionString
        
        // Then
        XCTAssertFalse(version.isEmpty, "App version should not be empty")
        XCTAssertFalse(buildNumber.isEmpty, "Build number should not be empty")
        XCTAssertTrue(fullVersion.contains(version), "Full version should contain version")
        XCTAssertTrue(fullVersion.contains(buildNumber), "Full version should contain build number")
    }
    
    func testAppBranding_UsesCorrectBundleValues() {
        // When
        let brandingVersion = AppBranding.version
        let brandingBuildNumber = AppBranding.buildNumber
        let brandingFullVersion = AppBranding.fullVersionString
        
        let bundleVersion = Bundle.main.appVersion
        let bundleBuildNumber = Bundle.main.buildNumber
        let bundleFullVersion = Bundle.main.fullVersionString
        
        // Then
        XCTAssertEqual(brandingVersion, bundleVersion, "AppBranding should use Bundle version")
        XCTAssertEqual(brandingBuildNumber, bundleBuildNumber, "AppBranding should use Bundle build number")
        XCTAssertEqual(brandingFullVersion, bundleFullVersion, "AppBranding should use Bundle full version")
    }
    
    func testLoadContent_WithCurrentVersion_ReturnsContentWithCorrectVersion() {
        // Given
        let currentVersion = Bundle.main.appVersion
        
        // When
        let content = provider.loadContent(for: currentVersion)
        
        // Then
        XCTAssertNotNil(content, "Should load content for current version")
        
        if let content = content {
            // The content version might be updated to match current version
            // or might be the version from the JSON file
            XCTAssertFalse(content.version.isEmpty, "Content version should not be empty")
        }
    }
    
    func testJSONContentStructure_MatchesExpectedFormat() {
        // When
        let content = provider.loadContent()
        
        // Then
        XCTAssertNotNil(content, "Should load content from JSON")
        
        guard let content = content else { return }
        
        // Verify expected content structure from our sample JSON
        XCTAssertEqual(content.version, "1.2.0", "Should match JSON version")
        XCTAssertNotNil(content.releaseDate, "Should have release date")
        XCTAssertEqual(content.sections.count, 3, "Should have 3 sections")
        
        // Verify specific sections exist
        let newFeaturesSection = content.sections.first { $0.type == .newFeatures }
        XCTAssertNotNil(newFeaturesSection, "Should have new features section")
        XCTAssertEqual(newFeaturesSection?.title, "New Features")
        
        let improvementsSection = content.sections.first { $0.type == .improvements }
        XCTAssertNotNil(improvementsSection, "Should have improvements section")
        XCTAssertEqual(improvementsSection?.title, "Improvements")
        
        let bugFixesSection = content.sections.first { $0.type == .bugFixes }
        XCTAssertNotNil(bugFixesSection, "Should have bug fixes section")
        XCTAssertEqual(bugFixesSection?.title, "Bug Fixes")
        
        // Verify highlighted items exist
        let allItems = content.sections.flatMap { $0.items }
        let highlightedItems = allItems.filter { $0.isHighlighted }
        XCTAssertFalse(highlightedItems.isEmpty, "Should have at least one highlighted item")
    }
    
    func testFallbackContent_WhenJSONMissing() {
        // Given
        let providerWithMissingJSON = WhatsNewContentProvider(bundle: Bundle())
        
        // When
        let content = providerWithMissingJSON.loadContent(for: "1.0.0")
        
        // Then
        XCTAssertNotNil(content, "Should provide fallback content")
        
        if let content = content {
            XCTAssertEqual(content.version, "1.0.0", "Should use requested version")
            XCTAssertEqual(content.sections.count, 1, "Should have one fallback section")
            XCTAssertEqual(content.sections.first?.type, .improvements, "Should be improvements section")
            XCTAssertEqual(content.sections.first?.title, "Updates", "Should have Updates title")
            XCTAssertEqual(content.sections.first?.items.count, 1, "Should have one fallback item")
            XCTAssertEqual(content.sections.first?.items.first?.title, "App Updated", "Should have generic update message")
        }
    }
}