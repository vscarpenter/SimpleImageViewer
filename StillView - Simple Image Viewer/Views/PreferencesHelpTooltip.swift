import SwiftUI

/// Contextual help tooltip for complex preference settings
struct PreferencesHelpTooltip: View {
    
    // MARK: - Properties
    
    let title: String
    let content: String
    let type: HelpTooltipType
    @State private var isVisible = false
    
    // MARK: - Body
    
    var body: some View {
        Button(action: {
            withAnimation(AnimationPresets.adaptiveSpring(.gentle)) {
                isVisible.toggle()
            }
        }) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 12))
                .foregroundColor(.appSecondaryText)
        }
        .buttonStyle(.plain)
        .help("Show help for \(title)")
        // Ensure the popover is dismissed if the parent view/window disappears
        .onDisappear {
            isVisible = false
        }
        .popover(isPresented: $isVisible, arrowEdge: .bottom) {
            HelpTooltipContent(
                title: title,
                content: content,
                type: type,
                onDismiss: {
                    withAnimation(AnimationPresets.adaptiveHover()) {
                        isVisible = false
                    }
                }
            )
        }
    }
}

/// Content view for help tooltip popover
struct HelpTooltipContent: View {
    
    // MARK: - Properties
    
    let title: String
    let content: String
    let type: HelpTooltipType
    let onDismiss: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: type.iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(type.color)
                
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appText)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.appSecondaryText)
                }
                .buttonStyle(.plain)
                .hoverEffect(intensity: .subtle)
            }
            
            // Content
            Text(content)
                .font(.system(size: 12))
                .foregroundColor(.appSecondaryText)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            
            // Additional tips based on type
            if let additionalTip = type.additionalTip {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 10))
                        .foregroundColor(.appWarning)
                    
                    Text(additionalTip)
                        .font(.system(size: 10))
                        .foregroundColor(.appSecondaryText)
                        .italic()
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .frame(maxWidth: 280)
        .background(Color.appBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.appBorder.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(8)
        .shadowSubtle()
    }
}

/// Types of help tooltips with associated styling and behavior
enum HelpTooltipType {
    case information
    case warning
    case tip
    case performance
    case accessibility
    
    var iconName: String {
        switch self {
        case .information:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .tip:
            return "lightbulb"
        case .performance:
            return "speedometer"
        case .accessibility:
            return "accessibility"
        }
    }
    
    var color: Color {
        switch self {
        case .information:
            return .appInfo
        case .warning:
            return .appWarning
        case .tip:
            return .appSuccess
        case .performance:
            return .appWarning
        case .accessibility:
            return .appInfo
        }
    }
    
    var additionalTip: String? {
        switch self {
        case .performance:
            return "Tip: Test settings on your hardware to find the best balance."
        case .accessibility:
            return "Tip: These settings work with macOS accessibility features."
        default:
            return nil
        }
    }
}

// MARK: - Predefined Help Content

extension PreferencesHelpTooltip {
    
    /// Help tooltip for animation intensity setting
    static func animationIntensity() -> PreferencesHelpTooltip {
        PreferencesHelpTooltip(
            title: "Animation Intensity",
            content: "Controls how dramatic interface animations appear. Minimal uses simple fades, Normal adds smooth transitions, and Enhanced includes bouncy spring animations. Enhanced animations may impact performance on older Macs.",
            type: .performance
        )
    }
    
    /// Help tooltip for glassmorphism effects
    static func glassEffects() -> PreferencesHelpTooltip {
        PreferencesHelpTooltip(
            title: "Glassmorphism Effects",
            content: "Modern translucent visual effects that create depth and visual hierarchy. Uses system materials and blur effects for a contemporary look. May reduce performance on older hardware or when combined with enhanced animations.",
            type: .performance
        )
    }
    
    /// Help tooltip for hover effects
    static func hoverEffects() -> PreferencesHelpTooltip {
        PreferencesHelpTooltip(
            title: "Hover Effects",
            content: "Visual feedback when hovering over interface elements like buttons and thumbnails. Includes subtle scaling, color changes, and shadow effects. Automatically disabled when Reduce Motion is enabled in System Preferences.",
            type: .accessibility
        )
    }
    
    /// Help tooltip for toolbar style
    static func toolbarStyle() -> PreferencesHelpTooltip {
        PreferencesHelpTooltip(
            title: "Toolbar Style",
            content: "Floating toolbars appear as rounded panels with shadows, while attached toolbars connect directly to the window edge. Floating style works best with glassmorphism effects enabled.",
            type: .information
        )
    }
    
