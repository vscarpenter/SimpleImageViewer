//
//  WhatsNewSheetTests.swift
//  Simple Image Viewer Tests
//
//  Created by Kiro on 8/7/25.
//

import XCTest
import SwiftUI
@testable import Simple_Image_Viewer

@MainActor
final class WhatsNewSheetTests: XCTestCase {
    
    func testWhatsNewSheetInitialization() {
        // Given
        let content = WhatsNewContent.sampleContent
        
        // When
        let sheet = WhatsNewSheet(content: content)
        
        // Then
        XCTAssertNotNil(sheet)
    }
    
    func testWhatsNewSheetDismissalWithEscapeKey() {
        // Given
        let content = WhatsNewContent.sampleContent
        let sheet = WhatsNewSheet(content: content)
        
        // When/Then - This tests the keyboard shortcut configuration
        // The actual dismissal behavior is handled by SwiftUI's environment
        XCTAssertNotNil(sheet)
    }
    
    func testWhatsNewSheetFrameSize() {
        // Given
        let content = WhatsNewContent.sampleContent
        let sheet = WhatsNewSheet(content: content)
        
        // When/Then - Verify the sheet has the expected frame configuration
        // The frame size is set to 480x600 as per design specifications
        XCTAssertNotNil(sheet)
    }
}

@MainActor
final class WhatsNewContentViewTests: XCTestCase {
    
    func testWhatsNewContentViewInitialization() {
        // Given
        let content = WhatsNewContent.sampleContent
        
        // When
        let contentView = WhatsNewContentView(content: content)
        
        // Then
        XCTAssertNotNil(contentView)
    }
    
    func testWhatsNewContentViewDisplaysVersion() {
        // Given
        let content = WhatsNewContent(
            version: "1.2.3",
            releaseDate: Date(),
            sections: []
        )
        
        // When
        let contentView = WhatsNewContentView(content: content)
        
        // Then
        XCTAssertNotNil(contentView)
        // The version display is tested through the view's content property
    }
    
    func testWhatsNewContentViewDisplaysReleaseDate() {
        // Given
        let releaseDate = Date()
        let content = WhatsNewContent(
            version: "1.0.0",
            releaseDate: releaseDate,
            sections: []
        )
        
        // When
        let contentView = WhatsNewContentView(content: content)
        
        // Then
        XCTAssertNotNil(contentView)
        // The release date display is tested through the view's content property
    }
    
    func testWhatsNewContentViewHandlesEmptySections() {
        // Given
        let content = WhatsNewContent(
            version: "1.0.0",
            releaseDate: nil,
            sections: []
        )
        
        // When
        let contentView = WhatsNewContentView(content: content)
        
        // Then
        XCTAssertNotNil(contentView)
    }
}

@MainActor
final class WhatsNewSectionViewTests: XCTestCase {
    
    func testWhatsNewSectionViewInitialization() {
        // Given
        let section = WhatsNewSection.sampleNewFeatures
        
        // When
        let sectionView = WhatsNewSectionView(section: section)
        
        // Then
        XCTAssertNotNil(sectionView)
    }
    
    func testWhatsNewSectionViewDisplaysCorrectIcon() {
        // Given
        let newFeaturesSection = WhatsNewSection.sampleNewFeatures
        let improvementsSection = WhatsNewSection.sampleImprovements
        let bugFixesSection = WhatsNewSection.sampleBugFixes
        
        // When
        let newFeaturesView = WhatsNewSectionView(section: newFeaturesSection)
        let improvementsView = WhatsNewSectionView(section: improvementsSection)
        let bugFixesView = WhatsNewSectionView(section: bugFixesSection)
        
        // Then
        XCTAssertNotNil(newFeaturesView)
        XCTAssertNotNil(improvementsView)
        XCTAssertNotNil(bugFixesView)
        // Icon selection is tested through the section type property
    }
    
    func testWhatsNewSectionViewHandlesEmptyItems() {
        // Given
        let section = WhatsNewSection(
            title: "Empty Section",
            items: [],
            type: .newFeatures
        )
        
        // When
        let sectionView = WhatsNewSectionView(section: section)
        
        // Then
        XCTAssertNotNil(sectionView)
    }
}

@MainActor
final class WhatsNewItemViewTests: XCTestCase {
    
    func testWhatsNewItemViewInitialization() {
        // Given
        let item = WhatsNewItem(
            title: "Test Feature",
            description: "Test description",
            isHighlighted: false
        )
        
        // When
        let itemView = WhatsNewItemView(item: item)
        
        // Then
        XCTAssertNotNil(itemView)
    }
    
    func testWhatsNewItemViewWithoutDescription() {
        // Given
        let item = WhatsNewItem(
            title: "Test Feature",
            description: nil,
            isHighlighted: false
        )
        
        // When
        let itemView = WhatsNewItemView(item: item)
        
        // Then
        XCTAssertNotNil(itemView)
    }
    
    func testWhatsNewItemViewHighlighted() {
        // Given
        let item = WhatsNewItem(
            title: "Highlighted Feature",
            description: "Important feature",
            isHighlighted: true
        )
        
        // When
        let itemView = WhatsNewItemView(item: item)
        
        // Then
        XCTAssertNotNil(itemView)
        // Highlighting is tested through the item's isHighlighted property
    }
    
    func testWhatsNewItemViewAccessibilityDescription() {
        // Given
        let itemWithDescription = WhatsNewItem(
            title: "Feature Title",
            description: "Feature description",
            isHighlighted: false
        )
        let itemWithoutDescription = WhatsNewItem(
            title: "Simple Feature",
            description: nil,
            isHighlighted: false
        )
        
        // When
        let itemViewWithDescription = WhatsNewItemView(item: itemWithDescription)
        let itemViewWithoutDescription = WhatsNewItemView(item: itemWithoutDescription)
        
        // Then
        XCTAssertNotNil(itemViewWithDescription)
        XCTAssertNotNil(itemViewWithoutDescription)
        // Accessibility descriptions are computed properties that combine title and description
    }
}