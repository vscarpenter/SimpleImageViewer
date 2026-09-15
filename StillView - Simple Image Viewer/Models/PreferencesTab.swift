import Foundation
import SwiftUI

// MARK: - Preferences Tab

extension Preferences {
    /// Enumeration of available preference tabs with enhanced properties
    enum Tab: String, CaseIterable, Identifiable {
        case general = "general"
        case intelligence = "intelligence"
        case shortcuts = "shortcuts"
        
        var id: String { rawValue }
        
        /// Content size follows the selected pane, as in native macOS settings.
        var contentHeight: CGFloat {
            switch self {
            case .general: return 320
            case .intelligence: return 360
            case .shortcuts: return 440
            }
        }

        /// Numeric order for tab transitions
        var order: Int {
            switch self {
            case .general:
                return 0
            case .intelligence:
                return 1
            case .shortcuts:
                return 2
            }
        }
        
        var title: String {
            switch self {
            case .general:
                return "General"
            case .intelligence:
                return "Intelligence"
            case .shortcuts:
                return "Shortcuts"
            }
        }
        
        var icon: String {
            switch self {
            case .general:
                return "gearshape"
            case .intelligence:
                return "sparkles"
            case .shortcuts:
                return "keyboard"
            }
        }
        
        var accessibilityLabel: String {
            switch self {
            case .general:
                return "General settings tab"
            case .intelligence:
                return "Intelligence settings tab"
            case .shortcuts:
                return "Keyboard shortcuts settings tab"
            }
        }
        
        /// Description for the tab content
        var description: String {
            switch self {
            case .general:
                return "Configure general application settings and behavior"
            case .intelligence:
                return "Control on-device image analysis and enhancements"
            case .shortcuts:
                return "Find built-in keyboard shortcuts"
            }
        }
    }
}
