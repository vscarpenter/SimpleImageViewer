import SwiftUI

// MARK: - Glass Effect Modifier

/// A view modifier that applies modern glassmorphism effects to UI elements
struct GlassEffectModifier: ViewModifier {
    
    // MARK: - Properties
    
    let intensity: GlassIntensity
    let tintColor: Color?
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    let shadowRadius: CGFloat
    let shadowOffset: CGSize
    
    // MARK: - Initialization
    
    init(
        intensity: GlassIntensity = .medium,
        tintColor: Color? = nil,
        cornerRadius: CGFloat = 12,
        borderWidth: CGFloat = 0.5,
        shadowRadius: CGFloat = 8,
        shadowOffset: CGSize = CGSize(width: 0, height: 4)
    ) {
        self.intensity = intensity
        self.tintColor = tintColor
        self.cornerRadius = cornerRadius
        self.borderWidth = borderWidth
        self.shadowRadius = shadowRadius
        self.shadowOffset = shadowOffset
    }
    
    // MARK: - Body
    
    func body(content: Content) -> some View {
        content
            .background(
                glassBackground
            )
            .overlay(
                glassBorder
            )
            .overlay(
                glassHighlight
            )
            .shadow(
                color: Color.appGlassShadow,
                radius: shadowRadius,
                x: shadowOffset.width,
                y: shadowOffset.height
            )
    }
    
    // MARK: - Glass Components
    
    private var glassBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(intensity.materialType)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(effectiveTintColor)
            )
    }
    
    private var glassBorder: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(
                Color.appGlassBorder,
                lineWidth: borderWidth
            )
    }
    
    private var glassHighlight: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(
                Color.appGlassHighlight,
                lineWidth: borderWidth
            )
            .mask(
                Rectangle()
                    .frame(height: borderWidth * 2)
                    .offset(y: -(cornerRadius / 2))
            )
    }
    
    // MARK: - Computed Properties
    
    private var effectiveTintColor: Color {
        if let tintColor = tintColor {
            return tintColor.glassEffect(opacity: intensity.tintOpacity)
        }
        return intensity.defaultTintColor
    }
}

// MARK: - Glass Intensity

/// Defines the intensity levels for glass effects
enum GlassIntensity: CaseIterable {
    case subtle
    case medium
    case strong
    case prominent
    
    /// Material type for the glass effect
    var materialType: Material {
        switch self {
        case .subtle:
            return .thinMaterial
        case .medium:
            return .regularMaterial
        case .strong:
            return .thickMaterial
        case .prominent:
            return .ultraThickMaterial
        }
    }
    
    /// Default tint color for the intensity level
    var defaultTintColor: Color {
        switch self {
        case .subtle:
            return Color.appGlassTertiary
        case .medium:
            return Color.appGlassSecondary
        case .strong:
            return Color.appGlassPrimary
        case .prominent:
            return Color.appGlassPrimary.opacity(1.2)
        }
    }
    
    /// Tint opacity for custom colors
    var tintOpacity: Double {
        switch self {
        case .subtle:
            return 0.05
        case .medium:
            return 0.1
        case .strong:
            return 0.15
        case .prominent:
            return 0.2
        }
    }
    
    /// Human-readable description
    var description: String {
        switch self {
        case .subtle:
            return "Subtle"
        case .medium:
            return "Medium"
        case .strong:
            return "Strong"
        case .prominent:
            return "Prominent"
        }
    }
}

// MARK: - Specialized Glass Effects

/// Glass effect specifically designed for toolbar elements
struct ToolbarGlassEffect: ViewModifier {
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .modifier(GlassEffectModifier(
                intensity: isHovered ? .medium : .subtle,
                cornerRadius: 8,
                shadowRadius: isHovered ? 12 : 6,
                shadowOffset: CGSize(width: 0, height: isHovered ? 6 : 3)
            ))
            .animation(
                AnimationPresets.adaptiveHover() ?? .easeInOut(duration: 0.2),
                value: isHovered
            )
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

/// Glass effect for overlay panels and modals
struct OverlayGlassEffect: ViewModifier {
    let isVisible: Bool
    
    func body(content: Content) -> some View {
        content
            .modifier(GlassEffectModifier(
                intensity: .strong,
                cornerRadius: 16,
                shadowRadius: 24,
                shadowOffset: CGSize(width: 0, height: 12)
            ))
            .opacity(isVisible ? 1.0 : 0.0)
            .scaleEffect(isVisible ? 1.0 : 0.95)
            .animation(
                AnimationPresets.adaptiveTransition() ?? .easeInOut(duration: 0.3),
                value: isVisible
            )
    }
}

/// Glass effect for notification banners
struct NotificationGlassEffect: ViewModifier {
    let notificationType: NotificationType
    
