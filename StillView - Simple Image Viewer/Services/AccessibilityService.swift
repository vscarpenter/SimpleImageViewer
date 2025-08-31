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
    
    /// Get focus ring color that adapts to accessibility settings
    /// - Returns: Appropriate focus ring color
    func focusRingColor() -> Color {
        if isHighContrastEnabled {
            return .accentColor
        } else {
            return .accentColor.opacity(0.7)
        }
    }
    
    /// Get focus ring width that adapts to accessibility settings
    /// - Returns: Appropriate focus ring width
    func focusRingWidth() -> CGFloat {
        return isHighContrastEnabled ? 3.0 : 2.0
    }
    
    /// Check if system prefers reduced transparency
    /// - Returns: Whether reduced transparency is enabled
    func isReducedTransparencyEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: "ReduceTransparency")
    }
    
    /// Get background opacity that respects transparency preferences
    /// - Parameter normalOpacity: Normal opacity value
    /// - Returns: Adjusted opacity for accessibility preferences
    func adaptiveBackgroundOpacity(_ normalOpacity: Double) -> Double {
        return isReducedTransparencyEnabled() ? 1.0 : normalOpacity
    }
    
    /// Announce preference changes for screen readers
    /// - Parameters:
    ///   - setting: Name of the setting that changed
    ///   - newValue: New value of the setting
    func announcePreferenceChange(setting: String, newValue: String) {
        guard isVoiceOverEnabled else { return }
        
        let message = "\(setting) changed to \(newValue)"
        DispatchQueue.main.async {
            NSAccessibility.post(
                element: NSApp.mainWindow as Any,
                notification: .announcementRequested
            )
        }
    }
    
    /// Get appropriate contrast ratio for text
    /// - Returns: Minimum contrast ratio to use
    func minimumContrastRatio() -> Double {
        return isHighContrastEnabled ? 7.0 : 4.5 // WCAG AAA vs AA standards
    }
    
    /// Post accessibility announcement for favorites actions
    /// - Parameters:
    ///   - message: The message to announce
    ///   - priority: The priority of the announcement
    func announceFavoritesAction(_ message: String, priority: NSAccessibilityPriorityLevel = .medium) {
        guard isVoiceOverEnabled else { return }
        
        DispatchQueue.main.async {
            // Post accessibility notification with the message
            let notification = NSAccessibility.Notification.announcementRequested
            NSAccessibility.post(element: NSApp.mainWindow as Any, notification: notification)
        }
    }
    
    /// Get accessibility description for favorite status
    /// - Parameters:
    ///   - isFavorite: Whether the item is favorited
    ///   - itemName: Name of the item
    /// - Returns: Accessibility description
    func favoriteStatusDescription(isFavorite: Bool, itemName: String) -> String {
        if isFavorite {
            return "\(itemName) is in your favorites collection"
        } else {
            return "\(itemName) is not favorited"
        }
    }
    
    /// Get accessibility hint for favorite actions
    /// - Parameter isFavorite: Whether the item is currently favorited
    /// - Returns: Accessibility hint for the action
    func favoriteActionHint(isFavorite: Bool) -> String {
        if isFavorite {
            return "Double-tap to remove from favorites, or use Command+F"
        } else {
            return "Double-tap to add to favorites, or use Command+F"
        }
    }
    
    /// Get high contrast color for heart indicators
    /// - Parameter isFavorite: Whether the item is favorited
    /// - Returns: Appropriate color for high contrast mode
    func heartIndicatorColor(isFavorite: Bool) -> Color {
        if isHighContrastEnabled {
            return isFavorite ? .red : .primary
        } else {
            return isFavorite ? .red : .secondary
        }
    }
    
    /// Get high contrast background color for heart indicators
    /// - Returns: Appropriate background color for high contrast mode
    func heartIndicatorBackgroundColor() -> Color {
        return adaptiveColor(
            normal: Color.black.opacity(0.6),
            highContrast: Color.black.opacity(0.9)
        )
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
        // Check for high contrast mode using system preferences
        let increaseContrast = UserDefaults.standard.bool(forKey: "AppleAquaColorVariant")
        let differentiateWithoutColor = UserDefaults.standard.bool(forKey: "DifferentiateWithoutColor")
        
        isHighContrastEnabled = increaseContrast || differentiateWithoutColor
    }
    
    private func updateReducedMotionSetting() {
        // Check for reduced motion preference using system accessibility settings
        isReducedMotionEnabled = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
    
    private func updateVoiceOverSetting() {
        // Check if VoiceOver is running using accessibility APIs
        isVoiceOverEnabled = NSWorkspace.shared.isVoiceOverEnabled
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

/// View modifier that adapts focus rings for accessibility
struct AccessibilityFocusRing: ViewModifier {
    @ObservedObject private var accessibilityService = AccessibilityService.shared
    
    let isVisible: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        accessibilityService.focusRingColor(),
                        lineWidth: isVisible ? accessibilityService.focusRingWidth() : 0
                    )
                    .animation(accessibilityService.adaptiveAnimation(.easeInOut(duration: 0.2)), value: isVisible)
            )
    }
}

/// View modifier that adapts transparency for accessibility
struct AccessibilityTransparency: ViewModifier {
    @ObservedObject private var accessibilityService = AccessibilityService.shared
    
    let normalOpacity: Double
    
    func body(content: Content) -> some View {
        content
            .opacity(accessibilityService.adaptiveBackgroundOpacity(normalOpacity))
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
    
    /// Apply accessibility-aware focus ring
    func accessibilityFocusRing(isVisible: Bool) -> some View {
        self.modifier(AccessibilityFocusRing(isVisible: isVisible))
    }
    
    /// Apply accessibility-aware transparency
    func accessibilityTransparency(_ opacity: Double) -> some View {
        self.modifier(AccessibilityTransparency(normalOpacity: opacity))
    }
}