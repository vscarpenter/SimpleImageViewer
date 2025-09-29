import Foundation
import SwiftUI

// MARK: - Preferences Tab

extension Preferences {
    /// Enumeration of available preference tabs with enhanced properties
    enum Tab: String, CaseIterable, Identifiable {
        case general = "general"
        case appearance = "appearance"
        case shortcuts = "shortcuts"
        
        var id: String { rawValue }
        
        /// Numeric order for tab transitions
        var order: Int {
            switch self {
            case .general:
                return 0
            case .appearance:
                return 1
            case .shortcuts:
                return 2
            }
        }
        
        var title: String {
            switch self {
            case .general:
                return "General"
            case .appearance:
                return "Appearance"
            case .shortcuts:
                return "Shortcuts"
            }
        }
        
        var icon: String {
            switch self {
            case .general:
                return "gearshape"
            case .appearance:
                return "paintbrush"
            case .shortcuts:
                return "keyboard"
            }
        }
        
        var accessibilityLabel: String {
            switch self {
            case .general:
                return "General preferences tab"
            case .appearance:
                return "Appearance preferences tab"
            case .shortcuts:
                return "Keyboard shortcuts preferences tab"
            }
        }
        
        /// Description for the tab content
        var description: String {
            switch self {
            case .general:
                return "Configure general application settings and behavior"
            case .appearance:
                return "Customize the visual appearance and animations"
            case .shortcuts:
                return "Manage keyboard shortcuts and key bindings"
            }
        }
    }
}