    func body(content: Content) -> some View {
        content
            .modifier(GlassEffectModifier(
                intensity: .medium,
                tintColor: notificationType.tintColor,
                cornerRadius: 12,
                shadowRadius: 16,
                shadowOffset: CGSize(width: 0, height: 8)
            ))
    }
}

/// Glass effect for thumbnail containers
struct ThumbnailGlassEffect: ViewModifier {
    @State private var isHovered = false
    let isSelected: Bool
    
    func body(content: Content) -> some View {
        content
            .modifier(GlassEffectModifier(
                intensity: isSelected ? .strong : (isHovered ? .medium : .subtle),
                tintColor: isSelected ? Color.appAccent : nil,
                cornerRadius: 8,
                shadowRadius: isSelected ? 16 : (isHovered ? 12 : 4),
                shadowOffset: CGSize(width: 0, height: isSelected ? 8 : (isHovered ? 6 : 2))
            ))
            .animation(
                AnimationPresets.adaptiveHover() ?? .easeInOut(duration: 0.2),
                value: isHovered
            )
            .animation(
                AnimationPresets.adaptiveTransition() ?? .easeInOut(duration: 0.3),
                value: isSelected
            )
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - Supporting Types

/// Notification types for glass effect tinting
enum NotificationType {
    case success
    case warning
    case error
    case info
    case neutral
    
    var tintColor: Color {
        switch self {
        case .success:
            return Color.appSuccess
        case .warning:
            return Color.appWarning
        case .error:
            return Color.appError
        case .info:
            return Color.appInfo
        case .neutral:
            return Color.appText
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply glass effect with configurable intensity and appearance
    /// - Parameters:
    ///   - intensity: The intensity of the glass effect
    ///   - tintColor: Optional tint color for the glass effect
    ///   - cornerRadius: Corner radius for the glass shape
    ///   - borderWidth: Width of the glass border
    ///   - shadowRadius: Radius of the drop shadow
    ///   - shadowOffset: Offset of the drop shadow
    /// - Returns: View with glass effect applied
    func glassEffect(
        intensity: GlassIntensity = .medium,
        tintColor: Color? = nil,
        cornerRadius: CGFloat = 12,
        borderWidth: CGFloat = 0.5,
        shadowRadius: CGFloat = 8,
        shadowOffset: CGSize = CGSize(width: 0, height: 4)
    ) -> some View {
        self.modifier(GlassEffectModifier(
            intensity: intensity,
            tintColor: tintColor,
            cornerRadius: cornerRadius,
            borderWidth: borderWidth,
            shadowRadius: shadowRadius,
            shadowOffset: shadowOffset
        ))
    }
    
    /// Apply toolbar-specific glass effect
    /// - Returns: View with toolbar glass effect applied
    func toolbarGlassEffect() -> some View {
        self.modifier(ToolbarGlassEffect())
    }
    
    /// Apply overlay-specific glass effect
    /// - Parameter isVisible: Whether the overlay is currently visible
    /// - Returns: View with overlay glass effect applied
    func overlayGlassEffect(isVisible: Bool = true) -> some View {
        self.modifier(OverlayGlassEffect(isVisible: isVisible))
    }
    
    /// Apply notification-specific glass effect
    /// - Parameter type: The type of notification for appropriate tinting
    /// - Returns: View with notification glass effect applied
    func notificationGlassEffect(type: NotificationType = .neutral) -> some View {
        self.modifier(NotificationGlassEffect(notificationType: type))
    }
    
    /// Apply thumbnail-specific glass effect
    /// - Parameter isSelected: Whether the thumbnail is currently selected
    /// - Returns: View with thumbnail glass effect applied
    func thumbnailGlassEffect(isSelected: Bool = false) -> some View {
        self.modifier(ThumbnailGlassEffect(isSelected: isSelected))
    }
}

// MARK: - Glass Effect Presets

/// Predefined glass effect configurations for common use cases
struct GlassEffectPresets {
    
    /// Subtle glass effect for background elements
    static let background = GlassEffectModifier(
        intensity: .subtle,
        cornerRadius: 16,
        shadowRadius: 4,
        shadowOffset: CGSize(width: 0, height: 2)
    )
    
    /// Medium glass effect for interactive elements
    static let interactive = GlassEffectModifier(
        intensity: .medium,
        cornerRadius: 12,
        shadowRadius: 8,
        shadowOffset: CGSize(width: 0, height: 4)
    )
    
    /// Strong glass effect for prominent UI elements
    static let prominent = GlassEffectModifier(
        intensity: .strong,
        cornerRadius: 16,
        shadowRadius: 16,
        shadowOffset: CGSize(width: 0, height: 8)
    )
    
    /// Glass effect for floating panels
    static let floating = GlassEffectModifier(
        intensity: .prominent,
        cornerRadius: 20,
        shadowRadius: 24,
        shadowOffset: CGSize(width: 0, height: 12)
    )
    
    /// Compact glass effect for small UI elements
    static let compact = GlassEffectModifier(
        intensity: .medium,
        cornerRadius: 8,
        shadowRadius: 6,
        shadowOffset: CGSize(width: 0, height: 3)
    )
}