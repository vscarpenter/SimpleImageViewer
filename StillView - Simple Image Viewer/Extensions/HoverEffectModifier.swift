import SwiftUI

// MARK: - Hover Effect Modifier

/// A view modifier that provides configurable hover effects with smooth transitions
struct HoverEffectModifier: ViewModifier {
    
    // MARK: - Properties
    
    @State private var isHovered = false
    
    let intensity: HoverIntensity
    let scaleEffect: Bool
    let opacityEffect: Bool
    let customScale: CGFloat?
    let customOpacity: Double?
    
    // MARK: - Initialization
    
    init(
        intensity: HoverIntensity = .normal,
        scaleEffect: Bool = true,
        opacityEffect: Bool = false,
        customScale: CGFloat? = nil,
        customOpacity: Double? = nil
    ) {
        self.intensity = intensity
        self.scaleEffect = scaleEffect
        self.opacityEffect = opacityEffect
        self.customScale = customScale
        self.customOpacity = customOpacity
    }
    
    // MARK: - Body
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scaleEffect ? (isHovered ? effectiveScale : 1.0) : 1.0)
            .opacity(opacityEffect ? (isHovered ? effectiveOpacity : 1.0) : 1.0)
            .animation(AnimationPresets.adaptiveHover(), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
    
    // MARK: - Computed Properties
    
    private var effectiveScale: CGFloat {
        if let customScale = customScale {
            return customScale
        }
        return intensity.scaleValue
    }
    
    private var effectiveOpacity: Double {
        if let customOpacity = customOpacity {
            return customOpacity
        }
        return intensity.opacityValue
    }
}

// MARK: - Hover Intensity

/// Defines the intensity levels for hover effects
enum HoverIntensity: CaseIterable {
    case subtle
    case normal
    case strong
    
    /// Scale factor for the hover effect
    var scaleValue: CGFloat {
        switch self {
        case .subtle:
            return 1.02
        case .normal:
            return 1.05
        case .strong:
            return 1.08
        }
    }
    
    /// Opacity value for the hover effect
    var opacityValue: Double {
        switch self {
        case .subtle:
            return 0.9
        case .normal:
            return 0.8
        case .strong:
            return 0.7
        }
    }
    
    /// Human-readable description
    var description: String {
        switch self {
        case .subtle:
            return "Subtle"
        case .normal:
            return "Normal"
        case .strong:
            return "Strong"
        }
    }
}

// MARK: - Enhanced Button Styles with Hover Effects

/// Enhanced toolbar button style that includes hover effects
struct EnhancedToolbarButtonStyle: ButtonStyle {
    let hoverIntensity: HoverIntensity
    
    init(hoverIntensity: HoverIntensity = .normal) {
        self.hoverIntensity = hoverIntensity
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? .appAccent : .appText)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        configuration.isPressed 
                        ? Color.appAccent.opacity(0.2)
                        : Color.appButtonBackground.opacity(0.8)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        configuration.isPressed 
                        ? Color.appAccent.opacity(0.3)
                        : Color.appBorder.opacity(0.2), 
                        lineWidth: 0.5
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(AnimationPresets.adaptiveHover(), value: configuration.isPressed)
            .modifier(HoverEffectModifier(
                intensity: hoverIntensity,
                scaleEffect: true,
                opacityEffect: false
            ))
    }
}

/// Enhanced compact toolbar button style that includes hover effects
struct EnhancedCompactToolbarButtonStyle: ButtonStyle {
    let hoverIntensity: HoverIntensity
    
    init(hoverIntensity: HoverIntensity = .subtle) {
        self.hoverIntensity = hoverIntensity
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? .appAccent : .appText)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        configuration.isPressed 
                        ? Color.appAccent.opacity(0.2)
                        : Color.appButtonBackground.opacity(0.8)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        configuration.isPressed 
                        ? Color.appAccent.opacity(0.3)
                        : Color.appBorder.opacity(0.2), 
                        lineWidth: 0.5
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(AnimationPresets.adaptiveHover(), value: configuration.isPressed)
            .modifier(HoverEffectModifier(
                intensity: hoverIntensity,
                scaleEffect: true,
                opacityEffect: false
            ))
    }
}

// MARK: - Specialized Hover Effects

