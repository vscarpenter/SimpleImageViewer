//
//  WhatsNewContent.swift
//  StillView - Simple Image Viewer
//
//  Created by Kiro on 8/6/25.
//

import Foundation

/// Represents the complete "What's New" content for a specific version
struct WhatsNewContent: Codable, Equatable {
    let version: String
    let releaseDate: Date?
    let sections: [WhatsNewSection]
    
    init(version: String, releaseDate: Date? = nil, sections: [WhatsNewSection]) {
        self.version = version
        self.releaseDate = releaseDate
        self.sections = sections
    }
}

/// Represents a section within the "What's New" content (e.g., New Features, Bug Fixes)
struct WhatsNewSection: Codable, Equatable {
    let title: String
    let items: [WhatsNewItem]
    let type: SectionType
    
    init(title: String, items: [WhatsNewItem], type: SectionType) {
        self.title = title
        self.items = items
        self.type = type
    }
}

/// Defines the types of sections available in "What's New" content
enum SectionType: String, Codable, CaseIterable {
    case newFeatures
    case improvements
    case bugFixes
    
    var displayTitle: String {
        switch self {
        case .newFeatures:
            return "New Features"
        case .improvements:
            return "Improvements"
        case .bugFixes:
            return "Bug Fixes"
        }
    }
}

/// Represents an individual item within a "What's New" section
struct WhatsNewItem: Codable, Equatable {
    let title: String
    let description: String?
    let isHighlighted: Bool
    
    init(title: String, description: String? = nil, isHighlighted: Bool = false) {
        self.title = title
        self.description = description
        self.isHighlighted = isHighlighted
    }
}

// MARK: - Sample Content for Previews and Testing
extension WhatsNewContent {
    static var sampleContent: WhatsNewContent {
        WhatsNewContent(
            version: "1.2.0",
            releaseDate: Date(),
            sections: [
                .sampleNewFeatures,
                .sampleImprovements,
                .sampleBugFixes
            ]
        )
    }
}

extension WhatsNewSection {
    static var sampleNewFeatures: WhatsNewSection {
        WhatsNewSection(
            title: "New Features",
            items: [
                WhatsNewItem(
                    title: "Enhanced Thumbnail Grid",
                    description: "Improved performance and visual quality for better browsing experience",
                    isHighlighted: true
                ),
                WhatsNewItem(
                    title: "Keyboard Navigation",
                    description: "Navigate through images using arrow keys and shortcuts"
                )
            ],
            type: .newFeatures
        )
    }
    
    static var sampleImprovements: WhatsNewSection {
        WhatsNewSection(
            title: "Improvements",
            items: [
                WhatsNewItem(
                    title: "Faster Image Loading",
                    description: "Optimized image loading for smoother transitions"
                ),
                WhatsNewItem(
                    title: "Better Memory Management",
                    description: "Reduced memory usage when viewing large image collections"
                )
            ],
            type: .improvements
        )
    }
    
    static var sampleBugFixes: WhatsNewSection {
        WhatsNewSection(
            title: "Bug Fixes",
            items: [
                WhatsNewItem(
                    title: "Fixed Image Rotation Issues",
                    description: "Images now display with correct orientation"
                ),
                WhatsNewItem(
                    title: "Resolved Window State Persistence",
                    description: "Window size and position are now properly saved"
                )
            ],
            type: .bugFixes
        )
    }
}
