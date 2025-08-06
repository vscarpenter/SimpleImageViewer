import Foundation

/// Enumeration for thumbnail quality levels
enum ThumbnailQuality: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    /// Display name for the quality level
    var displayName: String {
        switch self {
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        }
    }
    
    /// Size multiplier for the quality level
    var sizeMultiplier: CGFloat {
        switch self {
        case .low:
            return 0.5
        case .medium:
            return 1.0
        case .high:
            return 2.0
        }
    }
    
    /// Compression quality for JPEG thumbnails
    var compressionQuality: CGFloat {
        switch self {
        case .low:
            return 0.3
        case .medium:
            return 0.7
        case .high:
            return 0.9
        }
    }
}

/// Enumeration for thumbnail grid sizes
enum ThumbnailGridSize: String, CaseIterable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    
    /// Display name for the grid size
    var displayName: String {
        switch self {
        case .small:
            return "Small"
        case .medium:
            return "Medium"
        case .large:
            return "Large"
        }
    }
    
    /// Base thumbnail size for the grid size
    var thumbnailSize: CGSize {
        switch self {
        case .small:
            return CGSize(width: 120, height: 90)
        case .medium:
            return CGSize(width: 160, height: 120)
        case .large:
            return CGSize(width: 200, height: 150)
        }
    }
    
    /// Spacing between thumbnails
    var spacing: CGFloat {
        switch self {
        case .small:
            return 8
        case .medium:
            return 12
        case .large:
            return 16
        }
    }
    
    /// Padding around the grid
    var padding: CGFloat {
        switch self {
        case .small:
            return 12
        case .medium:
            return 16
        case .large:
            return 20
        }
    }
}