/// Hover effect specifically designed for image thumbnails
struct ThumbnailHoverEffect: ViewModifier {
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .shadow(
                color: .black.opacity(isHovered ? 0.3 : 0.1),
                radius: isHovered ? 8 : 4,
                x: 0,
                y: isHovered ? 4 : 2
            )
            .animation(AnimationPresets.adaptiveHover(), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

/// Hover effect for navigation controls
struct NavigationControlHoverEffect: ViewModifier {
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? 1.1 : 1.0)
            .opacity(isHovered ? 1.0 : 0.7)
            .animation(AnimationPresets.adaptiveSpring(.snappy), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

/// Hover effect for overlay elements
struct OverlayHoverEffect: ViewModifier {
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isHovered ? 1.0 : 0.8)
            .animation(AnimationPresets.adaptiveHover(), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply hover effect with configurable intensity
    /// - Parameters:
    ///   - intensity: The intensity of the hover effect
    ///   - scaleEffect: Whether to apply scale effect on hover
    ///   - opacityEffect: Whether to apply opacity effect on hover
    ///   - customScale: Custom scale value (overrides intensity)
    ///   - customOpacity: Custom opacity value (overrides intensity)
    /// - Returns: View with hover effect applied
    func hoverEffect(
        intensity: HoverIntensity = .normal,
        scaleEffect: Bool = true,
        opacityEffect: Bool = false,
        customScale: CGFloat? = nil,
        customOpacity: Double? = nil
    ) -> some View {
        self.modifier(HoverEffectModifier(
            intensity: intensity,
            scaleEffect: scaleEffect,
            opacityEffect: opacityEffect,
            customScale: customScale,
            customOpacity: customOpacity
        ))
    }
    
    /// Apply thumbnail-specific hover effect
    /// - Returns: View with thumbnail hover effect applied
    func thumbnailHoverEffect() -> some View {
        self.modifier(ThumbnailHoverEffect())
    }
    
    /// Apply navigation control hover effect
    /// - Returns: View with navigation control hover effect applied
    func navigationControlHoverEffect() -> some View {
        self.modifier(NavigationControlHoverEffect())
    }
    
    /// Apply overlay element hover effect
    /// - Returns: View with overlay hover effect applied
    func overlayHoverEffect() -> some View {
        self.modifier(OverlayHoverEffect())
    }
    
    /// Apply enhanced toolbar button style with hover effects
    /// - Parameter intensity: The hover intensity level
    /// - Returns: View with enhanced toolbar button style applied
    func enhancedToolbarButtonStyle(intensity: HoverIntensity = .normal) -> some View {
        self.buttonStyle(EnhancedToolbarButtonStyle(hoverIntensity: intensity))
    }
    
    /// Apply enhanced compact toolbar button style with hover effects
    /// - Parameter intensity: The hover intensity level
    /// - Returns: View with enhanced compact toolbar button style applied
    func enhancedCompactToolbarButtonStyle(intensity: HoverIntensity = .subtle) -> some View {
        self.buttonStyle(EnhancedCompactToolbarButtonStyle(hoverIntensity: intensity))
    }
}

// MARK: - Hover State Management

/// Observable object for managing global hover states
class HoverStateManager: ObservableObject {
    @Published var hoveredElement: String?
    @Published var hoverIntensity: HoverIntensity = .normal
    
    static let shared = HoverStateManager()
    
    private init() {}
    
    /// Set the currently hovered element
    /// - Parameter elementId: Identifier for the hovered element
    func setHovered(_ elementId: String?) {
        hoveredElement = elementId
    }
    
    /// Check if a specific element is currently hovered
    /// - Parameter elementId: Identifier to check
    /// - Returns: True if the element is currently hovered
    func isHovered(_ elementId: String) -> Bool {
        return hoveredElement == elementId
    }
    
    /// Update the global hover intensity
    /// - Parameter intensity: New hover intensity level
    func updateIntensity(_ intensity: HoverIntensity) {
        hoverIntensity = intensity
    }
}

// MARK: - Environment Integration

/// Environment key for hover state manager
struct HoverStateManagerKey: EnvironmentKey {
    static let defaultValue = HoverStateManager.shared
}

extension EnvironmentValues {
    var hoverStateManager: HoverStateManager {
        get { self[HoverStateManagerKey.self] }
        set { self[HoverStateManagerKey.self] = newValue }
    }
}