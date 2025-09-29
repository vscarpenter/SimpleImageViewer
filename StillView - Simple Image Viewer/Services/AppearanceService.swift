import SwiftUI
import Combine

/// Service for managing appearance settings and their integration with the design system
class AppearanceService: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current toolbar style setting
    @Published var toolbarStyle: Preferences.ToolbarStyle = .floating
    
    /// Whether glass effects are enabled
    @Published var enableGlassEffects: Bool = true
    
    /// Current animation intensity level
    @Published var animationIntensity: Preferences.AnimationIntensity = .normal
    
    /// Whether hover effects are enabled
    @Published var enableHoverEffects: Bool = true
    
    /// Current thumbnail size setting
    @Published var thumbnailSize: Preferences.ThumbnailSize = .medium
    
    /// Whether metadata badges are shown on thumbnails
    @Published var showMetadataBadges: Bool = true
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var preferencesService: PreferencesService
    
    // MARK: - Singleton
    
    static let shared = AppearanceService()
    
    // MARK: - Initialization
    
    private init(preferencesService: PreferencesService = DefaultPreferencesService.shared) {
        self.preferencesService = preferencesService
        loadSettings()
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    /// Get animation that respects current settings and accessibility preferences
    /// - Parameter baseAnimation: The base animation to adapt
    /// - Returns: Adapted animation based on current settings
    func adaptiveAnimation(_ baseAnimation: Animation) -> Animation? {
        // First check accessibility preferences
        guard let accessibilityAnimation = AccessibilityService.shared.adaptiveAnimation(baseAnimation) else {
            return nil
        }
        
        // Then adapt based on animation intensity
        switch animationIntensity {
        case .minimal:
            return .easeInOut(duration: 0.1)
        case .normal:
            return accessibilityAnimation
        case .enhanced:
            // Make animations more dramatic
            if let spring = accessibilityAnimation as? Animation {
                return .spring(response: 0.6, dampingFraction: 0.6, blendDuration: 0.0)
            }
            return accessibilityAnimation
        }
    }
    
    /// Get hover animation that respects current settings
    /// - Returns: Hover animation or nil if hover effects are disabled
    func adaptiveHoverAnimation() -> Animation? {
        guard enableHoverEffects else { return nil }
        
        switch animationIntensity {
        case .minimal:
            return .easeInOut(duration: 0.1)
        case .normal:
            return .easeInOut(duration: 0.2)
        case .enhanced:
            return .spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.0)
        }
    }
    
    /// Get scale factor for hover effects based on animation intensity
    /// - Returns: Scale factor for hover effects
    func hoverScaleFactor() -> CGFloat {
        guard enableHoverEffects else { return 1.0 }
        return animationIntensity.scaleFactor
    }
    
    /// Get background color for glass effects
    /// - Parameter opacity: Base opacity for the effect
    /// - Returns: Glass background color or fallback if glass effects are disabled
    func glassBackground(opacity: Double = 0.7) -> Color {
        if enableGlassEffects {
            return Color.adaptive(
                light: Color.white.opacity(opacity),
                dark: Color.black.opacity(opacity * 0.8)
            )
        } else {
            return Color.appSecondaryBackground
        }
    }
    
    /// Get border color for glass effects
    /// - Returns: Glass border color or standard border if glass effects are disabled
    func glassBorder() -> Color {
        if enableGlassEffects {
            return Color.appGlassBorder
        } else {
            return Color.appBorder
        }
    }
    
    /// Get shadow modifier based on current settings
    /// - Returns: Shadow view modifier
    func adaptiveShadow() -> some ViewModifier {
        if enableGlassEffects {
            return ShadowModifier(shadow: DesignTokens.shadowSubtle)
        } else {
            return ShadowModifier(shadow: nil)
        }
    }
    
    /// Get toolbar background based on current style
    /// - Returns: Appropriate background view for toolbar
    func toolbarBackground() -> AnyView {
        switch toolbarStyle {
        case .floating:
            return AnyView(
                RoundedRectangle(cornerRadius: 8)
                    .fill(glassBackground())
                    .modifier(adaptiveShadow())
            )
        case .attached:
            return AnyView(
                Rectangle()
                    .fill(Color.appSecondaryBackground)
            )
        }
    }
    
    /// Update appearance settings and notify observers
    /// - Parameters:
    ///   - toolbarStyle: New toolbar style
    ///   - enableGlassEffects: Whether to enable glass effects
    ///   - animationIntensity: New animation intensity
    ///   - enableHoverEffects: Whether to enable hover effects
    ///   - thumbnailSize: New thumbnail size
    ///   - showMetadataBadges: Whether to show metadata badges
    func updateSettings(
        toolbarStyle: Preferences.ToolbarStyle? = nil,
        enableGlassEffects: Bool? = nil,
        animationIntensity: Preferences.AnimationIntensity? = nil,
        enableHoverEffects: Bool? = nil,
        thumbnailSize: Preferences.ThumbnailSize? = nil,
        showMetadataBadges: Bool? = nil
    ) {
        if let toolbarStyle = toolbarStyle {
            self.toolbarStyle = toolbarStyle
        }
        
        if let enableGlassEffects = enableGlassEffects {
            self.enableGlassEffects = enableGlassEffects
        }
        
        if let animationIntensity = animationIntensity {
            self.animationIntensity = animationIntensity
        }
        
        if let enableHoverEffects = enableHoverEffects {
            self.enableHoverEffects = enableHoverEffects
        }
        
        if let thumbnailSize = thumbnailSize {
            self.thumbnailSize = thumbnailSize
        }
        
        if let showMetadataBadges = showMetadataBadges {
            self.showMetadataBadges = showMetadataBadges
        }
        
        saveSettings()
    }
    
    // MARK: - Private Methods
    
    private func loadSettings() {
        let userDefaults = UserDefaults.standard
        
        // Load toolbar style
        let toolbarRawValue = userDefaults.string(forKey: "PreferencesToolbarStyle") ?? "floating"
        toolbarStyle = Preferences.ToolbarStyle(rawValue: toolbarRawValue) ?? .floating
        
        // Load glass effects
        enableGlassEffects = userDefaults.object(forKey: "PreferencesEnableGlassEffects") as? Bool ?? true
        
        // Load animation intensity
        let animationRawValue = userDefaults.string(forKey: "PreferencesAnimationIntensity") ?? "normal"
        animationIntensity = Preferences.AnimationIntensity(rawValue: animationRawValue) ?? .normal
        
        // Load hover effects
        enableHoverEffects = userDefaults.object(forKey: "PreferencesEnableHoverEffects") as? Bool ?? true
        
        // Load thumbnail size from PreferencesService
        switch preferencesService.defaultThumbnailGridSize {
        case .small:
            thumbnailSize = .small
        case .medium:
            thumbnailSize = .medium
        case .large:
            thumbnailSize = .large
        }
        
        // Load metadata badges
        showMetadataBadges = userDefaults.object(forKey: "PreferencesShowMetadataBadges") as? Bool ?? true
    }
    
    private func saveSettings() {
        let userDefaults = UserDefaults.standard
        
        userDefaults.set(toolbarStyle.rawValue, forKey: "PreferencesToolbarStyle")
        userDefaults.set(enableGlassEffects, forKey: "PreferencesEnableGlassEffects")
        userDefaults.set(animationIntensity.rawValue, forKey: "PreferencesAnimationIntensity")
        userDefaults.set(enableHoverEffects, forKey: "PreferencesEnableHoverEffects")
        userDefaults.set(showMetadataBadges, forKey: "PreferencesShowMetadataBadges")
        
        // Update PreferencesService for thumbnail size
        let gridSize: ThumbnailGridSize
        switch thumbnailSize {
        case .small:
            gridSize = .small
        case .medium:
            gridSize = .medium
        case .large:
            gridSize = .large
        }
        preferencesService.defaultThumbnailGridSize = gridSize
        preferencesService.savePreferences()
    }
    
    private func setupBindings() {
        // Automatically save when settings change
        Publishers.CombineLatest4(
            $toolbarStyle,
            $enableGlassEffects,
            $animationIntensity,
            $enableHoverEffects
        )
        .dropFirst()
        .sink { [weak self] _, _, _, _ in
            self?.saveSettings()
        }
        .store(in: &cancellables)
        
        Publishers.CombineLatest(
            $thumbnailSize,
            $showMetadataBadges
        )
        .dropFirst()
        .sink { [weak self] _, _ in
            self?.saveSettings()
        }
        .store(in: &cancellables)
    }
}

// MARK: - Supporting View Modifier

struct ShadowModifier: ViewModifier {
    let shadow: Shadow?
    
    func body(content: Content) -> some View {
        if let shadow = shadow {
            content.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
        } else {
            content
        }
    }
}

// MARK: - Environment Integration

struct AppearanceServiceKey: EnvironmentKey {
    static let defaultValue = AppearanceService.shared
}

extension EnvironmentValues {
    var appearanceService: AppearanceService {
        get { self[AppearanceServiceKey.self] }
        set { self[AppearanceServiceKey.self] = newValue }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply appearance-aware glass background
    func adaptiveGlassBackground(opacity: Double = 0.7) -> some View {
        self.background(AppearanceService.shared.glassBackground(opacity: opacity))
    }
    
    /// Apply appearance-aware hover effects
    func adaptiveHoverEffect<V: Equatable>(_ value: V) -> some View {
        self.animation(AppearanceService.shared.adaptiveHoverAnimation(), value: value)
    }
    
    /// Apply appearance-aware animation
    func adaptiveAnimation<V: Equatable>(_ baseAnimation: Animation, value: V) -> some View {
        self.animation(AppearanceService.shared.adaptiveAnimation(baseAnimation), value: value)
    }
}
