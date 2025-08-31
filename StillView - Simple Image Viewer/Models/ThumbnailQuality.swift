import Foundation
import AppKit

/// Enumeration for thumbnail quality levels
enum ThumbnailQuality: String, CaseIterable {
    case low
    case medium
    case high
    
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
    
    /// Maximum pixel size for this quality level
    var maxPixelSize: CGFloat {
        switch self {
        case .low: return 128
        case .medium: return 256
        case .high: return 512
        }
    }
    
    /// Interpolation quality for this level
    var interpolationQuality: CGInterpolationQuality {
        switch self {
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        }
    }
    
    /// Whether to use high-quality thumbnail generation
    var useHighQuality: Bool {
        switch self {
        case .low: return false
        case .medium: return true
        case .high: return true
        }
    }
}

/// Enumeration for thumbnail grid sizes
enum ThumbnailGridSize: String, CaseIterable {
    case small
    case medium
    case large
    
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
    
    /// Number of columns for the grid size
    var columnCount: Int {
        switch self {
        case .small:
            return 6
        case .medium:
            return 4
        case .large:
            return 3
        }
    }
}

// MARK: - ThumbnailQuality Extensions

extension ThumbnailQuality {
    /// Get the appropriate thumbnail size for a given container size
    /// - Parameter containerSize: The size of the container that will display the thumbnail
    /// - Returns: The optimal thumbnail size
    func optimalSize(for containerSize: CGSize) -> CGSize {
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let maxDimension = max(containerSize.width, containerSize.height) * scale
        
        // Ensure we don't exceed the quality's maximum pixel size
        let clampedDimension = min(maxDimension, maxPixelSize)
        
        return CGSize(width: clampedDimension, height: clampedDimension)
    }
}
