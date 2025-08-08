import SwiftUI
import Combine

/// Service for managing accessibility settings and preferences
class AccessibilityService: ObservableObject {
    // MARK: - Published Properties
    
    /// Whether high contrast mode is enabled
    @Published var isHighContrastEnabled: Bool = false
    
    /// Whether reduced motion is enabled
    @Published var isReducedMotionEnabled: Bool = false
    
    /// Whether VoiceOver is currently running
    @Published var isVoiceOverEnabled: Bool = false
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Singleton
    
    static let shared = AccessibilityService()
    
    private init() {
        setupAccessibilityMonitoring()
        updateAccessibilitySettings()
    }
    
    // MARK: - Public Methods
    
    /// Get color that adapts to high contrast mode
    /// - Parameters:
    ///   - normalColor: Color to use in normal mode
    ///   - highContrastColor: Color to use in high contrast mode
    /// - Returns: Appropriate color for current accessibility settings
    func adaptiveColor(normal normalColor: Color, highContrast highContrastColor: Color) -> Color {
        return isHighContrastEnabled ? highContrastColor : normalColor
    }
    
    /// Get text color that ensures proper contrast
    /// - Parameter background: Background color to contrast against
    /// - Returns: Text color with appropriate contrast
    func contrastingTextColor(for background: Color) -> Color {
        if isHighContrastEnabled {
            // In high contrast mode, use pure black or white
            return background == .black || background == .blue || background == .red ? .white : .black
        } else {
            // Normal contrast mode
            return background == .black ? .white : .primary
        }
    }
    
    /// Get animation duration that respects reduced motion preferences
    /// - Parameter normalDuration: Normal animation duration
    /// - Returns: Adjusted duration for accessibility preferences
    func adaptiveAnimationDuration(_ normalDuration: Double) -> Double {
        return isReducedMotionEnabled ? 0.0 : normalDuration
    }
    
    /// Get animation that respects reduced motion preferences
    /// - Parameter normalAnimation: Normal animation
    /// - Returns: Adjusted animation for accessibility preferences
    func adaptiveAnimation(_ normalAnimation: Animation) -> Animation? {
        return isReducedMotionEnabled ? nil : normalAnimation
    }
    
    // MARK: - Private Methods
    
    private func setupAccessibilityMonitoring() {
        // Monitor for accessibility changes
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                self?.updateAccessibilitySettings()
            }
            .store(in: &cancellables)
        
        // Monitor for reduced motion changes
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                self?.updateReducedMotionSetting()
            }
            .store(in: &cancellables)
        
        // Monitor VoiceOver status
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                self?.updateVoiceOverSetting()
            }
            .store(in: &cancellables)
    }
    
    private func updateAccessibilitySettings() {
        DispatchQueue.main.async { [weak self] in
            self?.updateHighContrastSetting()
            self?.updateReducedMotionSetting()
            self?.updateVoiceOverSetting()
        }
    }
    
    private func updateHighContrastSetting() {
        // Check for high contrast mode using UserDefaults
        isHighContrastEnabled = UserDefaults.standard.bool(forKey: "AppleInterfaceStyleSwitchesAutomatically") ||
                               UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }
    
    private func updateReducedMotionSetting() {
        // Check for reduced motion preference using UserDefaults
        isReducedMotionEnabled = UserDefaults.standard.bool(forKey: "ReduceMotion")
    }
    
    private func updateVoiceOverSetting() {
        // Check if VoiceOver is running using accessibility APIs
        // Note: This is a basic implementation - for production use more robust detection
        isVoiceOverEnabled = false // Simplified for now - can be enhanced with proper accessibility detection
    }
}

// MARK: - SwiftUI Integration

/// Environment key for AccessibilityService
struct AccessibilityServiceKey: EnvironmentKey {
    static let defaultValue = AccessibilityService.shared
}

extension EnvironmentValues {
    var accessibilityService: AccessibilityService {
        get { self[AccessibilityServiceKey.self] }
        set { self[AccessibilityServiceKey.self] = newValue }
    }
}


// MARK: - View Modifiers

/// View modifier that adapts colors for high contrast mode
struct HighContrastAdaptive: ViewModifier {
    @ObservedObject private var accessibilityService = AccessibilityService.shared
    
    let normalColor: Color
    let highContrastColor: Color
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(accessibilityService.adaptiveColor(normal: normalColor, highContrast: highContrastColor))
    }
}

/// View modifier that adapts animations for reduced motion
struct ReducedMotionAdaptive: ViewModifier {
    @ObservedObject private var accessibilityService = AccessibilityService.shared
    
    let normalAnimation: Animation
    
    func body(content: Content) -> some View {
        content
            .animation(accessibilityService.isReducedMotionEnabled ? nil : normalAnimation, value: UUID())
    }
}

extension View {
    /// Apply high contrast adaptive coloring
    func highContrastAdaptive(normal normalColor: Color, highContrast highContrastColor: Color) -> some View {
        self.modifier(HighContrastAdaptive(normalColor: normalColor, highContrastColor: highContrastColor))
    }
    
    /// Apply reduced motion adaptive animation
    func reducedMotionAdaptive(animation: Animation) -> some View {
        self.modifier(ReducedMotionAdaptive(normalAnimation: animation))
    }
}