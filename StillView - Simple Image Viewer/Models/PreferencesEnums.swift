import Foundation
import SwiftUI

enum Preferences {}

extension Preferences {
    /// Defines the available toolbar styles for the application
    enum ToolbarStyle: String, CaseIterable, Identifiable {
        case floating = "floating"
        case attached = "attached"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .floating:
                return "Floating"
            case .attached:
                return "Attached"
            }
        }
        
        var description: String {
            switch self {
            case .floating:
                return "Toolbar floats above content with transparency"
            case .attached:
                return "Toolbar is attached to the top of the window"
            }
        }
    }
}

extension Preferences {
    /// Defines the intensity levels for animations throughout the application
    enum AnimationIntensity: String, CaseIterable, Identifiable {
        case minimal = "minimal"
        case normal = "normal"
        case enhanced = "enhanced"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .minimal:
                return "Minimal"
            case .normal:
                return "Normal"
            case .enhanced:
                return "Enhanced"
            }
        }
        
        var description: String {
            switch self {
            case .minimal:
                return "Reduced animations for performance"
            case .normal:
                return "Standard animation experience"
            case .enhanced:
                return "Rich animations and effects"
            }
        }
        
        var scaleFactor: Double {
            switch self {
            case .minimal:
                return 0.5
            case .normal:
                return 1.0
            case .enhanced:
                return 1.5
            }
        }
        
        var duration: Double {
            switch self {
            case .minimal:
                return 0.15
            case .normal:
                return 0.3
            case .enhanced:
                return 0.45
            }
        }
    }
}

extension Preferences {
    /// Defines the available thumbnail sizes for the grid view
    enum ThumbnailSize: String, CaseIterable, Identifiable {
        case small = "small"
        case medium = "medium"
        case large = "large"
        
        var id: String { rawValue }
        
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
        
        var description: String {
            switch self {
            case .small:
                return "Compact thumbnails for dense layouts"
            case .medium:
                return "Balanced size and detail"
            case .large:
                return "Large thumbnails for detailed previews"
            }
        }
        
        var size: CGSize {
            switch self {
            case .small:
                return CGSize(width: 120, height: 90)
            case .medium:
                return CGSize(width: 160, height: 120)
            case .large:
                return CGSize(width: 200, height: 150)
            }
        }
        
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
}

extension Preferences {
    /// Defines the default zoom levels for image viewing
    enum ZoomLevel: String, CaseIterable, Identifiable {
        case fitToWindow = "fitToWindow"
        case actualSize = "actualSize"
        case fillWindow = "fillWindow"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .fitToWindow:
                return "Fit to Window"
            case .actualSize:
                return "Actual Size"
            case .fillWindow:
                return "Fill Window"
            }
        }
        
        var description: String {
            switch self {
            case .fitToWindow:
                return "Image fits entirely within the window"
            case .actualSize:
                return "Image displays at its original pixel dimensions"
            case .fillWindow:
                return "Image fills the entire window"
            }
        }
        
        var zoomFactor: Double {
            switch self {
            case .fitToWindow:
                return -1.0 // Special value indicating fit-to-window
            case .actualSize:
                return 1.0
            case .fillWindow:
                return -2.0 // Special value indicating fill-window
            }
        }
    }
}
