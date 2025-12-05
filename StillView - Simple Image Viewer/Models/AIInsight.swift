
//
//  AIInsight.swift
//  StillView
//
//  Created by Vinny Carpenter on 10/11/25.
//

import Foundation

/// Represents a single AI-generated insight about an image.
/// Enhanced to support multiple insight categories, priorities, and rich metadata for improved user experience.
struct AIInsight: Identifiable, Equatable {
    let id = UUID()
    let type: InsightType
    let title: String
    let description: String
    let confidence: Double
    let action: InsightAction?
    let priority: InsightPriority
    let category: String?
    let metadata: [String: String]?
    let icon: String?
    
    /// Initialize an insight with all properties
    init(
        type: InsightType,
        title: String,
        description: String,
        confidence: Double,
        action: InsightAction? = nil,
        priority: InsightPriority = .medium,
        category: String? = nil,
        metadata: [String: String]? = nil,
        icon: String? = nil
    ) {
        self.type = type
        self.title = title
        self.description = description
        self.confidence = confidence
        self.action = action
        self.priority = priority
        self.category = category
        self.metadata = metadata
        self.icon = icon
    }
    
    /// Expanded insight types to cover comprehensive AI analysis
    enum InsightType: String, Codable {
        case compositional  // Framing, cropping, composition
        case quality        // Image quality issues and metrics
        case content        // What's in the image
        case technical      // EXIF data, metrics, camera settings
        case accessibility  // Color contrast, readability, VoiceOver
        case organization   // Auto-tags, collections, categorization
        case enhancement    // Specific editing recommendations
        case context        // Time, location, scene characteristics
        case privacy        // Faces, text, sensitive information
        case discovery      // Landmarks, barcodes, hidden details
        case action         // Quick actions based on content
    }
    
    /// Expanded action types for comprehensive user interaction
    enum InsightAction: String, Codable {
        case crop           // Crop or reframe image
        case enhance        // Apply enhancements
        case tag            // Add tags
        case export         // Export with specific format
        case share          // Share to specific destination
        case copy           // Copy text, barcode, or other content
        case navigate       // Navigate to location or URL
        case search         // Search for similar images
        case addToCollection // Add to collection
        case viewMetadata   // View technical metadata
        case none           // No action available
    }
    
    /// Priority level for insight importance and display ordering
    enum InsightPriority: Int, Codable, Comparable {
        case critical = 4   // Privacy, security, errors - show first
        case high = 3       // Actionable improvements
        case medium = 2     // Useful information
        case low = 1        // Nice to know
        
        static func < (lhs: InsightPriority, rhs: InsightPriority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    // MARK: - Equatable
    
    static func == (lhs: AIInsight, rhs: AIInsight) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - Convenience Accessors
    
    /// Returns a user-friendly description of the insight type
    var typeDescription: String {
        switch type {
        case .compositional: return "Composition"
        case .quality: return "Quality"
        case .content: return "Content"
        case .technical: return "Technical"
        case .accessibility: return "Accessibility"
        case .organization: return "Organization"
        case .enhancement: return "Enhancement"
        case .context: return "Context"
        case .privacy: return "Privacy"
        case .discovery: return "Discovery"
        case .action: return "Action"
        }
    }
    
    /// Returns a default SF Symbol name for the insight type if icon is not set
    var displayIcon: String {
        if let icon = icon {
            return icon
        }
        
        // Default icons based on type
        switch type {
        case .compositional: return "crop"
        case .quality: return "star.circle"
        case .content: return "doc.text.image"
        case .technical: return "info.circle"
        case .accessibility: return "accessibility"
        case .organization: return "folder"
        case .enhancement: return "wand.and.stars"
        case .context: return "location.circle"
        case .privacy: return "lock.shield"
        case .discovery: return "sparkles"
        case .action: return "bolt.circle"
        }
    }
    
    /// Returns true if this insight has an actionable step
    var isActionable: Bool {
        guard let action = action else { return false }
        return action != .none
    }
}