    /// Help tooltip for thumbnail size
    static func thumbnailSize() -> PreferencesHelpTooltip {
        PreferencesHelpTooltip(
            title: "Thumbnail Size",
            content: "Affects both the thumbnail strip and grid view. Larger thumbnails show more detail but use more memory and may scroll more slowly with large image collections. Small thumbnails are recommended for collections over 500 images.",
            type: .performance
        )
    }
    
    /// Help tooltip for slideshow interval
    static func slideshowInterval() -> PreferencesHelpTooltip {
        PreferencesHelpTooltip(
            title: "Slideshow Duration",
            content: "How long each image is displayed during automatic slideshow mode. Shorter intervals work well for quick previews, while longer intervals are better for detailed viewing or presentations.",
            type: .information
        )
    }
    
    /// Help tooltip for keyboard shortcuts
    static func keyboardShortcuts() -> PreferencesHelpTooltip {
        PreferencesHelpTooltip(
            title: "Keyboard Shortcuts",
            content: "Click any shortcut to record a new key combination. The system automatically checks for conflicts with existing shortcuts and system shortcuts. Use the search field to quickly find specific shortcuts.",
            type: .information
        )
    }
    
    /// Help tooltip for shortcut conflicts
    static func shortcutConflicts() -> PreferencesHelpTooltip {
        PreferencesHelpTooltip(
            title: "Shortcut Conflicts",
            content: "Red indicators show shortcuts that conflict with system shortcuts or other app shortcuts. Click the conflicting shortcut to record a new, unique combination. Some system shortcuts cannot be overridden.",
            type: .warning
        )
    }
    
    /// Help tooltip for metadata badges
    static func metadataBadges() -> PreferencesHelpTooltip {
        PreferencesHelpTooltip(
            title: "Metadata Badges",
            content: "Small labels on thumbnails showing file format (JPG, PNG, etc.) and file size. Helpful for identifying different image types in mixed collections, but may clutter the view with many thumbnails.",
            type: .information
        )
    }
    
    /// Help tooltip for file deletion confirmation
    static func deleteConfirmation() -> PreferencesHelpTooltip {
        PreferencesHelpTooltip(
            title: "Delete Confirmation",
            content: "Shows a confirmation dialog before moving images to Trash. Recommended to prevent accidental deletions, especially when using keyboard shortcuts. Files moved to Trash can be recovered.",
            type: .tip
        )
    }
}

// MARK: - View Extensions

extension View {
    /// Add a help tooltip to any view
    /// - Parameters:
    ///   - title: Title for the help tooltip
    ///   - content: Detailed help content
    ///   - type: Type of help tooltip (affects styling)
    /// - Returns: View with help tooltip attached
    func helpTooltip(title: String, content: String, type: HelpTooltipType = .information) -> some View {
        HStack(spacing: 4) {
            self
            PreferencesHelpTooltip(title: title, content: content, type: type)
        }
    }
    
    /// Add a predefined help tooltip for common preference settings
    /// - Parameter helpType: Predefined help tooltip type
    /// - Returns: View with help tooltip attached
    func preferencesHelp(_ helpType: PreferencesHelpType) -> some View {
        HStack(spacing: 4) {
            self
            helpType.tooltip
        }
    }
}

/// Predefined help tooltip types for common preferences
enum PreferencesHelpType {
    case animationIntensity
    case glassEffects
    case hoverEffects
    case toolbarStyle
    case thumbnailSize
    case slideshowInterval
    case keyboardShortcuts
    case shortcutConflicts
    case metadataBadges
    case deleteConfirmation
    
    var tooltip: PreferencesHelpTooltip {
        switch self {
        case .animationIntensity:
            return .animationIntensity()
        case .glassEffects:
            return .glassEffects()
        case .hoverEffects:
            return .hoverEffects()
        case .toolbarStyle:
            return .toolbarStyle()
        case .thumbnailSize:
            return .thumbnailSize()
        case .slideshowInterval:
            return .slideshowInterval()
        case .keyboardShortcuts:
            return .keyboardShortcuts()
        case .shortcutConflicts:
            return .shortcutConflicts()
        case .metadataBadges:
            return .metadataBadges()
        case .deleteConfirmation:
            return .deleteConfirmation()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct PreferencesHelpTooltip_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Animation Intensity")
                PreferencesHelpTooltip.animationIntensity()
            }
            
            HStack {
                Text("Glassmorphism Effects")
                PreferencesHelpTooltip.glassEffects()
            }
            
            HStack {
                Text("Hover Effects")
                PreferencesHelpTooltip.hoverEffects()
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}
#endif
